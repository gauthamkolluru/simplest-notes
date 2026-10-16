import XCTest

/// Phase 2 UI tests (T2.06–T2.16). Run on iOS Simulator / macOS via CI.
final class EditorUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// T2.06 Launch (not first) → editor visible and focused.
    func test_T2_06_launchShowsFocusedEditor() {
        app.launchArguments += ["-ui-testing", "-skip-onboarding"]
        app.launch()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
#if os(iOS)
        // Software keyboard should appear without an extra tap when focused.
        let keyboard = app.keyboards.element
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Keyboard should show on iOS/iPadOS at launch")
#endif
    }

    /// T2.07 First launch → onboarding explains benefit with Connect / Not now.
    func test_T2_07_firstLaunchShowsOnboardingBenefit() {
        app.launchArguments += ["-ui-testing", "-force-onboarding"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["onboardingSheet"].waitForExistence(timeout: 5))
        let benefit = app.staticTexts["onboardingBenefit"]
        XCTAssertTrue(benefit.waitForExistence(timeout: 2))
        let text = benefit.label.lowercased()
        XCTAssertTrue(text.contains("backup") || text.contains("drive") || text.contains("delete"))
        XCTAssertTrue(app.buttons["onboardingConnect"].exists)
        XCTAssertTrue(app.buttons["onboardingNotNow"].exists)
    }

    /// T2.08 After onboarding dismissal → editor focused.
    func test_T2_08_afterOnboardingEditorFocused() {
        app.launchArguments += ["-ui-testing", "-force-onboarding"]
        app.launch()
        app.buttons["onboardingNotNow"].tap()
        XCTAssertTrue(app.textViews["noteEditor"].waitForExistence(timeout: 5))
    }

    /// T2.09 No formatting toolbar / title / file name / save button.
    func test_T2_09_noChrome() {
        app.launchArguments += ["-ui-testing", "-skip-onboarding"]
        app.launch()
        XCTAssertFalse(app.buttons["Save"].exists)
        XCTAssertFalse(app.navigationBars.buttons.count > 0 && app.navigationBars.staticTexts["Untitled"].exists)
        XCTAssertFalse(app.buttons["Bold"].exists)
    }

    /// T2.11 Select all + delete empties and persists (best-effort via typing clear).
    func test_T2_11_clearingNotePersistsEmpty() {
        app.launchArguments += ["-ui-testing", "-skip-onboarding", "-seed-text", "hello"]
        app.launch()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
#if os(macOS)
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey(.delete, modifierFlags: [])
#else
        editor.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        editor.typeText(XCUIKeyboardKey.delete.rawValue)
#endif
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding"]
        app.launch()
        let editor2 = app.textViews["noteEditor"]
        XCTAssertTrue(editor2.waitForExistence(timeout: 5))
        // Empty or whitespace-only after clear
        let value = editor2.value as? String ?? ""
        XCTAssertTrue(value.isEmpty || value == "\n")
    }

    /// T2.12 Type → kill → relaunch → text present.
    func test_T2_12_textSurvivesRelaunch() {
        app.launchArguments += ["-ui-testing", "-skip-onboarding", "-reset-note"]
        app.launch()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("persist-me")
        // Allow autosave debounce
        Thread.sleep(forTimeInterval: 0.5)
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding"]
        app.launch()
        let editor2 = app.textViews["noteEditor"]
        XCTAssertTrue(editor2.waitForExistence(timeout: 5))
        let value = editor2.value as? String ?? ""
        XCTAssertTrue(value.contains("persist-me"))
    }
}
