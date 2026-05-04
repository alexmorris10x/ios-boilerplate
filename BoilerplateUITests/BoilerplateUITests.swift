import XCTest

final class BoilerplateUITests: XCTestCase {
    func testFirstRunShowsOnboardingThenLogin() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-useMockData")
        app.launchArguments.append("-resetOnboarding")
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Boilerplate"].waitForExistence(timeout: 5))

        app.buttons["Get Started"].tap()

        XCTAssertTrue(app.staticTexts["Welcome Back"].waitForExistence(timeout: 5))
    }
}
