import Foundation

/// A normalized HTTPS origin. Paths, user information, queries and fragments are rejected.
public struct RemoteServerURL: Hashable, Sendable, Codable, CustomStringConvertible {
    public let url: URL
    public var description: String { url.absoluteString }

    public init(_ value: String) throws {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.contains(where: { $0.isWhitespace || $0.isNewline }),
              !value.contains("\\"),
              var components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/",
              components.port.map({ (1...65535).contains($0) }) ?? true else {
            throw RemoteAPIError.invalidServerURL
        }
        components.scheme = "https"
        components.host = host.lowercased()
        if components.port == 443 { components.port = nil }
        components.path = ""
        guard let url = components.url else { throw RemoteAPIError.invalidServerURL }
        self.url = url
    }

    public init(from decoder: any Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public enum RemoteAPIError: Error, Sendable, Equatable, LocalizedError {
    case invalidServerURL
    case invalidInput(String)
    case invalidResponse
    case redirectRejected
    case http(status: Int, code: String?, message: String?, retryable: Bool)

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            "Enter an HTTPS server address without a path, account information, query, or fragment."
        case .invalidInput(let message): message
        case .invalidResponse: "The Remote server returned an invalid response."
        case .redirectRejected: "The Remote server redirected the request. Use its final HTTPS address."
        case .http(let status, _, _, _):
            // Server strings are retained for inspection but are not automatically displayed:
            // a server or proxy can echo sensitive request data in an error response.
            "The Remote server rejected the request (HTTP \(status))."
        }
    }
}

public struct AccountLoginResult: Codable, Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { "AccountLoginResult(token: <redacted>)" }
    public var debugDescription: String { description }
    public let token: String
    /// Unix milliseconds, as returned by the Remote server.
    public let expiresAt: Int64
    public let account: String
    public let isAdmin: Bool

    enum CodingKeys: String, CodingKey { case token, expiresAt, account, isAdmin }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        token = try values.decode(String.self, forKey: .token)
        expiresAt = try values.decode(Int64.self, forKey: .expiresAt)
        account = try values.decode(String.self, forKey: .account)
        isAdmin = try values.decode(Bool.self, forKey: .isAdmin)
        guard RemoteValidation.token(token), RemoteValidation.timestamp(expiresAt), !account.isEmpty else {
            throw RemoteAPIError.invalidResponse
        }
    }
}

/// Remote device credentials only; these never contain a model provider API key.
public struct DeviceTokenPair: Codable, Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { "DeviceTokenPair(accessToken: <redacted>, refreshToken: <redacted>)" }
    public var debugDescription: String { description }
    public let accessToken: String
    public let accessTokenExpiresAt: Int64
    public let refreshToken: String
    public let refreshTokenExpiresAt: Int64

    public init(accessToken: String, accessTokenExpiresAt: Int64,
                refreshToken: String, refreshTokenExpiresAt: Int64) throws {
        guard RemoteValidation.token(accessToken), RemoteValidation.token(refreshToken),
              RemoteValidation.timestamp(accessTokenExpiresAt), RemoteValidation.timestamp(refreshTokenExpiresAt) else {
            throw RemoteAPIError.invalidResponse
        }
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.refreshToken = refreshToken
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
    }

    enum CodingKeys: String, CodingKey {
        case accessToken, accessTokenExpiresAt, refreshToken, refreshTokenExpiresAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            accessToken: values.decode(String.self, forKey: .accessToken),
            accessTokenExpiresAt: values.decode(Int64.self, forKey: .accessTokenExpiresAt),
            refreshToken: values.decode(String.self, forKey: .refreshToken),
            refreshTokenExpiresAt: values.decode(Int64.self, forKey: .refreshTokenExpiresAt)
        )
    }

    public func needsRefresh(at date: Date = .now, leeway: TimeInterval = 60) -> Bool {
        Double(accessTokenExpiresAt) / 1_000 <= date.timeIntervalSince1970 + leeway
    }

    public func canRefresh(at date: Date = .now) -> Bool {
        Double(refreshTokenExpiresAt) / 1_000 > date.timeIntervalSince1970
    }
}

/// Discovery metadata is not a trusted identity. Obtain and verify the peer key separately.
public struct RemoteDevice: Codable, Sendable, Equatable, Identifiable {
    public let deviceId: String
    public let name: String
    public let role: String
    public let platform: String
    public let membershipId: String
    public let online: Bool
    public let lastSeenAt: Int64?
    public let clientVersion: String?
    public let harnessVersion: String?
    public var id: String { deviceId }

