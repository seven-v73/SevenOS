# SevenOS Progress

Derniere mise a jour : 2026-05-16

Ce document suit l'evolution de SevenOS : ce qui est deja en place, le niveau actuel du projet, les ameliorations recentes, et les prochaines etapes pour le faire passer d'une base Arch personnalisee a un vrai systeme d'exploitation coherent.

## Niveau Actuel

SevenOS est actuellement au niveau :

```text
Phase B2 / Product Consolidation Before ISO
```

Cela signifie que SevenOS n'est plus seulement une idee ou un theme Arch. Le projet possede deja une architecture de distribution, une identite visuelle, des scripts d'installation, des profils metiers, un debut de Control Center, une couche Windows, une base ISO, une couche serveur et un gestionnaire logiciel maison.

Le niveau actuel a progresse sur l'experience desktop : Waybar n'est plus seulement informative, les menus Rofi sont plus lisibles, et le lanceur d'applications suit maintenant une logique Launchpad plein ecran adaptee a SevenOS, adaptee a l'identite SevenOS.

SevenOS est maintenant dans la phase :

```text
Phase B2 — consolidation produit avant passage B3
```

Cette phase vise a reduire la dependance au terminal, stabiliser les contrats JSON, rendre Seven Hub Native plus utile, preparer Seven Server, et introduire Seven Shell AGS/TypeScript sans casser le fallback Waybar/Rofi/GTK.

Le phase gate actuel indique :

```text
decision: blocked
pass: 1
warn: 4
block: 5
```

Les blocages principaux avant B3 sont : readiness, control plane, Shield, Seven Server et installateur.

Le projet n'est pas encore au niveau :

```text
Stable Public Distribution
```

Pour y arriver, les priorites restantes sont : installateur graphique reel, Seven Hub complet, ISO testable proprement, profils metiers plus robustes, securite active par defaut, et meilleure integration entre tous les composants.

## Vision Produit

SevenOS vise a devenir un OS Linux afro-futuriste, souverain, fluide et modulaire.

Le positionnement est clair :

```text
Un ecosysteme Linux moderne pour creer, developper, securiser, deployer et utiliser Windows quand c'est necessaire.
```

Les piliers du projet sont :

- Performance : base Arch, Hyprland, composants legers.
- UX premium : Design System v1, surfaces liquid glass, coherence visuelle.
- Compatibilite : Wine, Bottles, Lutris, KVM/QEMU, VirtIO.
- Compatibilite app-first : `seven run <app>` choisit Wine, Bottles, Proton/Lutris ou VM selon le contexte.
- Simplicite : commandes `seven` et `sevenpkg`.
- Securite : Shield mode, hardening, sandbox, Cyber Lab.
- Profils metiers : Forge, Shield, Studio, Windows, Server.
- Ecosysteme : Seven Hub, Seven Server, Seven Deploy, SevenRepo futur.

## Ameliorations Deja Appliquees

### Architecture projet

- Structure modulaire du depot creee.
- Separation claire entre `bin/`, `scripts/`, `profiles/`, `security/`, `vm/`, `server/`, `sevenpkg/`, `seven-hub/`, `identity/`, `branding/`, `installer/` et `archiso/`.
- Ajout des documents de vision, architecture, UX, criteres OS, deploiement et test machine.
- Ajout de `docs/SYSTEM_EXPERIENCE_LAYER.md` comme reference principale : SevenOS est defini comme une couche d'experience systeme au-dessus du kernel Linux et de la base Arch, avec Seven Core, SevenBus, Seven Shell, Seven Hub, IA et hardware intelligence comme direction long terme.
- Ajout de `seven-core/` comme premiere implementation concrète de cette direction : README d'architecture, schema `sevenos.bus.v1`, scaffold Rust `seven-daemon` et contrat `seven core status --json`.
- Ajout de `seven core plan --json`, `seven core bus --json` et `seven core doctor` pour rendre la couche Seven Core observable avant le passage au daemon.
- Ajout de `bin/seven-daemon` et `systemd/user/seven-daemon.service` : SevenDaemon peut maintenant etre lance comme runtime local et rattache a `sevenos-session.target`.
- Ajout de `seven core install-service`, `seven core start`, `seven core stop` et `seven core logs` pour piloter le runtime Core sans manipuler systemd a la main.
- Debut de migration Bash vers Rust : `seven events log` prefere maintenant `seven-daemon emit` pour ecrire les evenements SevenBus, avec fallback Bash/Python si le daemon n'est pas disponible.
- Ajout de `seven core snapshot --json` : SevenDaemon lit maintenant le journal SevenBus et expose un resume natif des sources, etats, writers et dernier evenement.
- Renforcement du snapshot SevenDaemon avec `serde_json` : les evenements sont parses par Rust, les lignes invalides sont comptees separement, et `last_event` reste un vrai objet JSON.
- Migration supplementaire hors Bash : `seven events --json` et `seven events summary-json` preferent maintenant `seven-daemon events` / `seven-daemon summary`, avec fallback Bash conserve.
- Ajout de `seven core health --json` : SevenDaemon expose maintenant une sante runtime locale depuis Rust (`/proc`, session Wayland, memoire, charge, integrite SevenBus), sans traverser toute la pile Bash.
- Seven Shell consomme maintenant `seven core health --json` dans `seven shell status --json` : les futures surfaces AGS/GTK pourront afficher session, memoire, charge et integrite SevenBus depuis le runtime Rust.
- Ajout de la frontiere C : `seven-core/bus-c` et `sevenbus-probe --json` preparent les futures capacites IPC/hardware de SevenBus sans deplacer la logique produit vers C.
- Integration de Seven Core dans `seven state --json`, Seven Server, Seven Hub Native, le registre `seven actions`, le phase gate, le manifeste installable et les checks.
- Ajout de checks globaux avec `scripts/check.sh`, `scripts/ux-check.sh` et scripts de diagnostic.
- Ajout de `sevenos.dotinst`, manifeste d'installation et de migration inspire des logiques Hyprland matures : metadata, composants installables, chemins proteges, plan de restauration et checks de validation.
- Ajout de `seven manifest` comme point d'entree pour valider le manifeste, afficher les futurs composants paquetables et lister les chemins utilisateur a preserver.
- Ajout de `seven migrate plan` et `seven migrate backup` pour preparer les upgrades sans ecraser l'etat utilisateur.
- Definition des futures frontieres de paquets : `sevenos-cli`, `sevenos-branding`, `sevenos-hyprland`, `sevenos-hub`, `sevenos-profiles`, `sevenos-server` et `sevenos-installer`.

### Commandes systeme

- Mise en place de `seven` comme controleur principal.
- Mise en place de `sevenpkg` comme gestionnaire logiciel SevenOS.
- Ajout de commandes de statut, readiness, doctor, improvement et profils.
- Ajout de commandes UX : `seven-session`, `seven-wallpaper`, `seven-power`, `seven-files`, `seven-welcome`, `seven-country`.
- Ajout de sorties JSON stables pour `seven status --json`, `seven profile status --json`, `sevenpkg status --json` et `sevenpkg meta --json`.
- Ajout de `seven state --json`, snapshot machine unifie pour les interfaces natives, l'automatisation et le futur Seven Server.
- Ajout de `seven core status --json` comme contrat de la couche System Experience Layer : etat des contrats, SevenBus, journal local, API, daemon Rust et toolchain.
- Ajout de `seven actions --json`, registre central des actions SevenOS pour partager les memes commandes entre Hub, Waybar, Quick Settings et les futures surfaces natives.
- Ajout de `seven actions category <name>` pour fournir des listes d'actions ciblees aux petits panneaux systeme sans dupliquer les commandes.
- Ajout de `seven manifest show|doctor|restore-plan|protected|components` pour preparer les upgrades, le packaging pacman et la future ISO sans ecraser les choix utilisateur.
- Ajout de `seven migrate plan|backup` comme etape de securite avant reapplication du theme, upgrade Git, paquet pacman futur ou ISO.
- Ajout du resume manifeste dans `seven state --json`, pour que Seven Hub et Seven Server voient les composants, la version, le canal et les compteurs de protection en JSON.
- Seven Server expose maintenant `/actions`, afin que les interfaces locales puissent consommer le meme registre d'actions que Seven Hub.
- Debut de separation entre affichage humain et donnees machine pour que Seven Hub pilote SevenOS sans parser des textes fragiles.
- Ajout de `seven run <app>` comme entree directe vers la couche Windows App Layer.
- Ajout de `seven windows catalog`, `seven windows resolve <app> --json` et `seven windows run <app>` : SevenOS peut maintenant raisonner en “application Windows” avant de demander une VM.
- Ajout du contrat `sevenos.windows-app-resolve.v1` pour exposer moteur choisi, engines disponibles, fallback VM, sandbox recommandee et prochaines actions.
- Ajout de `docs/WINDOWS_APP_LAYER.md` : la compatibilite Windows devient app-first, VM-optionnelle, et exploitable par Seven Hub/SevenDaemon.

### Design System

- Creation du Design System v1 : `Sovereign by design`.
- Ajout de `identity/STYLE.md` comme reference officielle.
- Ajout de `identity/tokens.css` comme source CSS des couleurs, rayons, espacements, typographies et transitions.
- Ajout des motifs dans `identity/patterns/`.
- Nouvelle palette : Ebene clair, surfaces liquid glass, Or ancestral, Argile, Baobab, Indigo.
- Harmonisation de Waybar, Rofi, Kitty, Mako, Hyprland, Seven Hub et Tauri GUI.
- Suppression des styles trop generiques : pas de fond blanc, pas de `box-shadow`, pas de `backdrop-filter`, pas de font-weight lourd.
- Correction des surfaces Rofi trop noires ou illisibles.
- Passage du menu Apps vers un rendu plein ecran type Launchpad SevenOS : recherche centree, grille 6 colonnes, grandes icones et labels centres.
- Suppression des couleurs alpha hex fragiles dans Rofi et Waybar pour ameliorer la compatibilite GTK/Rofi.
- Recomposition de Waybar en vraie barre systeme : identite et workspaces a gauche, navigation au centre, controles systeme a droite.
- Ajout d'une surface dediee Quick Settings avec theme Rofi specifique, plus proche d'un panneau systeme que d'un simple menu texte.
- Raccordement du Launchpad Apps aux tokens Rofi centraux au lieu d'une palette locale dupliquee.
- Ajout de `scripts/design-check.sh` pour bloquer les regressions visuelles : ombres decoratives, blur lourd, font weights trop forts, Launchpad non tokenise, Quick Settings absent ou Hub sans details structurels.
- Refonte palette `Sovereign Dusk` : surfaces graphite plus lumineuses, textes secondaires plus lisibles et tuiles Apps mieux separees pour eviter l'effet noir-sur-noir en usage jour/nuit.
- Pivot design `Sovereign Glass` : SevenOS adopte une base light/liquid glass par defaut pour Rofi, Waybar, Kitty, Mako, Seven Hub, GTK/Qt et le wallpaper.
- Ajustement `Sovereign Glass` vers une teinte ivoire/raphia plus douce pour reduire la fatigue visuelle tout en gardant le rendu light/liquid glass.

### Desktop et session

