# SevenOS Vision

SevenOS is not meant to be another Arch remix. It is a Linux ecosystem with a
Beyond the Desktop point of view: intelligent, open, immersive, and built for
modern work.

## Positioning

SevenOS aims to become:

> a futuristic intelligent Linux ecosystem for productivity, creation, cybersecurity,
> Windows compatibility, personal cloud deployment, and digital sovereignty.

The goal is to combine:

- the power and freshness of Arch
- the simplicity expected from a modern desktop OS
- the creative polish people associate with premium systems
- the openness of Linux
- a cultural identity that is structural, not decorative

## Why SevenOS Exists

Most Linux distributions are strong technically, but neutral culturally. They
often feel like collections of packages rather than complete digital
environments.

SevenOS starts from a different premise:

> an operating system is not just a tool; it is a digital living environment.

SevenOS should help users code, create, secure, learn, run Windows workflows,
and deploy projects without feeling like they are assembling a system by hand
every day.

## Product Promise

SevenOS should feel:

- simple enough for daily work
- powerful enough for advanced Linux users
- expressive enough to have a recognizable soul
- modular enough to adapt to different professions
- sovereign enough to support local, open, and self-hosted futures
- connected enough to become a private deployment node when the user chooses

## The Three Pillars

SevenOS is organized through the architecture documented in
`docs/ARCHITECTURE.md`: System Core, Package Layer, Service Layer, UI Layer,
Security Layer, Compatibility Layer, Deployment Layer, Identity Layer, and
Installer Layer.

### `seven`

The system controller. It manages status, profiles, security, virtual machines,
and high-level automation.

### `sevenpkg`

The package and application manager. It wraps pacman, optional AUR tooling,
SevenOS meta-packages, and future SevenRepo packages.

### Seven Hub

The user-facing control center. It should make SevenOS visible, navigable, and
comfortable without hiding Linux power.

### `seven-server`

The local backend. It turns the machine into a controlled system API,
monitoring surface, deployment node, and future personal cloud foundation.

### `seven-deploy`

The deployment planner. It detects project stacks and prepares reproducible
deployment plans before later phases execute them through rootless containers.

### Seven Ecosystem

The innovation map for SevenAI, SevenCloud, SevenStore, SevenBox, SevenFlow,
SevenIdentity and future cluster features. It keeps the ambition visible while
marking every module as active, preview, or planned.

## Differentiators

- Beyond the Desktop identity without reducing the system to decoration
- profile-based workflows: Forge, Shield, Studio, Horizon, Griot, Baobab
- integrated Windows compatibility through Wine, Bottles, Lutris, and KVM
- cybersecurity as a first-class workspace, not a separate live ISO only
- creative production as a native workflow
- local server and deployment architecture as a native OS capability
- ecosystem roadmap for AI, cloud, marketplace, automation and identity modules
- narrative UX that makes system operations understandable and memorable

## North Star

Every major change should answer yes to at least one of these questions:

- Does it make SevenOS more sovereign?
- Does it make Linux easier to live with?
- Does it strengthen the Beyond the Desktop identity in a useful way?
- Does it improve creative, cyber, development, or Windows workflows?
- Does it make self-hosting and deployment easier without weakening security?
- Does it make the system feel more coherent and premium?

SevenOS also tracks its ability to satisfy the practical OS choice criteria in
`docs/OS_CRITERIA.md` and through:

```bash
seven readiness
seven ecosystem
```
