import CryptoKit
import Foundation
import Security
import Testing
@testable import DSHCore

private let accessToken = "device-access-token-for-tests"
private let refreshToken = "device-refresh-token-for-tests"
private let accountToken = "account-registration-token-for-tests"
private let deviceID = "d6ae2f9a-7d54-43ab-9520-93adc5ae747d"
private let tokenJSON = #"{"accessToken":"device-access-token-for-tests","accessTokenExpiresAt":2000000000000,"refreshToken":"device-refresh-token-for-tests","refreshTokenExpiresAt":2000100000000}"#

private func response(_ request: URLRequest, json: String, status: Int = 200,
                      url: URL? = nil) -> (Data, HTTPURLResponse) {
    (Data(json.utf8), HTTPURLResponse(url: url ?? request.url!, statusCode: status,
                                   httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!)
}

private func object(_ request: URLRequest) throws -> [String: Any] {
    let body = try #require(request.httpBody)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

@Test func serverURLNormalizesOriginAndDefaultPort() throws {
    let server = try RemoteServerURL("  HTTPS://EXAMPLE.COM:443/  ")
    #expect(server.description == "https://example.com")
    #expect(server == (try RemoteServerURL("https://example.com")))
    #expect(try RemoteServerURL("https://localhost:8443").description == "https://localhost:8443")
    #expect(try JSONDecoder().decode(RemoteServerURL.self, from: JSONEncoder().encode(server)) == server)
}

@Test(arguments: [
    "http://example.com", "http://localhost:3000", "example.com", "https://",
    "https://user:pass@example.com", "https://example.com/path", "https://example.com?token=x",
    "https://example.com#fragment", "https://example.com:0", "https://example.com:65536",
    "https://exa mple.com", "https://example.com\\@other.test", "https://exam\nple.com",
    "https://example.com/%2F"
]) func invalidServerURLsAreRejected(_ value: String) {
    #expect(throws: RemoteAPIError.invalidServerURL) { try RemoteServerURL(value) }
}

@Test func loginUsesExactAccountSchemaWithoutDeviceAuthorization() async throws {
    let server = try RemoteServerURL("https://remote.example")
    let api = RemoteServerAPI(server: server) { request in
        #expect(request.url?.absoluteString == "https://remote.example/api/v1/auth/login")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(!request.httpShouldHandleCookies)
        let body = try object(request)
        #expect(Set(body.keys) == ["email", "password"])
        #expect(body["email"] as? String == "person@example.com")
        #expect(body["password"] as? String == " password with spaces ")
        return response(request, json: #"{"token":"account-registration-token-for-tests","expiresAt":2000000000000,"account":"person@example.com","isAdmin":false,"profile":{"displayName":"Person"}}"#)
    }
    let login = try await api.login(email: " person@example.com\n", password: " password with spaces ")
    #expect(login.token == accountToken)
    #expect(login.expiresAt == 2_000_000_000_000)
    #expect(login.account == "person@example.com")
    #expect(!login.isAdmin)
    #expect(!String(reflecting: login).contains(accountToken))
}

@Test func registrationSendsOnlyPublicIOSClientDescriptor() async throws {
    let identity = try DeviceIdentity.generate(name: "Test iPhone")
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        #expect(request.url?.path == "/api/v1/devices/register")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(accountToken)")
        let body = try object(request)
        #expect(Set(body.keys) == ["v", "device"])
        #expect(body["v"] as? Int == 1)
        let device = try #require(body["device"] as? [String: Any])
        #expect(Set(device.keys) == ["deviceId", "name", "role", "platform", "identityKey", "clientVersion"])
        #expect(device["deviceId"] as? String == identity.deviceId)
        #expect(device["name"] as? String == identity.name)
        #expect(device["role"] as? String == "client")
        #expect(device["platform"] as? String == "ios")
        #expect(device["identityKey"] as? String == identity.publicKey)
        #expect(device["clientVersion"] as? String == "0.1.0")
        return response(request, json: tokenJSON)
    }
    let tokens = try await api.register(identity: identity, accountToken: accountToken, clientVersion: "0.1.0")
    #expect(tokens.accessToken == accessToken)
    #expect(tokens.refreshToken == refreshToken)
    #expect(!String(reflecting: tokens).contains(accessToken))
    #expect(!String(reflecting: tokens).contains(refreshToken))
}

@Test func refreshSendsExactSchemaWithoutBearer() async throws {
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        #expect(request.url?.path == "/api/v1/auth/refresh")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try object(request)
        #expect(Set(body.keys) == ["deviceId", "refreshToken"])
        #expect(body["deviceId"] as? String == deviceID)
        #expect(body["refreshToken"] as? String == refreshToken)
        return response(request, json: tokenJSON)
    }
    let tokens = try await api.refresh(deviceID: deviceID, refreshToken: refreshToken)
    #expect(!tokens.needsRefresh(at: Date(timeIntervalSince1970: 1_999_999_000)))
    #expect(tokens.needsRefresh(at: Date(timeIntervalSince1970: 1_999_999_950)))
    #expect(tokens.canRefresh(at: Date(timeIntervalSince1970: 2_000_000_100)))
    #expect(!tokens.canRefresh(at: Date(timeIntervalSince1970: 2_000_100_000)))
}

@Test func discoveryDecodesHostsWithoutPretendingTheyHaveTrustedKeys() async throws {
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        #expect(request.url?.path == "/api/v1/devices")
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(accessToken)")
        return response(request, json: #"{"items":[{"deviceId":"host-1","name":"Mac","role":"host","platform":"darwin","membershipId":"account:123","online":true,"lastSeenAt":2000000000000,"clientVersion":"0.6.2","harnessVersion":"0.2.1-rc.5"},{"deviceId":"client-1","name":"Phone","role":"client","platform":"ios","membershipId":"account:123"}],"nextCursor":null}"#)
    }
    let devices = try await api.listDevices(accessToken: accessToken)
    #expect(devices.count == 1)
    #expect(devices.first?.id == "host-1")
    #expect(devices.first?.online == true)
    #expect(devices.first?.lastSeenAt == 2_000_000_000_000)
    #expect(devices.first?.harnessVersion == "0.2.1-rc.5")
}

@Test func authorizedPeerProvidesCanonicalKeyAndChecksRequestedIdentity() async throws {
    let identity = try DeviceIdentity.generate(name: "Fixture")
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        #expect(request.url?.path == "/api/v1/devices/\(deviceID)")
        return response(request, json: """
        {"deviceId":"\(deviceID)","name":"Mac","role":"host","platform":"darwin","identityKey":"\(identity.publicKey)","membershipId":"account:123","online":false}
        """)
    }
    let peer = try await api.device(id: deviceID, accessToken: accessToken)
    #expect(peer.identityKey == identity.publicKey)
    #expect(peer.id == deviceID)
    let mismatch = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        response(request, json: """
        {"deviceId":"another-device","name":"Mac","role":"host","platform":"darwin","identityKey":"\(identity.publicKey)","membershipId":"account:123"}
        """)
    }
    await #expect(throws: RemoteAPIError.invalidResponse) {
        try await mismatch.device(id: deviceID, accessToken: accessToken)
    }
}

