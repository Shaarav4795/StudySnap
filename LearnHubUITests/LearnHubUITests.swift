// UI test scaffold for LearnHub flows.

import XCTest

final class LearnHubUITests: XCTestCase {

    override func setUpWithError() throws {
        // Stop immediately on failure to reduce cascading errors.
        continueAfterFailure = false

        // Configure the initial UI state (orientation, permissions, seed data) here.
    }

    override func tearDownWithError() throws {
        // Reset any state that could affect subsequent tests.
    }

    @MainActor
    func testExample() throws {
        // Launch the app under test.
        let app = XCUIApplication()
        app.launch()

        // Add assertions that validate expected UI behavior.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Measure cold-start launch performance.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
