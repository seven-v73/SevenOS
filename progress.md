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
- Definition des futures frontieres de paquets : `sevenos-cli`, `sevenos-branding`, `sevenos-hyprland`, `sevenos-hub`, `sevenos-profiles`, `sevenos-server` et `sevenos-installer`.

### Commandes systeme

- Mise en place de `seven` comme controleur principal.
- Mise en place de `sevenpkg` comme gestionnaire logiciel SevenOS.
- Ajout de commandes de statut, readiness, doctor, improvement et profils.
- Ajout de commandes UX : `seven-session`, `seven-wallpaper`, `seven-power`, `seven-files`, `seven-welcome`, `seven-country`.
- Ajout de sorties JSON stables pour `seven status --json`, `seven profile status --json`, `sevenpkg status --json` et `sevenpkg meta --json`.
- Ajout de `seven state --json`, snapshot machine unifie pour les interfaces natives, l'automatisation et le futur Seven Server.
- Ajout de `seven manifest show|doctor|restore-plan|protected|components` pour preparer les upgrades, le packaging pacman et la future ISO sans ecraser les choix utilisateur.
- Debut de separation entre affichage humain et donnees machine pour que Seven Hub pilote SevenOS sans parser des textes fragiles.

### Design System

- Creation du Design System v1 : `Sovereign by design`.
- Ajout de `identity/STYLE.md` comme reference officielle.
- Ajout de `identity/tokens.css` comme source CSS des couleurs, rayons, espacements, typographies et transitions.
- Ajout des motifs dans `identity/patterns/`.
- Nouvelle palette : Ebene, surfaces sombres, Or ancestral, Argile, Baobab, Indigo.
- Harmonisation de Waybar, Rofi, Kitty, Mako, Hyprland, Seven Hub et Tauri GUI.
- Suppression des styles trop generiques : pas de fond blanc, pas de `box-shadow`, pas de `backdrop-filter`, pas de font-weight lourd.
- Correction des surfaces Rofi trop noires ou illisibles.
- Passage du menu Apps vers un rendu plein ecran type Launchpad macOS : recherche centree, grille 6 colonnes, grandes icones et labels centres.
- Suppression des couleurs alpha hex fragiles dans Rofi et Waybar pour ameliorer la compatibilite GTK/Rofi.

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
- Les actions dangereuses ou modificatrices ne partent plus au clic direct : le Hub demande confirmation avant installation, activation, reparation ou changement de profil.
- Le panneau de sortie distingue maintenant les etats `running`, `success` et `error`, avec un resume humain avant le detail technique.
- Amelioration de la maniabilite du Hub : vraie zone de contenu scrollable, navigation laterale lisible avec labels, hauteur adaptee au viewport, scrollbars integrees au design et changement de section plus naturel.
- Clarification strategique : Tauri reste un prototype de productisation, mais la cible OS devient Seven Hub Native en GTK4/libadwaita.
- Ajout de `seven-hub/native/README.md` pour definir les modules natifs, les contrats JSON et le chemin de migration.
- Ajout de `seven-hub-native`, premier prototype GTK/libadwaita centre sur les profils et connecte a `seven profile status --json`.
- Integration de `seven hub-native`, du lanceur desktop `seven-hub-native.desktop` et des wrappers d'installation.

### Gestion fichiers

- Ajout de Seven Files comme point d'entree utilisateur.
- Integration avec Nautilus, GVFS, MTP, SMB, File Roller, Sushi et XDG user dirs.
- Ajout de theme GTK/Qt pour eviter une experience visuelle incoherente entre apps sombres et apps claires.

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
