import XCTest

/// Un test par parcours de la section 12, plus Retour, Terminé, Ça ne va pas et l'audit.
final class FlowTests: XCTestCase {
    func testFaireLeBilan() {
        let app = launch()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bilan du jour")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Sommeil"].waitForExistence(timeout: 4))
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.staticTexts["Moments"].waitForExistence(timeout: 4))
    }

    func testNoterUnMoment() {
        let app = launch()
        noter(app).tap()
        XCTAssertTrue(app.staticTexts["Émotion"].waitForExistence(timeout: 4))
        app.buttons["Calme"].tap()
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.staticTexts["Moments"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.tabBars.buttons["Aujourd'hui"].isSelected)
    }

    func testRelireHistoriquePuisRetour() {
        let app = launch()
        app.tabBars.buttons["Historique"].tap()
        XCTAssertTrue(app.staticTexts["Tes journées apparaîtront ici."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Faire le bilan"].exists)
        app.buttons["Pour ma psy"].tap()
        XCTAssertTrue(app.staticTexts["Rien à montrer pour l'instant."].waitForExistence(timeout: 4))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Pour ma psy"].waitForExistence(timeout: 4))
    }

    func testPreparerLaSeance() {
        let app = launch()
        app.tabBars.buttons["Historique"].tap()
        app.buttons["Pour ma psy"].tap()
        XCTAssertTrue(app.staticTexts["Pour ma psy"].waitForExistence(timeout: 4))
        let montrer = app.buttons["Montrer"]
        if montrer.waitForExistence(timeout: 2) {
            montrer.tap()
            XCTAssertTrue(app.buttons["Terminé"].waitForExistence(timeout: 4))
            app.buttons["Terminé"].tap()
        } else {
            XCTAssertTrue(app.staticTexts["Rien à montrer pour l'instant."].exists)
            XCTAssertTrue(app.textFields["Ajouter une question"].exists)
        }
    }

    func testAppelerQuandCaNeVaPas() {
        let app = launch()
        for tab in ["Aujourd'hui", "Historique", "Mon plan"] {
            app.tabBars.buttons[tab].tap()
            if tab != "Mon plan" {
                app.tabBars.buttons["Mon plan"].tap()
            }
            XCTAssertTrue(app.links["3114"].waitForExistence(timeout: 4))
            XCTAssertTrue(app.links["15"].exists)
        }
        app.buttons["Ça ne va pas"].tap()
        XCTAssertTrue(app.navigationBars["Ça ne va pas"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.links["3114"].exists)
    }

    func testAjouterUnTraitement() {
        let app = launch()
        app.tabBars.buttons["Mon plan"].tap()
        app.buttons["Ajouter"].tap()
        app.buttons["Traitement"].tap()
        let name = app.textFields["Nom"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["Terminé"].isEnabled)
        name.tap()
        name.typeText("Lithium")
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.buttons["Lithium"].waitForExistence(timeout: 4))
    }

    func testEcrireUnSignal() {
        let app = launch()
        app.tabBars.buttons["Mon plan"].tap()
        app.buttons["Ajouter un signal"].tap()
        XCTAssertTrue(app.staticTexts["Choisis une phrase"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["Terminé"].isEnabled)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Si je dors moins")).firstMatch.tap()
        let hours = app.textFields["Heures"]
        let nights = app.textFields["Nombre"]
        XCTAssertTrue(hours.waitForExistence(timeout: 4))
        hours.tap()
        hours.typeText("5")
        nights.tap()
        nights.typeText("3")
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.staticTexts["Si je dors moins de 5 h pendant 3 nuits"].waitForExistence(timeout: 4))
    }

    func testChangerLHeureDuRappel() {
        let app = launch()
        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Bilan du jour"].exists)
        XCTAssertTrue(app.staticTexts["Point de la semaine"].exists)
        XCTAssertTrue(app.staticTexts["Confidentialité"].exists)
        XCTAssertTrue(app.staticTexts["Santé et données"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Affichage"].exists)
        XCTAssertTrue(app.staticTexts["À propos"].exists)
        XCTAssertTrue(app.datePickers["Rappel du soir"].exists || app.buttons["Rappel du soir"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Moments"].waitForExistence(timeout: 4))
    }

    func testCaNeVaPasEnModeDiscretEtEnPause() {
        let app = launch()
        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 4))
        app.swipeUp()
        app.swipeUp()
        let discreet = app.switches["Mode discret"]
        let pause = app.switches["Pause du suivi"]
        XCTAssertTrue(discreet.waitForExistence(timeout: 4))
        discreet.tap()
        pause.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Mon plan"].tap()
        XCTAssertTrue(app.links["3114"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.links["15"].exists)
    }

    func testAccessibiliteAujourdhui() throws {
        let app = launch()
        try app.performAccessibilityAudit()
    }

    func testAccessibiliteHistorique() throws {
        let app = launch()
        app.tabBars.buttons["Historique"].tap()
        XCTAssertTrue(app.buttons["Pour ma psy"].waitForExistence(timeout: 4))
        try app.performAccessibilityAudit()
    }

    func testAccessibiliteMonPlan() throws {
        let app = launch()
        app.tabBars.buttons["Mon plan"].tap()
        XCTAssertTrue(app.buttons["Ça ne va pas"].waitForExistence(timeout: 4))
        try app.performAccessibilityAudit()
    }

    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-polarUITest"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Moments"].waitForExistence(timeout: 8))
        return app
    }

    private func noter(_ app: XCUIApplication) -> XCUIElement {
        let named = app.tabBars.buttons["Noter un moment"]
        let plain = app.tabBars.buttons["Noter"]
        XCTAssertTrue(named.waitForExistence(timeout: 4) || plain.waitForExistence(timeout: 2))
        return named.exists ? named : plain
    }
}
