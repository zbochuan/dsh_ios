import CryptoKit
import Foundation
import Testing
@testable import DSHCore

struct NoiseIKTests {
    @Test func pinnedGoldenVectorMatchesHandshakeKeysTrafficAndCounters() throws {
        let fixture = try loadFixture()
        #expect(fixture.suite == NoiseIK.protocolName)
        #expect(fixture.fixtureFormatVersion == 1)
        #expect(fixture.protocolVersion == 1)
        #expect(!fixture.vectors.isEmpty)
        for vector in fixture.vectors {
            let prologue = try NoiseIK.makePrologue(
                connectionID: vector.prologue.connectionId,
                hostDeviceID: vector.prologue.hostDeviceId,
                clientDeviceID: vector.prologue.clientDeviceId
            )
            #expect(prologue == b64(vector.prologue.bytes))
            let initiator = try makeInitiator(vector)
            #expect(!initiator.isComplete)
            #expect(try initiator.writeHandshake(payload: b64(vector.handshake.message1.payload))
                == b64(vector.handshake.message1.message))

            // A separate responder calculation uses CryptoKit HKDF, does not
            // call production state/cipher helpers, and reproduces message 2.
            let responder = try referenceResponder(vector)
            #expect(responder.message2 == b64(vector.handshake.message2.message))
            #expect(responder.initiatorPayload == b64(vector.handshake.message1.payload))
            #expect(responder.initiatorStatic == b64(vector.staticKeys.initiator.publicKey))
            #expect(try initiator.readHandshake(responder.message2) == b64(vector.handshake.message2.payload))
            #expect(initiator.isComplete)
            #expect(initiator.sendingCounter == UInt64(vector.countersAfterHandshake.initiatorSending))
            #expect(initiator.receivingCounter == UInt64(vector.countersAfterHandshake.initiatorReceiving))
            #expect(try #require(initiator.sendingCipher).key.rawBytes == responder.initiatorSendingKey)
            #expect(try #require(initiator.receivingCipher).key.rawBytes == responder.responderSendingKey)

            for message in vector.transport {
                let referenceKey = message.sender == "initiator" ? responder.initiatorSendingKey : responder.responderSendingKey
                let referenceCounter = message.sender == "initiator" ? initiator.sendingCounter : initiator.receivingCounter
                #expect(try referenceSeal(b64(message.plaintext), key: referenceKey, counter: referenceCounter)
                    == b64(message.ciphertext))
                if message.sender == "initiator" {
                    #expect(try initiator.encrypt(b64(message.plaintext)) == b64(message.ciphertext))
                } else {
                    #expect(message.sender == "responder")
                    #expect(try initiator.decrypt(b64(message.ciphertext)) == b64(message.plaintext))
                }
                #expect(initiator.sendingCounter == UInt64(message.countersAfter.initiatorSending))
                #expect(initiator.receivingCounter == UInt64(message.countersAfter.initiatorReceiving))
            }
        }
    }

    @Test func nonceEncodingCorruptionAndExhaustionAreIndependentOfHandshake() throws {
        let key = SymmetricKey(data: Data(0..<32))
        let plaintext = Data("independent nonce check".utf8)
        let ad = Data("authenticated metadata".utf8)
        let counter: UInt64 = 0x0102_0304_0506_0708
        let explicitNonce = try ChaChaPoly.Nonce(data: Data([0, 0, 0, 0, 8, 7, 6, 5, 4, 3, 2, 1]))
        let reference = try ChaChaPoly.seal(plaintext, using: key, nonce: explicitNonce, authenticating: ad)
        let expected = reference.ciphertext + reference.tag
        var sender = NoiseCipherState(key: key, counter: counter)
        #expect(try sender.encrypt(plaintext, authenticating: ad) == expected)
        #expect(sender.counter == counter + 1)
        var receiver = NoiseCipherState(key: key, counter: counter)
        var corrupt = expected
        corrupt[corrupt.count - 1] ^= 1
        #expect(throws: NoiseIKError.authenticationFailed) {
            try receiver.decrypt(corrupt, authenticating: ad)
        }
        #expect(receiver.counter == counter)
        #expect(throws: NoiseIKError.authenticationFailed) {
            try receiver.decrypt(expected, authenticating: Data())
        }
        #expect(receiver.counter == counter)
        #expect(try receiver.decrypt(expected, authenticating: ad) == plaintext)
        #expect(receiver.counter == counter + 1)
        #expect(throws: NoiseIKError.authenticationFailed) {
            try receiver.decrypt(expected, authenticating: ad)
        }
        var finalNonce = NoiseCipherState(key: key, counter: .max - 1)
        _ = try finalNonce.encrypt(Data())
        #expect(finalNonce.counter == .max)
        #expect(throws: NoiseIKError.nonceExhausted) { try finalNonce.encrypt(Data()) }
        #expect(throws: NoiseIKError.nonceExhausted) { try finalNonce.decrypt(expected) }
    }

    @Test func corruptedOrReplayedTrafficClosesSession() throws {
        let vector = try firstVector()
        let session = try completedInitiator(vector)
        var corrupt = b64(vector.transport[1].ciphertext)
        corrupt[0] ^= 1
        #expect(throws: NoiseIKError.authenticationFailed) { try session.decrypt(corrupt) }
        #expect(!session.isComplete)
        #expect(session.sendingCipher == nil)
        #expect(session.receivingCipher == nil)
        #expect(throws: NoiseIKError.closed) { try session.decrypt(b64(vector.transport[1].ciphertext)) }
        #expect(throws: NoiseIKError.closed) { try session.encrypt(Data()) }

        let replay = try completedInitiator(vector)
        _ = try replay.decrypt(b64(vector.transport[1].ciphertext))
        #expect(throws: NoiseIKError.authenticationFailed) {
            try replay.decrypt(b64(vector.transport[1].ciphertext))
        }
        #expect(throws: NoiseIKError.closed) { try replay.encrypt(Data()) }

        let reordered = try completedInitiator(vector)
        let keys = try referenceResponder(vector)
        let secondFrame = try referenceSeal(Data("second".utf8), key: keys.responderSendingKey, counter: 1)
        #expect(throws: NoiseIKError.authenticationFailed) { try reordered.decrypt(secondFrame) }
        #expect(throws: NoiseIKError.closed) { try reordered.decrypt(b64(vector.transport[1].ciphertext)) }
    }

    @Test func handshakeRejectsCorruptionWrongPinAndWrongPrologue() throws {
        let vector = try firstVector()
        let session = try makeInitiator(vector)
        _ = try session.writeHandshake(payload: b64(vector.handshake.message1.payload))
        var corrupt = b64(vector.handshake.message2.message)
        corrupt[corrupt.count - 1] ^= 0x40
        #expect(throws: NoiseIKError.authenticationFailed) { try session.readHandshake(corrupt) }
        #expect(throws: NoiseIKError.closed) { try session.readHandshake(b64(vector.handshake.message2.message)) }

        for wrongPin in [false, true] {
            let other = try NoiseIK(
                localStaticPrivateKey: b64(vector.staticKeys.initiator.privateKey),
                remoteStaticPublicKey: b64(wrongPin ? vector.staticKeys.initiator.publicKey : vector.staticKeys.responder.publicKey),
                prologue: wrongPin ? b64(vector.prologue.bytes) : Data("wrong connection".utf8),
                ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey(rawRepresentation: b64(vector.ephemeralPrivateKeys.initiator))
            )
            _ = try other.writeHandshake(payload: b64(vector.handshake.message1.payload))
            #expect(throws: NoiseIKError.authenticationFailed) {
                try other.readHandshake(b64(vector.handshake.message2.message))
            }
            #expect(!other.isComplete)
        }
    }

    @Test func handshakeOrderSizeAndKeyValidation() throws {
        let vector = try firstVector()
        let session = try makeInitiator(vector)
        #expect(throws: NoiseIKError.invalidState) { try session.encrypt(Data()) }
        #expect(throws: NoiseIKError.invalidState) { try session.readHandshake(Data()) }
        #expect(throws: NoiseIKError.messageTooLarge) {
            try session.writeHandshake(payload: Data(repeating: 0, count: 65_535 - 95))
        }
        _ = try session.writeHandshake()
        #expect(throws: NoiseIKError.invalidState) { try session.writeHandshake() }
        #expect(throws: NoiseIKError.malformedMessage) { try session.readHandshake(Data(repeating: 0, count: 47)) }
        #expect(throws: NoiseIKError.closed) { try session.writeHandshake() }
        #expect(throws: NoiseIKError.invalidKey) {
            try NoiseIK(localStaticPrivateKey: Data(), remoteStaticPublicKey: Data(repeating: 0, count: 32), prologue: Data())
        }
        let zeroPoint = try NoiseIK(
            localStaticPrivateKey: b64(vector.staticKeys.initiator.privateKey),
            remoteStaticPublicKey: Data(repeating: 0, count: 32), prologue: Data()
        )
        #expect(throws: NoiseIKError.invalidKey) { try zeroPoint.writeHandshake() }
        #expect(throws: NoiseIKError.closed) { try zeroPoint.writeHandshake() }
        #expect(throws: NoiseIKError.invalidPrologue) {
            try NoiseIK.makePrologue(connectionID: "", hostDeviceID: "host", clientDeviceID: "client")
        }
        #expect(throws: NoiseIKError.invalidPrologue) {
            try NoiseIK.makePrologue(connectionID: "connection", hostDeviceID: "host\0alias", clientDeviceID: "client")
        }
    }

    @Test func fragmentationBoundariesAndExactWireHeader() throws {
        let chunk = SecureChannel.fragmentChunkBytes
        for count in [0, chunk, chunk + 1, SecureChannel.maximumMessageBytes] {
            let message = Data((0..<count).map { UInt8(truncatingIfNeeded: $0) })
            var sender = SecureFragmentCodec()
            var receiver = SecureFragmentCodec()
            let frames = try sender.encode(message)
            #expect(frames.count == max(1, (count + chunk - 1) / chunk))
            if count == chunk + 1 {
                #expect(frames[0].prefix(17) == Data([
                    0x44, 0x53, 0x48, 0x46, 1, 0, 0, 0, 1,
                    0, 0, 0, 2, 0, 0, 0xc0, 1
                ]))
                #expect(frames[1].count == 18)
            }
            for (index, frame) in frames.enumerated() {
                let decoded = try receiver.decode(frame)
                if index == frames.count - 1 { #expect(decoded == message) }
                else { #expect(decoded == nil) }
            }
        }
        var codec = SecureFragmentCodec()
        #expect(throws: SecureChannelError.messageTooLarge) {
            try codec.encode(Data(repeating: 0, count: SecureChannel.maximumMessageBytes + 1))
        }
    }

    @Test func fragmentsRejectInvalidMetadataOrderingAndExcessAssemblies() throws {
        var sender = SecureFragmentCodec()
        let frames = try sender.encode(Data(repeating: 0xab, count: SecureChannel.fragmentChunkBytes + 1))
        var receiver = SecureFragmentCodec()
        #expect(throws: SecureChannelError.fragmentOutOfOrder) { try receiver.decode(frames[1]) }
        #expect(try receiver.decode(frames[0]) == nil)
        #expect(throws: SecureChannelError.fragmentOutOfOrder) { try receiver.decode(frames[0]) }
        #expect(throws: SecureChannelError.fragmentOutOfOrder) { try receiver.decode(frames[1]) }
        var truncated = frames[0]
        truncated.removeLast()
        #expect(throws: SecureChannelError.invalidFragment) { try receiver.decode(truncated) }
        var wrongVersion = frames[0]
        wrongVersion[4] = 2
        #expect(throws: SecureChannelError.invalidFragment) { try receiver.decode(wrongVersion) }
        #expect(throws: SecureChannelError.invalidFragment) { try receiver.decode(Data("DSHF".utf8)) }
        for _ in 0..<8 {
            let first = try sender.encode(Data(repeating: 0, count: SecureChannel.fragmentChunkBytes + 1))[0]
            #expect(try receiver.decode(first) == nil)
        }
        let ninth = try sender.encode(Data(repeating: 0, count: SecureChannel.fragmentChunkBytes + 1))[0]
        #expect(throws: SecureChannelError.tooManyIncompleteMessages) { try receiver.decode(ninth) }
    }

    @Test func channelEncryptsFragmentsAndReassemblesAuthenticatedFrames() async throws {
        let vector = try firstVector()
        let keys = try referenceResponder(vector)
        let channel = SecureChannel(noise: try completedInitiator(vector))
        let message = Data(repeating: 0x61, count: SecureChannel.fragmentChunkBytes + 19)
        let encrypted = try await channel.encryptMessage(message)
        #expect(encrypted.count == 2)
        var decoder = SecureFragmentCodec()
        for (index, frame) in encrypted.enumerated() {
            let plaintext = try referenceOpen(frame, key: keys.initiatorSendingKey, counter: UInt64(index))
            let decoded = try decoder.decode(plaintext)
            #expect(decoded == (index == encrypted.count - 1 ? message : nil))
        }
        var encoder = SecureFragmentCodec()
        let replyFrames = try encoder.encode(message)
        for (index, frame) in replyFrames.enumerated() {
            let encrypted = try referenceSeal(frame, key: keys.responderSendingKey, counter: UInt64(index))
            let result = try await channel.decryptFrame(encrypted)
            #expect(result == (index == replyFrames.count - 1 ? message : nil))
        }
        #expect(await channel.sendingCounter == 2)
        #expect(await channel.receivingCounter == 2)
        // This frame authenticates correctly, but its fragment header is invalid.
        let malformed = try referenceSeal(Data("DSHF".utf8), key: keys.responderSendingKey, counter: 2)
        do {
            _ = try await channel.decryptFrame(malformed)
            Issue.record("Authenticated malformed fragment was accepted")
        } catch { #expect(error as? SecureChannelError == .invalidFragment) }
        #expect(await channel.isComplete == false)
        do {
            _ = try await channel.encryptMessage(Data())
            Issue.record("Channel remained usable after invalid fragment")
        } catch { #expect(error as? NoiseIKError == .closed) }
    }
}

private struct Fixture: Decodable {
    let fixtureFormatVersion: Int
    let protocolVersion: Int
    let suite: String
    let vectors: [Vector]
}

private struct Vector: Decodable {
    struct Pair: Decodable { let privateKey: String; let publicKey: String }
    struct StaticKeys: Decodable { let initiator: Pair; let responder: Pair }
    struct Ephemeral: Decodable { let initiator: String; let responder: String }
    struct Prologue: Decodable { let connectionId: String; let hostDeviceId: String; let clientDeviceId: String; let bytes: String }
    struct HandshakeMessage: Decodable { let payload: String; let message: String }
    struct Handshake: Decodable { let message1: HandshakeMessage; let message2: HandshakeMessage }
    struct Counters: Decodable { let initiatorSending: String; let initiatorReceiving: String }
    struct Transport: Decodable { let sender: String; let plaintext: String; let ciphertext: String; let countersAfter: Counters }
    let staticKeys: StaticKeys
    let ephemeralPrivateKeys: Ephemeral
    let prologue: Prologue
    let handshake: Handshake
    let countersAfterHandshake: Counters
    let transport: [Transport]
}

private func loadFixture() throws -> Fixture {
    let url = try #require(Bundle.module.url(forResource: "noise-ik", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
}

private func firstVector() throws -> Vector { try #require(loadFixture().vectors.first) }

private func b64(_ input: String) -> Data {
    let base = input.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    return Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4))!
}

