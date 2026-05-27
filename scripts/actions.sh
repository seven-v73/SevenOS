#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS action registry

Usage:
  seven actions
  seven actions --json
  seven actions list
  seven actions category <name>
  seven actions run <id> [--dry-run]

The registry is the shared action contract for Seven Hub, Waybar,
Quick Settings and future native SevenOS surfaces.
EOF
}

action_rows() {
  cat <<'EOF'
home.open	Desktop	Open SevenOS Home	seven home	safe	Open the public SevenOS Home surface for mini OS, settings, store, backup and recent actions.
hub.open	Desktop	Open Seven Hub	seven hub	safe	Open the SevenOS Control Center.
actions.open	Desktop	Open Action Center	seven actions open	safe	Open the graphical SevenOS action center for normal users.
startup.audit	Desktop	Startup Performance Audit	./scripts/startup-audit.sh	safe	Check that public SevenOS apps open from cache and do not block on deep audits.
hub.status	Desktop	Hub Status	seven hub status	safe	Show whether Seven Hub is ready as the default product control surface.
hub.plan	Desktop	Hub Product Plan	seven hub plan	safe	Show missing Hub productization work before changing the desktop.
about.status	System	About SevenOS	seven about	safe	Show the public SevenOS identity, edition, active mini OS, channel and distribution state.
about.plan	System	About Plan	seven about plan	safe	Show the next identity and public About actions without exposing backend-first checks.
about.doctor	System	About Doctor	seven about doctor	safe	Validate the public About contract used by Settings, Hub and installer surfaces.
about.json	System	About SevenOS JSON	seven about --json	safe	Expose the SevenOS public identity contract for Hub, Settings and installer surfaces.
lifecycle.status	System	SevenOS Lifecycle	seven lifecycle	safe	Show the SevenOS-first maintenance routes for updates, repair, protected state, recovery and release gates.
lifecycle.doctor	System	Lifecycle Doctor	seven lifecycle doctor	safe	Validate that SevenOS maintenance is exposed through SevenOS surfaces instead of raw backend commands.
lifecycle.plan	System	Lifecycle Plan	seven lifecycle plan	safe	Show remaining maintenance gates before SevenOS feels like a complete autonomous distribution.
boot.splash.status	System	Boot Splash Status	seven boot-splash status	safe	Show SevenOS quiet boot and shutdown splash readiness.
boot.splash.doctor	System	Boot Splash Doctor	seven boot-splash doctor	safe	Validate the SevenOS Plymouth theme, Prism boot asset and ISO install hook.
boot.splash.apply	System	Apply Boot Splash	seven boot-splash apply	packages	Enable SevenOS Plymouth splash, quiet kernel parameters and initramfs integration.
login.theme.status	System	Login Theme Status	seven login-theme status	safe	Show SevenOS SDDM login screen readiness.
login.theme.doctor	System	Login Theme Doctor	seven login-theme doctor	safe	Validate the SevenOS Prism SDDM theme and locale-aware login contract.
login.theme.apply	System	Apply Login Theme	seven login-theme apply	packages	Install and select the SevenOS SDDM login screen after boot.
update.status	System	SevenOS Update	seven update	safe	Show SevenOS system, app, community and profile update state before backend commands run.
update.plan	System	Update Plan	seven update plan	safe	Show the SevenOS-first update sequence.
update.apply	System	Apply Updates	seven update apply	packages	Update through the SevenOS route, then delegate to package foundations.
update.rollback	System	Roll Back SevenOS Update	seven update rollback	changes	Restore the last SevenOS tree snapshot after an update problem.
recovery.status	System	SevenOS Recovery	seven recovery	safe	Show protected user state, migration backups, repair routes and installer/recovery readiness.
recovery.plan	System	Recovery Plan	seven recovery plan	safe	Show the SevenOS-first recovery sequence.
recovery.backup	System	Create Recovery Backup	seven recovery backup	changes	Create a protected migration backup using the SevenOS manifest.
health.status	System	SevenOS Health	seven health	safe	Show product, lifecycle, update, recovery, foundations, distribution and service health in SevenOS language.
health.plan	System	Health Plan	seven health plan	safe	Show the next SevenOS-first actions for any daily health issue.
health.doctor	System	Health Doctor	seven health doctor	safe	Validate SevenOS daily health without exposing backend-first diagnostics.
smoke.status	System	SevenOS Smoke Gate	seven smoke	safe	Run the fast public-product gate used before opening deeper developer audits.
smoke.doctor	System	Smoke Doctor	seven smoke doctor	safe	Validate state, product, identity, distribution and health contracts with strict timeouts.
smoke.json	System	Smoke Gate JSON	seven smoke --json	safe	Expose the fast SevenOS distribution smoke contract for Hub, Settings and release surfaces.
quality.status	System	Public Quality Gate	seven quality	safe	Show the product-quality aggregate for health, surfaces, update, mini OS, Shell, Server/Deploy and release freeze.
quality.doctor	System	Public Quality Doctor	seven quality doctor	safe	Validate the user-experience gates before public release or a major phase claim.
quality.json	System	Public Quality JSON	seven quality json	safe	Expose the public-quality aggregate to Hub, Settings and future Shell surfaces.
release.review	System	Release Freeze Review	seven release review	safe	Show grouped dirty-worktree guidance before freezing or committing a public release.
release.review_native	System	Release Review UI	seven release open	safe	Open the native SevenOS release freeze review surface.
release.freeze	System	Write Release Freeze	seven release freeze --json	safe	Write the current release-freeze manifest with git status and diff stat paths.
support.status	System	SevenOS Support	seven support	safe	Show local-first support readiness, health, product, recovery and event summary.
support.bundle	System	Create Support Bundle	seven support bundle	changes	Create a local support bundle under the user account; nothing is uploaded automatically.
support.plan	System	Support Plan	seven support plan	safe	Show the SevenOS-first support flow before collecting diagnostics.
product.status	System	SevenOS Product	seven product	safe	Show the compact SevenOS product snapshot used by Hub, Settings, Welcome and installer surfaces.
product.json	System	SevenOS Product JSON	seven product --json	safe	Expose the SevenOS product facade as one machine-readable contract for native surfaces.
foundations.status	System	SevenOS Foundations	seven foundations	safe	Show how SevenOS owns normal workflows while Arch, Hyprland, pacman and libvirt remain technical foundations.
foundations.doctor	System	Foundations Doctor	seven foundations doctor	safe	Validate that each low-level foundation has a SevenOS-native route before backend tools are exposed.
foundations.plan	System	Foundations Plan	seven foundations plan	safe	Show remaining backend-first gaps to make SevenOS feel autonomous and masked.
autonomy.status	System	SevenOS Autonomy	seven autonomy	safe	Show whether SevenOS is presented as an autonomous OS layer instead of exposed Arch/Hyprland internals.
autonomy.plan	System	Autonomy Plan	seven autonomy plan	safe	Show the remaining work to mask backend details behind SevenOS surfaces.
autonomy.doctor	System	Autonomy Doctor	seven autonomy doctor	safe	Validate the SevenOS autonomy contract.
platform.status	System	SevenOS Platform	seven platform	safe	Show SevenOS public platform layers and their hidden technical backends.
platform.doctor	System	Platform Doctor	seven platform doctor	safe	Validate the SevenOS platform facade.
mask.status	System	SevenOS Mask	seven mask	safe	Show whether public SevenOS surfaces present SevenOS before backend details.
mask.doctor	System	Mask Doctor	seven mask doctor	safe	Validate launcher names, installer portal, software surfaces and identity masking.
surfaces.status	System	Public Surfaces	seven surfaces	safe	Show whether SevenOS native surfaces cover normal-user workflows.
surfaces.doctor	System	Surfaces Doctor	seven surfaces doctor	safe	Validate Hub, Settings, Store, Files, Reader, Terminal and profile-aware native surfaces.
routes.status	System	User Routes	seven routes	safe	Show how normal user intentions route to SevenOS surfaces before backend tools.
routes.doctor	System	Routes Doctor	seven routes doctor	safe	Validate user-intent routing across SevenOS surfaces and action IDs.
distribution.status	System	SevenOS Distribution	seven distribution	safe	Show the top-level distribution gate across autonomy, masking, dynamic UI, surfaces, routes, channel and installer readiness.
distribution.doctor	System	Distribution Doctor	seven distribution doctor	safe	Validate whether SevenOS is daily-driver distribution ready or blocked from public release.
distribution.plan	System	Distribution Plan	seven distribution plan	safe	Show the remaining gates before SevenOS can be treated as a public release candidate.
channel.status	System	Release Channel	seven channel	safe	Show whether this workspace is dev, testing or stable from a SevenOS product perspective.
channel.testing	System	Switch To Testing Channel	seven channel set testing	changes	Mark the current workspace as a SevenOS testing channel without creating a git commit.
channel.stable	System	Switch To Stable Channel	seven channel set stable	changes	Mark the current workspace as stable when release gates are ready.
apps.open	Desktop	Open Apps	seven-overview apps	safe	Open the SevenOS application library.
spotlight.open	Desktop	Open Spotlight	seven-spotlight	safe	Open SevenOS Spotlight search and action surface.
launchpad.open	Desktop	Open Launchpad	seven-launchpad-native	safe	Open the SevenOS profile-aware application grid.
files.open	Desktop	Open Files	seven-files	safe	Open Seven Files.
files.downloads	Desktop	Downloads	seven-files downloads	safe	Open Downloads for the active mini OS in Seven Files.
files.documents	Desktop	Documents	seven-files documents	safe	Open Documents for the active mini OS in Seven Files.
files.code	Desktop	Code	seven-files code	safe	Open Code for the active mini OS in Seven Files.
files.pictures	Desktop	Pictures	seven-files pictures	safe	Open Pictures for the active mini OS in Seven Files.
files.videos	Desktop	Videos	seven-files videos	safe	Open Videos for the active mini OS in Seven Files.
files.music	Desktop	Music	seven-files music	safe	Open Music for the active mini OS in Seven Files.
files.resources.status	Desktop	Resource Mode	seven-files resources status	safe	Show whether Seven Files uses active mini OS resources or shared user folders.
files.resources.toggle	Desktop	Toggle Resource Mode	seven-files resources toggle	changes	Switch Seven Files between active mini OS folders and shared user folders.
files.resources.mini	Desktop	Use Mini OS Resources	seven-files resources mini	changes	Keep Downloads, Documents, Code, Music, Pictures and Videos inside the active mini OS.
files.resources.shared	Desktop	Use Shared Resources	seven-files resources shared	changes	Use the global user folders for Downloads, Documents, Code, Music, Pictures and Videos.
files.profile	Desktop	Profile Workspace	seven-files profile	safe	Open the active SevenOS profile workspace in Seven Files.
reader.open	Desktop	Open Reader	seven-reader	safe	Open the Seven Reader immersive library.
reader.library	Desktop	Reader Library	seven-reader library	safe	Open the Seven Reader visual library.
reader.status	System	Reader Status	seven-reader --json	safe	Show Seven Reader formats, modes and local state.
quick.open	Desktop	Open Quick Settings	seven-quick-settings	safe	Open SevenOS quick controls.
notifications.open	Desktop	Open Notifications	seven-waybar-notifications menu	safe	Open the SevenOS notification center.
terminal.open	Desktop	Open Terminal	seven-terminal	safe	Open the active mini OS terminal.
terminal.forge	Desktop	Forge Terminal	seven-terminal forge	safe	Open a SevenOS terminal tuned for development, Git and builds.
terminal.cyber	Desktop	Cyber Terminal	seven-terminal cyber	safe	Open a SevenOS terminal tuned for logs, diagnostics and security work.
terminal.palette	Desktop	Terminal Actions	seven-terminal-palette	safe	Open Seven Terminal quick actions for history, diagnosis and SevenAI help.
recorder.panel	Desktop	Seven Recorder	seven-recorder panel	safe	Open the SevenOS Recorder controls.
recorder.area	Desktop	Record Area	seven-recorder area	safe	Select an area and start a smooth SevenOS screen recording.
recorder.full	Desktop	Record Screen	seven-recorder full	safe	Start a full-screen SevenOS recording.
recorder.stop	Desktop	Stop Recording	seven-recorder stop	safe	Stop the active SevenOS recording and copy the saved path.
window.toggle-float	Desktop	Toggle Floating	seven window toggle-float	safe	Toggle the active window between tiled and floating mode.
window.smart-maximize	Desktop	Smart Maximize	seven window smart-maximize	safe	Apply SevenOS smart maximize to the active window.
window.remember	Desktop	Remember Window Layout	seven window remember	safe	Record active window, workspace, size and position for SevenOS session continuity.
window.memory	Desktop	Window Memory	seven window memory --json	safe	Show remembered windows, workspaces and app layout state.
window.restore	Desktop	Restore Window Layout	seven window restore	safe	Focus and restore the remembered active window layout when possible.
settings.open	Desktop	Open Settings	seven-settings	safe	Open the native SevenOS Settings app for wallpaper, displays, network, sound, keyboard, security, profiles and system.
welcome.open	System	Welcome	seven welcome	safe	Show the SevenOS onboarding overview.
welcome.status	System	First-Run Status	seven welcome status	safe	Check whether this user session is really SevenOS.
welcome.plan	System	First-Run Plan	seven welcome plan	safe	Show the first-run completion plan.
migrate.ml4w.plan	System	ML4W Migration Plan	seven migrate-ml4w plan	safe	Show active ML4W-marked configuration paths that conflict with SevenOS.
migrate.ml4w.switch	System	Switch ML4W to SevenOS	seven migrate-ml4w switch	changes	Quarantine ML4W configs, apply SevenOS desktop layer and restart session services.
keyboard.status	Desktop	Keyboard Layout	seven keyboard status	safe	Show SevenOS keyboard layouts and switching mode.
keyboard.apply	Desktop	Apply US/FR Keyboard	seven keyboard apply	changes	Enable English/French keyboard layouts with Alt+Shift switching.
postinstall.check	System	Post-Install Check	seven post-install	safe	Check common blockers after installation.
session.status	Desktop	Session Status	seven session status	safe	Check SevenOS session services and desktop files.
session.start	Desktop	Start Session	seven session start	changes	Start SevenOS desktop session components.
waybar.status	Desktop	Waybar Status	seven-waybar status --json	safe	Show the machine-readable SevenOS Waybar, context daemon and repair contract.
waybar.repair	Desktop	Repair Waybar	seven-waybar repair	changes	Repair the SevenOS Waybar and active context daemon, then verify the doctor state.
readiness.run	System	Run Readiness	seven readiness	safe	Score SevenOS against product readiness checks.
experience.run	System	Experience Audit	seven experience	safe	Check whether SevenOS behaves like a coherent OS.
experience.status	Desktop	Shell Experience State	seven experience status	safe	Show the shared motion, feedback, focus and mini OS continuity contract.
experience.apply	Desktop	Apply Shell Experience	seven experience apply	changes	Synchronize motion, focus feedback, workspace memory and mini OS behavior hints.
experience.doctor	Desktop	Shell Experience Doctor	seven experience doctor	safe	Validate the unified SevenOS Shell Experience contract.
experience.warmup	Desktop	Warm Up Shell Experience	seven experience warmup	safe	Prepare Spotlight, app and motion caches so SevenOS feels instant after session start.
experience.events	Desktop	Shell Experience Events	seven experience events	safe	Show recent launch, focus, workspace and feedback events.
experience.recommend	Desktop	Shell Experience Recommendation	seven experience recommend	safe	Show the next suggested action for the active mini OS and current shell state.
experience.reduced_motion	Desktop	Reduced Motion Path	seven motion reduced	changes	Use the accessibility-ready reduced motion preset across the compositor.
control.plan	System	Control Plane	seven control	safe	Show prioritized SevenOS actions across readiness, trust and services.
control.preview	System	Preview Control Fixes	seven control apply --limit 5	safe	Preview the next prioritized SevenOS fixes without changing the system.
events.open	System	Event Journal	seven events	safe	Show local SevenOS decision and action history.
insights.open	System	OS Insights	seven insights	safe	Show product-facing SevenOS limits and next actions.
phase.gate	System	Phase Gate	seven phase-gate --json	safe	Show whether SevenOS is ready to move beyond product consolidation.
b3.status	System	B3 Status	seven b3 status	safe	Show the B2 to B3 consolidation score and blockers.
b3.plan	System	B3 Plan	seven b3 plan	safe	Show the ordered path for trust, backend, profiles, shell and installer.
b3.trust	System	B3 Trust Plan	seven b3 plan --phase trust	safe	Show only critical trust and Shield actions.
b3.backend	System	B3 Backend Plan	seven b3 plan --phase backend	safe	Show only Seven Server backend actions.
b3.profiles	System	B3 Profiles Plan	seven b3 plan --phase profiles	safe	Show only profile completion actions.
b3.shell	System	B3 Shell Plan	seven b3 plan --phase shell	safe	Show only Seven Shell native desktop actions.
b3.installer	System	B3 Installer Plan	seven b3 plan --phase installer	safe	Show only installer readiness actions.
b3.doctor	System	B3 Doctor	seven b3 doctor	safe	Validate B3 orchestration before applying system changes.
b3.apply	System	B3 Apply Preview	seven b3 apply --limit 8	safe	Preview the next B3 consolidation actions without changing the system.
b3.apply.trust	System	B3 Trust Preview	seven b3 apply --phase trust --limit 4	safe	Preview the next trust and Shield actions without changing the system.
b3.apply.backend	System	B3 Backend Preview	seven b3 apply --phase backend --limit 4	safe	Preview the next Seven Server actions without changing the system.
b3.apply.profiles	System	B3 Profiles Preview	seven b3 apply --phase profiles --limit 4	safe	Preview the next profile completion actions without changing the system.
doctor.run	System	Run Doctor	seven doctor	safe	Check common system blockers.
doctor.open	System	Open Seven Doctor	seven doctor open	safe	Open the graphical Seven Doctor surface with guided repair actions.
prepush.fast	System	Pre-Push Fast Gate	seven pre-push	safe	Run the fast GitHub push gate: syntax, JSON contracts, design, smoke, state and first-install dry-runs.
prepush.full	System	Pre-Push Full Audit	seven pre-push full	safe	Run the long developer audit before a release tag.
daily.status	System	Daily Driver Gate	seven daily	safe	Check whether SevenOS is ready for a primary PC.
daily.plan	System	Daily Driver Plan	seven daily plan	safe	Show the ordered path to make SevenOS daily-driver ready.
daily.apply	System	Apply Daily Driver Plan	seven daily apply --yes	packages	Install and enable the daily-driver security, profile, Atlas, server and installer foundation.
primary.status	System	Primary PC Gate	seven primary	safe	Show the consolidated primary-PC readiness gate across Shield, profiles, Atlas, Core, Server and Flatpak.
primary.json	System	Primary PC JSON	seven primary --json	safe	Expose primary-PC readiness as one machine-readable contract for Seven Hub and future Seven Core clients.
primary.apply	System	Apply Primary PC Path	seven primary apply	packages	Run the daily-driver consolidation path from the primary-PC entrypoint.
setup.new	System	Install SevenOS New Machine	seven new	packages	One-command fresh machine setup: fonts, dependencies, mini OS workspaces, isolation and post-install checks.
setup.doctor	System	New Device Doctor	seven setup doctor	safe	Check fresh-machine package files, network, fonts, splash and profile contracts before installing.
setup.new_device	System	New Device Setup	seven setup new-device --yes	packages	Automatically prepare a fresh SevenOS machine with fonts, visual layer, mini OS requirements, workspaces and isolation.
setup.new_device.optional	System	New Device Full Setup	seven setup new-device --yes --optional	packages	Prepare a fresh SevenOS machine and include optional mini OS package sets.
improve.daily	System	Improve Daily Driver	seven improve daily --apply --yes	packages	Apply the daily-driver consolidation plan.
improve.security	System	Improve Security	seven improve security --apply	packages	Install or prepare the core security improvements.
improve.security.yes	System	Improve Security Batch	seven improve security --apply --yes	packages	Install core security improvements non-interactively.
improve.deployment	System	Improve Deployment	seven improve deployment --apply	packages	Install or prepare server and deployment dependencies.
improve.deployment.yes	System	Improve Deployment Batch	seven improve deployment --apply --yes	packages	Install server and deployment dependencies non-interactively.
improve.compatibility	System	Improve Compatibility	seven improve compatibility	packages	Install or prepare Atlas exploration improvements.
repair.ux	System	Repair UX	seven repair ux	changes	Review desktop and shell repair actions.
theme.apply	System	Apply Theme	./install.sh theme	changes	Reapply SevenOS shell, toolkit and wallpaper identity.
motion.status	Desktop	Motion Status	seven motion	safe	Show the active SevenOS animation preset and compositor motion state.
motion.ux_doctor	Desktop	Motion UX Doctor	seven motion ux-doctor	safe	Validate mini OS passage overlays, declared motion and accessibility-ready presets.
motion.premium	Desktop	Enable Premium Motion	seven motion premium	changes	Apply a visible SevenOS motion preset for atlas, layers and workspaces.
motion.profile	Desktop	Apply Profile Motion	seven motion profile	changes	Apply the active mini OS motion language.
motion.auto	Desktop	Automatic Motion	seven motion set auto	changes	Let each mini OS choose its own motion preset.
motion.reduced	Desktop	Reduced Motion	seven motion reduced	changes	Apply a calmer animation preset for accessibility and low-power sessions.
profile.status	Profiles	Profile Status	seven profile status	safe	Show installed and active profile state.
profile.current	Profiles	Current Profile	seven profile current	safe	Show the active profile in detail.
profile.guide	Profiles	Profile Guide	seven profile guide	safe	Show recommended actions for the active profile.
profile.apps	Profiles	Profile Apps	seven profile apps	safe	Show apps and launch commands for the active profile.
profile.gaps	Profiles	Profile Gaps	seven profile gaps	safe	Show incomplete profile packages, apps and next actions.
profile.requirements	Profiles	Profile Requirements	seven profile requirements $(seven profile current --json | python -c 'import json,sys; print(json.load(sys.stdin).get("key","equinox"))')	safe	Show missing package requirements for the active mini OS.
profile.requirements.install	Profiles	Install Profile Requirements	seven profile requirements $(seven profile current --json | python -c 'import json,sys; print(json.load(sys.stdin).get("key","equinox"))') --apply --yes	packages	Install missing required packages for the active mini OS.
profile.requirements.optional	Profiles	Install Optional Requirements	seven profile requirements $(seven profile current --json | python -c 'import json,sys; print(json.load(sys.stdin).get("key","equinox"))') --optional --apply --yes	packages	Install optional/profile community packages when available.
profile.plan	Profiles	Profile Plan	seven profile plan	safe	Show prioritized profile completion plan.
profile.aliases	Profiles	Profile Aliases	seven profile aliases	safe	Show retired profile aliases and their active replacements.
profile.migrate_aliases	Profiles	Migrate Profile Aliases	seven profile migrate-aliases --apply	changes	Rewrite stale local state from retired profile aliases to active mini OS names.
profile.isolation	Profiles	Profile Isolation	seven profile isolation status	safe	Show active packages, quiet packages, services and strict app-data boundaries.
profile.strict.active	Profiles	Strict Active Runtime	seven-profile-run --json	safe	Show the strict execution boundary for the active mini OS.
profile.strict.manifest	Profiles	Runtime Manifest	seven-profile-run --manifest	safe	Show the full runtime manifest for the active mini OS.
profile.rootfs.status	Profiles	Profile RootFS Status	seven profile-rootfs status	safe	Show real per-mini-OS rootfs readiness.
profile.rootfs.audit	Profiles	Profile RootFS Audit	seven profile-rootfs audit all	safe	Test rootfs execution, profile marker, isolation mode, runtime sockets, GPU/dev and network posture.
profile.rootfs.seal	Profiles	Seal Profile RootFS	seven profile-rootfs seal all --apply --yes	safe	Write local rootfs fingerprints for drift detection.
profile.rootfs.verify	Profiles	Verify Profile RootFS	seven profile-rootfs verify all	safe	Compare current rootfs package/os fingerprints against the last seal.
profile.rootfs.prepare	Profiles	Prepare Profile RootFS	seven profile-rootfs prepare --apply --yes	safe	Create rootfs directories, manifests and package lists for the active mini OS.
profile.rootfs.build	Profiles	Build Profile RootFS	seven profile-rootfs build --apply --yes	root	Build the active mini OS rootfs with its own package set when pacstrap is available.
profile.rootfs.shell	Profiles	Profile RootFS Shell	seven profile exec $(seven profile current --json | python -c 'import json,sys; print(json.load(sys.stdin).get("key","equinox"))') --rootfs sh	root	Open a shell inside the active mini OS rootfs when it is ready.
profile.rootfs.maintenance	Profiles	RootFS Maintenance Shell	seven profile exec $(seven profile current --json | python -c 'import json,sys; print(json.load(sys.stdin).get("key","equinox"))') --rootfs-writable sh	root	Open an explicit writable maintenance shell for the active mini OS rootfs.
profile.independent.shell	Profiles	Independent Mini OS Shell	seven profile exec $(seven profile current --json | python -c 'import json,sys; print(json.load(sys.stdin).get("key","equinox"))') --independent sh	root	Open the active mini OS with its sealed read-only rootfs and separated HOME/cache/data, without VM.
profile.strict.workspace	Profiles	Strict Workspace Shell	seven-profile-run --container --workspace . sh	packages	Open a strict shell for the active mini OS with only the current folder mounted as workspace.
profile.strict.profile_workspace	Profiles	Strict Profile Workspace	seven-profile-run --container --workspace-profile sh	packages	Open a strict shell for the active mini OS with its default workspace mounted.
profile.folders	Profiles	External Folders	seven profile folders	safe	Show folders explicitly granted to the active mini OS.
profile.grant.repo	Profiles	Grant SevenOS Repo	seven profile grant-folder forge /home/seven/Code/OS/SevenOS --name SevenOS --rw	changes	Allow Forge to access the SevenOS repository as an explicit external folder.
profile.open.repo	Profiles	Open SevenOS Repo In Forge	seven profile open-folder forge /home/seven/Code/OS/SevenOS	changes	Open the SevenOS repository inside Forge through a strict workspace mount.
profile.strict.ephemeral	Profiles	Ephemeral Strict Shell	seven-profile-run --ephemeral sh	packages	Open a strict shell with temporary HOME, cache and data removed after exit.
profile.strict.equinox	Profiles	Strict Equinox Shell	seven profile exec equinox --container sh	packages	Open an Equinox shell with isolated HOME, cache and data.
profile.strict.baobab	Profiles	Strict Baobab Shell	seven profile exec baobab --container sh	packages	Open a Baobab shell with isolated HOME, cache and data.
profile.strict.forge	Profiles	Strict Forge Shell	seven profile exec forge --container sh	packages	Open a Forge shell with isolated HOME, cache and data.
profile.strict.shield	Profiles	Strict Shield Shell	seven profile exec shield --container sh	packages	Open a Shield shell with isolated HOME, cache and data.
profile.strict.shield_ephemeral	Profiles	Ephemeral Shield Shell	seven profile exec shield --ephemeral sh	packages	Open a disposable Shield shell for labs, OSINT or risky investigation.
profile.strict.studio	Profiles	Strict Studio Shell	seven profile exec studio --container sh	packages	Open a Studio shell with isolated HOME, cache and data.
profile.strict.atlas	Profiles	Strict Atlas Shell	seven profile exec atlas --container sh	packages	Open a Atlas Explorer shell with isolated HOME, cache and data.
profile.strict.pulse	Profiles	Strict Pulse Shell	seven profile exec pulse --container sh	packages	Open a Pulse shell with isolated HOME, cache and data.
profile.bootstrap.active	Profiles	Bootstrap Active Profile	seven profile bootstrap	safe	Create the manifest, checklist and launcher for the active profile workspace.
profile.bootstrap.all	Profiles	Bootstrap All Profiles	seven profile bootstrap all	safe	Create workspace manifests, checklists and launchers for every SevenOS profile.
profile.open	Profiles	Open Active Workspace	seven profile open	safe	Open the current profile workspace.
profile.experience	Profiles	Profile Experience State	seven profile experience	safe	Show the active mini OS isolated experience manifest: config, theme, wallpaper and workspace.
bridge.status	Profiles	Mini OS Bridge	seven bridge	safe	Show inbox, outbox and SevenOS object counts for every mini OS.
bridge.init	Profiles	Initialize Mini OS Bridge	seven bridge init	safe	Create bridge inbox/outbox, session files and relation map for every mini OS.
bridge.relations	Profiles	Mini OS Relations	seven bridge relations	safe	Show which mini OS can exchange assets, reports, captures and cultural objects.
bridge.objects	Profiles	SevenOS Objects	seven bridge objects	safe	List explicit SevenOS objects exchanged between mini OS experiences.
bridge.graph	Profiles	Mini OS Relation Graph	seven bridge graph	safe	Show the relation graph with nodes, channels, inboxes, outboxes and object counts.
bridge.doctor	Profiles	Mini OS Bridge Doctor	seven bridge doctor	safe	Validate mini OS isolation, session memory, passage state, inbox/outbox and relations.
bridge.session	Profiles	Mini OS Session Memory	seven bridge session	safe	Show the active mini OS recent apps, paths, objects, tasks and mood.
bridge.switch.baobab	Profiles	Passage To Baobab	seven bridge switch --to baobab	safe	Preview the passage language, motion and boundaries before entering Baobab.
bridge.switch.forge	Profiles	Passage To Forge	seven bridge switch --to forge	safe	Preview the passage language, motion and boundaries before entering Forge.
bridge.baobab_studio	Profiles	Send Baobab To Studio	seven bridge send --from baobab --to studio --kind textile	safe	Send a declared cultural reference from Baobab to Studio without sharing hidden config state.
profile.activate.equinox	Profiles	Activate Equinox	seven profile activate equinox	changes	Switch to the balanced general SevenOS mini OS.
profile.activate.baobab	Profiles	Activate Baobab	seven profile activate baobab	changes	Switch to the African cultural mini OS.
profile.activate.forge	Profiles	Activate Forge DevOps	seven profile activate forge	changes	Switch to the development, containers and deployment mini OS.
profile.activate.shield	Profiles	Activate Shield	seven profile activate shield	changes	Switch to the cybersecurity mini OS.
profile.activate.studio	Profiles	Activate Studio	seven profile activate studio	changes	Switch to the creator mini OS.
profile.activate.atlas	Profiles	Activate Atlas	seven profile activate atlas	changes	Switch to the Atlas Explorer mini OS for documents, maps, OCR and research.
profile.activate.pulse	Profiles	Activate Pulse	seven profile activate pulse	changes	Switch to the Linux gaming mini OS.
runtime.status	Profiles	Runtime Status	seven runtime status	safe	Show the active SevenOS layered autonomous runtime without changing resources.
runtime.plan	Profiles	Runtime Fusion Plan	seven runtime plan equinox forge shield studio pulse	safe	Preview Equinox with controlled capability fragments from multiple profiles.
runtime.capabilities	Profiles	Runtime Capabilities	seven runtime capabilities	safe	List profile capabilities that can be injected into a composite runtime.
runtime.doctor	Profiles	Runtime Doctor	seven runtime doctor	safe	Check cgroups, scheduler, context, zram and future checkpoint hooks for runtime orchestration.
profile.equinox	Profiles	Install Equinox	seven profile install equinox	packages	Install the balanced global SevenOS profile.
profile.baobab	Profiles	Install Baobab	seven profile install baobab	packages	Install the cultural SevenOS profile.
baobab.status	Baobab	Baobab Status	seven baobab	safe	Show the Baobab cultural mini OS contract.
baobab.bootstrap	Baobab	Bootstrap Baobab	seven baobab bootstrap	safe	Create the Baobab offline workspace, manifest and module directories.
baobab.install_core	Baobab	Install Baobab Core	seven baobab install-core	packages	Install the lightweight Baobab core package set including fonts and MPV.
baobab.install_optional	Baobab	Install Baobab Optional	seven baobab install-optional	packages	Install optional Baobab repo packages and AUR/community candidates when a helper is available.
baobab.capabilities	Baobab	Baobab Capabilities	seven baobab capabilities	safe	Show how Baobab tools map to culture, offline use, education, AI, media, sync and creation.
baobab.capability_doctor	Baobab	Baobab Capability Doctor	seven baobab capability-doctor	safe	Check Baobab product capabilities against the cultural OS tool strategy.
baobab.config	Baobab	Baobab Config Roots	seven baobab config	safe	Show Baobab profile-owned config, data, cache and service config files.
baobab.runtime	Baobab	Baobab Runtime	seven baobab runtime	safe	Show the Baobab runtime environment and profile-specific service roots.
baobab.config_doctor	Baobab	Baobab Config Doctor	seven baobab config-doctor	safe	Validate that Baobab config, data and cache stay inside the Baobab mini OS profile.
baobab.service_doctor	Baobab	Baobab Service Doctor	seven baobab service-doctor	safe	Validate profile-owned Baobab launchers for sound, local search, AI and narration.
baobab.app_doctor	Baobab	Baobab App Doctor	seven baobab app-doctor	safe	Validate profile-owned Baobab desktop launchers and public app entries.
baobab.apply_config	Baobab	Apply Baobab Config	seven baobab apply-config	safe	Materialize profile-owned Baobab configs for MPV, Waybar, Eww, Meilisearch, Ollama, Piper, Argos and sync.
baobab.sound	Baobab	Baobab Sound	seven baobab sound	safe	Open Baobab Sound through the profile-owned MPV configuration and local audio library.
baobab.open	Baobab	Open Baobab	seven baobab open	safe	Open the native Baobab cultural OS surface.
baobab.native	Baobab	Baobab Native	seven baobab native	safe	Open the French-first native Baobab interface for patrimoine, pays, récits and musée.
baobab.village	Baobab	Baobab Village Page	seven baobab village	safe	Show the generated local Village page path.
baobab.heritage_gallery	Baobab	Heritage Gallery	seven baobab heritage	safe	Open the visual offline heritage gallery.
baobab.museum	Baobab	Baobab Museum	seven baobab museum	safe	Open the generated offline Baobab museum scene.
baobab.story	Baobab	Story Mode	seven baobab story	safe	Open the generated offline Baobab storytelling surface.
baobab.explore_map	Baobab	Explore Africa	seven baobab explore	safe	Open the generated offline cultural map prototype.
baobab.countries	Baobab	Africa Country Index	seven baobab countries	safe	Show the embedded offline Africa country index.
baobab.country	Baobab	Country Detail	seven baobab country Burkina Faso	safe	Show an offline country detail from the Baobab Africa index.
baobab.unesco	Baobab	UNESCO ICH Index	seven baobab unesco	safe	Show African-linked UNESCO intangible cultural heritage entries imported from the local CSV.
baobab.datasets	Baobab	Cultural Datasets	seven baobab datasets	safe	Show local CSV, TSV and JSON sources available to Baobab.
baobab.catalog	Baobab	Offline Catalog	seven baobab catalog	safe	Show the Baobab offline starter catalog.
baobab.search	Baobab	Search Baobab	seven baobab search wisdom	safe	Search the Baobab offline cultural catalog.
baobab.stats	Baobab	Catalog Stats	seven baobab stats	safe	Show Baobab offline catalog statistics.
baobab.db	Baobab	SQLite Index	seven baobab db	safe	Show the Baobab local SQLite index status.
baobab.engines	Baobab	Engine Readiness	seven baobab engines	safe	Show local readiness for Baobab shell, AI, reader, 3D and offline engines.
baobab.tools	Baobab	Baobab Tools	seven baobab tools	safe	Show the cultural OS tool strategy: shell, identity, offline content, AI, education, media, sync and creation.
baobab.tool_doctor	Baobab	Baobab Tool Doctor	seven baobab tool-doctor	safe	Validate Baobab core tools and optional immersive/community engines.
baobab.languages	Baobab	African Languages	seven baobab languages	safe	Show Baobab starter African language metadata and local validation status.
baobab.integrations	Baobab	Open Source Engines	seven baobab integrations	safe	List Baobab open source engine candidates.
baobab.roadmap	Baobab	Integration Roadmap	seven baobab roadmap	safe	Show the Baobab shell, heritage, 3D, AI and offline integration roadmap.
baobab.packs	Baobab	Cultural Packs	seven baobab packs	safe	List local Baobab cultural packs.
baobab.audit_packs	Baobab	Audit Cultural Packs	seven baobab audit-packs	safe	Check Baobab packs for provenance, license, curator, confidence, language and country metadata.
baobab.seed_packs	Baobab	Seed Starter Packs	seven baobab seed-packs	safe	Create and import starter packs for Burkina food, Mandingue sound and Faso Danfani fashion.
baobab.enrich_packs	Baobab	Prepare Living Packs	seven baobab enrich-packs	safe	Add interview, consent, media and community review templates to Baobab packs.
baobab.sample_fieldwork	Baobab	Sample Fieldwork	seven baobab sample-fieldwork	safe	Create sample-only fieldwork files to demonstrate collection readiness without claiming real validation.
baobab.scaffold_pack	Baobab	New Cultural Pack	seven baobab scaffold-pack local-heritage	safe	Create a local Baobab cultural pack scaffold.
baobab.modules	Baobab	Baobab Modules	seven baobab modules	safe	Show Heritage, Story, Sound, Explore, Museum, Languages, Fashion, Food, Wisdom and Market modules.
baobab.heritage	Baobab	Baobab Heritage	seven baobab module heritage	safe	Show the heritage library module.
baobab.explore	Baobab	Explore Africa	seven baobab module explore	safe	Show the interactive Africa exploration module.
baobab.fashion	Baobab	Baobab Fashion	seven baobab module fashion	safe	Show the African fashion and ElegantStyle bridge module.
profile.forge	Profiles	Install Forge DevOps	seven profile install forge	packages	Install the development, containers and deployment mini OS stack.
profile.shield	Profiles	Install Shield	seven profile install shield	packages	Install the cybersecurity mini OS stack.
profile.studio	Profiles	Install Studio	seven profile install studio	packages	Install the creator mini OS stack.
profile.atlas	Profiles	Install Atlas Explorer	seven profile install atlas	packages	Install the Atlas Explorer app-first stack with Maps fallback.
profile.pulse	Profiles	Install Pulse	seven profile install pulse	packages	Install the Linux gaming mini OS stack.
security.audit	Security	Shield Audit	seven shield audit	safe	Audit firewall, sandbox and cyber tooling.
security.dashboard	Security	Shield Control	seven shield dashboard	safe	Open the native Shield workspace dashboard.
security.mode	Security	CyberSpace	seven shield mode	safe	Show the context-aware cybersecurity workspace.
security.hud	Security	Cyber HUD	seven shield hud	safe	Show cyber context, scope and workspace status.
security.context.recon	Security	Recon Context	seven shield context recon	changes	Enter the Recon CyberSpace workspace.
security.context.web	Security	Web Pentest Context	seven shield context web	changes	Enter the Web Pentest CyberSpace workspace.
security.context.forensics	Security	Forensics Context	seven shield context forensics	changes	Enter the Forensics CyberSpace workspace.
security.status	Security	Shield Status	seven shield status	safe	Show firewall, sandbox and Shield trust posture.
security.plan	Security	Shield Plan	seven shield plan	safe	Show prioritized Shield hardening actions.
security.bootstrap	Security	Bootstrap Shield Workspace	seven shield bootstrap	safe	Create Shield policy, checklist and safe launchers in the user workspace.
security.workspace	Security	Shield Workspace	seven shield workspace	safe	Show the local Shield workspace contract.
security.open	Security	Open Shield Workspace	seven shield open	safe	Open the Shield workspace folders.
security.tools	Security	Shield Tools	seven shield tools	safe	Show grouped Shield tool readiness.
security.scope	Security	Shield Scope	seven shield scope	safe	Show authorized audit scope before any network action.
security.report	Security	New Shield Report	seven shield report	safe	Create a structured Shield report in the workspace.
security.enable	Security	Enable Shield	seven shield enable	changes	Apply base SevenOS security hardening.
security.blackarch.full	Security	Full BlackArch Preview	seven shield toolchain blackarch-full --dry-run	safe	Preview the complete BlackArch package set before explicit installation.
security.lab	Security	Open Cyber Lab	seven shield lab --preset web	safe	Open an isolated web testing lab.
security.lab.forensics	Security	Open Forensics Lab	seven shield lab --preset forensics	safe	Open an offline evidence-safe forensics lab.
security.lab.reversing	Security	Open Reversing Lab	seven shield lab --preset reversing	safe	Open an offline reversing lab.
atlas.status	Atlas	État Atlas	seven atlas status	safe	Vérifier si Atlas Explorer est prêt dans SevenOS.
atlas.open	Atlas	Ouvrir Atlas	seven-mini-os-center atlas	safe	Ouvrir le centre Atlas avec readiness, documents, cartes, références et actions.
atlas.activate	Atlas	Activer Atlas	seven profile activate atlas	changes	Basculer vers le mini OS Atlas Explorer.
atlas.install	Atlas	Installer Atlas	seven atlas install --yes	packages	Installer les paquets Atlas pour documents, cartes, OCR, archives et recherche.
atlas.optional	Atlas	Installer les extensions Atlas	seven-profile-requirements status atlas --optional --apply --yes	packages	Ajouter les outils Atlas avancés quand ils sont disponibles.
atlas.files	Atlas	Fichiers Atlas	seven profile open atlas	safe	Ouvrir l’espace Atlas dans Seven Files.
atlas.documents	Atlas	Documents Atlas	seven profile open-folder atlas Documents	safe	Ouvrir les PDF, ebooks, notes et documents Atlas.
atlas.maps	Atlas	Cartes Atlas	seven profile open-folder atlas Maps	safe	Ouvrir les cartes, trajets et GPX Atlas.
atlas.scans	Atlas	Scans Atlas	seven profile open-folder atlas Scans	safe	Ouvrir les scans et documents OCR Atlas.
atlas.apps	Atlas	Applications Atlas	seven profile apps atlas	safe	Ouvrir les applications liées à Atlas.
atlas.rootfs	Atlas	Vérifier Atlas rootfs	seven-profile-rootfs audit atlas	safe	Vérifier que le rootfs Atlas est cohérent.
server.status	Server	Server Status	seven server status	safe	Check the local SevenOS API service.
server.plan	Server	Server Plan	seven server plan	safe	Show prioritized Seven Server backend actions.
server.install	Server	Install Server Service	seven server install-user-service	changes	Install the local SevenOS API user service.
server.start	Server	Start Server Service	seven server start	changes	Start the local SevenOS API user service.
deploy.plan	Server	Deployment Plan	seven deploy plan .	safe	Forge only: detect and plan deployment for the current project.
deploy.inspect	Server	Inspect Project	seven deploy inspect .	safe	Forge only: detect stack, tools and natural dev commands for the current project.
deploy.dev	Server	Dev Loop	seven deploy dev .	safe	Forge only: show the natural development loop for the current project.
deploy.doctor	Server	Deploy Doctor	seven deploy doctor .	safe	Forge only: check project-specific deployment tools.
deploy.publish	Server	Publish Web App	seven deploy publish .	changes	Forge only: save a durable build snapshot and start it as a local hosting service.
deploy.publish_public	Server	Publish Public Preview	seven deploy publish . --provider cloudflare	changes	Forge only: expose the hosted snapshot through a generated public tunnel when cloudflared is available.
deploy.publish_domain	Server	Publish With Domain	seven deploy publish . --domain app.example.com	changes	Forge only: prepare a hosted snapshot for a custom domain route.
deploy.domain_tunnel	Server	Domain Tunnel Plan	seven deploy domain app.example.com --target tunnel	safe	Forge only: show DNS steps for a purchased domain on a personal SevenOS machine through a tunnel.
deploy.domain_vps	Server	Domain VPS Plan	seven deploy domain app.example.com --target vps --public-ip 203.0.113.10	safe	Forge only: show DNS A/AAAA records for a VPS or public SevenOS host.
deploy.dns_check_ip	Server	DNS IP Check	seven deploy dns-check app.example.com --expected-ip 203.0.113.10	safe	Forge only: check whether a domain resolves to the expected VPS or public host IP.
deploy.dns_check_tunnel	Server	DNS Tunnel Check	seven deploy dns-check app.example.com --expected-cname tunnel.cfargotunnel.com	safe	Forge only: check whether a domain CNAME points to the expected tunnel hostname.
deploy.route_check	Server	Route Check	seven deploy route-check app.example.com	safe	Forge only: check DNS plus local/public HTTP reachability for a hosted app or domain.
deploy.diagnose	Server	Hosting Diagnose	seven deploy diagnose app.example.com	safe	Forge only: run the full hosting diagnosis: service, route, DNS, versions and next actions.
deploy.versions	Server	Hosted Versions	seven deploy versions .	safe	Forge only: show saved build snapshots for a hosted project.
deploy.rollback	Server	Rollback Hosted App	seven deploy rollback .	changes	Forge only: switch a hosted project back to a previous saved snapshot.
deploy.remove	Server	Remove Hosted App	seven deploy remove .	changes	Forge only: stop a hosted project and remove its SevenOS deploy snapshots.
deploy.services	Server	Hosting Services	seven deploy services	safe	Forge only: show active SevenOS hosted services.
deploy.panel	Server	Hosting Panel	seven deploy panel	safe	Forge only: show the local deployment management panel contract.
installer.status	Installer	Installer Status	seven installer status	safe	Check Calamares and ISO foundations.
installer.plan	Installer	Installer Plan	seven installer plan	safe	Show prioritized installer and ISO actions.
installer.release	Installer	Installer Release Readiness	seven installer release	safe	Show public-ISO release readiness, required checks and graphical installer gap.
installer.graphical	Installer	Graphical Installer Route	seven installer graphical	safe	Show the Calamares graphical installer route, launcher and live ISO entrypoint readiness.
installer.runtime	Installer	Calamares Runtime Policy	seven installer runtime	safe	Show whether Calamares is installed, officially available or declared as a trusted AUR/downstream ISO runtime.
installer.portal	Installer	Installer Portal	seven-installer portal	safe	Show the user-facing SevenOS installer portal and safe route for this machine.
installer.guide	Installer	Installer Guide	seven installer guide	safe	Show the normal-user install path SevenOS exposes today.
installer.install	Installer	Install Installer Tools	seven installer install	packages	Install installer foundation packages.
installer.iso	Installer	Preview ISO Build	./install.sh iso --dry-run	safe	Preview the SevenOS ISO build path.
ai.brief	System	SevenAI Brief	seven ai	safe	Show the local SevenAI system brief.
ai.plan	System	SevenAI Plan	seven ai plan	safe	Show prioritized local guidance from SevenOS state.
ai.focus	System	SevenAI Product Focus	seven ai focus	safe	Show the next product-hardening focus from ecosystem maturity and release contracts.
ai.agent	System	SevenAI Agent	seven ai "open settings"	safe	Run the local SevenAI intent engine against a natural-language request.
ai.apps	System	SevenAI App Registry	seven ai apps --json	safe	Show the app registry SevenAI uses before launching applications.
ai.context	System	SevenAI Context	seven ai context --json	safe	Show SevenAI local system context from processes and Hyprland state.
ai.memory	System	SevenAI Memory	seven ai memory --json	safe	Show the local-only SevenAI interaction memory log.
ai.wifi	System	SevenAI Wi-Fi Repair Plan	seven ai "mon wifi ne marche pas"	safe	Let SevenAI diagnose a Wi-Fi repair intent before applying system changes.
ai.theme.light	System	SevenAI Light Theme Plan	seven ai "mets le thème light"	safe	Let SevenAI understand and preview the SevenOS Light Mode switch.
ai.workspace	System	SevenAI Workspace Switch	seven ai "workspace 2"	safe	Switch Hyprland workspace through a natural-language SevenAI command.
ai.shortcuts	System	SevenAI Shortcuts	seven ai shortcuts	safe	Show SevenOS keyboard shortcuts from the AI knowledge layer.
ai.knowledge	System	SevenAI SevenOS Knowledge	seven ai knowledge	safe	Explain what SevenOS is, its surfaces and its daily workflow model.
ai.llm	System	SevenAI LLM Contract	seven ai llm --json	safe	Show the provider-neutral local-first LLM and web architecture contract.
ai.provider	System	SevenAI Local Provider	seven ai provider "mon wifi ne marche pas" --json	safe	Run the local-only SevenOS provider without tokens, accounts or external data flow.
ai.diagnose	System	SevenAI Diagnostics	seven ai diagnose system --json	safe	Inspect local load, memory, disk, services, network and top processes.
ai.playbook.wifi	System	SevenAI Wi-Fi Playbook	seven ai playbook wifi_repair --json	safe	Show the confirmed Wi-Fi repair playbook before applying changes.
ai.research	System	SevenAI Research Cache	seven ai research "Hyprland" --json	safe	Show cached/offline-first research contract; web requires explicit --web.
store.open	Apps	SevenStore	seven store	safe	Browse SevenOS modules, Flatpak apps and safe OS actions from one catalog.
store.modules	Apps	Store Modules	seven store modules	safe	Show installable SevenOS bundles with optional modules separated from required readiness.
store.apps	Apps	Store Apps	seven store apps	safe	Show the Flatpak application catalog exposed through SevenStore.
store.doctor	Apps	Store Doctor	seven store doctor	safe	Validate the SevenStore catalog contract for Hub and future native UI surfaces.
box.status	Ecosystem	SevenBox Status	seven box	safe	Show sandbox, container and app isolation readiness.
box.profiles	Ecosystem	SevenBox Profiles	seven box profiles	safe	Show available sandbox/container profiles without starting anything.
cloud.status	Ecosystem	SevenCloud Status	seven cloud	safe	Show local-first backup and restore readiness.
cloud.plan	Ecosystem	SevenCloud Plan	seven cloud plan	safe	Show which SevenOS state would be protected before any backup runs.
flow.status	Ecosystem	SevenFlow Status	seven flow	safe	Show automation recipes and safety policy.
flow.recipes	Ecosystem	SevenFlow Recipes	seven flow recipes	safe	Show the explicit steps behind each automation recipe.
cluster.status	Ecosystem	SevenCluster Status	seven cluster	safe	Show private multi-machine readiness and safety policy.
cluster.nodes	Ecosystem	SevenCluster Nodes	seven cluster nodes	safe	Show declared local/private cluster nodes.
cluster.plan	Ecosystem	SevenCluster Plan	seven cluster plan	safe	Show next steps before any multi-machine orchestration is enabled.
flatpak.status	Apps	Flatpak Status	seven flatpak status	safe	Check Flathub and Flatpak readiness.
flatpak.install	Apps	Install Default Flatpaks	seven flatpak install	packages	Install default Flatpak apps including Bottles and creative tools.
sevenpkg.status	Apps	SevenPkg Status	sevenpkg status	safe	Show SevenOS software layer state.
sevenpkg.doctor	Apps	SevenPkg Doctor	sevenpkg doctor	safe	Diagnose SevenPkg sources, mini OS software layers, optional packages and removal guards.
sevenpkg.plan	Apps	Software Plan	sevenpkg plan	safe	Show prioritized software and app completion actions.
sevenpkg.meta	Apps	Meta Packages	sevenpkg meta	safe	List SevenOS software bundles.
sevenpkg.owner	Apps	Package Owner	sevenpkg owner nmap	safe	Show which SevenOS mini OS owns a package before install/remove decisions.
sevenpkg.optional	Apps	Optional Software	sevenpkg optional	safe	Show optional SevenOS software layers without installing them.
sevenpkg.history	Apps	Package History	sevenpkg history	safe	Show recent guarded SevenPkg transactions.
sevenpkg.transaction.forge	Apps	Preview Forge Install	sevenpkg transaction install forge	safe	Preview the guarded Forge software transaction and post-install SevenOS repair hooks.
sevenpkg.transaction.remove	Apps	Preview Removal	sevenpkg transaction remove	safe	Show removal impact and SevenOS ownership guard before packages are removed.
software.open	Apps	SevenOS Software	seven software plan	safe	Open the friendly SevenOS software CLI entrypoint.
sevenpkg.baobab	Apps	Install Baobab Bundle	sevenpkg install baobab	packages	Install the African cultural OS software bundle.
sevenpkg.forge	Apps	Install Forge Bundle	sevenpkg install forge	packages	Install the developer software bundle.
sevenpkg.shield	Apps	Install Shield Bundle	sevenpkg install shield	packages	Install the cybersecurity software bundle.
sevenpkg.studio	Apps	Install Studio Bundle	sevenpkg install studio	packages	Install the creative production software bundle.
sevenpkg.atlas	Apps	Install Atlas Bundle	sevenpkg install atlas	packages	Install the Atlas Explorer bundle for documents, maps, OCR and research.
sevenpkg.pulse	Apps	Install Pulse Bundle	sevenpkg install pulse	packages	Install the Linux gaming software bundle.
sevenpkg.griot	Apps	Install Griot Bundle	sevenpkg install griot	packages	Install the documentation and knowledge software bundle.
ecosystem.status	Ecosystem	Ecosystem Map	seven ecosystem	safe	Show modules and maturity states.
ecosystem.processes	Ecosystem	Process Map	seven ecosystem processes	safe	Show all-in-one SevenOS user flows.
ecosystem.maturity	Ecosystem	Maturity Map	seven ecosystem maturity	safe	Show product-readiness levels and next hardening steps for every SevenOS module.
ecosystem.roadmap	Ecosystem	Ecosystem Roadmap	seven ecosystem roadmap	safe	Show Phase 4 and Phase 5 priorities.
ecosystem.doctor	Ecosystem	Ecosystem Doctor	seven ecosystem doctor	safe	Validate ecosystem foundation files.
architecture.map	Ecosystem	Architecture Map	seven architecture	safe	Show the SevenOS product and control-plane architecture map.
architecture.hybrid	Ecosystem	Hybrid OS Contract	seven architecture hybrid	safe	Explain the local user-space hybrid OS architecture above Linux.
architecture.matrix	Ecosystem	Hybrid OS Matrix	seven architecture matrix	safe	Show layer readiness, ownership, contracts, safety and next actions.
architecture.json	Ecosystem	Hybrid OS JSON	seven architecture matrix --json	safe	Expose SevenOS hybrid architecture as a machine-readable contract for Hub and SevenAI.
stack.status	Ecosystem	Stack Strategy	seven stack	safe	Show the phased technology stack strategy.
stack.roadmap	Ecosystem	Stack Roadmap	seven stack roadmap	safe	Show when AGS, Rust, AI and app stacks should enter SevenOS.
stack.doctor	Ecosystem	Stack Doctor	seven stack doctor	safe	Validate stack strategy files and shell foundation packages.
core.status	Ecosystem	Seven Core Status	seven core	safe	Show the Seven Core and SevenBus foundation state.
core.plan	Ecosystem	Seven Core Plan	seven core plan	safe	Show the next actions for the system experience layer.
core.bus	Ecosystem	SevenBus Schema	seven core bus --json	safe	Show the local event envelope consumed by Hub, Shell and future daemon.
core.snapshot	Ecosystem	SevenDaemon Snapshot	seven core snapshot --json	safe	Show the Rust daemon view of SevenBus event state.
core.health	Ecosystem	SevenDaemon Health	seven core health --json	safe	Show local runtime health from the Rust daemon.
core.profiles	Ecosystem	SevenDaemon Profiles	seven core profiles --json	safe	Show daemon-native profile state as SevenOS migrates profile logic out of Bash.
core.observe	Ecosystem	Observe Context Once	seven core observe --json	safe	Ask SevenDaemon to record one semantic context observation into SevenBus.
core.doctor	Ecosystem	Seven Core Doctor	seven core doctor	safe	Validate contracts, SevenBus and the daemon scaffold.
core.install-service	Ecosystem	Install Seven Daemon	seven core install-service	changes	Install the Seven Core runtime as a user service.
core.install-observer	Ecosystem	Install Context Observer	seven core install-observer	changes	Install the supervised SevenOS semantic context observer service.
core.start	Ecosystem	Start Seven Daemon	seven core start	changes	Start the local Seven Core runtime.
core.start-observer	Ecosystem	Start Context Observer	seven core start-observer	changes	Start continuous semantic context observations for the current session.
core.logs	Ecosystem	Seven Daemon Logs	seven core logs	safe	Follow the Seven Core runtime journal.
core.observer-logs	Ecosystem	Context Observer Logs	seven core observer-logs	safe	Follow the semantic context observer journal.
adaptive.status	Ecosystem	Adaptive UI Status	seven adaptive	safe	Show whether active profile, shell, Waybar, Hub and context signals are connected.
adaptive.plan	Ecosystem	Adaptive UI Plan	seven adaptive plan	safe	Show the remaining steps to make profile-aware UI behavior feel productized.
dynamic.status	Ecosystem	Dynamic OS Status	seven dynamic	safe	Show whether profile UI, theme runtime, wallpaper palette and compositor accents are connected.
dynamic.doctor	Ecosystem	Dynamic OS Doctor	seven dynamic doctor	safe	Validate SevenOS dynamic profile/theme/surface adaptation.
scheduler.status	Ecosystem	Seven Scheduler Status	seven scheduler status	safe	Show process groups, active profile policy and host scheduling hints.
scheduler.plan	Ecosystem	Seven Scheduler Plan	seven scheduler plan	safe	Show context-aware CPU, priority and power actions.
scheduler.apply	Ecosystem	Apply Scheduler Hints	seven scheduler apply	changes	Preview or apply safe user-space nice adjustments for owned processes.
context.status	Ecosystem	Context Status	seven-context --json	safe	Show the unified active SevenOS context: app, profile, layout, window, workflow and recommendation.
context.graph	Ecosystem	Context Graph	seven context graph	safe	Show process/window topology grouped into human workflows.
context.plan	Ecosystem	Context Plan	seven context plan	safe	Show context-driven profile and scheduler recommendations.
context.emit	Ecosystem	Emit Context Event	seven context emit	safe	Record the current semantic context into SevenBus for Hub, Shell and future daemon observation.
shell.status	Desktop	Seven Shell Status	seven shell	safe	Show the AGS/TypeScript Seven Shell foundation state.
shell.plan	Desktop	Seven Shell Plan	seven shell plan	safe	Show how Seven Shell will replace Rofi panels gradually.
shell.preview	Desktop	Seven Shell Preview	seven shell preview	safe	Show planned AGS surfaces and fallback contracts.
shell.install	Desktop	Install Shell Foundation	./install.sh shell-ags --yes	packages	Install GJS, TypeScript, GTK4 and libadwaita for the B3 shell foundation.
shell.ags_runtime	Desktop	Install AGS Runtime	./install.sh shell-ags-runtime --yes	packages	Install Aylur's Gtk Shell runtime from the explicit AUR route after review.
shell.ags_runtime.open	Desktop	Open AGS Install	scripts/shell-ags-runtime.sh open	packages	Open the AGS runtime install route inside Seven Terminal with a readable report.
shell.ags_runtime.report	Desktop	AGS Runtime Report	scripts/shell-ags-runtime.sh report	safe	Show the last AGS runtime install report and next action.
identity.status	Ecosystem	SevenOS Visual Identity	seven identity	safe	Show SevenOS Beyond the Desktop product language.
identity.experience	Ecosystem	Identity Experience Gate	seven identity experience	safe	Check whether SevenOS feels like a coherent OS identity instead of a set of scripts.
identity.open	Ecosystem	Identity Experience Surface	seven identity open	safe	Open the native Prism-first identity report for SevenOS.
identity.plan	Ecosystem	Identity Plan	seven identity plan	safe	Show identity gaps before public surfaces rely on branding and theme assets.
identity.design	Ecosystem	Seven Design Engine	seven identity design	safe	Show Seven Mocha/Latte palettes, icon resolution and design surfaces.
identity.theme	Ecosystem	Theme Runtime	seven identity theme	safe	Show active GTK, Qt, icons, cursor and Kvantum runtime state.
identity.theme.doctor	Ecosystem	Theme Doctor	seven identity theme-doctor	safe	Check dark/light parity, toolkit coherence and runtime theme state.
identity.icons	Ecosystem	SevenOS Native Icons	seven identity icons	safe	Show native SevenOS app icons and install names.
identity.visuals	Ecosystem	Visual Package Layer	seven identity visuals	safe	Show Catppuccin, cursor, Kvantum and icon package readiness.
identity.visuals.install	Ecosystem	Install Visual Layer	seven identity visuals install --yes	packages	Install Catppuccin GTK, cursors, Kvantum themes and Papirus folder integration.
identity.packs	Ecosystem	Regional Accent Packs	seven identity packs	safe	Show planned regional accent packs without turning the UI into flags.
identity.current	Ecosystem	Active Identity Pack	seven identity current	safe	Show the active SevenOS regional accent pack.
identity.activate.pan	Ecosystem	Activate Accent Pack	seven identity activate pan-african	changes	Set the active SevenOS contextual accent pack.
identity.doctor	Ecosystem	Identity Doctor	seven identity doctor	safe	Validate SevenOS identity files and components.
identity.doctor.json	Ecosystem	Identity Doctor JSON	seven identity doctor --json	safe	Expose the identity readiness contract for Hub, Settings and release checks.
EOF
}

