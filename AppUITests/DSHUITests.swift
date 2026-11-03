import XCTest

final class DSHUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoMessageAndStopAllowsContinuation() {
        let app = launchApplication()
        attachScreenshot(of: app, named: "Light - entry")
        enterDemo(in: app)
        let composer = element("chat.composer", in: app)
        let send = app.buttons["chat.send"]
        XCTAssertFalse(send.isEnabled)
        attachScreenshot(of: app, named: "Light - new conversation")

        composer.tap()
        composer.typeText("   ")
        XCTAssertFalse(send.isEnabled, "Whitespace alone must not enable sending.")
        composer.typeText("Explain this project")
        XCTAssertTrue(send.isEnabled)
        send.tap()

        let stop = app.buttons["chat.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(element("chat.interrupted", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(stop.waitForNonExistence(timeout: 5))
        XCTAssertFalse(send.isEnabled, "Sending must clear the previous draft.")
        XCTAssertTrue(app.staticTexts["你：Explain this project"].exists)

        composer.tap()
        composer.typeText("Continue with the tests")
        send.tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(element("chat.interrupted", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["你：Continue with the tests"].exists)
        XCTAssertFalse(send.isEnabled)
    }

    @MainActor
    func testDraftSurvivesHistoryNewConversationAndDemoExit() {
        let app = launchDemo()
        let composer = element("chat.composer", in: app)
        let example = app.buttons["chat.example"]
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Keep this draft")
        XCTAssertTrue(example.waitForNonExistence(timeout: 5), "The example must not offer to replace an existing draft.")
        XCTAssertEqual(composer.value as? String, "Keep this draft")
        app.buttons["conversation.new"].tap()
        XCTAssertFalse((composer.value as? String ?? "").contains("Keep this draft"))
        XCTAssertFalse(app.buttons["chat.send"].isEnabled)
        XCTAssertTrue(example.waitForExistence(timeout: 5))

        openHistory(in: app)
        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Keep this draft")).firstMatch
        XCTAssertTrue(draftRow.waitForExistence(timeout: 5))
        draftRow.tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, "Keep this draft")

        app.buttons["demo.info"].tap()
        let leave = app.buttons["demo.leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()
        let resume = app.buttons["demo.enter"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertFalse(composer.exists)
        XCTAssertFalse(app.buttons["conversation.new"].exists)
        resume.tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, "Keep this draft")
    }

    @MainActor
    func testDraftSurvivesCancelledLogin() {
        let app = launchDemo()
        let composer = element("chat.composer", in: app)
        composer.tap()
        composer.typeText("Keep this while connecting")

        app.buttons["demo.info"].tap()
        let computers = app.buttons["查看电脑"]
        XCTAssertTrue(computers.waitForExistence(timeout: 5))
        computers.tap()
        openLogin(in: app)
        app.textFields["connection.server"].tap()
        app.textFields["connection.server"].typeText("https://remote.example.invalid")
        app.navigationBars["登录 Remote"].buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["登录 Remote"].waitForNonExistence(timeout: 5))
        app.navigationBars["电脑"].buttons["完成"].tap()

        XCTAssertTrue(app.buttons["demo.info"].waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, "Keep this while connecting")
        XCTAssertTrue(app.buttons["chat.send"].isEnabled)
    }