    public init(deviceId: String, name: String, role: String = "host", platform: String,
                membershipId: String, online: Bool = false, lastSeenAt: Int64? = nil,
                clientVersion: String? = nil, harnessVersion: String? = nil) {
        self.deviceId = deviceId
        self.name = name
        self.role = role
        self.platform = platform
        self.membershipId = membershipId
        self.online = online
        self.lastSeenAt = lastSeenAt
        self.clientVersion = clientVersion
        self.harnessVersion = harnessVersion
    }

    enum CodingKeys: String, CodingKey {
        case deviceId, name, role, platform, membershipId, online, lastSeenAt, clientVersion, harnessVersion
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            deviceId: try values.decode(String.self, forKey: .deviceId),
            name: try values.decode(String.self, forKey: .name),
            role: try values.decode(String.self, forKey: .role),
            platform: try values.decode(String.self, forKey: .platform),
            membershipId: try values.decode(String.self, forKey: .membershipId),
            online: try values.decodeIfPresent(Bool.self, forKey: .online) ?? false,
            lastSeenAt: try values.decodeIfPresent(Int64.self, forKey: .lastSeenAt),
            clientVersion: try values.decodeIfPresent(String.self, forKey: .clientVersion),
            harnessVersion: try values.decodeIfPresent(String.self, forKey: .harnessVersion)
        )
        guard !deviceId.isEmpty, !name.isEmpty, !membershipId.isEmpty,
              role == "host" || role == "client" else { throw RemoteAPIError.invalidResponse }
    }
}

public struct AuthorizedPeerDevice: Codable, Sendable, Equatable, Identifiable {
    public let deviceId: String
    public let name: String
    public let role: String
    public let platform: String
    public let identityKey: String
    public let membershipId: String
    public let online: Bool?
    public let lastSeenAt: Int64?
    public let clientVersion: String?
    public let harnessVersion: String?
    public var id: String { deviceId }

    enum CodingKeys: String, CodingKey {
        case deviceId, name, role, platform, identityKey, membershipId, online, lastSeenAt, clientVersion, harnessVersion
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try values.decode(String.self, forKey: .deviceId)
        name = try values.decode(String.self, forKey: .name)
        role = try values.decode(String.self, forKey: .role)
        platform = try values.decode(String.self, forKey: .platform)
        identityKey = try values.decode(String.self, forKey: .identityKey)
        membershipId = try values.decode(String.self, forKey: .membershipId)
        online = try values.decodeIfPresent(Bool.self, forKey: .online)
        lastSeenAt = try values.decodeIfPresent(Int64.self, forKey: .lastSeenAt)
        clientVersion = try values.decodeIfPresent(String.self, forKey: .clientVersion)
        harnessVersion = try values.decodeIfPresent(String.self, forKey: .harnessVersion)
        guard !deviceId.isEmpty, !name.isEmpty, !membershipId.isEmpty,
              role == "host" || role == "client", Base64URL.decodeKey(identityKey) != nil else {
            throw RemoteAPIError.invalidResponse
        }
    }
}

/// REST schemas follow ds-harness-remote c374397dea2bea0e5a81adc993553be992102bc6.
/// No automatic retries: refresh tokens rotate, so a lost response needs explicit recovery.
public struct RemoteServerAPI: Sendable {
    public let server: RemoteServerURL
    private let transport: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public init(server: RemoteServerURL) {
        let client = RemoteHTTPSession()
        self.server = server
        self.transport = { request in try await client.send(request) }
    }

    /// Test seam. The production initializer always installs the redirect-rejecting delegate.
    init(server: RemoteServerURL,
         transport: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.server = server
        self.transport = transport
    }

