import Foundation

/// Role: Abstraction. Donors that cover the payday gap. No skip while cooling.
@MainActor
@Observable
final class RemontoireAbstraction {
    var focus: BarrelStamp?
    var donors: [BarrelStamp] = []
    var fault: String?
    var busy = false
}

/// Role: Control. Buy early only by sacrificing another cooling want.
@MainActor
@Observable
final class RemontoireControl {
    unowned let pendulum: PendulumControl
    let abstraction = RemontoireAbstraction()

    init(pendulum: PendulumControl) {
        self.pendulum = pendulum
    }

    func sync(focus: Mainspring?, donors: [BarrelStamp]) {
        if let focus {
            let instant = Horology.instant(from: Date())
            let remaining = max(0, focus.unlockAt - instant)
            abstraction.focus = BarrelStamp(
                id: focus.id,
                title: focus.title,
                price: focus.price,
                remaining: remaining,
                remainingHours: Horology.hours(from: remaining),
                unlockAt: focus.unlockAt,
                phase: focus.phase(at: instant),
                coversFocus: false
            )
        } else {
            abstraction.focus = nil
        }
        abstraction.donors = donors
    }

    func prepare() {
        abstraction.fault = nil
    }

    func sacrifice(_ donorID: UUID) async throws {
        guard !abstraction.busy else { return }
        abstraction.busy = true
        defer { abstraction.busy = false }
        let instant = Horology.instant(from: Date())
        guard let focusID = abstraction.focus?.id,
              let target = pendulum.snapshot.mainsprings[focusID],
              let donor = pendulum.snapshot.mainsprings[donorID]
        else {
            abstraction.fault = "Choose a cooling want that covers the gap."
            throw CarriageError.gapNotCovered
        }
        do {
            let result = try Remontoire.advance(target, sacrificing: donor, at: instant)
            try await pendulum.commit(result.advanced, chime: false)
            try await pendulum.commit(result.sacrificed, chime: false)
            try await pendulum.retire(result.sacrificed.id)
            let book = pendulum.snapshot.dispatch.appending(result.sacrifice)
            try await pendulum.commit(book)
            abstraction.fault = nil
            pendulum.dismissSpoke()
        } catch let error as CarriageError {
            abstraction.fault = remontoireCopy(error)
            throw error
        }
    }

    private func remontoireCopy(_ error: CarriageError) -> String {
        switch error {
        case .gapNotCovered:
            return "That want does not cover the hours to payday."
        case .donorNotCooling, .alreadyHalted, .alreadyOpen, .sameMainspring:
            return "Remontoire needs another cooling want."
        default:
            return "The swap did not strike."
        }
    }
}
