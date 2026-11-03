import SwiftUI
import DSHCore

@MainActor @Observable
final class ConnectionStore {
    // Kept as a draft for existing callers; restoration never reads form edits.
    var serverAddress: String
    private(set) var committedServerAddress: String
    var devices: [RemoteDevice] = []
    var isBusy = false
    var isSignedIn = false
    var errorMessage: String?
    var accountName = ""
    private var activeServer: RemoteServerURL?
    private let credentials = CredentialStore()
    private var hasRestored = false
    private var restoreNeedsRetry = false
    private var requiresLogin = false
    private var unreadableIdentityServer: RemoteServerURL?

    var canSignOut: Bool { !isBusy && (activeServer != nil || requiresLogin) }
    var canRetryRestore: Bool { restoreNeedsRetry && !requiresLogin && !isBusy }
    var canForgetSavedIdentity: Bool { unreadableIdentityServer != nil && !isBusy }
    var savedIdentityServerAddress: String? { unreadableIdentityServer?.description }

    init() {
        let savedAddress = UserDefaults.standard.string(forKey: "remote.server") ?? ""
        serverAddress = savedAddress
        committedServerAddress = savedAddress
        requiresLogin = UserDefaults.standard.bool(forKey: "remote.loginRequired")
    }

    func login(email: String, password: String) async -> Bool {
        await login(serverAddress: serverAddress, email: email, password: password)
    }

