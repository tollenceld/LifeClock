import XCTest

@MainActor
final class KeduUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["onboarding.birthDate"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.targetAge"].exists)
        XCTAssertTrue(app.buttons["onboarding.finish"].waitForExistence(timeout: 2))
        app.buttons["onboarding.finish"].tap()
        XCTAssertTrue(app.buttons["event.add"].waitForExistence(timeout: 3))
    }

    func testAddEditAndDeleteEvent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSeeded"]
        app.launch()

        XCTAssertTrue(app.buttons["event.add"].waitForExistence(timeout: 3))
        app.buttons["event.add"].tap()

        let titleField = app.textFields["event.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("生日")
        app.buttons["event.save"].tap()

        XCTAssertTrue(app.buttons["event.summary"].waitForExistence(timeout: 3))
        app.buttons["event.summary"].tap()
        XCTAssertTrue(app.buttons["event.delete"].waitForExistence(timeout: 2))
        app.buttons["event.delete"].tap()
        XCTAssertTrue(app.buttons["confirmation.destructive"].waitForExistence(timeout: 2))
        app.buttons["confirmation.destructive"].tap()

        XCTAssertFalse(app.buttons["event.summary"].waitForExistence(timeout: 3))
    }

    func testSettingsUsesImmediateCustomControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSeeded", "-uiTestingOpenSettings"]
        app.launch()

        XCTAssertTrue(app.staticTexts["设置"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["settings.birthday"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.targetAge"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.weekStart"].exists)

        let haptics = app.descendants(matching: .any)["settings.haptics"]
        XCTAssertTrue(haptics.waitForExistence(timeout: 2))
        haptics.tap()

        let close = app.buttons["settings.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
        close.tap()
        XCTAssertTrue(app.buttons["settings.button"].waitForExistence(timeout: 3))
    }

    func testDirectEventEditorStates() throws {
        let add = XCUIApplication()
        add.launchArguments = ["-uiTesting", "-uiTestingSeeded", "-uiTestingOpenEventEditor"]
        add.launch()
        XCTAssertTrue(add.descendants(matching: .any)["event.preview"].waitForExistence(timeout: 3))
        XCTAssertTrue(add.descendants(matching: .any)["event.appearance"].exists)
        XCTAssertFalse(add.buttons["event.delete"].exists)
        add.terminate()

        let edit = XCUIApplication()
        edit.launchArguments = [
            "-uiTesting", "-uiTestingSeeded", "-uiTestingSeedEvent", "-uiTestingOpenEditEvent"
        ]
        edit.launch()
        XCTAssertTrue(edit.buttons["event.delete"].waitForExistence(timeout: 3))
        XCTAssertTrue(edit.buttons["event.save"].exists)
    }

    func testSwitchesAcrossFiveScales() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSeeded"]
        app.launch()

        let scales = [
            ("life", "人生时钟"),
            ("year", "年度时钟"),
            ("month", "月度时钟"),
            ("week", "每周时钟"),
            ("day", "今日时钟")
        ]

        for (scale, accessibilityLabel) in scales {
            let button = app.buttons["scale.\(scale)"]
            XCTAssertTrue(button.waitForExistence(timeout: 2))
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertEqual(button.label, accessibilityLabel)
            button.tap()
            XCTAssertTrue(app.otherElements["clock.\(scale)"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.descendants(matching: .any)["timefield.\(scale)"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.descendants(matching: .any)["insight.\(scale)"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.descendants(matching: .any)["relations.\(scale)"].waitForExistence(timeout: 2))
        }
    }

    func testDragAcrossScaleNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSeeded"]
        app.launch()

        let year = app.buttons["scale.year"]
        let life = app.buttons["scale.life"]
        let day = app.buttons["scale.day"]
        XCTAssertTrue(year.waitForExistence(timeout: 3))
        XCTAssertTrue(life.exists)
        XCTAssertTrue(day.exists)

        life.tap()
        life.press(forDuration: 0.15, thenDragTo: day)
        XCTAssertTrue(app.otherElements["clock.day"].waitForExistence(timeout: 3))

        day.press(forDuration: 0.15, thenDragTo: year)
        XCTAssertTrue(app.otherElements["clock.year"].waitForExistence(timeout: 3))
    }
}
