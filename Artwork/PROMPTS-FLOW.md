# Prompts Google Flow pour les assets de Doneko

Chaque prompt reprend la direction artistique de `DESIGN.md` et les contraintes des scripts qui transforment les
images (`make-mascots.swift`, `make-appicon.sh`, `make-dmg-background.swift`). Une image qui ne respecte pas ces
contraintes (fond pas uni, tête déplacée, dessin trop près du bord) casse le détourage ou le recalage.

## Mode d'emploi

1. Dans Flow, choisis **Image** et le modèle **Nano Banana Pro** (le plus fidèle aux images de référence).
2. Ajoute les images de référence indiquées pour chaque asset (bouton « + », ou glisser-déposer). Sans référence,
   le chat change de tête d'une génération à l'autre.
3. Colle le prompt (en anglais, car le modèle suit plus fidèlement les consignes de cadrage et de couleur en
   anglais), choisis le format indiqué et génère 4 variantes.
4. Garde la meilleure en pleine résolution, puis vérifie la liste « Avant de garder une image » plus bas.
5. Ordre conseillé : l'icône d'abord (elle fixe le chat), puis les mascottes de base, puis les images-clés tirées
   de ces mascottes, puis la patte et le fond du DMG.

## Bloc de style commun

Ajoute ce paragraphe à la fin de chaque prompt ci-dessous (il est déjà inclus dans les prompts complets).

```text
Style: soft, rounded, vector-like illustration with gentle volumetric shading, like a premium macOS app icon.
Original ginger tabby cat mascot, not based on any existing cartoon character: wide round head with full cheeks,
tall pointed ears with cream inner ears, three tabby stripes on the forehead, two stripes on each cheek, almond
eyes, a small cream patch on the muzzle, a small dark triangular nose, no visible mouth at rest, a matcha green
collar with a round tag bearing a white check mark. Palette: mandarin orange #FF8A3D fur with slightly darker
orange stripes, cream #FBF7F0, ink #1F1B24 for eyes and nose, matcha green #5DB27F collar.
No outline stroke, no text, no letters, no watermark.
```

---

## 1. Icône de l'app (Mac et iPhone)

- Remplace `Artwork/AppIcon.png`.
- Référence : `Artwork/AppIcon.png`.
- Format : carré 1:1, 2K.
- But : le même chat, plus net et plus lisible en petit (16 px dans le Finder). Le regard actuel est un peu boudeur ;
  on cherche « éveillé et malicieux ».

```text
Use the reference image as the character. Create a polished app icon illustration: the cat's head, front view,
centered on a flat cream #FBF7F0 background that fills the whole square (no rounded corners, no frame, no border:
the corners are cut later). The head with its ears fills about 62% of the image width; the collar and its round tag
are fully visible under the chin. Awake, friendly, slightly mischievous expression: big almond eyes with a small
white highlight, looking at the viewer. Perfectly symmetrical head, crisp edges, soft volumetric shading, a very soft
drop shadow under the head. It must stay readable at 16 x 16 pixels: bold simple shapes, strong silhouette, few
small details.
Style: soft, rounded, vector-like illustration with gentle volumetric shading, like a premium macOS app icon.
Original ginger tabby cat mascot, not based on any existing cartoon character: wide round head with full cheeks,
tall pointed ears with cream inner ears, three tabby stripes on the forehead, two stripes on each cheek, almond
eyes, a small cream patch on the muzzle, a small dark triangular nose, no visible mouth at rest, a matcha green
collar with a round tag bearing a white check mark. Palette: mandarin orange #FF8A3D fur with slightly darker
orange stripes, cream #FBF7F0, ink #1F1B24 for eyes and nose, matcha green #5DB27F collar.
No outline stroke, no text, no letters, no watermark.
```

---

## 2. Mascotte endormie (`MascotAsleep`)

- Remplace `Artwork/MascotAsleep.webp`. Elle sert aussi de base aux images-clés « oreille » et « bâillement ».
- Références : `Artwork/MascotAsleep.webp` et la nouvelle icône (étape 1).
- Format : carré 1:1, 2K.

```text
Use the first reference image for the exact framing and the second one for the character's face and colors.
Redraw the sleeping cat cleaner and more polished: perfectly symmetrical head, smoother shading, crisp edges.
The cat is asleep: eyes closed as soft downward arcs, relaxed face, a small hand-drawn grey-purple (#6D6874)
letter "z" floating near the ear on the viewer's right. Front view, head and collar only, centered, the head filling
about 55% of the image width, with a wide empty margin on every side.
Background: perfectly flat pure magenta #FF00FF, no gradient, no vignette, no shadow on the background, no glow,
nothing magenta or pink on the cat.
Style: soft, rounded, vector-like illustration with gentle volumetric shading, like a premium macOS app icon.
Original ginger tabby cat mascot, not based on any existing cartoon character: wide round head with full cheeks,
tall pointed ears with cream inner ears, three tabby stripes on the forehead, two stripes on each cheek, a small
cream patch on the muzzle, a small dark triangular nose, no visible mouth, a matcha green collar with a round tag
bearing a white check mark. Palette: mandarin orange #FF8A3D fur with slightly darker orange stripes, cream
#FBF7F0, ink #1F1B24 for eyes and nose, matcha green #5DB27F collar.
No outline stroke, no watermark, no text other than the small "z".
```

