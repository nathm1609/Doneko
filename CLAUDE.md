# Doneko — app to-do dans la barre de menu macOS

Doneko (*done* + *neko*, « chat » en japonais) est une petite app de to-do qui vit dans la barre de menu.
Un clic sur la tête de chat (ou ⌃⌥⌘D) ouvre un panneau : on tape ce qu'il reste à faire, et un clic sur une tâche
la fait « tomber de la table », comme un chat pousse un objet du bord.

**La direction artistique complète est dans `DESIGN.md`. La lire avant tout travail d'interface et la respecter
strictement** (palette, typographie, icônes, animations, micro-textes).

## Périmètre

### V0 — MVP (à construire en premier)
- Icône tête de chat dans la barre de menu, aucune icône dans le Dock (`LSUIElement = YES`).
- Icône éveillée s'il reste des tâches, endormie sinon ; compteur de tâches restantes à côté (masqué à 0).
- Panneau de 320 pt : champ de saisie en haut, liste des tâches, section repliable « Tombé aujourd'hui ».
- Entrée ajoute la tâche et garde le focus dans le champ.
- Clic sur le rond (ou Espace sur la ligne sélectionnée) : animation « coup de patte », toast « Annuler » pendant 5 s,
  puis la tâche passe dans « Tombé aujourd'hui ».
- « Tombé aujourd'hui » est vidé automatiquement chaque jour (à minuit, au démarrage, au réveil de veille).
- Double-clic pour modifier une tâche ; ⌫ pour la supprimer (avec annulation).
- Clavier : ↑/↓ pour naviguer, Espace pour cocher, ⌫ pour supprimer, ⌘Z pour annuler, Échap pour fermer.
- Raccourci global ⌃⌥⌘D (⌥⌘D est réservé par macOS au masquage du Dock) pour ouvrir le panneau, curseur directement dans le champ.
- Option « Lancer au démarrage ».
- Sauvegarde automatique locale.

### V1 — Confort
- Réorganisation par glisser-déposer.
- `!` en fin de saisie = tâche prioritaire (point Sakura, remontée en haut).
- Dates en langage naturel en français (« demain », « lundi », « le 20 ») → échéance, sections « Aujourd'hui » / « Plus tard ».
- Fenêtre de réglages : raccourci personnalisable, heure de purge, son, affichage du compteur.

### V2 — Intégrations
- Export automatique des tâches faites en Markdown dans un dossier Obsidian choisi
  (une note par jour `YYYY-MM-DD.md`, section « Fait avec Doneko »).
- Notifications de rappel pour les tâches avec échéance.
- Synchronisation iCloud (en dernier).

### V3 — iPhone et dossiers (en cours)
App iPhone synchronisée avec le Mac par iCloud Drive, fusion tâche par tâche, dossiers sur les deux apps.
Demande reformulée, décisions et plan par étapes : `PLAN-V3.md`. Chaque étape est validée par l'utilisateur
avant la suivante.

Ne pas commencer V1 tant que V0 n'est pas terminé, testé et validé par l'utilisateur. Même règle pour V2 et V3.

## Stack
- Swift 5.10+, SwiftUI, macOS 14+ (Sonoma), framework Observation (`@Observable`).
- Icône `NSStatusItem` + panneau `NSPanel` (AppKit) qui héberge la vue SwiftUI : sous macOS 27, un `MenuBarExtra`
  ne peut pas être ouvert par code, ce qu'exige le raccourci ⌃⌥⌘D.
- Stockage JSON (`Codable`) dans `~/Library/Application Support/Doneko/todos.json`, ou dans iCloud Drive
  (`Doneko/todos.json`) si la synchronisation est activée : sans compte Apple Developer payant, pas de CloudKit.
- Raccourci global : package Swift `KeyboardShortcuts` (sindresorhus).
- Lancement au démarrage : `SMAppService.mainApp`.
- Projet généré avec XcodeGen à partir de `project.yml`.
- Bundle identifier : `com.nathanmarchant.doneko` (Mac), `com.nathanmarchant.doneko.ios` (iPhone).
- App iPhone : SwiftUI, iOS 17+, iPhone seulement, en portrait. Compte Apple gratuit (« Personal Team ») : pas de
  CloudKit ni de conteneur iCloud, l'app installée sur un iPhone expire au bout de 7 jours.