- Configuration Hyprland stabilisee.
- Correction des options Hyprland obsoletes.
- Integration de Waybar, Rofi, Mako, Kitty, Hyprpaper, Swaylock et Swayidle.
- Ajout d'une logique `seven-session` pour lancer les composants desktop.
- Ajout de raccourcis plus decouvrables pour Hub, Apps et Help.
- Ajout du wallpaper SevenOS via Hyprpaper.
- Correction du demarrage Waybar avec chemins explicites de config et style.
- Ajout d'une couche `seven-waybar-action` pour transformer Waybar en barre de controle active.
- Ajout d'actions clic sur CPU, RAM, profil, securite, reseau, audio, batterie et horloge.
- Ajout de menus contextuels Waybar pour systeme, profils, Shield, reseau, audio, batterie et temps.
- L'indicateur profil Waybar lit maintenant `seven profile status --json` et affiche le profil actif reel au lieu d'un resume statique issu de `sevenpkg`.
- Ajout de fichiers Hyprland proteges : `~/.config/hypr/conf/monitor.conf`, `keyboard.conf` et `custom.conf`.
- `scripts/apply-theme.sh` installe ces fichiers seulement s'ils n'existent pas deja, afin que les mises a jour SevenOS puissent changer la session sans effacer les ecrans, le clavier ou les regles personnelles.
- Ajout de `seven-overview`, surface type Activities/Overview inspiree des shells modernes : apps, fenetres, recherche et run.
- Ajout de `seven-apps`, indexeur/lanceur d'applications SevenOS qui lit les applications systeme, utilisateur et Flatpak via leurs fichiers `.desktop`.
- `Super` seul, `Super+A`, Waybar Apps et Seven Help passent par `seven-apps`, afin que l'acces aux applications installees ne depende plus uniquement du cache `drun` de Rofi.
- `seven-apps` transmet maintenant les icones des fichiers `.desktop` a Rofi, ce qui permet au Launchpad Apps d'afficher les vraies icones d'applications quand le theme d'icones les fournit.
- Ajout de `seven-quick-settings`, panneau rapide pour Hub, apps, fenetres, reseau, audio, wallpaper, profils, migration, monitoring et power.
- Hyprland adopte une ergonomie plus GNOME-like : `Super+Tab` pour les fenetres, `Super+N`/`Super+O` pour les quick settings, `Super+S` pour scratchpad, `Super+L` pour lock, mouvements souris Super+clic et workspaces gauche/droite.
- `Super+D` toggle maintenant le Dock SevenOS ; l'ouverture directe des applications reste sur `Super`, avec `Super+Space` pour Spotlight.
- Kitty expose maintenant deux profils simultanes via `seven-terminal` :
  `classic` pour le rendu SevenOS clair et `dark` pour le rendu SevenOS graphite.
  `Super+Enter`, `Super+Shift+Enter` et `Super+Ctrl+Enter` ouvrent
  respectivement le terminal classic, dark et le menu de choix.
- Les profils SevenOS Terminal sont maintenant forces en fenetres flottantes
  centrees et compactes `640x420` via Hyprland pour se rapprocher du petit
  format Apple, au lieu d'ouvrir un grand terminal tuile.
- Ajout de `seven-terminal-shell`, un shell minimal dedie aux profils classic et
  dark : pas de signal pays, pas de fastfetch, pas de description materielle,
  uniquement un prompt simple type Terminal Apple.
- Les profils Kitty affichent maintenant des marqueurs type traffic lights
  `rouge / jaune / vert` dans la barre superieure, avec raccourcis associes :
  fermer, envoyer au scratch workspace et basculer le plein ecran.
- Ajout de `seven-terminal-native`, surface GTK/VTE qui fournit de vrais boutons
  traffic lights cliquables. `seven-terminal` l'utilise automatiquement quand
  `python-gobject` et `vte3` sont installes, puis retombe sur Kitty sinon.
- Le Launchpad SevenOS passe vers une grille plus native SevenOS : fond immersif,
  champ `Search` compact en haut, moins de cartes visibles, plus d'espace,
  icones plus grandes et selection glass legere. Spotlight reste reserve a la
  recherche systeme globale et aux actions intelligentes.
- Ajout de regles de fenetres pour dialogues fichiers, audio, reseau, aide SevenOS, migration et picture-in-picture afin que l'interface semble plus controlee et moins brute.

### Seven Hub

- Passage d'un simple launcher vers une logique de Control Center.
- Organisation par categories : Dashboard, Profiles, Cyber, Desktop, VM & Windows, Server & Deploy, Ecosystem, Installer, Apps.
- Ajout d'un Control Center web local.
- Fondation Tauri ajoutee pour une future vraie interface native.
- Ajout d'actions systeme contextuelles et de checks.
- Amelioration de la visibilite du Hub Rofi avec une largeur plus confortable.
- Les menus Hub restent encore bases sur Rofi, mais ils sont moins compresses et mieux contrastes.
- Debut de transformation du Hub Tauri en vrai Control Center natif.
- Ajout d'une navigation interne : Dashboard, Profiles, Security, Apps et System.
- Ajout d'un score readiness visible dans l'interface.
- Ajout de cartes services : Network, Firewall, Windows Mode, Seven Server.
- Ajout de cartes profils : Forge, Shield, Studio, Windows.
- Ajout de recommandations exploitables depuis l'interface.
- Ajout d'un backend Tauri `get_hub_snapshot` pour afficher l'etat systeme sans ouvrir un terminal.
- Connexion du Hub aux donnees JSON de SevenPkg pour les profils metiers.
- Ajout d'un workflow d'actions plus proche d'un vrai OS : labels explicites, niveaux d'impact, confirmation avant les actions sensibles, et retours lisibles dans le panneau de sortie.
- Connexion du Hub Tauri a `seven actions --json` : les cartes Security, Apps et System utilisent maintenant le registre central au lieu d'une liste statique locale.
- Ajout de l'execution par `action_id` via le backend Tauri, afin que le Hub lance une action SevenOS validee sans exposer directement des commandes arbitraires.
- Les actions dangereuses ou modificatrices ne partent plus au clic direct : le Hub demande confirmation avant installation, activation, reparation ou changement de profil.
- Le panneau de sortie distingue maintenant les etats `running`, `success` et `error`, avec un resume humain avant le detail technique.
- Amelioration de la maniabilite du Hub : vraie zone de contenu scrollable, navigation laterale lisible avec labels, hauteur adaptee au viewport, scrollbars integrees au design et changement de section plus naturel.
- Clarification strategique : Tauri reste un prototype de productisation, mais la cible OS devient Seven Hub Native en GTK4/libadwaita.
- Ajout de `seven-hub/native/README.md` pour definir les modules natifs, les contrats JSON et le chemin de migration.
- Ajout de `seven-hub-native`, prototype GTK/libadwaita centre sur Dashboard, Profiles et Actions, connecte a `seven readiness --json`, `seven profile status --json` et `seven actions --json`.
- Integration de `seven hub-native`, du lanceur desktop `seven-hub-native.desktop` et des wrappers d'installation.
- `seven-hub` devient la porte d'entree du Hub natif en session graphique, avec fallback menu/Rofi/terminal quand GTK n'est pas encore disponible.
- Les actions du Hub natif ouvrent maintenant un terminal visible pour les details, installations et actions systeme, afin d'eviter les boutons silencieux qui semblent decoratifs.
- `seven-hub doctor` audite le cablage des actions par categorie et detecte les entrees de menu qui ne menent a rien.
- Passage UI icon-first inspire par les references ML4W, GeoDots et end-4 : Waybar devient plus compacte, le Hub Rofi affiche icone + etat plutot que de longues phrases, et le Hub natif utilise des boutons symboliques avec tooltips.
- Approfondissement du shell SevenOS : Launchpad nettoye des identifiants `.desktop`, fallback d'icones par categorie, Quick Settings et Power Menu en lignes icon-first, panneaux Rofi plus arrondis et plus proches d'un control surface OS.
- Harmonisation des sous-surfaces shell : menus Waybar, Seven Files et Seven Help passent en icon-first avec nettoyage de selection, pour eviter les entrees purement textuelles et conserver des actions reelles.
- Ajout d'une surface Notifications dans Waybar : etat Mako, menu notification, test, restauration, dismissal, redemarrage du service et bascule Do Not Disturb via `seven-waybar-notifications`.
- Refonte shell Frost : Waybar en groupes capsules flottants, dry-run transforme en langage produit `DRY-RUN > Surface > Action`, et ajout de `seven-shell-preview` pour auditer Waybar, Rofi, Mako, fonts et commandes shell.
- Debut de sortie de Rofi pour les panneaux systeme : ajout de `seven-shell-panel` en GTK4/libadwaita pour Quick Settings et Notifications, avec fallback Rofi conserve si la stack native manque.
- Productisation session : ajout de `session/sevenos.desktop`, services utilisateur systemd `sevenos-session.target`, Waybar, notifications, wallpaper et idle, plus `seven-session-status` pour verifier que SevenOS se comporte comme une vraie session OS installable.
- Productisation packaging : ajout de `scripts/package-plan.sh`, generation de squelettes PKGBUILD depuis `sevenos.dotinst`, commandes `seven manifest package-plan|package-generate|package-doctor`, et documentation packaging pour preparer les paquets pacman SevenOS.
- Autonomie Windows Mode : ajout de `seven-windows-assistant`, avec statut JSON, guide grand public, ouverture Bottles, ouverture Virt Manager, relais VM et commandes `seven windows guide|apps|vm|open`.
- Les profils commencent a piloter l'experience : le panneau natif Quick Settings lit le profil actif et ajoute des actions contextuelles Forge, Shield, Studio, Windows, Horizon ou Baobab.
- Le registre d'actions expose maintenant des actions non decoratives pour l'activation de profils, l'ouverture de workspaces et Windows Mode, afin que Hub/Waybar puissent lancer de vrais flux utilisateur.
- `seven profile current --json`, `seven profile apps --json` et `seven profile guide` transforment les profils en contrats exploitables : apps disponibles, commandes de lancement, prochaines actions et workspace actif.
- `seven profile gaps --json` expose maintenant les paquets manquants, apps indisponibles, priorites et commandes d'installation pour transformer les profils en vrais modes metier pilotables.
- `seven profile plan --json` priorise les profils incomplets et alimente maintenant Control Plane, Insights, Seven Server et Seven Hub Native.
- Correction du contrat `seven windows status --json` : la sortie est maintenant du JSON strict, sans message humain ajoute par `install.sh`.
- Ajout de `seven windows plan` / `seven windows plan --json` : plan de compatibilite Windows priorise pour Wine, Bottles, KVM/libvirt, reseau et creation VM, expose dans l'etat unifie, Seven Server, Insights, Control Plane et Hub natif.
- Ajout de `seven installer plan` / `seven installer plan --json` : plan de readiness distribution pour Archinstall, Calamares, Archiso et ISO build, relie a `seven state`, Seven Server, Control Plane, Insights et Hub natif.
- Ajout de `sevenpkg plan` / `sevenpkg plan --json` : plan logiciel central pour meta-packages SevenOS, Flatpak, Flathub et applications par defaut, relie a `seven state`, Seven Server, Control Plane, Insights et Hub natif.
- `seven state --json` expose maintenant `active_profile` et `windows`, pour que le Hub natif puisse lire un etat OS complet sans parser des textes humains.
- Renforcement Seven Ecosystem : ajout d'un process map all-in-one (`seven ecosystem processes`), d'un contrat JSON (`seven ecosystem --json`) et integration de l'ecosysteme dans `seven state --json`.
- Le registre d'actions expose maintenant les actions Ecosystem Map, Process Map, Roadmap et Doctor pour Seven Hub et les futures surfaces natives.
- Fluidite Ecosystem : Seven Hub Native affiche les processus avec boutons de lancement, et `seven ecosystem summary` donne un resume compact modules/processus.
- Ajout de `seven experience` / `seven experience --json` : audit de coherence OS qui relie identite, shell, Hub, profils, actions, Windows, securite, serveur, installateur et ecosysteme.
- Consolidation Trust/Server : ajout de `seven shield status --json`, `seven server status --json`, endpoints `/experience` et `/shield`, et integration de `shield`/`server` dans `seven state --json`.
- Ajout de `seven control` / `seven control --json` : plan d'actions priorise qui fusionne readiness, experience, Shield, Server et profils pour guider Seven Hub comme un vrai centre de decision OS.
- Ajout de `seven control apply` : preview executable des corrections prioritaires, non destructif par defaut, avec execution explicite uniquement via `--apply`.
- `seven state --json` embarque maintenant `control`, afin que les futures surfaces Seven Hub/Server lisent les priorites OS depuis un snapshot unique.
- Ajout de `seven events` / `seven events --json` : journal local des decisions, previews et futures actions executees, expose dans `seven state --json` et Seven Hub Native.
- Ajout de `seven insights` / `seven insights --json` : synthese produit des limites actuelles, priorites et prochaines commandes, afin que Seven Hub ne montre pas seulement des donnees brutes.
- Ajout de `seven shield plan` / `seven shield plan --json` : plan de remediation Shield priorise, expose dans `seven state --json`, Seven Server, Control Plane, Insights et Seven Hub Native.
- Ajout de `seven server plan` / `seven server plan --json` : plan de remediation backend local pour transformer Seven Server en service pilotable, expose dans l'etat unifie, Control Plane, Insights et Hub natif.
- Ajout de `seven welcome status --json` et `seven welcome plan --json` : contrat de premiere ouverture qui detecte commandes, fichiers de session, services utilisateur, reseau, firewall et Windows VM apres reboot.
- `seven state --json`, Seven Server, Control Plane, Insights et Seven Hub Native consomment maintenant le plan First Run, afin que SevenOS puisse guider l'utilisateur vers un environnement complet sans lire un README ni deviner les commandes.
- Ajout de `seven session status --json` : contrat runtime de session SevenOS pour verifier entree de login, services utilisateur, Waybar, notifications, wallpaper et idle depuis Seven Hub, Seven Server et l'etat unifie.
- Renforcement African First : ajout de `identity/AFRICAN_FIRST.md`, composants SVG reutilisables, `seven identity --json`, endpoint `/identity`, carte African first dans le Hub natif et profils enrichis avec role, symbole, principe et recit.
- Ajout du contrat `identity/accent-packs.json` et de `seven identity packs --json`, pour preparer les variantes Pan-African, West, North, Central, East, Southern et Diaspora sans reduire l'interface aux drapeaux.
- Ajout de `seven identity current --json` et `seven identity activate <pack>` pour transformer les accent packs en preference utilisateur lisible par le Hub.
- Ajout de `seven phase-gate --json` comme contrat de passage B2 -> B3 : readiness, experience, control plane, Shield, Seven Server, installateur, Windows Mode, profils, logiciels et pack African first actif sont exposes dans une decision `pass/warning/blocked`.
- Ajout de `seven stack` / `seven stack --json` : strategie officielle d'adoption des technologies pour eviter l'empilement incontrôle. Ordre retenu : contrats JSON + Hub natif, puis Seven Shell AGS/TypeScript, puis seven-daemon Rust, puis IA Python, puis apps Flutter/Qt, puis Store/Cloud/Marketplace.
- Ajout de `seven b3 status`, `seven b3 plan --json` et `seven b3 apply` : orchestrateur de consolidation B2 -> B3 qui transforme les blocages principaux en sequence OS unique, dans l'ordre trust/Shield, Seven Server, profils concrets, Seven Shell AGS et installateur.
- Integration du plan B3 dans `seven state --json`, Seven Server (`/b3`), le registre `seven actions`, le Control Plane et les checks, afin que Seven Hub puisse presenter une route claire au lieu d'une collection de scripts disperses.
- Ajout des filtres `seven b3 plan/apply --phase trust|backend|profiles|shell|installer` et de `seven b3 doctor`, pour corriger les couches critiques une par une sans melanger securite, backend, profils, shell et installateur.
- Ajout de seuils B3 mesurables : Trust 70%, Backend 80%, Profiles 70%, Shell 65%, Installer 50%. `seven b3 status` affiche maintenant score, cible, gate, preflight sudo et blocages explicites.
- Ajout de `docs/B3_CONSOLIDATION.md` comme reference de phase : B3 ne passe que si les seuils sont atteints et qu'aucune action critique/high ne reste ouverte.
- Amelioration de `seven b3 apply` : les actions systeme sans session `sudo` sont marquees `BLOCKED` au lieu de casser tout le flux, pendant que les actions safe/manual restent consultables.
- Integration de B3 dans Seven Hub Native : le dashboard affiche maintenant le score B3, les seuils par phase et les prochaines actions de consolidation.
- Ajout de la fondation `seven shell` : statut, plan, doctor, preview, contrats `sevenos.shell.v1` et `sevenos.shell-plan.v1`, scaffold `seven-shell/ags` en TypeScript et endpoints Seven Server `/shell` et `/shell-plan`.
- Ajout de `seven context status|graph|plan --json` : SevenOS dispose maintenant d'un Context Engine qui transforme processus, fenetres Hyprland et profil actif en contexte humain (`Forge`, `Studio`, `Shield`, `Windows`, `Horizon`, `Streaming`, `Baobab`).
- Ajout de `docs/CONTEXT_ENGINE.md` : SevenOS est formule comme une plateforme Linux context-aware, capable de comprendre le workflow utilisateur au-dessus des PID/process.
- Ajout de `seven scheduler status|plan|apply` et `docs/SCHEDULING.md` : Seven Scheduler devient une couche user-space au-dessus de Linux CFS, sans remplacement kernel, avec politiques par groupe de contexte.
- Le Scheduler consomme maintenant le Context Engine : si l'utilisateur est en profil Baobab mais que les signaux indiquent Forge, la politique active devient Forge au lieu d'une simple lecture du profil.
- Le contrat Scheduler expose les bases futures `cgroups v2`, `systemd slices`, `CPUWeight`, `IOWeight` et `uclamp`, tout en gardant les changements destructifs ou opaques hors de la phase actuelle.
- `seven state --json`, Seven Server, Insights, Control Plane, le registre d'actions et les checks consomment maintenant `context` et `scheduler`, ce qui prepare Seven Hub et Seven Shell a piloter le systeme par intention utilisateur.
- Ajout de `seven context emit` : le contexte detecte est maintenant enregistrable dans SevenBus avec un payload `sevenos.context-event.v1`, ce qui transforme la detection ponctuelle en evenement systeme observable.
- SevenDaemon accepte maintenant `--payload-json` sur `emit`, et SevenBus declare les sources `context` / `scheduler`, premiere etape vers une boucle d'observation runtime moins dependante des scripts.
- Ajout de `seven core observe --json` : SevenDaemon peut maintenant declencher une observation de contexte ponctuelle et l'enregistrer dans SevenBus, premiere transition concrete vers une boucle runtime supervisee.
- Ajout de `seven-context-observer.service` et de `seven-daemon observe-loop` : le Context Engine peut maintenant fonctionner comme signal continu de session via systemd user, avec `seven core install-service` / `seven core start-observer`.
- Le plan B3 integre maintenant la mise en service de Seven Core runtime, afin que le backend ne se limite pas a Seven Server mais inclue aussi l'observation semantique locale.

