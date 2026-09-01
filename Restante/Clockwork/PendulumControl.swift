import Foundation
import UIKit

/// Role: Abstraction. Sheet identity for payday-driven spokes. No view types.
enum PendulumSpoke: String, Identifiable, Equatable, Sendable {
    case filing
    case remontoire
    case payday
    case dispatch
    case regulator
    case settings
    case onboarding

    var id: String { rawValue }
}

/// Role: Abstraction. One held want, already snapped. Presentations only format this.
struct BarrelStamp: Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var price: Double
    var remaining: TimeInterval
    var remainingHours: Double
    var unlockAt: TimeInterval
    var phase: WaitPhase
    var coversFocus: Bool
}

/// Role: Abstraction. Remaining hours as TimeInterval since the reference date,
/// gate-open versus still-cooling, and the current wait phase. No view types.
@MainActor
@Observable
final class PendulumAbstraction {
    var remaining: TimeInterval = 0
    var remainingHours: Double = 0
    var gateOpen = false
    var phase: WaitPhase = .cooling
    var focus: BarrelStamp?
    var cooling: [BarrelStamp] = []
    var donors: [BarrelStamp] = []
    var fault: String?
    var busy = false
    var commitBusy = false
    var onboarded = false
    var spoke: PendulumSpoke?
    var paydayInstant: TimeInterval = 0
    var monthlyLimit: Double = Regulator.defaultLimit
    var empty: Bool = true
    var dialFraction: Double = 0
    var flashSuccess = false
}

/// Role: Control. Parent PAC agent. Owns fusee, payday snap, remontoire, JSON writes
/// through the train. Children talk only to this Control.
@MainActor
@Observable
final class PendulumControl {
    let abstraction: PendulumAbstraction
    let train: GoingTrain
    let defaults: UserDefaults
    private(set) var filing: FilingControl!
    private(set) var gating: EscapementControl!
    private(set) var sacrificing: RemontoireControl!
    private(set) var releasing: ReleasingControl!
    private(set) var reviewing: DispatchControl!
    private(set) var regulator: RegulatorControl!

    var shouldLoad = false
    private var carriage: Carriage
    private var hookConsumed = false
    private var appeared = false
    private let calendar: Calendar

    init(train: GoingTrain, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.train = train
        self.defaults = defaults
        self.calendar = calendar
        self.abstraction = PendulumAbstraction()
        self.carriage = Carriage(
            mainsprings: [:],
            regulator: Regulator.factoryDefault(now: Date(), calendar: calendar),
            dispatch: .empty
        )
        filing = FilingControl(pendulum: self)
        gating = EscapementControl(pendulum: self)
        sacrificing = RemontoireControl(pendulum: self)
        releasing = ReleasingControl(pendulum: self)
        reviewing = DispatchControl(pendulum: self)
        regulator = RegulatorControl(pendulum: self)
    }

    var snapshot: Carriage { carriage }

