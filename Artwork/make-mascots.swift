// Détoure les mascottes (illustrations générées avec Gemini sur fond magenta uni) et les range dans l'Asset Catalog.
// Usage, depuis la racine du projet : swift Artwork/make-mascots.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let names = ["MascotAsleep", "MascotContent"]
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
        let alpha = max(0, min(1, (0.8 - magenta) / 0.65))
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

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
var bitmaps = names.map { load(root.appendingPathComponent("Artwork/\($0).webp")) }
for i in bitmaps.indices { removeMagenta(&bitmaps[i]) }

// Même cadre carré pour toutes : passer d'une mascotte à l'autre ne fait pas sauter le chat.
let union = bitmaps.map(visibleBounds).reduce(CGRect.null) { $0.union($1) }
let side = max(union.width, union.height) * 1.04
let crop = CGRect(x: union.midX - side / 2, y: union.midY - side / 2, width: side, height: side).integral

for (name, bitmap) in zip(names, bitmaps) {
    let context = CGContext(data: nil, width: outputSize, height: outputSize, bitsPerComponent: 8, bytesPerRow: 0,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    let scale = CGFloat(outputSize) / crop.width
    // CGContext a son origine en bas à gauche : on place l'image entière pour que `crop` remplisse la sortie.
    context.draw(makeImage(bitmap), in: CGRect(x: -crop.minX * scale, y: -(CGFloat(bitmap.height) - crop.maxY) * scale,
                                               width: CGFloat(bitmap.width) * scale, height: CGFloat(bitmap.height) * scale))

    let folder = root.appendingPathComponent("Doneko/Resources/Assets.xcassets/\(name).imageset")
    try? FileManager.default.removeItem(at: folder)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
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
    print("\(name) : \(outputSize) × \(outputSize), cadre \(crop)")
}
