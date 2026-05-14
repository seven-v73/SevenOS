# SevenOS Productization

SevenOS Productization is the phase where SevenOS stops feeling like an Arch
configuration and starts behaving like an independent operating system.

## Goal

```text
SevenOS should be operable from its own system interface.
```

The terminal remains powerful, but it must become an advanced tool, not the
default path for normal users.

## Phase B Priorities

### 1. Seven Hub Native Control Center

Seven Hub becomes the main system surface.

Required capabilities:

- dashboard with readiness score
- profile status and installation actions
- security state and repair actions
- app/package status through SevenPkg
- Windows Mode status
- server/deployment status
- readable logs and command output
- no hidden terminal requirement for common actions

Current foundation:

- Tauri GUI scaffold exists
- dashboard layout exists
- Rust backend command allowlist exists
- backend snapshot command exists
- readiness, services, profiles and recommendations are exposed to the UI

Next work:

- add confirmation dialogs for privileged actions
- add progress states for long installs
- add structured JSON outputs to more `seven` commands
- replace raw command text with human-readable result summaries

### 2. SevenOS Local Backend

`seven-server` should become the coordination layer behind the GUI.

Required endpoints:

- `/status`
- `/readiness`
- `/profiles`
- `/packages`
- `/security`
- `/windows`
- `/server`
- `/theme`

Design rule:

```text
The GUI should call stable backend operations, not random shell scripts.
```

### 3. Guided Installer

SevenOS needs a graphical installation flow.

Required capabilities:

- Calamares profile
- user creation
- locale and keyboard selection
- disk planning
- SevenOS profile selection
- automatic theme, CLI, Hub and session setup
- first-boot welcome

### 4. First Run Experience

After installation, SevenOS should guide the user through setup.

Required steps:

- verify internet
- verify audio
- verify GPU/session
- select primary profile
- apply theme
- install app essentials
- explain Seven Hub, Apps, Files and Power
- finish with a readiness score

### 5. SevenPkg As User Software Layer

SevenPkg should hide package-source complexity.

Required capabilities:

- show meta-packages
- search apps
- install from Arch, Flatpak and later AUR/SevenRepo
- show installed/partial/missing states
- expose data to Seven Hub

## Non-Goals For This Phase

- no marketplace yet
- no full cloud platform yet
- no complex AI automation yet
- no GPU passthrough automation yet

Those features come after the OS foundation feels coherent.

## Product Rule

Every new feature must answer:

```text
Can a normal user discover, understand and control this without reading scripts?
```

If the answer is no, the feature is not productized yet.
