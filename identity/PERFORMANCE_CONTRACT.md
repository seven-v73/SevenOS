# SevenOS Performance UX Contract

SevenOS public surfaces must feel immediate, calm and recoverable. Expensive
work is allowed, but the user must never feel that the interface is frozen or
that a click disappeared.

## Baseline

- visible response within 200 ms for common clicks;
- progress or pulse feedback for long actions;
- background workers for package, file, update and diagnostics work;
- bounded command probes with explicit timeouts;
- calm completion, error and recovery states.

## Public Rules

1. Every dense public surface exposes feedback primitives.
2. Long-running actions run in a worker or process, not in the UI path.
3. Public quality gates use bounded checks.
4. Motion presets include reduced and off modes.
5. Seven Files stays compact and gives click/hover feedback.
6. Sleep-based waits stay short and intentional.

## Gate

```bash
seven performance-gate
seven performance-gate --json
seven performance-gate --gui
```
