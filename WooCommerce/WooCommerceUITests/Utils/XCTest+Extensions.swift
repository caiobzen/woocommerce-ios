import XCTest

var isIPhone: Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}

var isIpad: Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

var isDarkMode: Bool {
    return UIViewController().traitCollection.userInterfaceStyle == .dark
}

let navBackButton = XCUIApplication().navigationBars.element(boundBy: 0).buttons.element(boundBy: 0)

extension XCUIElement {
    /**
     Removes any current text in the field
     */
    func clearTextIfNeeded() -> Void {
        let app = XCUIApplication()

        self.press(forDuration: 1.2)
        app.keys["delete"].tap()
    }

    /**
     Removes any current text in the field before typing in the new value
     - Parameter text: the text to enter into the field
     */
    func clearAndEnterText(text: String) -> Void {
        clearTextIfNeeded()
        self.tap()
        self.typeText(text)
    }

    var stringValue: String? {
        return self.value as? String
    }
}

extension XCTestCase {

//    public func setUpTestSuite() {
//        super.setUp()
//
//        // In UI tests it is usually best to stop immediately when a failure occurs.
//        continueAfterFailure = false
//
//        let app = XCUIApplication()
//        app.activate()
//
//        // Media permissions alert handler
//        systemAlertHandler(alertTitle: "“WordPress” Would Like to Access Your Photos", alertButton: "OK")
//    }

    public func takeScreenshotOfFailedTest() {
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            XCTContext.runActivity(named: "Take a screenshot at the end of a failed test") { (activity) in
                add(XCTAttachment(screenshot: XCUIApplication().windows.firstMatch.screenshot()))
            }
        }
    }

    public func systemAlertHandler(alertTitle: String, alertButton: String) {
        addUIInterruptionMonitor(withDescription: alertTitle) { (alert) -> Bool in
            let alertButtonElement = alert.buttons[alertButton]
            XCTAssert(alertButtonElement.waitForExistence(timeout: 5))
            alertButtonElement.tap()
            return true
        }
    }

    public func waitForElementToNotExist(element: XCUIElement, timeout: TimeInterval? = nil) {
        let notExistsPredicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: notExistsPredicate,
                                                    object: element)

        let timeoutValue = timeout ?? 30
        guard XCTWaiter().wait(for: [expectation], timeout: timeoutValue) == .completed else {
            XCTFail("\(element) still exists after \(timeoutValue) seconds.")
            return
        }
    }

    public func getRandomPhrase() -> String {
        var wordArray: [String] = []
        let phraseLength = Int.random(in: 3...6)
        for _ in 1...phraseLength {
            wordArray.append(DataHelper.words.randomElement()!)
        }
        let phrase = wordArray.joined(separator: " ")

        return phrase
    }

    public func getRandomContent() -> String {
        var sentenceArray: [String] = []
        let paraLength = Int.random(in: 1...DataHelper.sentences.count)
        for _ in 1...paraLength {
            sentenceArray.append(DataHelper.sentences.randomElement()!)
        }
        let paragraph = sentenceArray.joined(separator: " ")

        return paragraph
    }

    public func getCategory() -> String {
        return "Wedding"
    }

    public func getTag() -> String {
        return "tag"
    }

    public struct DataHelper {
        static let words = ["Lorem", "Ipsum", "Dolor", "Sit", "Amet", "Consectetur", "Adipiscing", "Elit"]
        static let sentences = [
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "Nam ornare accumsan ante, sollicitudin bibendum erat bibendum nec.",
            "Nam congue efficitur leo eget porta.",
            "Proin dictum non ligula aliquam varius.",
            "Aenean vehicula nunc in sapien rutrum, nec vehicula enim iaculis."
        ]
        static let category = "iOS Test"
        static let tag = "tag"
    }

    public func elementIsFullyVisibleOnScreen(element: XCUIElement) -> Bool {
        guard element.exists && !element.frame.isEmpty && element.isHittable else { return false }
        return XCUIApplication().windows.element(boundBy: 0).frame.contains(element.frame)
    }

    // A shortcut to scroll TableViews or CollectionViews to top
    func tapStatusBarToScrollToTop() {
        XCUIApplication().statusBars.firstMatch.tap()
    }
}

extension XCUIElement {

    func scroll(byDeltaX deltaX: CGFloat, deltaY: CGFloat) {

        let startCoordinate = self.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let destination = startCoordinate.withOffset(CGVector(dx: deltaX, dy: deltaY * -1))

        startCoordinate.press(forDuration: 0.01, thenDragTo: destination)
    }

    @discardableResult
    func waitForHittability(timeout: TimeInterval) -> Bool {

        let predicate = NSPredicate(format: "isHittable == true")
        let elementPredicate = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [elementPredicate], timeout: timeout)

        return result == .completed
    }
}

extension XCUIElementQuery {
    var lastMatch: XCUIElement? {
        return self.allElementsBoundByIndex.last
    }

    var allElementsShareCommonXAxis: Bool {
        let elementXPositions = allElementsBoundByIndex.map { $0.frame.minX }

        // Use a set to remove duplicates – if all elements are the same, only one should remain
        return Set(elementXPositions).count == 1
    }
}
