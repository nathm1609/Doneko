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

Ne pas commencer V1 tant que V0 n'est pas terminé, testé et validé par l'utilisateur. Même règle pour V2.

## Stack
- Swift 5.10+, SwiftUI, macOS 14+ (Sonoma), framework Observation (`@Observable`).
- Icône `NSStatusItem` + panneau `NSPanel` (AppKit) qui héberge la vue SwiftUI : sous macOS 27, un `MenuBarExtra`
  ne peut pas être ouvert par code, ce qu'exige le raccourci ⌃⌥⌘D.
- Stockage JSON (`Codable`) dans `~/Library/Application Support/Doneko/todos.json`, ou dans iCloud Drive
  (`Doneko/todos.json`) si la synchronisation est activée : sans compte Apple Developer payant, pas de CloudKit.
- Raccourci global : package Swift `KeyboardShortcuts` (sindresorhus).
- Lancement au démarrage : `SMAppService.mainApp`.
- Projet généré avec XcodeGen à partir de `project.yml`.
- Bundle identifier : `com.nathanmarchant.doneko`.
- Tests : XCTest.

## Structure
```
Doneko/
├── project.yml
├── CLAUDE.md
├── DESIGN.md
├── Doneko/
│   ├── DonekoApp.swift          # point d'entrée, AppDelegate (store, purge, raccourci ⌃⌥⌘D)
│   ├── Info.plist               # LSUIElement = YES
│   ├── Models/
│   │   └── TodoItem.swift       # id, title, createdAt, completedAt?, isPriority, dueDate?, order
│   ├── Store/
│   │   ├── TodoStore.swift      # @Observable : add, complete, uncomplete, undo, delete, edit, move, purge ; dates en français
│   │   ├── Persistence.swift    # lecture / écriture JSON atomique
│   │   └── Clock.swift          # protocole d'horloge injectable (tests de purge)
│   ├── Views/
│   │   ├── PanelView.swift
│   │   ├── InputField.swift
│   │   ├── TodoRow.swift        # rond « coussinet », animation coup de patte
│   │   ├── DoneSection.swift    # « Tombé aujourd'hui », titres de section
│   │   ├── EmptyState.swift     # mascotte endormie
│   │   ├── UndoToast.swift
│   │   └── SwipeToDelete.swift  # glisser à deux doigts vers la gauche
│   ├── Design/
│   │   └── Theme.swift          # couleurs, tailles, durées d'animation issues de DESIGN.md
│   ├── Services/
│   │   ├── MenuBarController.swift # icône + compteur, panneau NSPanel
│   │   ├── HotkeyService.swift
│   │   ├── LaunchAtLogin.swift
│   │   ├── DailyPurge.swift
│   │   ├── ICloudSync.swift     # liste dans iCloud Drive, relue quand un autre Mac la change
│   │   ├── ObsidianExport.swift # note du jour AAAA-MM-JJ.md, section « Fait avec Doneko »
│   │   └── Reminders.swift      # notification le jour de l'échéance, à l'heure choisie
│   └── Resources/
│       └── Assets.xcassets      # couleurs nommées, icônes MenuIcon* de la barre de menu, mascottes, patte, AppIcon
└── DonekoTests/
    ├── TodoStoreTests.swift
    ├── PersistenceTests.swift
    ├── DailyPurgeTests.swift
    ├── ICloudSyncTests.swift
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

Prérequis sur la machine : Xcode complet installé, `brew install xcodegen`.

## Règles de travail
- Toute la logique métier vit dans `TodoStore`, jamais dans les vues.
- Chaque fonctionnalité du store a ses tests unitaires avant d'être branchée à l'interface.
- L'heure est injectée via `Clock` : aucun `Date()` direct dans la logique.
- Écriture JSON atomique (fichier temporaire puis remplacement). Fichier illisible → renommé en `todos.json.bak`, liste vide, pas de crash.
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
