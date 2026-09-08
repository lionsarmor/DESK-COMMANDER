#!/usr/bin/env python3
"""DESK COMMANDER authenticated chat server.

The browser uses short-lived bearer sessions over HTTPS. The Commander X16
uses the same accounts through ZiModem's HTTPS-capable ``AT&G`` command. User
passwords are never stored: the server keeps salted scrypt hashes only.
"""

from __future__ import annotations

import json
import base64
import hashlib
import ipaddress
import os
import secrets
import socket
import struct
import threading
import fcntl
import time
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


ROOT = Path(__file__).resolve().parent
WEB_ROOT = ROOT / "web"
DATA_FILE = Path(os.environ.get("DESK_CHAT_DATA", ROOT / "chat-data.json"))
LOCK = threading.Lock()
CHAT_PORT = int(os.environ.get("DESK_CHAT_PORT", "8088"))
ONLINE_SECONDS = 75
SESSION_SECONDS = 12 * 60 * 60
MAX_REQUEST_BODY = 4096
MAX_REQUESTS_PER_MINUTE = 240
# The public alpha must never grow without a ceiling.  The first two limits
# match what one X16 can display; the remaining limits keep a forgotten public
# server from accumulating an unlimited number of placeholder users/rooms.
MAX_FRIENDS_PER_USER = 8
MAX_GROUPS_PER_USER = 4
MAX_GROUP_MEMBERS = 32
MAX_USERS = 256
MAX_GROUPS = 64
MAX_MESSAGES_PER_THREAD = 100
MAX_MESSAGE_LENGTH = 96
ADMIN_NAME_RAW = os.environ.get("DESK_ADMIN_NAME", "RODDY")
ADMIN_TOKEN_FILE = os.environ.get("DESK_ADMIN_TOKEN_FILE", "")
if ADMIN_TOKEN_FILE:
    try:
        ADMIN_TOKEN = Path(ADMIN_TOKEN_FILE).read_text(encoding="ascii").strip()
    except OSError:
        ADMIN_TOKEN = ""
else:
    ADMIN_TOKEN = os.environ.get("DESK_ADMIN_TOKEN", "")
PRESENCE: dict[str, dict] = {}
ACTIVITY: list[dict] = []
REQUEST_TIMES: dict[str, list[float]] = {}
SESSIONS: dict[str, dict] = {}


def detect_lan_ip() -> str:
    """Find the physical LAN address the X16 can use.

    A VPN or Docker address is often the computer's default route, so do not
    simply report that route. Prefer Wi-Fi, then another normal LAN adapter.
    """
    public_host = os.environ.get("DESK_PUBLIC_HOST", "").strip()
    if public_host:
        return public_host
    candidates: list[tuple[int, str]] = []
    control = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        for _, name in socket.if_nameindex():
            if name == "lo" or name.startswith(("docker", "br-", "veth", "tun", "tap", "proton")):
                continue
            try:
                request = struct.pack("256s", name[:15].encode())
                address = socket.inet_ntoa(fcntl.ioctl(control.fileno(), 0x8915, request)[20:24])
            except OSError:
                continue
            wireless = Path("/sys/class/net", name, "wireless").exists()
            candidates.append((0 if wireless else 1, address))
    finally:
        control.close()
    return min(candidates, default=(9, "NOT FOUND"))[1]


def clean(value: str, limit: int = 16) -> str:
    """Keep the alpha protocol printable, bounded, and X16-friendly."""
    return "".join(c for c in value.strip() if 32 <= ord(c) <= 126)[:limit]


def checked_password(value: str) -> str:
    """Validate one bounded password without ever normalizing its case."""
    if not 8 <= len(value) <= 24 or any(ord(c) < 32 or ord(c) > 126 for c in value):
        raise ValueError("PASSWORD MUST BE 8-24 PRINTABLE CHARACTERS")
    return value


def hash_password(password: str) -> str:
    """Return a portable salted scrypt record using Python's audited primitive."""
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode("utf-8"), salt=salt,
                            n=16384, r=8, p=1, dklen=32)
    encode = lambda value: base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")
    return f"scrypt$16384$8$1${encode(salt)}${encode(digest)}"


