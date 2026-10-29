// Anime la mascotte endormie et la patte du coup de patte à partir de vidéos Veo (Google Flow) sur fond magenta :
// Artwork/Videos/MascotNap.mp4 et PawPush.mp4. Détourage (comme make-mascots.swift), nettoyage des poussières,
// puis la sieste en boucle sans couture, en HEVC avec transparence (Shared/Resources/MascotNap.mov), et la patte en
// images PNG dans l'Asset Catalog (PawPush00, PawPush01…), jouées au rythme de la chute de la ligne.
// Usage, depuis la racine du projet : swift -O Artwork/make-animations.swift
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

/// Sieste : carré autour du chat et de ses « z » sur toute la vidéo (pixels de la source 1920 × 1080), taille de sortie
/// (mascotte de 96 pt, @3x), et fondu de la fin vers le début pour une boucle sans saut.
let napCrop = CGRect(x: 482, y: 206, width: 760, height: 760)
let napSize = 320
let napCrossfade = 12

/// Patte : bande autour du bras sur le geste retenu, même rapport que la patte des lignes (53 × 20 pt), 160 px de haut.
/// Images retenues (source à 24 i/s), rejouées à 30 i/s : entrée par la gauche, petit recul, poussée.
let pawCrop = CGRect(x: 276, y: 280, width: 1484, height: 560)
let pawHeight = 160
let pawEntry = [48, 51, 54, 57, 60, 66]
let pawWindUp = [104, 112]
let pawPush = [120, 123, 126, 129, 132]

/// Pixels RGBA prémultipliés, de 0 à 255.
struct Frame {
    let width: Int, height: Int
    var pixels: [Double]
}

/// Appelle `handle` pour chaque image retenue de la vidéo, recadrée sur `crop` (origine en haut à gauche).
func readFrames(_ name: String, crop: CGRect, keep: (Int) -> Bool, _ handle: (Int, Frame) -> Void) {
    let asset = AVURLAsset(url: root.appendingPathComponent("Artwork/Videos/\(name).mp4"))
    let semaphore = DispatchSemaphore(value: 0)
    var track: AVAssetTrack?
    Task { track = try? await asset.loadTracks(withMediaType: .video).first; semaphore.signal() }
    semaphore.wait()
    let reader = try! AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track!, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(output)
    reader.startReading()
    var index = 0
    while let sample = output.copyNextSampleBuffer() {
        defer { index += 1 }
        guard keep(index), let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        let row = CVPixelBufferGetBytesPerRow(buffer)
        let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let (x0, y0, width, height) = (Int(crop.minX), Int(crop.minY), Int(crop.width), Int(crop.height))
        var pixels = [Double](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let source = base + (y0 + y) * row + (x0 + x) * 4, i = (y * width + x) * 4
                pixels[i] = Double(source[2]); pixels[i + 1] = Double(source[1]); pixels[i + 2] = Double(source[0])
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        handle(index, Frame(width: width, height: height, pixels: pixels))
    }
}

/// Part de magenta d'un pixel : min(R, B) − V. Le fond de Veo n'est pas tout à fait uni (de 0,45 à 0,8), le chat
/// reste sous 0,15 (même ses joues roses) : opaque sous 0,15, transparent au-dessus de 0,45. La couleur du fond,
/// mesurée sur le bord de l'image, est retirée des pixels de bord pour ne pas laisser de liseré rose.
/// Le rose que la compression de la vidéo fait déborder sur les bords est aussi retiré, sur les pixels moins opaques que
/// `despillBelow` : tous pour la patte, seulement le contour pour la sieste, dont les joues roses sont voulues.
func removeMagenta(_ frame: inout Frame, despillBelow: Double) {
    func magenta(_ i: Int) -> Double { (min(frame.pixels[i], frame.pixels[i + 2]) - frame.pixels[i + 1]) / 255 }
    var background = (0.0, 0.0, 0.0, 0.0)
    for y in 0..<frame.height {
        for x in 0..<frame.width where y == 0 || y == frame.height - 1 || x == 0 || x == frame.width - 1 {
            let i = (y * frame.width + x) * 4
            guard magenta(i) > 0.45 else { continue }
            background = (background.0 + frame.pixels[i], background.1 + frame.pixels[i + 1], background.2 + frame.pixels[i + 2], background.3 + 1)
        }
    }
    let key = [background.0, background.1, background.2].map { $0 / max(background.3, 1) }
    for i in stride(from: 0, to: frame.pixels.count, by: 4) {
        var alpha = max(0, min(1, (0.45 - magenta(i)) / 0.30))
        if alpha < 0.05 { alpha = 0 }
        for c in 0..<3 {
            frame.pixels[i + c] = max(0, min(alpha * 255, frame.pixels[i + c] - (1 - alpha) * key[c]))
        }
        frame.pixels[i + 3] = alpha * 255
        if alpha < despillBelow {
            let spill = max(0, min(frame.pixels[i], frame.pixels[i + 2]) - frame.pixels[i + 1])
            frame.pixels[i] -= spill
            frame.pixels[i + 2] -= spill
        }
    }
}

/// Efface les taches détachées du sujet (poussières de Veo, traits de vitesse) : soit tout sauf la plus grande, soit
/// celles de moins de `minArea` pixels (les « z » de la sieste sont détachés de la tête, mais bien plus grands).
func removeSpecks(_ frame: inout Frame, keepLargestOnly: Bool, minArea: Int = 0) {
    let count = frame.width * frame.height
    var label = [Int32](repeating: 0, count: count)
    var areas: [Int] = [0]
    var stack: [Int] = []
    for start in 0..<count where label[start] == 0 && frame.pixels[start * 4 + 3] > 0 {
        let id = Int32(areas.count)
        var area = 0
        label[start] = id
        stack.append(start)
        while let p = stack.popLast() {
            area += 1
            let (x, y) = (p % frame.width, p / frame.width)
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            where nx >= 0 && ny >= 0 && nx < frame.width && ny < frame.height {
                let q = ny * frame.width + nx
                if label[q] == 0 && frame.pixels[q * 4 + 3] > 0 { label[q] = id; stack.append(q) }
            }
        }
        areas.append(area)
    }
    let largest = areas.indices.dropFirst().max { areas[$0] < areas[$1] } ?? 0
    for p in 0..<count where label[p] != 0 {
        let kept = keepLargestOnly ? Int(label[p]) == largest : areas[Int(label[p])] >= minArea
        if !kept { for c in 0..<4 { frame.pixels[p * 4 + c] = 0 } }
    }
}

func makeImage(_ frame: Frame) -> CGImage {
    let bytes = frame.pixels.map { UInt8($0.rounded()) }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
                   space: sRGB, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
}

func scaled(_ image: CGImage, width: Int, height: Int) -> Frame {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return Frame(width: width, height: height, pixels: pixels.map(Double.init))
}

/// HEVC avec transparence (lu par AVPlayerLayer sur Mac et iPhone), sans son.
func writeVideo(_ frames: [Frame], fps: Int32, to url: URL) {
    try? FileManager.default.removeItem(at: url)
    let writer = try! AVAssetWriter(outputURL: url, fileType: .mov)
    let (width, height) = (frames[0].width, frames[0].height)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoQualityKey: 0.8,
            kVTCompressionPropertyKey_TargetQualityForAlpha as String: 0.9,
        ],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    for (index, frame) in frames.enumerated() {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        let pixelBuffer = buffer!
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: sRGB,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(makeImage(frame), in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferAlphaChannelModeKey, kCVImageBufferAlphaChannelMode_PremultipliedAlpha, .shouldPropagate)
        adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(index), timescale: fps))
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    guard writer.status == .completed else { fatalError("Vidéo non écrite : \(String(describing: writer.error))") }
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
}