print_rows_for_category() {
  local wanted="$1"
  action_rows | awk -F '\t' -v wanted="$wanted" 'tolower($2) == tolower(wanted)'
}

json_output() {
  local rows
  rows="${1:-$(action_rows)}"
  ACTION_ROWS="$rows" python - <<'PY'
import json
import os
from collections import defaultdict
from datetime import datetime, timezone

items = []
categories = defaultdict(list)
profile_map = {
    "baobab": [],
    "forge": [],
    "shield": [],
    "studio": [],
    "atlas": [],
    "pulse": [],
    "equinox": [],
}
for raw in os.environ.get("ACTION_ROWS", "").splitlines():
    raw = raw.rstrip("\n")
    if not raw:
        continue
    action_id, category, title, command, impact, description = raw.split("\t", 5)
    item = {
        "id": action_id,
        "category": category,
        "title": title,
        "command": command,
        "impact": impact,
        "description": description,
        "safe": impact == "safe",
        "profile": "",
        "surface": "terminal" if command.startswith(("seven-terminal", "kitty")) else "native",
    }
    for profile in profile_map:
        if action_id.startswith(f"{profile}.") or f" {profile}" in command or f".{profile}" in action_id:
            item["profile"] = profile
            profile_map[profile].append(action_id)
            break
    if action_id.startswith("profile.activate."):
        profile = action_id.rsplit(".", 1)[-1]
        item["profile"] = profile
        profile_map.setdefault(profile, []).append(action_id)
    items.append(item)
    categories[category].append(action_id)

quick_actions = {
    "equinox": ["spotlight.open", "files.profile", "settings.open", "experience.recommend"],
    "baobab": ["baobab.open", "files.documents", "reader.open", "bridge.switch.baobab"],
    "forge": ["terminal.forge", "files.code", "deploy.plan", "profile.strict.forge"],
    "shield": ["security.dashboard", "security.scope", "security.lab.forensics", "profile.strict.shield_ephemeral"],
    "studio": ["files.pictures", "files.videos", "recorder.area", "profile.strict.studio"],
    "atlas": ["atlas.open", "atlas.documents", "atlas.maps", "atlas.apps"],
    "pulse": ["files.videos", "files.music", "recorder.full", "motion.reduced"],
}

print(json.dumps({
    "schema": "sevenos.actions.v1",
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "count": len(items),
    "actions": items,
    "categories": dict(sorted(categories.items())),
    "profiles": {key: value for key, value in sorted(profile_map.items()) if value},
    "quick_actions": quick_actions,
    "contract": {
        "consumers": ["Waybar", "Spotlight", "Seven Hub", "Mini OS centers", "Notifications"],
        "run_command": "seven actions run <id>",
        "json_command": "seven-actions --json",
        "seven_cli_json_command": "seven actions --json",
    },
}, indent=2))
PY
}