def verify_password(password: str, encoded: str) -> bool:
    try:
        name, n, r, p, salt_text, digest_text = encoded.split("$")
        if name != "scrypt":
            return False
        decode = lambda value: base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
        expected = decode(digest_text)
        actual = hashlib.scrypt(password.encode("utf-8"), salt=decode(salt_text),
                                n=int(n), r=int(r), p=int(p), dklen=len(expected))
        return secrets.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def authenticate_account(username: str, password: str, allow_claim: bool = False) -> bool:
    """Authenticate, or securely claim a new/legacy placeholder account."""
    password = checked_password(password)
    profile = DATA["users"].get(username)
    if profile is None:
        if not allow_claim:
            return False
        profile = ensure_user(username)
    saved = profile.get("password_hash")
    if not saved:
        if not allow_claim:
            return False
        profile["password_hash"] = hash_password(password)
        ensure_default_group(username)
        save_data()
        return True
    return verify_password(password, saved)


def issue_session(username: str) -> str:
    token = secrets.token_urlsafe(32)
    SESSIONS[token] = {"user": username, "expires": time.time() + SESSION_SECONDS}
    return token


def session_user(authorization: str) -> str:
    prefix = "Bearer "
    if not authorization.startswith(prefix):
        return ""
    token = authorization[len(prefix):]
    session = SESSIONS.get(token)
    if not session or session["expires"] <= time.time():
        SESSIONS.pop(token, None)
        return ""
    session["expires"] = time.time() + SESSION_SECONDS
    return str(session["user"])


# Normalize the configured manager after clean() is available.
ADMIN_NAME = clean(ADMIN_NAME_RAW) or "RODDY"
DEFAULT_GROUP = "WELCOME"
DEFAULT_GROUP_MESSAGE = "WELCOME! MEET PEOPLE HERE, THEN CREATE YOUR OWN GROUPS."
EMOJI_TO_TOKEN = {"🙂": ":S:", "😄": ":G:", "😉": ":W:", "🙁": ":F:", "😠": ":A:"}
TOKEN_TO_EMOJI = {token: emoji for emoji, token in EMOJI_TO_TOKEN.items()}


def encode_web_emojis(value: str) -> str:
    """Turn browser Unicode into the tiny ASCII tokens understood by X16."""
    for emoji, token in EMOJI_TO_TOKEN.items():
        value = value.replace(emoji, token)
    return value


def web_messages(messages: list[dict]) -> list[dict]:
    """Add a browser-only rendering without changing stored/wire text."""
    rendered = []
    for message in messages:
        web_text = message.get("text", "")
        for token, emoji in TOKEN_TO_EMOJI.items():
            web_text = web_text.replace(token, emoji)
        rendered.append({**message, "webText": web_text})
    return rendered


def empty_data() -> dict:
    return {"users": {}, "groups": {}, "direct": {}}


def load_data() -> dict:
    if not DATA_FILE.exists():
        return empty_data()
    try:
        with DATA_FILE.open("r", encoding="utf-8") as source:
            data = json.load(source)
        for key in ("users", "groups", "direct"):
            data.setdefault(key, {})
        # Early Desk Commander builds called a second kind of group chat a
        # "server". Groups are the single shared-room model now. Fold every
        # legacy server into Groups so an upgrade never loses members/chat.
        for name, old_room in data.pop("servers", {}).items():
            room = data["groups"].setdefault(name, {"members": [], "messages": []})
            for member in old_room.get("members", []):
                if member not in room["members"]:
                    room["members"].append(member)
            room["messages"].extend(old_room.get("messages", []))
            del room["messages"][:-MAX_MESSAGES_PER_THREAD]
        for username, profile in data["users"].items():
            profile.setdefault("friends", [])
            profile.setdefault("password_hash", None)
            # A direct conversation with yourself is never meaningful. Older
            # manager-console builds accidentally allowed RODDY to add RODDY,
            # which made the web transcript look empty while the real X16
            # user's thread continued elsewhere.
            profile["friends"] = [name for name in profile["friends"]
                                  if name != username]
            for room_name in profile.pop("servers", []):
                room = data["groups"].setdefault(room_name, {"members": [], "messages": []})
                if username not in room["members"]:
                    room["members"].append(username)
        return data
    except (OSError, ValueError):
        return empty_data()


