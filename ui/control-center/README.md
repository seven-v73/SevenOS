# SevenOS Control Center

The Control Center is a system surface, not a provider aggregator.

`bin/seven-control-center status` projects the already-computed Waybar Context
into the `sevenos.control-center.v1` contract. The UI must consume that contract
only; it must not query NetworkManager, PipeWire, battery devices, or security
providers directly.

The current native quick-settings surface remains the temporary UI backend.
Future GTK4 layer-shell work belongs in this directory and must use
`seven-control-center-action` for all mutations.
