# SevenOS Release Validation

SevenOS separates three release levels:

1. **Daily ready**: the local system has no blocking gate and can be used as a daily driver.
2. **Public beta ready**: the ISO route, installer, update, support and release evidence are coherent enough for controlled public testing.
3. **Large-scale ready**: multiple real machines have passed the hardware matrix and release signing/support operations are in place.

The project must not claim large-scale readiness from local checks alone.

## Required Local Evidence

Run:

```bash
seven production validate
```

or:

```bash
scripts/release-validation.sh record
```

This records a JSON report in:

```text
out/release-validation/latest.json
```

The report captures:

- generated ISO artifact in `out/iso`;
- SevenOS boot entries;
- Calamares local ISO runtime;
- local package repository;
- Wi-Fi tooling;
- Bluetooth tooling;
- external disk tooling;
- suspend tooling;
- GPU detection tooling;
- CPU, GPU, memory and disk evidence.

## Manual Matrix

Before a public beta, validate at least one real target machine:

- boot USB in normal mode;
- boot USB in Safe Graphics mode;
- connect Wi-Fi from the live installer portal;
- run Calamares full install;
- first boot into SevenOS;
- run `seven first-run verify`;
- run `seven update check`;
- mount and unmount an external disk;
- test suspend and resume;
- test Bluetooth if hardware is available.

Before a large-scale release, validate the matrix across:

- Intel graphics;
- AMD graphics;
- NVIDIA graphics;
- laptop Wi-Fi and Bluetooth;
- desktop wired network;
- suspend/resume on laptop;
- external USB storage;
- fresh install and update after reboot.

## Honest Release Rule

SevenOS can be called **Public Beta** when:

- `seven installer release` is `graphical-ready`;
- `seven smoke` is ready;
- `seven design-check` passes;
- `seven production validate` records local evidence;
- the Git tree is frozen in a reviewable commit.

SevenOS can be called **large-scale production ready** only after real multi-machine validation and signed release operations exist.