DATA = load_data()


def save_data() -> None:
    temporary = DATA_FILE.with_suffix(".tmp")
    with temporary.open("w", encoding="utf-8") as output:
        json.dump(DATA, output, indent=2, sort_keys=True)
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(DATA_FILE)


def ensure_user(username: str) -> dict:
    if username in DATA["users"]:
        return DATA["users"][username]
    if len(DATA["users"]) >= MAX_USERS:
        raise ValueError("server user limit reached")
    DATA["users"][username] = {"friends": [], "password_hash": None}
    return DATA["users"][username]


def group_count_for(username: str) -> int:
    return sum(username in room.get("members", [])
               for room in DATA["groups"].values())


def groups_for_user(username: str) -> list[str]:
    """Return the X16's groups with the system WELCOME room first."""
    names = [name for name, room in DATA["groups"].items()
             if username in room.get("members", [])]
    if DEFAULT_GROUP in names:
        names.remove(DEFAULT_GROUP)
        names.insert(0, DEFAULT_GROUP)
    return names


def ensure_default_group(username: str) -> dict:
    """Create the permanent lobby and add an account to it.

    WELCOME is the one room allowed to exceed the ordinary 32-member limit:
    every account needs a common place to meet before making smaller groups.
    """
    room = DATA["groups"].setdefault(
        DEFAULT_GROUP,
        {"members": [], "messages": []},
    )
    if ADMIN_NAME not in room["members"]:
        room["members"].insert(0, ADMIN_NAME)
    if username and username not in room["members"]:
        room["members"].append(username)
    if not room["messages"]:
        room["messages"].append(
            {"from": ADMIN_NAME, "text": DEFAULT_GROUP_MESSAGE}
        )
    return room


def require_friend_space(username: str, friend: str) -> None:
    """RODDY is global; ordinary clients have the X16's eight-name limit."""
    if username == ADMIN_NAME:
        return
    profile = DATA["users"].get(username, {"friends": []})
    if friend not in profile.get("friends", []) and \
       len(profile.get("friends", [])) >= MAX_FRIENDS_PER_USER:
        raise ValueError("friend list full (8)")


def link_friends(left: str, right: str) -> None:
    require_friend_space(left, right)
    require_friend_space(right, left)
    left_profile = ensure_user(left)
    right_profile = ensure_user(right)
    if right not in left_profile["friends"]:
        left_profile["friends"].append(right)
    if left not in right_profile["friends"]:
        right_profile["friends"].append(left)


def unlink_friends(left: str, right: str) -> None:
    left_profile = DATA["users"].get(left)
    right_profile = DATA["users"].get(right)
    if left_profile and right in left_profile.get("friends", []):
        left_profile["friends"].remove(right)
    if right_profile and left in right_profile.get("friends", []):
        right_profile["friends"].remove(left)
    # Unfriending is also the user's delete-history operation.  This bounds
    # direct threads and avoids resurrecting old chat after adding them again.
    DATA["direct"].pop(direct_key(left, right), None)


def create_or_join_group(username: str, group_name: str) -> dict:
    if group_name == DEFAULT_GROUP:
        return ensure_default_group(username)
    room = DATA["groups"].get(group_name)
    joining = room is None or username not in room["members"]
    if joining and username != ADMIN_NAME and \
       group_count_for(username) >= MAX_GROUPS_PER_USER:
        raise ValueError("group list full (4)")
    if room is None:
        if len(DATA["groups"]) >= MAX_GROUPS:
            raise ValueError("server group limit reached")
        room = {"members": [], "messages": []}
        DATA["groups"][group_name] = room
    if joining:
        if len(room["members"]) >= MAX_GROUP_MEMBERS:
            raise ValueError("group member limit reached")
        room["members"].append(username)
    return room


def note_activity(client: str, user: str, action: str, result: str = "OK") -> None:
    """Keep a short live diagnostic trail; this is not written to the SD data."""
    ACTIVITY.append({"time": datetime.now().strftime("%H:%M:%S"),
                     "at": time.time(),
                     "client": client, "user": user or "-",
                     "action": action, "result": result})
    del ACTIVITY[:-40]