@Test func serverErrorsRetainStatusCodeAndRetryability() async throws {
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        response(request, json: #"{"error":{"code":"AUTH_INVALID","message":"Token expired","retryable":false,"requestId":"id"}}"#, status: 401)
    }
    await #expect(throws: RemoteAPIError.http(status: 401, code: "AUTH_INVALID", message: "Token expired", retryable: false)) {
        try await api.listDevices(accessToken: accessToken)
    }
    let unavailable = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        response(request, json: "<html>Unavailable</html>", status: 503)
    }
    await #expect(throws: RemoteAPIError.http(status: 503, code: nil, message: nil, retryable: true)) {
        try await unavailable.listDevices(accessToken: accessToken)
    }
}

@Test(arguments: ["{}", "not JSON", #"{"items":{}}"#, #"{"items":[{"deviceId":"missing-fields"}]}"#])
func invalidSuccessResponsesAreRejected(_ body: String) async throws {
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        response(request, json: body)
    }
    await #expect(throws: RemoteAPIError.invalidResponse) { try await api.listDevices(accessToken: accessToken) }
}

@Test(arguments: [
    #"{"accessToken":"short","accessTokenExpiresAt":2000000000000,"refreshToken":"long-enough-refresh-token","refreshTokenExpiresAt":2000100000000}"#,
    #"{"accessToken":"long-enough-access-token","accessTokenExpiresAt":0,"refreshToken":"long-enough-refresh-token","refreshTokenExpiresAt":2000100000000}"#,
    #"{"accessToken":"long-enough-access-token","accessTokenExpiresAt":2000000000000,"refreshToken":"long-enough-refresh-token","refreshTokenExpiresAt":9007199254740992}"#
]) func invalidTokenResponsesAreRejected(_ body: String) async throws {
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { request in
        response(request, json: body)
    }
    await #expect(throws: RemoteAPIError.invalidResponse) {
        try await api.refresh(deviceID: deviceID, refreshToken: refreshToken)
    }
}