### Gestion fichiers

- Ajout de Seven Files comme point d'entree utilisateur.
- Integration avec Nautilus, GVFS, MTP, SMB, File Roller, Sushi et XDG user dirs.
- Ajout de theme GTK/Qt clair pour eviter une experience visuelle incoherente entre apps et surfaces SevenOS.

### Terminal et branding

- Kitty harmonise avec la palette SevenOS.
- Ajout d'un signal culturel dynamique dans le terminal via pays africains aleatoires.
- Ajout du drapeau, nom, capitale et population.
- Ajout des fichiers branding : `motd`, `issue`, `os-release`, `sevenos-release`.

### Profils metiers

- Profil Forge pour developpement.
- Profil Shield pour cybersecurite.
- Profil Studio pour creation.
- Profil Windows pour compatibilite.
- Profil Server pour deploiement.
- Meta-packages dans `sevenpkg/metapackages.json`.
- Ajout d'un vrai gestionnaire de profils : `profiles/profile-manager.sh`.
- Les profils ne sont plus seulement des scripts d'installation : ils exposent maintenant un etat, un workspace, un accent, une activation et une sortie JSON exploitable par Seven Hub.
- `seven profile status --json`, `seven profile show <profil>`, `seven profile activate <profil>` et `seven profile install <profil>` deviennent la base de la logique metier SevenOS.
- Seven Hub lit maintenant les profils via `seven profile status --json` au lieu de dependre uniquement de `sevenpkg`.
- Les profils sont maintenant visibles dans le shell : l'utilisateur voit des actions adaptees a son mode courant au lieu d'une grille generique identique pour tout le monde.
- Les profils exposent aussi la disponibilite reelle des apps metier via `app_status`, afin de distinguer outil present, manquant et action de lancement.
- L'activation d'un profil cree maintenant un workspace structure, un `profile.json` local et une liste d'apps metier.
- `seven profile open <profil>` et `seven-files profile` ouvrent le workspace actif, avec raccourci Hyprland `Super+Ctrl+E`.
- Ajout de `seven profile bootstrap <profil|all>` : chaque profil genere maintenant un manifeste local `.sevenos/profile.json`, une checklist `.sevenos/CHECKLIST.md` et un lanceur `.sevenos/launch.sh` dans son workspace.
- Les actions `profile.bootstrap.active` et `profile.bootstrap.all` sont exposees au registre d'actions, afin que Seven Hub et Seven Shell puissent preparer les workspaces sans passer par des scripts caches.

### Cybersecurite

- Hardening systeme de base.
- Cyber Lab sandbox.
- Outils de security audit.
- Ajout de `seven shield bootstrap` et `seven shield workspace --json` : Shield genere maintenant un contrat local, une checklist, des notes sandbox et des launchers dans `~/ShieldLab/.sevenos`.
- Le plan Shield distingue maintenant la preparation workspace non destructive des actions systeme comme UFW, Firejail et les outils d'audit.

### Migration hors Bash

- Ajout de `seven-daemon profiles --json` et `seven core profiles --json` : SevenDaemon sait maintenant lire les profils depuis Rust, calculer paquets installes/manquants, apps disponibles et etat de bootstrap.
- Cette migration pose le premier moteur de profils daemon-native. `profiles/profile-manager.sh` reste le wrapper et le fallback, mais le contrat cible pour Seven Hub/Seven Shell devient Rust-owned.
- Ajout de `seven-daemon shield --json` et `seven-daemon shield-plan --json` : le posture Shield et son plan de remediation sont maintenant calcules par Rust, avec `security/shield-status.sh` conserve comme interface humaine/fallback.
- Ajout de `seven-daemon server --json` et `seven-daemon server-plan --json` : la readiness Seven Server, les dependances backend, le bind local et le plan de remediation serveur ont maintenant un contrat Rust-owned.
- Ajout de `seven-daemon windows --json` et `seven-daemon windows-plan --json` : Windows Mode a maintenant une readiness Rust-owned pour Wine, Bottles, KVM, libvirt, reseau et VM, pendant que l'assistant Bash reste la couche UX guidee.
- Ajout de `seven-daemon installer --json` et `seven-daemon installer-plan --json` : l'etat Archinstall, Calamares, Archiso, builder ISO et plan distribution sont maintenant lus par Rust, sans donner au daemon le pouvoir de modifier les disques.
- Ajout de `seven-daemon packages --json` et `seven-daemon packages-plan --json` : SevenPkg conserve l'interface utilisateur, mais le statut logiciel, les meta-packages et le plan Flatpak/Flathub sont maintenant calcules par Rust.
- Ajout de `seven-daemon insights --json` et delegation de `seven insights --json` : la synthese produit priorisee peut maintenant etre calculee par Seven Core sans attendre la grande aggregation Bash.
- Ajout de `seven-daemon phase-gate --json` et delegation de `seven phase-gate --json` : la decision B2 -> B3 dispose maintenant d'un contrat Rust rapide, pendant que le mode humain conserve les audits complets.
- Ajout de `seven shield dashboard`, `seven shield tools`, `seven shield labs`, `seven shield scope`, `seven shield open` et `seven shield report` : Shield devient un espace cyber natif avec posture, perimetre d'audit autorise, labs, outils, workspace, rapports et actions rapides, au lieu d'etre seulement une liste de paquets.
- Ajout de `seven shield mode`, `seven shield workspaces`, `seven shield context <name>`, `seven shield layout <name>` et `seven shield hud` : naissance de CyberSpace, une couche cyber orientee contexte qui relie Shield aux workspaces Hyprland, aux scopes, aux labs et au HUD.
- Hyprland expose maintenant `Super+C` pour CyberSpace et `Super+Ctrl+C` pour le Cyber HUD, avec les workspaces 1-9 alignes sur Recon, Web, Reversing, Network, Forensics, Exploit, Intel, Logs et Sandbox.
- Migration CyberSpace vers Seven Core : `seven-daemon cyberspace --json` et `seven-daemon cyberspace-plan --json` exposent maintenant la carte des contextes, l'etat du scope et le plan de remediation cyber. `seven state --json` et Seven Server exposent aussi `cyberspace` / `cyberspace-plan`.

## Daily Driver Consolidation

- Ajout de `seven daily`, `seven daily --json`, `seven daily plan` et `seven daily apply --yes` : SevenOS dispose maintenant d'un gate explicite avant installation sur PC principal.
- Le gate daily-driver mesure readiness, Shield/securite, profils metiers, Windows Mode, Seven Server, installateur et services Seven Core avec des seuils concrets pour usage quotidien.
- Ajout de `seven improve daily --apply --yes` : orchestration en une passe avec backup utilisateur, securite, profils, Windows Mode, serveur, installateur et services Core.
- Renforcement de `seven improve security` : installation hardening + Shield core + sandbox + bootstrap workspace + CyberSpace status.
- Renforcement de `seven improve compatibility` : Windows profile, Flatpak defaults/Bottles, KVM/libvirt checks, reseau VM et assistant Windows.
- Renforcement de `seven improve target` : bootstrap de tous les workspaces puis installation Forge, Shield, Studio, Windows et Horizon.
- Seven Server expose maintenant `/daily` pour que Seven Hub puisse afficher le gate PC principal sans parser le terminal.
- Integration possible de Firejail, UFW, Wireshark, nmap et autres outils.
- Strategie BlackArch documentee comme extension optionnelle, pas dependance obligatoire.

