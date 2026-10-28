# Doneko V3 — iPhone, synchronisation et dossiers

## La demande, reformulée

> Construire **Doneko pour iPhone** : la même app (direction artistique de `DESIGN.md`, même logique, mêmes
> micro-textes), adaptée au tactile. **La liste est la même sur le Mac et sur l'iPhone** : ce qui est ajouté, coché,
> modifié ou supprimé sur l'un apparaît sur l'autre en quelques secondes, y compris après une modification faite hors
> connexion. Ajouter, **sur les deux apps**, les **dossiers** : ranger chaque tâche dans un dossier (ou aucun),
> filtrer la liste par dossier, créer, renommer, réordonner et supprimer les dossiers.
>
> Contraintes : compte Apple gratuit (équipe personnelle), aucun serveur tiers, l'app Mac garde tout ce qu'elle fait
> aujourd'hui, toute la logique dans le code partagé et testée (XCTest) avant d'être branchée à l'interface, règles de
> `CLAUDE.md` inchangées. Une étape à la fois : à la fin de chacune, compiler, tester, lancer, résumer comment vérifier,
> puis **attendre la validation** avant la suivante.

## Décisions prises le 2026-10-28

Compte Apple gratuit (sync par iCloud Drive) ; saisie en bas sur l'iPhone ; dossiers affichés en barre de filtres ;
supprimer un dossier remet ses tâches dans « Tout ».

## Ce que je corrige ou améliore au passage

1. **Fusion tâche par tâche au lieu de « le dernier qui écrit gagne ».** La sync actuelle (un fichier dans iCloud
   Drive) convient à deux Mac rarement utilisés en même temps. Un iPhone, lui, modifie souvent la liste hors ligne
   (métro, avion) : au retour du réseau, il écraserait ce que le Mac a fait entre-temps. Chaque tâche et chaque dossier
   porte donc une date de modification, une suppression laisse une trace pendant 30 jours (sinon la tâche
   « ressusciterait » depuis l'autre appareil), et les deux versions sont fusionnées à chaque lecture et écriture.
2. **Code partagé.** Modèle, store, persistance, thème, couleurs et mascottes passent dans `Shared/`, compilé dans les
   deux apps : une seule logique, testée une fois.
3. **Export Obsidian sans trou.** Si l'iPhone vidait « Tombé aujourd'hui » à minuit avant que le Mac ait vu les tâches
   cochées sur l'iPhone, elles manqueraient dans Obsidian. L'iPhone masque donc les tâches de la veille ; le Mac les
   exporte puis les efface.
4. **Compatibilité du fichier.** Le format de `todos.json` évolue (dossiers, dates de modification) ; l'ancien format
   reste lisible. Il faut mettre à jour l'app Mac (1.2.0) sur tous les Mac **avant** d'activer la sync sur l'iPhone.
5. **Adaptations tactiles de `DESIGN.md`** (nouvelle section iOS) : lignes d'au moins 44 pt (zone de toucher),
   Dynamic Type, retour haptique iOS, badge sur l'icône à la place du compteur de la barre de menu.

## Ce que le compte gratuit impose

Vérifié dans Xcode : le compte est une équipe personnelle gratuite (« Personal Team »).

- Pas de CloudKit ni de conteneur iCloud. L'iPhone accède au fichier `iCloud Drive › Doneko › todos.json` (celui que
  la sync Mac utilise déjà) par le sélecteur Fichiers, une seule fois ; l'accès est ensuite mémorisé.
- L'app installée sur l'iPhone depuis Xcode **expire au bout de 7 jours** : il faut la relancer depuis Xcode (câble ou
  Wi-Fi). Trois apps perso au maximum sur l'appareil.
- La synchronisation passe par iCloud Drive : de quelques secondes à une minute, pas instantanée. Sans notification
  push, l'iPhone relit le fichier à l'ouverture, au retour au premier plan, toutes les 5 s quand l'app est ouverte, et
  quand on tire la liste vers le bas.
- Avec le programme développeur payant (99 €/an), on pourrait passer plus tard à CloudKit et TestFlight ; la fusion de
  l'étape 3 resterait utile.

## Fonctionnalités cibles

### Dossiers (Mac et iPhone)

