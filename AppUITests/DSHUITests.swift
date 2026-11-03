import XCTest

final class DSHUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoMessageAndStopAllowsContinuation() {
        let app = launchDemo()
        attachScreenshot(of: app, named: "Light - example task")
        openNewTask(in: app)
        let composer = element("chat.composer", in: app)
        let send = app.buttons["chat.send"]
        XCTAssertFalse(send.isEnabled)
        attachScreenshot(of: app, named: "Light - new task")

        composer.tap()
        composer.typeText("   ")
        XCTAssertFalse(send.isEnabled, "Whitespace alone must not enable sending.")
        composer.typeText("Explain this project")
        XCTAssertTrue(send.isEnabled)
        send.tap()

        let stop = app.buttons["chat.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        XCTAssertFalse(send.isEnabled, "A running task must not accept another message.")
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
    func testHomeComposerStartsTask() {
        let app = launchDemo()
        goHome(in: app)
        let composer = element("home.composer", in: app)
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.send"].exists, "Sending needs text first.")
        XCTAssertEqual(app.buttons["home.chip.permission"].label, "权限模式：每次询问")
        composer.tap()
        composer.typeText("Summarize open issues")
        app.buttons["home.send"].tap()

        XCTAssertTrue(app.buttons["chat.stop"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("task.title", in: app).label.contains("Summarize open issues"))
        XCTAssertTrue(app.staticTexts["你：Summarize open issues"].exists)
        app.buttons["chat.stop"].tap()
        XCTAssertTrue(element("chat.interrupted", in: app).waitForExistence(timeout: 5))

        goHome(in: app)
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertFalse((composer.value as? String ?? "").contains("Summarize"), "Starting a task must clear the home draft.")
        XCTAssertFalse(app.buttons["home.send"].exists)
        XCTAssertTrue(app.buttons["task.row.Summarize open issues"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDraftSurvivesNavigationAndNewTask() {
        let app = launchDemo()
        openNewTask(in: app)
        let composer = element("chat.composer", in: app)
        let example = app.buttons["chat.example"]
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Keep this draft")
        XCTAssertTrue(example.waitForNonExistence(timeout: 5), "The example must not offer to replace an existing draft.")
        XCTAssertEqual(composer.value as? String, "Keep this draft")

        app.buttons["task.more"].tap()
        let newTask = app.buttons["conversation.new"]
        XCTAssertTrue(newTask.waitForExistence(timeout: 5))
        newTask.tap()
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        XCTAssertFalse((composer.value as? String ?? "").contains("Keep this draft"))
        XCTAssertFalse(app.buttons["chat.send"].isEnabled)

        goHome(in: app)
        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "草稿：Keep this draft")).firstMatch
        XCTAssertTrue(draftRow.waitForExistence(timeout: 5))
        draftRow.tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, "Keep this draft")
        XCTAssertTrue(app.buttons["chat.send"].isEnabled)
    }

    @MainActor
    func testDraftSurvivesCancelledLogin() {
        let app = launchDemo()
        openNewTask(in: app)
        let composer = element("chat.composer", in: app)
        composer.tap()
        composer.typeText("Keep this while connecting")

        goHome(in: app)
        openDrawer(in: app)
        app.buttons["drawer.computers"].tap()
        openLogin(in: app)
        app.textFields["connection.server"].tap()
        app.textFields["connection.server"].typeText("https://remote.example.invalid")
        app.navigationBars["登录 Remote"].buttons["取消"].tap()
        XCTAssertTrue(app.navigationBars["登录 Remote"].waitForNonExistence(timeout: 5))
        app.navigationBars["电脑"].buttons["完成"].tap()
        XCTAssertFalse(app.textFields["drawer.search"].exists, "Opening a panel from the drawer closes the drawer.")

        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "草稿：Keep this while connecting")).firstMatch
        XCTAssertTrue(draftRow.waitForExistence(timeout: 5))
        draftRow.tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, "Keep this while connecting")
        XCTAssertTrue(app.buttons["chat.send"].isEnabled)
    }

    @MainActor
    func testApprovalClosePreservesRequestAndAllowConsumesIt() {
        let app = launchDemo(appearance: "dark")
        openApprovalTask(in: app)
        let composer = element("chat.composer", in: app)
        composer.tap()
        composer.typeText("Draft after approval")
        XCTAssertFalse(app.buttons["chat.send"].isEnabled)
        app.buttons["approval.composerReview"].tap()

        XCTAssertTrue(app.buttons["approval.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(containsText("Mac mini", in: app))
        XCTAssertTrue(containsText("~/code/harness-api", in: app))
        XCTAssertEqual(element("approval.command", in: app).label, "命令：npm run test -- --watch=false")
        XCTAssertTrue(app.buttons["approval.allow"].isEnabled)
        XCTAssertTrue(app.buttons["approval.reject"].isEnabled)
        XCTAssertTrue(app.buttons["approval.explain"].isEnabled)
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

        goHome(in: app)
        XCTAssertFalse(app.buttons["home.pending.修复登录超时"].exists, "A resolved request must leave the waiting list.")
        let row = app.buttons["task.row.修复登录超时"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertApprovalConsumed(in: app, outcome: "已记录「仅允许一次」。没有执行命令。")
        XCTAssertEqual(composer.value as? String, "Draft after approval")
    }

    @MainActor
    func testRejectApprovalShowsLocalResult() {
        let app = launchDemo()
        openApprovalTask(in: app)
        app.buttons["approval.composerReview"].tap()
        XCTAssertTrue(app.buttons["approval.reject"].waitForExistence(timeout: 5))
        app.buttons["approval.reject"].tap()
        assertApprovalConsumed(in: app, outcome: "已记录「拒绝这次操作」。没有执行命令。")
    }

    @MainActor
    func testRejectWithNoteSendsNoteOnce() {
        let app = launchDemo()
        openApprovalTask(in: app)
        app.buttons["approval.composerReview"].tap()
        XCTAssertTrue(app.buttons["approval.explain"].waitForExistence(timeout: 5))
        app.buttons["approval.explain"].tap()
        let note = element("approval.note", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["approval.sendNote"].isEnabled, "An empty note must not be sent.")
        note.typeText("Run only the login tests")
        XCTAssertTrue(app.buttons["approval.sendNote"].isEnabled)
        app.buttons["approval.sendNote"].tap()
        assertApprovalConsumed(in: app, outcome: "已记录「拒绝这次操作」，并附上说明：Run only the login tests。没有执行命令。")
    }

    @MainActor
    func testHomePendingCardOpensApprovalSheet() {
        let app = launchDemo()
        goHome(in: app)
        XCTAssertEqual(element("home.pendingHeader", in: app).label, "等你确认 · 1")
        let card = app.buttons["home.pending.修复登录超时"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "Light - home")
        card.tap()
        XCTAssertTrue(app.buttons["approval.allow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["需要你确认"].exists)
        app.buttons["approval.close"].tap()
        XCTAssertTrue(app.buttons["approval.composerReview"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("task.title", in: app).label.contains("修复登录超时"))
    }

    @MainActor
    func testBackgroundInvalidatesOpenApprovalAndPreservesDraft() {
        let app = launchDemo()
        openApprovalTask(in: app)
        let composer = element("chat.composer", in: app)
        composer.tap()
        composer.typeText("Keep this after backgrounding")
        app.buttons["approval.composerReview"].tap()
        XCTAssertTrue(app.buttons["approval.allow"].waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()

        XCTAssertTrue(app.buttons["approval.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("approval.stale", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["approval.allow"].isEnabled)
        XCTAssertFalse(app.buttons["approval.reject"].isEnabled)
        XCTAssertFalse(app.buttons["approval.explain"].isEnabled)
        app.buttons["approval.close"].tap()
        assertApprovalConsumed(in: app, outcome: "待确认操作已失效，没有记录授权。你可以继续发送消息。")
        XCTAssertEqual(composer.value as? String, "Keep this after backgrounding")
        XCTAssertTrue(app.buttons["chat.send"].isEnabled)
    }

    @MainActor
    func testConnectionEntryDoesNotExposeRemoteComposer() {
        let app = launchApplication()
        XCTAssertFalse(element("chat.composer", in: app).exists)
        XCTAssertFalse(element("home.composer", in: app).exists)
        XCTAssertFalse(app.buttons["home.new"].exists)
        app.buttons["home.connect"].tap()
        XCTAssertTrue(app.navigationBars["连接电脑"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pairing.copy"].exists)
        XCTAssertTrue(app.buttons["pairing.example"].exists)
        app.buttons["pairing.manual"].tap()
        XCTAssertTrue(app.textFields["connection.server"].waitForExistence(timeout: 5))
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
        app.buttons["pairing.manual"].tap()
        XCTAssertTrue(app.textFields["connection.server"].waitForExistence(timeout: 5))
        XCTAssertFalse(login.isEnabled)
        XCTAssertNotEqual(app.textFields["connection.server"].value as? String, "https://remote.example.invalid")
        XCTAssertNotEqual(app.textFields["connection.account"].value as? String, "ui-test@example.invalid")
        app.navigationBars["登录 Remote"].buttons["取消"].tap()
        app.buttons["pairing.cancel"].tap()
        XCTAssertTrue(app.navigationBars["连接电脑"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("chat.composer", in: app).exists)
        XCTAssertFalse(element("home.composer", in: app).exists)
    }

    @MainActor
    func testPairingOffersExampleTask() {
        let app = launchApplication(appearance: "dark")
        app.buttons["home.connect"].tap()
        let example = app.buttons["pairing.example"]
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "Dark - pairing")
        example.tap()
        XCTAssertTrue(app.navigationBars["连接电脑"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("task.title", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("task.title", in: app).label.contains("加暗色模式"))
    }

    @MainActor
    func testPermissionMenuOffersNoBypass() {
        let app = launchDemo()
        openNewTask(in: app)
        let permission = app.buttons["chat.permission"]
        XCTAssertEqual(permission.label, "权限模式：每次询问")
        permission.tap()
        for mode in ["每次询问", "自动改文件", "计划模式"] {
            XCTAssertTrue(app.buttons[mode].waitForExistence(timeout: 5), "Missing permission mode \(mode)")
        }
        let bypass = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "跳过", "绕过"))
        XCTAssertEqual(bypass.count, 0, "The phone must not offer to skip approvals.")
        app.buttons["计划模式"].tap()
        XCTAssertTrue(app.buttons["chat.permission"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["chat.permission"].label, "权限模式：计划模式")
    }

    @MainActor
    func testExampleTaskShowsChangesAndForks() {
        let app = launchDemo()
        XCTAssertTrue(element("task.title", in: app).label.contains("加暗色模式"))
        let activity = app.buttons["message.activity"].firstMatch
        XCTAssertTrue(activity.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["diff.showAll"].firstMatch.exists || scrollTo(app.buttons["diff.showAll"].firstMatch, in: app))
        attachScreenshot(of: app, named: "Light - task detail")

        let fork = app.buttons["message.fork"].firstMatch
        XCTAssertTrue(fork.waitForExistence(timeout: 5))
        fork.tap()
        let forkedTitle = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "task.title", "加暗色模式 · 分叉")).firstMatch
        XCTAssertTrue(forkedTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(element("chat.composer", in: app).exists)
        XCTAssertTrue(app.buttons["chat.send"].exists)
    }

    @MainActor
    func testDrawerSearchFindsTask() {
        let app = launchDemo()
        goHome(in: app)
        openDrawer(in: app)
        let search = app.textFields["drawer.search"]
        search.tap()
        search.typeText("周报")
        let match = app.buttons["drawer.task.写周报脚本"]
        XCTAssertTrue(match.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["drawer.task.修复登录超时"].exists)
        match.tap()
        XCTAssertTrue(element("task.title", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("task.title", in: app).label.contains("写周报脚本"))
        XCTAssertTrue(element("task.title", in: app).label.contains("MacBook Pro · blog"))
    }

    @MainActor
    func testLargestAccessibilityTextKeepsPrimaryActionsReachable() {
        let app = launchApplication(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertEqual(element("home.title", in: app).label, "在手机上看着电脑里的 Agent 干活")
        XCTAssertTrue(app.buttons["home.connect"].isHittable)
        attachScreenshot(of: app, named: "Accessibility XXXL - entry")
        XCTAssertTrue(scrollTo(app.buttons["home.example"], in: app), "The example task must be reachable by scrolling.")
        XCTAssertTrue(app.buttons["home.example"].isHittable)
        enterDemo(in: app)
        goHome(in: app)
        XCTAssertTrue(element("home.composer", in: app).isHittable)
        XCTAssertTrue(app.buttons["home.new"].isHittable)
        XCTAssertTrue(app.buttons["home.menu"].isHittable)
        attachScreenshot(of: app, named: "Accessibility XXXL - home")

        openApprovalTask(in: app)
        XCTAssertTrue(app.buttons["approval.composerReview"].isHittable)
        XCTAssertTrue(element("chat.composer", in: app).isHittable)
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
            "-defaults.permissionMode", "ask",
            "-defaults.model", "跟随电脑",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
        XCTAssertTrue(app.buttons["home.example"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func launchDemo(appearance: String = "light") -> XCUIApplication {
        let app = launchApplication(appearance: appearance)
        enterDemo(in: app)
        return app
    }

    /// Opens the example task, which also loads the other example tasks.
    @MainActor
    private func enterDemo(in app: XCUIApplication) {
        app.buttons["home.example"].tap()
        XCTAssertTrue(element("task.title", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("chat.composer", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    private func goHome(in app: XCUIApplication) {
        if app.buttons["home.new"].exists && app.buttons["home.new"].isHittable { return }
        let back = app.navigationBars.buttons["任务"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["home.new"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openNewTask(in app: XCUIApplication) {
        goHome(in: app)
        app.buttons["home.new"].tap()
        XCTAssertTrue(element("chat.composer", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("task.title", in: app).label.contains("新任务"))
    }

    @MainActor
    private func openDrawer(in app: XCUIApplication) {
        app.buttons["home.menu"].tap()
        XCTAssertTrue(app.textFields["drawer.search"].waitForExistence(timeout: 5))
    }

    /// Opens the waiting task through the drawer, as a user switching tasks would.
    @MainActor
    private func openApprovalTask(in app: XCUIApplication) {
        goHome(in: app)
        openDrawer(in: app)
        let row = app.buttons["drawer.task.修复登录超时"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.label, "修复登录超时，等你确认")
        row.tap()
        // This safe-area action stays reachable even when the transcript card is offscreen.
        XCTAssertTrue(app.buttons["approval.composerReview"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("task.title", in: app).label.contains("修复登录超时"))
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
    private func containsText(_ text: String, in app: XCUIApplication) -> Bool {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists
    }

    @MainActor
    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 {
            if target.exists && target.isHittable { return true }
            app.swipeUp()
        }
        return target.exists
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
