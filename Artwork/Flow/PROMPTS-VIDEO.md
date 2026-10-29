# Prompts Google Flow pour animer Doneko (vidéo)

Le but est de remplacer les animations actuelles de la mascotte et de la patte (images-clés en fondu de 120 ms,
échelle et rotation faites en code) par de courtes vidéos fluides. Le style visé est celui des personnages d'apps
d'apprentissage ludiques : souple, rebondi, expressif.

Les images à charger dans Flow sont dans [`images/`](images). Elles sont en 1920 × 1080 (16:9), sur fond uni,
toutes tirées des sources haute définition d'`Artwork/` :

- **Fond uni :** Veo, le modèle vidéo de Flow, ne sort que du 16:9 ou du 9:16, et jamais de transparence. Les
  mascottes et la patte sont donc sur magenta pur (`#FF00FF`), comme les sources, pour être détourées ensuite.
  L'icône et le fond du DMG gardent leur crème.
- **Mascottes alignées :** les cinq poses sont recalées entre elles (largeur aux joues, bas du collier), comme dans
  `make-mascots.swift`. La tête est exactement au même endroit sur chaque image, donc la fin d'un clip raccorde avec
  le début du suivant.
- **De la place au-dessus :** les mascottes sont un peu sous le centre, pour laisser la place du saut de joie.

## Les assets utilisés par l'app

| Asset | Où dans le code | Image pour Flow | S'anime avec Flow ? |
|---|---|---|---|
| `MascotAsleep` (endormie, « z ») | `Shared/Views/EmptyState.swift` (panneau vide, Mac et iPhone) | `mascot-asleep.png` | oui |
| `MascotAsleepEar` (oreille repliée) | `EmptyState.swift` | `mascot-asleep-ear.png` | oui (image de fin) |
| `MascotYawn` (bâillement) | `EmptyState.swift` | `mascot-yawn.png` | oui (image de fin) |
| `MascotContent` (contente) | `EmptyState.swift` | `mascot-content.png` | oui |
| `MascotCheer` (joie) | `EmptyState.swift` | `mascot-cheer.png` | oui (image de fin) |
| `Paw` (coup de patte) | `Doneko/Views/TodoRow.swift`, `DonekoiOS/Views/TodoRow.swift` | `paw.png` + `empty-magenta.png` | oui |
| `AppIcon` (Mac et iPhone) | Asset Catalogs | `app-icon.png` | pour le README seulement |
| Fond du DMG | `make-dmg.sh` | `dmg-background.png` | pour le README seulement |
| `MenuIconAwake`, `Blink`, `AsleepHead`, `Z`, `Paw` | `Doneko/Services/MenuBarController.swift` | — | non |
| `Pop.wav` | `DonekoiOS/Views/TodoRow.swift` | — | non |

Ce qui ne passe pas par Flow :

- **Icônes de la barre de menu :** des vecteurs de 18 pt en mode « Template » (monochromes, adaptés à la barre
  claire ou sombre). Une vidéo n'y a pas sa place, et leur animation (saut, coup de tête, clin d'œil, « z ») est
  déjà faite en code.
- **Son « pop » :** Flow ne génère pas de son seul.
- **Captures et GIF du README :** ce sont de vraies captures de l'app. Elles se refont depuis l'app une fois les
  vidéos intégrées.
- **Icône de l'app et fond du DMG :** le Finder, le Dock et macOS n'affichent jamais de vidéo à leur place. Leurs
  clips (en bonus, à la fin) ne servent qu'au README et à la promo.

## Mode d'emploi

1. Dans Flow, choisis **Vidéo**, puis le mode **Frames to Video** (première et dernière image).
2. Charge l'**image de début** et, quand elle est indiquée, l'**image de fin**. Une boucle utilise la même image au
   début et à la fin : c'est ce qui la rend sans couture.
3. Modèle **Veo 3.1**, format **16:9** :
   - **Fast** pour les essais ;
   - **Quality** pour la version retenue.
4. Colle le prompt tel quel (en anglais : Veo suit plus fidèlement les consignes de mouvement et de cadrage dans
   cette langue). Génère 2 à 4 variantes.