@Test func redirectsAndUnexpectedFinalOriginsAreRejected() async throws {
    let server = try RemoteServerURL("https://remote.example")
    let redirect = RemoteServerAPI(server: server) { request in response(request, json: "", status: 307) }
    await #expect(throws: RemoteAPIError.redirectRejected) {
        try await redirect.login(email: "person", password: "password")
    }
    let moved = RemoteServerAPI(server: server) { request in
        response(request, json: tokenJSON, url: URL(string: "https://different.example/api/v1/auth/refresh")!)
    }
    await #expect(throws: RemoteAPIError.redirectRejected) {
        try await moved.refresh(deviceID: deviceID, refreshToken: refreshToken)
    }
}

@Test func sessionDelegateNeverForwardsRedirectedRequests() async throws {
    let delegate = RemoteRedirectDelegate()
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let original = URL(string: "https://remote.example/api/v1/auth/login")!
    let task = session.dataTask(with: original)
    let redirect = HTTPURLResponse(url: original, statusCode: 307, httpVersion: nil, headerFields: nil)!
    var forwarded = URLRequest(url: URL(string: "https://other.example/collect")!)
    forwarded.httpBody = Data("password=secret".utf8)
    forwarded.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
    let result: URLRequest? = await withCheckedContinuation { continuation in
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: redirect, newRequest: forwarded) {
            continuation.resume(returning: $0)
        }
    }
    #expect(result == nil)
}

@Test func cancellationPropagatesWithoutRetry() async throws {
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { _ in
        throw CancellationError()
    }
    await #expect(throws: CancellationError.self) { try await api.listDevices(accessToken: accessToken) }
}

@Test func invalidLocalInputDoesNotReachTransport() async throws {
    let api = RemoteServerAPI(server: try RemoteServerURL("https://remote.example")) { _ in
        Issue.record("Invalid local input reached HTTP transport")
        throw CancellationError()
    }
    await #expect(throws: RemoteAPIError.self) { try await api.listDevices(accessToken: "short") }
    await #expect(throws: RemoteAPIError.self) { try await api.listDevices(accessToken: "long-enough-token\r\nInjected: value") }
    await #expect(throws: RemoteAPIError.self) { try await api.device(id: "../auth/login", accessToken: accessToken) }
    await #expect(throws: RemoteAPIError.self) { try await api.login(email: " ", password: "password") }
}

