import SwiftUI

/// Valeurs visuelles issues de DESIGN.md. Les vues n'en utilisent aucune autre.
enum Theme {
    /// Couleurs nommées de l'Asset Catalog, avec variantes clair / sombre.
    enum Palette {
        static let mandarine = Color("Mandarine")
        static let creme = Color("Creme")
        static let coussin = Color("Coussin")
        static let encre = Color("Encre")
        static let moustache = Color("Moustache")
        static let matcha = Color("Matcha")
        static let sakura = Color("Sakura")
        static let checkmark = Color.white
    }

    enum Layout {
        static let panelWidth: CGFloat = 320
        static let panelMaxHeight: CGFloat = 480
        /// Zone des tâches : le panneau (480) moins le champ, la barre de dossiers, les marges et la barre basse.
        static let listMaxHeight: CGFloat = 344
        /// Barre de dossiers : pastilles arrondies (« Tout », un dossier, « + »), et largeur du champ de nom.
        static let folderChipHeight: CGFloat = 24
        static let folderChipPadding: CGFloat = 10
        static let folderNameWidth: CGFloat = 96
        static let panelCornerRadius: CGFloat = 14
        /// Panneau Mac : matière des panneaux de la barre de menu, teintée de Crème, et filet de bord à peine visible.
        static let panelTintOpacity = 0.82
        static let panelEdgeOpacity = 0.08
        static let panelEdgeWidth: CGFloat = 0.5
        /// Espace entre la barre de menu (ou le bord de l'écran) et le panneau.
        static let panelScreenGap: CGFloat = 4
        static let settingsWidth: CGFloat = 420
        static let panelPadding: CGFloat = 12
        static let rowHeight: CGFloat = 32
        /// iPhone : zone de toucher minimale d'un élément (recommandation Apple).
        static let touchTarget: CGFloat = 44
        /// iPhone : rond plus grand, centré dans sa zone de toucher, et patte à sa mesure (mêmes images, 424 × 160).
        static let touchPawPadDiameter: CGFloat = 22
        static let touchPawHeight: CGFloat = 26
        static let touchPawWidth: CGFloat = 69
        static let touchPawReach: CGFloat = 36
        /// iPhone : pastilles de la barre de dossiers.
        static let touchChipHeight: CGFloat = 32
        static let touchChipPadding: CGFloat = 12
        /// iPhone : champ de saisie en capsule, texte écarté de l'arrondi.
        static let touchFieldPadding: CGFloat = 16
        /// iPhone : air au-dessus d'un titre de section (« Plus tard », « Tombé aujourd'hui »).
        static let touchSectionGap: CGFloat = 12
        /// iPhone : les tâches s'effacent sur cette hauteur en passant sous la barre du bas.
        static let scrollEdgeFade: CGFloat = 16
        static let rowSpacing: CGFloat = 2
        static let rowCornerRadius: CGFloat = 8
        static let pawPadDiameter: CGFloat = 16
        static let pawPadStroke: CGFloat = 1.5
        /// Empreinte au survol et coche blanche, à l'intérieur du rond : la moitié de son diamètre.
        static let pawPadGlyphRatio: CGFloat = 0.5
        static let rowHorizontalPadding: CGFloat = 8
        static let rowContentSpacing: CGFloat = 8
        static let smallSpacing: CGFloat = 4
        static let focusRingWidth: CGFloat = 1
        /// Toast d'annulation : capsule qui flotte au-dessus de la liste.
        static let toastShadowOpacity = 0.15
        static let toastShadowRadius: CGFloat = 8
        static let toastShadowY: CGFloat = 2
        /// Illustration de la mascotte (endormie ou contente) quand la liste est vide.
        static let mascotSize: CGFloat = 96
        /// Patte qui pousse la tâche hors de la table (images PawPush, 424 × 160) : elle entre par le bord gauche de la
        /// ligne et son bout se pose sur le rond, à `pawReach` du bord, puis pousse pendant la chute.
        static let pawHeight: CGFloat = 20
        static let pawWidth: CGFloat = 53
        static let pawReach: CGFloat = 26
        /// Bout de la patte posée, en part de la largeur des images (donné par Artwork/make-animations.swift).
        static let pawRestTip: CGFloat = 0.639
        /// Point Sakura devant une tâche prioritaire (« ! » en fin de saisie).
        static let priorityDotSize: CGFloat = 6
        /// iPhone : feuille « Pour quand ? », juste assez haute pour le calendrier.
        static let datePickerSheetHeight: CGFloat = 470
        /// Chevron de « Tombé aujourd'hui » une fois la section dépliée.
        static let disclosureRotation = Angle.degrees(90)
        /// Glissement à deux doigts vers la gauche au-delà duquel la tâche est supprimée.
        static let swipeDeleteThreshold: CGFloat = 80
    }

