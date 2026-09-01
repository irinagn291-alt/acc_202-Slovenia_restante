import Foundation

/// Role: Domain. Released, sacrificed and still-cooling review book.
struct DispatchBook: Hashable, Sendable, Equatable {
    var strikes: [Strike]

    static let empty = DispatchBook(strikes: [])

    func appending(_ strike: Strike) -> DispatchBook {
        var next = self
        next.strikes.append(strike)
        return next
    }

    var bought: [Strike] { strikes.filter { $0.kind == .bought } }
    var dropped: [Strike] { strikes.filter { $0.kind == .dropped } }
    var sacrificed: [Strike] { strikes.filter { $0.kind == .sacrificed } }
}
