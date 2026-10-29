# Doneko — Direction artistique

## Le concept

**Doneko** = *done* + *neko* (猫, « chat » en japonais).

L'idée centrale : **un chat fait tomber les objets posés sur une table, Doneko fait tomber tes tâches.**
Chaque tâche est un petit objet posé sur la table. Quand elle est faite, un coup de patte la pousse hors du bord. C'est ce geste, connu de tous ceux qui ont un chat, qui donne sa personnalité à l'app : malicieuse, rapide, satisfaisante.

Trois mots pour guider chaque décision :
- **Léger** : l'app se fait oublier, s'ouvre et se ferme en une seconde.
- **Malicieux** : un clin d'œil dans les détails, jamais envahissant.
- **Doux** : formes arrondies, couleurs chaudes, animations souples.

---

## La mascotte

Un chat roux tigré, stylisé, **original** (ne pas s'inspirer d'un personnage existant).
Tête ronde, deux oreilles triangulaires légèrement arrondies, yeux en amande, une petite tache crème sur le museau. Pas de bouche visible au repos.

Ses états, utilisés dans l'icône de la barre de menu et les écrans vides :

| État | Quand | Représentation |
|---|---|---|
| **Éveillé** | Il reste des tâches | Tête de chat, yeux ouverts |
| **Endormi** | Plus aucune tâche | Yeux fermés en arc, petit « z » |
| **Patte levée** | Au moment où une tâche est cochée | Une patte apparaît brièvement à côté de la ligne |
| **Content** | Toutes les tâches du jour faites | Yeux fermés en « ^ ^ », satisfait |

Dans le panneau vide, les états **Endormi** et **Content** sont des illustrations en couleur (96 pt), dans le style de
l'icône de l'app : `Artwork/MascotAsleep.webp` et `Artwork/MascotContent.webp`, générées avec Gemini sur fond magenta
uni, détourées par `swift Artwork/make-mascots.swift`. L'image-clé du saut de joie, `MascotCheer` (bouche ouverte), est
une retouche Gemini (Nano Banana Pro) de la mascotte contente, recalée sur elle (largeur aux joues, bas du collier) pour
qu'on passe de l'une à l'autre sans que la tête bouge.
La sieste est une vidéo en boucle : `Artwork/Videos/MascotNap.mp4`, générée avec Veo (Google Flow) sur fond magenta,
détourée et bouclée par `swift -O Artwork/make-animations.swift` en `MascotNap.mov` (HEVC avec transparence, 320 px).
L'image fixe `MascotAsleep` la remplace quand on réduit les animations. La barre de menu garde des icônes monochromes
(template).

---

## Palette