    func appear() async {
        guard shouldLoad else { return }
        if appeared {
            await refresh()
            applyReviewHook()
            return
        }
        appeared = true
        let spinner = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if !Task.isCancelled {
                abstraction.busy = true
            }
        }
        let loaded = await train.load()
        carriage = loaded.carriage
        do {
            try await train.seedDemoIfNeeded()
        } catch {
            abstraction.fault = "The carriage could not be opened."
        }
        await refresh()
        if loaded.warning == .startedEmpty, abstraction.fault == nil {
            abstraction.fault = "A waybill was unreadable. The pigeonhole is empty."
        } else if loaded.warning == .recoveredFromBackup {
            abstraction.fault = "Recovered the last good waybill."
        }
        abstraction.onboarded = defaults.bool(forKey: PostageKey.onboardingComplete)
        applyReviewHook()
        spinner.cancel()
        abstraction.busy = false
    }

    func refresh() async {
        carriage = await train.snapshot
        if let write = await train.lastWriteError, !write.isEmpty {
            abstraction.fault = "The waybill did not lodge. Try again."
        }
        apply(carriage, now: Date())
        reviewing.sync(from: carriage, now: Date())
        regulator.sync(from: carriage.regulator)
        gating.sync(from: carriage.regulator)
    }

    func tick(now: Date) {
        apply(carriage, now: now)
    }

    func open(_ spoke: PendulumSpoke) {
        abstraction.spoke = spoke
        if spoke == .filing {
            filing.resetDraft()
        }
        if spoke == .remontoire {
            sacrificing.prepare()
        }
        if spoke == .regulator {
            regulator.sync(from: carriage.regulator)
        }
        if spoke == .payday {
            gating.sync(from: carriage.regulator)
        }
        if spoke == .dispatch {
            reviewing.sync(from: carriage, now: Date())
        }
    }

    func dismissSpoke() {
        abstraction.spoke = nil
    }

    func finishOnboarding() async {
        defaults.set(true, forKey: PostageKey.onboardingComplete)
        abstraction.onboarded = true
        abstraction.spoke = nil
        do {
            try await train.commit(carriage.regulator)
        } catch {
            abstraction.fault = "Payday rules did not lodge."
        }
        await refresh()
        applyReviewHook()
    }

    func reopenOnboarding() {
        abstraction.spoke = .onboarding
    }

    func resetAll() async {
        abstraction.commitBusy = true
        defer { abstraction.commitBusy = false }
        do {
            try await train.resetAllData()
            carriage = await train.snapshot
            apply(carriage, now: Date())
            reviewing.sync(from: carriage, now: Date())
            regulator.sync(from: carriage.regulator)
            gating.sync(from: carriage.regulator)
            abstraction.onboarded = false
            abstraction.fault = nil
            hookConsumed = false
            abstraction.spoke = nil
        } catch {
            abstraction.fault = "Reset failed. Try again."
        }
    }

    func flush() async {
        do {
            try await train.flush()
        } catch {
            abstraction.fault = "The waybill did not lodge. Try again."
        }
    }

    func retry() async {
        abstraction.fault = nil
        await refresh()
    }

    func focus(_ id: UUID) {
        guard let item = carriage.mainsprings[id] else { return }
        let now = Date()
        apply(carriage, now: now, focusID: item.id)
    }

    func commit(_ mainspring: Mainspring, chime: Bool = true) async throws {
        try await train.commit(mainspring)
        await refresh()
        if chime { self.chime() }
    }

    func retire(_ id: UUID) async throws {
        try await train.retire(id)
        await refresh()
    }

    func commit(_ book: DispatchBook, chime: Bool = true) async throws {
        try await train.commit(book)
        await refresh()
        if chime { self.chime() }
    }

    func commit(_ rules: Regulator, chime: Bool = true) async throws {
        let checked = try Regulation.validated(rules)
        try await train.commit(checked)
        try await resnap(to: checked)
        await refresh()
        if chime { self.chime() }
    }

    func chime() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        abstraction.flashSuccess = true
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            abstraction.flashSuccess = false
        }
    }

    func applyReviewHook(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        guard abstraction.onboarded else { return }
        guard let pane = ReviewHook.consume(
            arguments: arguments,
            onboarded: true,
            consumed: &hookConsumed
        ) else { return }
        switch pane {
        case .today:
            break
        case .log:
            abstraction.spoke = .dispatch
        case .goals:
            abstraction.spoke = .regulator
        }
    }

    func hydratePreview() {
        let now = Date()
        do {
            let (rules, posts) = try PostageSeed.day(now: now, calendar: calendar)
            var held: [UUID: Mainspring] = [:]
            for post in posts {
                held[post.id] = post
            }
            carriage = Carriage(mainsprings: held, regulator: rules, dispatch: previewBook(from: posts, now: now))
            apply(carriage, now: now)
            reviewing.sync(from: carriage, now: now)
            regulator.sync(from: rules)
            gating.sync(from: rules)
            abstraction.onboarded = true
            abstraction.fault = nil
        } catch {
            abstraction.fault = "Preview carriage failed."
        }
    }

    private func previewBook(from posts: [Mainspring], now: Date) -> DispatchBook {
        guard let first = posts.first else { return .empty }
        return DispatchBook(strikes: [
            Strike(
                id: UUID(),
                mainspringID: first.id,
                title: first.title,
                price: first.price,
                kind: .bought,
                struckAt: Horology.instant(from: now),
                remainingHours: 0
            ),
        ])
    }

    private func resnap(to rules: Regulator) async throws {
        let now = Horology.instant(from: Date())
        for item in carriage.held where item.halt == nil {
            let raw = item.filedAt + Horology.interval(hours: item.coolingHours)
            var next = item
            next.unlockAt = Escapement.snap(rawUnlock: raw, regulator: rules, calendar: calendar)
            if next.phase(at: now) == .cooling || next.phase(at: now) == .open {
                try await train.commit(next)
            }
        }
    }

    private func apply(_ carriage: Carriage, now: Date, focusID: UUID? = nil) {
        let instant = Horology.instant(from: now)
        let live = carriage.held.filter { $0.halt == nil }
        let chosen = pickFocus(live, prefer: focusID, at: instant)
        let stamps = live.map { item in
            stamp(item, at: instant, focus: chosen)
        }
        .sorted { lhs, rhs in
            if lhs.phase == rhs.phase {
                return lhs.unlockAt < rhs.unlockAt
            }
            return lhs.phase == .open && rhs.phase != .open
        }
        abstraction.cooling = stamps.filter { $0.phase == .cooling }
        abstraction.donors = stamps.filter(\.coversFocus)
        abstraction.focus = chosen.map { stamp($0, at: instant, focus: chosen) }
        if let chosen {
            let remaining = max(0, chosen.unlockAt - instant)
            abstraction.remaining = remaining
            abstraction.remainingHours = Horology.hours(from: remaining)
            abstraction.phase = chosen.phase(at: instant)
            abstraction.gateOpen = abstraction.phase == .open
            abstraction.dialFraction = abstraction.gateOpen
                ? 1
                : min(1, max(0, remaining / Horology.interval(hours: Fusee.ceilingHours)))
        } else {
            abstraction.remaining = 0
            abstraction.remainingHours = 0
            abstraction.phase = .cooling
            abstraction.gateOpen = false
            abstraction.dialFraction = 0
        }
        abstraction.empty = live.isEmpty
        abstraction.monthlyLimit = carriage.regulator.monthlyImpulseLimit
        abstraction.paydayInstant = Escapement.snap(
            rawUnlock: instant,
            regulator: carriage.regulator,
            calendar: calendar
        )
        sacrificing.sync(focus: chosen, donors: stamps.filter(\.coversFocus))
        releasing.sync(focus: chosen, open: abstraction.gateOpen)
    }

    private func pickFocus(_ live: [Mainspring], prefer: UUID?, at instant: TimeInterval) -> Mainspring? {
        if let prefer, let hit = live.first(where: { $0.id == prefer }) {
            return hit
        }
        if let open = live.first(where: { $0.phase(at: instant) == .open }) {
            return open
        }
        return live.min { $0.unlockAt < $1.unlockAt }
    }

    private func stamp(
        _ item: Mainspring,
        at instant: TimeInterval,
        focus: Mainspring?
    ) -> BarrelStamp {
        let remaining = max(0, item.unlockAt - instant)
        var covers = false
        if let focus, focus.id != item.id {
            covers = Remontoire.covers(gapOf: focus, with: item, at: instant)
        }
        return BarrelStamp(
            id: item.id,
            title: item.title,
            price: item.price,
            remaining: remaining,
            remainingHours: Horology.hours(from: remaining),
            unlockAt: item.unlockAt,
            phase: item.phase(at: instant),
            coversFocus: covers
        )
    }

    static func live() -> PendulumControl {
        let directory: URL
        do {
            directory = try GoingTrain.applicationSupportDirectory()
        } catch {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("Restante", isDirectory: true)
        }
        let control = PendulumControl(
            train: GoingTrain(directory: directory),
            defaults: .standard,
            calendar: .current
        )
        control.shouldLoad = true
        return control
    }

    static func previewPopulated() -> PendulumControl {
        let control = isolated()
        control.shouldLoad = false
        control.hydratePreview()
        return control
    }

    static func isolated() -> PendulumControl {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("rst.pac.\(UUID().uuidString)", isDirectory: true)
        let suite = "rst.pac.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return PendulumControl(
            train: GoingTrain(
                directory: folder,
                defaultsSuiteName: suite,
                writeDelayNanoseconds: 0
            ),
            defaults: defaults,
            calendar: .current
        )
    }
}
