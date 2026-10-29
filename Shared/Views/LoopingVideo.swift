import AVFoundation
import SwiftUI

/// Vidéo en boucle, muette, avec transparence (HEVC avec alpha) : la sieste de la mascotte (`MascotNap.mov`, faite par
/// `Artwork/make-animations.swift`). Elle ne tourne que quand on la voit : panneau ouvert sur Mac, app au premier plan
/// sur l'iPhone.
struct LoopingVideo {
    let url: URL
}

/// File de lecture qui rejoue la vidéo sans fin, sans empêcher l'écran de se mettre en veille.
private final class LoopingPlayer {
    let player = AVQueuePlayer()
    private let looper: AVPlayerLooper

    init(url: URL) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
    }
}

#if os(macOS)
extension LoopingVideo: NSViewRepresentable {
    func makeNSView(context: Context) -> PlayerView { PlayerView(url: url) }
    func updateNSView(_ view: PlayerView, context: Context) {}

    final class PlayerView: NSView {
        private let looping: LoopingPlayer
        private var observer: NSObjectProtocol?

        init(url: URL) {
            looping = LoopingPlayer(url: url)
            super.init(frame: .zero)
            let playerLayer = AVPlayerLayer(player: looping.player)
            playerLayer.videoGravity = .resizeAspect
            layer = playerLayer
            wantsLayer = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) n'est pas utilisé") }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        /// Le panneau caché reste en mémoire : la vidéo s'arrête quand sa fenêtre n'est plus visible.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = window.map { window in
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
                ) { [weak self] _ in self?.updatePlayback() }
            }
            updatePlayback()
        }

        private func updatePlayback() {
            if window?.occlusionState.contains(.visible) == true {
                looping.player.play()
            } else {
                looping.player.pause()
            }
        }
    }
}
#else
extension LoopingVideo: UIViewRepresentable {
    func makeUIView(context: Context) -> PlayerView { PlayerView(url: url) }
    func updateUIView(_ view: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        private let looping: LoopingPlayer
        private var observers: [NSObjectProtocol] = []

        init(url: URL) {
            looping = LoopingPlayer(url: url)
            super.init(frame: .zero)
            backgroundColor = .clear
            isOpaque = false
            let playerLayer = layer as! AVPlayerLayer
            playerLayer.player = looping.player
            playerLayer.videoGravity = .resizeAspect
            // iOS met la vidéo en pause en arrière-plan sans la relancer au retour.
            observers = [UIApplication.didBecomeActiveNotification, UIApplication.didEnterBackgroundNotification].map { name in
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.updatePlayback()
                }
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) n'est pas utilisé") }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updatePlayback()
        }

        private func updatePlayback() {
            if window != nil && UIApplication.shared.applicationState != .background {
                looping.player.play()
            } else {
                looping.player.pause()
            }
        }
    }
}
#endif