@Test func identityUsesX25519AndCanonicalBase64URL() throws {
    // RFC 7748 section 6.1 Alice key pair, not a live credential.
    let secret = dataFromHex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    let expectedPublic = dataFromHex("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
    let identity = try DeviceIdentity(deviceID: deviceID, name: " Phone ", privateKey: secret)
    #expect(identity.name == "Phone")
    #expect(identity.platform == "ios")
    #expect(identity.publicKey == Base64URL.encode(expectedPublic))
    #expect(identity.publicKey.count == 43)
    #expect(!identity.publicKey.contains("="))
    #expect(try identity.keyAgreementPrivateKey().publicKey.rawRepresentation == expectedPublic)
    #expect(try JSONDecoder().decode(DeviceIdentity.self, from: JSONEncoder().encode(identity)) == identity)
    #expect(identity.fingerprint == SHA256.hash(data: expectedPublic).prefix(6).map { String(format: "%02X", $0) }.joined())
    #expect(!String(reflecting: identity).contains(secret.base64EncodedString()))
    #expect(throws: RemoteAPIError.self) { try DeviceIdentity.generate(name: String(repeating: "鲸", count: 43)) }
}

@Test func credentialLifecycleIsIsolatedPerServerAndDevice() async throws {
    let storage = MemoryCredentialStorage()
    let store = CredentialStore(storage: storage)
    let one = try RemoteServerURL("https://one.example")
    let same = try RemoteServerURL("https://ONE.example:443/")
    let two = try RemoteServerURL("https://two.example")
    let identity = try await store.loadOrCreateIdentity(for: one, name: "Phone")
    let reloaded = try await store.loadOrCreateIdentity(for: same, name: "Unused name")
    #expect(identity == reloaded)
    let other = try await store.loadOrCreateIdentity(for: two, name: "Phone")
    #expect(identity.deviceId != other.deviceId)
    #expect(identity.publicKey != other.publicKey)
    let tokens = try JSONDecoder().decode(DeviceTokenPair.self, from: Data(tokenJSON.utf8))
    try await store.saveCredentials(tokens, for: one, deviceID: identity.deviceId)
    #expect(try await store.credentials(for: same, deviceID: identity.deviceId) == tokens)
    #expect(try await store.credentials(for: two, deviceID: other.deviceId) == nil)
    #expect(try await store.credentials(for: one, deviceID: other.deviceId) == nil)
    await #expect(throws: CredentialStoreError.identityMismatch) {
        try await store.saveCredentials(tokens, for: one, deviceID: other.deviceId)
    }
    let rotated = try DeviceTokenPair(accessToken: "rotated-access-token", accessTokenExpiresAt: 2_000_020_000_000,
                                      refreshToken: "rotated-refresh-token", refreshTokenExpiresAt: 2_000_030_000_000)
    try await store.saveCredentials(rotated, for: one, deviceID: identity.deviceId)
    #expect(try await store.credentials(for: one, deviceID: identity.deviceId) == rotated)
    let restoredStore = CredentialStore(storage: storage)
    #expect(try await restoredStore.identity(for: one) == identity)
    #expect(try await restoredStore.credentials(for: one, deviceID: identity.deviceId) == rotated)
    try await store.clearCredentials(for: one, deviceID: identity.deviceId)
    #expect(try await store.credentials(for: one, deviceID: identity.deviceId) == nil)
    #expect(try await store.identity(for: one) == identity)
    try await store.removeIdentity(for: one)
    try await store.removeIdentity(for: one)
    #expect(try await store.identity(for: one) == nil)
    #expect(try await store.identity(for: two) == other)
}

@Test func corruptOrUnavailableStorageDoesNotSilentlyReplaceIdentity() async throws {
    let storage = MemoryCredentialStorage()
    let store = CredentialStore(storage: storage)
    let server = try RemoteServerURL("https://remote.example")
    _ = try await store.loadOrCreateIdentity(for: server, name: "Phone")
    storage.corruptExistingRecords()
    await #expect(throws: CredentialStoreError.invalidStoredData) {
        try await store.loadOrCreateIdentity(for: server, name: "Replacement")
    }
    storage.setFailure(.keychain(errSecInteractionNotAllowed))
    await #expect(throws: CredentialStoreError.keychain(errSecInteractionNotAllowed)) {
        try await store.loadOrCreateIdentity(for: server, name: "Replacement")
    }
    await #expect(throws: CredentialStoreError.keychain(errSecInteractionNotAllowed)) {
        try await store.removeIdentity(for: server)
    }
}

private func dataFromHex(_ value: String) -> Data {
    let bytes = Array(value.utf8)
    return Data(stride(from: 0, to: bytes.count, by: 2).map { offset in
        UInt8(String(decoding: bytes[offset...offset + 1], as: UTF8.self), radix: 16)!
    })
}

/// Mutable test data is guarded by the lock; no user Keychain is touched by the test suite.
private final class MemoryCredentialStorage: CredentialStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    private var failure: CredentialStoreError?

    func load(key: String) throws -> Data? {
        try lock.withLock { if let failure { throw failure }; return values[key] }
    }
    func save(_ data: Data, key: String) throws {
        try lock.withLock { if let failure { throw failure }; values[key] = data }
    }
    func remove(key: String) throws {
        try lock.withLock { if let failure { throw failure }; values[key] = nil }
    }
    func corruptExistingRecords() {
        lock.withLock { values = values.mapValues { _ in Data("invalid JSON".utf8) } }
    }
    func setFailure(_ value: CredentialStoreError) { lock.withLock { failure = value } }
}