list_output() {
  printf '%-22s %-11s %-24s %s\n' "ID" "IMPACT" "CATEGORY" "TITLE"
  local rows
  rows="${1:-$(action_rows)}"
  while IFS=$'\t' read -r action_id category title _command impact _description; do
    [[ -n "${action_id:-}" ]] || continue
    printf '%-22s %-11s %-24s %s\n' "$action_id" "$impact" "$category" "$title"
  done <<<"$rows"
}

command_for_id() {
  local wanted="$1"
  action_rows | awk -F '\t' -v wanted="$wanted" '$1 == wanted { print $4; found=1 } END { exit found ? 0 : 1 }'
}

run_action() {
  local action_id="$1"
  local command
  command="$(command_for_id "$action_id")" || {
    log_error "Unknown SevenOS action: $action_id"
    exit 1
  }

  if is_dry_run; then
    printf '%s\n' "$command"
    return 0
  fi

  log_info "Running SevenOS action: $action_id"
  "$ROOT_DIR/scripts/shell-experience.sh" launch "$action_id" >/dev/null 2>&1 || true
  if bash -lc "cd '$ROOT_DIR' && $command"; then
    "$ROOT_DIR/scripts/shell-experience.sh" notify "SevenOS" "Action terminée: $action_id" >/dev/null 2>&1 || true
  else
    status=$?
    "$ROOT_DIR/scripts/shell-experience.sh" notify "SevenOS" "Action échouée: $action_id" >/dev/null 2>&1 || true
    return "$status"
  fi
}

ACTION="${1:-list}"
case "$ACTION" in
  -h|--help|help)
    usage
    ;;
  --json|json)
    json_output
    ;;
  list)
    list_output
    ;;
  open|gui|center)
    if is_dry_run; then
      printf '%s\n' "$ROOT_DIR/bin/seven-actions-native"
      exit 0
    fi
    "$ROOT_DIR/bin/seven-actions-native"
    ;;
  category)
    shift
    if [[ -z "${1:-}" ]]; then
      log_error "Missing category name."
      usage
      exit 1
    fi
    rows="$(print_rows_for_category "$1")"
    if [[ -z "$rows" ]]; then
      log_error "Unknown SevenOS action category: $1"
      exit 1
    fi
    list_output "$rows"
    ;;
  run)
    shift
    if [[ -z "${1:-}" ]]; then
      log_error "Missing action id."
      usage
      exit 1
    fi
    run_action "$1"
    ;;
  *)
    log_error "Unknown actions command: $ACTION"
    usage
    exit 1
    ;;
esac