    @MainActor
    func testApprovalClosePreservesRequestAndAllowConsumesIt() {
        let app = launchDemo(appearance: "dark")
        openApprovalConversation(in: app)
        let composer = element("chat.composer", in: app)
        composer.tap()
        composer.typeText("Draft after approval")
        XCTAssertFalse(app.buttons["chat.send"].isEnabled)
        app.buttons["approval.composerReview"].tap()

        XCTAssertTrue(app.buttons["approval.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["示例 Mac"].exists)
        XCTAssertTrue(app.staticTexts["~/Projects/app"].exists)
        XCTAssertEqual(app.staticTexts["approval.command"].label, "swift test")
        XCTAssertTrue(app.buttons["approval.allow"].isEnabled)
        XCTAssertTrue(app.buttons["approval.reject"].isEnabled)
        attachScreenshot(of: app, named: "Dark - pending approval")

        app.buttons["approval.close"].tap()
        XCTAssertTrue(app.buttons["approval.composerReview"].waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, "Draft after approval")
        XCTAssertFalse(app.buttons["chat.send"].isEnabled)
        app.buttons["approval.composerReview"].tap()
        XCTAssertTrue(app.buttons["approval.allow"].waitForExistence(timeout: 5))
        app.buttons["approval.allow"].tap()

        assertApprovalConsumed(in: app, outcome: "已记录「仅允许一次」。没有执行命令。")
        XCTAssertEqual(composer.value as? String, "Draft after approval")
        XCTAssertTrue(app.buttons["chat.send"].isEnabled)
        attachScreenshot(of: app, named: "Dark - approval result")

        selectConversation("阅读一个 Swift 项目", in: app)
        selectConversation("检查登录流程", in: app)
        assertApprovalConsumed(in: app, outcome: "已记录「仅允许一次」。没有执行命令。")
        XCTAssertEqual(composer.value as? String, "Draft after approval")
    }

    @MainActor
    func testRejectApprovalShowsLocalResult() {
        let app = launchDemo()
        openApprovalConversation(in: app)
        app.buttons["approval.composerReview"].tap()
        XCTAssertTrue(app.buttons["approval.reject"].waitForExistence(timeout: 5))
        app.buttons["approval.reject"].tap()
        assertApprovalConsumed(in: app, outcome: "已记录「拒绝这次操作」。没有执行命令。")
    }

    @MainActor
    func testBackgroundInvalidatesOpenApprovalAndPreservesDraft() {
        let app = launchDemo()
        openApprovalConversation(in: app)
        let composer = element("chat.composer", in: app)
        composer.tap()
        composer.typeText("Keep this after backgrounding")
        app.buttons["approval.composerReview"].tap()
        XCTAssertTrue(app.buttons["approval.allow"].waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()

        XCTAssertTrue(app.buttons["approval.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["approval.allow"].isEnabled)
        XCTAssertFalse(app.buttons["approval.reject"].isEnabled)
        app.buttons["approval.close"].tap()
        assertApprovalConsumed(in: app, outcome: "待确认操作已失效，没有记录授权。你可以继续发送消息。")
        XCTAssertEqual(composer.value as? String, "Keep this after backgrounding")
        XCTAssertTrue(app.buttons["chat.send"].isEnabled)
    }

    @MainActor
    func testConnectionEntryDoesNotExposeRemoteComposer() {
        let app = launchApplication()
        XCTAssertFalse(element("chat.composer", in: app).exists)
        XCTAssertFalse(app.buttons["conversation.new"].exists)
        app.buttons["entry.computers"].tap()
        openLogin(in: app)
        XCTAssertFalse(element("chat.composer", in: app).exists)

        let login = app.buttons["connection.login"]
        XCTAssertFalse(login.isEnabled)
        app.textFields["connection.server"].tap()
        app.textFields["connection.server"].typeText("https://remote.example.invalid")
        app.textFields["connection.account"].tap()
        app.textFields["connection.account"].typeText("ui-test@example.invalid")
        XCTAssertFalse(login.isEnabled)
        app.secureTextFields["connection.password"].tap()
        app.secureTextFields["connection.password"].typeText("local-ui-placeholder")
        XCTAssertTrue(login.isEnabled)
        // Cancel without submitting: these tests must never contact a Remote service.
        app.navigationBars["登录 Remote"].buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["登录 Remote"].waitForNonExistence(timeout: 5))
        openLogin(in: app)
        XCTAssertFalse(login.isEnabled)
        XCTAssertNotEqual(app.textFields["connection.server"].value as? String, "https://remote.example.invalid")
        XCTAssertNotEqual(app.textFields["connection.account"].value as? String, "ui-test@example.invalid")
        XCTAssertFalse(element("chat.composer", in: app).exists)
    }

    @MainActor
    func testLargestAccessibilityTextKeepsPrimaryActionsReachable() {
        let app = launchApplication(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertEqual(app.staticTexts["entry.title"].label, "从一个对话开始")
        XCTAssertEqual(app.buttons["demo.enter"].label, "试用本地对话")
        XCTAssertEqual(app.buttons["entry.computers"].label, "登录并发现电脑")
        XCTAssertTrue(app.buttons["demo.enter"].isHittable)
        XCTAssertTrue(app.buttons["entry.computers"].isHittable)
        attachScreenshot(of: app, named: "Accessibility XXXL - entry")
        enterDemo(in: app)
        XCTAssertTrue(element("chat.composer", in: app).isHittable)
        XCTAssertTrue(app.buttons["conversation.new"].isHittable)
        attachScreenshot(of: app, named: "Accessibility XXXL - new conversation")

        openApprovalConversation(in: app)
        XCTAssertTrue(app.buttons["approval.composerReview"].isHittable)
        app.buttons["approval.composerReview"].tap()
        XCTAssertTrue(app.buttons["approval.allow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["approval.allow"].isHittable)
        XCTAssertTrue(app.buttons["approval.reject"].isHittable)
        XCTAssertTrue(app.buttons["approval.close"].isHittable)
        attachScreenshot(of: app, named: "Accessibility XXXL - approval")
    }

    @MainActor
    private func launchApplication(appearance: String = "light", contentSizeCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        // Argument-domain defaults last only for this process. They prevent restoring
        // a real account without deleting preferences or touching Keychain records.
        app.launchArguments = [
            "-remote.server", "",
            "-remote.loginRequired", "NO",
            "-appearance", appearance,
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
        XCTAssertTrue(app.buttons["demo.enter"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func launchDemo(appearance: String = "light") -> XCUIApplication {
        let app = launchApplication(appearance: appearance)
        enterDemo(in: app)
        return app
    }

    @MainActor
    private func enterDemo(in app: XCUIApplication) {
        app.buttons["demo.enter"].tap()
        XCTAssertTrue(app.buttons["demo.info"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("chat.composer", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    private func openHistory(in app: XCUIApplication) {
        let history = app.buttons["conversation.history"]
        if history.exists { history.tap() }
        XCTAssertTrue(app.navigationBars["历史记录"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func selectConversation(_ title: String, in app: XCUIApplication) {
        openHistory(in: app)
        let row = app.buttons["history.conversation.\(title)"]
        for _ in 0..<4 {
            if row.exists && row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isHittable)
        row.tap()
        if app.buttons["conversation.history"].exists {
            XCTAssertTrue(app.navigationBars["历史记录"].waitForNonExistence(timeout: 5))
        }
        XCTAssertTrue(app.buttons["demo.info"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["demo.info"].label.contains(title))
    }

    @MainActor
    private func openApprovalConversation(in app: XCUIApplication) {
        selectConversation("检查登录流程", in: app)
        // This safe-area action stays reachable even when the transcript card is offscreen.
        XCTAssertTrue(app.buttons["approval.composerReview"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openLogin(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["电脑"].waitForExistence(timeout: 5))
        let login = app.buttons["devices.login"]
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        XCTAssertTrue(login.isEnabled)
        login.tap()
        XCTAssertTrue(app.textFields["connection.server"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertApprovalConsumed(in app: XCUIApplication, outcome: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["approval.close"].waitForNonExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(app.buttons["approval.composerReview"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["approval.review"].exists, file: file, line: line)
        let result = app.staticTexts.matching(NSPredicate(format: "label == %@", "助手：\(outcome)"))
        XCTAssertTrue(result.firstMatch.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(result.count, 1, "A request should produce only one local result.", file: file, line: line)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
