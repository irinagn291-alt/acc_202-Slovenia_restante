import Foundation

/// Role: Abstraction. Payday weekday, interval, monthly impulse limit.
@MainActor
@Observable
final class RegulatorAbstraction {
    var weekday = Regulator.friday
    var intervalDays = Regulator.defaultInterval
    var limitText = ""
    var fault: String?
    var busy = false
    var empty = false
}

/// Role: Control. Rules spoke. Validates then writes the regulator document.
@MainActor
@Observable
final class RegulatorControl {
    unowned let pendulum: PendulumControl
    let abstraction = RegulatorAbstraction()

    init(pendulum: PendulumControl) {
        self.pendulum = pendulum
    }

    func sync(from rules: Regulator) {
        abstraction.weekday = rules.weekday
        abstraction.intervalDays = rules.intervalDays
        abstraction.limitText = PostageFigures.decimal(rules.monthlyImpulseLimit)
        abstraction.empty = false
        abstraction.fault = nil
    }

    func setWeekday(_ weekday: Int) {
        abstraction.weekday = weekday
        abstraction.fault = nil
    }

    func setInterval(_ days: Int) {
        abstraction.intervalDays = max(1, days)
    }

    func setLimitText(_ raw: String) {
        let separator = Locale.current.decimalSeparator ?? "."
        let allowed = CharacterSet(charactersIn: "0123456789\(separator)")
        abstraction.limitText = String(raw.unicodeScalars.filter { allowed.contains($0) })
        abstraction.fault = nil
    }

    func lodge() async throws {
        guard !abstraction.busy else { return }
        abstraction.busy = true
        defer { abstraction.busy = false }
        guard let limit = PostageFigures.parseDecimal(abstraction.limitText), limit > 0 else {
            abstraction.fault = "Monthly limit must be greater than zero."
            throw CarriageError.invalidLimit
        }
        var rules = pendulum.snapshot.regulator
        rules.weekday = abstraction.weekday
        rules.intervalDays = abstraction.intervalDays
        rules.monthlyImpulseLimit = limit
        let start = Calendar.current.startOfDay(for: Horology.date(from: rules.anchorPayday))
        rules.anchorPayday = Horology.instant(from: start)
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
