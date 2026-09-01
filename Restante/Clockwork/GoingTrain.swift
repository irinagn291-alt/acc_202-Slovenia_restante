import Foundation

/// Role: Storage. JSON documents, one file per aggregate. FileManager stays here.
actor GoingTrain {
    private let directory: URL
    private let defaultsSuiteName: String?
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let writeDelayNanoseconds: UInt64

    private var carriage: Carriage
    private var pendingMainsprings: Set<UUID> = []
    private var pendingRegulator = false
    private var pendingDispatch = false
    private var writeTask: Task<Void, Never>?
    private(set) var warning: TrainWarning?
    private(set) var lastWriteError: String?

    init(
        directory: URL,
        defaultsSuiteName: String? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = Calendar.current,
        writeDelayNanoseconds: UInt64 = 300_000_000
    ) {
        self.directory = directory
        self.defaultsSuiteName = defaultsSuiteName
        self.now = now
        self.calendar = calendar
        self.writeDelayNanoseconds = writeDelayNanoseconds
        self.carriage = Carriage(
            mainsprings: [:],
            regulator: Regulator.factoryDefault(now: now(), calendar: calendar),
            dispatch: .empty
        )
    }

    static func applicationSupportDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appendingPathComponent("Restante", isDirectory: true)
    }

    var snapshot: Carriage { carriage }

    func load() async -> (carriage: Carriage, warning: TrainWarning?) {
        warning = nil
        prepareFolders()
        var recovered = false
        var sawDocument = false
        var loadedAny = false

        var held: [UUID: Mainspring] = [:]
        for url in mainspringURLs() {
            sawDocument = true
            if let item = readMainspring(url) {
                held[item.id] = item
                loadedAny = true
                continue
            }
            if let item = readMainspring(backupURL(for: url)) {
                held[item.id] = item
                recovered = true
                loadedAny = true
            }
        }

        let regulatorURL = directory.appendingPathComponent("regulator.json")
        if FileManager.default.fileExists(atPath: regulatorURL.path) {
            sawDocument = true
            if let item = readRegulator(regulatorURL) {
                carriage.regulator = item
                loadedAny = true
            } else if let item = readRegulator(backupURL(for: regulatorURL)) {
                carriage.regulator = item
                recovered = true
                loadedAny = true
            }
        }

        let dispatchURL = directory.appendingPathComponent("dispatch.json")
        if FileManager.default.fileExists(atPath: dispatchURL.path) {
            sawDocument = true
            if let book = readDispatch(dispatchURL) {
                carriage.dispatch = book
                loadedAny = true
            } else if let book = readDispatch(backupURL(for: dispatchURL)) {
                carriage.dispatch = book
                recovered = true
                loadedAny = true
            }
        }

        carriage.mainsprings = held
        if recovered {
            warning = .recoveredFromBackup
        } else if sawDocument, !loadedAny {
            warning = .startedEmpty
            carriage.mainsprings = [:]
            carriage.dispatch = .empty
        }
        return (carriage, warning)
    }

    func commit(_ mainspring: Mainspring) async throws {
        try writeMainspring(mainspring)
        carriage.mainsprings[mainspring.id] = mainspring
        pendingMainsprings.remove(mainspring.id)
        lastWriteError = nil
    }

    func commit(_ regulator: Regulator) async throws {
        let checked = try Regulation.validated(regulator)
        try writeRegulator(checked)
        carriage.regulator = checked
        pendingRegulator = false
        lastWriteError = nil
    }

    func commit(_ book: DispatchBook) async throws {
        try writeDispatch(book)
        carriage.dispatch = book
        pendingDispatch = false
        lastWriteError = nil
    }

    func retire(_ id: UUID) async throws {
        carriage.mainsprings[id] = nil
        pendingMainsprings.remove(id)
        try removeMainspringFile(id)
        lastWriteError = nil
    }

    func stage(_ mainspring: Mainspring) {
        carriage.mainsprings[mainspring.id] = mainspring
        pendingMainsprings.insert(mainspring.id)
        scheduleFlush()
    }

    func stage(_ regulator: Regulator) throws {
        carriage.regulator = try Regulation.validated(regulator)
        pendingRegulator = true
        scheduleFlush()
    }

    func stage(_ book: DispatchBook) {
        carriage.dispatch = book
        pendingDispatch = true
        scheduleFlush()
    }

    func flush() async throws {
        writeTask?.cancel()
        writeTask = nil
        try persistPending()
    }

    func resetAllData() async throws {
        writeTask?.cancel()
        writeTask = nil
        pendingMainsprings = []
        pendingRegulator = false
        pendingDispatch = false
        warning = nil
        lastWriteError = nil
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        carriage = Carriage(
            mainsprings: [:],
            regulator: Regulator.factoryDefault(now: now(), calendar: calendar),
            dispatch: .empty
        )
        prepareFolders()
        let defaults = preferenceDefaults()
        defaults.removeObject(forKey: PostageKey.demoSeed)
        defaults.removeObject(forKey: PostageKey.onboardingComplete)
    }

    func seedDemoIfNeeded() async throws {
        #if targetEnvironment(simulator)
        let defaults = preferenceDefaults()
        guard defaults.object(forKey: PostageKey.demoSeed) == nil else { return }
        let (regulator, posts) = try PostageSeed.day(now: now(), calendar: calendar)
        try await commit(regulator)
        for post in posts {
            try await commit(post)
        }
        defaults.set(true, forKey: PostageKey.demoSeed)
        defaults.set(true, forKey: PostageKey.onboardingComplete)
        #endif
    }

    private func scheduleFlush() {
        writeTask?.cancel()
        let delay = writeDelayNanoseconds
        writeTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.flushQuietly()
        }
    }

    private func flushQuietly() async {
        writeTask = nil
        do {
            try persistPending()
        } catch {
            lastWriteError = String(describing: error)
        }
    }

    private func persistPending() throws {
        let ids = pendingMainsprings
        pendingMainsprings = []
        for id in ids {
            if let item = carriage.mainsprings[id] {
                try writeMainspring(item)
            }
        }
        if pendingRegulator {
            pendingRegulator = false
            try writeRegulator(carriage.regulator)
        }
        if pendingDispatch {
            pendingDispatch = false
            try writeDispatch(carriage.dispatch)
        }
        lastWriteError = nil
    }

    private func writeMainspring(_ item: Mainspring) throws {
        prepareFolders()
        let url = mainspringURL(item.id)
        try replaceAtomically(Waybill.encodeMainspring(item), at: url)
    }

    private func writeRegulator(_ item: Regulator) throws {
        prepareFolders()
        try replaceAtomically(
            Waybill.encodeRegulator(item),
            at: directory.appendingPathComponent("regulator.json")
        )
    }

    private func writeDispatch(_ book: DispatchBook) throws {
        prepareFolders()
        try replaceAtomically(
            Waybill.encodeDispatch(book),
            at: directory.appendingPathComponent("dispatch.json")
        )
    }

    private func replaceAtomically(_ data: Data, at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = backupURL(for: url)
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
        }
        try data.write(to: url, options: .atomic)
    }

    private func readMainspring(_ url: URL) -> Mainspring? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Waybill.decodeMainspring(data)
    }

    private func readRegulator(_ url: URL) -> Regulator? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Waybill.decodeRegulator(data)
    }

    private func readDispatch(_ url: URL) -> DispatchBook? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Waybill.decodeDispatch(data)
    }

    private func removeMainspringFile(_ id: UUID) throws {
        let url = mainspringURL(id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let backup = backupURL(for: url)
        if FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.removeItem(at: backup)
        }
    }

    private func mainspringURLs() -> [URL] {
        let folder = directory.appendingPathComponent("mainsprings", isDirectory: true)
        let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
        return (contents ?? []).filter { url in
            url.pathExtension == "json" && !url.lastPathComponent.hasSuffix(".json.backup")
        }
    }

    private func mainspringURL(_ id: UUID) -> URL {
        directory
            .appendingPathComponent("mainsprings", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
    }

    private func backupURL(for url: URL) -> URL {
        url.appendingPathExtension("backup")
    }

    private func preferenceDefaults() -> UserDefaults {
        if let defaultsSuiteName {
            return UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        }
        return .standard
    }

    private func prepareFolders() {
        let springs = directory.appendingPathComponent("mainsprings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: springs.path) {
            try? FileManager.default.createDirectory(at: springs, withIntermediateDirectories: true)
        }
    }
}