### Windows Mode

- Helpers VM Windows avec KVM/QEMU.
- Support VirtIO ISO.
- Detection/verification libvirt.
- Documentation VM et reseau.
- Strategie future : Bottles, Wine, Lutris, Looking Glass.

### Deploiement et serveur

- Ajout de la vision Seven Server.
- Ajout de `seven-server` comme fondation.
- Ajout de `seven-deploy` comme moteur initial de deploiement.
- Seven Server expose maintenant des endpoints locaux vivants : `/state`, `/status`, `/profiles`, `/readiness`, `/monitor/system`.
- Seven Server expose aussi `/manifest`, endpoint local pour les informations de packaging, migration et composants SevenOS.
- Documentation de la logique Personal Operating Cloud.
- Fondation pour transformer SevenOS en OS + plateforme de deploiement.

### Installateur et ISO

- Fondation Archiso ajoutee.
- Build ISO documente.
- Debut d'integration Calamares.
- Documentation test machine ajoutee.
- Scripts post-install et repair ajoutes.

## Niveau Par Domaine

| Domaine | Niveau | Etat |
|---|---:|---|
| Vision produit | 85% | Tres claire, bien documentee |
| Architecture repo | 80% | Modulaire et lisible |
| Design system | 80% | V1 en place, Launchpad Apps ajoute, coherence a tester sur machine reelle |
| Desktop Hyprland | 75% | Fonctionnel, Waybar actionnable, session plus robuste |
| Seven commands | 70% | Base solide, besoin de plus de robustesse |
| SevenPkg | 65% | Wrapper utile, sorties JSON ajoutees, pas encore vrai package manager |
| Seven Hub | 78% | Tauri prototype maintenu, premiere surface native GTK/libadwaita ajoutee, contrats JSON consolides |
| Profils metiers | 69% | Etat, activation, workspaces structures, metadata apps et ouverture directe ajoutes |
| Securite | 55% | Bonne direction, hardening a renforcer |
| Windows Mode | 50% | Base technique, UX guidee manquante |
| Serveur/deploy | 40% | Vision et scripts initiaux |
| Installateur ISO | 35% | Fondation, pas encore distribution installable grand public |
| Documentation | 75% | Bonne base, a maintenir avec chaque phase |
| Packaging/migration | 45% | Manifeste installable, composants futurs et chemins proteges ajoutes |

## Points A Consolider Maintenant

### 1. Seven Hub doit devenir une vraie application

Objectif :

```text
Remplacer la sensation "launcher de scripts" par un vrai Control Center SevenOS.
```

A faire :

- Dashboard visuel.
- Readiness score.
- Cartes systeme.
- Actions `Fix now`.
- Profils avec etats installes/partiels/manquants.
- Actions sans clic aveugle : confirmation, statut en cours, succes, erreur.
- Gestion theme/session.
- Statut firewall, VM, server, deploy.
- Version Tauri maintenue comme prototype.
- Construire progressivement une interface native GTK4/libadwaita pour les surfaces systeme.
- Remplacer progressivement les menus Rofi du Hub par une interface native, avec Tauri comme banc d'essai.

### 2. Installer reel

Objectif :

```text
Pouvoir installer SevenOS sur une machine test sans post-install fragile.
```

A faire :

- Finaliser Calamares.
- Clarifier partitionnement.
- Integrer post-install SevenOS.
- Creer premiere ouverture SevenOS.
- Generer ISO testable.
- Ajouter GitHub Actions pour valider les builds.

### 3. Coherence UI systeme

Objectif :

```text
Eviter l'effet "theme Arch" et donner une experience OS complete.
```

A faire :

- Tester GTK/Qt apps en conditions reelles.
- Tester le nouveau Launchpad Apps sur machine test : densite, taille des icones, lisibilite des labels.
- Harmoniser Nautilus, menus, notifications, terminal.
- Ajouter assets plus premium.
- Construire des composants Seven Hub reutilisables.
- Revoir les autres menus Rofi pour les rapprocher du niveau du Launchpad Apps.

### 4. Profils metiers plus concrets

Objectif :

```text
Chaque profil doit transformer le systeme de maniere visible et utile.
```

En place :

- Gestionnaire central `profiles/profile-manager.sh`.
- Etat `OK/PART/MISS` par profil.
- Profil actif persistant dans `~/.config/sevenos/profile.env`.
- Metadata active persistante dans `~/.config/sevenos/profile.json`.
- Workspaces utilisateurs : `~/Forge`, `~/ShieldLab`, `~/Studio`, `~/WindowsMode`, `~/HorizonDeploy`.
- Sortie JSON stable pour Seven Hub.

A faire ensuite :

- `seven profile forge` : dev complet + services + shortcuts.
- `seven profile shield` : sandbox + audit + lab + firewall.
- `seven profile studio` : apps creatives + presets + file associations.
- `seven profile windows` : Bottles + VM assistant.
- `seven profile server` : deploy + monitoring local.

### 5. Securite active par defaut

Objectif :

```text
SevenOS doit etre un OS de confiance, pas seulement un desktop elegant.
```

A faire :

- UFW active proprement.
- Firejail/Bubblewrap mieux integres.
- Indicateur security dans Waybar et Hub.
- Audit de permissions.
- AppArmor en phase suivante.

### 6. SevenPkg doit devenir intelligent

Objectif :

```text
Passer d'un wrapper pacman a une couche logiciel SevenOS.
```

A faire :

- Recherche pacman/Flatpak/AUR.
- Installation de meta-packages.
- Source selection : Arch, Flatpak, AUR, SevenRepo futur.
- Post-configuration automatique.
- Export JSON pour Seven Hub.

## Roadmap Courte

### Phase A — Stabilisation UI

- Tester Design System v1 sur machine test.
- Corriger lisibilite, contrastes, app launcher et menus.
- Valider le Launchpad Apps plein ecran.
- Valider Waybar comme barre de controle active.
- Ameliorer Seven Files.
- Stabiliser Waybar/Hub/session.

### Phase B — Control Center

- Transformer Seven Hub Tauri en app principale.
- Ajouter dashboard, readiness, profiles, apps, security, VM, deploy.
- Connecter `seven` et `sevenpkg` au Hub.
- Standardiser les sorties JSON des commandes systeme.
- Ajouter confirmations pour les actions sensibles.
- Ajouter progress states pour les installations longues.
- Transformer les sorties brutes en messages utilisateur lisibles.
- Faire de Rofi un fallback, pas l'interface principale.

### Phase C — Distribution testable

- Utiliser `sevenos.dotinst` comme contrat d'installation et de migration.
- Transformer les composants du manifeste en paquets pacman SevenOS.
- Preserver les chemins declares par `seven manifest restore-plan` pendant les upgrades.
- Finaliser Calamares.
- Generer ISO live.
- Creer install flow complet.
- Tester sur machine physique et VM.

### Phase D — Ecosysteme

- SevenPkg avance.
- Flatpak/SevenRepo.
- Seven Server + Seven Deploy.
- Cloud personnel et backup.

## Definition Du Succes

SevenOS passe au niveau superieur quand un utilisateur peut :

- Installer SevenOS sans suivre dix commandes manuelles.
- Ouvrir Seven Hub et comprendre l'etat du systeme.
- Installer un profil metier en un clic ou une commande.
- Lancer ses apps Linux et Windows avec une experience claire.
- Voir une interface coherente partout.
- Se sentir dans un OS complet, pas dans une configuration Arch.

## Etat Git

Dernier grand jalon connu :

```text
68d460e Make app launcher SevenOS style
```

Jalons recents :

```text
b2736d2 Apply SevenOS design system v1
96850bf Fix Waybar startup compatibility
cc25e63 Make Waybar modules actionable
2f8b52e Improve Rofi menu visibility
68d460e Make app launcher SevenOS style
a31e630 Shift SevenOS design to transparent minimal glass
```

Ces jalons introduisent le Design System v1, stabilisent Waybar, rendent la barre plus actionnable, ameliorent la lisibilite des menus Rofi et transforment le lanceur d'applications en experience plein ecran adaptee a SevenOS Launchpad.

Travail en cours :

```text
Native Launchpad
Seven Files SevenOS Files surface
SevenOS native terminal
```

Objectif : remplacer les surfaces trop "script/theme" par des surfaces OS
natives quand les dependances sont presentes, avec Rofi/Kitty uniquement comme
fallback.

Avancement UI :

- Terminal natif GTK/VTE ajoute avec vraies pastilles rouge/jaune/verte
  dessinees directement, donc moins dependant du theme GTK.
- `seven-terminal status` indique si le terminal natif est actif ou si les
  dependances `python-gobject` et `vte3` manquent.
- Les surfaces natives GTK detectent maintenant pyenv et se relancent via
  `/usr/bin/python` quand les bindings systeme `gi` sont masques.
- Launchpad natif GTK ajoute : grille plein ecran, grandes icones, filtre
  compact et fermeture par Escape. Rofi reste le fallback.
- Seven Files a maintenant une vraie surface native SevenOS Files :
  sidebar, pastilles, barre de navigation, grandes icones et fallback Nautilus.
- Seven Files separe maintenant clairement "ouvrir une image" et "definir un
  wallpaper" : le clic ouvre une preview native, le wallpaper passe par une
  action explicite du clic droit.
- Le clic droit Seven Files expose des actions SevenOS Files : Open, Reveal,
  Copy Path, Set as Wallpaper pour les images, Properties.
- Les associations MIME SevenOS evitent maintenant de transformer
  `seven-wallpaper.desktop` en application par defaut des images.
- Le bouton jaune des surfaces natives suit la logique Hyprland : reduction
  vers le special workspace SevenOS quand la session Wayland le permet, avec
  fallback GTK classique.
- Ajout de `seven-dock` / `seven-dock-native` : dock liquid glass inspire de
  SevenOS, togglable avec `Super+D`, avec Files, Apps, Browser, Terminal,
  Spotlight, Hub et Settings.
- Refonte Waybar vers une barre superieure plus native SevenOS : Apps + heure a
  gauche, workspaces au centre, controles systeme compacts a droite.
- Checks design/UX mis a jour pour proteger ces surfaces.

Jalon en cours :

```text
Phase B — Seven Hub native Control Center
```

Ce jalon transforme le Hub Tauri en premiere vraie surface OS : dashboard, profils, securite, apps, systeme, readiness score et backend snapshot.

## Regle De Progression

Chaque nouvelle amelioration doit repondre a au moins une question :

- Est-ce que SevenOS devient plus simple a utiliser ?
- Est-ce que SevenOS devient plus coherent visuellement ?
- Est-ce que SevenOS devient plus robuste techniquement ?
- Est-ce que SevenOS devient plus proche d'un vrai OS autonome ?
- Est-ce que SevenOS renforce son identite souveraine, fluide et ancree ?

Si la reponse est non, l'amelioration doit etre repoussee ou repensee.

## 2026-05-17 - Dock and Waybar polish pass

- Le dock SevenOS gagne une presence plus native SevenOS : surface plus large, coins plus doux, icones plus grandes, separation entre apps et controles systeme, et effet de magnification au survol.
- Les icones du dock ont maintenant des surfaces colorees distinctes pour mieux differencier Files, Apps, Browser, Terminal, Spotlight, Hub et Settings sans surcharger l'interface.
- La Waybar est encore affine dans une logique menu-bar premium : capsules plus respirantes, contraste glass plus lisible, workspaces plus doux et etats hover/actif plus polis.
- Les regles Hyprland suivent la nouvelle taille du Dock afin d'eviter l'impression d'un panneau trop petit ou mal pose.

## 2026-05-17 - Waybar Seven menu and compact Dock

- La Waybar adopte une lecture plus native SevenOS et plus SevenOS : `7`, `Apps` et l'heure forment le menu systeme de gauche, les workspaces restent au centre, et les controles systeme sont regroupes a droite.
- La hauteur de la barre est reduite avec des capsules plus fines pour eviter l'effet "barre custom Arch" et donner une sensation plus proche d'un vrai menu-bar d'OS.
- Le Dock est fortement compacte : cadre moins large, hauteur reduite, icones plus petites, margin inferieur plus discret et position plus ergonomique.

## 2026-05-17 - Dock workflow foundation

