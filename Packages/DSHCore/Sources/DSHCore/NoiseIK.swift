import CryptoKit
import Foundation

public enum NoiseIKError: Error, Equatable, Sendable {
    case invalidKey
    case invalidPrologue
    case invalidState
    case malformedMessage
    case messageTooLarge
    case authenticationFailed
    case nonceExhausted
    case closed
}

/// Initiator for the fixed DSH Remote v1 Noise suite.
///
/// Own this object on one serial executor (or use `SecureChannel`). Each instance
/// has exactly one handshake and one pair of transport counters. This narrow
/// implementation has tests against the pinned upstream vector; it has not
/// received an independent cryptographic audit. Closing releases key owners;
/// Swift and CryptoKit do not promise that all temporary copies are zeroized.
public final class NoiseIK {
    public static let protocolName = "Noise_IK_25519_ChaChaPoly_SHA256"
    public static let maximumMessageBytes = 65_535

    private enum Phase { case fresh, awaitingResponse, transport, closed }
    private var phase: Phase = .fresh
    private var localStatic: Curve25519.KeyAgreement.PrivateKey?
    private var ephemeral: Curve25519.KeyAgreement.PrivateKey?
    private var remoteStatic: Curve25519.KeyAgreement.PublicKey?
    private var symmetric: NoiseSymmetricState?

    // Internal visibility permits comparison to independently derived fixture
    // keys without adding a public API that exports traffic key material.
    private(set) var sendingCipher: NoiseCipherState?
    private(set) var receivingCipher: NoiseCipherState?

    public var isComplete: Bool { phase == .transport }
    public var sendingCounter: UInt64 { sendingCipher?.counter ?? 0 }
    public var receivingCounter: UInt64 { receivingCipher?.counter ?? 0 }

    public convenience init(
        localStaticPrivateKey: Data,
        remoteStaticPublicKey: Data,
        prologue: Data
    ) throws {
        try self.init(
            localStaticPrivateKey: localStaticPrivateKey,
            remoteStaticPublicKey: remoteStaticPublicKey,
            prologue: prologue,
            ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey()
        )
    }

    // Deterministic ephemeral injection is internal and used only by vector tests.
    init(
        localStaticPrivateKey: Data,
        remoteStaticPublicKey: Data,
        prologue: Data,
        ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey
    ) throws {
        guard localStaticPrivateKey.count == 32, remoteStaticPublicKey.count == 32 else {
            throw NoiseIKError.invalidKey
        }
        do {
            localStatic = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: localStaticPrivateKey)
            remoteStatic = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteStaticPublicKey)
        } catch {
            throw NoiseIKError.invalidKey
        }
        ephemeral = ephemeralPrivateKey
        var state = NoiseSymmetricState()
        state.mixHash(prologue)
        // IK pre-message: the initiator already trusts the responder static key.
        state.mixHash(remoteStaticPublicKey)
        symmetric = state
    }

    /// The identifiers must come from the same verified carrier connection.
    public static func makePrologue(
        connectionID: String,
        hostDeviceID: String,
        clientDeviceID: String
    ) throws -> Data {
        guard [connectionID, hostDeviceID, clientDeviceID].allSatisfy({
            !$0.isEmpty && !$0.contains("\0")
        }) else { throw NoiseIKError.invalidPrologue }
        return Data("DSH-REMOTE\0v=1\0connection=\(connectionID)\0host=\(hostDeviceID)\0client=\(clientDeviceID)".utf8)
    }

    /// Produces message 1: e, es, s, ss, followed by the encrypted payload.
    public func writeHandshake(payload: Data = Data()) throws -> Data {
        try requireLive()
        guard phase == .fresh, var state = symmetric,
              let localStatic, let ephemeral, let remoteStatic else {
            throw NoiseIKError.invalidState
        }
        guard payload.count <= Self.maximumMessageBytes - 96 else {
            throw NoiseIKError.messageTooLarge
        }
        do {
            var message = ephemeral.publicKey.rawRepresentation
            state.mixHash(message)
            try state.mixKey(Self.dh(ephemeral, remoteStatic))
            message.append(try state.encryptAndHash(localStatic.publicKey.rawRepresentation))
            try state.mixKey(Self.dh(localStatic, remoteStatic))
            message.append(try state.encryptAndHash(payload))
            symmetric = state
            phase = .awaitingResponse
            return message
        } catch {
            close()
            throw error
        }
    }

    /// Authenticates message 2 (e, ee, se) and installs the two traffic keys.
    /// Authentication is bound to the pinned responder static key and prologue.
    @discardableResult
    public func readHandshake(_ message: Data) throws -> Data {
        try requireLive()
        guard phase == .awaitingResponse, var state = symmetric,
              let localStatic, let ephemeral else { throw NoiseIKError.invalidState }
        do {
            guard message.count >= 48 else { throw NoiseIKError.malformedMessage }
            guard message.count <= Self.maximumMessageBytes else { throw NoiseIKError.messageTooLarge }
            let remoteEphemeralBytes = Data(message.prefix(32))
            let remoteEphemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remoteEphemeralBytes)
            state.mixHash(remoteEphemeralBytes)
            try state.mixKey(Self.dh(ephemeral, remoteEphemeral))
            try state.mixKey(Self.dh(localStatic, remoteEphemeral))
            let payload = try state.decryptAndHash(Data(message.dropFirst(32)))
            let keys = state.split()
            sendingCipher = NoiseCipherState(key: keys.0)
            receivingCipher = NoiseCipherState(key: keys.1)
            self.localStatic = nil
            self.ephemeral = nil
            remoteStatic = nil
            symmetric = nil
            phase = .transport
            return payload
        } catch {
            close()
            throw error
        }
    }

    public func encrypt(_ plaintext: Data) throws -> Data {
        try requireLive()
        guard isComplete else { throw NoiseIKError.invalidState }
        guard plaintext.count <= Self.maximumMessageBytes - 16 else {
            throw NoiseIKError.messageTooLarge
        }
        do {
            return try sendingCipher!.encrypt(plaintext)
        } catch {
            close()
            throw error
        }
    }

    /// A failed receive permanently closes this session. Start a new handshake
    /// after corruption, replay, reordering, or any carrier loss.
    public func decrypt(_ ciphertext: Data) throws -> Data {
        try requireLive()
        guard isComplete else { throw NoiseIKError.invalidState }
        do {
            guard ciphertext.count <= Self.maximumMessageBytes else { throw NoiseIKError.messageTooLarge }
            return try receivingCipher!.decrypt(ciphertext)
        } catch {
            close()
            throw error
        }
    }

    public func close() {
        phase = .closed
        localStatic = nil
        ephemeral = nil
        remoteStatic = nil
        symmetric = nil
        sendingCipher = nil
        receivingCipher = nil
    }

    private func requireLive() throws {
        guard phase != .closed else { throw NoiseIKError.closed }
    }

    private static func dh(
        _ secret: Curve25519.KeyAgreement.PrivateKey,
        _ peer: Curve25519.KeyAgreement.PublicKey
    ) throws -> Data {
        do {
            let shared = try secret.sharedSecretFromKeyAgreement(with: peer)
            let bytes = shared.withUnsafeBytes { Data($0) }
            // Reject non-contributory points even if a CryptoKit version accepts one.
            guard bytes.contains(where: { $0 != 0 }) else { throw NoiseIKError.invalidKey }
            return bytes
        } catch {
            throw NoiseIKError.invalidKey
        }
    }
}

