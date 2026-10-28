import SwiftUI

/// Rond « coussinet de patte » : contour Moustache, Mandarine + empreinte au survol, Matcha + coche une fois fait.
/// Plus grand sur l'iPhone (`diameter`), où il n'y a pas de survol.
struct PawPad: View {
    let isChecked: Bool
    var isHovered = false
    var diameter = Theme.Layout.pawPadDiameter

    var body: some View {
        ZStack {
            Circle()
                .fill(isChecked ? Theme.Palette.matcha : .clear)
            Circle()
                .strokeBorder(strokeColor, lineWidth: Theme.Layout.pawPadStroke)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: glyphSize, weight: .bold))
                    .foregroundStyle(Theme.Palette.checkmark)
            } else if isHovered {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: glyphSize))
                    .foregroundStyle(Theme.Palette.mandarine)
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }

    private var glyphSize: CGFloat { diameter * Theme.Layout.pawPadGlyphRatio }

    private var strokeColor: Color {
        if isChecked { return Theme.Palette.matcha }
        return isHovered ? Theme.Palette.mandarine : Theme.Palette.moustache
    }
}