- Le Dock devient un vrai composant de workflow : configuration persistante dans `~/.config/sevenos/dock.json`, commandes `seven-dock pin`, `seven-dock unpin` et `seven-dock settings`.
- Le Dock separe les apps epinglees, les dossiers (`Downloads`, `Home`) et les actions systeme, comme un dock d'OS plutot qu'une simple barre de lancement.
- Les icones affichent des indicateurs d'execution bases sur les processus, un badge de notifications sur le Hub quand disponible, et des menus clic droit avec ouvrir, afficher les fenetres, quitter, forcer a quitter, garder ou retirer du Dock.

## 2026-05-17 - Spotlight command brain expansion

- Spotlight devient un centre de recherche plus proche de SevenOS Spotlight/Raycast : apps, fichiers, settings, actions SevenOS, fenetres Hyprland actives, clipboard, historique de recherche, bookmarks Firefox, calculs, conversions, definitions, mail, contacts, calendrier et actions rapides.
- Ajout des filtres `/clipboard`, `/windows` et `/history`, en plus de `/apps`, `/files`, `/settings`, `/system` et `/web`.
- Ajout de requetes directes : `timer 5`, `record audio`, `content <texte>`, `define <mot>`, `web <requete>`, expressions mathematiques et conversions.
- Le theme Spotlight est elargi et clarifie : placeholder plus explicite, lignes plus hautes, icones plus visibles et message de categories plus riche.

## 2026-05-17 - Waybar singleton repair

- Ajout de `seven-waybar` pour gerer proprement la barre : `status`, `repair`, `restart`, `stop`.
- Le service utilisateur `sevenos-waybar.service` coupe toute instance Waybar existante avant de lancer la barre SevenOS, afin d'eviter les doubles barres apres installation, theme reload ou migration ML4W.
- La documentation de test remplace le lancement manuel `waybar &` par `seven-waybar repair`.

## 2026-05-17 - Native Spotlight refonte

- Ajout de `seven-spotlight-native`, une surface GTK compacte qui remplace le
  rendu Rofi par defaut pour `Super+Space`.
- Au repos, Spotlight affiche uniquement une barre de recherche et des icones de
  categories : apps, fichiers, reglages, actions, web, clipboard, fenetres et
  historique. Les resultats n'apparaissent qu'apres saisie ou selection d'une
  categorie.
- `seven-spotlight` garde le catalogue universel et devient le routeur d'actions
  pour la surface native, avec fallback explicite :
  `SEVENOS_SPOTLIGHT_NATIVE=0 seven-spotlight rofi`.
- L'installation CLI, les checks design/UX et la documentation Primary/Test
  Machine protegent maintenant cette experience.

## 2026-05-17 - Liquid Glass OS refonte pass

- Ajout de `identity/LIQUID_GLASS_OS.md` comme reference produit pour la
  direction SevenOS-grade sans copie : menu bar, Dock, fenetres a sidebar,
  Spotlight calme et surfaces d'OS actionnables.
- Waybar est affinee vers une vraie menu bar liquide : contraste plus lisible,
  verres plus propres, hover plus subtil et separation gauche/centre/droite plus
  calme.
- Dock natif compacte et poli : cadre plus petit, icones legerement reduites,
  magnification plus douce et surface plus proche d'un dock que d'un panneau.
- Seven Files gagne une matiere SevenOS Files plus coherente : sidebar translucide,
  toolbar claire, canvas stable et preview plus douce.
- Spotlight natif conserve son ouverture minimaliste mais avec un glass plus
  lisible et une iconographie plus presente.

## 2026-05-17 - Notification Center UX pass

- Le panneau Notifications n'affiche plus une liste de modes techniques en
  premier. Il montre directement les notifications actives ou un etat vide clair
  `No notifications`.
- Les actions de notification deviennent secondaires et icon-only dans la
  surface native : test, restore, dismiss, focus/DND et restart.
- Le fallback Rofi de `seven-waybar-notifications` affiche aussi le flux de
  notifications avant les actions, afin d'eviter le rendu trop textuel de type
  menu admin.
- Les checks design/UX protegent maintenant cette direction orientee contenu.

## 2026-05-17 - Notification Center native surface

- Ajout de `seven-notification-center-native`, un centre de notifications GTK3
  dedie qui s'ouvre depuis la Waybar avant tout fallback Rofi ou panneau
  generique.
- La surface est maintenant contenu-first : cartes de notifications, etat vide
  calme et bande d'actions en icones uniquement avec tooltips.
- `seven-waybar-notifications menu` route vers ce centre natif, puis retombe sur
  `seven-shell-panel`, puis Rofi seulement si la stack native n'est pas
  disponible.
- Les regles Hyprland, l'installation CLI et les checks design/UX savent
  verifier cette surface comme un composant OS, pas comme une liste d'actions.

## 2026-05-17 - Quick Settings native Control Center

- Ajout de `seven-quick-settings-native`, une surface GTK3 dediee qui remplace
  le rendu grille textuelle pour les Quick Settings.
- Le panneau adopte une logique SevenOS Control Center : tuiles Wi-Fi,
  Bluetooth, Focus et Profil, sliders Sound/Display, puis actions systeme en
  icones compactes.
- `seven-quick-settings` ouvre cette surface native en priorite, garde
  `seven-shell-panel quick` comme fallback et n'utilise Rofi qu'en dernier
  recours.
- Les checks design/UX protegent le nouveau contrat : Quick Settings ne doit
  plus se presenter comme une liste repetitive de commandes.

## 2026-05-17 - Seven Hub compact OS dashboard

- Seven Hub Native passe en rendu compact par defaut : dashboard a metriques,
  raccourcis icon-only, tuiles d'etat et sections visuelles au lieu d'une longue
  page d'audit textuelle.
- Les pages Profiles, Actions et Ecosystem utilisent maintenant des grilles de
  tuiles native SevenOS avec les details en tooltips ou actions secondaires.
- Les anciens contrats JSON restent consommes, mais la presentation devient plus
  OS Control Center : moins de texte, moins de repetition, plus d'etats visuels.
- Les checks design/UX verifient la presence du rendu compact
  `render_dashboard_compact`, des tuiles `seven-tile` et des surfaces glass.

## 2026-05-17 - Waybar Profile and Shield native centers

- Les modules Profile et Shield de la Waybar deviennent icon-only avec tooltips
  utiles, afin d'eviter les libelles repetitifs dans la barre.
- Ajout de `seven-profile-center-native` : centre compact pour voir le profil
  actif, changer ou installer Forge, Shield, Studio, Windows, Horizon et Baobab.
- Ajout de `seven-shield-center-native` : centre compact pour lire la posture
  Shield, les points ouverts et les actions trust prioritaires.
- `seven-waybar-action profile` et `seven-waybar-action security` ouvrent ces
  surfaces natives en priorite, avec Rofi uniquement comme fallback.
- Waybar colore subtilement Profile/Shield selon etat OK/PART/MISS dans le style
  liquid glass actuel.

## 2026-05-17 - Waybar system centers pass

- Ajout de `seven-waybar-center-native`, une surface GTK3 commune pour Wi-Fi,
  Audio, Power, System et Time.
- Les modules Network, Audio et Battery deviennent plus compacts dans la Waybar :
  icone dans la barre, etat detaille en tooltip, panneau natif au clic.
- Le panneau Network expose etat Wi-Fi, connexion active, connect/settings/status
  et restart sans menu textuel repetitif.
- Le panneau Audio expose volume, mute state, slider direct et actions Mixer,
  Mute, Status et Settings.
- Le panneau Power expose batterie/session avec actions Lock, Restart, Power et
  Power Profiles.
- Les modules CPU/Mem/Clock passent aussi par la meme logique de centre natif,
  pour garder une experience menu-bar coherente.

## 2026-05-17 - SevenOS Settings native

- Ajout de `seven-settings-native`, une application GTK3 complete pour les
  reglages utilisateur normaux : apparence, wallpaper, ecrans, Wi-Fi, son,
  clavier, securite, profils, energie, apps et maintenance systeme.
- Ajout du wrapper `seven-settings`, du fichier desktop
  `seven-settings.desktop`, de l'installation CLI et du raccourci `Super+,`.
- Spotlight indexe maintenant `Settings · SevenOS Settings`, tandis que Seven
  Hub affiche un acces direct Settings dans ses raccourcis et tuiles.
- Les checks design/UX protegent ce nouveau centre afin que les reglages ne
  redeviendront pas une collection de scripts ou menus Rofi.

## 2026-05-17 - Settings daily usability fix

- Correction du lancement de `seven-settings-native` : l'app GTK3 utilisait une
  methode GTK4 (`set_wrap`) et ne s'ouvrait pas correctement.
- La Waybar ne lance plus Quick Settings comme entree principale : le module
  systeme ouvre maintenant `seven-settings`, avec Seven Hub et Spotlight comme
  actions secondaires.
- Les reglages SevenOS incluent maintenant les mises a jour systeme via
  `seven update`, plus l'etat paquet via `sevenpkg status`.
- Kitty accepte les flux de copie/coller quotidiens : selection vers presse-
  papiers, `Ctrl+Shift+C` pour copier et `Ctrl+Shift+V` pour coller dans les
  profils Classic et Dark.

## 2026-05-17 - Settings polish and terminal clipboard native

- `seven-settings-native` gagne une page d'accueil plus fluide : carte hero,
  raccourcis ronds icon-only et cartes plus compactes pour un rendu plus proche
  d'un panneau systeme native SevenOS.
- Le terminal natif VTE gere maintenant lui aussi le presse-papiers :
  `Ctrl+Shift+C`, `Ctrl+Shift+V`, `Ctrl+Insert`, `Shift+Insert`, plus un menu
  clic droit avec Copy, Paste, Select All et Clear.
- Les checks UX protegent la correction pour eviter que le copier/coller ne
  depende uniquement de Kitty quand SevenOS lance le terminal natif.

## 2026-05-17 - Settings compact professional layout

- Refonte de la densite de `seven-settings-native` apres test visuel sur machine
  principale : la fenetre passe a un format plus contenu, la sidebar est plus
  fine et le contenu principal est limite en largeur au lieu de s'etirer sur
  tout l'ecran.
- Les pages Settings utilisent maintenant des grilles de cartes en deux colonnes
  pour eviter les grandes lignes vides et donner une lecture plus proche d'un
  vrai panneau de reglages OS.
- Les cards, raccourcis rapides et statuts ont ete reduits et resserres :
  moins d'espace inutile, meilleure hierarchie, plus de lisibilite.
- Checks relances : `design-check`, `ux-check`, probe GTK et installation CLI
  utilisateur OK.

## 2026-05-17 - Settings controlled zoom

- Correction du comportement en mode agrandi : le bouton vert ne maximise plus
  l'app en plein ecran, il applique un zoom utile `980x660 <-> 1080x690` comme un
  panneau de reglages native SevenOS.
- Le contenu des pages Settings s'ancre maintenant a gauche dans une largeur
  controlee, au lieu de se centrer dans une immense zone vide quand la fenetre
  est forcee en grand format.
- Les cartes gardent des largeurs fixes professionnelles (`status` compact,
  cartes fonctionnelles en 2 colonnes), ce qui evite les lignes trop longues et
  l'effet dashboard web.

## 2026-05-17 - Settings Hyprland size discipline

- Alignement de la regle Hyprland avec la nouvelle ergonomie Settings :
  `SevenSettingsNative` et `SevenOS Settings` s'ouvrent maintenant en `980x660`
  au lieu de `1080x720`.
- Ajout de contraintes GTK min/max (`980x660` a `1080x690`) pour empecher le
  panneau Settings de se transformer en surface plein ecran trop vide.
- Rechargement de la session Hyprland et verification de la config active dans
  `~/.config/hypr/hyprland.conf`.

## 2026-05-17 - Notification center backend repair path

- Diagnostic du module Notifications Waybar : le centre natif etait present,
  mais le backend `mako` etait absent sur la machine principale, ce qui mettait
  `sevenos-notifications.service` en boucle d'echec `status=127`.
- `seven-waybar-notifications` distingue maintenant clairement les etats
  `running`, `inactive` et `backend missing`, et expose une action `Install`
  qui ouvre un terminal avec l'installation `mako + libnotify`.
- `seven-notification-center-native` affiche un etat utile quand le backend est
  manquant ou arrete, avec bouton principal `Install` ou `Start` au lieu d'un
  centre vide.
- La config Waybar appelle maintenant explicitement la version utilisateur
  `~/.local/bin/seven-waybar-notifications` avant tout wrapper systeme stale de
  `/usr/local/bin`.
