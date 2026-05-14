# SevenOS Progress

Derniere mise a jour : 2026-05-14

Ce document suit l'evolution de SevenOS : ce qui est deja en place, le niveau actuel du projet, les ameliorations recentes, et les prochaines etapes pour le faire passer d'une base Arch personnalisee a un vrai systeme d'exploitation coherent.

## Niveau Actuel

SevenOS est actuellement au niveau :

```text
Foundation OS / Developer Preview
```

Cela signifie que SevenOS n'est plus seulement une idee ou un theme Arch. Le projet possede deja une architecture de distribution, une identite visuelle, des scripts d'installation, des profils metiers, un debut de Control Center, une couche Windows, une base ISO, une couche serveur et un gestionnaire logiciel maison.

Le niveau actuel a progresse sur l'experience desktop : Waybar n'est plus seulement informative, les menus Rofi sont plus lisibles, et le lanceur d'applications suit maintenant une logique Launchpad plein ecran inspiree de macOS, adaptee a l'identite SevenOS.

SevenOS entre maintenant dans la phase :

```text
Phase B — OS Productization
```

Cette phase vise a reduire la dependance au terminal, masquer la complexite des scripts, et faire de Seven Hub la surface principale de controle du systeme.

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
- Simplicite : commandes `seven` et `sevenpkg`.
- Securite : Shield mode, hardening, sandbox, Cyber Lab.
- Profils metiers : Forge, Shield, Studio, Windows, Server.
- Ecosysteme : Seven Hub, Seven Server, Seven Deploy, SevenRepo futur.

## Ameliorations Deja Appliquees

### Architecture projet

- Structure modulaire du depot creee.
- Separation claire entre `bin/`, `scripts/`, `profiles/`, `security/`, `vm/`, `server/`, `sevenpkg/`, `seven-hub/`, `identity/`, `branding/`, `installer/` et `archiso/`.
- Ajout des documents de vision, architecture, UX, criteres OS, deploiement et test machine.
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
- Ajout de `seven actions --json`, registre central des actions SevenOS pour partager les memes commandes entre Hub, Waybar, Quick Settings et les futures surfaces natives.
- Ajout de `seven actions category <name>` pour fournir des listes d'actions ciblees aux petits panneaux systeme sans dupliquer les commandes.
- Ajout de `seven manifest show|doctor|restore-plan|protected|components` pour preparer les upgrades, le packaging pacman et la future ISO sans ecraser les choix utilisateur.
- Ajout de `seven migrate plan|backup` comme etape de securite avant reapplication du theme, upgrade Git, paquet pacman futur ou ISO.
- Ajout du resume manifeste dans `seven state --json`, pour que Seven Hub et Seven Server voient les composants, la version, le canal et les compteurs de protection en JSON.
- Seven Server expose maintenant `/actions`, afin que les interfaces locales puissent consommer le meme registre d'actions que Seven Hub.
- Debut de separation entre affichage humain et donnees machine pour que Seven Hub pilote SevenOS sans parser des textes fragiles.

### Design System

- Creation du Design System v1 : `Sovereign by design`.
- Ajout de `identity/STYLE.md` comme reference officielle.
- Ajout de `identity/tokens.css` comme source CSS des couleurs, rayons, espacements, typographies et transitions.
- Ajout des motifs dans `identity/patterns/`.
- Nouvelle palette : Ebene clair, surfaces liquid glass, Or ancestral, Argile, Baobab, Indigo.
- Harmonisation de Waybar, Rofi, Kitty, Mako, Hyprland, Seven Hub et Tauri GUI.
- Suppression des styles trop generiques : pas de fond blanc, pas de `box-shadow`, pas de `backdrop-filter`, pas de font-weight lourd.
- Correction des surfaces Rofi trop noires ou illisibles.
- Passage du menu Apps vers un rendu plein ecran type Launchpad macOS : recherche centree, grille 6 colonnes, grandes icones et labels centres.
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
- `Super+A`, Waybar Apps et Seven Help passent par `seven-apps`, afin que l'acces aux applications installees ne depende plus uniquement du cache `drun` de Rofi.
- `seven-apps` transmet maintenant les icones des fichiers `.desktop` a Rofi, ce qui permet au Launchpad Apps d'afficher les vraies icones d'applications quand le theme d'icones les fournit.
- Ajout de `seven-quick-settings`, panneau rapide pour Hub, apps, fenetres, reseau, audio, wallpaper, profils, migration, monitoring et power.
- Hyprland adopte une ergonomie plus GNOME-like : `Super+Tab` pour les fenetres, `Super+N`/`Super+O` pour les quick settings, `Super+S` pour scratchpad, `Super+L` pour lock, mouvements souris Super+clic et workspaces gauche/droite.
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
- `seven state --json` expose maintenant `active_profile` et `windows`, pour que le Hub natif puisse lire un etat OS complet sans parser des textes humains.
- Renforcement Seven Ecosystem : ajout d'un process map all-in-one (`seven ecosystem processes`), d'un contrat JSON (`seven ecosystem --json`) et integration de l'ecosysteme dans `seven state --json`.
- Le registre d'actions expose maintenant les actions Ecosystem Map, Process Map, Roadmap et Doctor pour Seven Hub et les futures surfaces natives.
- Fluidite Ecosystem : Seven Hub Native affiche les processus avec boutons de lancement, et `seven ecosystem summary` donne un resume compact modules/processus.
- Ajout de `seven experience` / `seven experience --json` : audit de coherence OS qui relie identite, shell, Hub, profils, actions, Windows, securite, serveur, installateur et ecosysteme.
- Consolidation Trust/Server : ajout de `seven shield status --json`, `seven server status --json`, endpoints `/experience` et `/shield`, et integration de `shield`/`server` dans `seven state --json`.
- Ajout de `seven control` / `seven control --json` : plan d'actions priorise qui fusionne readiness, experience, Shield, Server et profils pour guider Seven Hub comme un vrai centre de decision OS.
- Ajout de `seven control apply` : preview executable des corrections prioritaires, non destructif par defaut, avec execution explicite uniquement via `--apply`.

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

### Cybersecurite

- Hardening systeme de base.
- Cyber Lab sandbox.
- Outils de security audit.
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
68d460e Make app launcher macOS style
```

Jalons recents :

```text
b2736d2 Apply SevenOS design system v1
96850bf Fix Waybar startup compatibility
cc25e63 Make Waybar modules actionable
2f8b52e Improve Rofi menu visibility
68d460e Make app launcher macOS style
```

Ces jalons introduisent le Design System v1, stabilisent Waybar, rendent la barre plus actionnable, ameliorent la lisibilite des menus Rofi et transforment le lanceur d'applications en experience plein ecran inspiree de macOS Launchpad.

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
