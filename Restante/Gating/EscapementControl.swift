import Foundation

/// Role: Abstraction. Next payday and interval. Presentations never snap hours.
@MainActor
@Observable
final class EscapementAbstraction {
    var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    var intervalDays = Regulator.defaultInterval
    var weekday = Regulator.friday
    var fault: String?
    var busy = false
}

/// Role: Control. Payday snap and weekday/interval writes. Child of Pendulum.
@MainActor
@Observable
final class EscapementControl {
    unowned let pendulum: PendulumControl
    let abstraction = EscapementAbstraction()

    init(pendulum: PendulumControl) {
        self.pendulum = pendulum
    }

    func sync(from rules: Regulator) {
        abstraction.weekday = rules.weekday
        abstraction.intervalDays = rules.intervalDays
        abstraction.selectedDay = Calendar.current.startOfDay(for: Horology.date(from: rules.anchorPayday))
        abstraction.fault = nil
    }

    func select(_ date: Date) {
        let start = Calendar.current.startOfDay(for: date)
        abstraction.selectedDay = start
        abstraction.weekday = Calendar.current.component(.weekday, from: start)
        abstraction.fault = nil
    }

    func setInterval(_ days: Int) {
        abstraction.intervalDays = max(1, days)
    }

    func lodge() async throws {
        guard !abstraction.busy else { return }
        abstraction.busy = true
        defer { abstraction.busy = false }
        var rules = pendulum.snapshot.regulator
        rules.weekday = abstraction.weekday
        rules.intervalDays = abstraction.intervalDays
        rules.anchorPayday = Horology.instant(from: abstraction.selectedDay)
        do {
            try await pendulum.commit(rules)
            abstraction.fault = nil
            pendulum.dismissSpoke()
        } catch {
            abstraction.fault = "Payday rules did not lodge. Try again."
            throw error
        }
    }
}
