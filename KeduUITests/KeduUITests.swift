import XCTest

@MainActor
final class KeduUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchOnboarding() throws {
        let app = launch(seeded: false)
        XCTAssertTrue(element("onboarding.birthDate", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("onboarding.targetAge", in: app).exists)
        app.buttons["onboarding.finish"].tap()
        XCTAssertTrue(element("life.flip", in: app).waitForExistence(timeout: 3))
        assertLifeFace("生之时", in: app)
        XCTAssertTrue(app.buttons["scale.life"].isSelected)
    }

    func testAddEditAndDeleteEventThroughSettings() throws {
        let app = launch()
        openLibrary(in: app)
        app.buttons["events.add"].tap()

        let title = app.textFields["event.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("生日")
        app.buttons["event.save"].tap()

        let row = app.buttons["events.row.生日"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("纪念")
        app.buttons["event.save"].tap()

        let renamed = app.buttons["events.row.生日纪念"]
        XCTAssertTrue(renamed.waitForExistence(timeout: 3))
        renamed.tap()
        let delete = app.buttons["event.delete"]
        reveal(delete, in: app)
        delete.tap()
        let confirm = app.buttons["confirmation.destructive"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(renamed.waitForNonExistence(timeout: 3))
    }

    func testSettingsUsesImmediateControlsAndReturnsToSelectedScale() throws {
        let app = launch()
        app.buttons["scale.month"].tap()
        app.buttons["settings.button"].tap()
        XCTAssertTrue(element("settings.birthday", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("settings.targetAge", in: app).exists)
        XCTAssertFalse(element("settings.weekStart", in: app).exists)
        XCTAssertTrue(app.buttons["events.library"].exists)

        let haptics = element("settings.haptics", in: app)
        reveal(haptics, in: app)
        haptics.tap()
        let close = app.buttons["settings.close"]
        reveal(close, in: app, upwards: false)
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
        close.tap()
        XCTAssertTrue(element("timefield.month", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["scale.month"].isSelected)
    }

    func testDirectEventEditorStates() throws {
        let add = launch(arguments: ["-uiTestingOpenEventEditor"])
        XCTAssertTrue(element("event.preview", in: add).waitForExistence(timeout: 3))
        XCTAssertTrue(element("event.appearance", in: add).exists)
        XCTAssertFalse(add.buttons["event.delete"].exists)
        XCTAssertFalse(add.buttons["event.recurrence.weekly"].exists)
        add.terminate()

        let edit = launch(arguments: ["-uiTestingSeedEvent", "-uiTestingOpenEditEvent"])
        XCTAssertTrue(edit.buttons["event.delete"].waitForExistence(timeout: 3))
        XCTAssertTrue(edit.buttons["event.save"].exists)
    }

    func testSwitchesAcrossFourScalesWithoutRemovedContent() throws {
        let app = launch()
        XCTAssertTrue(element("life.flip", in: app).waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["scale.week"].exists)
        XCTAssertFalse(app.buttons["event.add"].exists)
        XCTAssertFalse(app.buttons["event.summary"].exists)
        XCTAssertFalse(app.buttons["events.library"].exists)

        for (scale, label) in [("life", "人生时钟"), ("day", "今日时钟"),
                               ("month", "月度时钟"), ("year", "年度时钟")] {
            let button = app.buttons["scale.\(scale)"]
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertEqual(button.label, label)
            button.tap()
            let visualIdentifier = scale == "life" ? "life.flip" : "timefield.\(scale)"
            XCTAssertTrue(element(visualIdentifier, in: app).waitForExistence(timeout: 3))
            XCTAssertTrue(button.isSelected)
            if scale != "life" { assertEightDecimalPlaces(element("clock.\(scale)", in: app)) }
            XCTAssertFalse(element("insight.\(scale)", in: app).exists)
            XCTAssertFalse(element("relations.\(scale)", in: app).exists)
            if scale == "life" {
                for other in ["year", "month", "day"] {
                    XCTAssertFalse(app.buttons["scale.\(other)"].isSelected)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(app.buttons["settings.button"].frame.height, 44)
        let order = ["scale.life", "scale.day", "scale.month", "scale.year", "settings.button"]
        for pair in zip(order, order.dropFirst()) {
            XCTAssertLessThan(app.buttons[pair.0].frame.midX, app.buttons[pair.1].frame.midX)
        }
    }

    func testLifeNumbersUpdateAndCardFlips() throws {
        let app = launch(arguments: ["-appearance", "dark"])
        let age = element("life.days", in: app)
        XCTAssertTrue(age.waitForExistence(timeout: 3))
        assertLifeFace("生之时", in: app)
        XCTAssertFalse(element("life.age", in: app).exists)
        XCTAssertFalse(element("life.progress", in: app).exists)
        let initial = try numericValue(of: age)
        assertEightDecimalPlaces(age)
        waitForValueChange(age)
        XCTAssertGreaterThan(try numericValue(of: age), initial)
        attachScreenshot("life-front-dark", from: app)
        element("life.flip", in: app).tap()
        assertLifeFace("死之时", in: app)
        let remaining = try numericValue(of: age)
        waitForValueChange(age)
        XCTAssertLessThan(try numericValue(of: age), remaining)
        assertEightDecimalPlaces(age)
        attachScreenshot("life-back-dark", from: app)
        app.buttons["life.face.elapsed"].tap()
        assertLifeFace("生之时", in: app)
    }

    func testLifeSwipeDoesNotFlipAndFacePersistsUntilRelaunch() throws {
        let app = launch()
        let card = element("life.flip", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.swipeLeft()
        XCTAssertTrue(element("timefield.day", in: app).waitForExistence(timeout: 3))
        app.buttons["scale.life"].tap()
        assertLifeFace("生之时", in: app)
        card.tap()
        assertLifeFace("死之时", in: app)
        app.buttons["scale.day"].tap()
        XCTAssertTrue(element("timefield.day", in: app).waitForExistence(timeout: 3))
        app.buttons["scale.life"].tap()
        assertLifeFace("死之时", in: app)
        app.terminate()
        app.launch()
        assertLifeFace("生之时", in: app)
    }

    func testLifeResumesActualTimeAfterSettings() throws {
        let app = launch()
        let age = element("life.days", in: app)
        XCTAssertTrue(age.waitForExistence(timeout: 3))
        let beforeSettings = try numericValue(of: age)
        app.buttons["settings.button"].tap()
        XCTAssertTrue(app.buttons["settings.close"].waitForExistence(timeout: 3))
        app.buttons["settings.close"].tap()
        XCTAssertTrue(age.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(try numericValue(of: age), beforeSettings)
        waitForValueChange(age)
    }

    func testReduceMotionKeepsLifeFlipAndFourScalesAvailable() throws {
        let app = launch(arguments: ["-uiTestingReduceMotion"])
        let card = element("life.flip", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        assertLifeFace("生之时", in: app)
        card.tap()
        assertLifeFace("死之时", in: app)
        XCTAssertTrue(card.isHittable)

        for scale in ["year", "month", "day"] {
            let button = app.buttons["scale.\(scale)"]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(element("timefield.\(scale)", in: app).waitForExistence(timeout: 3))
            XCTAssertTrue(button.isSelected)
        }

        app.buttons["scale.life"].tap()
        assertLifeFace("死之时", in: app)
        card.tap()
        assertLifeFace("生之时", in: app)
        XCTAssertTrue(app.buttons["settings.button"].isHittable)
        attachScreenshot("life-reduce-motion", from: app)
    }

    func testLibrarySearchAndEdit() throws {
        let app = launch(arguments: ["-uiTestingSeedEvent"])
        openLibrary(in: app)
        let row = app.buttons["events.row.生日"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        let search = app.textFields["events.search"]
        search.tap()
        search.typeText("不存在")
        XCTAssertTrue(row.waitForNonExistence(timeout: 3))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        let title = app.textFields["event.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("纪念")
        app.buttons["event.save"].tap()
        XCTAssertTrue(app.buttons["events.row.生日纪念"].waitForExistence(timeout: 3))
    }

    func testLegacyWeeklyEventCanBeViewedAndExplicitlyConverted() throws {
        let app = launch(arguments: ["-uiTestingSeedWeeklyEvent"])
        openLibrary(in: app)
        let history = element("events.history", in: app)
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        let row = app.buttons["events.row.每周回顾"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(element("event.preview", in: app).waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["event.recurrence.weekly"].exists)
        let title = app.textFields["event.title"]
        title.tap()
        title.typeText("更新")
        app.buttons["event.save"].tap()
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        let updatedRow = app.buttons["events.row.每周回顾更新"]
        XCTAssertTrue(updatedRow.waitForExistence(timeout: 3))
        updatedRow.tap()
        let yearly = app.buttons["event.recurrence.yearly"]
        reveal(yearly, in: app)
        yearly.tap()
        app.buttons["event.save"].tap()
        XCTAssertTrue(updatedRow.waitForExistence(timeout: 3))
        XCTAssertTrue(history.waitForNonExistence(timeout: 3))
        updatedRow.tap()
        XCTAssertTrue(app.buttons["event.recurrence.yearly"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["event.recurrence.yearly"].isSelected)
    }

    func testAppearanceAndLargeTextNavigation() throws {
        let app = launch(arguments: ["-uiTestingOpenSettings", "-UIPreferredContentSizeCategoryName",
                                     "UICTContentSizeCategoryAccessibilityXXXL"])
        let paper = app.buttons["appearance.light"]
        reveal(paper, in: app)
        paper.tap()
        attachScreenshot("settings-paper-large-text", from: app)
        let close = app.buttons["settings.close"]
        reveal(close, in: app, upwards: false)
        close.tap()
        XCTAssertTrue(element("life.flip", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("life.days", in: app).isHittable)
        XCTAssertTrue(app.buttons["scale.life"].isHittable)
        XCTAssertTrue(app.buttons["settings.button"].isHittable)
        attachScreenshot("life-paper-large-text", from: app)
        app.buttons["scale.day"].tap()
        XCTAssertTrue(element("timefield.day", in: app).waitForExistence(timeout: 3))
    }

    func testInstrumentScrollKeepsNavigationVisible() throws {
        let app = launch(arguments: ["-uiTestingScale", "day"])
        let day = app.buttons["scale.day"]
        XCTAssertTrue(day.waitForExistence(timeout: 3))
        let navigationFrame = day.frame
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(day.isHittable)
        XCTAssertEqual(day.frame, navigationFrame)
        attachScreenshot("instrument-after-scroll", from: app)
        app.buttons["scale.year"].tap()
        XCTAssertTrue(element("timefield.year", in: app).waitForExistence(timeout: 3))
    }

    func testDragAcrossCalendarNavigation() throws {
        let app = launch()
        let year = app.buttons["scale.year"]
        let day = app.buttons["scale.day"]
        XCTAssertTrue(year.waitForExistence(timeout: 3))
        year.press(forDuration: 0.15, thenDragTo: day)
        XCTAssertTrue(element("timefield.day", in: app).waitForExistence(timeout: 3))
        day.press(forDuration: 0.15, thenDragTo: year)
        XCTAssertTrue(element("timefield.year", in: app).waitForExistence(timeout: 3))
        app.buttons["scale.life"].tap()
        assertLifeFace("生之时", in: app)
    }

    func testNavigationExpandsAndSettingsNeverBecomesAScale() throws {
        let app = launch()
        let life = app.buttons["scale.life"]
        XCTAssertTrue(life.waitForExistence(timeout: 3))
        let expandedWidth = life.frame.width
        XCTAssertGreaterThan(expandedWidth, 90)
        app.buttons["scale.year"].tap()
        XCTAssertTrue(element("timefield.year", in: app).waitForExistence(timeout: 3))
        // Waiting for the destination also lets the 0.35 s navigation morph settle.
        XCTAssertLessThan(life.frame.width, 65)
        for key in ["scale.year", "scale.month", "scale.day", "settings.button"] {
            XCTAssertGreaterThanOrEqual(app.buttons[key].frame.width, 44)
        }
        app.buttons["scale.day"].press(forDuration: 0.15, thenDragTo: app.buttons["settings.button"])
        XCTAssertFalse(app.buttons["settings.close"].exists)
        XCTAssertTrue(app.buttons["scale.year"].isSelected)
        app.buttons["settings.button"].tap()
        XCTAssertTrue(app.buttons["settings.close"].waitForExistence(timeout: 3))
        app.buttons["settings.close"].tap()
        XCTAssertTrue(app.buttons["scale.year"].isSelected)
        life.tap()
        assertLifeFace("生之时", in: app)
        XCTAssertGreaterThan(life.frame.width, 90)
        attachScreenshot("timer-navigation-expanded", from: app)
    }

    func testTimerUpdatesAndResumesAfterBackground() throws {
        let app = launch()
        let timer = element("life.days", in: app)
        XCTAssertTrue(timer.waitForExistence(timeout: 3))
        XCTAssertEqual(timer.label, "已度过，天")
        waitForValueChange(timer)
        app.buttons["life.face.remaining"].tap()
        assertLifeFace("死之时", in: app)
        XCTAssertEqual(timer.label, "还剩，天")
        let oldAge = try numericValue(of: element("life.days", in: app))
        XCUIDevice.shared.press(.home)
        app.activate()
        assertLifeFace("死之时", in: app)
        XCTAssertLessThan(try numericValue(of: element("life.days", in: app)), oldAge)
        waitForValueChange(timer)
    }

    func testCalendarMarkersRemainEditableAcrossScales() throws {
        let app = launch(arguments: ["-uiTestingSeedEvent", "-uiTestingSeedCalendarEvents", "-appearance", "light"])
        for (scale, title) in [("day", "第一刻点"), ("month", "本月刻点"), ("year", "生日")] {
            app.buttons["scale.\(scale)"].tap()
            XCTAssertTrue(element("timefield.\(scale)", in: app).waitForExistence(timeout: 3))
            attachScreenshot("unified-\(scale)-light", from: app)
            if scale == "day" {
                let cluster = app.buttons["2 个刻点"]
                XCTAssertTrue(cluster.waitForExistence(timeout: 3))
                XCTAssertGreaterThanOrEqual(cluster.frame.height, 44)
                cluster.tap()
            }
            let marker = app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
            XCTAssertTrue(marker.waitForExistence(timeout: 3))
            marker.tap()
            let field = app.textFields["event.title"]
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            XCTAssertEqual(field.value as? String, title)
            app.buttons["event.save"].tap()
            XCTAssertTrue(app.buttons["scale.\(scale)"].isSelected)
        }
    }

    private func launch(seeded: Bool = true, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (seeded ? ["-uiTestingSeeded"] : []) + arguments
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func openLibrary(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["settings.button"].waitForExistence(timeout: 3))
        app.buttons["settings.button"].tap()
        let library = app.buttons["events.library"]
        XCTAssertTrue(library.waitForExistence(timeout: 3))
        reveal(library, in: app)
        library.tap()
        XCTAssertTrue(app.buttons["events.add"].waitForExistence(timeout: 3))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        for _ in 0..<6 where !element.isHittable {
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func assertLifeFace(_ expected: String, in app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        let face = app.buttons[expected == "生之时" ? "life.face.elapsed" : "life.face.remaining"]
        XCTAssertTrue(face.waitForExistence(timeout: 3), file: file, line: line)
        let match = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == YES"), object: face
        )
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 3), .completed, file: file, line: line)
    }

    private func numericValue(of element: XCUIElement) throws -> Double {
        let value = try XCTUnwrap(element.value as? String)
        return try XCTUnwrap(Double(value))
    }

    private func assertEightDecimalPlaces(_ element: XCUIElement,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let value = element.value as? String ?? ""
        XCTAssertNotNil(value.range(of: #"^\d+\.\d{8}$"#, options: .regularExpression), file: file, line: line)
    }

    private func waitForValueChange(_ element: XCUIElement) {
        let initial = element.value as? String ?? ""
        let change = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", initial), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [change], timeout: 2), .completed)
    }

    private func attachScreenshot(_ name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
