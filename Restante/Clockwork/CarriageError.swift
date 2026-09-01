import Foundation

/// Role: Domain. Failures of filing, fusee, regulator, remontoire and strike.
enum CarriageError: Error, Equatable, Sendable {
    case emptyTitle
    case invalidPrice
    case invalidNecessity
    case invalidDiscretion
    case invalidPriority
    case invalidLimit
    case invalidWeekday
    case invalidInterval
    case stillCooling
    case alreadyOpen
    case alreadyHalted
    case donorNotCooling
    case sameMainspring
    case gapNotCovered
    case invalidStrike
}