/// Noise encodes a ChaChaPoly nonce as four zero bytes plus little-endian u64.
/// UInt64.max is reserved by Noise and may never be used for an application message.
struct NoiseCipherState {
    let key: SymmetricKey
    private(set) var counter: UInt64

    init(key: SymmetricKey, counter: UInt64 = 0) {
        self.key = key
        self.counter = counter
    }

    private func nonce() throws -> ChaChaPoly.Nonce {
        guard counter < UInt64.max else { throw NoiseIKError.nonceExhausted }
        let bytes = Data(repeating: 0, count: 4) + Data((0..<8).map {
            UInt8(truncatingIfNeeded: counter >> ($0 * 8))
        })
        return try ChaChaPoly.Nonce(data: bytes)
    }

    mutating func encrypt(_ plaintext: Data, authenticating ad: Data = Data()) throws -> Data {
        let sealed = try ChaChaPoly.seal(plaintext, using: key, nonce: nonce(), authenticating: ad)
        counter += 1
        return sealed.ciphertext + sealed.tag
    }

    mutating func decrypt(_ ciphertext: Data, authenticating ad: Data = Data()) throws -> Data {
        let currentNonce = try nonce()
        guard ciphertext.count >= 16 else { throw NoiseIKError.malformedMessage }
        do {
            let sealed = try ChaChaPoly.SealedBox(
                nonce: currentNonce,
                ciphertext: ciphertext.dropLast(16),
                tag: ciphertext.suffix(16)
            )
            let plaintext = try ChaChaPoly.open(sealed, using: key, authenticating: ad)
            counter += 1
            return plaintext
        } catch {
            throw NoiseIKError.authenticationFailed
        }
    }
}

private struct NoiseSymmetricState {
    private var chainingKey: Data
    private var hash: Data
    private var cipher: NoiseCipherState?

    init() {
        let name = Data(NoiseIK.protocolName.utf8)
        let initial = name.count <= 32
            ? name + Data(repeating: 0, count: 32 - name.count)
            : Data(SHA256.hash(data: name))
        chainingKey = initial
        hash = initial
    }

    mutating func mixHash(_ data: Data) {
        hash = Data(SHA256.hash(data: hash + data))
    }

    mutating func mixKey(_ data: Data) {
        let keys = hkdf(data)
        chainingKey = keys.0
        cipher = NoiseCipherState(key: SymmetricKey(data: keys.1))
    }

    mutating func encryptAndHash(_ plaintext: Data) throws -> Data {
        let ciphertext = try cipher?.encrypt(plaintext, authenticating: hash) ?? plaintext
        mixHash(ciphertext)
        return ciphertext
    }

    mutating func decryptAndHash(_ ciphertext: Data) throws -> Data {
        let plaintext = try cipher?.decrypt(ciphertext, authenticating: hash) ?? ciphertext
        mixHash(ciphertext)
        return plaintext
    }

    func split() -> (SymmetricKey, SymmetricKey) {
        let keys = hkdf(Data())
        return (SymmetricKey(data: keys.0), SymmetricKey(data: keys.1))
    }

    // Noise HKDF with two outputs, SHA-256, and empty info.
    private func hkdf(_ input: Data) -> (Data, Data) {
        let temporary = HMAC<SHA256>.authenticationCode(for: input, using: SymmetricKey(data: chainingKey))
        let key = SymmetricKey(data: temporary)
        let first = Data(HMAC<SHA256>.authenticationCode(for: Data([1]), using: key))
        let second = Data(HMAC<SHA256>.authenticationCode(for: first + Data([2]), using: key))
        return (first, second)
    }
}