def touch_user(username: str, client: str = "WEB", state: str = "online") -> None:
    if username:
        PRESENCE[username] = {"state": state, "seen": time.monotonic(), "client": client}


def presence_of(username: str) -> str:
    item = PRESENCE.get(username)
    if not item or item["state"] == "offline":
        return "offline"
    if item["state"] == "away":
        return "away"
    if time.monotonic() - item["seen"] > ONLINE_SECONDS:
        return "offline"
    return "online"


def direct_key(left: str, right: str) -> str:
    return "|".join(sorted((left, right), key=str.casefold))


def messages_for(user: str, kind: str, target: str) -> list[dict]:
    if kind == "F":
        return DATA["direct"].get(direct_key(user, target), [])
    if kind != "G":
        return []
    room = DATA["groups"].get(target, {})
    if user not in room.get("members", []):
        return []
    return room.get("messages", [])


def add_message(user: str, kind: str, target: str, text: str) -> None:
    message = {"from": user, "text": text}
    if kind == "F":
        bucket = DATA["direct"].setdefault(direct_key(user, target), [])
    elif kind == "G":
        bucket = DATA["groups"][target]["messages"]
    else:
        raise ValueError("invalid conversation kind")
    bucket.append(message)
    del bucket[:-MAX_MESSAGES_PER_THREAD]


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        # X16 credentials are carried inside an HTTPS request because AT&G is
        # a bounded GET-only transport. Never copy that query into local logs.
        safe_args = list(args)
        if safe_args and isinstance(safe_args[0], str):
            safe_args[0] = safe_args[0].split("?", 1)[0]
        print(f"[chat] {self.address_string()} {fmt % tuple(safe_args)}")

    def send_bytes(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def rate_allowed(self) -> bool:
        """Small public-alpha abuse guard; real RetroWire uses device limits."""
        now = time.monotonic()
        address = self.client_address[0]
        # Caddy is the only loopback caller in production. Recover its original
        # browser address so several public testers do not share one 240/minute
        # bucket. Never trust this header on direct port-8088 connections.
        if address in ("127.0.0.1", "::1"):
            forwarded = self.headers.get("X-Forwarded-For", "").split(",", 1)[0].strip()
            try:
                if forwarded:
                    address = str(ipaddress.ip_address(forwarded))
            except ValueError:
                pass
        if len(REQUEST_TIMES) > 512:
            for old_address, seen in list(REQUEST_TIMES.items()):
                if not seen or now - seen[-1] >= 60:
                    del REQUEST_TIMES[old_address]
        recent = [seen for seen in REQUEST_TIMES.get(address, []) if now - seen < 60]
        if len(recent) >= MAX_REQUESTS_PER_MINUTE:
            REQUEST_TIMES[address] = recent
            return False
        recent.append(now)
        REQUEST_TIMES[address] = recent
        return True

    def send_json(self, status: int, value) -> None:
        self.send_bytes(status, json.dumps(value).encode(), "application/json")

    def send_text(self, lines: list[str], status: int = 200) -> None:
        body = ("\n".join(lines) + "\n").encode("ascii", "replace")
        self.send_bytes(status, body, "text/plain; charset=us-ascii")

    def query(self) -> dict[str, str]:
        parsed = parse_qs(urlparse(self.path).query)
        return {key: values[0] for key, values in parsed.items() if values}

    def json_body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length < 0 or length > MAX_REQUEST_BODY:
            raise ValueError("request too large")
        return json.loads(self.rfile.read(length) or b"{}")

    def admin_authorized(self) -> bool:
        supplied = self.headers.get("Authorization", "")
        expected = f"Bearer {ADMIN_TOKEN}"
        return bool(ADMIN_TOKEN and secrets.compare_digest(supplied, expected))

    def require_admin(self) -> bool:
        if self.admin_authorized():
            return True
        self.send_json(401, {"ok": False, "error": "manager token required"})
        return False

    def require_user(self, requested: str = "") -> str:
        user = session_user(self.headers.get("Authorization", ""))
        if not user or (requested and requested != user):
            self.send_json(401, {"ok": False, "error": "sign in required"})
            return ""
        return user

    def admin_state(self) -> dict:
        users = [{"name": name, "presence": presence_of(name),
                  "friends": list(profile.get("friends", []))}
                 for name, profile in sorted(DATA["users"].items())
                 if name != ADMIN_NAME]
        groups = [{"name": name, "members": list(room.get("members", [])),
                   "protected": name == DEFAULT_GROUP}
                  for name, room in sorted(DATA["groups"].items())]
        return {"ok": True, "manager": ADMIN_NAME, "users": users, "groups": groups,
                "usage": {"users": len(users), "groups": len(groups)},
                "limits": {"users": MAX_USERS - 1, "groups": MAX_GROUPS,
                           "friendsPerUser": MAX_FRIENDS_PER_USER,
                           "groupsPerUser": MAX_GROUPS_PER_USER,
                           "membersPerGroup": MAX_GROUP_MEMBERS,
                           "messagesPerThread": MAX_MESSAGES_PER_THREAD}}

    def admin_messages(self, kind: str, target: str) -> list[dict]:
        if kind == "F":
            messages = DATA["direct"].get(direct_key(ADMIN_NAME, target), [])
        else:
            messages = DATA["groups"].get(target, {}).get("messages", [])
        return web_messages(messages)

    def handle_admin_post(self, action: str, body: dict) -> dict:
        target = clean(str(body.get("target", "")))
        if action == "send":
            kind = clean(str(body.get("kind", "")), 1)
            text = clean(encode_web_emojis(str(body.get("text", ""))),
                         MAX_MESSAGE_LENGTH)
            if kind not in ("F", "G") or not target or not text:
                raise ValueError("conversation and message required")
            ensure_user(ADMIN_NAME)
            if kind == "F":
                if target == ADMIN_NAME:
                    raise ValueError("choose an X16 user, not RODDY")
                ensure_user(target)
                # A manager-initiated conversation becomes visible on the
                # retro client automatically; the user does not have to add
                # RODDY before reading and replying.
                link_friends(ADMIN_NAME, target)
                bucket = DATA["direct"].setdefault(direct_key(ADMIN_NAME, target), [])
                bucket.append({"from": ADMIN_NAME, "text": text})
                del bucket[:-MAX_MESSAGES_PER_THREAD]
            else:
                room = DATA["groups"].get(target)
                if not room:
                    raise ValueError("group not found")
                room["messages"].append({"from": ADMIN_NAME, "text": text})
                del room["messages"][:-MAX_MESSAGES_PER_THREAD]
        elif action == "user":
            if not target or target == ADMIN_NAME:
                raise ValueError("different username required")
            link_friends(ADMIN_NAME, target)
        elif action == "friend-delete":
            owner = clean(str(body.get("user", ADMIN_NAME))) or ADMIN_NAME
            if owner not in DATA["users"] or not target or \
               target not in DATA["users"][owner].get("friends", []):
                raise ValueError("friendship not found")
            unlink_friends(owner, target)
        elif action == "user-delete":
            if not target or target == ADMIN_NAME:
                raise ValueError("the manager account cannot be deleted")
            if target not in DATA["users"]:
                raise ValueError("user not found")

            # A manager deletion is a complete account removal. Clean every
            # reference so a deleted username does not remain in another
            # user's X16 SYNC list or in a group membership list.
            del DATA["users"][target]
            PRESENCE.pop(target, None)
            for token, session in list(SESSIONS.items()):
                if session.get("user") == target:
                    del SESSIONS[token]
            for profile in DATA["users"].values():
                profile["friends"] = [name for name in profile.get("friends", [])
                                      if name != target]
            for room in DATA["groups"].values():
                room["members"] = [name for name in room.get("members", [])
                                   if name != target]
            for key in list(DATA["direct"]):
                if target in key.split("|"):
                    del DATA["direct"][key]
        elif action == "group":
            if not target:
                raise ValueError("group name required")
            create_or_join_group(ADMIN_NAME, target)
        elif action == "group-delete":
            if target == DEFAULT_GROUP:
                raise ValueError("WELCOME is a protected group")
            if target not in DATA["groups"]:
                raise ValueError("group not found")
            del DATA["groups"][target]
        elif action == "group-member":
            member = clean(str(body.get("member", "")))
            room = DATA["groups"].get(target)
            if not room or not member:
                raise ValueError("group and member required")
            if member not in room["members"]:
                if member != ADMIN_NAME and group_count_for(member) >= MAX_GROUPS_PER_USER:
                    raise ValueError("member group list full (4)")
                if len(room["members"]) >= MAX_GROUP_MEMBERS:
                    raise ValueError("group member limit reached")
                ensure_user(member)
                room["members"].append(member)
        elif action == "group-test-send":
            # Let one manager browser impersonate small test accounts in a
            # group so a physical X16 can exercise a busy room.
            username = clean(str(body.get("user", "")))
            text = clean(encode_web_emojis(str(body.get("text", ""))),
                         MAX_MESSAGE_LENGTH)
            room = DATA["groups"].get(target)
            if not room:
                raise ValueError("select an existing group")
            if not username or not text:
                raise ValueError("test username and message required")
            if username == ADMIN_NAME:
                raise ValueError("use the RODDY message box for manager messages")
            ensure_user(username)
            ensure_default_group(username)
            if username not in room["members"]:
                if group_count_for(username) >= MAX_GROUPS_PER_USER:
                    raise ValueError("test user group list full")
                if len(room["members"]) >= MAX_GROUP_MEMBERS:
                    raise ValueError("group member limit reached")
                room["members"].append(username)
            room["messages"].append({"from": username, "text": text})
            del room["messages"][:-MAX_MESSAGES_PER_THREAD]
        else:
            raise ValueError("unknown manager action")
        note_activity("ADMIN", ADMIN_NAME, action.upper())
        return {"ok": True}

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_GET(self) -> None:
        if len(self.path) > 512:
            self.send_json(414, {"ok": False, "error": "request URI too long"})
            return
        if not self.rate_allowed():
            self.send_json(429, {"ok": False, "error": "rate limit"})
            return
        path = urlparse(self.path).path
        if path == "/api/admin/state":
            if not self.require_admin():
                return
            with LOCK:
                self.send_json(200, self.admin_state())
            return
        if path == "/api/admin/messages":
            if not self.require_admin():
                return
            q = self.query()
            with LOCK:
                self.send_json(200, self.admin_messages(clean(q.get("kind", ""), 1),
                                                        clean(q.get("target", ""))))
            return
        if path.startswith("/x16/"):
            self.handle_x16(path.removeprefix("/x16/"), self.query())
            return
        if path == "/api/state":
            requested = clean(self.query().get("user", ""))
            user = self.require_user(requested)
            if not user:
                return
            with LOCK:
                profile = DATA["users"].get(user, {"friends": []})
                groups = groups_for_user(user)
                statuses = {name: presence_of(name) for name in profile["friends"]}
                self.send_json(200, {"user": user, **profile, "groups": groups,
                                     "presence": statuses,
                                     "allUsers": sorted(DATA["users"])})
            return
        if path == "/api/info":
            x16_calls = [item for item in ACTIVITY if item["client"] == "X16"]
            last_x16 = x16_calls[-1] if x16_calls else None
            self.send_json(200, {"x16Ip": detect_lan_ip(), "port": CHAT_PORT,
                                 "lastX16": last_x16,
                                 "x16Active": bool(last_x16 and
                                                   time.time() - last_x16["at"] < 90)})
            return
        if path == "/api/heartbeat":
            requested = clean(self.query().get("user", ""))
            user = self.require_user(requested)
            if not user:
                return
            with LOCK:
                # Refresh the timer without overwriting an explicit Away or
                # Offline selection made in the browser console.
                state = PRESENCE.get(user, {}).get("state", "online")
                touch_user(user, "WEB", state)
            self.send_json(200, {"ok": True})
            return
        if path == "/api/preview":
            if not self.require_admin():
                return
            user = clean(self.query().get("user", ""))
            with LOCK:
                profile = DATA["users"].get(user, {"friends": []})
                codes = {"online": "O", "away": "A", "offline": "X"}
                lines = ["OK"]
                lines += [f"F|{name}|{codes[presence_of(name)]}"
                          for name in profile["friends"][:8]]
                lines += [f"G|{name}" for name in groups_for_user(user)[:4]]
                self.send_json(200, {"lines": lines,
                                     "bytes": len(("\n".join(lines) + "\n").encode())})
            return
        if path == "/api/activity":
            if not self.require_admin():
                return
            with LOCK:
                self.send_json(200, list(reversed(ACTIVITY)))
            return
        if path == "/api/messages":
            q = self.query()
            user = self.require_user(clean(q.get("user", "")))
            if not user:
                return
            with LOCK:
                self.send_json(200, web_messages(
                    messages_for(user,
                                 clean(q.get("kind", ""), 1),
                                 clean(q.get("target", "")))))
            return
        super().do_GET()

    def do_POST(self) -> None:
        try:
            if not self.rate_allowed():
                self.send_json(429, {"ok": False, "error": "rate limit"})
                return
            body = self.json_body()
            path = urlparse(self.path).path
            if path == "/api/session":
                username = clean(str(body.get("user", "")))
                password = str(body.get("password", ""))
                if not username or username == ADMIN_NAME:
                    raise ValueError("valid username required")
                with LOCK:
                    created = username not in DATA["users"] or not DATA["users"].get(username, {}).get("password_hash")
                    if not authenticate_account(username, password, bool(body.get("create"))):
                        raise ValueError("username or password is incorrect")
                    ensure_default_group(username)
                    touch_user(username, "WEB")
                    save_data()
                    token = issue_session(username)
                self.send_json(200, {"ok": True, "user": username,
                                     "created": created, "token": token,
                                     "expiresIn": SESSION_SECONDS})
                return
            if path.startswith("/api/admin/"):
                if not self.require_admin():
                    return
                with LOCK:
                    result = self.handle_admin_post(path.removeprefix("/api/admin/"), body)
                    save_data()
                self.send_json(200, result)
                return
            requested = clean(str(body.get("user", "")))
            user = self.require_user(requested)
            if not user:
                return
            body["user"] = user
            with LOCK:
                result = self.mutate(path.removeprefix("/api/"), body)
                save_data()
            self.send_json(200, {"ok": True, **result})
        except (json.JSONDecodeError, KeyError, ValueError) as error:
            self.send_json(400, {"ok": False, "error": str(error)})

    def mutate(self, action: str, values: dict) -> dict:
        user = clean(str(values.get("user", "")))
        if not user:
            raise ValueError("username required")
        if user == ADMIN_NAME:
            raise ValueError("manager username is reserved")
        if action == "account":
            created = user not in DATA["users"]
            ensure_user(user)
            ensure_default_group(user)
            touch_user(user, "WEB")
            note_activity("WEB", user, "ACCOUNT")
            return {"user": user, "created": created}
        if user not in DATA["users"]:
            raise ValueError("create the account first")

        target = clean(str(values.get("target", "")))
        if action == "friend":
            if not target or target == user:
                raise ValueError("enter a different friend name")
            # An offline friend does not need an active account yet. Create a
            # quiet placeholder so the name persists and direct messages wait.
            link_friends(user, target)
        elif action == "friend-delete":
            if not target or target == user:
                raise ValueError("friend not found")
            unlink_friends(user, target)
        elif action == "group":
            if not target:
                raise ValueError("group name required")
            create_or_join_group(user, target)
        elif action == "group-member":
            member = clean(str(values.get("member", "")))
            if target not in DATA["groups"] or member not in ensure_user(user)["friends"]:
                raise ValueError("group or friend not found")
            if member not in DATA["groups"][target]["members"]:
                if group_count_for(member) >= MAX_GROUPS_PER_USER:
                    raise ValueError("friend group list full (4)")
                if len(DATA["groups"][target]["members"]) >= MAX_GROUP_MEMBERS:
                    raise ValueError("group member limit reached")
                DATA["groups"][target]["members"].append(member)
        elif action == "group-leave":
            if target == DEFAULT_GROUP:
                raise ValueError("WELCOME is a protected group")
            room = DATA["groups"].get(target)
            if not room or user not in room["members"]:
                raise ValueError("group not found")
            room["members"].remove(user)
            if not room["members"]:
                del DATA["groups"][target]
        elif action == "presence":
            state = clean(str(values.get("state", "")), 7).lower()
            if state not in ("online", "away", "offline"):
                raise ValueError("invalid presence")
            touch_user(user, "WEB", state)
        elif action == "message":
            kind = clean(str(values.get("kind", "")), 1)
            text = clean(encode_web_emojis(str(values.get("text", ""))),
                         MAX_MESSAGE_LENGTH)
            if kind not in ("F", "G"):
                raise ValueError("invalid conversation kind")
            if not text or not messages_for(user, kind, target) and not self.can_open(user, kind, target):
                raise ValueError("conversation not available")
            add_message(user, kind, target, text)
        else:
            raise ValueError("unknown action")
        return {}

    @staticmethod
    def can_open(user: str, kind: str, target: str) -> bool:
        if kind == "F":
            return target in ensure_user(user)["friends"]
        if kind == "G":
            return user in DATA["groups"].get(target, {}).get("members", [])
        return False

    def handle_x16(self, action: str, q: dict[str, str]) -> None:
        try:
            with LOCK:
                user = clean(q.get("user", ""))
                if user == ADMIN_NAME:
                    raise ValueError("RESERVED USERNAME")
                password = q.get("auth", "")
                if not user or not authenticate_account(
                        user, password, allow_claim=action == "account"):
                    raise ValueError("AUTH FAILED")
                touch_user(user, "X16")
                note_activity("X16", user, action.upper())
                if action == "sync":
                    if user not in DATA["users"]:
                        raise ValueError("NO ACCOUNT")
                    profile = ensure_user(user)
                    state_code = {"online": "O", "away": "A", "offline": "X"}
                    friends = [f"F|{name}|{state_code[presence_of(name)]}"
                               for name in profile["friends"][:8]]
                    groups = [f"G|{name}" for name in groups_for_user(user)[:4]]
                    # Stay below the X16 client's 256-byte UART response cache.
                    # Never start streamed data with a standalone modem result
                    # word. ZiModem appends its own final OK after AT&G; using
                    # OK inside the payload can make a serial client stop before
                    # the following friend/group records have arrived.
                    lines = ["DC"] + friends + groups
                    self.send_text(lines)
                    return
                if action == "messages":
                    kind, target = clean(q.get("kind", ""), 1), clean(q.get("target", ""))
                    if kind not in ("F", "G"):
                        raise ValueError("BAD KIND")
                    try:
                        offset = max(0, min(96, int(q.get("offset", "0"))))
                    except ValueError:
                        offset = 0
                    history = messages_for(user, kind, target)
                    # The X16 shows two double-line bubbles. Offset advances by one
                    # message so wheel/arrow scrolling feels continuous while
                    # the server retains the complete 100-message history.
                    end = max(0, len(history) - offset)
                    start = max(0, end - 2)
                    batch = history[start:end] if end else []
                    lines = ["DC"] + [f"M|{m['from']}|{m['text']}" for m in batch]
                    self.send_text(lines)
                    return

                values = {"user": user, "target": clean(q.get("target", "")),
                          "kind": clean(q.get("kind", ""), 1),
                          "text": clean(q.get("text", ""), MAX_MESSAGE_LENGTH),
                          "member": clean(q.get("member", ""))}
                action_map = {"account": "account", "friend": "friend",
                              "group": "group", "groupadd": "group-member",
                              "unfriend": "friend-delete",
                              "groupleave": "group-leave", "send": "message"}
                self.mutate(action_map[action], values)
                save_data()
                self.send_text(["OK"])
        except (KeyError, ValueError) as error:
            self.send_text(["ERR", clean(str(error), 32)], 400)


def main() -> None:
    # The application origin carries no TLS of its own. Production Caddy runs
    # on the same machine and is the only public entry point.
    host = os.environ.get("DESK_CHAT_BIND", "127.0.0.1")
    with LOCK:
        ensure_user(ADMIN_NAME)
        # Upgrade existing saved accounts as well as new ones.  This is
        # idempotent, so every restart also repairs an accidentally damaged
        # WELCOME membership without duplicating people or the greeting.
        for username in list(DATA["users"]):
            ensure_default_group(username)
        save_data()
    server = ThreadingHTTPServer((host, CHAT_PORT), Handler)
    print(f"DESK COMMANDER chat server: http://localhost:{CHAT_PORT}")
    print("Open the configured HTTPS console; enter DESK_PUBLIC_HOST on the X16.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping chat server.")


if __name__ == "__main__":
    main()