- Barre de dossiers sous le champ de saisie : « Tout », puis les dossiers, puis « + » pour en créer. Le dossier choisi
  filtre la liste (les sections « Aujourd'hui » / « Plus tard » restent) et reçoit les nouvelles tâches. Le choix est
  mémorisé sur chaque appareil.
- `#nom` dans la saisie range la tâche, en créant le dossier s'il n'existe pas : « Lait #courses demain ! ».
- Dans « Tout », le nom du dossier s'affiche discrètement (Moustache) au bout de la ligne.
- Ranger une tâche : clic droit › « Ranger dans » (Mac), appui long (iPhone), ou `#nom` en la modifiant.
- Renommer, réordonner, supprimer un dossier. Supprimer un dossier remet ses tâches dans « Tout » (avec Annuler).
- Mac : ⌘1 pour « Tout », ⌘2 à ⌘9 pour les dossiers.
- Ni emoji ni couleur par dossier (règles de `DESIGN.md`).

### App iPhone

- Un seul écran : mêmes couleurs, SF Pro Rounded, rond « coussinet », patte, mascottes animées, micro-textes.
- Champ de saisie en bas, au-dessus du clavier (à portée de pouce) ; Retour ajoute la tâche et garde le clavier.
- Toucher le rond : coup de patte, vibration légère, toast « Annuler » pendant 5 s. Balayer vers la gauche : supprimer
  (avec Annuler). Toucher le texte : modifier. Appui long : menu (Prioritaire, Ranger dans, Supprimer). Glisser pour
  réordonner.
- « Tombé aujourd'hui » repliable, état vide avec la mascotte, badge du nombre de tâches du jour sur l'icône.
- Rappels des échéances, avec la même logique que sur le Mac.
- Réglages : synchronisation (choix du dossier iCloud Drive), heure de purge, heure de rappel, son, badge.
- iPhone seulement, en portrait, iOS 17 minimum.
- Absent sur iPhone : raccourci global, lancement au démarrage, export Obsidian (le Mac s'en charge).

## Plan par étapes

Chaque étape se termine par : compilation, tests, lancement, résumé de ce qui a été fait et de la façon de le vérifier,
puis ta validation.

| # | Étape | Ce que tu valides |
|---|---|---|
| 1 | **Code partagé et squelette iOS** : dossier `Shared/`, cible iOS dans `project.yml`, app iPhone minimale qui affiche, ajoute et coche des tâches stockées sur l'appareil, icône de l'app iOS. Périmètre V3 ajouté à `CLAUDE.md`. | L'app Mac marche comme avant (tests verts) ; l'app iPhone s'ouvre dans le simulateur avec les couleurs et la mascotte. |
| 2 | **Preuve de synchronisation** : sur l'iPhone, choisir `iCloud Drive › Doneko`, lire et écrire `todos.json`. | Sur **ton iPhone** : une tâche ajoutée sur le Mac apparaît sur l'iPhone, et inversement. Si ça échoue, on décide (compte payant ?) avant d'aller plus loin. |
| 3 | **Fusion tâche par tâche** dans le store, avec tests, utilisée aussi par le Mac. | Scénario hors ligne : modifier sur l'iPhone en mode avion, modifier sur le Mac, rien n'est perdu. |
| 4 | **Dossiers sur Mac** : modèle, format de fichier, `#nom`, créer/renommer/réordonner/supprimer/ranger (tests d'abord), puis barre de dossiers, menu « Ranger dans », ⌘1 à ⌘9 ; `DESIGN.md` complété. | Tu ranges tes tâches sur le Mac. |
| 5 | **Interface iPhone** : liste, saisie, coup de patte, toast, gestes, dossiers, état vide. | Captures et vidéo du simulateur, puis essai sur ton iPhone. |
| 6 | **Services iPhone** : purge quotidienne, rappels, badge, réglages. | Réglages, rappel reçu, badge. |
| 7 | **Passe finale** : `DESIGN.md` point par point sur les deux apps, clair et sombre, Dynamic Type, Réduire les animations, VoiceOver ; README, `CLAUDE.md`, note Obsidian ; version Mac 1.2.0 (DMG seulement sur ton feu vert). | Relecture finale. |

État au 2026-10-28 : les 7 étapes sont validées et commitées ; version Mac 1.2.0.

Pas prévu (à garder pour plus tard si besoin) : iPad, widget, Siri et Raccourcis, partage d'un dossier avec quelqu'un
d'autre, couleur ou icône par dossier.