## 3. Mascotte contente (`MascotContent`)

- Remplace `Artwork/MascotContent.webp`. Elle sert de base à l'image-clé « joie ».
- Références : la nouvelle `MascotAsleep` (étape 2), pour un cadrage identique, et la nouvelle icône.
- Format : carré 1:1, 2K.

```text
Edit the first reference image. Keep exactly the same head size, position, ears, stripes, collar, tag and magenta
background. Change only the expression: the cat is awake and content, eyes closed as happy upward arcs like "^ ^",
cheeks slightly lifted, satisfied. Remove the "z".
Background: perfectly flat pure magenta #FF00FF, no gradient, no vignette, no shadow on the background, nothing
magenta or pink on the cat. No text, no watermark.
```

## 4. Images-clés d'animation

Ce sont des retouches des mascottes des étapes 2 et 3 : le script les recale sur la mascotte endormie par la largeur
des joues et le bas du collier. Ces deux repères ne doivent donc pas bouger. Chaque prompt prend pour seule
référence l'image indiquée. Format : carré 1:1, 2K.

### `MascotAsleepEar` : oreille qui frémit

- Remplace `Artwork/MascotAsleepEar.png`.
- Référence : la nouvelle `MascotAsleep`.

```text
Edit this image. Keep everything identical: same head size and position, same cheeks, eyes, stripes, collar, tag,
"z" and flat magenta background. Change only one thing: the ear on the viewer's left is folded down and tilted
outward, as if it twitches in the cat's sleep. The other ear does not move. No text other than the "z", no watermark.
```

### `MascotYawn` : bâillement

- Remplace `Artwork/MascotYawn.png`.
- Référence : la nouvelle `MascotAsleep`.

```text
Edit this image. Keep the same head size and position, the same cheek width, the same collar and tag at exactly the
same height, and the same flat magenta background. Change only the face: the cat yawns, mouth wide open in a rounded
shape with a warm rosy-red interior (not magenta) and a tiny tongue, eyes squeezed shut, ears slightly pulled back.
Remove the "z". No text, no watermark.
```

### `MascotCheer` : saut de joie

- Remplace `Artwork/MascotCheer.png`.
- Référence : la nouvelle `MascotContent`.

```text
Edit this image. Keep the same head size and position, the same cheek width, the same collar and tag at exactly the
same height, and the same flat magenta background. Change only the face: the cat cheers with joy, mouth open in a
big happy smile with a warm rosy-red interior (not magenta), eyes closed as happy arcs, ears perked up high.
No text, no watermark.
```

---

## 5. Patte du coup de patte (`Paw`)

- Remplace `Artwork/Paw.png`. Elle s'affiche à 20 pt de haut sur Mac et 26 pt sur iPhone, et entre par le bord
  gauche de la ligne.
- Références : `Artwork/Paw.png` et la nouvelle icône (pour la couleur et les rayures).
- Format : paysage 16:9, 2K.
- But : une patte plus ronde et plus « chat », moins tube.

```text
Use the first reference image for the composition and the second for the fur color and stripes. Redraw the cat
paw cleaner and cuter: a ginger tabby forearm enters horizontally from the left edge of the image, cut cleanly by
the frame, and ends on the right with a round, plump cream paw seen from the side, its toes softly separated by two
small creases, slightly raised as if about to push something off a table. Two or three soft darker orange stripes on
the forearm. The arm stays within the vertical middle third of the image, with a lot of empty space above and below;
the tip of the paw stops at about 85% of the image width.
Background: perfectly flat pure magenta #FF00FF, no gradient, no vignette, no shadow on the background, nothing
magenta or pink on the paw (no pink toe beans).
Style: soft, rounded, vector-like illustration with gentle volumetric shading. Palette: mandarin orange #FF8A3D fur,
slightly darker orange stripes, cream #FBF7F0 paw. No outline stroke, no text, no watermark.
```

---

## 6. Fond de la fenêtre du DMG

- Remplace `Artwork/DMGBackground.webp`.
- Références : `Artwork/DMGBackground.webp` et la nouvelle icône.
- Format : carré 1:1, 2K.
- Contrainte : le script garde une bande horizontale entre 27 % et 94 % de la hauteur. Le Finder pose l'icône de
  Doneko à gauche et le dossier Applications à droite, à la hauteur de la piste d'empreintes.