5. Veo fait des clips de quelques secondes, plus longs que les animations de l'app. Les prompts demandent donc un
   geste vif, encadré de moments immobiles : on garde la partie utile, et on accélère au besoin au montage. La durée
   visée dans l'app est indiquée pour chaque clip.
6. Garde la variante où le fond reste magenta uni du début à la fin, où le chat ne change ni de taille ni de place,
   et où son dessin ne se déforme pas.

Le style est décrit sans citer d'app ni de marque : un nom de marque ferait dériver Veo vers son personnage.

Chaque prompt se termine par le même bloc de style et de contraintes, à garder.

```text
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

---

## 1. Sieste en boucle

- **Images :** début `mascot-asleep.png`, fin `mascot-asleep.png` (boucle).
- **Dans l'app :** panneau vide, liste vide. Respiration de 3 s, en boucle. Elle remplace l'échelle 1 → 1,03 et le
  balancement de ±1,5° faits en code.

```text
The sleeping ginger cat breathes slowly and peacefully: on each slow breath its head gently swells by about 3% and
relaxes back, and the whole head sways very slightly from side to side (about 1.5 degrees each way), in one calm
rhythm. The small "z" near its ear drifts up a little while fading, then softly reappears at its original place.
Eyes stay closed the whole time. The motion is slow and continuous, and the last frame matches the first frame
exactly, so the clip loops seamlessly.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

## 2. Oreille qui frémit (deux clips)

- **Dans l'app :** pendant la sieste, toutes les 7 à 14 s. Geste de 0,4 s.
- **Pourquoi deux clips :** un aller vers l'image « oreille repliée », puis un retour. La pose du milieu est
  exactement la mascotte existante, et les deux clips raccordent sur elle.

**Aller** : début `mascot-asleep.png`, fin `mascot-asleep-ear.png`.

```text
The sleeping cat stays asleep while one ear (the one on the viewer's right) gives a quick twitch: it flicks and folds
down outward in one snappy motion, with a tiny wobble, and ends folded as in the last frame. Nothing else moves
except a very slight head reaction to the twitch. Hold still for a moment at the start and at the end.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

**Retour** : début `mascot-asleep-ear.png`, fin `mascot-asleep.png`.

```text
The folded ear of the sleeping cat springs back up to its normal upright position in one quick, elastic motion,
overshoots slightly, wobbles once and settles. The cat stays asleep, eyes closed. Hold still for a moment at the
start and at the end.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

## 3. Bâillement (deux clips)

- **Dans l'app :** pendant la sieste, une fois sur trois au lieu de l'oreille. 1,6 s au total.

**Aller** : début `mascot-asleep.png`, fin `mascot-yawn.png`.

```text
The sleeping cat starts a big, slow yawn: first a tiny anticipation where the head dips and squashes slightly, then
the head stretches upward a little as the mouth opens wide into a big rounded yawn, the eyes squeeze shut and the
ears pull back. The small "z" fades away. The clip ends on the wide-open yawn of the last frame.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

**Retour** : début `mascot-yawn.png`, fin `mascot-asleep.png`.

```text
The yawning cat closes its mouth, smacks its lips once, and its head squashes down softly and settles back into a
peaceful sleep: relaxed closed eyes, ears back upright, a tiny contented head wobble. The small "z" softly fades back
in near its ear. Hold still for a moment at the end.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

## 4. Tortillement au clic

- **Images :** début `mascot-asleep.png`, fin `mascot-asleep.png`.
- **Dans l'app :** un clic (ou un toucher) sur la mascotte endormie. Environ 0,8 s, puis elle se rendort.