- `sevenos-notifications.service` ne boucle plus en echec si `mako` manque : il
  sort proprement et laisse le centre expliquer l'action a effectuer.

## 2026-05-17 - Improve/profile apply flag fix

- Correction du bug `seven profile install shield --yes` : `install.sh` filtre
  maintenant les flags globaux `--yes` et `--dry-run` avant de transmettre les
  arguments aux scripts de profil. `--yes` n'est donc plus confondu avec une
  categorie cyber.
- Les targets qui deleguent a d'autres scripts utilisent maintenant
  `TARGET_ARGS`, ce qui stabilise aussi `cybersecurity core --yes`,
  `daily-driver --yes`, `flatpak --yes`, VM, ISO et installer.
- `seven improve ... --apply --yes` affiche maintenant une ligne `running:` pour
  chaque etape executee, afin de distinguer clairement un plan d'une execution.
- Validation dry-run : `profiles/profile-manager.sh install shield --yes` ne
  produit plus `Unknown cybersecurity category: --yes`.

## 2026-05-17 - Daily driver gate hardening pass

- `seven profile install shield` bootstrappe maintenant aussi le vrai workspace
  Shield natif (`~/ShieldLab/.sevenos/shield.json`, scope, checklist,
  launchers). Le statut Shield ne confond plus le workspace generique du profil
  avec l'espace cyber operationnel.
- Shield est passe de `71%` a `86%` apres bootstrap local ; le dernier manque
  critique cote Shield est l'activation UFW via `seven shield enable`.
- `seven-daemon` est installe comme commande utilisateur et les services
  systemd user utilisent `~/.local/bin/seven-daemon` au lieu de dependre du PATH
  limite de systemd. Les services `seven-daemon.service` et
  `seven-context-observer.service` demarrent maintenant correctement.
- `seven core start` reset les services en echec avant redemarrage, ce qui evite
  le blocage `start-limit-hit` apres un ancien wrapper manquant.
- Le gate daily-driver lit maintenant l'etat Core depuis `scripts/core.sh
  status --json`, donc les services Core actifs sont visibles dans la decision
  OS principale.
- `install.sh cli` place `~/.local/bin` en priorite pour eviter les wrappers
  systeme obsoletes. La commande `seven improve --apply` signale explicitement
  si `SEVENOS_DRY_RUN=1` force encore un simple preview.

## 2026-05-17 - UFW degraded firewall handling

- `seven shield enable` ne plante plus en traceback Python quand UFW echoue sur
  `ufw-init` / iptables / nftables. L'installation continue et SevenOS affiche
  un diagnostic noyau/netfilter lisible.
- Quand UFW est installe mais que ses regles ne s'appliquent pas correctement,
  SevenOS ecrit maintenant un marqueur
  `~/.local/state/sevenos/security/ufw-degraded`.
- `seven shield status` et `seven-daemon shield --json` lisent ce marqueur et
  affichent le firewall en `PART` au lieu de pretendre que tout est parfaitement
  fiable.
- Etat apres correction : readiness `89%`, security `100%`, Shield `93%`, Core
  services `RUN`. Le blocage daily-driver restant est `Target Use`, c'est-a-dire
  les profils Studio / Windows / Horizon encore trop partiels.

## 2026-05-17 - Apply execution condition fix

- Correction d'un bug Bash subtil : `[[ "$APPLY" -eq 1 && ! is_dry_run ]]`
  ne lancait pas la fonction `is_dry_run`, donc `seven improve ... --apply`
  restait en mode preview et affichait `command:` au lieu de `running:`.
- La condition est maintenant ecrite correctement :
  `[[ "$APPLY" -eq 1 ]] && ! is_dry_run`.
- Le meme piege a ete corrige dans `scripts/repair.sh`,
  `scripts/control-plane.sh` et `vm/windows-app-runner.sh`.
- Validation : sans session sudo active, `seven improve target --apply --yes`
  echoue proprement avec un message sudo ; avec `SEVENOS_DRY_RUN=1`, il reste en
  preview explicite.

## 2026-05-17 - Flatpak Studio profile bridge

- Correction de `scripts/flatpak.sh` : l'appel inexistant `install_packages`
  a ete remplace par une installation Arch explicite de `flatpak`, compatible
  `--yes` et dry-run.
- Les installations Flatpak par defaut sont maintenant idempotentes : les apps
  deja presentes sont sautees, et les nouvelles apps utilisent
  `flatpak install --noninteractive --or-update -y`.
- Le bundle Flatpak par defaut couvre maintenant le socle Studio utile :
  Blender, GIMP, Inkscape, Kdenlive, Krita, OBS, Audacity, Darktable,
  RawTherapee, Scribus, LMMS et HandBrake.
- Les profils SevenOS, cote Bash et cote `seven-daemon`, reconnaissent les
  equivalents Flatpak officiels comme satisfaisant les besoins Studio. Cela
  evite de bloquer le daily gate si une app creative est installee via Flathub
  plutot que via pacman.
- Etat local avant installation des apps Studio : daily readiness `95%`,
  security/shield/compatibility/deployment `100%`, seul blocage restant :
  `Daily role profiles` a cause du profil Studio non installe.

## 2026-05-17 - Package conflict equivalence

- Correction du conflit Forge entre `code` et `visual-studio-code-bin` :
  SevenOS reconnait maintenant `visual-studio-code-bin`, `vscodium-bin` et
  `vscodium` comme equivalents valides du paquet Arch `code`.
- `install_package_file` filtre les paquets deja satisfaits par une alternative
  avant d'appeler `pacman -S`, ce qui evite les prompts de conflit non
  resolubles en mode `--yes`.
- Le calcul des profils Bash et `seven-daemon` utilise la meme equivalence, donc
  Forge ne reste plus partiel uniquement parce que l'utilisateur prefere la
  variante AUR de VS Code.

## 2026-05-17 - Primary PC gate ready

- Installation de la fondation installer TUI via `seven installer install` :
  `archinstall`, `arch-install-scripts`, outils de partitionnement et schemas
  Python sont presents.
- `seven installer status` affiche maintenant `archinstall: OK`, planner `OK`,
  profil Calamares `OK`, Archiso `OK` et ISO builder `OK`.
- `seven daily` passe officiellement a `Decision: ready` avec readiness,
  security, Shield, target use, compatibility et deployment a `100%`.
- Tous les gates daily-driver sont maintenant en `PASS`, y compris
  `Installer foundation tui-ready -> tui-ready` et les services Core
  `daemon=RUN, observer=RUN`.
- Calamares reste `MISS`, mais ce n'est plus bloquant pour la machine
  principale : le chemin TUI/recovery via Archinstall est disponible.

## 2026-05-17 - Waybar Wi-Fi simplification

- Le clic gauche sur l'icone Wi-Fi de Waybar ouvre maintenant directement le
  panneau Wi-Fi unique (`seven-wifi menu`) au lieu d'un centre d'actions trop
  charge ou de plusieurs chemins concurrents.
- Le panneau affiche d'abord l'action activer/desactiver, puis le Wi-Fi
  connecte, puis la liste des reseaux proches.
- Le reseau actif est retire de la liste des reseaux proches pour eviter les
  doublons visuels : une ligne d'etat connecte, puis uniquement les autres
  SSID disponibles.
- Le clic milieu deconnecte le Wi-Fi actif, et le clic droit ouvre les reglages
  NetworkManager avances.
- `seven-wifi connect` scanne les reseaux avec signal, securite et etat actif,
  affiche une liste compacte, reutilise les connexions NetworkManager deja
  enregistrees, et ne demande le mot de passe que pour les nouveaux reseaux
  proteges.
- Le menu Wi-Fi a ete retire des onglets/actions secondaires : le flux normal
  reste toggle + connecte + reseaux disponibles.
- Le centre Waybar reseau affiche maintenant etat, reseau et signal avec des
  actions directes `Choose`, `On / Off`, `Disconnect` et `Settings`.
- La configuration active `~/.config/waybar/config.jsonc` a ete reappliquee via
  `./install.sh theme`; Waybar tourne avec une seule instance.

## 2026-05-17 - Waybar feature-first interaction pass

- La logique Wi-Fi simple est etendue aux autres modules Waybar : clic gauche
  vers une surface fonctionnelle, clic droit vers le reglage logique, clic milieu
  seulement pour une action rapide claire.
- Les clics droits qui ouvraient des terminaux bruts pour Time, CPU, Memory,
  Security, Audio et Power sont remplaces par des entrees directes vers
  `seven-settings` et les centres natifs.
- `seven-waybar-action` reduit ses fallbacks a des menus courts orientes
  fonctionnalites : Settings, Monitor, Updates, Repair UI, Profile Center,
  Workspace, Shield Center, Wi-Fi Panel, Mixer, Lock, Sleep et Calendar.
- `seven-waybar-center-native` devient plus actionnable : panneaux Wi-Fi, Sound,
  Power, System et Time avec metriques utiles, hints courts et actions en icones
  coherentes avec le style liquid glass.
- `seven-settings-native` accepte maintenant une page initiale
  (`seven-settings sound`, `seven-settings power`, `seven-settings profiles`,
  etc.), pour que Waybar ouvre directement le bon contexte sans navigation
  supplementaire.

## 2026-05-17 - Seven Files compression and keyboard pass

- Seven Files natif ajoute une action `Compress` dans le menu contextuel et un
  bouton toolbar pour creer une archive `.zip` a cote de l'element selectionne.
- La compression utilise le module Python standard `zipfile`, respecte les
  dossiers recursifs et choisit automatiquement un nom libre (`name.zip`,
  `name 2.zip`, etc.).
- La navigation clavier est explicitement geree dans la grille : fleches gauche,
  droite, haut et bas changent la selection, `Enter` ouvre, `Backspace` revient
  en arriere.
- Les raccourcis de fichier restent coherents : `Ctrl+C`, `Ctrl+X`, `Ctrl+V`
  pour copier/couper/coller, et `Alt+C` pour compresser l'element selectionne.
- Les checks UX protegent maintenant la compression, le menu contextuel, la
  navigation clavier et le double-clic comme comportements attendus de Seven
  Files.

## 2026-05-17 - Seven Files default manager and modern file operations

- La compression n'est plus immediate : Seven Files affiche un dialogue pour
  choisir le nom de l'archive et le format (`zip`, `tar.gz`, `tar.xz`) avant de
  creer le fichier.
- La copie publie maintenant un clipboard de fichiers compatible avec les
  gestionnaires modernes (`x-special/gnome-copied-files`, avec fallback
  `text/uri-list` en lecture), au lieu de se limiter a du texte; le collage peut
  aussi reprendre un clipboard fichier externe.
- La preview laterale affiche une vignette reelle pour les images selectionnees,
  et `Space` ouvre la preview Seven Files avant ouverture externe.
- `seven-files.desktop` declare `inode/directory` et
  `application/x-gnome-saved-search`; `apply-theme` definit Seven Files comme
  gestionnaire par defaut des dossiers via `xdg-mime`.
- `seven-files` accepte aussi les URI `file://...` envoyees par le systeme et
  les normalise avant d'ouvrir Seven Files natif.

## 2026-05-17 - Seven Files Quick Look and real file clipboard

- La copie evite maintenant de publier un simple chemin texte quand Wayland ou
  X11 fournit un clipboard fichier : `wl-copy`/`xclip` expose le type
  `x-special/gnome-copied-files`, et Seven Files garde son clipboard interne
  pour un collage fiable.
- Le collage peut relire un clipboard fichier externe (`x-special` ou
  `text/uri-list`) afin de copier des elements depuis un autre gestionnaire vers
  Seven Files.
- La preview devient un Quick Look SevenOS : images en grand, texte/code en
  lecture seule, extraction texte DOCX, premiere page PDF via `pdftoppm`, et
  thumbnails video via `ffmpegthumbnailer` quand les paquets sont installes.
- La preview laterale affiche maintenant les vignettes PDF/video disponibles et
  `Space` ouvre Quick Look pour images, videos, PDF, DOCX, TXT, Markdown, code
  et fichiers de configuration.
- `scripts/packages-base.txt` inclut `ffmpegthumbnailer` et `poppler` pour que
  les previews video/PDF soient installees avec la base SevenOS.

## 2026-05-17 - Seven Files Finder-grade interaction pass

- La copie Seven Files est renforcee avec un clipboard persistant dans
  `~/.cache/sevenos/files-clipboard.json` et une publication systeme
  `text/uri-list`, plus compatible avec le collage de vrais fichiers entre
  gestionnaires.