- Code commun aux deux apps dans `Shared/` (modèle, store, persistance, thème, couleurs, mascottes), testé par la cible Mac.
- Tests : XCTest.

## Structure
```
Doneko/
├── project.yml
├── CLAUDE.md
├── DESIGN.md
├── PLAN-V3.md                   # V3 : iPhone, synchronisation, dossiers
├── Shared/                      # compilé dans les deux apps
│   ├── Models/
│   │   ├── TodoItem.swift       # Syncable ; id, title, createdAt, completedAt?, isPriority, dueDate?, order, folderID?, updatedAt?, deletedAt?
│   │   └── Folder.swift         # id, name, order, updatedAt?, deletedAt?
│   ├── Store/
│   │   ├── TodoStore.swift      # @Observable : tâches, dossiers, #nom, undo, purge, fusion ; dates en français
│   │   ├── Persistence.swift    # SavedList { items, folders } en JSON atomique (lit aussi l'ancien tableau), lecture sans attendre iCloud, versions en conflit
│   │   ├── Clock.swift          # protocole d'horloge injectable (tests de purge)
│   │   └── SettingsKey.swift    # clés des réglages (UserDefaults)
│   ├── Services/
│   │   └── Reminders.swift      # notification le jour de l'échéance, à l'heure choisie (Mac et iPhone)
│   ├── Views/
│   │   ├── EmptyState.swift     # mascotte endormie ou contente
│   │   ├── PawPad.swift         # rond « coussinet » (16 pt sur Mac, 22 pt sur iPhone)
│   │   └── UndoToast.swift      # « … · Annuler »
│   ├── Design/
│   │   └── Theme.swift          # couleurs, tailles, durées d'animation issues de DESIGN.md
│   └── Resources/
│       └── Shared.xcassets      # couleurs nommées, mascottes, patte
├── DonekoiOS/                   # app iPhone
│   ├── DonekoiOSApp.swift       # point d'entrée : store, synchronisation, purge, rappels, pastille
│   ├── Info.plist
│   ├── Views/
│   │   ├── TodoListView.swift   # sections, « Tombé aujourd'hui », toast, dossiers et saisie en bas, bouton ⚙︎
│   │   ├── TodoRow.swift        # coup de patte, modifier au toucher, balayer, appui long (Prioritaire, Ranger dans)
│   │   ├── FolderBar.swift      # « Tout », dossiers, « + » ; appui long : renommer, déplacer, supprimer
│   │   └── SettingsView.swift   # synchronisation, heure de vidage, rappels, son, pastille
│   ├── Services/
│   │   ├── FolderSync.swift     # dossier iCloud Drive › Doneko choisi dans Fichiers (signet), relu toutes les 5 s
│   │   ├── DailyPurge.swift     # vide « Tombé aujourd'hui », ou le masque seulement si la liste est partagée avec le Mac
│   │   └── Badge.swift          # nombre de tâches du jour sur l'icône
│   └── Resources/
│       ├── Assets.xcassets      # AppIcon iOS (taille unique 1024)
│       └── Pop.wav              # « pop » feutré, généré par Artwork/make-pop.py
├── Doneko/                      # app Mac
│   ├── DonekoApp.swift          # point d'entrée, AppDelegate (store, purge, raccourci ⌃⌥⌘D)
│   ├── Info.plist               # LSUIElement = YES
│   ├── Views/
│   │   ├── PanelView.swift
│   │   ├── InputField.swift
│   │   ├── FolderBar.swift      # « Tout », dossiers, « + » ; clic droit : renommer, déplacer, supprimer
│   │   ├── TodoRow.swift        # rond « coussinet », animation coup de patte
│   │   ├── DoneSection.swift    # « Tombé aujourd'hui », titres de section
│   │   ├── SettingsView.swift
│   │   └── SwipeToDelete.swift  # glisser à deux doigts vers la gauche
│   ├── Services/
│   │   ├── MenuBarController.swift # icône + compteur, panneau NSPanel
│   │   ├── HotkeyService.swift
│   │   ├── LaunchAtLogin.swift
│   │   ├── DailyPurge.swift
│   │   ├── ICloudSync.swift     # liste dans iCloud Drive, fusionnée quand un autre appareil la change
│   │   └── ObsidianExport.swift # note du jour AAAA-MM-JJ.md, section « Fait avec Doneko » ; créé avant la purge
│   └── Resources/
│       └── Assets.xcassets      # icônes MenuIcon* de la barre de menu, AppIcon Mac
└── DonekoTests/
    ├── TodoStoreTests.swift
    ├── PersistenceTests.swift
    ├── DailyPurgeTests.swift
    ├── FolderTests.swift        # dossiers, #nom, filtre, suppression avec annulation, sync
    ├── ICloudSyncTests.swift
    ├── MergeTests.swift         # Mac et iPhone sur le même fichier : hors ligne, suppressions, même seconde
    ├── ObsidianExportTests.swift
    ├── RemindersTests.swift
    └── MenuBarControllerTests.swift
```

