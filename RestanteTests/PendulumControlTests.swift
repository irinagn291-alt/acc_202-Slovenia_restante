import XCTest
@testable import Restante

/// Architecture: Presentation calls Control, Control updates Abstraction. No ViewModel.
@MainActor
final class PendulumControlTests: XCTestCase {
    func test_abstractionExposesPhaseAndRemainingNotViews() {
        let face = PendulumAbstraction()
        face.remaining = 3600
        face.remainingHours = 1
        face.gateOpen = false
        face.phase = .cooling
        XCTAssertEqual(face.remaining, 3600)
        XCTAssertEqual(face.phase, .cooling)
        XCTAssertFalse(face.gateOpen)
    }

    func test_parentOwnsChildControls() {
        let pendulum = PendulumControl.isolated()
        XCTAssertTrue(pendulum.filing.pendulum === pendulum)
        XCTAssertTrue(pendulum.gating.pendulum === pendulum)
        XCTAssertTrue(pendulum.sacrificing.pendulum === pendulum)
        XCTAssertTrue(pendulum.releasing.pendulum === pendulum)
        XCTAssertTrue(pendulum.reviewing.pendulum === pendulum)
        XCTAssertTrue(pendulum.regulator.pendulum === pendulum)
    }

    func test_fileWantUpdatesPendulumAbstraction() async throws {
        let pendulum = PendulumControl.isolated()
        pendulum.abstraction.onboarded = true
        pendulum.filing.setTitle("Walnut desk")
        pendulum.filing.setPriceText("80")
        pendulum.filing.setNecessity(30)
        pendulum.filing.setDiscretion(50)
        pendulum.filing.setPriority(1)
        try await pendulum.filing.submit()

        XCTAssertEqual(pendulum.abstraction.cooling.count, 1)
        XCTAssertEqual(pendulum.abstraction.focus?.title, "Walnut desk")
        XCTAssertGreaterThan(pendulum.abstraction.remainingHours, 0)
        XCTAssertFalse(pendulum.abstraction.gateOpen)
        XCTAssertEqual(pendulum.abstraction.phase, .cooling)
        XCTAssertFalse(pendulum.abstraction.empty)
    }

    func test_invalidFileLeavesCarriageEmpty() async {
        let pendulum = PendulumControl.isolated()
        pendulum.filing.setTitle("Lamp")
        pendulum.filing.setPriceText("")
        do {
            try await pendulum.filing.submit()
            XCTFail("expected invalid price")
        } catch {
            XCTAssertEqual(error as? CarriageError, .invalidPrice)
        }
        XCTAssertTrue(pendulum.abstraction.empty)
        XCTAssertEqual(pendulum.abstraction.cooling.count, 0)
    }

    func test_closedGateRefusesStrikeAndOffersRemontoireOrWait() async throws {
        let pendulum = PendulumControl.isolated()
        pendulum.filing.setTitle("Jacket")
        pendulum.filing.setPriceText("120")
        pendulum.filing.setNecessity(20)
        pendulum.filing.setDiscretion(40)
        pendulum.filing.setPriority(1)
        try await pendulum.filing.submit()

        XCTAssertFalse(pendulum.abstraction.gateOpen)
        XCTAssertEqual(pendulum.abstraction.phase, .cooling)
        do {
            try await pendulum.releasing.strike(.bought)
            XCTFail("skip is forbidden")
        } catch {
            XCTAssertEqual(error as? CarriageError, .stillCooling)
        }
    }

    func test_reviewHookOpensDispatchAndRegulatorOnce() {
        let pendulum = PendulumControl.previewPopulated()
        pendulum.applyReviewHook(arguments: ["-ReviewScreen", "log"])
        XCTAssertEqual(pendulum.abstraction.spoke, .dispatch)
        pendulum.applyReviewHook(arguments: ["-ReviewScreen", "goals"])
        XCTAssertEqual(pendulum.abstraction.spoke, .dispatch)
    }

    func test_reviewHookTodayStaysOnPendulum() {
        let pendulum = PendulumControl.previewPopulated()
        pendulum.applyReviewHook(arguments: ["-ReviewScreen", "today"])
        XCTAssertNil(pendulum.abstraction.spoke)
    }
}
