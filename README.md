# 🌙 Mamumi-Os

**Transforme Windows 10/11 en un bureau façon [Omarchy](https://omarchy.org) : fenêtres en mosaïque, tout au clavier, thème Tokyo Night, et un Windows débarrassé des pubs et du superflu.**

Une seule commande, environ 2 minutes, et c'est installé.

```
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ 🌙 1 2 3 │ ⧉ discord        ven. 16 oct.  22:15         ▫▫▫ 🖧 ↓2MB  ᛒ 🔊45% ⏻ │  ← barre Tokyo Night
  ├──────────────────────────────┬───────────────────────────────────────────┤
  │                              │                                           │
  │        Navigateur            │            Terminal                       │  ← fenêtres rangées
  │                              ├───────────────────────────────────────────┤     automatiquement
  │                              │            Discord                        │
  └──────────────────────────────┴───────────────────────────────────────────┘
```

---

## 📑 Sommaire

1. [Installation](#-installation)
2. [Ce que ça fait (en détail)](#-ce-que-ça-fait-en-détail)
3. [Les raccourcis clavier](#️-les-raccourcis-clavier)
4. [La barre du haut](#-la-barre-du-haut)
5. [Jouer](#-jouer)
6. [Entretien : réparer, sauvegarder, désinstaller](#-entretien--réparer-sauvegarder-désinstaller)
7. [FAQ / dépannage](#-faq--dépannage)
8. [Ce qui n'est PAS automatisé (à faire à la main)](#-ce-qui-nest-pas-automatisé-à-faire-à-la-main)
9. [Limites connues](#️-limites-connues)
10. [Comment c'est construit](#-comment-cest-construit)

---

## 🚀 Installation

### Prérequis
- Windows **10 ou 11**
- **winget**, installé d'office sur Windows 11. Sur Windows 10, installe « App Installer » depuis le Microsoft Store.
- Une connexion internet
- Un compte **administrateur**. Une seule fenêtre « Oui / Non » s'affichera.

### La commande
1. Ouvre le menu Démarrer, tape **PowerShell**, puis **Entrée**. Inutile de le lancer en administrateur.
2. Colle cette ligne, puis **Entrée** :

```powershell
irm https://raw.githubusercontent.com/AnisseBendrihem/Mamumi-Os/main/install.ps1 | iex
```

3. Le script te montre la liste de ce qu'il va faire. Tape **o**, puis **Entrée**.
4. Accepte la fenêtre **administrateur** qui s'ouvre. Elle sert à créer un point de restauration et à appliquer les réglages système.
5. Attends la fin (1 à 3 minutes selon la connexion), puis **redémarre le PC**.

> 💡 **Sécurité** : avant de toucher à quoi que ce soit, le script crée un **point de restauration Windows** nommé `Avant Mamumi-Os`. En cas de souci, tu peux tout annuler (voir [Désinstaller](#désinstaller)).

### Installation manuelle (sans la commande en une ligne)
Télécharge le dépôt (bouton vert **Code** → **Download ZIP**), décompresse-le, puis dans PowerShell :
```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

---

## 📦 Ce que ça fait (en détail)

### 1. Un seul logiciel installé (gratuit et open source)
| Logiciel | Rôle |
|---|---|
| [**GlazeWM**](https://github.com/glzr-io/glazewm) | Gestionnaire de fenêtres en mosaïque (comme Hyprland sur Omarchy). Il inclut **Zebar**, la barre du haut |

Le reste est fait avec ce qui est **déjà dans Windows** : de petits programmes compilés à l'installation avec le compilateur intégré à Windows, et des réglages.

### 2. Fenêtres en mosaïque, en spirale comme Hyprland
- Les fenêtres se **rangent toutes seules**, sans jamais se chevaucher, avec un espace de 10 px entre elles.
- **Disposition en spirale (« dwindle »)**, comme sur Omarchy. Une fenêtre active **plus large que haute** fait s'ouvrir la suivante **à côté**, une fenêtre **plus haute que large** la fait s'ouvrir **en dessous** :
  ```
  ┌────────┐   ┌────┬────┐   ┌────┬────┐   ┌────┬────┐
  │   A    │ → │ A  │ B  │ → │ A  │ B  │ → │ A  │ B  │
  │        │   │    │    │   │    ├────┤   │    ├──┬─┤
  │        │   │    │    │   │    │ C  │   │    │C │D│
  └────────┘   └────┴────┘   └────┴────┘   └────┴──┴─┘
  ```
  Pour revenir à des colonnes simples, crée un fichier vide `C:\ProgramData\Mamumi-Os\autotiling.off`.
- **Bordure violette** sur la fenêtre active, grise sur les autres.
- **Barres de titre masquées**, comme sur Omarchy. Pour déplacer une fenêtre, utilise **Win + Shift + flèches**. Pour la fermer, **Win + W**. Pour réafficher les barres de titre, passe `hide_title_bar` à `false` dans `config.yaml`, puis **Win + Shift + R**.
- **9 espaces de travail** (bureaux virtuels).
- Les **jeux et launchers** (Steam, Epic, Riot, Battle.net, EA, Ubisoft, Xbox…) sont **ignorés** : ils fonctionnent normalement.
- Les petites fenêtres (Gestionnaire des tâches, Capture d'écran, Calculatrice, boîtes de dialogue) restent **flottantes**.
- GlazeWM **démarre avec Windows**.

### 3. Barre du haut Tokyo Night (Zebar)
Elle remplace la barre des tâches Windows, qui est **cachée**. Détails dans [La barre du haut](#-la-barre-du-haut).
- **Légère** : écrite avec Preact + htm (≈ 30× plus léger que React, sans compilateur au démarrage).
- **Aucune dépendance Internet** : ses bibliothèques et sa police d'icônes sont **embarquées**, pour qu'elle s'affiche même hors ligne.
- **Relancée automatiquement** si elle plante.
- **Sans cache** : une modification de la barre s'applique dès qu'elle redémarre (avant, Zebar pouvait servir une ancienne version pendant 7 jours).

### 4. Thème Tokyo Night partout
| Élément | Changement |
|---|---|
| Windows | Mode sombre, couleur d'accent **violet** Tokyo Night `#bb9af7`, avec des touches de **rose** `#f4a6e0` |
| Menu Démarrer | Fond bleu nuit légèrement violet `#221e35`, **centré**, **épuré** : plus de section « Recommandé », de fichiers récents ou de suggestions, et plus de place pour les épingles |
| Panneaux Windows (Wi-Fi, volume, calendrier) | Bleu nuit légèrement violet |
| Windows Terminal | Palette Tokyo Night, police Cascadia Mono, légère transparence, marges, sans barre de défilement. **Tes profils sont conservés** |
| Bureau | Icônes masquées, pour un bureau propre comme sur Omarchy |

### 5. Pubs, IA et vie privée
- ❌ **Pubs et suggestions** : menu Démarrer, Paramètres, écran de verrouillage, conseils.
- ❌ **Installation automatique d'applis promo** (Candy Crush, Spotify, TikTok…).
- ❌ **Bing** dans la recherche du menu Démarrer : la recherche ne montre plus que tes applis et fichiers.
- ❌ **Copilot**, **Recall** (captures d'écran par l'IA) et **Widgets** (actus, météo).
- ❌ **Télémétrie** réduite au minimum, et services `DiagTrack` et `dmwappushservice` désactivés.
- ❌ **Historique d'activité**, **ID publicitaire**, **demandes d'avis**.

### 6. Applis Microsoft désinstallées
Actualités, Météo, Bing Search, Cartes, Hub de commentaires, Obtenir de l'aide, Visionneuse 3D, Portail de réalité mixte, Contacts, Courrier et Calendrier (ancienne version), Clipchamp, Power Automate, Dev Home, Office Hub, Widgets, **nouvel Outlook**, **Teams (perso)**, **OneNote**, **Lien avec Windows (Phone Link)**, Films et TV, Assistance rapide, Edge Game Assist, Copilot, Solitaire, To Do, Cortana.

✅ **Conservés** : Xbox et Game Pass, Photos, Calculatrice, Bloc-notes, Paint, Capture d'écran, Lecteur multimédia, Microsoft Store, Edge.

### 7. Démarrage plus léger
Ces programmes ne se lancent plus **automatiquement** au démarrage. Ils restent installés et s'ouvrent normalement quand tu cliques dessus :
Epic Games, GOG Galaxy, Riot Client, Teams, OneDrive, lancement auto d'Edge, Adobe Acrobat Sync, Figma Agent, Spotify, EA, Origin, Ubisoft.

### 8. Optimisations jeu
- **Enregistrement en arrière-plan de la Xbox Game Bar** coupé, ce qui fait gagner des FPS. La Game Bar reste disponible avec Win + G.
- **Mode Jeu** activé.
- **Planification GPU accélérée (HAGS)** activée, après redémarrage. Elle est utile pour le DLSS Frame Generation.

### 9. Nettoyage
Fichiers temporaires (utilisateur et Windows), cache de Windows Update, crash dumps, cache Internet et corbeille.

### 10. Panneau des raccourcis (Win + K)
Un petit panneau Tokyo Night, **centré**, qui liste tous les raccourcis, comme sur Omarchy :
- **tape** pour filtrer (« plein » trouve « Plein écran », sans tenir compte des accents) ;
- **↑ ↓** pour naviguer, **Entrée** (ou un clic) pour **exécuter** le raccourci ;
- **Échap**, un clic ailleurs ou **Win + K** pour fermer.

Il est aussi accessible depuis le menu Démarrer : **Win**, puis « rac ». C'est un mini-programme compilé à l'installation : il ne consomme rien quand il est fermé, et environ 25 Mo quand il est ouvert.

La liste se modifie dans `C:\ProgramData\Mamumi-Os\keys.txt` :
```
# Section
Touches | Ce que ça fait | commande lancée avec Entrée (optionnelle)
```
La commande peut être `glaze:<commande GlazeWM>`, `run:<programme> [arguments]` ou `send:<touches>`. Une ligne sans commande s'affiche en gris, comme simple aide.

### 11. Outils d'entretien (menu Démarrer)
- **Réparer Mamumi-Os** : remet tout en place après une mise à jour Windows.
- **Sauvegarder Mamumi-Os** : sauvegarde ta config.
- **Désinstaller Mamumi-Os** : revient en arrière.

---

## ⌨️ Les raccourcis clavier

> Toutes les touches utilisent **Win** (la touche Windows), comme **Super** sur Omarchy.
>
> 🆘 **Tu as oublié un raccourci ? Fais Win + K** : un panneau centré liste **tous** les raccourcis. Tape pour filtrer, **↑ ↓** pour naviguer, **Entrée** pour exécuter le raccourci sélectionné. C'est le même principe que le menu des raccourcis d'Omarchy.

### Applications
| Raccourci | Action |
|---|---|
| **Win** ou **Win + Espace** | Menu Démarrer : tape directement le nom de l'appli, puis Entrée |
| **Win + Entrée** | Terminal |
| **Win + B** | Navigateur (ton navigateur par défaut) |

### Fenêtres
| Raccourci | Action |
|---|---|
| **Win + W** | Fermer la fenêtre |
| **Win + F** | Plein écran |
| **Win + T** | Faire flotter la fenêtre, ou la remettre en mosaïque |
| **Win + J** | Changer le sens de découpe (horizontal ou vertical) |
| **Win + M** | Réduire la fenêtre |
| **Win + ← → ↑ ↓** | Passer à la fenêtre voisine |
| **Win + Shift + ← → ↑ ↓** | Déplacer la fenêtre |
| **Win + R**, puis **flèches** | Redimensionner (**Échap** pour terminer) |

### Espaces de travail
| Raccourci | Action |
|---|---|
| **Win + 1 … 9** | Aller à l'espace 1 … 9 |
| **Win + Shift + 1 … 9** | Envoyer la fenêtre vers l'espace 1 … 9 |
| **Win + Tab** / **Win + Shift + Tab** | Espace suivant / précédent |

### Système
| Raccourci | Action |
|---|---|
| **Win + K** | 📋 **Panneau de tous les raccourcis** : filtre, navigation, Entrée pour exécuter |
| **Win + Shift + P** | ⏸️ **Pause** de GlazeWM (pour jouer ou dépanner). Même raccourci pour reprendre |
| **Win + Shift + R** | Recharger la config |
| **Win + Shift + W** | Redessiner les fenêtres |
| **Win + Shift + Échap** | **Quitter GlazeWM** : la barre Windows revient |
| **Win + A** | Paramètres rapides (Wi-Fi, Bluetooth, volume…) |
| **Win + N** | Calendrier et notifications |
| **Alt + Tab** | Retrouver n'importe quelle fenêtre, même réduite |

> 💡 **Le réflexe Omarchy** : plutôt que de réduire une fenêtre, envoie-la sur un autre espace (**Win + Shift + 3**), puis vas-y quand tu en as besoin (**Win + 3**).

---

## 📊 La barre du haut

```
 🌙 1 2 3 │ ⧉ discord          ven. 16 oct.  22:15          ▫▫▫ │ 🖧 ↓2MB ↑0kB  ᛒ  🔊 45%  ▣ 40%  ⚙ 8%  ⏻
 └espaces┘ └réduites┘      └──── heure ────┘            └tray┘ └─ internet ─┘ └BT┘ └son─┘ └RAM┘ └CPU┘ └alim┘
```

| Élément | Affichage | Clic gauche | Autre |
|---|---|---|---|
| **Espaces 1 2 3…** | Espace actif en violet | Aller à cet espace | |
| **Fenêtres réduites** | Nom de l'appli | La fait revenir | |
| **Heure** | Date et heure | Ouvre le **calendrier** Windows. Un 2e clic le ferme | |
| **Zone de notification** | Icônes discrètes (grises), en couleur au survol | Ouvre l'appli | **Clic droit** : le vrai menu de l'appli (Quitter, Paramètres…) |
| **Internet** | Câble ou Wi-Fi + débit ↓↑, **rouge « Hors ligne »** sans connexion | **Paramètres rapides** (Wi-Fi, Bluetooth…) | |
| **Bluetooth** | ᛒ | **Paramètres rapides** | |
| **Volume** | Niveau en % | **Panneau volume** Windows | **Clic droit** : couper le son. **Molette** : ±5 % |
| **RAM / CPU / GPU** | Utilisation en %, en rouge au-delà de 85 % | **Détail** sur place : Go utilisés / total, cœurs et threads, mémoire vidéo, température et watts de la carte graphique, **mini-graphiques** de la dernière minute. Un 2e clic le referme | **Clic droit** : Gestionnaire des tâches. Le GPU s'affiche avec une carte **NVIDIA** (via `nvidia-smi`), sinon il est masqué |
| **⏻ Alimentation** | Violet, rouge au survol | Menu : 🔒 verrouiller, 💤 veille, 🔄 redémarrer, ⏻ éteindre | ⚠️ Redémarrer et éteindre sont **immédiats** |

**Sécurité :** la barre ne peut lancer **que** ces quelques commandes précises (liste blanche dans `zpack.json`).

---

## 🎮 Jouer

- **Aucune action nécessaire** pour les jeux et launchers courants : GlazeWM les ignore, et ils s'ouvrent en plein écran normalement.
- **Un jeu se comporte bizarrement** (redimensionné, bordure, écran noir) ? Appuie sur **Win + Shift + P** pour mettre GlazeWM en pause. La barre affiche alors « PAUSE » en rouge.
- **Pour l'ajouter définitivement à la liste des jeux ignorés :**
  1. Trouve le nom de son processus : Gestionnaire des tâches → Détails, par exemple `MonJeu.exe`.
  2. Ouvre `%USERPROFILE%\.glzr\glazewm\config.yaml` et ajoute `|MonJeu` dans la ligne `window_process: { regex: ... }` de la section *Jeux et launchers*.
  3. **Win + Shift + R** pour recharger.

---

## 🧰 Entretien : réparer, sauvegarder, désinstaller

### Réparer
Après une **grosse mise à jour Windows**, il arrive que des réglages sautent : couleurs revenues au bleu par défaut, barre Windows réapparue, pubs de retour, appli réinstallée…

👉 Touche **Win**, tape **« Réparer Mamumi-Os »**, **Entrée**, puis accepte la fenêtre admin.

La réparation :
- réapplique **tous les réglages** ;
- **restaure les fichiers de config manquants** depuis la dernière sauvegarde ;
- **n'écrase pas** tes modifications, et **ne réinstalle rien** ;
- relance l'Explorateur, GlazeWM et la barre.

### Sauvegarder
Après avoir modifié ta config (raccourcis, liste de jeux…) :
👉 **Win**, tape **« Sauvegarder Mamumi-Os »**, **Entrée**.

Les sauvegardes vont dans :
- `D:\Sauvegarde_Mamumi-Os\` si tu as un disque D: ;
- sinon dans `%USERPROFILE%\Sauvegarde_Mamumi-Os\`.

Les **5 dernières versions** sont gardées, plus une copie `derniere` que la réparation utilise.

### Désinstaller
👉 **Win**, tape **« Désinstaller Mamumi-Os »**, **Entrée**.

Ça arrête et désinstalle GlazeWM et Zebar, fait revenir la barre Windows et les icônes du bureau, et restaure l'ancienne config du terminal.

**Pour TOUT annuler**, y compris les réglages vie privée et les applis supprimées : **Panneau de configuration → Récupération → Ouvrir la Restauration du système**, puis choisis le point **« Avant Mamumi-Os »**.

---

## ❓ FAQ / dépannage

**Je n'ai plus aucune barre, je suis perdu !**
→ **Win + Shift + Échap** quitte GlazeWM, et la barre Windows revient. Et si GlazeWM plante, elle revient **toute seule** au bout d'environ 6 secondes.

**La barre du haut a disparu.**
→ Elle revient automatiquement en 2 à 3 secondes. Sinon : **Win + Shift + Échap**, puis relance GlazeWM depuis le menu Démarrer, ou utilise **Réparer Mamumi-Os**.

**Une fenêtre a disparu.**
→ Elle est sûrement sur un autre espace de travail (regarde les chiffres dans la barre), ou réduite (elle apparaît alors dans la barre). **Alt + Tab** montre tout.

**Les panneaux Wi-Fi, volume et calendrier s'ouvrent en bas à droite, pas sous la barre.**
→ C'est normal : Windows impose leur position, et elle ne peut pas être changée.

**Win + Espace change ma langue de clavier.**
→ Uniquement quand GlazeWM est en pause ou fermé. Sinon, Win + Espace ouvre le menu Démarrer.

**Ça consomme combien ?**
→ Environ **450 Mo de RAM** au total (GlazeWM ≈ 10 Mo, la barre ≈ 400 Mo, la garde et la spirale ≈ 25 Mo) et **≈ 0,2 % de processeur**. Aucun impact sur les FPS en jeu. La barre est la plus gourmande, parce que Zebar l'affiche avec le moteur d'Edge (WebView2).

**Je veux modifier un raccourci.**
→ `%USERPROFILE%\.glzr\glazewm\config.yaml`, section `keybindings`, puis **Win + Shift + R**. Pense à mettre à jour aussi la liste du panneau **Win + K** (`C:\ProgramData\Mamumi-Os\keys.txt`). ⚠️ GlazeWM ne sait pas lancer un chemin **contenant un espace ou entre guillemets** : utilise un raccourci `.lnk` placé dans `C:\ProgramData\Mamumi-Os\` (exemple : `shell-exec explorer.exe C:\ProgramData\Mamumi-Os\MonAppli.lnk`).

**Faut-il mettre à jour GlazeWM et Zebar ?**
→ Pas sans vérifier : une version majeure de Zebar (v4…) pourrait demander d'adapter la barre. Ils ne se mettent **pas** à jour tout seuls.

**Où sont les fichiers ?**
| Quoi | Où |
|---|---|
| Config GlazeWM | `%USERPROFILE%\.glzr\glazewm\config.yaml` |
| Barre du haut | `%USERPROFILE%\.glzr\zebar\tokyo-night\` |
| Outils (masquage de la barre, panneaux, raccourcis, copie du dépôt) | `C:\ProgramData\Mamumi-Os\` |
| Ancienne config (avant installation) | `%USERPROFILE%\.glzr.avant-mamumi`, `settings.json.avant-mamumi` |
| Journal de la partie admin | `C:\ProgramData\Mamumi-Os\admin.log` |

---

## ✋ Ce qui n'est PAS automatisé (à faire à la main)

Ces optimisations dépendent **du matériel de chaque PC**, donc aucun script ne doit les faire à l'aveugle :

| À vérifier | Pourquoi | Comment |
|---|---|---|
| **EXPO / XMP** (vitesse de la RAM) | Beaucoup de PC tournent avec la RAM **bridée** (par ex. 4800 MHz au lieu de 6000), ce qui fait perdre 5 à 15 % de FPS | BIOS (touche **Suppr** au démarrage) → active **EXPO** (AMD) ou **XMP** (Intel), profil 1 → **F10** |
| **BIOS à jour** | Stabilité, sécurité, compatibilité RAM | Site du fabricant de la carte mère + clé USB en FAT32. ⚠️ **Réactive EXPO/XMP après**, la mise à jour efface les réglages |
| **Pilotes chipset** | Performance et stabilité | Site d'AMD ou d'Intel, rubrique « chipset » de ta plateforme |
| **Pilote de carte graphique** | FPS, corrections de bugs | NVIDIA App / AMD Software |
| **Santé des SSD** | Anticiper une panne | [CrystalDiskInfo](https://crystalmark.info) |
| **Logiciels inutiles** | Chaque PC a les siens | Paramètres → Applications : trie par taille et vire ce qui ne sert pas (vieux logiciels RGB, utilitaires de marque, launchers en double…) |
| **Écran à la bonne fréquence** | Un écran 144 Hz réglé à 60 Hz, ça arrive souvent | Paramètres → Affichage → Affichage avancé → Fréquence d'actualisation |

---

## ⚠️ Limites connues

- **Ce n'est pas Linux** : environ 80 % de l'expérience Omarchy. Il n'y a pas les animations fluides de Hyprland.
- Les **panneaux Windows** (Wi-Fi, volume, calendrier) s'ouvrent **en bas à droite** : Windows ne permet pas de les déplacer.
- La **barre Windows** est cachée par un petit script. Une grosse mise à jour Windows peut la faire réapparaître : il suffit de lancer **Réparer Mamumi-Os**.
- **Zebar 3.3** peut planter (rarement) à l'ouverture d'un panneau. La barre est alors **relancée automatiquement**.
- Sur **Windows Pro/Famille**, Windows peut ignorer en partie le masquage de la section « Recommandé » du menu Démarrer.
- **Win + L** (verrouiller) reste réservé à Windows et ne peut pas être réaffecté.

---

## 🏗️ Comment c'est construit

```
Mamumi-Os/
├── install.ps1                  # commande en une ligne : télécharge le dépôt et lance setup.ps1
├── setup.ps1                    # installation complète  (-Repair : réparation, -Yes : sans question)
├── admin.ps1                    # partie administrateur : point de restauration, stratégies, télémétrie, HAGS
├── config/
│   ├── glazewm/config.yaml      # raccourcis, couleurs, jeux ignorés, espaces de travail
│   ├── zebar/settings.json      # quelle barre lancer
│   ├── zebar/tokyo-night/       # la barre du haut (Preact + htm, CSS, permissions)
│   │   └── vendor/              #   bibliothèques et police d'icônes embarquées (zéro Internet)
│   ├── keys.txt                 # liste du panneau des raccourcis (Win + K)
│   └── terminal/tokyo-night.json# palette et réglages de Windows Terminal (fusionnés, pas écrasés)
└── tools/
    ├── taskbar-guard.cs         # programme compilé : cache la barre Windows, relance la barre du haut
    │                            #   si elle plante, rend la barre Windows si GlazeWM n'est plus là,
    │                            #   et range les fenêtres en spirale (via l'IPC de GlazeWM)
    ├── flyout.cs                # mini-programme (compilé à l'installation avec le compilateur
    │                            #   intégré à Windows) qui ouvre les panneaux natifs instantanément
    ├── keys.cs                  # panneau des raccourcis Win + K (compilé à l'installation)
    ├── backup.ps1               # sauvegarde
    └── uninstall.ps1            # désinstallation
```

**Choix techniques :**
- **Aucun logiciel en plus** de GlazeWM : tout le reste utilise ce qui est déjà dans Windows (registre, PowerShell 5.1, compilateur C# du .NET Framework).
- Ce qui tourne en fond est **compilé** plutôt qu'écrit en PowerShell : environ 25 Mo au lieu d'environ 80 Mo.
- Les outils sont dans `C:\ProgramData\Mamumi-Os`, un chemin **sans espace**, parce que GlazeWM ne sait pas lancer un chemin entre guillemets.
- Les panneaux natifs passent par un **petit `.exe` compilé** plutôt que par PowerShell : on passe d'environ 1 s de délai à un lancement instantané.
- Les configs existantes sont **sauvegardées avant d'être modifiées** (`*.avant-mamumi`). La config du terminal est **fusionnée**, pas écrasée.

---

## 🙏 Crédits

- [Omarchy](https://omarchy.org) par DHH, l'inspiration
- [GlazeWM et Zebar](https://github.com/glzr-io) par glzr-io
- [Preact](https://preactjs.com) et [htm](https://github.com/developit/htm), pour la barre
- L'idée de la spirale vient des scripts d'« autotiling » cités par GlazeWM ([GAT-GWM](https://github.com/Dutch-Raptor/GAT-GWM))
- Palette [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) par enkia

Licence : MIT. Utilise, modifie et partage librement.
