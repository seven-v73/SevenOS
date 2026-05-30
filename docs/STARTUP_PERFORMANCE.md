# SevenOS Startup Performance Contract

SevenOS native apps must feel immediate on a normal desktop session.

## Rule

Public surfaces must:

- display from cache, local files or small contracts first;
- refresh live state in the background;
- expose a visible Refresh or Doctor route for full audits;
- avoid blocking startup on `seven state --json`, `seven health`, `seven readiness`, `pacman`, `flatpak`, `virsh` or long service checks.
- version quality caches that feed release gates, so a stale `surfaces` or
  `public-experience` snapshot cannot keep the UI in an old degraded state
  after a theme, profile or surface contract has improved.

## Expected Paths

- Home, Spotlight, Settings, Hub, Store, Launchpad and profile surfaces should open from cached state.
- `seven surfaces` and `seven quality` may cache their aggregate reports, but
  their cache payloads must carry a version and regenerate automatically when
  the contract changes.
- Doctor, readiness, release, package validation and export workflows may run deep checks.
- Deep checks must be explicit user actions or background refreshes.

## Audit

Run:

```bash
./scripts/startup-audit.sh
./scripts/startup-audit.sh --json
```

The audit separates public surfaces, which must stay under strict thresholds, from deep audits, which are measured and reported but should not be used as app startup paths.
