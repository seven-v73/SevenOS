# SevenBus C Layer

This directory defines the C boundary for SevenOS.

C is not the product brain, the UI language, or the ecosystem layer. In SevenOS,
C belongs to the physical and nervous layer of the system:

- low-level IPC probes;
- hardware-facing capability checks;
- future input, power and audio bridges;
- future kernel/udev/libinput/ALSA/PipeWire adjacency;
- tiny, auditable binaries where startup cost and ABI stability matter.

The first binary is intentionally small:

```bash
sevenbus-probe --json
```

It reports local IPC capabilities that SevenBus can use later. The current
SevenBus implementation still uses JSONL events and Rust event writing through
`seven-daemon emit`.

## Boundary

```text
UI Layer                  GTK / Tauri / JS
System Orchestration      TypeScript / Rust
Core Layer                Rust + small C probes
Hardware Interface        C through Linux primitives and libraries
Kernel                    Linux
```

This keeps C powerful without letting it spread into areas where Rust, GTK,
TypeScript or Python are better fits.
