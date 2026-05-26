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

Server runtime and deployment surfaces are scoped to the Forge mini OS. Forge is
the SevenOS development workspace, so use `seven deploy ...`, `/deploy/*` API
endpoints and runtime server actions from Forge. Outside Forge, these surfaces
return `sevenos.profile-gate.v1` with the command to switch.

Informational commands such as `seven server status`, `seven server plan` and
`seven server doctor` remain readable so the user can understand the gate. The
runtime actions `serve`, `install-user-service`, `start`, `stop` and `logs`, plus
all deploy commands, require Forge.

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
seven profile activate forge
seven-terminal forge

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
seven deploy inspect ./my-project
seven deploy inspect ./my-project --json
seven deploy dev ./my-project
seven deploy doctor ./my-project
seven deploy publish ./my-project
seven deploy publish ./my-project --provider cloudflare
seven deploy publish ./my-project --domain app.example.com
seven deploy domain app.example.com --target tunnel
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
seven deploy services
seven deploy panel
seven deploy plan ./my-project
seven deploy plan ./my-project --json
seven deploy detect ./my-project
seven deploy status
seven deploy status --json
```

Seven Server is local-only by default. A non-local bind through
`SEVENOS_SERVER_HOST` is refused unless `SEVENOS_SERVER_EXPOSE_UNSAFE=1` is set.
That escape hatch is intentionally explicit because public auth, TLS and policy
broker flows are not enabled yet.

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
curl http://127.0.0.1:7777/store
curl http://127.0.0.1:7777/box
curl http://127.0.0.1:7777/cloud
curl http://127.0.0.1:7777/flow
curl http://127.0.0.1:7777/cluster
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
curl http://127.0.0.1:7777/deploy/status
curl 'http://127.0.0.1:7777/deploy/inspect?path=/path/to/project'
curl 'http://127.0.0.1:7777/deploy/doctor?path=/path/to/project'
curl http://127.0.0.1:7777/deploy/services
curl http://127.0.0.1:7777/deploy/panel
curl 'http://127.0.0.1:7777/deploy/domain?domain=app.example.com&target=vps&public_ip=203.0.113.10'
curl 'http://127.0.0.1:7777/deploy/dns-check?domain=app.example.com&expected_ip=203.0.113.10'
curl 'http://127.0.0.1:7777/deploy/route-check?subject=app.example.com'
curl 'http://127.0.0.1:7777/deploy/diagnose?subject=app.example.com'
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
GET  /store
GET  /box
GET  /cloud
GET  /flow
GET  /cluster
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
```

`seven deploy status --json` exposes generated deployment plans through the
machine-readable `sevenos.deploy.status.v1` contract for Hub, Server and future
automation.

`seven deploy inspect <project> --json` exposes the project contract
`sevenos.deploy.project.v1`: detected stack, package manager, dev/build/preview
commands, missing tools and plan outputs. Seven Shell and Seven Hub should use
this contract instead of scraping terminal text.

`seven deploy publish <project>` creates a durable snapshot under
`~/.local/share/sevenos/deploy/<project>/current`, starts a user systemd service
on `127.0.0.1`, and records a `sevenos.deploy.service.v1` service contract. With
`--provider cloudflare`, SevenOS also starts a `cloudflared` quick tunnel when
the tool is installed; Cloudflare documents that quick tunnels generate a random
`trycloudflare.com` URL for sharing. With `--domain`, SevenOS records the custom
domain route and keeps the local service durable while DNS/tunnel policy is
configured.

Publish runs a detected build step by default when the project exposes one
(`npm run build`, `pnpm run build`, `go build ./...`, `flutter build web`).
Use `--no-build` when you want to snapshot the current directory exactly as-is.
Published services can be managed with `start`, `stop`, `restart` and `logs`.
Every publish creates a saved version under `versions/` and updates the
`current` symlink, so the local URL stays stable across rebuilds and
`seven deploy rollback <project>` can return to the previous hosted snapshot.
Use `seven deploy remove <project>` to stop the units and delete the local
deploy state.

Domain routing is explicit. `seven deploy domain <domain> --target vps
--public-ip <ip>` tells the user to create A/AAAA records toward the VPS or
public SevenOS host. `seven deploy domain <domain> --target tunnel` explains
that a personal SevenOS machine needs a stable tunnel/CNAME target instead of a
private or changing home IP.
After the user edits DNS, `seven deploy dns-check <domain> --expected-ip <ip>`
or `--expected-cname <host>` confirms whether propagation already matches the
hosting route.
`seven deploy route-check <project-or-domain>` then checks the full path:
SevenOS service metadata, local reachability and public HTTP/HTTPS reachability.
`seven deploy diagnose <project-or-domain>` is the panel-friendly aggregate:
route, DNS, service metadata, saved versions, score and next actions.

## Deployment Philosophy

SevenOS deployment should feel like:

```bash
seven deploy elegantstyle
```

The system detects the stack, builds or packages it, prepares the runtime,
assigns ports, writes logs and exposes monitoring. Phase 1 generates the plan;
later phases can execute it through rootless containers and Caddy.