private func makeInitiator(_ vector: Vector) throws -> NoiseIK {
    try NoiseIK(
        localStaticPrivateKey: b64(vector.staticKeys.initiator.privateKey),
        remoteStaticPublicKey: b64(vector.staticKeys.responder.publicKey),
        prologue: b64(vector.prologue.bytes),
        ephemeralPrivateKey: Curve25519.KeyAgreement.PrivateKey(rawRepresentation: b64(vector.ephemeralPrivateKeys.initiator))
    )
}

private func completedInitiator(_ vector: Vector) throws -> NoiseIK {
    let session = try makeInitiator(vector)
    _ = try session.writeHandshake(payload: b64(vector.handshake.message1.payload))
    _ = try session.readHandshake(b64(vector.handshake.message2.message))
    return session
}

private extension SymmetricKey {
    var rawBytes: Data { withUnsafeBytes { Data($0) } }
}

private struct ReferenceResult {
    let message2: Data
    let initiatorPayload: Data
    let initiatorStatic: Data
    let initiatorSendingKey: Data
    let responderSendingKey: Data
}

/// A deliberately independent responder calculation for this fixture. Production
/// code implements only the initiator and uses manual HMAC expansion; this uses
/// CryptoKit's HKDF and explicit transcript operations on the responder side.
/// The upstream fixture contains no raw transport keys: comparison here derives
/// them separately, while fixture ciphertexts independently anchor both keys.
private func referenceResponder(_ vector: Vector) throws -> ReferenceResult {
    let responderStatic = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: b64(vector.staticKeys.responder.privateKey))
    let responderEphemeral = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: b64(vector.ephemeralPrivateKeys.responder))
    let message1 = b64(vector.handshake.message1.message)
    let initiatorEphemeralBytes = Data(message1.prefix(32))
    let initiatorEphemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: initiatorEphemeralBytes)
    var hash = Data("Noise_IK_25519_ChaChaPoly_SHA256".utf8)
    hash.append(Data(repeating: 0, count: 32 - hash.count))
    var chainingKey = hash
    hash = Data(SHA256.hash(data: hash + b64(vector.prologue.bytes)))
    hash = Data(SHA256.hash(data: hash + responderStatic.publicKey.rawRepresentation))
    hash = Data(SHA256.hash(data: hash + initiatorEphemeralBytes))

    var derived = referenceHKDF(try referenceDH(responderStatic, initiatorEphemeral), salt: chainingKey)
    chainingKey = derived.0
    let staticCiphertext = Data(message1.dropFirst(32).prefix(48))
    let initiatorStaticBytes = try referenceOpen(staticCiphertext, key: derived.1, counter: 0, ad: hash)
    hash = Data(SHA256.hash(data: hash + staticCiphertext))
    let initiatorStatic = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: initiatorStaticBytes)
    derived = referenceHKDF(try referenceDH(responderStatic, initiatorStatic), salt: chainingKey)
    chainingKey = derived.0
    let payloadCiphertext = Data(message1.dropFirst(80))
    let initiatorPayload = try referenceOpen(payloadCiphertext, key: derived.1, counter: 0, ad: hash)
    hash = Data(SHA256.hash(data: hash + payloadCiphertext))

    let ephemeralBytes = responderEphemeral.publicKey.rawRepresentation
    hash = Data(SHA256.hash(data: hash + ephemeralBytes))
    derived = referenceHKDF(try referenceDH(responderEphemeral, initiatorEphemeral), salt: chainingKey)
    chainingKey = derived.0
    derived = referenceHKDF(try referenceDH(responderEphemeral, initiatorStatic), salt: chainingKey)
    chainingKey = derived.0
    let response = try referenceSeal(b64(vector.handshake.message2.payload), key: derived.1, counter: 0, ad: hash)
    let traffic = referenceHKDF(Data(), salt: chainingKey)
    return ReferenceResult(
        message2: ephemeralBytes + response,
        initiatorPayload: initiatorPayload,
        initiatorStatic: initiatorStaticBytes,
        initiatorSendingKey: traffic.0,
        responderSendingKey: traffic.1
    )
}

