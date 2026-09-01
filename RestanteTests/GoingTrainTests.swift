import XCTest
@testable import Restante

final class GoingTrainTests: XCTestCase {
    private var folder: URL!
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        suite = "rst.test.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDownWithError() throws {
        if let folder {
            try? FileManager.default.removeItem(at: folder)
        }
        if let suite {
            defaults?.removePersistentDomain(forName: suite)
        }
        folder = nil
        defaults = nil
        suite = nil
    }

    func test_roundTrip_reloadPreservesMainspringAndPayday() async throws {
        let calendar = gmtCalendar()
        let train = makeTrain(calendar: calendar)
        let regulator = Regulator(
            weekday: 6,
            intervalDays: 7,
            monthlyImpulseLimit: 400,
            anchorPayday: Horology.instant(from: date(2026, 1, 2, calendar: calendar))
        )
        try await train.commit(regulator)
        let held = try Filing.mainspring(
            title: "Walnut desk",
            price: 120,
            necessity: 30,
            discretion: 50,
            priority: 1,
            at: Horology.instant(from: date(2026, 1, 5, 12, calendar: calendar)),
            regulator: regulator,
            calendar: calendar
        )
        try await train.commit(held)
        let strike = Strike(
            id: UUID(),
            mainspringID: held.id,
            title: held.title,
            price: held.price,
            kind: .dropped,
            struckAt: held.unlockAt,
            remainingHours: 0
        )
        try await train.commit(DispatchBook(strikes: [strike]))

        let relaunched = makeTrain(calendar: calendar)
        let loaded = await relaunched.load()
        XCTAssertNil(loaded.warning)
        XCTAssertEqual(loaded.carriage.held.count, 1)
        let restored = try XCTUnwrap(loaded.carriage.held.first)
        XCTAssertEqual(restored.id, held.id)
        XCTAssertEqual(restored.title, "Walnut desk")
        XCTAssertEqual(restored.price, 120)
        XCTAssertEqual(restored.unlockAt, held.unlockAt)
        XCTAssertEqual(loaded.carriage.regulator.monthlyImpulseLimit, 400)
        XCTAssertEqual(loaded.carriage.dispatch.strikes.count, 1)
        XCTAssertEqual(loaded.carriage.dispatch.dropped.first?.kind, .dropped)
    }

    func test_corruptMainspringFallsBackToBackup() async throws {
        let calendar = gmtCalendar()
        let train = makeTrain(calendar: calendar)
        let held = try Filing.mainspring(
            id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA") ?? UUID(),
            title: "Lamp",
            price: 40,
            necessity: 20,
            discretion: 20,
            priority: 1,
            at: 50_000,
            regulator: Regulator.factoryDefault(
                now: date(2026, 1, 5, calendar: calendar),
                calendar: calendar
            ),
            calendar: calendar
        )
        try await train.commit(held)
        let url = folder
            .appendingPathComponent("mainsprings", isDirectory: true)
            .appendingPathComponent("\(held.id.uuidString).json")
        let backup = url.appendingPathExtension("backup")
        try FileManager.default.copyItem(at: url, to: backup)
        try Data("{not-json".utf8).write(to: url)

        let loaded = await makeTrain(calendar: calendar).load()
        XCTAssertEqual(loaded.warning, .recoveredFromBackup)
        XCTAssertEqual(loaded.carriage.held.first?.id, held.id)
    }

    func test_corruptFileWithoutBackupStartsEmpty() async throws {
        let springs = folder.appendingPathComponent("mainsprings", isDirectory: true)
        try FileManager.default.createDirectory(at: springs, withIntermediateDirectories: true)
        let url = springs.appendingPathComponent("\(UUID().uuidString).json")
        try Data("nope".utf8).write(to: url)
        let loaded = await makeTrain().load()
        XCTAssertEqual(loaded.warning, .startedEmpty)
        XCTAssertTrue(loaded.carriage.held.isEmpty)
    }

    func test_resetAllData_clearsDocuments() async throws {
        let train = makeTrain()
        let calendar = gmtCalendar()
        try await train.commit(
            try Filing.mainspring(
                title: "Pen",
                price: 30,
                necessity: 10,
                discretion: 10,
                priority: 1,
                at: 1_000,
                regulator: Regulator.factoryDefault(
                    now: date(2026, 1, 5, calendar: calendar),
                    calendar: calendar
                ),
                calendar: calendar
            )
        )
        try await train.resetAllData()
        let loaded = await train.load()
        XCTAssertTrue(loaded.carriage.held.isEmpty)
        XCTAssertTrue(loaded.carriage.dispatch.strikes.isEmpty)
        let leftovers = try FileManager.default.contentsOfDirectory(
            at: folder.appendingPathComponent("mainsprings", isDirectory: true),
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(leftovers.filter { $0.pathExtension == "json" }.isEmpty)
    }

    func test_waybillSwitchesOnSchemaVersion() throws {
        let held = Mainspring(
            id: UUID(),
            title: "Card",
            price: 12,
            necessity: 10,
            discretion: 10,
            priority: 1,
            filedAt: 20,
            coolingHours: 48,
            unlockAt: 200,
            halt: nil
        )
        let data = try Waybill.encodeMainspring(held)
        let decoded = try Waybill.decodeMainspring(data)
        XCTAssertEqual(decoded.title, "Card")
        XCTAssertEqual(decoded.coolingHours, 48)

        XCTAssertThrowsError(try Waybill.decodeMainspring(Data("{\"schemaVersion\":99}".utf8))) { error in
            XCTAssertEqual(error as? Waybill.Fault, .unsupportedSchema(99))
        }
        XCTAssertThrowsError(try Waybill.decodeMainspring(Data("[]".utf8))) { error in
            XCTAssertEqual(error as? Waybill.Fault, .corrupt)
        }
    }

    #if targetEnvironment(simulator)
    func test_simulatorSeedWritesFourHeldWantsOnce() async throws {
        let calendar = gmtCalendar()
        let train = makeTrain(calendar: calendar)
        try await train.seedDemoIfNeeded()
        try await train.seedDemoIfNeeded()
        let loaded = await train.load()
        XCTAssertEqual(loaded.carriage.held.count, 4)
        XCTAssertEqual(Set(loaded.carriage.held.map(\.id)), [
            PostageSeed.walnut, PostageSeed.lamp, PostageSeed.jacket, PostageSeed.pen,
        ])
        XCTAssertTrue(defaults.bool(forKey: PostageKey.demoSeed))
        XCTAssertTrue(defaults.bool(forKey: PostageKey.onboardingComplete))
    }
    #endif

    private func makeTrain(calendar: Calendar = gmtCalendar()) -> GoingTrain {
        GoingTrain(
            directory: folder,
            defaultsSuiteName: suite,
            now: { Date(timeIntervalSince1970: 1_767_312_000) },
            calendar: calendar,
            writeDelayNanoseconds: 0
        )
    }
}
