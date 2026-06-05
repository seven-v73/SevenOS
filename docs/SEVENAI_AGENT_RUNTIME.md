# SevenAI Agent Runtime

SevenAI is not only a chatbot. In SevenOS it is a local-first system manager
that observes, explains, previews and records actions before anything sensitive
is applied.

## Contract

- `seven ai runtime --json` exposes the runtime state.
- `seven ai agents --json` exposes the seven OS agents.
- `seven ai permissions --json` exposes the permission graph.
- `seven ai ledger --json` exposes the local action ledger.
- `seven ai learning --json` exposes local learning state.
- `seven ai learning enable --json` enables learning from approved local
  sources.
- `seven ai learning scan --json` indexes approved folders with metadata only.
- `seven ai learning scan --content --json` also stores short snippets from
  small text files.
- `seven ai habits --json` summarizes local interaction habits.
- `seven ai proactive --json` exposes local-only proactive cards from approved
  files, local habits and the active Mini OS.
- `seven ai operate "<request>" --json` remains the preview path for natural
  language requests.

## Application Control

SevenAI can open installed applications from natural language without requiring
root confirmation:

- `seven ai open firefox`
- `seven ai "ouvre les paramètres"`
- `seven ai "ouvre le lecteur PDF"`
- `seven ai "ouvre la boutique"`

`seven ai open` without an app name still opens the SevenAI interface. With an
app name, it is routed through the local agent, resolves aliases and tries the
SevenOS profile launcher first, then desktop launchers and Hyprland fallbacks.
If no app is found, the agent returns suggestions instead of failing silently.

## Principles

1. Equinox stays the system steward. It coordinates health, settings, updates,
   rescue and profile state.
2. Mini OS agents stay domain-specific: Forge, Shield, Studio, Pulse, Atlas and
   Baobab do not silently change the host.
3. Cloud and web are disabled by default. They require explicit user intent.
4. Sensitive actions require confirmation: package changes, services, network,
   file deletion, profile switches, security changes and cloud model calls.
5. Every applied action should write to the SevenAI ledger.
6. Personal learning is local, opt-in and source-based. SevenAI does not index
   arbitrary home data unless the user enables learning and approves sources.
7. Proactive suggestions are previews. They surface commands and context, but
   they do not execute system-changing actions automatically.

## Runtime Files

- Agent registry: `ai/agents.json`
- Local ledger: `$XDG_STATE_HOME/sevenos/ai/ledger.jsonl`
- Local learning index: `$XDG_STATE_HOME/sevenos/ai-learning.sqlite3`
- Learning config: `$XDG_CONFIG_HOME/sevenos/ai-learning.json`
- CLI runtime: `scripts/seven_ai_runtime.py`
- CLI learning layer: `scripts/seven_ai_learning.py`

This keeps the new agentic layer independent from UI surfaces. Settings,
Doctor, Store, Installer, Files and Terminal can consume the same contracts
instead of each app inventing its own AI state.
