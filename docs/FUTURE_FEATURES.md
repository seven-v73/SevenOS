# SevenOS Future Features

This document separates current SevenOS capabilities from future product
directions. A future item should not appear as a finished public feature until
it has a command, a doctor/check path, documentation and a recovery route.

## Principles

- Future work must preserve Equinox as the host/admin profile.
- Mini OS isolation must remain explicit and understandable.
- Public surfaces should show status, plans and previews before applying
  sensitive changes.
- SevenOS should prefer local-first workflows and avoid hidden cloud dependency.
- Strategic docs may mention future systems, but user-facing commands must
  clearly label preview, scaffold, planned or experimental behavior.

## Roadmap Areas

| Area | Direction | Current expectation |
| --- | --- | --- |
| Public installer | guided disk install through Calamares/Archinstall and SevenOS checks | planned |
| SevenRepo | SevenOS repository for packages, themes, helpers and native components | reserved |
| Seven Core | deeper Rust daemon for health, events and stable local contracts | foundation |
| SevenBus | local context/action/event bus without scraping shell output | foundation |
| Seven Shell | more native, fast and maintainable shell layer | progressive |
| SevenAI | local-first assistant with playbooks, explanations and safe actions | progressive |
| SevenStore | permissions, recommendations and profile-aware source clarity | progressive |
| Baobab | cultural packs, African languages, maps and offline collections | progressive |
| Windows Bridge | app-first Windows workflows around VM, Wine and Bottles | progressive |
| Personal cloud | opt-in backup, sync, deployment and local server workflows | future |
| Performance | explicit systemd slice/uclamp/power policies with user visibility | future |

## Acceptance Rule

A future feature becomes a SevenOS feature only when it has:

- a documented user workflow;
- a non-destructive status or plan command;
- an apply command when changes are needed;
- a doctor/check path;
- a UI or helper entry that a normal user can understand;
- an entry in the relevant UX or integration check.

