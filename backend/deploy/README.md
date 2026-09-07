# Backend deployment

Production currently runs as the unprivileged `deskcmd` user under systemd:

- code: `/opt/deskcommander/backend`
- virtual environment: `/opt/deskcommander/venv`
- database: `/var/lib/deskcommander/deskcommander.sqlite3`
- environment: `/etc/deskcommander/backend.env`
- service: `deskcommander-backend.service`

The HTTP process initially binds only to `127.0.0.1:8080`. The firewall exposes
SSH only. HTTPS and RetroWire ports must remain closed until their respective
authentication layers are configured and tested.

Useful remote checks:

```bash
systemctl status deskcommander-backend
journalctl -u deskcommander-backend -n 100 --no-pager
curl http://127.0.0.1:8080/healthz
```

