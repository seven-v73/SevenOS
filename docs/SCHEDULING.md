# SevenOS Process And Thread Orchestration

SevenOS does not replace the Linux scheduler.

The Linux kernel keeps ownership of process scheduling through CFS and the
hardware scheduler. SevenOS adds a user-space orchestration layer above it:

```text
Applications
  -> Seven Shell context
  -> Seven Core Scheduler Layer
  -> Linux CFS Scheduler
  -> CPU
```

## Role

Seven Context Engine detects the human workflow. Seven Scheduler turns that
context into safe policy hints. The kernel decides how CPU time is actually
distributed.

SevenOS can influence scheduling by:

- grouping processes by active profile;
- consuming semantic context from `seven context --json`;
- preparing nice/IO/power policy hints;
- preparing cgroups v2 / systemd slice policy hints;
- exposing future `uclamp` intent for latency-sensitive contexts;
- detecting foreground workloads;
- exposing state to Seven Hub and Seven Shell;
- later delegating stable decisions to SevenDaemon and SevenBus.

It must not:

- replace CFS;
- patch the kernel scheduler as an early feature;
- silently boost unknown processes;
- apply destructive or hard-to-debug affinity policies by default.

## Process Groups

| Group | Purpose | Policy |
|-------|---------|--------|
| Baobab | core OS services and shell | balanced |
| Forge | editors, compilers, containers | interactive-build |
| Shield | audit, sandbox, network/security tools | isolated-analysis |
| Studio | media, graphics, audio and 3D | media-low-latency |
| Windows | Wine, Bottles and KVM/QEMU | vm-foreground |
| Forge DevOps | code, server, deploy and personal cloud | service-stability |

Each group has:

- process match rules;
- a target nice value;
- an IO policy label;
- a power policy label;
- a future systemd slice name;
- CPU and IO weight targets;
- `uclamp` min/max intent;
- a human reason.

The planned cgroup model is:

```text
seven-baobab.slice   -> core OS services and shell surfaces
seven-forge.slice    -> editors, compilers, containers
seven-shield.slice   -> audit tools and sandboxed labs
seven-studio.slice   -> creative apps, media and audio
seven-windows.slice  -> Wine, Bottles, QEMU/KVM
seven-forge.slice  -> code, server, deploy and personal cloud
```

In B3 this is exposed as policy metadata only. SevenOS should not silently move
user processes between cgroups until SevenDaemon owns a visible, reversible
policy executor.

## Command Contract

```bash
seven scheduler status
seven scheduler status --json
seven scheduler plan
seven scheduler plan --json
seven scheduler apply
seven scheduler apply --apply
```

`status --json` exposes `sevenos.scheduler.v1` for Seven Hub, Seven Shell and
Seven Server.

`apply` is preview-only unless `--apply` is passed. The current implementation
only attempts safe user-space `renice` changes on matched processes owned by the
current user. CPU affinity, cgroups, `uclamp` and governor changes remain future
explicit features.

## Future Runtime

The long-term target is:

```text
SevenShell
  -> user context and foreground intent
SevenBus
  -> profile/app/performance events
SevenDaemon
  -> stable process observation and policy execution
Seven Scheduler
  -> context policy engine
Linux CFS
  -> actual CPU scheduling
```

This makes SevenOS adaptive without pretending to be a new kernel.
