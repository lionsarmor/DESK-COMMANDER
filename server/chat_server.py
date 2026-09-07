#!/usr/bin/env python3
"""DESK COMMANDER local alpha chat server.

Run this on a computer on the same Wi-Fi/LAN as the Commander X16. It serves
the browser dashboard and a deliberately tiny text protocol for ZiModem.
Only Python's standard library is required.
"""

from __future__ import annotations

import json
import os
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
PRESENCE: dict[str, dict] = {}
ACTIVITY: list[dict] = []


def detect_lan_ip() -> str:
    """Find the physical LAN address the X16 can use.

    A VPN or Docker address is often the computer's default route, so do not
    simply report that route. Prefer Wi-Fi, then another normal LAN adapter.
    """
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
        self.end_headers()
        self.wfile.write(body)

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
        return json.loads(self.rfile.read(length) or b"{}")

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_GET(self) -> None:
        path = urlparse(self.path).path
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
            body = self.json_body()
            with LOCK:
                result = self.mutate(urlparse(self.path).path.removeprefix("/api/"), body)
                save_data()
            self.send_json(200, {"ok": True, **result})
        except (KeyError, ValueError) as error:
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
                    lines = ["OK"] + friends + groups
                    self.send_text(lines)
                    return
                if action == "messages":
                    kind, target = clean(q.get("kind", ""), 1), clean(q.get("target", ""))
                    lines = ["OK"] + [f"M|{m['from']}|{m['text']}"
                                      for m in messages_for(user, kind, target)[-4:]]
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
    server = ThreadingHTTPServer((host, CHAT_PORT), Handler)
    print(f"DESK COMMANDER chat server: http://localhost:{CHAT_PORT}")
    print("Open that address in a browser; enter this computer's LAN IP on the X16.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping chat server.")


if __name__ == "__main__":
    main()