```text
Poked in its sleep, the cat squirms without waking up: its head quickly squashes down, wiggles left and right twice
(about 4 degrees each way) with both ears flicking, then stretches back up, overshoots slightly and settles into the
exact sleeping pose of the start. Eyes stay closed the whole time. Quick and cute, then hold still.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

## 5. Contente en boucle

- **Images :** début `mascot-content.png`, fin `mascot-content.png` (boucle).
- **Dans l'app :** panneau vide quand toutes les tâches du jour sont faites (« Table rase ! »). Boucle de 3 s. Elle
  remplace la respiration et le balancement de ±3° faits en code.

```text
The happy cat sways its head gently from side to side (about 3 degrees each way) with a soft, satisfied bounce,
breathing slowly, its eyes staying in happy closed arcs. The small sparkles around it twinkle in place, softly
growing and shrinking one after another. The last frame matches the first frame exactly, so the clip loops
seamlessly.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

## 6. Saut de joie (deux clips)

- **Dans l'app :** quand le panneau vide content apparaît, et à chaque clic sur la mascotte. Environ 0,6 s.
- **Le saut :** il est le seul mouvement qui déplace la tête, de 12 pt dans l'app. Dans ces images, la place
  au-dessus de la tête est prévue pour lui.

**Aller** : début `mascot-content.png`, fin `mascot-cheer.png`.

```text
The happy cat jumps for joy: a quick anticipation where its head squashes down and gets wider, then it springs
straight up (about 15% of the frame height) while stretching taller, its mouth opening into a big joyful smile in
mid-air, ears perked up high and the sparkles bursting brighter. It falls back to exactly its starting spot, lands
with a squash and a small rebound, and settles on the cheering pose of the last frame. Fast, springy, delightful.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design and colors, and comes back to the same place in the frame; only the motion described
moves, and it never leaves the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush
stays as is). No text, no new objects, no other characters. Silent: no music, no sound effects.
```

**Retour** : début `mascot-cheer.png`, fin `mascot-content.png`.

```text
The cheering cat calms down: its open smile closes into a small satisfied smile, the head does one soft little
bounce and settles, eyes in happy closed arcs, sparkles back to their gentle size. Hold still for a moment at the
end.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat (its existing soft cheek blush stays as is). No text, no
new objects, no other characters. Silent: no music, no sound effects.
```

## 7. Contente → endormie

- **Images :** début `mascot-content.png`, fin `mascot-asleep.png`.
- **Dans l'app :** quand la mascotte contente laisse place à la mascotte endormie (« Tombé aujourd'hui » vidé, plus
  rien sur la table). Environ 1,5 s, calme.

```text
The happy cat slowly gets sleepy: the sparkles gently fade away, its happy eye arcs relax into soft sleepy closed
eyes, the cheek blush fades, its head droops a little with a small tired sway and a quiet sigh, then settles into a
peaceful sleep as a small "z" fades in near its ear. Slow, soft and cozy.
Style: smooth, bouncy 2D cartoon character animation in the exact flat-vector look of the input frames, same soft
shading, same proportions. Snappy, playful timing with clear animation principles: a small anticipation, squash and
stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. The cat keeps
exactly the same size, design, colors and place in the frame; only the motion described moves, and it never leaves
the frame. Nothing new that is pink or magenta on the cat. No text, no new objects, no other characters. Silent: no
music, no sound effects.
```

## 8. Coup de patte (deux clips)

- **Dans l'app :** la patte entre par le bord gauche de la ligne et pousse le rond « coussinet », puis la ligne
  tombe. Environ 0,45 s au total : 150 ms d'entrée, 300 ms de poussée.
- **Images :** `empty-magenta.png` est l'image vide, sans patte. `paw.png` est la patte entrée.

**Entrée et poussée** : début `empty-magenta.png`, fin `paw.png`.

```text
A ginger tabby cat paw, exactly like the paw in the last frame, darts in from the left edge of the frame: a quick
slide in, a tiny pull back (anticipation), then a playful push forward to the right, the round cream paw squashing
slightly on impact as if shoving something off a table. It ends in the exact position of the last frame. Very
snappy.
Style: smooth, bouncy 2D cartoon animation in the exact flat-vector look of the input frames, same soft shading,
same proportions and stripes. Snappy, playful timing with clear animation principles: a small anticipation, squash
and stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. Only the paw
and forearm move; nothing else appears. Nothing pink or magenta on the paw, no pink toe beans. No text, no other
objects. Silent: no music, no sound effects.
```

