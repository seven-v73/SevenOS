# SevenOS Server Layer

SevenOS Server is the first foundation for turning a SevenOS machine into a
personal operating cloud: workstation, development environment, deployment node
and private service host.

Phase 1 is intentionally local-first and non-destructive.

## Components

- `seven-server`: local system backend and monitoring API
- `seven-deploy`: project detector and deployment plan generator
- `seven server`: controller entrypoint
- `seven deploy`: deployment entrypoint

## Security Model

The server binds to `127.0.0.1` by default.

Do not expose it on a LAN or the Internet until authentication, TLS and
authorization policies are enabled. Future phases should add:

- token auth
- Unix socket mode
- SSH key delegation
- per-action permissions
- audit logging
- optional reverse proxy through Caddy

## Commands

```bash
seven server status
seven server doctor
seven server serve
seven server install-user-service
seven server start
seven server stop

seven deploy ./my-project
seven deploy plan ./my-project
seven deploy detect ./my-project
seven deploy status
```

## API Preview

When running locally:

```bash
curl http://127.0.0.1:7777/health
curl http://127.0.0.1:7777/state
curl http://127.0.0.1:7777/status
curl http://127.0.0.1:7777/profiles
curl http://127.0.0.1:7777/monitor/system
curl http://127.0.0.1:7777/readiness
curl http://127.0.0.1:7777/manifest
curl http://127.0.0.1:7777/actions
```

Planned future endpoints:

```text
POST /system/update
POST /vm/start/windows
POST /deploy/project
GET  /state
GET  /profiles
GET  /manifest
GET  /actions
GET  /monitor/system
GET  /deploy/status
```

## Deployment Philosophy

SevenOS deployment should feel like:

```bash
seven deploy elegantstyle
```

The system detects the stack, builds or packages it, prepares the runtime,
assigns ports, writes logs and exposes monitoring. Phase 1 generates the plan;
later phases can execute it through rootless containers and Caddy.