// --- Sieste en boucle
var nap: [Frame] = []
readFrames("MascotNap", crop: napCrop, keep: { _ in true }) { _, frame in
    var frame = frame
    removeMagenta(&frame, despillBelow: 1)
    removeSpecks(&frame, keepLargestOnly: false, minArea: 250)
    nap.append(scaled(makeImage(frame), width: napSize, height: napSize))
}
// Boucle : les dernières images se fondent dans les premières, la vidéo finit là où elle recommence.
let loopLength = nap.count - napCrossfade
let loop = (0..<loopLength).map { j -> Frame in
    guard j < napCrossfade else { return nap[j] }
    let t = Double(j) / Double(napCrossfade)
    var mixed = nap[j]
    for i in mixed.pixels.indices { mixed.pixels[i] = nap[loopLength + j].pixels[i] * (1 - t) + nap[j].pixels[i] * t }
    return mixed
}
writeVideo(loop, fps: 24, to: root.appendingPathComponent("Shared/Resources/MascotNap.mov"))
print("MascotNap.mov : \(loop.count) images, \(napSize) × \(napSize)")

// --- Patte
let pawFrames = pawEntry + pawWindUp + pawPush
var paws: [Int: Frame] = [:]
let pawWidth = Int((pawCrop.width / pawCrop.height * Double(pawHeight)).rounded())
readFrames("PawPush", crop: pawCrop, keep: pawFrames.contains) { index, frame in
    var frame = frame
    removeMagenta(&frame, despillBelow: .infinity)
    removeSpecks(&frame, keepLargestOnly: true)
    paws[index] = scaled(makeImage(frame), width: pawWidth, height: pawHeight)
}
let assets = root.appendingPathComponent("Shared/Resources/Shared.xcassets")
for old in (try? FileManager.default.contentsOfDirectory(atPath: assets.path)) ?? [] where old.hasPrefix("PawPush") {
    try? FileManager.default.removeItem(at: assets.appendingPathComponent(old))
}
for (n, index) in pawFrames.enumerated() {
    writeImageset(String(format: "PawPush%02d", n), makeImage(paws[index]!))
}
// Où se pose le bout de la patte à la fin de l'entrée, en part de la largeur : Theme.Layout.pawRestTip.
let rest = paws[pawEntry.last!]!
let tip = (0..<rest.width).last { x in (0..<rest.height).contains { rest.pixels[($0 * rest.width + x) * 4 + 3] > 128 } } ?? 0
print("PawPush : \(pawFrames.count) images (\(pawEntry.count + pawWindUp.count) avant la chute), \(pawWidth) × \(pawHeight),",
      String(format: "bout de la patte posé à %.3f de la largeur", Double(tip + 1) / Double(rest.width)))
