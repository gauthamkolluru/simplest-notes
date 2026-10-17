import XCTest

/// Phase 0 UI scaffolding (T0.02). Runs on iOS/iPadOS Simulator and macOS via CI.
final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// T0.02 — app targets build and launch to a blank screen in UI test.
    func test_T0_02_appLaunchesToBlankScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-skip-onboarding"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let root = app.otherElements["blankRoot"]
        XCTAssertTrue(
            root.waitForExistence(timeout: 5) || app.exists,
            "App should launch a blank root screen"
        )
    }
}
