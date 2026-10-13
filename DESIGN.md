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

---

## Palette

Couleurs nommées pour être utilisées telles quelles dans le code (`Color("Mandarine")` dans l'Asset Catalog, avec variantes clair/sombre).

| Nom | Rôle | Clair | Sombre |
|---|---|---|---|
| **Mandarine** | Accent principal, mascotte, focus | `#FF8A3D` | `#FF9B57` |
| **Crème** | Fond du panneau | `#FBF7F0` | `#1C1A22` |
| **Coussin** | Surface des lignes au survol, champ de saisie | `#F2ECE2` | `#26232E` |
| **Encre** | Texte principal | `#1F1B24` | `#F2EEF6` |
| **Moustache** | Texte secondaire, tâches faites, séparateurs | `#9A93A3` | `#8A8394` |
| **Matcha** | Confirmation, coche validée | `#5DB27F` | `#6FC892` |
| **Sakura** | Priorité (`!`) | `#F2668B` | `#FF7FA0` |

Règles :
- La Mandarine est rare : focus, coche au survol, mascotte, compteur. Pas de grands aplats orange.
- Contraste texte/fond au minimum AA (4,5:1) dans les deux modes.
- Le mode clair/sombre suit le système.

---

## Typographie

Police système **SF Pro Rounded** (aucune police à installer) :
`.fontDesign(.rounded)` appliqué à la racine du panneau.

| Usage | Taille | Graisse |
|---|---|---|
| Champ de saisie | 14 pt | Regular |
| Texte d'une tâche | 13 pt | Regular |
| Titres de section (« Tombé aujourd'hui ») | 11 pt | Semibold, majuscules, interlettrage +0,5 |
| Toast, état vide, aide | 12 pt | Regular |
| Compteur dans la barre de menu | 12 pt | Medium, chiffres à chasse fixe (`.monospacedDigit()`) |

---

## Icônes

### Icône de barre de menu
- Tête de chat minimaliste dessinée en vecteur (SVG dans l'Asset Catalog, « Preserve Vector Data » activé, rendu **Template** pour s'adapter à la barre claire/sombre).
- Taille de dessin : 18 × 18 pt, trait de 1,5 pt, formes pleines simples.
- Deux variantes : `MenuIconAwake` (yeux ouverts) et `MenuIconAsleep` (yeux fermés + petit z).
- Le compteur s'affiche à droite de la tête quand il reste au moins une tâche ; masqué à 0.

### Icône de l'app (Finder, réglages, « À propos »)
- Carré arrondi macOS, fond Crème, tête de chat Mandarine au centre, légère ombre portée douce.
- Fournir un SVG source et générer toutes les tailles de l'`AppIcon`.

### Coche des tâches
- Pas une case carrée : un **rond façon coussinet de patte** (cercle de 16 pt, contour Moustache 1,5 pt).
- Au survol : le contour passe en Mandarine et une minuscule empreinte de patte apparaît à l'intérieur.
- Une fois cochée : remplissage Matcha avec une coche blanche, juste avant l'animation de chute.

Les autres icônes utilisent les SF Symbols, en version arrondie quand elle existe.

---

## Mise en page du panneau

- Largeur fixe : **320 pt**. Hauteur qui s'adapte au contenu, maximum 480 pt puis défilement.
- Coins arrondis : 14 pt. Marges internes : 12 pt.
- Ordre vertical : champ de saisie → tâches à faire → section repliable « Tombé aujourd'hui » → barre basse discrète (réglages, quitter).
- Hauteur d'une ligne : 32 pt, espacement 2 pt, coins 8 pt, fond Coussin uniquement au survol ou à la sélection clavier.
- Tâche prioritaire : petit point Sakura à gauche du texte, remontée en haut de liste.

---

## Animations

L'animation de complétion est la signature de l'app. Tout le reste reste sobre.

**Le coup de patte (complétion)**
1. La coche se remplit en Matcha (120 ms).
2. Une petite patte Mandarine glisse depuis la gauche et touche la ligne (150 ms).
3. La ligne glisse vers la droite en pivotant légèrement (environ 8°) et s'estompe, comme un objet qui tombe de la table (300 ms, ressort doux).
4. Les lignes suivantes remontent pour combler l'espace (ressort, 250 ms).

**Autres mouvements**
- Ouverture du panneau : apparition native, aucun effet ajouté.
- Ajout d'une tâche : la ligne apparaît en glissant légèrement du haut (200 ms).
- Toast d'annulation : monte depuis le bas, disparaît après 5 s.
- Liste vide : la mascotte endormie « respire » très lentement (échelle 1 → 1,03, 3 s, en boucle).

**Accessibilité** : si « Réduire les animations » est activé dans macOS, remplacer tous les mouvements par un simple fondu de 150 ms.

**Retour tactile** : petit retour haptique du trackpad à la complétion (`NSHapticFeedbackManager`, motif `.alignment`).
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
| Info-bulle de l'icône | Doneko — 3 tâches sur la table |
| Réglages | Raccourci pour appeler Doneko |
| Quitter | Laisser Doneko dormir (Quitter) |

---

## Ce qu'on évite

- Les cases carrées et l'esthétique « formulaire administratif ».
- Les emojis dans l'interface (la mascotte suffit).
- Les couleurs saturées en grandes surfaces.
- Les animations longues ou qui bloquent la saisie : on doit pouvoir enchaîner les tâches sans attendre.
- Toute ressemblance avec un chat de personnage existant.
