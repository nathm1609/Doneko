import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌃⌥⌘D : appeler Doneko depuis n'importe où (personnalisable dans les réglages en V1).
    /// Pas ⌥⌘D : macOS le réserve au masquage du Dock.
    static let openPanel = Self("openPanel", default: .init(.d, modifiers: [.control, .option, .command]))
}
