import Foundation

/// Role: Domain (owned by Controls). Hour formula. Presentations never call this.
enum Fusee {
    static let floorHours = 6.0
    static let ceilingHours = 720.0
    static let monthHours = 720.0

    static func baseHours(price: Double, monthlyLimit: Double) throws -> Double {
        guard price.isFinite, price > 0 else { throw CarriageError.invalidPrice }
        guard monthlyLimit.isFinite, monthlyLimit > 0 else { throw CarriageError.invalidLimit }
        return (price / monthlyLimit) * monthHours
    }

    /// hours = base × priority × (1.5 − nec/100) × (2 − disc/100), clamped 6…720.
    static func coolingHours(
        price: Double,
        monthlyLimit: Double,
        priority: Double,
        necessity: Double,
        discretion: Double
    ) throws -> Double {
        let base = try baseHours(price: price, monthlyLimit: monthlyLimit)
        guard priority.isFinite, priority > 0 else { throw CarriageError.invalidPriority }
        guard necessity.isFinite, (0 ... 100).contains(necessity) else {
            throw CarriageError.invalidNecessity
        }
        guard discretion.isFinite, (0 ... 100).contains(discretion) else {
            throw CarriageError.invalidDiscretion
        }
        let raw = base * priority * (1.5 - necessity / 100) * (2 - discretion / 100)
        guard raw.isFinite else { throw CarriageError.invalidPrice }
        return min(ceilingHours, max(floorHours, raw))
    }
}
