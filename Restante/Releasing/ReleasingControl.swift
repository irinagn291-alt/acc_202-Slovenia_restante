import Foundation

/// Role: Abstraction. Gate-open release. Closed gate never offers a skip.
@MainActor
@Observable
final class ReleasingAbstraction {
    var focus: BarrelStamp?
    var open = false
    var fault: String?
    var busy = false
}

/// Role: Control. Strike bought or dropped only after the payday gate opens.
@MainActor
@Observable
final class ReleasingControl {
    unowned let pendulum: PendulumControl
    let abstraction = ReleasingAbstraction()

    init(pendulum: PendulumControl) {
        self.pendulum = pendulum
    }

    func sync(focus: Mainspring?, open: Bool) {
        abstraction.open = open
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
    }

    func strike(_ kind: StrikeKind) async throws {
        guard abstraction.open else {
            abstraction.fault = "Wait for payday, or sacrifice another want."
            throw CarriageError.stillCooling
        }
        guard !abstraction.busy else { return }
        abstraction.busy = true
        defer { abstraction.busy = false }
        guard let id = abstraction.focus?.id,
              let held = pendulum.snapshot.mainsprings[id]
        else {
            abstraction.fault = "Nothing is waiting at the gate."
            throw CarriageError.stillCooling
        }
        do {
            let (halted, record) = try Releasing.strike(held, as: kind, at: Horology.instant(from: Date()))
            try await pendulum.commit(halted, chime: false)
            try await pendulum.retire(halted.id)
            try await pendulum.commit(pendulum.snapshot.dispatch.appending(record))
            abstraction.fault = nil
        } catch let error as CarriageError {
            abstraction.fault = error == .stillCooling
                ? "Wait for payday, or sacrifice another want."
                : "The strike did not lodge."
            throw error
        }
    }
}