**Retrait** : début `paw.png`, fin `empty-magenta.png`.

```text
The ginger tabby cat paw gives one last little push to the right, then quickly pulls back and slides out of the frame
to the left, leaving the frame empty. Quick and smooth, with a slight overshoot as it leaves.
Style: smooth, bouncy 2D cartoon animation in the exact flat-vector look of the input frames, same soft shading,
same proportions and stripes. Snappy, playful timing with clear animation principles: a small anticipation, squash
and stretch on the main move, a slight overshoot, then a soft settle. Fluid, clean motion, no morphing of the design,
no motion smear artifacts.
Rules: locked-off static camera, no zoom, no pan, no camera shake. The background stays perfectly flat pure magenta
#FF00FF for the whole clip: no shadow, no gradient, no lighting change, no particles, no reflections. Only the paw
and forearm move; nothing else appears. Nothing pink or magenta on the paw, no pink toe beans. No text, no other
objects. Silent: no music, no sound effects.
```

---

## Bonus pour le README et la promo

Ces deux clips ne vont pas dans l'app : macOS n'affiche jamais de vidéo à la place d'une icône ou d'un fond de DMG.
Ils sont sur fond crème, il n'y a donc rien à détourer.

### L'icône qui fait un clin d'œil

- **Images :** début `app-icon.png`, fin `app-icon.png` (boucle).

```text
The ginger tabby cat head blinks playfully: it gives a quick, mischievous wink with the eye on the viewer's right,
tilts its head slightly with a little bounce, then opens the eye again and settles back exactly into the starting
pose. The green collar tag gives a tiny swing. The last frame matches the first frame, so the clip loops.
Style: smooth, bouncy 2D cartoon character animation in the exact soft vector look of the input frame, same shading
and colors. Snappy, playful timing: a small anticipation, squash and stretch, a slight overshoot, a soft settle.
Fluid, clean motion, no morphing of the design.
Rules: locked-off static camera, no zoom, no pan. The cream background and its soft shadow stay exactly the same
for the whole clip. The cat keeps the same size and place. No text, no new objects. Silent.
```

### Le chat du DMG qui pousse de la patte

- **Images :** début `dmg-background.png`, fin `dmg-background.png` (boucle).

```text
The ginger tabby cat lying on its belly swats its raised front paw forward twice, playfully, as if pushing something
toward the right, while its tail swishes gently. The orange paw prints above light up softly one after another from
left to right, and the arrow gives a small nudge to the right. Everything returns exactly to the starting pose, so
the clip loops.
Style: smooth, bouncy 2D cartoon animation in the exact soft vector look of the input frame, same shading and
colors. Snappy, playful timing with squash and stretch and a soft settle. Fluid, clean motion, no morphing.
Rules: locked-off static camera, no zoom, no pan. The flat cream background stays exactly the same. The cat, the paw
prints and the arrow keep their size and place. No text, no new objects. Silent.
```

---

## Après Flow

1. Télécharge chaque clip retenu en 1080p et range-le dans `Artwork/Flow/videos/`, nommé comme sa section
   (`sieste-boucle.mp4`, `oreille-aller.mp4`, `oreille-retour.mp4`, `saut-aller.mp4`…).
2. Ensuite vient une étape d'intégration à part, qui n'est pas encore faite :
   - **Détourage :** le magenta devient transparent, avec la même formule que `make-mascots.swift`.
   - **Montage :** couper à la partie utile et accélérer aux durées de l'app.
   - **Encodage :** HEVC avec transparence (`AVAssetWriter`, codec `hevcWithAlpha`). Il n'y a pas de ffmpeg sur ce
     Mac, AVFoundation suffit.
   - **Lecture :** dans `EmptyState.swift` et `TodoRow.swift`, en gardant l'image fixe et un simple fondu quand
     « Réduire les animations » est activé.
3. Si un jour tu veux un rendu encore plus proche de ces apps, avec un chat vectoriel qui réagit au doigt et des
   fichiers légers, ce serait Rive ou Lottie plutôt que de la vidéo. C'est un autre chantier.
