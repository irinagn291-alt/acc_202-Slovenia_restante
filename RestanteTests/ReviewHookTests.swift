import XCTest
@testable import Restante

final class ReviewHookTests: XCTestCase {
    func test_readsOnceAfterOnboarding() {
        var consumed = false
        XCTAssertNil(
            ReviewHook.consume(
                arguments: ["-ReviewScreen", "log"],
                onboarded: false,
                consumed: &consumed
            )
        )
        XCTAssertFalse(consumed)

        let first = ReviewHook.consume(
            arguments: ["app", "-ReviewScreen", "log"],
            onboarded: true,
            consumed: &consumed
        )
        XCTAssertEqual(first, .log)
        XCTAssertTrue(consumed)
        XCTAssertNil(
            ReviewHook.consume(
                arguments: ["-ReviewScreen", "goals"],
                onboarded: true,
                consumed: &consumed
            )
        )
    }

    func test_unknownKeyIsIgnored() {
        var consumed = false
        XCTAssertNil(
            ReviewHook.consume(
                arguments: ["-ReviewScreen", "aura"],
                onboarded: true,
                consumed: &consumed
            )
        )
        XCTAssertTrue(consumed)
    }
}