```text
Use the first reference image for the composition and the second for the cat's face and colors. Redraw it cleaner
and calmer. Flat, uniform cream #FBF7F0 background everywhere, with no texture, no noise and no vignette.
At exactly the vertical center of the image: a horizontal trail of six small mandarin orange (#FF8A3D) cat paw
prints, alternating slightly up and down like walking steps, followed by a short rounded arrow pointing right. The
trail spans from about 32% to 68% of the image width; the left 30% and the right 30% of the image stay completely
empty (an app icon and a folder icon will be placed there).
Below the trail, between about 62% and 76% of the image height: the ginger tabby cat mascot lying stretched out on
its belly, facing right, one front paw reaching forward as if pushing something toward the right, with a very soft
ground shadow. The top quarter and the bottom tenth of the image stay completely empty. Minimal, airy, lots of
breathing room.
Style: soft, rounded, vector-like illustration with gentle volumetric shading. Original ginger tabby cat, not based
on any existing cartoon character: round head, tall pointed ears with cream inner ears, tabby stripes, almond eyes,
cream muzzle patch, matcha green #5DB27F collar with a round tag and a white check mark.
No outline stroke, no text, no letters, no watermark.
```

---

## En option

Ces trois assets n'existent pas encore dans l'app.

### Icône iPhone en mode sombre

iOS sait afficher une icône différente en mode sombre. Il faut ensuite ajouter la variante à l'`AppIcon` iOS.

- Référence : la nouvelle icône (étape 1). Format : carré 1:1, 2K.

```text
Edit this image. Keep the cat's head exactly the same: same size, position, colors, collar and tag. Replace only the
background with a flat, very dark plum #1C1A22 that fills the whole square, and remove the drop shadow. Fur colors
stay warm and saturated so they pop on the dark background. No rounded corners, no frame, no text, no watermark.
```

### Image d'aperçu du dépôt GitHub

Image d'aperçu affichée quand on partage le lien du dépôt (1280 × 640 px une fois recadrée).

- Référence : la nouvelle icône. Format : paysage 16:9, 2K.

```text
Wide banner illustration. On the right half: the ginger tabby cat mascot from the reference image sits on the edge of
a light wooden table and gently pushes a small paper sticky note off the edge with one front paw; the note is tipping
over the edge. The cat looks at the viewer with a mischievous expression. The left 55% of the image is plain cream
#FBF7F0, left empty for a title added later. Soft, rounded, vector-like illustration with gentle volumetric shading,
warm and calm. Palette: mandarin orange #FF8A3D, cream #FBF7F0, matcha green #5DB27F collar.
No text, no letters, no watermark.
```

### Petite vidéo du coup de patte (Veo)

Clip court pour le README ou la page de release, à faire dans Flow en mode vidéo, avec « Ingredients to Video ».

- Références : la nouvelle icône et la nouvelle `MascotContent`.
- Format : 16:9, 8 s ; Veo Fast pour les essais, qualité Standard pour la version finale.

```text
A soft 3D-animated ginger tabby cat, exactly like the reference images (round head, tall ears, tabby stripes, cream
muzzle, matcha green collar with a check mark tag), sits on a cream tabletop next to three small paper task cards.
It glances at the camera, then slowly and gently pushes the nearest card off the edge of the table with one paw; the
card tips over and falls out of frame. The cat closes its eyes in happy arcs, satisfied. Static camera, eye level,
warm soft studio light, cream background, slow and cute, no people.
Audio: a soft paper slide, a muffled pop, a short purr. No music, no text, no subtitles.
```

---

## Ce qui ne passe pas par Flow

- **Icônes de la barre de menu** (`MenuIcon*`) : des vecteurs SVG de 18 pt, monochromes, en mode « Template ». Une
  image générée serait floue à cette taille et ne s'adapterait pas aux barres claires et sombres. Elles se redessinent
  à la main (Figma, ou directement en SVG).
- **Captures et GIF du README** (`docs/images/`) : ce sont de vraies captures de l'app. Une image générée montrerait
  une interface qui n'existe pas. Elles se refont depuis l'app une fois les nouveaux assets en place.
- **Son « pop »** (`Pop.wav`) : Flow ne génère pas de son seul. Il vient de `Artwork/make-pop.py`.

## Avant de garder une image

- Le chat est le même que sur l'icône : rayures, collier vert avec la coche, nez en triangle, tache crème.
- Fond magenta (mascottes, patte) : uni d'un bord à l'autre, sans dégradé ni ombre portée, et rien de rose ou de
  magenta sur le chat. Sinon le détourage troue le dessin.
- Le dessin ne touche aucun bord, sauf l'avant-bras de la patte, coupé net à gauche.
- Images-clés : posées sur la mascotte de base, la tête et le collier ne bougent pas.
- Aucun texte ni filigrane visible (sauf le « z » de la mascotte endormie).

Dépose les images retenues dans `Artwork/` en gardant les noms ci-dessus (l'extension importe peu) : il reste à
relancer le détourage, les tailles d'icône et le fond du DMG, puis à vérifier le rendu dans l'app.