    public func login(email: String, password: String) async throws -> AccountLoginResult {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...254).contains(email.utf16.count), (1...1024).contains(password.utf16.count) else {
            throw RemoteAPIError.invalidInput("Enter your Remote account and password.")
        }
        return try await request(path: "/api/v1/auth/login", body: LoginRequest(email: email, password: password))
    }

    public func register(identity: DeviceIdentity, accountToken: String,
                         clientVersion: String) async throws -> DeviceTokenPair {
        guard (1...64).contains(clientVersion.utf8.count) else {
            throw RemoteAPIError.invalidInput("The client version must contain between 1 and 64 UTF-8 bytes.")
        }
        let device = RegistrationRequest.Device(deviceId: identity.deviceId, name: identity.name,
                                                identityKey: identity.publicKey, clientVersion: clientVersion)
        return try await request(path: "/api/v1/devices/register", bearer: accountToken,
                                 body: RegistrationRequest(device: device))
    }

    public func refresh(deviceID: String, refreshToken: String) async throws -> DeviceTokenPair {
        guard RemoteValidation.deviceID(deviceID), RemoteValidation.token(refreshToken) else {
            throw RemoteAPIError.invalidInput("The Remote device credentials are invalid.")
        }
        return try await request(path: "/api/v1/auth/refresh",
                                 body: RefreshRequest(deviceId: deviceID, refreshToken: refreshToken))
    }

    public func listDevices(accessToken: String) async throws -> [RemoteDevice] {
        let result: DeviceList = try await request(path: "/api/v1/devices", bearer: accessToken)
        return result.items.filter { $0.role == "host" }
    }

    public func device(id: String, accessToken: String) async throws -> AuthorizedPeerDevice {
        guard RemoteValidation.deviceID(id) else {
            throw RemoteAPIError.invalidInput("The Remote device identifier is invalid.")
        }
        let peer: AuthorizedPeerDevice = try await request(path: "/api/v1/devices/\(id)", bearer: accessToken)
        guard peer.deviceId == id else { throw RemoteAPIError.invalidResponse }
        return peer
    }

    private func request<Response: Decodable>(path: String, bearer: String? = nil) async throws -> Response {
        try await send(path: path, bearer: bearer, body: nil)
    }

    private func request<Body: Encodable, Response: Decodable>(
        path: String, bearer: String? = nil, body: Body
    ) async throws -> Response {
        try await send(path: path, bearer: bearer, body: JSONEncoder().encode(body))
    }

    private func send<Response: Decodable>(path: String, bearer: String?, body: Data?) async throws -> Response {
        guard let url = URL(string: server.description + path) else { throw RemoteAPIError.invalidServerURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let bearer {
            guard RemoteValidation.token(bearer),
                  bearer.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
                throw RemoteAPIError.invalidInput("The Remote authorization token is invalid.")
            }
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await transport(request)
        guard !(300...399).contains(response.statusCode), response.url == url else {
            throw RemoteAPIError.redirectRejected
        }
        guard (200...299).contains(response.statusCode) else {
            let error = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw RemoteAPIError.http(status: response.statusCode, code: error?.error?.code ?? error?.code,
                                      message: error?.error?.message ?? error?.detail,
                                      retryable: error?.error?.retryable == true || response.statusCode == 429 || response.statusCode >= 500)
        }
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch { throw RemoteAPIError.invalidResponse }
    }
}

private struct LoginRequest: Encodable { let email: String; let password: String }
private struct RefreshRequest: Encodable { let deviceId: String; let refreshToken: String }
private struct RegistrationRequest: Encodable {
    let v = 1
    let device: Device
    struct Device: Encodable {
        let deviceId: String
        let name: String
        let role = "client"
        let platform = "ios"
        let identityKey: String
        let clientVersion: String
    }
}
private struct DeviceList: Decodable { let items: [RemoteDevice] }
private struct ErrorEnvelope: Decodable {
    let detail: String?
    let code: String?
    let error: Detail?
    struct Detail: Decodable { let code: String?; let message: String?; let retryable: Bool? }
}

/// Reject even same-origin redirects: 307/308 can forward passwords or refresh-token bodies.
final class RemoteRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private final class RemoteHTTPSession: Sendable {
    let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration, delegate: RemoteRedirectDelegate(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw RemoteAPIError.invalidResponse }
        return (data, response)
    }
}

// Bounds and encodings from packages/protocol/src/index.ts at the pinned revision.
enum RemoteValidation {
    static func token(_ value: String) -> Bool { (16...8192).contains(value.utf8.count) }
    static func timestamp(_ value: Int64) -> Bool { value > 0 && value <= 9_007_199_254_740_991 }
    static func deviceID(_ value: String) -> Bool {
        value.range(of: #"\A(?:[0-9A-HJKMNP-TV-Z]{26}|[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\z"#,
                    options: [.regularExpression, .caseInsensitive]) != nil
    }
    static func deviceName(_ value: String) -> Bool {
        (1...128).contains(value.utf8.count) && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