Couleurs nommées pour être utilisées telles quelles dans le code (`Color("Mandarine")` dans l'Asset Catalog, avec variantes clair/sombre).

| Nom | Rôle | Clair | Sombre |
|---|---|---|---|
| **Mandarine** | Accent principal, mascotte, focus | `#FF8A3D` | `#FF9B57` |
| **Crème** | Fond du panneau (teinte de sa matière sur Mac) | `#FBF7F0` | `#1C1A22` |
| **Coussin** | Surface des lignes au survol, champ de saisie | `#F2ECE2` | `#26232E` |
| **Encre** | Texte principal | `#1F1B24` | `#F2EEF6` |
| **Moustache** | Texte secondaire, tâches faites, séparateurs | `#6D6874` | `#90889A` |
| **Matcha** | Confirmation, coche validée | `#5DB27F` | `#6FC892` |
| **Sakura** | Priorité (`!`) | `#F2668B` | `#FF7FA0` |

Règles :
- La Mandarine est rare : focus, coche au survol, mascotte, compteur. Pas de grands aplats orange.
- Contraste texte/fond au minimum AA (4,5:1) dans les deux modes.
- Le mode clair/sombre suit le système ; sur l'iPhone, « Réglages › Apparence » peut imposer le clair ou le sombre.
- iPhone : la Mandarine est la teinte de l'app (boutons « OK », interrupteurs, curseur, calendrier). Le bouton ⚙︎ reste
  Moustache.

---

## Typographie

Police système **SF Pro Rounded** (aucune police à installer) :
`.fontDesign(.rounded)` appliqué à la racine du panneau.

| Usage | Taille | Graisse |
|---|---|---|
| Champ de saisie | 14 pt | Regular |
| Texte d'une tâche | 13 pt | Regular |
| Titres de section (« Tombé aujourd'hui ») | 11 pt | Semibold, majuscules, interlettrage +0,5 |
| Toast, état vide, aide, barre de dossiers, nom du dossier sur une ligne | 12 pt | Regular |
| Compteur dans la barre de menu | 12 pt | Medium, chiffres à chasse fixe (`.monospacedDigit()`) |

---

## Icônes

### Icône de barre de menu
- Tête de chat minimaliste dessinée en vecteur (SVG dans l'Asset Catalog, « Preserve Vector Data » activé, rendu **Template** pour s'adapter à la barre claire/sombre).
- Même silhouette que la mascotte de l'icône : tête large aux joues rondes, oreilles hautes et pointues, trois rayures sur le front, petit nez en triangle.
- Taille de dessin : 18 × 18 pt, trait de 1,5 pt, formes pleines simples.
- Images : `MenuIconAwake` (yeux ronds ouverts), `MenuIconBlink` (yeux fermés, pour cligner), `MenuIconAsleepHead`
  (yeux fermés en arc) et `MenuIconZ` (petit z, à part pour pouvoir monter), `MenuIconPaw` (patte du coup de tête,
  détachée de la tête par un vide de 1 pt). L'icône est composée en code à partir de ces images.
- Le compteur s'affiche à droite de la tête quand il reste au moins une tâche ; masqué à 0.
- Clic gauche : le panneau. Clic droit (ou ⌃ clic) : menu « Réglages… » / « Laisser Doneko dormir (Quitter) ».

### Icône de l'app (Finder, réglages, « À propos »)
- Carré arrondi macOS, fond Crème, tête de chat roux tigré Mandarine au centre, collier Matcha avec une coche,
  légère ombre portée douce.
- Illustration source `Artwork/AppIcon.png` (générée avec Gemini), découpée dans la forme macOS par
  `Artwork/AppIcon.svg` ; `Artwork/make-appicon.sh` génère toutes les tailles de l'`AppIcon`.
- iPhone : la même illustration en carré plein, sans ombre (iOS arrondit les coins), une seule taille de 1024 px.

### Fenêtre du DMG
- Fond Crème, piste d'empreintes Mandarine et flèche de l'app vers Applications, chat allongé dessous qui pousse
  de la patte. Pas de texte : le dessin suffit.
- Illustration source `Artwork/DMGBackground.webp` (générée avec Gemini), recadrée et unifiée par
  `Artwork/make-dmg-background.swift`, que `make-dmg.sh` appelle.

### Coche des tâches
- Pas une case carrée : un **rond façon coussinet de patte** (cercle de 16 pt, contour Moustache 1,5 pt).
- Au survol : le contour passe en Mandarine et une minuscule empreinte de patte apparaît à l'intérieur.
- Une fois cochée : remplissage Matcha avec une coche blanche, juste avant l'animation de chute.

Les autres icônes utilisent les SF Symbols, en version arrondie quand elle existe.

---

## Mise en page du panneau

- Largeur fixe : **320 pt**. Hauteur qui s'adapte au contenu, maximum 480 pt puis défilement.
- Coins arrondis : 14 pt. Marges internes : 12 pt.
- Fond : la matière translucide des panneaux de la barre de menu (comme le Centre de contrôle), teintée de Crème à
  82 % : le bureau transparaît à peine. Filet de bord Encre à 8 %, 0,5 pt. « Réduire la transparence » : Crème plein.
- Champ de saisie : fond Coussin, cerclé d'un filet Mandarine de 1 pt quand il a le curseur.
- Ordre vertical : champ de saisie → barre de dossiers → tâches à faire → section repliable « Tombé aujourd'hui » → barre basse discrète (bouton réglages ; quitter passe par le clic droit sur l'icône ou ⌘Q).
- Hauteur d'une ligne : 32 pt, espacement 2 pt, coins 8 pt, fond Coussin uniquement au survol ou à la sélection clavier.
- Tâche prioritaire : petit point Sakura à gauche du texte, remontée en haut de liste.

### Échéance au calendrier
- Au bout du champ : le bouton calendrier (SF Symbol `calendar`, Moustache, Mandarine quand le calendrier est
  ouvert), ou la date choisie pour la prochaine tâche (« Ven. 25 déc. », 12 pt). Une date tapée l'emporte.
- « Pour quand ? » s'ouvre à la place des tâches : titre de section, la tâche visée s'il y en a une, calendrier en
  français (lundi en premier, jours passés grisés), puis « Sans échéance » et « OK ». Un clic sur un jour le choisit
  et referme ; « OK » valide le jour sélectionné (aujourd'hui sans date) ; Échap referme sans rien changer.
- Clic droit sur une tâche : « Échéance… » ouvre le même calendrier pour elle.

### Dossiers
- Barre sous le champ : pastilles arrondies de 24 pt de haut, texte 12 pt : « Tout », les dossiers dans leur ordre, puis « + ».
  Pastille choisie : fond Coussin, texte Encre ; les autres : texte Moustache, sans fond. La barre défile
  horizontalement quand elle dépasse.
- Le dossier choisi filtre la liste (« Aujourd'hui », « Plus tard » et « Tombé aujourd'hui » restent) et reçoit les
  nouvelles tâches. Le choix est mémorisé sur chaque appareil.
- `#nom` dans la saisie range la tâche, en créant le dossier au besoin : « Lait #courses demain ! ».
- Au bout de la ligne, une seule étiquette discrète (12 pt, Moustache, chiffres à chasse fixe) : le dossier (dans
  « Tout ») et l'échéance (« Plus tard »), séparés par un point médian : « courses · Sam. 16 janv. ».
- Clic droit sur une tâche : « Ranger dans ». Clic droit sur un dossier : « Renommer », « Vers la gauche »,
  « Vers la droite », « Supprimer le dossier ». Le nom se tape dans la pastille même, cerclée de Mandarine.
- ⌘1 : « Tout » ; ⌘2 à ⌘9 : les dossiers, dans l'ordre de la barre.
- Ni couleur ni emoji par dossier : un nom suffit.

---

## Écran iPhone

- Un seul écran en portrait, fond Crème. De haut en bas : la barre de navigation du système, avec le grand titre
  « Aujourd'hui » (la date dessous, « Jeudi 29 octobre », depuis iOS 26) et le bouton ⚙︎ des réglages (Moustache) à
  droite ; le titre se replie en haut quand la liste défile. Puis les tâches du jour, « Plus tard », « Tombé
  aujourd'hui » repliable ; enfin, à portée de pouce et au-dessus du clavier, le toast d'annulation, la barre de
  dossiers et le champ de saisie (capsule Coussin). Les tâches s'effacent sur 16 pt en passant sous cette barre.
- Tailles qui suivent Dynamic Type : tâches et champ en Body ; titres de section en Title 3 semi-gras, Encre, en
  minuscules, 12 pt d'air au-dessus ; nom du dossier, échéance et toast en Footnote ; pastilles de dossier en
  Subheadline. Titres de la barre de navigation en gras arrondi, Encre.
- « Tombé aujourd'hui 3 » : le nombre en Moustache, le chevron au bout de la ligne.
- Zone de toucher de 44 pt partout. Rond « coussinet » de 22 pt au centre de la sienne, patte de 26 pt de haut qui
  entre par le bord de l'écran. Pas de survol : le rond reste Moustache jusqu'à la coche.
- Pastilles de dossier de 32 pt de haut (zone de 44 pt), mêmes couleurs que sur le Mac. Le fond Coussin glisse vers
  la pastille touchée (ressort amorti, sans mouvement si on réduit les animations), avec le petit retour haptique de
  sélection.
- Très grand texte (tailles d'accessibilité) : le rond, la patte et le point Sakura grandissent avec le texte ; le
  dossier et l'échéance passent sous le titre au lieu de l'écraser.
- Balayer vers la gauche révèle le « Supprimer » rouge du système : la convention d'iOS l'emporte ici sur la règle
  des grands aplats saturés, le bouton n'apparaissant que le temps du geste.
- Gestes :
  - toucher le rond : coup de patte, vibration légère ;
  - toucher le texte : modifier ; toucher ailleurs garde la modification ;
  - balayer vers la gauche : « Supprimer » ;
  - appui long : « Prioritaire », « Échéance… », « Ranger dans », « Supprimer » ; appui long puis glisser : changer
    de place ;
  - appui long sur un dossier : le menu du Mac, avec icônes ; un nom de dossier se tape dans une alerte ;
  - tirer la liste vers le bas : relire la liste partagée avec le Mac.
- Bouton ⚙︎ (Moustache) en haut à droite : « Réglages » en feuille. La synchronisation avec le Mac s'y règle.
- Feuilles (« Réglages », « Pour quand ? ») sur fond Crème, cases Coussin : la même matière que la liste, en clair
  comme en sombre.
- Bouton calendrier au bout du champ, comme sur le Mac ; « Pour quand ? » s'ouvre en feuille juste assez haute pour
  le calendrier (470 pt), avec « Sans échéance » à gauche et « OK » à droite. Balayer la feuille annule.
- Pastille rouge du système sur l'icône : le nombre de tâches du jour, comme le compteur de la barre de menu.
- « Pop » feutré optionnel (désactivé par défaut) : son propre à l'app (`Artwork/make-pop.py`), muet en silencieux.
- Liste entièrement vide : la mascotte au milieu de l'écran ; sinon à la place des tâches du jour, comme sur le Mac.

---

## Animations

L'animation de complétion est la signature de l'app. Tout le reste reste sobre.

**Le coup de patte (complétion)**
1. La coche se remplit en Matcha (120 ms).
2. Une patte rousse (20 pt de haut) entre par le bord gauche de la ligne, se pose sur le rond et recule un peu pour
   prendre son élan (270 ms). Elle est jouée image par image, à 30 images/s : `PawPush00` à `PawPush12`, tirées de la
   vidéo Veo `Artwork/Videos/PawPush.mp4` par `Artwork/make-animations.swift`.
3. La ligne glisse vers la droite en pivotant légèrement (environ 8°) et s'estompe, comme un objet qui tombe de la table (300 ms, ressort doux) ;
   la patte pousse avec elle et s'efface.
4. Les lignes suivantes remontent pour combler l'espace (ressort amorti, sans rebond, 250 ms).

**Autres mouvements**
- Ouverture du panneau : apparition native, aucun effet ajouté.
- Ajout d'une tâche : la ligne apparaît en glissant légèrement du haut (200 ms).
- Toast d'annulation : capsule Encre à l'ombre douce, qui monte depuis le bas et disparaît après 5 s.
- Appui sur un bouton (rond, pastilles, calendrier, ⚙︎, « Annuler ») : il se resserre dès l'appui (94 %, 100 ms),
  sans attendre le relâchement ; il pâlit à la place si on réduit les animations.
- Tout ce qui se range sans élan (ajout, lignes qui remontent, toast) suit un ressort amorti, sans rebond. Seuls les
  gestes qui ont de l'élan dépassent un peu : la tâche poussée hors de la table, le glisser pour supprimer.
- Liste vide : la mascotte endormie fait la sieste en vidéo (9,5 s en boucle) : elle respire, ses « z » montent, sa
  bouche s'entrouvre. La vidéo ne tourne que lorsqu'on la voit (panneau ouvert, app au premier plan). La mascotte
  contente se balance d'un côté à l'autre (±3°, 3 s).

**La mascotte réagit**
- Tête de la barre de menu, quand le nombre de tâches du jour change (400 ms) :
  - une tâche arrive (ajout, annulation, échéance qui tombe aujourd'hui) : petit saut de 2 pt ; endormie, elle se
    réveille en sautant ;
  - une tâche part (faite, supprimée) : coup de tête vers la droite (14°) et petite patte levée, comme pour la pousser
    hors de la table, puis léger balancement ; après la dernière, elle s'endort.
- Tête de la barre de menu au repos, toutes les 6 à 14 s : éveillée, elle cligne des yeux (150 ms) ; endormie, son « z »
  monte de 2 pt en s'effaçant puis revient (1,4 s).
- Panneau vide : la mascotte contente saute de joie en arrivant (montée de 12 pt, retombée avec rebond), avec
  l'image `MascotCheer` le temps du saut (fondu de 120 ms). Un clic la fait sauter de nouveau ; endormie, elle se
  tortille dans son sommeil, puis se rendort.

**Accessibilité** : si « Réduire les animations » est activé dans macOS ou iOS, remplacer tous les mouvements par un simple fondu de 150 ms.

**Retour tactile** : petit retour haptique du trackpad à la complétion (`NSHapticFeedbackManager`, motif `.alignment`) ;
sur l'iPhone, vibration légère (`sensoryFeedback(.impact(weight: .light))`).
**Son** : un « pop » feutré optionnel, désactivé par défaut.

---

## Ton et micro-textes

Tutoiement, phrases courtes, une pointe d'humour félin, jamais de jeu de mots forcé.

| Endroit | Texte |
|---|---|
| Champ de saisie vide | Qu'est-ce qu'on fait tomber aujourd'hui ? |
| Liste vide | Plus rien sur la table. Doneko fait la sieste. |
| Toutes les tâches du jour faites | Table rase ! Bien joué. |
| Toast après complétion | Doneko l'a fait tomber · **Annuler** |
| Section des tâches faites | Tombé aujourd'hui (3) |
| Suppression | Tâche supprimée · **Annuler** |
| Barre de dossiers | Tout · courses · maison · + |
| Bouton « + » (info-bulle, VoiceOver) | Nouveau dossier |
| Clic droit sur une tâche | Ranger dans › Aucun dossier, puis les dossiers |
| Clic droit sur un dossier | Renommer · Vers la gauche · Vers la droite · Supprimer le dossier |
| Suppression d'un dossier | Dossier supprimé · **Annuler** |
| Appui long sur une tâche (iPhone) | Prioritaire · Échéance… · Ranger dans · Supprimer |
| Bouton calendrier (info-bulle, VoiceOver) | Choisir une date · Changer la date · Échéance : ven. 25 déc. |
| Calendrier | Pour quand ? · Sans échéance · OK |
| Clic droit sur une tâche (en plus) | Échéance… |
| Balayer une tâche vers la gauche (iPhone) | Supprimer |
| Nouveau dossier (iPhone, alerte) | Nouveau dossier · Nom du dossier · Annuler · Créer |
| Renommer un dossier (iPhone, alerte) | Renommer le dossier · Annuler · Renommer |
| Réglages (iPhone) | Synchronisation avec le Mac · Dossier · Arrêter la synchronisation · Choisir le dossier Doneko… |
| | Apparence · Automatique · Clair · Sombre |
| | Vider « Tombé aujourd'hui » à · Rappeler les tâches datées à · Petit « pop » quand une tâche tombe · Afficher le nombre de tâches sur l'icône |
| Titre de l'écran (iPhone) | Aujourd'hui · Jeudi 29 octobre |
| Rappel | (titre de la tâche) — C'est pour aujourd'hui. |
| Info-bulle de l'icône | Doneko — 3 tâches sur la table |
| Réglages | Raccourci pour appeler Doneko |
| Réglages › Mise à jour (Mac) | Mise à jour · Version 1.4.0 · Rechercher · Recherche d'une nouvelle version… · Doneko 1.4.0 est la dernière version · Doneko 1.5.0 est disponible · Installer et relancer · Installation… Doneko va se relancer · GitHub ne répond pas, réessaie plus tard · L'installation a échoué : télécharge le DMG sur GitHub |
| Quitter | Laisser Doneko dormir (Quitter) |

---

## Ce qu'on évite

- Les cases carrées et l'esthétique « formulaire administratif ».
- Les emojis dans l'interface (la mascotte suffit).
- Les couleurs saturées en grandes surfaces.
- Les animations longues ou qui bloquent la saisie : on doit pouvoir enchaîner les tâches sans attendre.
- Toute ressemblance avec un chat de personnage existant.
