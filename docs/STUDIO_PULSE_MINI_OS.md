# Studio And Pulse Mini OS Contracts

SevenOS keeps creative and gaming workflows inside their natural mini OS spaces.
Equinox remains the stable host, while Studio and Pulse expose dedicated product
centers and actions through `seven studio`, `seven pulse` and the global action
registry.

## Studio

Studio is the creator mini OS. It owns:

- visual design and image editing;
- video editing and exports;
- screen capture and streaming;
- audio editing;
- 3D creation;
- stable creator folders under `~/Studio`.

Primary routes:

```bash
seven studio
seven studio workspace
seven studio assets
seven studio captures
seven studio exports
seven studio record
seven studio apps
```

The base Studio profile stays focused and fast. Heavy or specialized tools remain
optional, so SevenOS does not become large by surprise.

## Pulse

Pulse is the gaming and performance mini OS. It owns:

- game launchers;
- Proton/Wine gaming routes;
- HUD and frame pacing;
- GameMode and performance visibility;
- gaming audio checks;
- rootfs-private gaming packages where possible.

Primary routes:

```bash
seven pulse doctor
seven pulse center
seven pulse performance
seven pulse audio
seven pulse hud
seven pulse launchers
seven pulse packages
```

GPU drivers, kernel modules and shared desktop services remain host-level
Equinox responsibilities because the kernel and display stack are shared.

## Shield Scope

Shield should remain partial until an authorized scope exists. This is not a bug:
it prevents audit tools from feeling ready before owner, engagement, time window
and targets are explicit.

```bash
seven shield scope
seven shield scope create --owner "Name" --engagement "Lab" --window "Today" --target 127.0.0.1
seven shield scope activate
```

## Baobab

Baobab remains intentionally modular. Its optional packs include large tools and
community engines, but they should be installed only when the user needs them.
The priority is cultural validation, provenance and field/community workflows,
not maximal package count.
