import XCTest

final class FlowTests: XCTestCase {
    func testLeParcoursDuJour() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-polarUITest"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Moments"].waitForExistence(timeout: 8))
        let dayCard = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bilan du jour")).firstMatch
        XCTAssertTrue(dayCard.exists)
        XCTAssertTrue(app.buttons["Ça ne va pas"].exists)

        dayCard.tap()
        XCTAssertTrue(app.staticTexts["Sommeil"].waitForExistence(timeout: 4), "bilan frame=\(dayCard.frame)")
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.staticTexts["Moments"].waitForExistence(timeout: 4))

        let plus = app.buttons["Nouveau moment"]
        plus.press(forDuration: 0.05)
        XCTAssertTrue(
            app.staticTexts["Qu'est-ce que tu ressens ?"].waitForExistence(timeout: 4),
            "hittable=\(plus.isHittable) frame=\(plus.frame)"
        )
        let calm = app.buttons["Calme"]
        XCTAssertTrue(calm.waitForExistence(timeout: 4))
        calm.tap()
        app.buttons["Suivant"].tap()

        let thought = app.textFields["Qu'est-ce qui te passe par la tête ?"]
        XCTAssertTrue(thought.waitForExistence(timeout: 4))
        thought.tap()
        thought.typeText("ça va")
        tapIfNeeded(app.buttons["Suivant"])

        app.buttons["Sortir marcher"].tap()
        tapIfNeeded(app.buttons["Terminé"])

        let noted = app.staticTexts["C'est noté."]
        XCTAssertTrue(noted.waitForExistence(timeout: 4) || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Calme")).firstMatch.exists)

        dayCard.tap()
        XCTAssertTrue(app.staticTexts["Sommeil"].waitForExistence(timeout: 4))
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.staticTexts["Moments"].waitForExistence(timeout: 4))

        app.tabBars.buttons["Calendrier"].tap()
        XCTAssertTrue(app.staticTexts["septembre 2026"].waitForExistence(timeout: 4))

        app.tabBars.buttons["Tendances"].tap()
        XCTAssertTrue(app.staticTexts["Tendances"].waitForExistence(timeout: 4))
        app.swipeUp()
        XCTAssertTrue(app.buttons["Résumé de la semaine"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Rapport PDF du mois"].exists)
        app.buttons["Résumé de la semaine"].tap()

        app.tabBars.buttons["Aujourd'hui"].tap()
        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 4))
        app.swipeUp()
        app.buttons["Mon plan"].tap()
        XCTAssertTrue(app.staticTexts["Aucun seuil n'est fixé tant que tu ne l'écris pas avec ta psy."].waitForExistence(timeout: 4))
        app.navigationBars.buttons.firstMatch.tap()
        app.swipeDown()

        app.buttons["Ça ne va pas"].tap()
        XCTAssertTrue(app.links["3114, prévention du suicide, 24 h/24"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.links["15, urgence médicale"].exists)
    }

    private func tapIfNeeded(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
