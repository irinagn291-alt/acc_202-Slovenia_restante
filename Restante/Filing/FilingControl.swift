import Foundation

/// Role: Abstraction. Draft of a want. Presentations never run the fusee.
@MainActor
@Observable
final class FilingAbstraction {
    var title = ""
    var priceText = ""
    var necessity = 40.0
    var discretion = 40.0
    var priority = 1.0
    var fault: String?
    var busy = false
}

/// Role: Control. Primary verb — file a want. Fusee hours then payday snap, then write.
@MainActor
@Observable
final class FilingControl {
    unowned let pendulum: PendulumControl
    let abstraction = FilingAbstraction()

    init(pendulum: PendulumControl) {
        self.pendulum = pendulum
    }

    func resetDraft() {
        abstraction.title = ""
        abstraction.priceText = ""
        abstraction.necessity = 40
        abstraction.discretion = 40
        abstraction.priority = 1
        abstraction.fault = nil
        abstraction.busy = false
    }

    func setTitle(_ text: String) {
        abstraction.title = text
        abstraction.fault = nil
    }

    func setPriceText(_ raw: String) {
        let separator = Locale.current.decimalSeparator ?? "."
        let allowed = CharacterSet(charactersIn: "0123456789\(separator)")
        abstraction.priceText = String(raw.unicodeScalars.filter { allowed.contains($0) })
        abstraction.fault = nil
    }

    func setNecessity(_ value: Double) {
        abstraction.necessity = min(100, max(0, value))
    }

    func setDiscretion(_ value: Double) {
        abstraction.discretion = min(100, max(0, value))
    }

    func setPriority(_ value: Double) {
        abstraction.priority = max(0.1, value)
    }

    func submit() async throws {
        guard !abstraction.busy else { return }
        abstraction.busy = true
        defer { abstraction.busy = false }
        let title = abstraction.title
        guard let price = PostageFigures.parseDecimal(abstraction.priceText), price > 0 else {
            abstraction.fault = "Enter a price greater than zero."
            throw CarriageError.invalidPrice
        }
        let rules = pendulum.snapshot.regulator
        do {
            let item = try Filing.mainspring(
                title: title,
                price: price,
                necessity: abstraction.necessity,
                discretion: abstraction.discretion,
                priority: abstraction.priority,
                at: Horology.instant(from: Date()),
                regulator: rules,
                calendar: Calendar.current
            )
            try await pendulum.commit(item)
            abstraction.fault = nil
            pendulum.dismissSpoke()
        } catch let error as CarriageError {
            abstraction.fault = filingCopy(error)
            throw error
        }
    }

    private func filingCopy(_ error: CarriageError) -> String {
        switch error {
        case .emptyTitle:
            return "Name the want."
        case .invalidPrice:
            return "Price must be greater than zero."
        case .invalidNecessity:
            return "Necessity is 0 to 100."
        case .invalidDiscretion:
            return "Discretion is 0 to 100."
        case .invalidPriority:
            return "Priority must be greater than zero."
        default:
            return "The want could not be filed."
        }
    }
}
