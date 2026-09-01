import Foundation

/// Role: Abstraction. Released, sacrificed, still-cooling. No view types.
@MainActor
@Observable
final class DispatchAbstraction {
    var bought: [BarrelStamp] = []
    var dropped: [BarrelStamp] = []
    var sacrificed: [BarrelStamp] = []
    var cooling: [BarrelStamp] = []
    var fault: String?
    var empty = true
}

/// Role: Control. Review book. Child of Pendulum. Talks only to Controls.
@MainActor
@Observable
final class DispatchControl {
    unowned let pendulum: PendulumControl
    let abstraction = DispatchAbstraction()

    init(pendulum: PendulumControl) {
        self.pendulum = pendulum
    }

    func sync(from carriage: Carriage, now: Date) {
        let instant = Horology.instant(from: now)
        abstraction.bought = carriage.dispatch.bought.map { row in
            outcome(row, phase: .struck)
        }
        abstraction.dropped = carriage.dispatch.dropped.map { row in
            outcome(row, phase: .struck)
        }
        abstraction.sacrificed = carriage.dispatch.sacrificed.map { row in
            outcome(row, phase: .sacrificed)
        }
        abstraction.cooling = carriage.held
            .filter { $0.halt == nil && $0.phase(at: instant) == .cooling }
            .map { item in
                let remaining = max(0, item.unlockAt - instant)
                return BarrelStamp(
                    id: item.id,
                    title: item.title,
                    price: item.price,
                    remaining: remaining,
                    remainingHours: Horology.hours(from: remaining),
                    unlockAt: item.unlockAt,
                    phase: .cooling,
                    coversFocus: false
                )
            }
        abstraction.empty = abstraction.bought.isEmpty
            && abstraction.dropped.isEmpty
            && abstraction.sacrificed.isEmpty
            && abstraction.cooling.isEmpty
    }

    func retry() async {
        abstraction.fault = nil
        await pendulum.refresh()
    }

    private func outcome(_ row: Strike, phase: WaitPhase) -> BarrelStamp {
        BarrelStamp(
            id: row.id,
            title: row.title,
            price: row.price,
            remaining: Horology.interval(hours: row.remainingHours),
            remainingHours: row.remainingHours,
            unlockAt: row.struckAt,
            phase: phase,
            coversFocus: false
        )
    }
}
