import CryptoKit
import Foundation

/// A per-server X25519 identity. The private key belongs in Keychain, never UserDefaults or logs.
/// This supplies the identity primitive; it does not implement the Noise IK handshake.
public struct DeviceIdentity: Codable, Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public let deviceId: String
    public let name: String
    public var platform: String { "ios" }
    public let publicKey: String
    private let privateKeyData: Data

    public var description: String { "DeviceIdentity(\(deviceId), privateKey: <redacted>)" }
    public var debugDescription: String { description }

    public static func generate(name: String) throws -> DeviceIdentity {
        let key = Curve25519.KeyAgreement.PrivateKey()
        return try DeviceIdentity(deviceID: UUID().uuidString.lowercased(), name: name,
                                  privateKey: key.rawRepresentation)
    }

    /// Restores a raw 32-byte X25519 secret. Public identity is always derived from the secret.
    public init(deviceID: String, name: String, privateKey: Data) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RemoteValidation.deviceID(deviceID), RemoteValidation.deviceName(name) else {
            throw RemoteAPIError.invalidInput("Use a valid device ID and a name of 1 to 128 UTF-8 bytes.")
        }
        let key = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        self.deviceId = deviceID
        self.name = name
        self.privateKeyData = key.rawRepresentation
        self.publicKey = Base64URL.encode(key.publicKey.rawRepresentation)
    }

    public func keyAgreementPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
    }

    /// Matches upstream identityFingerprint: first six SHA-256 bytes, uppercase hexadecimal.
    public var fingerprint: String {
        let bytes = Base64URL.decodeKey(publicKey)!
        return SHA256.hash(data: bytes).prefix(6).map { String(format: "%02X", $0) }.joined()
    }

    enum CodingKeys: String, CodingKey { case deviceId, name, privateKeyData }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(deviceID: values.decode(String.self, forKey: .deviceId),
                      name: values.decode(String.self, forKey: .name),
                      privateKey: values.decode(Data.self, forKey: .privateKeyData))
    }
}

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func decodeKey(_ value: String) -> Data? {
        guard value.utf8.count == 43 else { return nil }
        let base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "="
        guard let data = Data(base64Encoded: base64), data.count == 32, encode(data) == value else { return nil }
        return data
    }
}
