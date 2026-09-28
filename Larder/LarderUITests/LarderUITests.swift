//
//  LarderUITests.swift
//  LarderUITests
//
//  Created by Joshua Samuel on 9/20/26.
//

import XCTest

/// Opens each main screen with seeded data and runs Xcode's accessibility
/// audit on it (contrast, labels, text that clips at big sizes, small tap
/// targets), plus a quick walk through the tabs.
final class LarderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private let seeded = ["-hasCompletedOnboarding", "YES", "-seedDemo", "YES", "-forcePlus", "YES",
                          "-chatEngine", "offline"]

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = seeded + extra
        app.launch()
        return app
    }

    /// Runs the audit and reports every issue it finds, not just the first.
    private func audit(_ app: XCUIApplication, _ screen: String, file: StaticString = #filePath, line: UInt = #line) throws {
        // Give the look splash and any entrance animation time to settle.
        sleep(3)
        var issues: [String] = []
        try app.performAccessibilityAudit { issue in
            let element = issue.element.map { "\($0.elementType) '\($0.label)'" } ?? "screen"
            issues.append("\(issue.auditType): \(issue.compactDescription) on \(element)")
            return true
        }
        if !issues.isEmpty {
            XCTFail("\(screen): \(issues.count) accessibility issue(s)\n" + issues.joined(separator: "\n"),
                    file: file, line: line)
        }
    }

    func testHomeAudit() throws { try audit(launch(["-tab", "home"]), "Home") }
    func testPantryAudit() throws { try audit(launch(["-tab", "pantry"]), "Pantry") }
    func testShoppingListAudit() throws {
        try audit(launch(["-tab", "pantry", "-pantryMode", "shopping", "-seedShopping", "YES"]), "Shopping list")
    }
    func testRecipesAudit() throws { try audit(launch(["-tab", "recipes"]), "Recipes") }
    func testRecipeDetailAudit() throws {
        try audit(launch(["-tab", "recipes", "-openRecipe", "egg-fried-rice"]), "Recipe detail")
    }
    func testInsightsAudit() throws { try audit(launch(["-tab", "insights"]), "Insights") }
    func testNutmegChatAudit() throws {
        try audit(launch(["-tab", "nutmeg", "-chatAsk", "What can I make tonight?"]), "Nutmeg chat")
    }
    func testSettingsAudit() throws { try audit(launch(["-openSettings", "YES"]), "Settings") }
    func testGoalSettingsAudit() throws {
        try audit(launch(["-openSettings", "YES", "-openGoalSettings", "YES", "-goal", "buildMuscle"]), "Your goal")
    }
    func testCookModeAudit() throws {
        try audit(launch(["-cookRecipe", "egg-fried-rice", "-cookPhase", "1"]), "Cook Mode")
    }
    func testWelcomeAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO", "-onboardingStep", "welcome"]
        app.launch()
        try audit(app, "Welcome")
    }
    func testPaywallAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO", "-onboardingStep", "paywall", "-forcePlus", "NO"]
        app.launch()
        try audit(app, "Paywall")
    }

    /// Every tab opens and shows something.
    func testEveryTabOpens() throws {
        let app = launch([])
        for tab in ["Pantry", "Recipes", "Insights", "Nutmeg", "Home"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(tab) tab is missing")
            button.tap()
            XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 5), "\(tab) shows nothing")
        }
    }
}
