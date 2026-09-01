import Foundation

/// Role: Domain. How a mainspring left the barrel.
enum StrikeKind: String, Sendable, Hashable, Codable {
    case bought
    case dropped
    case sacrificed
}

/// Role: Domain. One released or sacrificed outcome.
struct Strike: Identifiable, Hashable, Sendable, Equatable {
    var id: UUID
    var mainspringID: UUID
    var title: String
    var price: Double
    var kind: StrikeKind
    var struckAt: TimeInterval
    var remainingHours: Double
}

/// Role: Domain (owned by Controls). Payday-open release. No skip while cooling.
enum Releasing {
    static func strike(
        _ mainspring: Mainspring,
        as kind: StrikeKind,
        at instant: TimeInterval
    ) throws -> (Mainspring, Strike) {
        guard kind == .bought || kind == .dropped else { throw CarriageError.invalidStrike }
        guard mainspring.halt == nil else { throw CarriageError.alreadyHalted }
        guard mainspring.phase(at: instant) == .open else { throw CarriageError.stillCooling }

        var halted = mainspring
        halted.halt = .struck
        let record = Strike(
            id: UUID(),
            mainspringID: mainspring.id,
            title: mainspring.title,
            price: mainspring.price,
            kind: kind,
            struckAt: instant,
            remainingHours: 0
        )
        return (halted, record)
    }
}
