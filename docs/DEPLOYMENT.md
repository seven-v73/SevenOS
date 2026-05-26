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
- project inspect contracts for Hub and Shell
- non-destructive deployment plans
- natural local development loop suggestions
- durable build snapshots under the user deploy state
- user systemd services that survive reboot
- optional generated public tunnel when `cloudflared` is available
- custom-domain route contracts
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
seven profile activate forge
seven-terminal forge

seven improve deployment
seven improve deployment --apply --yes

seven server status
seven server doctor
seven server install-user-service
seven server start

seven deploy ./my-project
seven deploy inspect ./my-project --json
seven deploy dev ./my-project
seven deploy doctor ./my-project
seven deploy publish ./my-project
seven deploy publish ./my-project --provider cloudflare
seven deploy publish ./my-project --domain app.example.com
seven deploy domain app.example.com --target tunnel
seven deploy domain app.example.com --target tunnel --tunnel-hostname <tunnel-id>.cfargotunnel.com
seven deploy domain app.example.com --target vps --public-ip 203.0.113.10
seven deploy dns-check app.example.com --expected-ip 203.0.113.10
seven deploy dns-check app.example.com --expected-cname <tunnel-id>.cfargotunnel.com
seven deploy route-check app.example.com
seven deploy route-check my-project
seven deploy diagnose app.example.com
seven deploy diagnose my-project
seven deploy publish ./my-project --no-build
seven deploy start my-project
seven deploy stop my-project
seven deploy restart my-project
seven deploy logs my-project
seven deploy versions my-project
seven deploy rollback my-project
seven deploy remove my-project
seven deploy services --json
seven deploy panel --json
seven deploy plan ./my-project --json
seven deploy detect ./my-project
seven deploy status
seven deploy status --json
```

SevenOS deployment is scoped to the Forge mini OS. Run deployment and hosting
commands from Forge, or open a Forge terminal first:

```bash
seven profile activate forge
seven-terminal forge
```

Outside Forge, `seven deploy ...` and `/deploy/*` API endpoints return
`sevenos.profile-gate.v1` with the required profile and the next action.
`seven server status`, `seven server plan` and `seven server doctor` stay
readable for diagnostics; server runtime actions and all deploy actions require
Forge.

## API Preview

```text
GET /health
GET /monitor/system
GET /readiness
GET /deploy/status
GET /deploy/inspect?path=/path/to/project
GET /deploy/doctor?path=/path/to/project
GET /deploy/services
GET /deploy/panel
GET /deploy/domain?domain=app.example.com&target=vps&public_ip=203.0.113.10
GET /deploy/domain?domain=app.example.com&target=tunnel&tunnel_hostname=<tunnel-id>.cfargotunnel.com
GET /deploy/dns-check?domain=app.example.com&expected_ip=203.0.113.10
GET /deploy/route-check?subject=app.example.com
GET /deploy/diagnose?subject=app.example.com
```

`publish` keeps a versioned snapshot history under
`~/.local/share/sevenos/deploy/<project>/versions`. Republishing the same app
keeps the same local port when possible, updates `current`, and lets you return
to the previous build with `seven deploy rollback <project>`.

## Domain and VPS Routing

When a domain is attached to a normal VPS, the DNS record points to the public
IP of the VPS:

```text
A     app.example.com     203.0.113.10
AAAA  app.example.com     2001:db8::10
```

SevenOS exposes that as a machine-readable plan:

```bash
seven deploy domain app.example.com --target vps --public-ip 203.0.113.10 --json
```

For a personal SevenOS machine without a fixed public IP, the domain should not
point to the local/private address. Use a stable tunnel instead:

```bash
seven deploy domain app.example.com --target tunnel --tunnel-hostname <tunnel-id>.cfargotunnel.com --json
```

Quick `trycloudflare.com` URLs are useful for previews. Purchased domains should
use a stable named tunnel/CNAME target or a VPS/public-IP route.

After editing DNS, SevenOS can check propagation:

```bash
seven deploy dns-check app.example.com --expected-ip 203.0.113.10 --json
seven deploy dns-check app.example.com --expected-cname <tunnel-id>.cfargotunnel.com --json
```

The check returns `sevenos.deploy.dns-check.v1` with discovered A, AAAA and
CNAME records plus the next action if the DNS is still mismatched.

When DNS looks correct, SevenOS can test the whole route:

```bash
seven deploy route-check app.example.com --json
seven deploy route-check my-project --json
```

The route contract `sevenos.deploy.route-check.v1` reports DNS records, local
service reachability and public HTTP/HTTPS reachability.

For a one-command hosting view, use:

```bash
seven deploy diagnose app.example.com --json
seven deploy diagnose my-project --json
```

The diagnosis contract `sevenos.deploy.diagnose.v1` combines route, DNS, local
service metadata, saved versions and next actions for Seven Shell or a hosting
panel.

Future guarded endpoints:

```text
POST /system/update
POST /deploy/project
POST /vm/start/windows
```

## Security Rules

The server is local-only by default. Before remote access, SevenOS must add:

- token or SSH-key authentication
- TLS termination
- per-action authorization
- audit logging
- firewall profile
- sandboxed deployment workers

Generated public URLs require a tunnel provider. SevenOS supports a natural
Cloudflare Quick Tunnel path when `cloudflared` is installed; custom domains are
recorded as explicit hosting routes and should be attached through DNS/tunnel
policy before being treated as production.

This keeps the vision ambitious without turning the workstation into an exposed
control plane too early.