- La preview video ne depend plus seulement de `ffmpegthumbnailer`; elle utilise
  `ffmpeg` en fallback pour generer une image de preview quand il est present.
- Les boutons de vue sont maintenant fonctionnels : grille, liste detaillee et
  vue compacte ajustent la densite, les tailles de tuiles, les metadonnees et la
  navigation.
- Seven Files ajoute des actions de base indispensables : nouveau dossier,
  dupliquer, renommer et deplacer vers la corbeille depuis le toolbar ou le menu
  contextuel.
- Les checks UX protegent les modes de vue, le clipboard fichier persistant, la
  preview video fallback et les actions modernes de gestionnaire de fichiers.

## 2026-05-17 - SevenOS typography role pass

- La typographie SevenOS est separee par role : SF Pro Display pour l'interface
  principale, SF Pro Text pour le texte normal, SF Mono pour le terminal,
  JetBrainsMono Nerd Font ou SF Mono pour les surfaces cyber, et SF Pro Rounded
  pour le branding avec fallback SF Pro Display.
- `hyprland/fontconfig/fonts.conf` expose les alias SevenOS UI, Display, Mono et
  Brand, et mappe aussi `monospace` vers SF Mono puis JetBrainsMono Nerd Font.
- `apply-theme` copie maintenant la configuration fontconfig avec les themes
  GTK/Qt et applique `SF Pro Display 10` a l'interface, `SF Pro Text 10` aux
  documents et `SF Mono 10` au monospace.
- Les polices SF Pro et SF Mono locales sont installees et detectees par
  fontconfig; SF Pro Rounded reste declare avec fallback SF Pro Display si la
  famille exacte n'est pas presente.
- Les checks design et UX verifient maintenant cette matrice typographique.

## 2026-05-17 - Dynamic font management pass

- Ajout de `seven fonts` via `scripts/fonts.sh` pour detecter, importer,
  rafraichir et appliquer les roles typographiques SevenOS sans terminal
  obligatoire.
- `install.sh base` applique deja le theme; `apply-theme` lance maintenant aussi
  `seven fonts apply-default`, ce qui rend la typographie par defaut robuste sur
  une nouvelle machine avec fallbacks Noto/Cantarell quand SF Pro n'est pas
  installe.
- SevenOS Settings ajoute une page `Fonts` accessible par `seven settings fonts`
  avec import `.ttf/.otf/.ttc`, ouverture de la bibliotheque de polices,
  refresh du cache et application des roles par defaut.
- Le manifest base ajoute `fontconfig`, `7zip` et `noto-fonts` afin que la
  detection, l'extraction locale et les fallbacks soient presents des
  l'installation.

## 2026-05-17 - Waybar Bluetooth replacement pass

- Le module `memory` de Waybar est retire de la barre parce qu'il doublonnait
  avec le module CPU/systeme.
- Ajout de `custom/bluetooth` avec etat JSON, tooltip propre, clic gauche vers
  le centre Bluetooth, clic milieu pour activer/desactiver et clic droit vers le
  gestionnaire.
- Ajout de `seven-bluetooth` pour exposer `status-json`, `toggle`, `scan`,
  `manager` et `devices` sans melanger la logique Bluetooth dans la config
  Waybar.
- `seven-waybar-center-native` ajoute un panneau Bluetooth compact : etat radio,
  appareil connecte, scan, manager et acces Settings.
- Le manifest base ajoute `bluez`, `bluez-utils` et `blueman` pour que la
  connexion Bluetooth soit disponible par defaut sur une installation SevenOS.

## 2026-05-17 - Dock visibility and helpers shortcut pass

- `Super+H` ouvre maintenant directement les helpers SevenOS, plus simple que
  l'ancien raccourci `Super+/`.
- Le Hub reste accessible via `Super+Shift+H` afin d'eviter le conflit avec
  l'aide et de garder un raccourci clavier clair.
- Le dock natif est repare avec un ancrage layer-shell bas centre plus robuste,
  un namespace `sevenos-dock`, et une commande `seven-dock repair/restart`.
- `seven-dock repair` ferme les anciens processus invisibles, relance le dock
  et signale si le processus ne reste pas ouvert.
- Le dock utilise maintenant une fenetre Hyprland visible en fallback quand
  layer-shell ne mappe pas la surface, puis se replace automatiquement en bas au
  centre via `hyprctl`.
- Les badges de notification du dock ont un timeout court afin qu'un
  `makoctl list` bloque ne puisse plus empecher l'apparition du dock.

## 2026-05-21 - Seven mini OS consolidation guard pass

- SevenOS est verrouille autour de 7 mini OS visibles : Equinox, Baobab,
  Forge DevOps, Shield, Studio, Windows Bridge et Pulse.
- Horizon reste disponible uniquement comme alias de compatibilite vers
  Forge DevOps, sans reapparaitre comme mini OS dans les surfaces principales.
- Les checks UX valident maintenant les sorties `profile aliases`,
  `profile migrate-aliases`, la migration automatique pendant l'activation et
  l'absence de Horizon dans la liste active des profils.
- Les plans runtime et mini-os-bridge testent explicitement que les anciennes
  commandes `horizon + shield` deviennent `forge + shield`.
- Les validations Python des gros JSON passent par variables d'environnement
  pour eviter les erreurs de type "liste d'arguments trop longue".

## 2026-05-21 - Windows Bridge profile sync pass

- Ajout de `seven windows sync` pour reconcilier automatiquement l'etat de la
  VM avec le mini OS actif : Windows actif lance/reconnecte la VM, les autres
  profils sauvegardent ou arretent la VM selon la politique.
- L'activation du profil Windows Bridge lance maintenant `seven windows enter`
  puis un `sync` retarde, afin de rattraper les courses entre changement de
  profil, libvirt et ouverture de console.
- Les verrous VM sont relaches explicitement dans les chemins start/enter/leave
  pour eviter les operations bloquees apres une erreur.
- L'action `windows.sync` est exposee dans les actions SevenOS et protegee par
  les checks UX.
- Ajout de `seven windows bridge-status` et du bloc `bridge_runtime` dans
  `seven windows status --json` pour diagnostiquer profil actif, etat VM,
  console, watchdog, et action recommandee.
- Le statut humain affiche maintenant un resume runtime clair, afin de savoir
  immediatement si Windows Bridge est synchronise ou s'il faut lancer
  `seven windows sync`.
- Le Mini OS Center affiche maintenant une carte `Windows Runtime` pour le
  profil Windows Bridge avec profil actif, etat VM, console, synchronisation et
  action suivante.
- Les actions rapides Windows Bridge incluent desormais `Sync` et `Status` dans
  le contrat du Mini OS et dans `profile-ui.json`.

## 2026-05-21 - Hybrid runtime autonomy pass

- L'isolation des mini OS prepare maintenant les racines overlay et les racines
  HOME/cache/data pour les 7 profils, pas uniquement pour le profil actif.
- Les containers de profil exposent un `launch_mode`
  `available-via-seven-profile-run-container`, ce qui rend l'isolation stricte
  disponible a la demande sans casser le store pacman global.
- Le scheduler passe de `foundation` a `active-user-space-executor` : il garde
  la detection de contexte, ajoute un etat d'application JSON et sait appliquer
  des renice prudents sur les processus possedes par l'utilisateur.
- `profile-ui.json` expose maintenant `runtime_context` pour clarifier les cas
  comme Equinox actif avec optimisation temporaire Forge.
- Le Mini OS Center affiche ce contexte dans la carte Composition afin que
  l'utilisateur voie le profil actif, les capacites injectees et l'optimisation
  runtime detectee.
- Les checks UX verrouillent ces garanties : 7 profils, alias Horizon nettoye,
  overlays/containers prepares, scheduler applicatif et contexte runtime visible.

## 2026-05-21 - Strict mini OS runtime visibility pass

- `profile-isolation.json` expose maintenant `strict_runtime` avec score,
  moteur, commande de lancement, scope runtime et separation app-data pour
  chaque mini OS.
- `seven profile isolation status` affiche une section `Strict runtime`
  lisible avec le score de chaque profil et sa commande stricte.
- Le registre d'actions expose des shells stricts pour les 7 mini OS, afin que
  le Hub, Spotlight et les surfaces natives puissent les proposer.
- `seven state --json` exporte `profile_run`, donnant aux interfaces un contrat
  central sur la frontiere d'execution du profil actif.
- Le Mini OS Center affiche le score strict dans la carte Isolation et ouvre les
  diagnostics/strict shells dans Seven Terminal, au lieu de lancer des commandes
  invisibles en arriere-plan.

## 2026-05-21 - Explicit workspace boundary pass

- `seven-profile-run` accepte maintenant `--workspace PATH`, monte ce dossier
  explicitement a `/workspace` et demarre la commande dedans.
- Le mode strict garde HOME/cache/data isoles par mini OS tout en permettant a
  Forge, Shield ou Studio de travailler sur un projet/cas precis sans exposer
  tout le vrai `$HOME`.
- Le contrat JSON `sevenos.profile-run.v1` documente `workspace_mount` et la
  politique `explicit-bind-only`.
- Le registre d'actions ajoute `profile.strict.workspace` pour ouvrir un shell
  strict du profil actif avec le dossier courant comme workspace.
- Le Mini OS Center ajoute `Workspace shell` afin de tester l'execution stricte
  avec un dossier de travail visible et controle.

## 2026-05-21 - Default profile workspace strict pass

- `seven-profile-run` accepte `--workspace-profile` pour monter le workspace
  par defaut du mini OS actif ou cible a `/workspace`.
- Les workspaces par defaut (`~/Forge`, `~/ShieldLab`, `~/Studio`, `~/Baobab`,
  `~/WindowsMode`, `~/Pulse`, `~/SevenOS`) sont crees automatiquement au besoin.
- Le contrat JSON expose `profile_default`, `profile_flag` et l'existence du
  workspace, ce qui permet aux interfaces d'afficher une action fiable.
- Le registre d'actions ajoute `profile.strict.profile_workspace`.
- Le Mini OS Center utilise maintenant le workspace du mini OS plutot que le
  dossier du depot SevenOS pour son action `Workspace shell`.

## 2026-05-21 - Ephemeral strict runtime pass

- `seven-profile-run` accepte maintenant `--ephemeral`, qui force un lancement
  strict avec HOME/cache/data temporaires supprimes a la fermeture.
- Le contrat JSON annonce `ephemeral` et la politique de conservation : les
  workspaces explicites restent intacts, seules les donnees temporaires sont
  detruites.
- Le registre d'actions ajoute `profile.strict.ephemeral` et
  `profile.strict.shield_ephemeral` pour les usages jetables, notamment Shield.
- Le Mini OS Center expose `Ephemeral shell`, utile pour labs, tests, OSINT ou
  experimentation sans pollution du profil permanent.

## 2026-05-21 - Mini OS runtime manifest pass

- `seven-profile-run --profile <profil> --manifest` expose maintenant un
  contrat complet `sevenos.profile-runtime-manifest.v1`.
- Le manifeste decrit les racines HOME/cache/data du mini OS, son workspace par
  defaut, ses variables d'environnement, ses commandes strictes et sa politique
  d'execution.
- `seven profile isolation apply` ecrit des manifests par profil dans
  `~/.local/share/sevenos/profile-runtime-manifests`.
- Le registre d'actions ajoute `profile.strict.manifest`, afin que Spotlight,
  Hub et Settings puissent ouvrir le contrat runtime actif sans parsing fragile.
- `seven state --json` expose maintenant `profile_runtime_manifest` pour le
  profil actif et `profile_runtime_manifests` comme index des manifests
  disponibles pour les 7 mini OS.

## 2026-05-21 - Seven Hub runtime/search pass

- Seven Hub Native dispose maintenant d'un cache `seven state --json` partage
  afin d'eviter de recalculer toutes les surfaces quand un snapshot central est
  deja disponible.
- Ajout d'une page `Search` dans Seven Hub pour trouver actions, mini OS,
  raccourcis systeme et manifests runtime depuis une seule surface.
- Ajout d'une page `Runtime & Mini OS` avec manifest actif, index des 7
  manifests, commandes strictes, workspace shell et shell ephemere.
- Le contrat `seven hub status --json` valide maintenant que `seven state`
  expose bien `profile_runtime_manifest` et `profile_runtime_manifests`.
- Nettoyage des anciennes mentions Horizon dans le vieux Hub Tauri/fallback au
  profit de Forge DevOps, Pulse et Baobab.

## 2026-05-21 - Seven Hub non-blocking stability pass

