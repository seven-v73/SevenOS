# SevenOS System Language And Build Stack

This document defines the stack and system language used to design SevenOS.
It explains which programming languages, contract languages, UI languages and
product vocabulary should be used for each part of the OS.

The rule is:

```text
One OS language.
Several implementation languages.
Clear boundaries between them.
```

SevenOS should be designed with a stable system language before code is added.
That language includes names, states, contracts, commands, schemas, UI copy and
runtime events.

## Language Layers

| Layer | Language | Purpose |
| --- | --- | --- |
| Product language | SevenOS vocabulary, FR/EN public copy | how users understand the OS |
| Contract language | JSON schemas first, Protobuf later where needed | how components communicate |
| Runtime language | Rust | stable services, daemon, events, jobs and orchestration |
| Shell language | TypeScript with AGS, Hyprland config, CSS tokens | shell surfaces and fast UI iteration |
| Native app language | GTK/libadwaita, Python or Rust bindings where appropriate, Tauri only as transition | Hub, Settings, Store, Files and installer surfaces |
| AI language | Python behind SevenAI contracts | models, OCR, analysis, recommendations and summaries |
| Packaging language | PKGBUILD, pacman metadata, archiso profile, component manifests | installable SevenOS releases |
| Compatibility language | Bash only for bootstrap, adapters and release checks | migration path, not OS ownership |
| Design language | Seven Design Engine tokens, profile accents, motion presets | visual and interaction coherence |

## Programming Language Boundaries

### Rust

Rust is the system language for SevenOS runtime behavior.

Use Rust for:

- `seven-daemon`
- SevenBus event and state handling
- job orchestration
- session/profile runtime
- health snapshots
- package API boundary helpers
- permission and confirmation services
- local IPC and typed service contracts

Rust should own behavior that is long-running, stateful, security-sensitive or
performance-sensitive.

### TypeScript

TypeScript is the shell and product UI iteration language.

Use TypeScript for:

- AGS shell panels
- dock and launcher components
- quick settings
- notification surfaces
- frontend state models
- transitional Tauri app UI

TypeScript should consume SevenOS contracts. It should not become the source of
truth for system state.

### Python

Python is the AI and analysis language.

Use Python for:

- SevenAI model adapters
- OCR and document analysis
- recommendations
- diagnostics explanation
- research and knowledge tools
- data processing prototypes

Python should not own session startup, permissions, security enforcement or
boot-critical logic.

### Bash

Bash is a compatibility and bootstrap language.

Use Bash for:

- install/bootstrap adapters
- release checks
- one-shot migration helpers
- calling existing Linux commands during transition
- simple developer diagnostics

Bash must not permanently own OS state, profile lifecycle, identity,
permissions, package policy or shell behavior.

### C

C is only for low-level, tiny and audited boundaries.

Use C for:

- hardware-adjacent probes
- ABI-sensitive helpers
- ultra-small IPC capability checks
- future audited low-level hooks

C must not own product logic, Hub logic, Shell logic or profile orchestration.

## Contract Language

SevenOS components should communicate through explicit contracts.

Preferred order:

1. JSON for public contracts and fast iteration.
2. JSON Schema for validation.
3. SQLite for local durable state.
4. JSONL for append-only event journals.
5. Protobuf/gRPC when service boundaries need stronger typing.

Every machine contract should include:

- `schema`
- `state`
- `score` or readiness when useful
- `summary`
- `checks`
- `issues`
- `next`
- `commands`
- `writer`

Human text and machine state must be separate fields. A UI should never parse
sentences to understand the OS.

## State Language

Use a small, consistent state vocabulary:

| State | Meaning |
| --- | --- |
| `OK` | ready and verified |
| `PART` | usable but needs attention |
| `FAIL` | blocked or broken |
| `MISS` | required file, service or dependency missing |
| `RUN` | active and running |
| `READY` | prepared but not currently running |
| `WARN` | non-blocking warning |
| `UNKNOWN` | no reliable signal yet |

Public UI can translate these states into friendlier labels, but contracts
should stay consistent.

## Workflow Language

Every SevenOS workflow should use this grammar:

```text
intent
  -> impact
  -> readiness
  -> plan
  -> preview
  -> confirmation when needed
  -> job
  -> progress
  -> result
  -> recovery or next action
```

This grammar applies to updates, repairs, Mini OS switching, app installation,
backup, language/theme changes, permissions and installer flows.

## Command Language

SevenOS commands should read like product routes:

```bash
seven <area> <action> [--json]
seven <area> doctor
seven <area> plan
seven <area> apply --yes
seven <area> open
```

Examples:

```bash
seven health doctor
seven shell status --json
seven profile plan --json
seven installer release
seven update install --yes
seven identity design --json
```

Rules:

- `status` reports state.
- `doctor` verifies and explains.
- `plan` proposes actions.
- `apply` changes state.
- `open` launches a native surface.
- `--json` must output strict machine-readable JSON only.

## UI Language

SevenOS surfaces should use calm, direct language:

- name the user intent
- explain impact before changes
- show progress while work runs
- use details drawers for logs
- show recovery when a failure occurs
- avoid raw backend names unless the user opens details
- keep FR/EN copy available for public controls

Use:

- Mini OS
- Seven Core
- SevenBus
- Seven Hub
- Seven Shell
- Seven Store
- SevenAI
- Shield
- Atlas
- Baobab

Avoid:

- presenting SevenOS as only Arch plus scripts
- exposing backend package managers as the product identity
- vague automation language
- calling Atlas Nexus
- terminal-first instructions for normal public workflows

## Design Language

The visual language is token-driven:

- Seven Design Engine for modes
- `identity/tokens.css` and `identity/tokens-light.css` for color and spacing
- profile accents for Mini OS identity
- named motion presets for transitions
- semantic status colors
- reusable components for status, jobs, confirmation and details

Design language must connect to backend state. A status card, progress bar or
warning surface should represent a real contract, not decoration.

## Backend Logic Language

SevenOS backend logic should use action, job and event vocabulary:

```text
Action
  preview
  permission
  execute
  job
  event
  result
```

Actions are registered. Jobs are tracked. Events are written. Results are
verified. This gives the UI fluid state without script chains.

## Package And Release Language

SevenOS should describe shippable pieces as components:

- `sevenos-core`
- `sevenos-cli`
- `sevenos-shell`
- `sevenos-hub`
- `sevenos-apps`
- `sevenos-profiles`
- `sevenos-identity`
- `sevenos-installer`
- `sevenos-security`
- `sevenos-ai`

These names should guide packaging, tests, release notes and future pacman
package boundaries.

## Decision Rules

When choosing a language or stack for a new feature:

1. If it owns system state, use Rust and a contract.
2. If it owns public shell UI, use AGS/TypeScript consuming contracts.
3. If it owns OS control UI, prefer native GTK/libadwaita consuming contracts.
4. If it owns AI analysis, use Python behind SevenAI contracts.
5. If it only bootstraps or adapts, Bash is acceptable.
6. If it needs privilege, use Polkit or an audited helper.
7. If another component reads it, define a schema.
8. If a normal user sees it, define FR/EN copy and design states.

This gives SevenOS a coherent construction language: stable enough for an OS,
flexible enough to evolve, and clear enough that every new feature knows where
it belongs.
