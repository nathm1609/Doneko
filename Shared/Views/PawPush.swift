import SwiftUI

/// Patte du coup de patte, image par image (vidéo Veo détourée par `Artwork/make-animations.swift`) : elle entre par le
/// bord gauche de la ligne, recule un peu, puis pousse la tâche hors de la table.
struct PawPush: View {
    /// Début du geste.
    let start: Date

    /// Images PawPush00… de l'Asset Catalog ; les premières (entrée et petit recul) précèdent la chute de la ligne.
    static let frameCount = 13
    static let entryFrames = 8
    /// La ligne tombe quand la patte commence à pousser.
    static var entryDuration: Double { Double(entryFrames) / Theme.Motion.pawFrameRate }

    var body: some View {
        TimelineView(.animation) { context in
            let frame = Int(context.date.timeIntervalSince(start) * Theme.Motion.pawFrameRate)
            Image(String(format: "PawPush%02d", min(max(frame, 0), Self.frameCount - 1)))
                .resizable()
        }
    }
}
