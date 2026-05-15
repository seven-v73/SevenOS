# SevenOS Stack Strategy

SevenOS must not become a pile of unrelated technologies. The stack grows by
phase, with one major new runtime introduced only when the previous layer is
testable through JSON contracts, checks and Seven Hub.

This strategy supports `docs/SYSTEM_EXPERIENCE_LAYER.md`, the main reference
for SevenOS as a system experience layer above Linux and Arch.

## Principle

```text
Contracts first. Native surfaces second. New runtimes only when they replace
real friction.
```

## Phase Order

| Phase | Focus | Stack |
| --- | --- | --- |
| B2-B3 | JSON contracts, Hub Native, Seven Server preparation | Bash, Python, GTK4/libadwaita |
| B3 | Seven Shell and long-running system core | AGS + TypeScript, Rust |
| Phase 4 | Intelligence and product apps | Python AI, Flutter/Qt/GTK apps |
| Phase 5 | Store, Cloud, Sync and extensions | Rust, Python, Flutter/Qt, package registry |

## Current Rule

SevenOS keeps the existing Bash/Python scripts while they are useful. The work
now is not to rewrite everything; it is to make every command expose stable JSON
so native interfaces can control the system without parsing terminal text.

## Next Technical Move

The next major UI move is:

```text
Seven Shell with AGS + TypeScript
```

Seven Shell should replace the most visible Rofi surfaces gradually:

- Quick Settings
- Notification Center
- Dock / pinned apps
- Launcher / overview
- profile-aware widgets

Rofi remains a fallback, not the main OS control plane.

## Rust Boundary

Rust enters after the shell contracts are stable, as:

- `seven-daemon`
- event and IPC broker
- session/profile orchestrator
- performance and trust monitor

Rust should not be introduced as a rewrite impulse. It enters where SevenOS
needs a reliable long-running process.

## Python Boundary

Python is the AI and analysis layer:

- SevenAI
- error explanation
- system recommendations
- local model integration
- OCR / vision experiments

Python should not own boot-critical session control or security enforcement.

## App Boundary

Flutter, Qt and GTK are for product applications:

- Seven Store
- Seven Cloud
- Seven Notes
- Seven Settings
- Seven Media

Do not build multiple versions of the same app in different stacks at the same
time. Pick one per product.

## Machine Contract

Use:

```bash
seven stack
seven stack --json
seven stack doctor
```

The JSON contract is `sevenos.stack.v1`. Seven Hub and Seven Server should use
it to show which stacks are active, next, planned or blocked.

## Seven Shell Contract

Use:

```bash
seven shell
seven shell status --json
seven shell plan --json
seven shell preview
seven shell doctor
```

The JSON contracts are:

- `sevenos.shell.v1`
- `sevenos.shell-plan.v1`

These contracts let Seven Hub and Seven Server prepare the AGS shell without
removing the stable Waybar/Rofi/GTK fallback.
