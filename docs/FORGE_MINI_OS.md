# Forge Mini OS

Forge is the SevenOS development workspace. Its role is to keep developer tools,
project services and deployment workflows inside the Forge profile instead of
polluting Equinox.

## Contract

- Equinox stays the stable host.
- Forge owns development runtimes, containers, databases and deployment tools.
- `seven forge` is the project-centered entry point.
- `seven deploy` remains the lower-level deployment engine and must stay gated
  to Forge.
- SevenPkg routes developer applications to Forge by natural domain.

## User Routes

```bash
seven forge
seven forge open
seven forge project .
seven forge readiness .
seven forge tasks .
seven forge services
seven forge ports
seven forge extensions
seven forge ai .
seven forge catalog
seven forge remember .
seven forge config
seven forge config import --apply
seven deploy inspect .
seven profile activate forge
```

## Project Center

`seven forge` returns a single contract for:

- active profile and rootfs readiness;
- current project stack and natural commands;
- Docker, PostgreSQL, Valkey and Caddy state;
- Forge comfort tools;
- project readiness score, missing tools and service hints;
- Forge app catalog;
- recent project memory;
- safe next actions.

This is the preferred surface for Settings, Spotlight, SevenAI and future Forge
UI panels.

## Native Project Center

`seven forge open` launches the native Forge Project Center. It is intentionally
project-first:

- the current stack and natural commands are visible first;
- project tasks are detected from `package.json`, `Cargo.toml`, `go.mod`,
  `pyproject.toml`, `pubspec.yaml`, compose files and Makefiles;
- Docker, PostgreSQL, Valkey and Caddy are shown as project services;
- local listening ports are visible without opening a terminal;
- editor setup shows imported settings and extension manifests;
- readiness shows missing tools, relevant services, Git state and safe actions;
- SevenAI prompts explain the project, build failures, ports and important
  files.

The graphical center reads the same `seven forge --json` contract as CLI and AI
surfaces. There should not be a separate GUI-only truth.

## Developer Config Bridge

Forge can import the useful development configuration that already exists in
Equinox without breaking profile isolation:

```bash
seven forge config
seven forge config import --apply
```

The bridge copies only safe editor preferences into the Forge profile home:

- VS Code / Code OSS `settings.json`;
- `keybindings.json`;
- `locale.json`;
- user snippets;
- an extension manifest and install list.

It deliberately does not copy `globalStorage`, `workspaceStorage`, history,
caches, tokens or secrets. Extensions are recorded as a manifest first instead
of duplicating gigabytes of extension folders by default. This keeps Forge
familiar for the developer while preserving Equinox as the stable host.

## Services

Forge treats services as project resources, not global user defaults:

- Docker for containers;
- PostgreSQL for relational data;
- Valkey for cache/queue use;
- Caddy for local hosting and reverse proxy.

Services should be started deliberately from Forge workflows and shown with
clear state, not silently enabled for every SevenOS user.

## Project Memory And AI

`seven forge remember <path>` stores a compact project memory entry with stack,
commands, tools, missing dependencies and Git state. SevenAI uses the same
project contract through:

```bash
seven forge tasks .
seven forge ai .
```

Task detection reads environment files as keys only. Secret values are never
placed in the Forge contract. The AI route does not run project commands
automatically. It prepares prompts for explanations and keeps system changes
behind the normal SevenOS preview/confirmation policy.

## Project Readiness

`seven forge readiness <path>` is the project preflight contract. It combines
project detection, required tools, service hints, Git state, editor setup and
environment-file policy into one score.

The route is intentionally preview-only:

- it never starts Docker, PostgreSQL, Valkey or Caddy by itself;
- it never installs packages without an explicit user action;
- `.env` files are inspected as key names only, never as secret values;
- Git changes are shown as a publishing/deployment signal, not as an error.

This makes Forge feel proactive without becoming reckless. Settings, Spotlight,
SevenAI and the native Project Center should reuse this contract instead of
inventing separate project checks.

## Catalog Scope

Forge owns:

- editors and Git tools;
- Python, Node.js, Rust, Go and Java;
- Flutter and Android command-line tooling;
- Docker and Podman;
- PostgreSQL, Valkey and Caddy;
- API testing, Kubernetes, Terraform, GitHub CLI and database tools.

SevenPkg may expose these through `seven install <tool>`, but the routing should
continue to resolve to Forge unless the app is explicitly system-level.

## Next Steps

- Add deeper log streaming for active project services.
- Add per-project error history for repeated build/test failures.
