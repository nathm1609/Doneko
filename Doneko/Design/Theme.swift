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
        /// Zone des tâches : le panneau (480) moins le champ, les marges et la barre basse.
        static let listMaxHeight: CGFloat = 380
        static let panelCornerRadius: CGFloat = 14
        /// Espace entre la barre de menu (ou le bord de l'écran) et le panneau.
        static let panelScreenGap: CGFloat = 4
        static let settingsWidth: CGFloat = 420
        static let panelPadding: CGFloat = 12
        static let rowHeight: CGFloat = 32
        static let rowSpacing: CGFloat = 2
        static let rowCornerRadius: CGFloat = 8
        static let pawPadDiameter: CGFloat = 16
        static let pawPadStroke: CGFloat = 1.5
        /// Empreinte au survol et coche blanche, à l'intérieur du rond.
        static let pawPadGlyphSize: CGFloat = 8
        static let rowHorizontalPadding: CGFloat = 8
        static let rowContentSpacing: CGFloat = 8
        static let smallSpacing: CGFloat = 4
        static let focusRingWidth: CGFloat = 2
        /// Illustration de la mascotte (endormie ou contente) quand la liste est vide.
        static let mascotSize: CGFloat = 96
        /// Patte qui pousse la tâche hors de la table (image Paw, 337 × 128) : elle entre par le bord gauche de la ligne,
        /// se pose sur le rond, puis pousse encore un peu pendant la chute.
        static let pawHeight: CGFloat = 20
        static let pawWidth: CGFloat = 53
        static let pawReach: CGFloat = 26
        static let pawPush: CGFloat = 10
        /// Point Sakura devant une tâche prioritaire (« ! » en fin de saisie).
        static let priorityDotSize: CGFloat = 6
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
        /// Compteur de la barre de menu (AppKit) : medium, arrondi, chiffres à chasse fixe.
        static let counterSize: CGFloat = 12
    }

    enum Sound {
        /// « Pop » feutré à la chute d'une tâche (réglage, désactivé par défaut).
        static let popVolume: Float = 0.3
    }

    /// Durées en secondes.
    enum Motion {
        static let checkFill = 0.12
        static let pawSlide = 0.15
        static let fall = 0.30
        static let fallRotation = Angle.degrees(8)
        static let fallDistance: CGFloat = 80
        /// Ressort doux de la chute et de la remontée des lignes.
        static let springBounce = 0.15
        static let closeGap = 0.25
        static let rowAppear = 0.20
        static let rowAppearOffset: CGFloat = 8
        /// Estompage de la ligne au seuil du glissement de suppression.
        static let swipeFade = 0.5
        static let reducedMotionFade = 0.15
        static let undoToastDuration = 5.0
        static let breathePeriod = 3.0
        static let breatheScale: CGFloat = 1.03
        /// Balancement de la tête au rythme de la respiration (d'un côté à l'autre), plus ample quand elle est contente.
        static let mascotSwayContent = Angle.degrees(3)
        static let mascotSwayAsleep = Angle.degrees(1.5)
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
        /// Images-clés de la mascotte (oreille, bâillement, joie) : fondu d'entrée et de sortie, puis durée affichée.
        static let mascotPoseFade = 0.12
        static let mascotEarTwitch = 0.4
        static let mascotYawn = 1.6
        static let mascotCheer = 0.9
        /// Pendant la sieste, intervalle entre deux petits mouvements.
        static let mascotNapEvery = 7.0...14.0
    }
}
