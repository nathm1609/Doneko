import Foundation

/// Horloge injectable : la logique ne lit jamais `Date()` directement, pour pouvoir simuler le temps en test.
protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}