## Commandes
- Générer le projet : `xcodegen generate`
- Compiler : `xcodebuild -project Doneko.xcodeproj -scheme Doneko -configuration Debug -derivedDataPath build build`
- Tester : `xcodebuild -project Doneko.xcodeproj -scheme Doneko -derivedDataPath build test`
- Lancer : `open build/Build/Products/Debug/Doneko.app`
- Relancer après modification : `pkill -x Doneko; open build/Build/Products/Debug/Doneko.app`
- DMG pour une release GitHub : `./make-dmg.sh` → `build/Doneko.dmg`
- Compiler l'app iPhone (simulateur) :
  `xcodebuild -project Doneko.xcodeproj -scheme DonekoiOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build`
- Lancer dans le simulateur : `build/Build/Products/Debug-iphonesimulator/DonekoiOS.app`
  (outil simulateur, ou `xcrun simctl install booted …` puis `xcrun simctl launch booted com.nathanmarchant.doneko.ios`)

Prérequis sur la machine : Xcode complet installé, `brew install xcodegen`.

## Règles de travail
- Toute la logique métier vit dans `TodoStore`, jamais dans les vues.
- Chaque fonctionnalité du store a ses tests unitaires avant d'être branchée à l'interface.
- L'heure est injectée via `Clock` : aucun `Date()` direct dans la logique.
- Écriture JSON atomique (fichier temporaire puis remplacement). Fichier abîmé → renommé en `todos.json.bak`, liste vide, pas de crash.
  Fichier pas encore téléchargé par iCloud → ni renommé, ni écrasé.
- Synchronisation : toute modification d'une tâche date `updatedAt` avec `stamp(after:)`, et une suppression la garde
  30 jours avec `deletedAt` (jamais de retrait sec, sinon l'autre appareil la ferait revenir). Même règle pour tout
  nouvel élément synchronisé (dossiers).
- Ne jamais modifier le `.xcodeproj` à la main : modifier `project.yml` puis regénérer.
- Toutes les valeurs visuelles (couleurs, tailles, durées) passent par `Theme.swift`, jamais en dur dans les vues.
- Respecter « Réduire les animations » (fondu simple à la place des mouvements).
- Libellés VoiceOver sur tous les éléments interactifs.
- Interface et micro-textes en français, repris tels quels de `DESIGN.md`.
- Après chaque étape : compiler, lancer les tests, lancer l'app. Ne passer à la suite que si tout est vert,
  puis résumer en quelques lignes ce qui a été fait et comment le vérifier.

## Plan d'exécution V0
1. Squelette : `project.yml`, `Info.plist`, `DonekoApp.swift` avec un `MenuBarExtra` minimal. Vérifier : icône dans la barre, rien dans le Dock.
2. Modèle + store + tests (ajout, complétion, annulation, suppression, édition).
3. Persistance JSON + tests (sauvegarde, rechargement, fichier corrompu).
4. `Theme.swift` et Asset Catalog : couleurs nommées clair/sombre, icônes SVG de la barre de menu (template), AppIcon.
5. Interface : panneau, champ, lignes, rond « coussinet », section « Tombé aujourd'hui », état vide.
6. Animation « coup de patte », toast d'annulation, retour haptique.
7. Navigation clavier complète.
8. Icône éveillée/endormie + compteur dans la barre de menu.
9. Purge quotidienne (minuit, démarrage, réveil) + tests avec horloge simulée.
10. Raccourci global ⌃⌥⌘D et lancement au démarrage.
11. Passe finale : relecture de `DESIGN.md` point par point, modes clair et sombre, « Réduire les animations », VoiceOver.
