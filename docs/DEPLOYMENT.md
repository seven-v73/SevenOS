# SevenOS Deployment Architecture

SevenOS deployment extends the OS into a personal operating cloud.

The goal is not to replace Kubernetes in Phase 1. The goal is to make local
hosting, project detection, containers, monitoring and remote control feel like
native OS features.

## Layer Model

```text
SevenOS
├── seven          system controller
├── sevenpkg       software manager
├── seven-server   local backend and API
├── seven-deploy   project detection and deployment planning
├── seven-vm       virtual machines and Windows Mode
├── Seven Hub      graphical control surface
└── Shield         security and isolation
```

## Phase 1 Scope

- local API bound to `127.0.0.1`
- system monitoring endpoints
- readiness endpoint
- project stack detection
- non-destructive deployment plans
- user service installation
- rootless container tooling through Podman

## Stack Detection

`seven-deploy` detects:

| Stack | Signal |
| --- | --- |
| Node.js | `package.json` |
| Go | `go.mod` |
| Laravel | `composer.json` + `artisan` |
| Flutter Web | `pubspec.yaml` |
| Container | `Dockerfile`, `Containerfile`, compose files |
| Static | fallback |

## Commands

```bash
seven improve deployment
seven improve deployment --apply --yes

seven server status
seven server doctor
seven server install-user-service
seven server start

seven deploy ./my-project
seven deploy detect ./my-project
seven deploy status
```

## API Preview

```text
GET /health
GET /monitor/system
GET /readiness
```

Future guarded endpoints:

```text
POST /system/update
POST /deploy/project
POST /vm/start/windows
GET  /deploy/status
```

## Security Rules

The server is local-only by default. Before remote access, SevenOS must add:

- token or SSH-key authentication
- TLS termination
- per-action authorization
- audit logging
- firewall profile
- sandboxed deployment workers

This keeps the vision ambitious without turning the workstation into an exposed
control plane too early.
