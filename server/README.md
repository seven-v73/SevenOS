# SevenOS Server Layer

SevenOS Server is the first foundation for turning a SevenOS machine into a
personal operating cloud: workstation, development environment, deployment node
and private service host.

Phase 1 is intentionally local-first and non-destructive.

## Components

- `seven-server`: local system backend and monitoring API
- `seven-deploy`: project detector and deployment plan generator
- `seven-core`: system experience layer and SevenBus contract provider
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
seven server status --json
seven server plan
seven server plan --json
seven server doctor
seven server serve
seven server install-user-service
seven server start
seven server stop

seven b3 status
seven b3 plan
seven b3 plan --json
seven b3 plan --phase backend
seven b3 doctor

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
curl http://127.0.0.1:7777/welcome
curl http://127.0.0.1:7777/welcome-plan
curl http://127.0.0.1:7777/session
curl http://127.0.0.1:7777/identity
curl http://127.0.0.1:7777/profiles
curl http://127.0.0.1:7777/profile-gaps
curl http://127.0.0.1:7777/profile-plan
curl http://127.0.0.1:7777/windows
curl http://127.0.0.1:7777/windows-plan
curl http://127.0.0.1:7777/installer
curl http://127.0.0.1:7777/installer-plan
curl http://127.0.0.1:7777/packages
curl http://127.0.0.1:7777/packages-plan
curl http://127.0.0.1:7777/monitor/system
curl http://127.0.0.1:7777/readiness
curl http://127.0.0.1:7777/manifest
curl http://127.0.0.1:7777/actions
curl http://127.0.0.1:7777/stack
curl http://127.0.0.1:7777/shell
curl http://127.0.0.1:7777/shell-plan
curl http://127.0.0.1:7777/core
curl http://127.0.0.1:7777/core-plan
curl http://127.0.0.1:7777/core-snapshot
curl http://127.0.0.1:7777/core-health
curl http://127.0.0.1:7777/scheduler
curl http://127.0.0.1:7777/context
curl http://127.0.0.1:7777/bus
curl http://127.0.0.1:7777/experience
curl http://127.0.0.1:7777/shield
curl http://127.0.0.1:7777/shield-plan
curl http://127.0.0.1:7777/cyberspace
curl http://127.0.0.1:7777/cyberspace-plan
curl http://127.0.0.1:7777/server-plan
curl http://127.0.0.1:7777/control
curl http://127.0.0.1:7777/b3
curl http://127.0.0.1:7777/daily
curl http://127.0.0.1:7777/events
curl http://127.0.0.1:7777/insights
```

Planned future endpoints:

```text
POST /system/update
POST /vm/start/windows
POST /deploy/project
GET  /state
GET  /profiles
GET  /profile-gaps
GET  /profile-plan
GET  /windows
GET  /windows-plan
GET  /installer
GET  /installer-plan
GET  /packages
GET  /packages-plan
GET  /manifest
GET  /actions
GET  /core
GET  /core-plan
GET  /core-snapshot
GET  /core-health
GET  /scheduler
GET  /context
GET  /bus
GET  /experience
GET  /shield
GET  /shield-plan
GET  /cyberspace
GET  /cyberspace-plan
GET  /server-plan
GET  /control
GET  /b3
GET  /daily
GET  /events
GET  /insights
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
