// Détoure les mascottes (illustrations générées avec Gemini sur fond magenta uni) et les range dans l'Asset Catalog.
// Aussi l'image-clé du saut de joie. La sieste et la patte du coup de patte sont des vidéos : make-animations.swift.
// Usage, depuis la racine du projet : swift Artwork/make-mascots.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Mascottes et image-clé de la joie (retouche Gemini de la mascotte contente, en .png). La mascotte endormie reste
/// l'image fixe montrée quand on réduit les animations, et la référence sur laquelle les autres sont recalées.
let sources = [
    ("MascotAsleep", "webp"), ("MascotContent", "webp"), ("MascotCheer", "png"),
]
let names = sources.map(\.0)
let outputSize = 512
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

/// Pixels RGBA prémultipliés.
struct Bitmap {
    let width: Int
    let height: Int
    var pixels: [UInt8]
}

func load(_ url: URL) -> Bitmap {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Image illisible : \(url.path)") }
    let (width, height) = (image.width, image.height)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return Bitmap(width: width, height: height, pixels: pixels)
}

/// Fond magenta → transparent. L'opacité vient de la part de magenta du pixel (min(R, B) − V), et cette part est retirée
/// de sa couleur : les bords lissés ne laissent pas de liseré rose sur le fond crème ou sombre du panneau.
func removeMagenta(_ bitmap: inout Bitmap) {
    let key = (Double(bitmap.pixels[0]), Double(bitmap.pixels[1]), Double(bitmap.pixels[2])) // coin = fond
    for i in stride(from: 0, to: bitmap.pixels.count, by: 4) {
        let (r, g, b) = (Double(bitmap.pixels[i]), Double(bitmap.pixels[i + 1]), Double(bitmap.pixels[i + 2]))
        let magenta = (min(r, b) - g) / 255
        // Le fond n'est pas tout à fait uni (léger dégradé en bas, part de magenta mesurée ≥ 0,8) : transparent dès 0,8.
        // Sous 15 % d'opacité, c'est un reste de fond plus sombre par endroits (bords de certaines images) : transparent.
        let opacity = max(0, min(1, (0.8 - magenta) / 0.65))
        let alpha = opacity < 0.15 ? 0 : opacity
        func unmix(_ value: Double, _ background: Double) -> UInt8 {
            UInt8(max(0, min(alpha * 255, value - (1 - alpha) * background)).rounded())
        }
        bitmap.pixels[i] = unmix(r, key.0)
        bitmap.pixels[i + 1] = unmix(g, key.1)
        bitmap.pixels[i + 2] = unmix(b, key.2)
        bitmap.pixels[i + 3] = UInt8((alpha * 255).rounded())
    }
}

/// Rectangle (origine en haut à gauche) des pixels visibles.
func visibleBounds(_ bitmap: Bitmap) -> CGRect {
    var (minX, minY, maxX, maxY) = (bitmap.width, bitmap.height, 0, 0)
    for y in 0..<bitmap.height {
        for x in 0..<bitmap.width where bitmap.pixels[(y * bitmap.width + x) * 4 + 3] > 25 {
            (minX, minY, maxX, maxY) = (min(minX, x), min(minY, y), max(maxX, x), max(maxY, y))
        }
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func makeImage(_ bitmap: Bitmap) -> CGImage {
    var pixels = bitmap.pixels
    return pixels.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: bitmap.width, height: bitmap.height, bitsPerComponent: 8, bytesPerRow: bitmap.width * 4,
                  space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }
}

func isOpaque(_ bitmap: Bitmap, _ x: Int, _ y: Int) -> Bool { bitmap.pixels[(y * bitmap.width + x) * 4 + 3] > 128 }

/// Repères de la tête qui ne bougent ni avec les oreilles ni avec la bouche : largeur aux joues (plus longue suite de
/// pixels opaques qui traverse la colonne du milieu, sous le front) et bas du collier dans cette colonne.
func headMarks(_ bitmap: Bitmap) -> (width: Double, centerX: Double, bottom: Double) {
    let mid = bitmap.width / 2
    let column = (0..<bitmap.height).filter { isOpaque(bitmap, mid, $0) }
    guard let top = column.first, let bottom = column.last else { fatalError("Tête introuvable") }
    var best = (width: 0, centerX: Double(mid))
    for y in (top + (bottom - top) * 45 / 100)...bottom where isOpaque(bitmap, mid, y) {
        var (left, right) = (mid, mid)
        while left > 0, isOpaque(bitmap, left - 1, y) { left -= 1 }
        while right < bitmap.width - 1, isOpaque(bitmap, right + 1, y) { right += 1 }
        if right - left + 1 > best.width { best = (right - left + 1, Double(left + right) / 2) }
    }
    return (Double(best.width), best.centerX, Double(bottom))
}

/// Redessine `bitmap` dans le cadre de `reference`, tête à la même taille et au même endroit.
func align(_ bitmap: Bitmap, to reference: Bitmap) -> Bitmap {
    let (target, marks) = (headMarks(reference), headMarks(bitmap))
    let scale = target.width / marks.width
    let (width, height) = (Double(bitmap.width) * scale, Double(bitmap.height) * scale)
    let top = target.bottom - marks.bottom * scale // origine en haut à gauche
    var pixels = [UInt8](repeating: 0, count: reference.width * reference.height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: reference.width, height: reference.height, bitsPerComponent: 8,
                                bytesPerRow: reference.width * 4, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(makeImage(bitmap), in: CGRect(x: target.centerX - marks.centerX * scale,
                                                   y: Double(reference.height) - top - height, width: width, height: height))
    }
    return Bitmap(width: reference.width, height: reference.height, pixels: pixels)
}

func writeImageset(_ name: String, _ image: CGImage) {
    let folder = root.appendingPathComponent("Shared/Resources/Shared.xcassets/\(name).imageset")
    try? FileManager.default.removeItem(at: folder)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Écriture impossible : \(name).png") }
    try! """
    {
      "images" : [
        {
          "filename" : "\(name).png",
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("\(name) : \(image.width) × \(image.height)")
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let detoured = sources.map { name, ext in
    var bitmap = load(root.appendingPathComponent("Artwork/\(name).\(ext)"))
    removeMagenta(&bitmap)
    return bitmap
}
// Gemini redessine les retouches un peu plus grandes ou plus petites : toutes recalées sur la mascotte endormie.
let bitmaps = detoured.indices.map { $0 == 0 ? detoured[0] : align(detoured[$0], to: detoured[0]) }

// Même cadre carré pour toutes : passer d'une image à l'autre ne fait pas sauter le chat.
let union = bitmaps.map(visibleBounds).reduce(CGRect.null) { $0.union($1) }
let side = max(union.width, union.height) * 1.04
let crop = CGRect(x: union.midX - side / 2, y: union.midY - side / 2, width: side, height: side).integral
print("Cadre commun : \(crop)")

for (name, bitmap) in zip(names, bitmaps) {
    let context = CGContext(data: nil, width: outputSize, height: outputSize, bitsPerComponent: 8, bytesPerRow: 0,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    let scale = CGFloat(outputSize) / crop.width
    // CGContext a son origine en bas à gauche : on place l'image entière pour que `crop` remplisse la sortie.
    context.draw(makeImage(bitmap), in: CGRect(x: -crop.minX * scale, y: -(CGFloat(bitmap.height) - crop.maxY) * scale,
                                               width: CGFloat(bitmap.width) * scale, height: CGFloat(bitmap.height) * scale))
    writeImageset(name, context.makeImage()!)
}