private func referenceDH(_ secret: Curve25519.KeyAgreement.PrivateKey, _ peer: Curve25519.KeyAgreement.PublicKey) throws -> Data {
    try secret.sharedSecretFromKeyAgreement(with: peer).withUnsafeBytes { Data($0) }
}

private func referenceHKDF(_ input: Data, salt: Data) -> (Data, Data) {
    let bytes = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: input), salt: salt, info: Data(), outputByteCount: 64).rawBytes
    return (Data(bytes.prefix(32)), Data(bytes.suffix(32)))
}

private func referenceNonce(_ counter: UInt64) throws -> ChaChaPoly.Nonce {
    var littleEndian = counter.littleEndian
    let encoded = withUnsafeBytes(of: &littleEndian) { Data($0) }
    return try ChaChaPoly.Nonce(data: Data(repeating: 0, count: 4) + encoded)
}

private func referenceSeal(_ plaintext: Data, key: Data, counter: UInt64, ad: Data = Data()) throws -> Data {
    let box = try ChaChaPoly.seal(plaintext, using: SymmetricKey(data: key), nonce: referenceNonce(counter), authenticating: ad)
    return box.ciphertext + box.tag
}

private func referenceOpen(_ ciphertext: Data, key: Data, counter: UInt64, ad: Data = Data()) throws -> Data {
    let box = try ChaChaPoly.SealedBox(nonce: referenceNonce(counter), ciphertext: ciphertext.dropLast(16), tag: ciphertext.suffix(16))
    return try ChaChaPoly.open(box, using: SymmetricKey(data: key), authenticating: ad)
}