    /// SF Pro Rounded partout.
    enum Typography {
        static let input = Font.system(size: 14, design: .rounded)
        static let task = Font.system(size: 13, design: .rounded)
        static let sectionTitle = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let sectionTitleTracking: CGFloat = 0.5
        static let caption = Font.system(size: 12, design: .rounded)
        /// iPhone : tailles qui suivent Dynamic Type.
        static let touchBody = Font.system(.body, design: .rounded)
        static let touchCaption = Font.system(.footnote, design: .rounded)
        /// iPhone : titres de section en minuscules, sous le grand titre « Aujourd'hui » de la barre de navigation.
        static let touchSectionTitle = Font.system(.title3, design: .rounded, weight: .semibold)
        static let touchChip = Font.system(.subheadline, design: .rounded)
        /// Compteur de la barre de menu (AppKit) : medium, arrondi, chiffres à chasse fixe.
        static let counterSize: CGFloat = 12
        #if os(iOS)
        /// iPhone : titres de la barre de navigation (UIKit), gras et arrondis comme le reste. Taille prise au lancement.
        static func navigationTitle(_ style: UIFont.TextStyle) -> UIFont {
            let descriptor = UIFont.preferredFont(forTextStyle: style).fontDescriptor
            let bold = descriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.bold]])
            return UIFont(descriptor: bold.withDesign(.rounded) ?? bold, size: 0)
        }
        #endif
    }

    enum Sound {
        /// « Pop » feutré à la chute d'une tâche (réglage, désactivé par défaut).
        static let popVolume: Float = 0.3
    }

    /// Durées en secondes.
    enum Motion {
        static let checkFill = 0.12
        /// Images de la patte par seconde : l'entrée et le petit recul durent 0,27 s, la poussée accompagne la chute.
        static let pawFrameRate = 30.0
        static let fall = 0.30
        static let fallRotation = Angle.degrees(8)
        static let fallDistance: CGFloat = 80
        /// Ressort de la chute : la tâche poussée a de l'élan, elle peut dépasser un peu.
        static let springBounce = 0.15
        /// Ressort amorti, sans rebond, pour tout ce qui se range sans élan : lignes qui remontent, ajout, toast.
        static let settleBounce = 0.0
        /// Réponse dès l'appui sur un bouton : il se resserre un peu (ou pâlit, si on réduit les animations).
        static let press = 0.1
        static let pressScale: CGFloat = 0.94
        static let pressedOpacity = 0.6
        static let closeGap = 0.25
        static let rowAppear = 0.20
        static let rowAppearOffset: CGFloat = 8
        /// Estompage de la ligne au seuil du glissement de suppression.
        static let swipeFade = 0.5
        static let reducedMotionFade = 0.15
        static let undoToastDuration = 5.0
        /// Mascotte contente : balancement de la tête d'un côté à l'autre, au rythme d'une respiration lente.
        /// (Endormie, elle respire dans sa vidéo, MascotNap.)
        static let breathePeriod = 3.0
        static let mascotSwayContent = Angle.degrees(3)
        /// Tête de chat de la barre de menu : petit saut quand une tâche arrive, coup de tête quand une tâche part.
        static let iconReaction = 0.4
        static let iconHopLift: CGFloat = 2
        static let iconSwatAngle: CGFloat = 14
        /// Vide autour de la petite patte du coup de tête, pour la détacher du trait de la tête.
        static let iconPawGap: CGFloat = 1
        /// Au repos, de temps en temps : clignement des yeux (éveillée) ou « z » qui monte en s'effaçant (endormie).
        static let iconIdleDelay = 6.0...14.0
        static let iconBlink = 0.15
        static let iconSnore = 1.4
        static let iconZLift: CGFloat = 2
        /// Mascotte du panneau vide : saut de joie (tout est fait, clic) et tortillement dans son sommeil (clic).
        static let mascotHopRise = 0.16
        static let mascotHopHeight: CGFloat = 12
        static let mascotLanding = 0.45
        static let mascotWiggleAngle = Angle.degrees(6)
        static let mascotBounce = 0.6
        /// Image-clé de la joie, le temps du saut : fondu d'entrée et de sortie, puis durée affichée.
        static let mascotPoseFade = 0.12
        static let mascotCheer = 0.9
    }
}
