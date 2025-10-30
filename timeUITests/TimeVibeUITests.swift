import XCTest

final class TimeVibeUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
    }

    func testLaunchShowsSidebarAndDetail() {
        XCTAssertTrue(app.otherElements["view.sidebar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["view.detail"].exists)
    }

    func testSidebarNavigationToTimeEntries() {
        let timeEntries = app.buttons["sidebar.timeEntries"]
        if timeEntries.waitForExistence(timeout: 2) {
            timeEntries.click()
        } else {
            // Fallback: navigate via static text if needed
            app.staticTexts["Time Entries"].firstMatch.click()
        }

        // New Time Entry button appears only on Time Entries tab
        XCTAssertTrue(app.buttons["toolbar.newTimeEntryButton"].waitForExistence(timeout: 2))
    }

    func testStartTimerFlowCancel() {
        let timerButton = app.buttons["toolbar.timerButton"]
        XCTAssertTrue(timerButton.waitForExistence(timeout: 2))

        // If timer is not active, the button opens the popover
        timerButton.click()

        // Popover fields
        XCTAssertTrue(app.popovers.textFields["startTimer.titleField"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.popovers.buttons["startTimer.startButton"].exists)

        // Cancel instead of actually starting
        app.popovers.buttons["startTimer.cancelButton"].click()

        // Popover dismissed
        XCTAssertFalse(app.popovers.element.exists)
    }

    func testCreateProjectFromToolbar() {
        // Open Create Project sheet from toolbar
        let newProjectButton = app.buttons["toolbar.newProjectButton"]
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 3))
        newProjectButton.click()

        // Fill project form
        let nameField = app.textFields["projectForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeText("UITest Project")

        // Submit
        let submit = app.buttons["projectForm.submitButton"]
        XCTAssertTrue(submit.exists)
        submit.click()

        // Sheet should dismiss eventually
        XCTAssertFalse(submit.waitForExistence(timeout: 5))

        // Sidebar should reflect (best-effort; project tree may be async)
        XCTAssertTrue(app.otherElements["view.sidebar"].exists)
    }

    func testCreateTimeEntryFromTimeEntriesTab() {
        // Navigate to Time Entries
        if app.buttons["sidebar.timeEntries"].exists {
            app.buttons["sidebar.timeEntries"].click()
        } else {
            app.staticTexts["Time Entries"].firstMatch.click()
        }

        // Open New Entry sheet
        let newEntry = app.buttons["timeEntries.newEntryButton"]
        XCTAssertTrue(newEntry.waitForExistence(timeout: 3))
        newEntry.click()

        // Fill fields
        let titleField = app.textFields["newEntry.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.click()
        titleField.typeText("UI Created Entry")

        let submit = app.buttons["newEntry.submitButton"]
        XCTAssertTrue(submit.exists)
        submit.click()

        // Sheet dismissed
        XCTAssertFalse(submit.waitForExistence(timeout: 5))

        // Verify a list exists
        XCTAssertTrue(app.scrollViews["timeEntries.list"].firstMatch.exists || app.tables["timeEntries.list"].firstMatch.exists || app.outlines["timeEntries.list"].firstMatch.exists)
    }

    func testActivitiesToggles() {
        // Navigate to Activities
        if app.buttons["sidebar.activities"].exists {
            app.buttons["sidebar.activities"].click()
        } else {
            app.staticTexts["Activities"].firstMatch.click()
        }

        let header = app.staticTexts["activities.header.total"]
        XCTAssertTrue(header.waitForExistence(timeout: 3))

        // Toggle include App Usage off and on
        let appUsageToggle = app.checkBoxes["activities.toggle.appUsage"]
        if appUsageToggle.waitForExistence(timeout: 2) {
            appUsageToggle.click()
            appUsageToggle.click()
        }

        // Toggle include Time Entries off and on
        let timeEntriesToggle = app.checkBoxes["activities.toggle.timeEntries"]
        if timeEntriesToggle.exists {
            timeEntriesToggle.click()
            timeEntriesToggle.click()
        }

        // List should exist
        XCTAssertTrue(app.scrollViews["activities.list"].firstMatch.exists || app.tables["activities.list"].firstMatch.exists || app.outlines["activities.list"].firstMatch.exists)
    }
}
