// Fond de la fenêtre du DMG (illustration générée avec Gemini) : recadrée en 660 × 440 pt, fond crème uni autour des dessins.
// Usage, depuis la racine du projet (appelé par make-dmg.sh) : swift Artwork/make-dmg-background.swift <dossier>
// Écrit background.png et background@2x.png dans le dossier.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let source = URL(fileURLWithPath: "Artwork/DMGBackground.webp")
guard let image = CGImageSourceCreateWithURL(source as CFURL, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) })
else { fatalError("Image illisible : \(source.path)") }
let (width, height) = (image.width, image.height)
var pixels = [UInt8](repeating: 0, count: width * height * 4)
pixels.withUnsafeMutableBytes { buffer in
    CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
              space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        .draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
}

// Dessins = pixels nettement plus sombres que le crème. Ombre comprise, avec une marge pour son fondu.
var (minX, minY, maxX, maxY) = (width, height, 0, 0)
for y in 0..<height {
    for x in 0..<width {
        let i = (y * width + x) * 4
        if Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2]) < 690 {
            (minX, minY, maxX, maxY) = (min(minX, x), min(minY, y), max(maxX, x), max(maxY, y))
        }
    }
}
let margin = 40
let drawing = (minX - margin)...(maxX + margin)
let drawingRows = (minY - margin)...(maxY + margin)

// Gemini laisse de légères bandes plus foncées : tout ce qui est hors des dessins prend le crème qui les entoure.
let sample = (y: minY - margin - 1, x: (minX + maxX) / 2)
let cream = Array(pixels[(sample.y * width + sample.x) * 4..<(sample.y * width + sample.x) * 4 + 4])
for y in 0..<height {
    for x in 0..<width where !(drawing.contains(x) && drawingRows.contains(y)) {
        let i = (y * width + x) * 4
        pixels.replaceSubrange(i..<i + 4, with: cream)
    }
}
let flat = pixels.withUnsafeMutableBytes { buffer in
    CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
              space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
}

// Bande 660 × 440 sur toute la largeur ; la piste de pattes tombe à y = 150 pt, la hauteur des icônes (voir make-dmg.sh).
// La fenêtre en montre environ 400 : le crème en plus en bas absorbe les écarts de hauteur de la barre de titre.
let crop = flat.cropping(to: CGRect(x: 0, y: 550, width: width, height: width * 440 / 660))!
for (name, scale) in [("background.png", 1), ("background@2x.png", 2)] {
    let context = CGContext(data: nil, width: 660 * scale, height: 440 * scale, bitsPerComponent: 8, bytesPerRow: 0,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(crop, in: CGRect(x: 0, y: 0, width: 660 * scale, height: 440 * scale))
    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    let dpi = 72 * scale
    CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("Écriture impossible : \(name)") }
}
