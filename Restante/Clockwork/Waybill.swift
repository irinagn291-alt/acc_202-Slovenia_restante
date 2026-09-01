import Foundation

/// Role: Storage. JSON envelope for one mainspring. Domain never sees this type.
struct MainspringWaybill: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var id: UUID
    var title: String
    var price: Double
    var necessity: Double
    var discretion: Double
    var priority: Double
    var filedAt: TimeInterval
    var coolingHours: Double
    var unlockAt: TimeInterval
    var halt: Halt?
}

/// Role: Storage. JSON envelope for payday rules.
struct RegulatorWaybill: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var weekday: Int
    var intervalDays: Int
    var monthlyImpulseLimit: Double
    var anchorPayday: TimeInterval
}

/// Role: Storage. JSON envelope for one strike row.
struct StrikeWaybill: Codable, Equatable, Sendable {
    var id: UUID
    var mainspringID: UUID
    var title: String
    var price: Double
    var kind: StrikeKind
    var struckAt: TimeInterval
    var remainingHours: Double
}

/// Role: Storage. JSON envelope for the dispatch book.
struct DispatchWaybill: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var strikes: [StrikeWaybill]
}

private struct SchemaProbe: Decodable {
    var schemaVersion: Int
}

/// Role: Storage. schemaVersion switch and mapping. No FileManager.
enum Waybill {
    static let currentSchema = 1

    enum Fault: Error, Equatable {
        case unsupportedSchema(Int)
        case corrupt
    }

    static func encodeMainspring(_ item: Mainspring) throws -> Data {
        try encode(
            MainspringWaybill(
                schemaVersion: currentSchema,
                id: item.id,
                title: item.title,
                price: item.price,
                necessity: item.necessity,
                discretion: item.discretion,
                priority: item.priority,
                filedAt: item.filedAt,
                coolingHours: item.coolingHours,
                unlockAt: item.unlockAt,
                halt: item.halt
            )
        )
    }

    static func decodeMainspring(_ data: Data) throws -> Mainspring {
        let bill: MainspringWaybill = try decode(data)
        return Mainspring(
            id: bill.id,
            title: bill.title,
            price: bill.price,
            necessity: bill.necessity,
            discretion: bill.discretion,
            priority: bill.priority,
            filedAt: bill.filedAt,
            coolingHours: bill.coolingHours,
            unlockAt: bill.unlockAt,
            halt: bill.halt
        )
    }

    static func encodeRegulator(_ item: Regulator) throws -> Data {
        try encode(
            RegulatorWaybill(
                schemaVersion: currentSchema,
                weekday: item.weekday,
                intervalDays: item.intervalDays,
                monthlyImpulseLimit: item.monthlyImpulseLimit,
                anchorPayday: item.anchorPayday
            )
        )
    }

    static func decodeRegulator(_ data: Data) throws -> Regulator {
        let bill: RegulatorWaybill = try decode(data)
        return Regulator(
            weekday: bill.weekday,
            intervalDays: bill.intervalDays,
            monthlyImpulseLimit: bill.monthlyImpulseLimit,
            anchorPayday: bill.anchorPayday
        )
    }

    static func encodeDispatch(_ book: DispatchBook) throws -> Data {
        try encode(
            DispatchWaybill(
                schemaVersion: currentSchema,
                strikes: book.strikes.map { strike in
                    StrikeWaybill(
                        id: strike.id,
                        mainspringID: strike.mainspringID,
                        title: strike.title,
                        price: strike.price,
                        kind: strike.kind,
                        struckAt: strike.struckAt,
                        remainingHours: strike.remainingHours
                    )
                }
            )
        )
    }

    static func decodeDispatch(_ data: Data) throws -> DispatchBook {
        let bill: DispatchWaybill = try decode(data)
        return DispatchBook(
            strikes: bill.strikes.map { row in
                Strike(
                    id: row.id,
                    mainspringID: row.mainspringID,
                    title: row.title,
                    price: row.price,
                    kind: row.kind,
                    struckAt: row.struckAt,
                    remainingHours: row.remainingHours
                )
            }
        )
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw Fault.corrupt
        }
        switch probe.schemaVersion {
        case 1:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw Fault.corrupt
            }
        default:
            throw Fault.unsupportedSchema(probe.schemaVersion)
        }
    }
}