- Seven Hub affiche maintenant une coque de chargement immediatement, puis
  charge `seven state --json` dans un thread de fond pour ne plus bloquer GTK.
- Le statut live lit uniquement le snapshot deja en cache, ce qui evite les
  pauses repetees toutes les 10 secondes.
- Le bouton refresh et le refresh periodique passent par le meme garde-fou
  anti-double-chargement.
- Si le snapshot central est indisponible ou partiel, le Hub reste ouvert et
  affiche un etat degrade au lieu de relancer une cascade de diagnostics lents.

## 2026-05-21 - Distribution autonomy masking pass

- Ajout de `seven autonomy`, contrat qui mesure si SevenOS se presente comme une
  couche OS autonome plutot qu'un Arch/Hyprland rice expose.
- Ajout de `seven-action-runner`, runner d'actions avec logs et notifications
  pour eviter d'ouvrir un terminal par defaut depuis les surfaces natives.
- Seven Hub utilise maintenant `seven-action-runner` pour les actions non
  interactives, tout en gardant le terminal pour les commandes explicitement
  interactives/debug.
- `seven state --json` expose maintenant le contrat `autonomy` pour Hub,
  Settings, Doctor et les futures surfaces SevenDaemon.
- La documentation `docs/DISTRIBUTION_AUTONOMY.md` formalise la politique :
  SevenOS peut utiliser Arch/Hyprland comme backend, mais les workflows normaux
  doivent passer par des surfaces SevenOS.

## 2026-05-21 - SevenOS platform facade pass

- Ajout de `seven platform`, carte publique des couches SevenOS : Software,
  Smart Window System, Session, Mini OS Runtime, Installer, Seven Core et
  Windows Bridge.
- Les backends Arch, pacman, Hyprland, systemd, libvirt et QEMU restent
  documentes comme details techniques, mais les surfaces peuvent afficher le
  vocabulaire SevenOS en premier.
- `seven autonomy` integre maintenant la presence de cette facade, ce qui fait
  passer SevenOS d'un masquage partiel a une couche distribution mesurable.
- `seven state --json`, Hub, actions et UX QA savent verifier `platform`.

## 2026-05-21 - SevenOS release channel and installer portal pass

- Ajout de `seven channel`, contrat de canal produit `dev/testing/stable` pour
  eviter que Hub et Settings parlent d'abord en termes de branche Git sale.
- `seven channel --json` expose l'etat daily-driver, le canal actif, le commit,
  le nombre de chemins modifies et les gates restantes sans pretendre qu'une
  release publique est prete.
- `seven-installer status --json` expose maintenant `sevenos.installer-portal.v1`
  avec la route effective : Calamares si disponible, sinon guide SevenOS TUI.
- `seven installer release --json` verifie le portail installateur comme gate
  obligatoire, en plus du launcher, du profil Calamares et de l'entree live ISO.
- `seven state --json`, `seven autonomy`, le registre d'actions et `ux-check`
  savent maintenant lire `channel` et le portail installateur.

## 2026-05-21 - Calamares runtime source gate

- Ajout de `seven installer runtime`, contrat `sevenos.calamares-runtime.v1`
  qui separe le profil Calamares SevenOS du runtime Calamares reel.
- Le gate indique maintenant si Calamares est installe, disponible via pacman,
  declare dans `scripts/packages-installer-aur.txt`, et quel helper AUR
  (`yay`/`paru`) peut servir au build ISO.
- `seven installer release --json` ajoute `calamares-source-policy` comme check
  optionnel sans marquer la release graphique comme prete tant que le runtime
  Calamares n'est pas present.

## 2026-05-21 - SevenOS public mask contract pass

- Ajout de `seven mask`, contrat dedie au masquage public : noms de lanceurs,
  portail installateur, surface logiciel, identite de boot et facade plateforme.
- `seven state --json` expose maintenant `mask` pour Hub, Settings, Doctor et
  futures surfaces natives.
- `seven autonomy` prend en compte le contrat public mask pour mesurer si
  SevenOS ressemble a une distribution autonome plutot qu'a un backend expose.
- Le registre d'actions et `ux-check` savent valider `seven mask`, afin que les
  prochains raffinements de branding soient visibles dans les gates produit.

## 2026-05-21 - SevenOS dynamic adaptation contract pass

- `seven dynamic` devient l'entree produit pour verifier que SevenOS est vivant
  et pas seulement masque : profil actif, `profile-ui.json`, contexte
  semantique, theme runtime, palette wallpaper et accents Hyprland dynamiques.
- `scripts/adaptive-ui.sh` expose maintenant `dynamic_inputs`, avec le bus UI du
  mini OS, les toolkits dark/light, la source matugen/wallpaper et le fichier
  `sevenos-dynamic.conf`.
- `seven state --json` expose maintenant `adaptive`, ce qui permet a Hub,
  Settings et SevenDaemon de lire l'etat dynamique sans relancer des probes
  disperses.
- `seven autonomy` integre `dynamic-adaptation` comme gate de distribution
  autonome : SevenOS doit changer de comportement et d'identite selon le mini OS,
  le contexte et le theme.

## 2026-05-21 - SevenOS public surfaces contract pass

- Ajout de `seven surfaces`, inventaire produit des surfaces natives visibles :
  Hub, Settings, Launchpad, Spotlight, Quick Settings, Files, Store, Reader,
  Terminal, Profile Center, Mini OS Center, Shield, Windows Bridge, Doctor,
  notifications et controles de fenetres.
- Le contrat verifie les executables natifs, les entrees desktop, les actions
  Hub/Spotlight et la compatibilite avec `seven mask` + `seven dynamic`.
- `seven state --json` expose maintenant `surfaces`, afin que Hub et Settings
  puissent afficher une carte de couverture produit sans relancer des checks
  disperses.
- `seven autonomy` integre `public-surfaces` comme gate : SevenOS doit avoir des
  entrees natives pour les workflows normaux avant de parler de distribution
  autonome.

## 2026-05-21 - SevenOS user routes contract pass

- Ajout de `seven routes`, contrat qui mappe les intentions utilisateur vers
  les surfaces SevenOS : installer une app, changer les reglages, chercher,
  ouvrir les fichiers, lire un document, changer de mini OS, utiliser Windows,
  reparer le systeme ou controler les fenetres.
- Chaque route verifie l'action ID, la surface native, l'entree commande et les
  contrats `mask` + `dynamic`, afin que les workflows restent SevenOS-first.
- `seven state --json` expose maintenant `routes` pour Hub, Spotlight, Settings
  et SevenAI.
- `seven autonomy` integre `user-routes` comme gate : SevenOS ne doit pas
  seulement avoir des apps natives, il doit aussi router clairement les
  intentions normales vers ces surfaces.

## 2026-05-21 - SevenOS distribution contract pass

- Ajout de `seven distribution`, gate produit au-dessus de `autonomy`,
  `platform`, `mask`, `dynamic`, `surfaces`, `routes`, `channel`, installer et
  release doctor.
- Le contrat distingue explicitement `daily-driver-distribution` et
  `public-release-candidate`, afin que SevenOS reste honnete quand Calamares,
  l'ISO graphique ou le freeze Git ne sont pas encore verrouilles.
- `seven state --json` expose maintenant `distribution`, pour que Hub,
  Settings, Doctor et SevenAI puissent lire une seule jauge de distribution.
- Le registre d'actions et `ux-check` valident `seven distribution`, ce qui
  donne un filet QA a la couche "distro autonome masquee et dynamique".

## 2026-05-21 - SevenOS about identity contract pass

- Ajout de `seven about`, contrat public pour les ecrans A propos, Settings,
  Hub et installateur : nom, edition, mini OS actif, canal, commit et etat de
  distribution.
- `seven about --json` expose `sevenos.about.v1` sans passer par tout le
  snapshot global, afin de rester rapide pour les surfaces natives.
- `seven state --json`, le registre d'actions, README, la doc autonomie et
  `ux-check` savent maintenant lire cette identite produit SevenOS-first.

## 2026-05-21 - SevenOS lifecycle contract pass

- Ajout de `seven lifecycle`, contrat de maintenance SevenOS-first pour les
  mises a jour, reparations, protection/restauration utilisateur, installer et
  gates de release.
- Le contrat mappe les intentions normales vers SevenStore/sevenpkg, Seven
  Doctor/Repair, manifest restore-plan, distribution gate et installer release.
- `seven state --json`, le registre d'actions, README, la doc autonomie et
  `ux-check` exposent maintenant ce cycle de vie afin de masquer les commandes
  backend dans les parcours grand public.

## 2026-05-21 - SevenOS product facade pass

- Ajout de `seven product`, snapshot compact pour Hub, Settings, Welcome et
  installateur : About, lifecycle, distribution, surfaces, routes, mask et
  dynamic dans un seul contrat `sevenos.product.v1`.
- Le contrat expose des cartes d'accueil produit et des promesses utilisateur,
  afin que les surfaces natives puissent parler SevenOS avant de parler backend.
- `seven state --json`, le registre d'actions, README, la doc autonomie et
  `ux-check` savent maintenant valider cette facade produit.

## 2026-05-21 - SevenOS foundations ownership pass

- Ajout de `seven foundations` / `seven foundation`, contrat qui relie chaque
  fondation technique a une surface SevenOS : Software, Smart Window System,
  Shell, Settings, Mini OS Runtime, Shield, Windows Bridge, Installer et
  Lifecycle.
- Le contrat garde Arch, Hyprland, pacman, Waybar, libvirt, QEMU et systemd
  comme fondations documentees, mais force une route SevenOS-first pour les
  parcours normaux.
- `seven state --json`, le registre d'actions, README, la doc autonomie et
  `ux-check` savent maintenant valider cette carte de propriete produit, ce qui
  reduit encore l'effet "Arch rice" visible.

## 2026-05-22 - SevenOS update surface pass

- Ajout de `seven update`, contrat de mise a jour SevenOS-first au-dessus de
  pacman, Flatpak, AUR helpers et bundles de profils.
- Par defaut, `seven update` affiche l'etat systeme/apps/community/profils sans
  lancer de commande destructive; `seven update apply` delegue ensuite a
  `sevenpkg update` puis Flatpak si disponible.
- `seven lifecycle`, `seven foundations`, `seven state --json`, le registre
  d'actions, README, la doc autonomie et `ux-check` savent maintenant valider
  cette route, afin que la maintenance courante ne commence plus par un
  workflow Arch brut.

## 2026-05-22 - SevenOS recovery surface pass

- Ajout de `seven recovery`, contrat de recuperation SevenOS-first qui regroupe
  chemins proteges, backups de migration, plan de reparation, installer/recovery
  et gate de distribution.
- `seven recovery backup` delegue explicitement a `scripts/migrate.sh backup`,
  mais le parcours utilisateur commence maintenant par une surface SevenOS.
- `seven lifecycle`, `seven foundations`, `seven state --json`, le registre
  d'actions, README, la doc autonomie et `ux-check` savent maintenant valider
  cette route de recuperation, pour que SevenOS ressemble davantage a une
  distribution autonome qu'a un ensemble de scripts de secours.

## 2026-05-22 - SevenOS health surface pass

- Ajout de `seven health`, surface d'etat quotidien SevenOS-first qui resume
  Product, Lifecycle, Update, Recovery, Foundations, Distribution, session et
  services echoues.
- Le contrat `sevenos.health.v1` donne une reponse produit rapide avant les
  diagnostics backend comme `systemctl --failed`, `journalctl`, pacman ou
  Hyprland.
- `seven state --json`, le registre d'actions, README, la doc autonomie et
  `ux-check` valident maintenant cette jauge de sante quotidienne.

## 2026-05-22 - SevenOS support surface pass

- Ajout de `seven support`, route de support locale qui regroupe health,
  product, recovery, evenements et chemins de logs sans exposer d'abord les
  commandes backend.
- `seven support bundle` cree un dossier local sous
  `~/.local/share/sevenos/support` et n'envoie rien automatiquement.
- `seven state --json`, le registre d'actions, README, la doc autonomie et
  `ux-check` valident maintenant cette surface de diagnostic partageable.

## 2026-05-22 - Seven Hub support/cache pass

- Seven Hub conserve maintenant un snapshot local dans
  `~/.cache/sevenos/hub-state.json`, ce qui garde le cockpit ouvrable meme si
  une commande backend devient lente ou indisponible.
- Le dashboard expose la route `seven support` comme action de diagnostic
  locale, avec score de support et acces au bundle.
- Le contrat Hub valide maintenant que `support` est present dans `seven
  state --json` et dans le registre d'actions.
