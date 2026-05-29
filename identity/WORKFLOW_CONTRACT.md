# SevenOS Workflow Contract

SevenOS workflows turn system commands into public, understandable journeys.
They are the bridge between powerful tools and a calm OS experience.

## Public Workflow Shape

Every public workflow should expose:

1. **Intent**: what the user wants to achieve.
2. **Impact**: what SevenOS will change.
3. **Preparation**: checks, backup or readiness state.
4. **Progress**: visible steps while work is running.
5. **Result**: success, warning or failure in human language.
6. **Details**: logs or commands on demand.
7. **Recovery**: rollback, retry or repair when relevant.

## Required Workflows

- Update: check, backup, install, refresh surfaces, rollback.
- Repair: detect, explain, apply only needed repairs, verify.
- Mini OS switch: prepare, Prism passage, apply profile, wait until ready.
- Backup: scope, destination, create, verify, restore plan.
- Permissions: show access, explain risk, open controls, record changes.
- Install apps: source, size/impact, progress, final state, uninstall route.
- Quality public mode: interaction, accessibility, surfaces, smoke and release
  readiness.

## Public Rules

- Sensitive actions ask for confirmation.
- Long actions show progress or a running state.
- Raw logs are optional details, not the main user experience.
- Public actions should prefer native SevenOS surfaces before terminal output.
- Failures must offer a next action.
