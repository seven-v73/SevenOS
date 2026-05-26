# Seven Shell

Seven Shell is the B3 desktop shell direction for SevenOS.

It does not replace the current Waybar/Rofi/GTK fallback yet. It prepares a
controlled AGS + TypeScript layer for:

- Quick Settings
- Notification Center
- launcher / overview
- dock
- profile-aware widgets

The rule is simple:

```text
Seven Shell replaces visible friction gradually. It does not rewrite the whole
desktop before the contracts are stable.
```

## Commands

```bash
seven shell
seven shell status --json
seven shell plan
seven shell plan --json
seven shell doctor
seven shell preview
scripts/shell-ags-runtime.sh status --json
./install.sh shell-ags-runtime --yes
```

## Data Sources

Seven Shell consumes JSON contracts only:

- `seven state --json`
- `seven actions --json`
- `seven core snapshot --json`
- `seven core health --json`
- `seven profile current --json`
- `seven shell status --json`
- `seven deploy inspect . --json`
- `seven deploy status --json`
- `seven deploy services --json`
- `seven deploy panel --json`
- `seven deploy versions <project> --json`
- `seven deploy domain <domain> --target tunnel|vps --json`
- `seven deploy dns-check <domain> --expected-ip|--expected-cname ... --json`
- `seven deploy route-check <project-or-domain> --json`
- `seven deploy diagnose <project-or-domain> --json`

Human terminal output is not an API.

`seven core snapshot --json` is the daemon-native SevenBus reader. Shell
surfaces use it to understand recent system activity without parsing human
logs or walking the event journal directly.

`seven core health --json` is the daemon-native runtime health reader. Shell
surfaces use it for session, memory, load and SevenBus integrity signals
instead of spawning many separate Bash probes.

Seven Shell should treat `seven core status --json` state `RUNTIME_READY` as
the normal local runtime state. The SevenBus transport is still a local JSONL
journal for now; maintenance is exposed through
`seven core compact-bus --keep 5000 --json` until typed local IPC lands.

AGS runtime is explicit. The correct AUR package is `aylurs-gtk-shell`; the AUR
package named `ags` is Adventure Game Studio and must not be used for Seven
Shell. Use `scripts/shell-ags-runtime.sh status --json` to inspect the route,
then `./install.sh shell-ags-runtime --yes` when the AUR route is accepted.

For development surfaces, Seven Shell should consume
`seven deploy inspect <project> --json`. That contract gives the shell the
detected stack, missing tools, natural dev loop, build commands and local Server
endpoints without parsing terminal output.

Deployment and hosting are Forge-only surfaces. If Shell calls `seven deploy`
or `/deploy/*` while the active mini OS is not Forge, it should display the
`sevenos.profile-gate.v1` response and offer `seven profile activate forge` or
`seven-terminal forge`.

For hosting surfaces, Seven Shell should consume `seven deploy panel --json`.
That contract lists durable hosted snapshots, local URLs, generated public URLs
when available, custom-domain routes and the management commands for publish or
unpublish. Version management is exposed through
`seven deploy versions <project> --json` and rollback/remove commands so a Shell
panel can offer publish history without reading deploy directories directly.
Domain setup should use `seven deploy domain <domain> --target ... --json` so
the Shell can show the exact DNS record for VPS/public-IP hosting, or the stable
tunnel/CNAME requirement for a personal SevenOS machine without fixed public IP.
DNS verification should use `seven deploy dns-check <domain> --json` so the
panel can show whether A/AAAA/CNAME propagation matches the expected route.
End-to-end hosting health should use `seven deploy route-check
<project-or-domain> --json`; it reports service metadata, local reachability and
public HTTP/HTTPS reachability in one contract.
The top-level hosting surface can use `seven deploy diagnose
<project-or-domain> --json` to show one score, route state, DNS state, saved
versions and concrete next actions.

When Seven Server is running, Shell should prefer the local API equivalents for
hosting panels:

- `/deploy/domain?domain=app.example.com&target=vps&public_ip=203.0.113.10`
- `/deploy/dns-check?domain=app.example.com&expected_ip=203.0.113.10`
- `/deploy/route-check?subject=app.example.com`
- `/deploy/diagnose?subject=app.example.com`
