# SevenOS UX Principles

SevenOS UX should feel calm, fluid, useful, and culturally grounded.

## Core Principles

### 1. African First, Not Decorative

African identity should shape naming, rhythm, color, tone, and product
philosophy. It should not become a collage of flags or random motifs.

### 2. Workflows Before Packages

Users should think in terms of outcomes:

- Forge for building
- Shield for protecting
- Studio for creating
- Forge DevOps for building, connecting and deploying
- Griot for learning
- Baobab for system continuity

Packages remain available, but the default UX speaks in workflows.

### 3. Progressive Power

SevenOS should reveal complexity gradually:

- first: clear actions in Seven Hub
- then: simple commands through `seven`
- then: package control through `sevenpkg`
- finally: raw Arch tools when needed

### 4. Calm Premium Surfaces

Use liquid glass surfaces, readable contrast, precise spacing, and restrained
motion. Avoid visual noise and one-note palettes.

### 5. Narrative System Feedback

System messages should explain what is happening in plain language. They may
use SevenOS vocabulary, but should never become vague or theatrical.

Good:

```text
SevenOS Cyber Lab: web
Network: enabled
Private home: ~/SevenOS-Labs/cyber/web
```

Avoid:

```text
Magic mode activated.
```

### 6. One Source Of Truth

Seven Hub, `seven`, and `sevenpkg` should call the same scripts and manifests.
The GUI should not drift away from the CLI.

### 7. Safe By Default

Advanced actions should be explicit:

- BlackArch bridge requires review.
- VM provisioning requires clear ISO inputs.
- cyber labs make isolation visible.
- firewall changes preserve SSH when detected.

## Interface Standards

- Keep menus short and grouped by intent.
- Show status badges where useful: `OK`, `PART`, `MISS`, `RUN`.
- Use icons for recognition, but never rely on icons alone.
- Provide dry-run paths for system-changing actions.
- Keep Waybar informative without overcrowding it.
- Make power actions obvious and separate from settings.

## Tone

SevenOS should sound:

- confident
- practical
- warm
- technically honest
- rooted in its identity

It should not sound like generic enterprise software or exaggerated sci-fi.
