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
        attachScreenshot("audit-01-onboarding", from: app)
        app.buttons["onboarding.finish"].tap()
        XCTAssertTrue(element("clock.life", in: app).waitForExistence(timeout: 3))
        assertLifePhase(in: app)
        XCTAssertTrue(app.buttons["scale.life"].isSelected)
    }

    func testAddEditAndDeleteEventThroughSettings() throws {
        let app = launch()
        openLibrary(in: app)
        attachScreenshot("audit-08-empty-library", from: app)
        app.buttons["events.add"].tap()

        let title = app.textFields["event.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        attachScreenshot("audit-09-create-event", from: app)
        title.tap()
        title.typeText("生日")
        attachScreenshot("audit-10-keyboard-draft", from: app)
        app.buttons["event.save"].tap()

        let row = app.buttons["events.row.生日"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        attachScreenshot("audit-11-saved-library", from: app)
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
        attachScreenshot("audit-12-delete-confirmation", from: app)
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
        attachScreenshot("audit-06-settings", from: app)

        let haptics = element("settings.haptics", in: app)
        reveal(haptics, in: app)
        haptics.tap()
        attachScreenshot("audit-07-settings-preferences", from: app)
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
        XCTAssertTrue(element("clock.life", in: app).waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["scale.week"].exists)
        XCTAssertFalse(app.buttons["event.add"].exists)
        XCTAssertFalse(app.buttons["event.summary"].exists)
        XCTAssertFalse(app.buttons["events.library"].exists)

        for (scale, label) in [("life", "人生"), ("day", "今日时钟"),
                               ("month", "月度时钟"), ("year", "年度时钟")] {
            let button = app.buttons["scale.\(scale)"]
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertEqual(button.label, label)
            button.tap()
            let visualIdentifier = scale == "life" ? "clock.life" : "timefield.\(scale)"
            XCTAssertTrue(element(visualIdentifier, in: app).waitForExistence(timeout: 3))
            XCTAssertTrue(button.isSelected)
            attachScreenshot("audit-02-scale-\(scale)", from: app)
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

    func testLifeWeaveShowsBothTimes() throws {
        let app = launch(arguments: ["-appearance", "dark"])
        assertLifePhase(in: app)
        let past = element("life.days", in: app)
        let initialPast = try numericValue(of: past)
        assertEightDecimalPlaces(past)
        waitForValueChange(past)
        XCTAssertGreaterThan(try numericValue(of: past), initialPast)
        attachScreenshot("weave-dark", from: app)
        let future = element("life.remaining", in: app)
        let initialFuture = try numericValue(of: future)
        assertEightDecimalPlaces(future)
        waitForValueChange(future)
        XCTAssertLessThan(try numericValue(of: future), initialFuture)
        attachScreenshot("weave-dark-live", from: app)
        XCTAssertGreaterThan(try numericValue(of: past), initialPast)
    }

    func testLifeReadingsStayTogetherAcrossNavigation() throws {
        let app = launch(arguments: ["-appearance", "light"])
        assertLifePhase(in: app)
        attachScreenshot("weave-light", from: app)
        element("life.days", in: app).tap()
        assertLifePhase(in: app)
        attachScreenshot("weave-readings-together", from: app)
        app.buttons["settings.button"].tap()
        XCTAssertTrue(app.buttons["settings.close"].waitForExistence(timeout: 3))
        app.buttons["settings.close"].tap()
        assertLifePhase(in: app)
        attachScreenshot("weave-settings-return", from: app)
        element("clock.life", in: app).swipeLeft()
        XCTAssertTrue(element("timefield.day", in: app).waitForExistence(timeout: 3))
        attachScreenshot("day-original-appearance", from: app)
        app.buttons["scale.life"].tap()
        assertLifePhase(in: app)
        app.terminate()
        app.launch()
        assertLifePhase(in: app)
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

    func testReduceMotionKeepsWeaveAndFourScalesAvailable() throws {
        let app = launch(arguments: ["-uiTestingReduceMotion"])
        assertLifePhase(in: app)
        for scale in ["year", "month", "day"] {
            let button = app.buttons["scale.\(scale)"]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(element("timefield.\(scale)", in: app).waitForExistence(timeout: 3))
            XCTAssertTrue(element("clock.\(scale).remaining", in: app).exists)
            XCTAssertTrue(button.isSelected)
        }
        app.buttons["scale.life"].tap()
        assertLifePhase(in: app)
        XCTAssertTrue(app.buttons["settings.button"].isHittable)
        attachScreenshot("phase-reduce-motion", from: app)
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
        app.buttons["清除名称"].tap()
        title.tap()
        title.typeText("生日纪念")
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
        XCTAssertTrue(element("clock.life", in: app).waitForExistence(timeout: 3))
        reveal(element("life.days", in: app), in: app)
        XCTAssertTrue(element("life.days", in: app).isHittable)
        attachScreenshot("life-paper-large-text-past", from: app)
        assertLifePhase(in: app)
        app.scrollViews.firstMatch.swipeUp()
        let remaining = element("life.remaining", in: app)
        reveal(remaining, in: app)
        XCTAssertTrue(remaining.isHittable)
        XCTAssertLessThanOrEqual(remaining.frame.maxY, app.buttons["settings.button"].frame.minY)
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
        assertLifePhase(in: app)
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
        XCTAssertTrue(element("life.days", in: app).waitForExistence(timeout: 5))
        assertLifePhase(in: app)
        XCTAssertGreaterThan(life.frame.width, 90)
        attachScreenshot("timer-navigation-expanded", from: app)
    }

    func testBothReadingsResumeActualTimeAfterBackground() throws {
        let app = launch()
        for future in [false, true] {
            assertLifePhase(in: app)
            let reading = element(future ? "life.remaining" : "life.days", in: app)
            XCTAssertEqual(reading.label, future ? "死之终，预计尚余，天" : "生之始，已度过，天")
            let before = try numericValue(of: reading)
            XCUIDevice.shared.press(.home)
            app.activate()
            assertLifePhase(in: app)
            if future { XCTAssertLessThan(try numericValue(of: reading), before) }
            else { XCTAssertGreaterThan(try numericValue(of: reading), before) }
            waitForValueChange(reading)
        }
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
                attachScreenshot("phase-event-menu", from: app)
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

    func testPhaseMotionEvidence() throws {
        let app = launch(arguments: ["-appearance", "light"])
        assertLifePhase(in: app)
        for _ in 0..<6 { waitForValueChange(element("life.days", in: app)) }
        attachScreenshot("phase-life-light", from: app)
        for _ in 0..<4 { waitForValueChange(element("life.remaining", in: app)) }
        attachScreenshot("weave-minute-live", from: app)
        for scale in ["day", "month", "year", "life"] {
            app.buttons["scale.\(scale)"].tap()
            let identifier = scale == "life" ? "life.days" : "clock.\(scale)"
            XCTAssertTrue(element(identifier, in: app).waitForExistence(timeout: 3))
            for _ in 0..<4 { waitForValueChange(element(identifier, in: app)) }
            attachScreenshot("phase-zoom-\(scale)", from: app)
        }
    }

    func testLifetimeBasisAndEndpoint() throws {
        let app = launch(arguments: ["-uiTestingAtEndpoint"])
        assertLifePhase(in: app)
        XCTAssertEqual(element("life.progress", in: app).value as? String, "100.0%")
        XCTAssertTrue(element("life.endpoint", in: app).exists)
        waitForValueChange(element("life.days", in: app))
        XCTAssertEqual(try numericValue(of: element("life.remaining", in: app)), 0)
        XCTAssertEqual(element("life.progress", in: app).value as? String, "100.0%")
        XCTAssertTrue(element("life.endpoint", in: app).exists)
        app.buttons["settings.button"].tap()
        reveal(element("settings.lifeBasis", in: app), in: app)
        XCTAssertTrue(element("settings.lifeBasis", in: app).label.contains("并非死亡预测"))
    }

    func testStorageFailureCanRetryWithoutCrash() throws {
        let app = launch(arguments: ["-uiTestingStorageFailure"])
        XCTAssertTrue(app.buttons["storage.retry"].waitForExistence(timeout: 3))
        attachScreenshot("audit-13-storage-recovery", from: app)
        app.buttons["storage.retry"].tap()
        assertLifePhase(in: app)
    }

    func testUnsavedEventDraftCanContinueOrDiscard() throws {
        let app = launch(arguments: ["-uiTestingOpenEventEditor"])
        let title = app.textFields["event.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap(); title.typeText("未保存的刻点")
        app.buttons["event.close"].tap()
        XCTAssertTrue(app.buttons["继续编辑"].waitForExistence(timeout: 3))
        attachScreenshot("audit-14-unsaved-draft", from: app)
        app.buttons["继续编辑"].tap()
        XCTAssertEqual(title.value as? String, "未保存的刻点")
        app.buttons["event.close"].tap()
        app.buttons["放弃修改"].tap()
        assertLifePhase(in: app)
    }

    func testDataExportAndImportCanBeCancelled() throws {
        let app = launch(arguments: ["-uiTestingOpenSettings"])
        let data = element("settings.data", in: app)
        reveal(data, in: app); data.tap()
        XCTAssertTrue(app.buttons["data.export"].waitForExistence(timeout: 3))
        attachScreenshot("audit-15-local-data", from: app)
        for identifier in ["data.export", "data.import"] {
            app.buttons[identifier].tap()
            let cancel = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
            // A cold system file provider may take longer than an in-app sheet.
            if !cancel.waitForExistence(timeout: 15) {
                attachScreenshot("system-file-picker-missing-cancel", from: app)
                XCTFail("System picker cancel unavailable: \(app.debugDescription)")
                return
            }
            attachScreenshot("audit-16-\(identifier)", from: app)
            for _ in 0..<4 where !cancel.isHittable {
                let back = app.buttons["BackButton"]
                if back.exists && back.isHittable { back.tap() }
                else { break }
            }
            if cancel.isHittable { cancel.tap() }
            else {
                // System export browsers hide Cancel inside a selected directory.
                // Pull the observed sheet toolbar down to dismiss it.
                let toolbar = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: cancel.frame.midY))
                toolbar.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
            }
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["data.close"])
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        }
        app.buttons["data.close"].tap()
        let about = element("settings.about", in: app)
        reveal(about, in: app); about.tap()
        XCTAssertTrue(element("about.calculation", in: app).waitForExistence(timeout: 3))
        attachScreenshot("audit-17-calculation", from: app)
        let privacy = element("about.privacy", in: app)
        reveal(privacy, in: app)
        attachScreenshot("audit-18-privacy", from: app)
        app.buttons["about.close"].tap()
    }

    func testBackupRestoreConfirmationCommitsAndReturns() throws {
        let app = launch(arguments: ["-uiTestingOpenSettings", "-uiTestingPreviewBackup"])
        let data = element("settings.data", in: app)
        reveal(data, in: app); data.tap()
        XCTAssertTrue(app.buttons["data.restore.confirm"].waitForExistence(timeout: 3))
        attachScreenshot("audit-19-restore-preview", from: app)
        app.buttons["data.restore.confirm"].tap()
        XCTAssertTrue(element("data.notice", in: app).waitForExistence(timeout: 3))
        app.buttons["data.close"].tap()
        let close = app.buttons["settings.close"]
        reveal(close, in: app, upwards: false); close.tap()
        assertLifePhase(in: app)
        XCTAssertTrue(element("life.basis", in: app).label.contains("90"))
        openLibrary(in: app)
        XCTAssertTrue(app.buttons["events.row.备份中的刻点"].waitForExistence(timeout: 3))
        XCTAssertTrue(element("events.history", in: app).exists)
    }

    func testBirthdayChangesPreserveExpectedLifespan() throws {
        let app = launch(arguments: ["-uiTestingOpenSettings"])
        let birthday = element("settings.birthday", in: app)
        reveal(birthday, in: app); birthday.tap()
        XCTAssertTrue(app.buttons["settings.birthday.apply"].waitForExistence(timeout: 3))
        attachScreenshot("audit-20-birthday", from: app)
        let year = Calendar(identifier: .gregorian).component(.year, from: .now) - 90
        let wheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(wheel.exists)
        wheel.adjust(toPickerWheelValue: "\(year)年")
        app.buttons["settings.birthday.apply"].tap()
        let age = element("settings.targetAge", in: app)
        reveal(age, in: app); age.tap()
        XCTAssertTrue(app.buttons["settings.age.apply"].waitForExistence(timeout: 3))
        attachScreenshot("audit-21-lifespan", from: app)
        app.buttons["减少预计寿命"].tap()
        app.buttons["settings.age.apply"].tap()
        let close = app.buttons["settings.close"]
        reveal(close, in: app, upwards: false); close.tap()
        XCTAssertEqual(element("life.progress", in: app).value as? String, "100.0%")
        XCTAssertTrue(element("life.basis", in: app).label.contains("84"))
        XCTAssertTrue(element("life.endpoint", in: app).exists)
    }

    func testProfileAndEventsPersistAcrossColdLaunch() throws {
        let app = launch(arguments: ["-uiTestingPersistentStore", "-uiTestingResetStore"])
        openLibrary(in: app)
        app.buttons["events.add"].tap()
        let title = app.textFields["event.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap(); title.typeText("持久化刻点")
        app.buttons["event.save"].tap()
        XCTAssertTrue(app.buttons["events.row.持久化刻点"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["-uiTesting", "-uiTestingPersistentStore"]
        app.launch()
        assertLifePhase(in: app)
        openLibrary(in: app)
        XCTAssertTrue(app.buttons["events.row.持久化刻点"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["-uiTesting", "-uiTestingPersistentStore", "-uiTestingResetStore"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.finish"].waitForExistence(timeout: 3))
    }

    func testEditorAndPrivacySupportLargestText() throws {
        let app = launch(arguments: ["-uiTestingOpenEventEditor", "-uiTestingReduceTransparency", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let title = app.textFields["event.title"]
        reveal(title, in: app); title.tap(); title.typeText("大字号刻点")
        app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["完成", "Done"])).firstMatch.tap()
        let monthly = app.buttons["event.recurrence.monthly"]
        reveal(monthly, in: app); monthly.tap()
        attachScreenshot("audit-22-editor-large-text", from: app)
        app.buttons["event.save"].tap()
        assertLifePhase(in: app)
        app.buttons["settings.button"].tap()
        let about = element("settings.about", in: app)
        reveal(about, in: app); about.tap()
        reveal(element("about.privacy", in: app), in: app)
        attachScreenshot("audit-23-privacy-large-text", from: app)
    }

    func testCalibrationSheetsSupportLargestText() throws {
        let app = launch(arguments: ["-uiTestingOpenSettings", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let birthday = element("settings.birthday", in: app)
        reveal(birthday, in: app); birthday.tap()
        XCTAssertTrue(app.buttons["settings.birthday.apply"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.birthday.apply"].isHittable)
        attachScreenshot("audit-24-birthday-large-text", from: app)
        app.buttons["settings.birthday.apply"].tap()
        let age = element("settings.targetAge", in: app)
        reveal(age, in: app); age.tap()
        XCTAssertTrue(app.buttons["settings.age.apply"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.age.apply"].isHittable)
        attachScreenshot("audit-25-lifespan-large-text", from: app)
        app.buttons["settings.age.apply"].tap()
        let close = app.buttons["settings.close"]
        reveal(close, in: app, upwards: false); close.tap()
        assertLifePhase(in: app)
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
        for _ in 0..<24 {
            let visible = app.frame.insetBy(dx: 0, dy: 100)
            if element.isHittable && visible.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) { break }
            let surface = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable && $0.frame.height > 200 }) ?? app
            let gap = element.frame.midY - visible.midY
            let height = max(1, surface.frame.height)
            let distance = min(0.6, max(0.12, abs(gap) * 0.7 / height))
            let movingUp = gap > 0 || (gap == 0 && upwards)
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: movingUp ? 0.75 : 0.25))
            let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: movingUp ? 0.75 - distance : 0.25 + distance))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        XCTAssertTrue(element.isHittable)
    }

    private func assertLifePhase(in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element("life.days", in: app).waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(element("life.remaining", in: app).exists, file: file, line: line)
        XCTAssertEqual(element("life.title", in: app).label, "人生", file: file, line: line)
        XCTAssertTrue(element("life.progress", in: app).exists, file: file, line: line)
        XCTAssertTrue(element("life.birth", in: app).exists, file: file, line: line)
        XCTAssertTrue(element("life.basis", in: app).exists, file: file, line: line)
        XCTAssertFalse(app.buttons["life.flip.control"].exists, file: file, line: line)
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
        XCTAssertEqual(XCTWaiter.wait(for: [change], timeout: 5), .completed)
    }

    private func attachScreenshot(_ name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
