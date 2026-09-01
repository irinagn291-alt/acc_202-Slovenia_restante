import Foundation

/// Role: Storage. Preference keys. Demo seed is Simulator-only and versioned.
enum PostageKey {
    static let demoSeed = "rst.demo.v1"
    static let onboardingComplete = "rst.onboarding.complete"
}

/// Role: Storage. Recoverable load outcome. Never crash on a corrupt document.
enum TrainWarning: Equatable, Sendable {
    case recoveredFromBackup
    case startedEmpty
}

/// Role: Storage. In-memory carriage. Files are a projection of this.
struct Carriage: Equatable, Sendable {
    var mainsprings: [UUID: Mainspring]
    var regulator: Regulator
    var dispatch: DispatchBook

    var held: [Mainspring] {
        mainsprings.values.sorted { $0.filedAt < $1.filedAt }
    }
}

/// Role: Storage. Simulator-only demo day. Device never seeds.
enum PostageSeed {
    static let walnut = stamp("11111111-1111-4111-8111-111111111111")
    static let lamp = stamp("22222222-2222-4222-8222-222222222222")
    static let jacket = stamp("33333333-3333-4333-8333-333333333333")
    static let pen = stamp("44444444-4444-4444-8444-444444444444")

    /// Seed identities are literals. Failure here is a programmer error.
    private static func stamp(_ raw: String) -> UUID {
        guard let value = UUID(uuidString: raw) else {
            fatalError("Postage seed UUID literal is invalid")
        }
        return value
    }

    static func day(now: Date, calendar: Calendar) throws -> (Regulator, [Mainspring]) {
        let regulator = Regulator.factoryDefault(now: now, calendar: calendar)
        let filedAt = Horology.instant(from: now)
        let posts = try [
            Filing.mainspring(
                id: walnut,
                title: "Walnut desk",
                price: 320,
                necessity: 30,
                discretion: 80,
                priority: 1.2,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            ),
            Filing.mainspring(
                id: lamp,
                title: "Studio lamp",
                price: 90,
                necessity: 40,
                discretion: 60,
                priority: 1.0,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            ),
            Filing.mainspring(
                id: jacket,
                title: "Linen jacket",
                price: 180,
                necessity: 20,
                discretion: 70,
                priority: 1.1,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            ),
            Filing.mainspring(
                id: pen,
                title: "Fountain pen",
                price: 55,
                necessity: 60,
                discretion: 40,
                priority: 0.8,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            ),
        ]
        return (regulator, posts)
    }
}