    func login(serverAddress: String, email: String, password: String) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        var attemptedServer: RemoteServerURL?
        var registrationStarted = false
        do {
            let server = try RemoteServerURL(serverAddress)
            attemptedServer = server
            let api = RemoteServerAPI(server: server)
            let account = try await api.login(email: email, password: password)
            let identity = try await credentials.loadOrCreateIdentity(for: server, name: "DSH iOS")
            registrationStarted = true
            if server.description == committedServerAddress {
                UserDefaults.standard.set(true, forKey: "remote.loginRequired")
            }
            let tokens = try await api.register(identity: identity, accountToken: account.token, clientVersion: "0.1.0")
            try await credentials.saveCredentials(tokens, for: server, deviceID: identity.deviceId)
            activeServer = server
            self.serverAddress = server.description
            committedServerAddress = server.description
            UserDefaults.standard.set(server.description, forKey: "remote.server")
            accountName = account.account
            devices = []
            isSignedIn = true
            hasRestored = true
            requiresLogin = false
            UserDefaults.standard.removeObject(forKey: "remote.loginRequired")
            restoreNeedsRetry = false
            unreadableIdentityServer = nil
            do { devices = try await api.listDevices(accessToken: tokens.accessToken) }
            catch {
                if isAuthorizationFailure(error) { invalidateAuthorization() }
                errorMessage = message(for: error)
            }
            return isSignedIn
        } catch {
            // Account login failure does not invalidate existing device credentials.
            // Registration may have replaced the current device's tokens even if its
            // response or the subsequent Keychain write failed. Never reuse them.
            if let server = attemptedServer,
               server.description == committedServerAddress,
               registrationStarted {
                invalidateAuthorization()
            }
            recordUnreadableIdentity(error, for: attemptedServer)
            errorMessage = message(for: error)
            return false
        }
    }

    func restore() async {
        guard !hasRestored, !isBusy else { return }
        hasRestored = true
        guard !committedServerAddress.isEmpty else { return }
        if requiresLogin {
            errorMessage = "登录信息需要更新，请重新登录 Remote 账号。"
            return
        }
        await refreshDevices()
    }

    func retryRestore() async {
        guard canRetryRestore else { return }
        await refreshDevices()
    }

    func refreshDevices() async {
        guard !isBusy, !requiresLogin, !committedServerAddress.isEmpty else { return }
        isBusy = true
        hasRestored = true
        restoreNeedsRetry = false
        errorMessage = nil
        defer { isBusy = false }
        var refreshStarted = false
        var refreshSaved = false
        do {
            let server = try activeServer ?? RemoteServerURL(committedServerAddress)
            activeServer = server
            guard let identity = try await credentials.identity(for: server),
                  var tokens = try await credentials.credentials(for: server, deviceID: identity.deviceId) else {
                clearSession()
                return
            }
            unreadableIdentityServer = nil
            let api = RemoteServerAPI(server: server)
            if tokens.needsRefresh() {
                guard tokens.canRefresh() else {
                    invalidateAuthorization()
                    errorMessage = "登录已过期，请重新登录 Remote 账号。"
                    return
                }
                refreshStarted = true
                // Persist before rotating so a later launch cannot replay a token
                // whose replacement response or Keychain save may have been lost.
                UserDefaults.standard.set(true, forKey: "remote.loginRequired")
                tokens = try await api.refresh(deviceID: identity.deviceId, refreshToken: tokens.refreshToken)
                try await credentials.saveCredentials(tokens, for: server, deviceID: identity.deviceId)
                refreshSaved = true
                UserDefaults.standard.removeObject(forKey: "remote.loginRequired")
            }
            isSignedIn = true
            devices = try await api.listDevices(accessToken: tokens.accessToken)
        } catch {
            devices = []
            let refreshOutcomeUnknown = refreshStarted && !refreshSaved
            if isAuthorizationFailure(error) || refreshOutcomeUnknown {
                invalidateAuthorization()
            }
            recordUnreadableIdentity(error, for: activeServer)
            restoreNeedsRetry = !isSignedIn && !requiresLogin && unreadableIdentityServer == nil
            errorMessage = refreshOutcomeUnknown && !isAuthorizationFailure(error)
                ? "登录信息更新未完成，请重新登录 Remote 账号。"
                : message(for: error)
        }
    }

    func signOut() async {
        guard !isBusy,
              let server = activeServer ?? (try? RemoteServerURL(committedServerAddress)) else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            if let identity = try await credentials.identity(for: server) {
                try await credentials.clearCredentials(for: server, deviceID: identity.deviceId)
            }
            clearSession()
        } catch {
            recordUnreadableIdentity(error, for: server)
            errorMessage = message(for: error)
        }
    }

    // Offered only for an unreadable record, never as a general-purpose identity reset.
    func forgetSavedIdentity() async {
        guard !isBusy, let server = unreadableIdentityServer else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await credentials.removeIdentity(for: server)
            if server.description == committedServerAddress { clearSession() }
            unreadableIdentityServer = nil
            errorMessage = nil
        } catch { errorMessage = message(for: error) }
    }

    private func invalidateAuthorization() {
        isSignedIn = false
        accountName = ""
        devices = []
        requiresLogin = true
        UserDefaults.standard.set(true, forKey: "remote.loginRequired")
        restoreNeedsRetry = false
    }

    private func clearSession() {
        invalidateAuthorization()
        requiresLogin = false
        UserDefaults.standard.removeObject(forKey: "remote.loginRequired")
        activeServer = nil
        hasRestored = true
        unreadableIdentityServer = nil
        errorMessage = nil
    }

    private func isAuthorizationFailure(_ error: Error) -> Bool {
        guard let remote = error as? RemoteAPIError,
              case .http(let status, _, _, _) = remote else { return false }
        return status == 401 || status == 403
    }

    private func recordUnreadableIdentity(_ error: Error, for server: RemoteServerURL?) {
        guard let stored = error as? CredentialStoreError,
              stored == .invalidStoredData, let server else { return }
        unreadableIdentityServer = server
        if server.description == committedServerAddress { invalidateAuthorization() }
    }

    private func message(for error: Error) -> String {
        if let remote = error as? RemoteAPIError {
            switch remote {
            case .invalidServerURL: return "请输入完整的 HTTPS 服务地址，不要包含路径或查询参数。"
            case .invalidInput: return "请检查账号、密码及设备信息。"
            case .invalidResponse: return "服务返回了无法识别的数据，请确认 Remote Server 版本。"
            case .redirectRejected: return "服务地址发生了跳转，请填写最终的 HTTPS 地址。"
            case .http(let status, _, _, _):
                if status == 401 || status == 403 { return "登录或设备授权失效，请检查账号后重新登录。" }
                return "服务暂时无法完成请求（HTTP \(status)），请稍后重试。"
            }
        }
        if let stored = error as? CredentialStoreError {
            switch stored {
            case .invalidStoredData:
                return "保存的设备身份无法读取。请移除该服务的本机身份后重新登录。"
            case .identityMismatch:
                return "登录信息与本机设备身份不匹配，请重新登录。"
            case .keychain:
                return "无法访问系统钥匙串，连接信息未能安全保存。请解锁设备后重试。"
            }
        }
        if let network = error as? URLError {
            return "无法连接服务，请检查网络与服务地址（\(network.code.rawValue)）。"
        }
        return "连接未完成，请检查服务配置后重试。"
    }
}
