# Desk Commander Backend

This is the public-service successor to the LAN-only `server/chat_server.py`.
It is a modular Python application shared by the Commander X16, ZX Spectrum
Next, Commodore 64 Ultimate, and the browser maintenance console.

The first deployed milestone deliberately binds to `127.0.0.1`. Do not expose
the retro TCP transport until device authentication, replay protection, and
authenticated encryption pass their hardware tests.

## Modules

- `identity` — users, devices, activation, authentication, and presence
- `chat` — friends, groups, direct messages, and offline delivery
- `mail` — internal Desk Mail first; external providers come later
- `games` — invitations, lobbies, turns, and shared game state
- `protocol` — the small platform-neutral RetroWire transport

## Local development

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8080
```

Then open `http://127.0.0.1:8080/healthz`.

