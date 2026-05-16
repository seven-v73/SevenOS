# SevenOS CyberSpace

CyberSpace is the cybersecurity experience layer of SevenOS. It is not meant to
be a collection of tools. It is a context-aware workspace that changes how the
system behaves when the user enters Shield mode.

## Product Goal

When CyberSpace is active, SevenOS should feel like an OS inside the OS:

- the active profile becomes Shield;
- the shell exposes cybersecurity actions first;
- Hyprland workspaces map to cyber workflows;
- audit scope is visible before any scan;
- labs, reports, captures and evidence are grouped in one workspace;
- dashboards show posture, tools, contexts and next actions.

The long-term daemon for this layer is `seven-cyberd`. Until that daemon exists,
`security/cyberspace.sh` provides the B3 contract and safe user-facing commands.

## Runtime Contract

```text
seven shield mode --json
  -> sevenos.cyberspace.v1
  -> seven-daemon cyberspace --json
  -> contexts, active context, scope state, workspace map

seven shield context recon
  -> writes .sevenos/cyberspace-context.json
  -> moves to the mapped Hyprland workspace when Hyprland is available

seven-daemon cyberspace-plan --json
  -> sevenos.cyberspace-plan.v1
  -> missing scope, workspace, context and sandbox actions

seven shield hud
  -> active context, scope state, reports and sandbox hint
```

## Workspace Map

| Workspace | Context | Purpose |
|-----------|---------|---------|
| 1 | Recon | OSINT, discovery, authorized surface mapping |
| 2 | Web Pentest | Browser, proxy, web testing |
| 3 | Reverse Engineering | Offline binary triage |
| 4 | Network | Packet inspection and network visibility |
| 5 | Forensics | Evidence-safe offline analysis |
| 6 | Exploitation | Controlled authorized exploitation workflow |
| 7 | Threat Intel | Indicators, references and notes |
| 8 | Logs & Monitoring | System logs, posture events and services |
| 9 | Sandbox | Unknown workloads and disposable tests |

## Safety Model

CyberSpace follows four rules:

1. Context before tool.
2. Scope before scan.
3. Isolation before unknown workloads.
4. Report before closure.

`seven shield scope` is the gatekeeper for authorized targets. Network launchers
must refuse targets that are not active in the scope file.

## Hyprland Integration

SevenOS exposes:

- `Super+C` -> `seven shield mode`
- `Super+Ctrl+C` -> `seven shield hud`
- workspaces `1` to `9` for the CyberSpace map

These bindings should stay lightweight. CyberSpace may move workspaces, but it
must not launch intrusive tooling automatically.

## Future `seven-cyberd`

`seven-cyberd` will eventually own:

- continuous cyber context detection;
- safe workflow sessions;
- VPN/Tor/IDS status feeds;
- sandbox lifecycle;
- notification rules;
- Seven Hub Security Center backend data;
- optional AI analysis hooks.

For now, the important contract is stable, inspectable JSON. Seven Hub and Seven
Shell should consume the contract, not scrape human terminal output.

## Seven Server Endpoints

When Seven Server is running, CyberSpace is exposed locally through:

```bash
curl http://127.0.0.1:7777/cyberspace
curl http://127.0.0.1:7777/cyberspace-plan
```

The API is local-only. Remote exposure must wait for authentication, audit
policy and TLS.
