# Doneko — règles d'usage du logo

## 1. Le logo

**Idée** : Doneko fait un clin d'œil, et son œil fermé est une coche. *Done* + *neko* en un seul signe.

La tête reprend la silhouette de l'icône de la barre de menu. Le nom « doneko » est dessiné (anneaux, traits à bouts
ronds), pas tapé dans une police : ne pas le recomposer au clavier.

| Version | Fichier | Usage |
|---|---|---|
| Horizontale (principale) | `doneko-horizontal-color.svg` | en-tête du README, pages, documents |
| Horizontale sur fond sombre | `doneko-horizontal-color-dark.svg` | README en mode sombre, fonds Nuit |
| Empilée | `doneko-stacked-color.svg` · `-dark.svg` | formats carrés, autocollants |
| Symbole | `doneko-symbol-color.svg` | avatar, icônes, partout où le nom est déjà écrit à côté |
| Symbole petite taille | `doneko-symbol-small.svg` | de 16 à 24 px : œil et coche plus grands, sans nez |
| Nom seul | `doneko-wordmark.svg` | rare : quand le chat est déjà présent ailleurs |
| Une couleur | `doneko-symbol.svg`, `doneko-horizontal.svg` (noir) · `exports/*/…-white.svg` (blanc) | gravure, tampon, fax, impression une couleur |

La version blanche du symbole (`doneko-symbol-reversed.svg`) a l'œil et la coche un peu plus ouverts : sur fond sombre,
le clair « bave » et refermerait les détails.

## 2. Zone de protection

Autour du logo, garder vide une marge égale à **la hauteur de l'œil ouvert** (environ un sixième de la hauteur du
symbole). Elle grandit avec le logo.

## 3. Tailles minimales

| Version | Écran | Impression |
|---|---|---|
| Horizontale | 120 px de large | 30 mm |
| Symbole | 24 px ; de 16 à 24 px, `doneko-symbol-small.svg` | 8 mm |

## 4. Couleurs

| Nom | Rôle | HEX | RVB | CMJN (approx.) | Pantone (à vérifier au nuancier) |
|---|---|---|---|---|---|
| Mandarine | la tête | `#FF8A3D` | 255 138 61 | 0 46 76 0 | proche 1575 C |
| Mandarine sombre | la tête sur fond sombre | `#FF9B57` | 255 155 87 | 0 39 66 0 | — |
| Encre | le nom sur fond clair | `#1F1B24` | 31 27 36 | 14 25 0 86 | proche Black 6 C |
| Crème | fond clair, le nom sur fond sombre | `#FBF7F0` | 251 247 240 | 0 2 4 2 | papier crème |
| Nuit | fond sombre | `#1C1A22` | 28 26 34 | 18 24 0 87 | — |

Ce sont les couleurs de l'app (`DESIGN.md`).

**Associations autorisées** :
- tête Mandarine et nom Encre, sur Crème ou blanc ;
- tête Mandarine sombre et nom Crème, sur Nuit ou noir ;
- tout en noir sur fond clair ;
- tout en blanc sur fond sombre ou sur Mandarine.

**Contrastes** :
- Encre sur Crème : 15,9:1.
- Crème sur Nuit : 16,1:1.
- Mandarine sombre sur Nuit : 8,3:1.
- Mandarine sur Crème : 2,2:1. Ce contraste suffit pour la grande tête pleine, mais **jamais pour du texte** : le nom
  reste en Encre sur fond clair.

## 5. Typographie

- Le nom du logo est dessiné : aucune police à installer ni à licencier.
- Texte d'accompagnement : SF Pro Rounded, comme l'app (police système Apple, à réserver aux supports Apple). Sur le
  web : `ui-rounded, "SF Pro Rounded", system-ui, sans-serif`. Hors Apple : Nunito (licence libre OFL), proche en
  esprit.

## 6. À éviter

- Ne pas étirer, écraser, pencher ni faire tourner le logo.
- Ne pas changer les couleurs hors de la palette, ni mettre le nom en Mandarine.
- Ne pas ajouter d'ombre, de contour, de dégradé ni d'effet.
- Ne pas déplacer ni redimensionner le chat par rapport au nom.
- Ne pas remplacer la coche par un autre œil, ni ajouter une bouche, des moustaches ou des rayures au symbole.
- Ne pas poser le logo sur un fond chargé sans fond uni derrière.
- Ne pas retaper « doneko » dans une police.

## 7. Fichiers

```
Artwork/Logo/
├── doneko-*.svg            masters vectoriels (couleur, noir, petite taille, inversé, barre de menu)
├── doneko-social.svg       aperçu du dépôt GitHub, 1280 × 640
├── exports/
│   ├── symbole/            noir, blanc, Mandarine, carré, icône d'app, favicon, icônes web (favicon.ico,
│   │                       apple-touch-icon, icon-192/512, manifeste, head-snippet.html)
│   ├── horizontal/         noir, blanc, Encre en PNG 1200 px
│   └── *.png               logos couleur clair et sombre, aperçu social en PNG
├── presentation/           planche de présentation (HTML) et ses diapositives en PNG
└── concepts/               les trois pistes de départ
```

## 8. Ce qui reste à décider

- **Barre de menu** : `doneko-menubar.svg` est le symbole petite taille en 18 pt, en image modèle (« Template »).
  L'app utilise encore les icônes au trait : la tête animée a cinq états (éveillée, clin d'œil, endormie, « z »,
  patte). Passer au style plein demande de redessiner ces cinq états, et de mettre `DESIGN.md` à jour.
- **Icône de l'app** : elle reste l'illustration du chat (`Artwork/AppIcon.png`). Le logo sert au README, au web et
  aux supports.
- **Marque déposée** : aucune recherche d'antériorité n'a été faite. À vérifier (base INPI/EUIPO, recherche d'image
  inversée) avant un usage commercial.
