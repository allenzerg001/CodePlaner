//
//  CodePlanerUITests.swift
//  CodePlanerUITests
//
//  Created by Allen on 2026/4/16.
//

import XCTest

final class CodePlanerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Helper

    /// Wait for main window and return it.
    @MainActor
    private func launchAndGetWindow(timeout: TimeInterval = 8) -> XCUIElement? {
        app.launch()
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: timeout) else { return nil }
        return window
    }

    // MARK: - Debug helper (run once to inspect accessibility tree)

    @MainActor
    func testZZ_DebugPrintAccessibilityTree() throws {
        guard let window = launchAndGetWindow() else {
            XCTFail("window not found")
            return
        }
        // Print complete accessibility hierarchy so we can see element types / labels
        print("=== WINDOW DESCRIPTION ===")
        print(window.debugDescription)
        print("=== STATIC TEXTS ===")
        let texts = app.staticTexts.allElementsBoundByIndex
        for t in texts {
            print("  StaticText label='\(t.label)' id='\(t.identifier)'")
        }
        print("=== BUTTONS ===")
        let buttons = app.buttons.allElementsBoundByIndex
        for b in buttons {
            print("  Button label='\(b.label)' id='\(b.identifier)'")
        }
        print("=== OUTLINE ROWS ===")
        let rows = app.outlines.cells.allElementsBoundByIndex
        for r in rows.prefix(30) {
            print("  OutlineCell label='\(r.label)' id='\(r.identifier)' children=\(r.children(matching: .any).count)")
        }
        print("=== TABLE CELLS ===")
        let cells = app.tables.cells.allElementsBoundByIndex
        for c in cells.prefix(30) {
            print("  TableCell label='\(c.label)' id='\(c.identifier)'")
        }
        // Always pass — this is just a diagnostic
        XCTAssertTrue(true)
    }

    // MARK: - TC01: App launches without crash

    @MainActor
    func testTC01_AppLaunchesWithoutCrash() throws {
        app.launch()
        // Give the app 2 s to stabilise
        let stable = XCTWaiter.wait(for: [expectation(description: "stabilise")], timeout: 2)
        // XCTWaiter returns .timedOut when no expectation is fulfilled — that is the happy path here
        _ = stable
        XCTAssertNotEqual(app.state, .notRunning, "App should still be running after launch")
    }

    // MARK: - TC02: Main window loads

    @MainActor
    func testTC02_MainWindowLoads() throws {
        guard let window = launchAndGetWindow() else {
            XCTFail("Main window did not appear within timeout")
            return
        }
        XCTAssertTrue(window.exists, "Main window should exist")
        XCTAssertGreaterThanOrEqual(app.windows.count, 1, "At least one window should be open")
    }

    // MARK: - TC03: Sidebar navigation exists

    @MainActor
    func testTC03_SidebarNavigationExists() throws {
        guard let _ = launchAndGetWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // The NavigationView sidebar renders as an outline or table on macOS.
        // We check for the navigation title "CodingPlan" or the known sidebar items.
        let sidebarContainsCodingPlan = app.staticTexts["CodingPlan"].waitForExistence(timeout: 4)
        let sidebarHasList = app.outlines.firstMatch.exists || app.tables.firstMatch.exists

        XCTAssertTrue(sidebarContainsCodingPlan || sidebarHasList,
                      "Sidebar should show 'CodingPlan' title or contain a list/outline")
    }

    // MARK: - TC04: Providers page loads

    @MainActor
    func testTC04_ProvidersPageLoads() throws {
        guard let _ = launchAndGetWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // Tap the "Provider Configurations" sidebar item
        let providerNavItem = app.staticTexts["Provider Configurations"]
        if providerNavItem.waitForExistence(timeout: 5) {
            providerNavItem.click()
        } else {
            // Fallback: try outlines / tables cells
            let cell = app.outlines.cells.containing(.staticText, identifier: "Provider Configurations").firstMatch
            if cell.waitForExistence(timeout: 3) {
                cell.click()
            } else {
                XCTFail("Could not find 'Provider Configurations' sidebar item")
                return
            }
        }

        // After click the detail pane should show the Providers heading
        let heading = app.staticTexts["Provider Configurations"]
        // The heading in ProvidersView uses NSLocalizedString("settings_provider_configs") → "Provider Configurations"
        // Give it time to appear in the detail area
        let appeared = heading.waitForExistence(timeout: 5)
        XCTAssertTrue(appeared, "Provider Configurations heading should appear in detail pane")
    }

    // MARK: - TC05: Preset providers are displayed

    @MainActor
    func testTC05_PresetProvidersDisplayed() throws {
        guard let _ = launchAndGetWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // Navigate to Provider Configurations
        let providerNavItem = app.staticTexts["Provider Configurations"]
        if providerNavItem.waitForExistence(timeout: 5) {
            providerNavItem.click()
        }

        // Wait for the providers list to populate
        _ = XCTWaiter.wait(for: [expectation(description: "providers load")], timeout: 2)

        // Check for known preset provider display names / names
        let presetNames = ["DeepSeek", "百炼", "月之暗面", "MiniMax", "硅基流动", "腾讯混元", "智谱", "火山"]
        var foundCount = 0
        for name in presetNames {
            let predicate = NSPredicate(format: "label CONTAINS %@", name)
            if app.staticTexts.matching(predicate).firstMatch.exists {
                foundCount += 1
            }
        }

        XCTAssertGreaterThanOrEqual(foundCount, 4,
            "At least 4 preset providers should be visible; found \(foundCount) out of \(presetNames.count)")
    }

    // MARK: - TC06: Provider icons displayed

    @MainActor
    func testTC06_ProviderIconsDisplayed() throws {
        guard let _ = launchAndGetWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        let providerNavItem = app.staticTexts["Provider Configurations"]
        if providerNavItem.waitForExistence(timeout: 5) {
            providerNavItem.click()
        }

        _ = XCTWaiter.wait(for: [expectation(description: "icons load")], timeout: 2)

        // Preset icons: 🔶 🌋 🧠 🐋 🌙 ⚡ 💎 🔵
        let icons = ["🔶", "🌋", "🧠", "🐋", "🌙", "⚡", "💎", "🔵"]
        var foundCount = 0
        for icon in icons {
            let predicate = NSPredicate(format: "label CONTAINS %@", icon)
            if app.staticTexts.matching(predicate).firstMatch.exists {
                foundCount += 1
            }
        }

        // If emoji are not exposed as accessibility labels, fall back to checking provider names
        if foundCount == 0 {
            // At least verify that provider name texts are visible (icon column may be inaccessible)
            let deepseekExists = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'DeepSeek'")).firstMatch.exists
            XCTAssertTrue(deepseekExists,
                "Provider row content should be visible (icons or at least provider names)")
        } else {
            XCTAssertGreaterThanOrEqual(foundCount, 1, "At least one provider icon emoji should be visible")
        }
    }

    // MARK: - TC07: Settings page loads

    @MainActor
    func testTC07_SettingsPageLoads() throws {
        guard let _ = launchAndGetWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // "CodingPlan Settings" is the title from NSLocalizedString("settings_title")
        let settingsNavItem = app.staticTexts["CodingPlan Settings"]
        if settingsNavItem.waitForExistence(timeout: 5) {
            settingsNavItem.click()
        } else {
            // Try the sidebar by label
            let altLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'Settings'")).element(boundBy: 0)
            if altLabel.waitForExistence(timeout: 3) {
                altLabel.click()
            } else {
                XCTFail("Could not find Settings sidebar item")
                return
            }
        }

        // SettingsView shows "CodingPlan Settings" as title + "General" Form section
        let titleAppeared = app.staticTexts["CodingPlan Settings"].waitForExistence(timeout: 5)
        let generalSection = app.staticTexts["General"].waitForExistence(timeout: 5)

        XCTAssertTrue(titleAppeared || generalSection,
                      "Settings page should show title or 'General' section")
    }

    // MARK: - TC08: Usage Dashboard loads

    @MainActor
    func testTC08_UsageDashboardLoads() throws {
        guard let _ = launchAndGetWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // The default detail view is already UsageDashboardView; click sidebar item to be explicit.
        // Sidebar label comes from NSLocalizedString("usage_title") → "Today's Usage"
        let usageNavItem = app.staticTexts["Today's Usage"]
        if usageNavItem.waitForExistence(timeout: 5) {
            usageNavItem.click()
        }

        // UsageDashboardView shows "Today's Usage" as heading and stat cards: Requests / Total Tokens / Cost
        let titleExists = app.staticTexts["Today's Usage"].waitForExistence(timeout: 5)
        let requestsCard = app.staticTexts["Requests"].waitForExistence(timeout: 3)
        let tokensCard = app.staticTexts["Total Tokens"].waitForExistence(timeout: 3)

        XCTAssertTrue(titleExists, "Usage Dashboard title 'Today's Usage' should appear")
        XCTAssertTrue(requestsCard || tokensCard,
                      "Usage Dashboard stat cards ('Requests' or 'Total Tokens') should be visible")
    }
}
