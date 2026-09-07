#!/usr/bin/env python3
"""DESK COMMANDER X16 compatibility chat server.

It serves the HTTPS-proxied RODDY maintenance console and a deliberately tiny
plaintext HTTP protocol for current ZiModem hardware. The latter is an alpha
bridge only and will be replaced by encrypted RetroWire. Only Python's standard
library is required.
"""

from __future__ import annotations

import json
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
MAX_REQUEST_BODY = 4096
MAX_REQUESTS_PER_MINUTE = 240
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


# Normalize the configured manager after clean() is available.
ADMIN_NAME = clean(ADMIN_NAME_RAW) or "RODDY"


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
            del room["messages"][:-100]
        for username, profile in data["users"].items():
            profile.setdefault("friends", [])
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
    return DATA["users"].setdefault(username, {"friends": []})


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
    room = DATA["groups"].get(target, {})
    if user not in room.get("members", []):
        return []
    return room.get("messages", [])


def add_message(user: str, kind: str, target: str, text: str) -> None:
    message = {"from": user, "text": text}
    if kind == "F":
        bucket = DATA["direct"].setdefault(direct_key(user, target), [])
    else:
        bucket = DATA["groups"][target]["messages"]
    bucket.append(message)
    del bucket[:-100]


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        print(f"[chat] {self.address_string()} {fmt % args}")

    def send_bytes(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def rate_allowed(self) -> bool:
        """Small public-alpha abuse guard; real RetroWire uses device limits."""
        now = time.monotonic()
        address = self.client_address[0]
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

    def admin_state(self) -> dict:
        users = [{"name": name, "presence": presence_of(name),
                  "friends": list(profile.get("friends", []))}
                 for name, profile in sorted(DATA["users"].items())]
        groups = [{"name": name, "members": list(room.get("members", []))}
                  for name, room in sorted(DATA["groups"].items())]
        return {"ok": True, "manager": ADMIN_NAME, "users": users, "groups": groups}

    def admin_messages(self, kind: str, target: str) -> list[dict]:
        if kind == "F":
            return DATA["direct"].get(direct_key(ADMIN_NAME, target), [])
        return DATA["groups"].get(target, {}).get("messages", [])

    def handle_admin_post(self, action: str, body: dict) -> dict:
        target = clean(str(body.get("target", "")))
        if action == "send":
            kind = clean(str(body.get("kind", "")), 1)
            text = clean(str(body.get("text", "")), 32)
            if kind not in ("F", "G") or not target or not text:
                raise ValueError("conversation and message required")
            ensure_user(ADMIN_NAME)
            if kind == "F":
                ensure_user(target)
                # A manager-initiated conversation becomes visible on the
                # retro client automatically; the user does not have to add
                # RODDY before reading and replying.
                if target not in ensure_user(ADMIN_NAME)["friends"]:
                    ensure_user(ADMIN_NAME)["friends"].append(target)
                if ADMIN_NAME not in ensure_user(target)["friends"]:
                    ensure_user(target)["friends"].append(ADMIN_NAME)
                bucket = DATA["direct"].setdefault(direct_key(ADMIN_NAME, target), [])
                bucket.append({"from": ADMIN_NAME, "text": text})
                del bucket[:-100]
            else:
                room = DATA["groups"].get(target)
                if not room:
                    raise ValueError("group not found")
                room["messages"].append({"from": ADMIN_NAME, "text": text})
                del room["messages"][:-100]
        elif action == "user":
            if not target or target == ADMIN_NAME:
                raise ValueError("different username required")
            ensure_user(target)
            friends = ensure_user(ADMIN_NAME)["friends"]
            if target not in friends:
                friends.append(target)
            if ADMIN_NAME not in ensure_user(target)["friends"]:
                ensure_user(target)["friends"].append(ADMIN_NAME)
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
            room = DATA["groups"].setdefault(target, {"members": [], "messages": []})
            if ADMIN_NAME not in room["members"]:
                room["members"].append(ADMIN_NAME)
        elif action == "group-member":
            member = clean(str(body.get("member", "")))
            room = DATA["groups"].get(target)
            if not room or not member:
                raise ValueError("group and member required")
            ensure_user(member)
            if member not in room["members"]:
                room["members"].append(member)
        elif action == "group-test-send":
            # Let one manager browser impersonate small test accounts in a
            # group so a physical X16 can exercise a busy room.
            username = clean(str(body.get("user", "")))
            text = clean(str(body.get("text", "")), 32)
            room = DATA["groups"].get(target)
            if not room:
                raise ValueError("select an existing group")
            if not username or not text:
                raise ValueError("test username and message required")
            if username == ADMIN_NAME:
                raise ValueError("use the RODDY message box for manager messages")
            ensure_user(username)
            if username not in room["members"]:
                room["members"].append(username)
            room["messages"].append({"from": username, "text": text})
            del room["messages"][:-100]
        else:
            raise ValueError("unknown manager action")
        note_activity("ADMIN", ADMIN_NAME, action.upper())
        return {"ok": True}

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
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
            user = clean(self.query().get("user", ""))
            with LOCK:
                profile = DATA["users"].get(user, {"friends": []})
                groups = [name for name, room in DATA["groups"].items()
                          if user in room["members"]]
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
            user = clean(self.query().get("user", ""))
            with LOCK:
                # Refresh the timer without overwriting an explicit Away or
                # Offline selection made in the browser console.
                state = PRESENCE.get(user, {}).get("state", "online")
                touch_user(user, "WEB", state)
            self.send_json(200, {"ok": True})
            return
        if path == "/api/preview":
            user = clean(self.query().get("user", ""))
            with LOCK:
                profile = DATA["users"].get(user, {"friends": []})
                codes = {"online": "O", "away": "A", "offline": "X"}
                lines = ["OK"]
                lines += [f"F|{name}|{codes[presence_of(name)]}"
                          for name in profile["friends"][:8]]
                lines += [f"G|{name}" for name, room in DATA["groups"].items()
                          if user in room["members"]][:4]
                self.send_json(200, {"lines": lines,
                                     "bytes": len(("\n".join(lines) + "\n").encode())})
            return
        if path == "/api/activity":
            with LOCK:
                self.send_json(200, list(reversed(ACTIVITY)))
            return
        if path == "/api/messages":
            q = self.query()
            with LOCK:
                self.send_json(200, messages_for(clean(q.get("user", "")),
                                                  clean(q.get("kind", ""), 1),
                                                  clean(q.get("target", ""))))
            return
        super().do_GET()

    def do_POST(self) -> None:
        try:
            if not self.rate_allowed():
                self.send_json(429, {"ok": False, "error": "rate limit"})
                return
            body = self.json_body()
            path = urlparse(self.path).path
            if path.startswith("/api/admin/"):
                if not self.require_admin():
                    return
                with LOCK:
                    result = self.handle_admin_post(path.removeprefix("/api/admin/"), body)
                    save_data()
                self.send_json(200, result)
                return
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
        if action == "account":
            ensure_user(user)
            touch_user(user, "WEB")
            note_activity("WEB", user, "ACCOUNT")
            return {"user": user}
        if user not in DATA["users"]:
            raise ValueError("create the account first")

        target = clean(str(values.get("target", "")))
        if action == "friend":
            if not target or target == user:
                raise ValueError("enter a different friend name")
            # An offline friend does not need an active account yet. Create a
            # quiet placeholder so the name persists and direct messages wait.
            ensure_user(target)
            friends = ensure_user(user)["friends"]
            if target not in friends:
                friends.append(target)
            reverse = ensure_user(target)["friends"]
            if user not in reverse:
                reverse.append(user)
        elif action == "friend-delete":
            if target in ensure_user(user)["friends"]:
                ensure_user(user)["friends"].remove(target)
            if user in ensure_user(target)["friends"]:
                ensure_user(target)["friends"].remove(user)
        elif action == "group":
            if not target:
                raise ValueError("group name required")
            room = DATA["groups"].setdefault(target, {"members": [], "messages": []})
            if user not in room["members"]:
                room["members"].append(user)
        elif action == "group-member":
            member = clean(str(values.get("member", "")))
            if target not in DATA["groups"] or member not in ensure_user(user)["friends"]:
                raise ValueError("group or friend not found")
            if member not in DATA["groups"][target]["members"]:
                DATA["groups"][target]["members"].append(member)
        elif action == "group-leave":
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
            text = clean(str(values.get("text", "")), 32)
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
        return user in DATA["groups"].get(target, {}).get("members", [])

    def handle_x16(self, action: str, q: dict[str, str]) -> None:
        try:
            with LOCK:
                user = clean(q.get("user", ""))
                touch_user(user, "X16")
                note_activity("X16", user, action.upper())
                if action == "sync":
                    if user not in DATA["users"]:
                        raise ValueError("NO ACCOUNT")
                    profile = ensure_user(user)
                    state_code = {"online": "O", "away": "A", "offline": "X"}
                    friends = [f"F|{name}|{state_code[presence_of(name)]}"
                               for name in profile["friends"][:8]]
                    groups = [f"G|{name}" for name, room in DATA["groups"].items()
                              if user in room["members"]][:4]
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
                    try:
                        offset = max(0, min(96, int(q.get("offset", "0"))))
                    except ValueError:
                        offset = 0
                    history = messages_for(user, kind, target)
                    # The X16 shows a four-row viewport. Offset advances by one
                    # message so wheel/arrow scrolling feels continuous while
                    # the server retains the complete 100-message history.
                    end = max(0, len(history) - offset)
                    start = max(0, end - 4)
                    batch = history[start:end] if end else []
                    lines = ["DC"] + [f"M|{m['from']}|{m['text']}" for m in batch]
                    self.send_text(lines)
                    return

                values = {"user": user, "target": clean(q.get("target", "")),
                          "kind": clean(q.get("kind", ""), 1),
                          "text": clean(q.get("text", ""), 32),
                          "member": clean(q.get("member", ""))}
                action_map = {"account": "account", "friend": "friend",
                              "group": "group", "groupadd": "group-member",
                              "send": "message"}
                self.mutate(action_map[action], values)
                save_data()
                self.send_text(["OK"])
        except (KeyError, ValueError) as error:
            self.send_text(["ERR", clean(str(error), 32)], 400)


def main() -> None:
    host = "0.0.0.0"
    with LOCK:
        ensure_user(ADMIN_NAME)
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
