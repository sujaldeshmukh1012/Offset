import XCTest

final class OffsetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing-reset-state"]
            app.launch()
        }
    }

    @MainActor
    func testAccessibilityContentSizeKeepsOnboardingUsable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset-state",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()
        let homeowner = app.buttons["onboarding.home.homeowner"]
        XCTAssertTrue(homeowner.waitForExistence(timeout: 5))
        XCTAssertEqual(homeowner.value as? String, "Not selected")
        let onboardingScrollView = app.scrollViews.firstMatch
        for _ in 0..<3 where !homeowner.isHittable {
            onboardingScrollView.swipeUp()
        }
        XCTAssertTrue(homeowner.isHittable)
    }

    @MainActor
    func testCompletesAndEditsOnboarding() throws {
        let app = completeOnboarding()

        XCTAssertTrue(app.navigationBars["Calculate"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Estimate your project cost"].exists)
        app.buttons["Solar panels"].tap()
        let priceField = app.textFields["pricer.price"]
        priceField.tap()
        priceField.typeText("12000")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["pricer.calculate"].tap()
        dismissNotificationPrimerIfNeeded(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["pricer.results"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.zip"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["settings.utility"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.projects"].exists)

        app.buttons["Edit profile"].tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testHomeDiscoversBeforeRequestingAQuote() throws {
        let app = completeOnboarding(openPricer: false)

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.summary"].exists)
        let solar = app.descendants(matching: .any)["home.opportunity.solar"]
        XCTAssertTrue(solar.waitForExistence(timeout: 3))
        solar.tap()

        XCTAssertTrue(app.navigationBars["Solar panels"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["What Offset found"].exists)
        XCTAssertTrue(app.staticTexts["Refine your match"].exists)
        XCTAssertFalse(app.textFields["pricer.price"].exists)
    }

    @MainActor
    func testSavesEditsChecksAndDeletesProject() throws {
        let app = completeOnboarding()

        let priceField = app.textFields["pricer.price"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 3))
        priceField.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            priceField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        priceField.typeText("12000")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["pricer.calculate"].tap()
        dismissNotificationPrimerIfNeeded(in: app)

        XCTAssertTrue(app.buttons["pricer.save-project"].waitForExistence(timeout: 3))
        app.buttons["pricer.save-project"].tap()
        XCTAssertTrue(app.navigationBars["Save project"].waitForExistence(timeout: 2))
        app.buttons["Save"].tap()

        let savedRow = app.buttons["saved-project-row"]
        XCTAssertTrue(savedRow.waitForExistence(timeout: 3))
        savedRow.tap()
        XCTAssertTrue(app.navigationBars["Heat pump"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No active matches"].exists)
        XCTAssertTrue(app.staticTexts["Other programs"].exists)

        app.buttons["program-history-row"].tap()
        XCTAssertTrue(app.navigationBars["Program details"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Amount"].exists)
        XCTAssertTrue(app.staticTexts["Eligibility"].exists)
        XCTAssertTrue(app.staticTexts["How to claim"].exists)
        XCTAssertTrue(app.staticTexts["Program record"].exists)
        XCTAssertTrue(app.buttons["Open official source"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Open claim checklist"].tap()
        XCTAssertTrue(app.navigationBars["Claim checklist"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No active claim steps are available for this project right now."].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["saved-project.menu"].tap()
        app.buttons["Edit project"].tap()
        let nameField = app.textFields["saved-project.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("Main heat pump")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Main heat pump"].waitForExistence(timeout: 2))

        app.buttons["saved-project.menu"].tap()
        app.buttons["Delete project"].tap()
        app.buttons["Delete project"].tap()
        XCTAssertTrue(app.navigationBars["Calculate"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["saved-project-row"].exists)
    }

    @MainActor
    func testCleanInstallProductionPricingJourneyWithReducedMotion() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset-state",
            "-ui-testing-premium",
            "-UIAccessibilityIsReduceMotionEnabled", "YES"
        ]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()
        app.buttons["onboarding.home.homeowner"].tap()
        continueButton.tap()

        let zipField = app.textFields["ZIP code"]
        XCTAssertTrue(zipField.waitForExistence(timeout: 5))
        if !app.keyboards.firstMatch.waitForExistence(timeout: 1) {
            zipField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        zipField.typeText("10001")
        XCTAssertTrue(app.staticTexts["State found: NY"].waitForExistence(timeout: 10))
        dismissKeyboardIfNeeded(in: app)
        continueButton.tap()
        selectUtility("con-edison", in: app)
        continueButton.tap()
        let solar = app.buttons["Solar panels"]
        XCTAssertTrue(solar.waitForExistence(timeout: 3))
        solar.tap()
        continueButton.tap()

        openProjectPricer(in: app)
        XCTAssertTrue(app.navigationBars["Calculate"].waitForExistence(timeout: 3))
        let priceField = app.textFields["pricer.price"]
        priceField.tap()
        priceField.typeText("12000")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["pricer.calculate"].tap()
        XCTAssertTrue(app.staticTexts["Keep every savings deadline in view"].waitForExistence(timeout: 3))
        dismissNotificationPrimerIfNeeded(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["pricer.results"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["How the total works"].exists)
        let programName = app.staticTexts["New York Solar Energy System Equipment Credit"]
        XCTAssertTrue(programName.exists)
        XCTAssertTrue(app.staticTexts["$9,000"].exists)

        programName.tap()
        XCTAssertTrue(app.navigationBars["Program details"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["How to claim"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["pricer.save-project"].tap()
        XCTAssertTrue(app.navigationBars["Save project"].waitForExistence(timeout: 2))
        app.buttons["Save"].tap()
        app.buttons["saved-project-row"].tap()
        XCTAssertTrue(app.navigationBars["Solar panels"].waitForExistence(timeout: 2))

        app.buttons["Open claim checklist"].tap()
        XCTAssertTrue(app.navigationBars["Claim checklist"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1. New York Solar Energy System Equipment Credit"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["settings.zip"].exists)
    }

    @MainActor
    func testNewYorkOrangeRocklandHeatPumpWaterHeaterJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-state", "-ui-testing-premium"]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()
        app.buttons["onboarding.home.homeowner"].tap()
        continueButton.tap()

        let zipField = app.textFields["ZIP code"]
        XCTAssertTrue(zipField.waitForExistence(timeout: 3))
        zipField.tap()
        zipField.typeText("10901")
        XCTAssertTrue(app.staticTexts["State found: NY"].waitForExistence(timeout: 10))
        dismissKeyboardIfNeeded(in: app)
        continueButton.tap()
        selectUtility("orange-rockland", in: app)
        continueButton.tap()
        let waterHeater = app.buttons["Heat pump water heater"]
        XCTAssertTrue(waterHeater.waitForExistence(timeout: 3))
        waterHeater.tap()
        continueButton.tap()

        openProjectPricer(in: app)
        XCTAssertTrue(app.navigationBars["Calculate"].waitForExistence(timeout: 3))
        let priceField = app.textFields["pricer.price"]
        priceField.tap()
        priceField.typeText("2500")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["pricer.calculate"].tap()
        dismissNotificationPrimerIfNeeded(in: app)

        XCTAssertTrue(app.staticTexts["Orange & Rockland NYS Clean Heat Incentives"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["−$1,250"].exists)
        XCTAssertTrue(app.staticTexts["$1,250"].exists)
    }

    @MainActor
    func testFreeMatchedResultOpensPaywallAndPurchaseUnlocks() throws {
        let app = completeOnboarding(launchArguments: ["-ui-testing-reset-state"])
        calculateNewYorkSolar(in: app)

        XCTAssertTrue(app.buttons["pricer.unlock"].waitForExistence(timeout: 3))
        let programName = app.staticTexts["New York Solar Energy System Equipment Credit"]
        XCTAssertTrue(programName.exists)
        XCTAssertTrue(app.staticTexts["$9,000"].exists)
        XCTAssertTrue(app.staticTexts["−$3,000"].exists)
        programName.tap()
        let paywall = app.navigationBars["Offset Premium"]
        XCTAssertTrue(paywall.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["paywall.annual"].exists)
        XCTAssertTrue(app.buttons["paywall.monthly"].exists)
        XCTAssertTrue(app.buttons["paywall.redeem-offer-code"].exists)
        app.buttons["paywall.monthly"].tap()
        XCTAssertTrue(app.navigationBars["Offset Premium"].exists)
        XCTAssertEqual(app.buttons["paywall.monthly"].value as? String, "Selected")
        app.buttons["paywall.continue"].tap()

        XCTAssertTrue(programName.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["$9,000"].exists)
        if paywall.exists {
            app.buttons["Close"].tap()
        }
        XCTAssertTrue(paywall.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["pricer.unlock"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testPremiumTabPurchasesAndDisappearsAfterUnlock() throws {
        let app = completeOnboarding(openPricer: false)

        let premiumTab = app.tabBars.buttons["Premium"]
        XCTAssertTrue(premiumTab.waitForExistence(timeout: 3))
        premiumTab.tap()
        XCTAssertTrue(app.navigationBars["Offset Premium"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["paywall.continue"].isEnabled)
        app.buttons["paywall.continue"].tap()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 3))
        XCTAssertTrue(premiumTab.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testCapturePaywallReviewScreenshot() throws {
        let app = completeOnboarding(launchArguments: ["-ui-testing-reset-state", "-ui-testing-monetization"])
        calculateNewYorkSolar(in: app)

        let unlock = app.buttons["pricer.unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 3))
        unlock.tap()
        XCTAssertTrue(app.navigationBars["Offset Premium"].waitForExistence(timeout: 2))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Offset-Premium-Review"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCaptureStorefrontScreenshots() throws {
        let app = completeOnboarding(launchArguments: [
            "-ui-testing-reset-state",
            "-ui-testing-monetization",
            "-UIAccessibilityIsReduceMotionEnabled", "YES"
        ], openPricer: false)

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.summary"].exists)
        captureScreenshot(named: "01-Home-Discovery")

        let solarOpportunity = app.descendants(matching: .any)["home.opportunity.solar"]
        XCTAssertTrue(solarOpportunity.waitForExistence(timeout: 3))
        solarOpportunity.tap()
        XCTAssertTrue(app.navigationBars["Solar panels"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["What Offset found"].exists)
        captureScreenshot(named: "02-Solar-Programs")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        openProjectPricer(in: app)

        XCTAssertTrue(app.navigationBars["Calculate"].waitForExistence(timeout: 3))
        let solar = app.buttons["Solar panels"]
        XCTAssertTrue(solar.waitForExistence(timeout: 3))
        solar.tap()
        captureScreenshot(named: "03-Project-Calculator")

        let priceField = app.textFields["pricer.price"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 2))
        priceField.tap()
        priceField.typeText("12000")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["pricer.calculate"].tap()
        dismissNotificationPrimerIfNeeded(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["pricer.results"].waitForExistence(timeout: 3))
        for _ in 0..<1 {
            app.scrollViews.firstMatch.swipeUp()
        }
        captureScreenshot(named: "04-Savings-Estimate")

        let saveProject = app.buttons["pricer.save-project"]
        scrollToHittable(saveProject, in: app)
        app.buttons["pricer.save-project"].tap()
        XCTAssertTrue(app.navigationBars["Save project"].waitForExistence(timeout: 3))
        app.buttons["Save"].tap()

        let checklistTab = app.tabBars.buttons["Checklist"]
        XCTAssertTrue(checklistTab.waitForExistence(timeout: 3))
        checklistTab.tap()
        XCTAssertTrue(app.navigationBars["Checklist"].waitForExistence(timeout: 3))
        captureScreenshot(named: "05-Claim-Checklist")

        let premiumTab = app.tabBars.buttons["Premium"]
        XCTAssertTrue(premiumTab.waitForExistence(timeout: 3))
        premiumTab.tap()
        XCTAssertTrue(app.navigationBars["Offset Premium"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["paywall.annual"].exists)
        XCTAssertTrue(app.buttons["paywall.monthly"].exists)
        captureScreenshot(named: "06-Offset-Premium")
    }

    @MainActor
    func testPaywallRestoreUnlocksExistingResultWithoutRestart() throws {
        let app = completeOnboarding(launchArguments: ["-ui-testing-reset-state", "-ui-testing-restore-premium"])
        calculateNewYorkSolar(in: app)

        app.buttons["pricer.unlock"].tap()
        XCTAssertTrue(app.navigationBars["Offset Premium"].waitForExistence(timeout: 2))
        app.buttons["paywall.restore"].tap()

        XCTAssertTrue(app.staticTexts["New York Solar Energy System Equipment Credit"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["$9,000"].exists)
    }

    @MainActor
    func testFreeTierSavingProjectOpensPaywall() throws {
        let app = completeOnboarding()
        calculateNewYorkSolar(in: app)

        let saveButton = app.buttons["pricer.save-project"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()
        XCTAssertTrue(app.navigationBars["Offset Premium"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testEligibilityAnswersUnlockExactFPLRebate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-state", "-ui-testing-premium"]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()
        app.buttons["onboarding.home.homeowner"].tap()
        continueButton.tap()

        let zipField = app.textFields["ZIP code"]
        XCTAssertTrue(zipField.waitForExistence(timeout: 3))
        zipField.tap()
        zipField.typeText("33101")
        XCTAssertTrue(app.staticTexts["State found: FL"].waitForExistence(timeout: 10))
        dismissKeyboardIfNeeded(in: app)
        continueButton.tap()
        selectUtility("fpl", in: app)
        continueButton.tap()
        let heatPump = app.buttons["Heat pump"]
        XCTAssertTrue(heatPump.waitForExistence(timeout: 3))
        heatPump.tap()
        continueButton.tap()

        openProjectPricer(in: app)
        XCTAssertTrue(app.navigationBars["Calculate"].waitForExistence(timeout: 3))
        let contractorYes = app.buttons["eligibility.contractor_participating.yes"]
        scrollToHittable(contractorYes, in: app)
        contractorYes.tap()

        let seerField = app.textFields["eligibility.seer2.number"]
        scrollToHittable(seerField, in: app)
        seerField.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            seerField.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        seerField.typeText("16")
        dismissKeyboardIfNeeded(in: app)

        let priceField = app.textFields["pricer.price"]
        scrollToHittable(priceField, in: app)
        priceField.tap()
        priceField.typeText("8000")
        dismissKeyboardIfNeeded(in: app)
        let calculate = app.buttons["pricer.calculate"]
        scrollToHittable(calculate, in: app)
        calculate.tap()
        dismissNotificationPrimerIfNeeded(in: app)

        XCTAssertTrue(app.staticTexts["FPL A/C Rebate"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["$7,800"].exists)
    }

    @MainActor
    private func completeOnboarding(
        launchArguments: [String] = ["-ui-testing-reset-state"],
        openPricer: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        let homeowner = app.buttons["onboarding.home.homeowner"]
        XCTAssertTrue(homeowner.waitForExistence(timeout: 2))
        homeowner.tap()
        continueButton.tap()

        let zipField = app.textFields["ZIP code"]
        XCTAssertTrue(zipField.waitForExistence(timeout: 5))
        if !app.keyboards.firstMatch.waitForExistence(timeout: 1) {
            zipField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        zipField.typeText("10001")
        XCTAssertTrue(app.staticTexts["State found: NY"].waitForExistence(timeout: 10))
        dismissKeyboardIfNeeded(in: app)
        continueButton.tap()

        selectUtility("con-edison", in: app)
        continueButton.tap()

        let heatPump = app.buttons["Heat pump"]
        let solar = app.buttons["Solar panels"]
        XCTAssertTrue(heatPump.waitForExistence(timeout: 3))
        XCTAssertTrue(solar.exists)
        heatPump.tap()
        solar.tap()
        continueButton.tap()
        if openPricer { openProjectPricer(in: app) }
        return app
    }

    @MainActor
    private func openProjectPricer(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        let calculate = app.buttons["home.calculate-project"]
        scrollToHittable(calculate, in: app)
        calculate.tap()
    }

    @MainActor
    private func calculateNewYorkSolar(in app: XCUIApplication) {
        let solar = app.buttons["Solar panels"]
        XCTAssertTrue(solar.waitForExistence(timeout: 3))
        solar.tap()
        let priceField = app.textFields["pricer.price"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 2))
        priceField.tap()
        priceField.typeText("12000")
        dismissKeyboardIfNeeded(in: app)
        app.buttons["pricer.calculate"].tap()
        dismissNotificationPrimerIfNeeded(in: app)
    }

    @MainActor
    private func dismissNotificationPrimerIfNeeded(in app: XCUIApplication) {
        let notNow = app.buttons["notifications.not-now"]
        if notNow.waitForExistence(timeout: 5) {
            XCTAssertTrue(notNow.isHittable)
            notNow.tap()
            XCTAssertTrue(notNow.waitForNonExistence(timeout: 5))
        }
    }

    @MainActor
    private func selectUtility(_ id: String, in app: XCUIApplication) {
        let utility = app.buttons["onboarding.utility.\(id)"]
        XCTAssertTrue(utility.waitForExistence(timeout: 3))
        XCTAssertTrue(utility.isHittable)
        utility.tap()
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"),
            object: utility
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
    }

    @MainActor
    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<8 where !element.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func dismissKeyboardIfNeeded(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }

    @MainActor
    private func captureScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
