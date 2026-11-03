import Foundation

public enum SecureChannelError: Error, Equatable, Sendable {
    case messageTooLarge
    case invalidFragment
    case fragmentOutOfOrder
    case tooManyIncompleteMessages
}

/// Serializes the Noise state and DSH Remote v1 secure fragmentation codec.
///
/// The carrier must send each returned frame array in order, serialize whole
/// `encryptMessage` + send operations, and close this channel after a failed send.
/// Actor isolation protects counters, but cannot order network I/O performed by
/// the caller after a method returns. Establish a new instance on reconnect.
public actor SecureChannel {
    public static let fragmentChunkBytes = 48 * 1024
    public static let maximumMessageBytes = 4 * 1024 * 1024

    private let noise: NoiseIK
    private var outgoing = SecureFragmentCodec()
    private var incoming = SecureFragmentCodec()

    public init(
        localStaticPrivateKey: Data,
        remoteStaticPublicKey: Data,
        connectionID: String,
        hostDeviceID: String,
        clientDeviceID: String
    ) throws {
        noise = try NoiseIK(
            localStaticPrivateKey: localStaticPrivateKey,
            remoteStaticPublicKey: remoteStaticPublicKey,
            prologue: NoiseIK.makePrologue(
                connectionID: connectionID,
                hostDeviceID: hostDeviceID,
                clientDeviceID: clientDeviceID
            )
        )
    }

    init(noise: sending NoiseIK) {
        self.noise = noise
    }

    public var isComplete: Bool { noise.isComplete }
    public var sendingCounter: UInt64 { noise.sendingCounter }
    public var receivingCounter: UInt64 { noise.receivingCounter }

    public func writeHandshake(payload: Data = Data()) throws -> Data {
        try noise.writeHandshake(payload: payload)
    }

    @discardableResult
    public func readHandshake(_ message: Data) throws -> Data {
        do {
            return try noise.readHandshake(message)
        } catch {
            close()
            throw error
        }
    }

    public func encryptMessage(_ message: Data) throws -> [Data] {
        let frames = try outgoing.encode(message)
        do {
            return try frames.map { try noise.encrypt($0) }
        } catch {
            close()
            throw error
        }
    }

    /// Returns nil until a fragmented message is complete. Any authentication
    /// or fragment error closes the channel and discards incomplete messages.
    public func decryptFrame(_ ciphertext: Data) throws -> Data? {
        do {
            return try incoming.decode(noise.decrypt(ciphertext))
        } catch {
            close()
            throw error
        }
    }

    public func close() {
        noise.close()
        outgoing = SecureFragmentCodec()
        incoming = SecureFragmentCodec()
    }
}

// Adapted from ds-harness-remote packages/protocol/src/index.ts at
// c374397dea2bea0e5a81adc993553be992102bc6. See THIRD_PARTY_NOTICES.txt.
// This framing reserves the DSHF prefix, as upstream does. Business messages
// are JSON; arbitrary short binary data starting with DSHF is not escaped.
struct SecureFragmentCodec {
    private static let magic = Data([0x44, 0x53, 0x48, 0x46])
    private static let headerBytes = 17
    private static let maximumAssemblies = 8
    private var nextMessageID: UInt32 = 1
    private var assemblies: [UInt32: Assembly] = [:]

    private struct Assembly {
        let total: Int
        let totalBytes: Int
        var nextIndex = 0
        var bytes = Data()
    }

    mutating func encode(_ message: Data) throws -> [Data] {
        guard message.count <= SecureChannel.maximumMessageBytes else {
            throw SecureChannelError.messageTooLarge
        }
        let chunkSize = SecureChannel.fragmentChunkBytes
        guard message.count > chunkSize else { return [message] }
        let messageID = nextMessageID
        nextMessageID = messageID == .max ? 1 : messageID + 1
        let total = (message.count + chunkSize - 1) / chunkSize
        return (0..<total).map { index in
            var frame = Self.magic
            frame.append(1)
            frame.append(Self.bigEndian(messageID, count: 4))
            frame.append(Self.bigEndian(UInt32(index), count: 2))
            frame.append(Self.bigEndian(UInt32(total), count: 2))
            frame.append(Self.bigEndian(UInt32(message.count), count: 4))
            frame.append(message.dropFirst(index * chunkSize).prefix(chunkSize))
            return frame
        }
    }

    mutating func decode(_ frame: Data) throws -> Data? {
        guard frame.starts(with: Self.magic) else { return frame }
        // Normalize the indices, since a caller may pass a Data slice.
        let bytes = [UInt8](frame)
        guard bytes.count >= Self.headerBytes, bytes[4] == 1 else {
            throw SecureChannelError.invalidFragment
        }
        let messageID = Self.readBigEndian(bytes, at: 5, count: 4)
        let index = Int(Self.readBigEndian(bytes, at: 9, count: 2))
        let total = Int(Self.readBigEndian(bytes, at: 11, count: 2))
        let totalBytes = Int(Self.readBigEndian(bytes, at: 13, count: 4))
        let chunkSize = SecureChannel.fragmentChunkBytes
        guard messageID != 0, total >= 2, index < total,
              totalBytes > chunkSize, totalBytes <= SecureChannel.maximumMessageBytes,
              total == (totalBytes + chunkSize - 1) / chunkSize,
              bytes.count - Self.headerBytes == min(chunkSize, totalBytes - index * chunkSize) else {
            throw SecureChannelError.invalidFragment
        }
        if assemblies[messageID] == nil {
            guard index == 0 else { throw SecureChannelError.fragmentOutOfOrder }
            guard assemblies.count < Self.maximumAssemblies else {
                throw SecureChannelError.tooManyIncompleteMessages
            }
            assemblies[messageID] = Assembly(total: total, totalBytes: totalBytes)
        }
        // Remove before mutation to avoid copying the full partial message on
        // each append. Invalid metadata also discards the partial assembly.
        var assembly = assemblies.removeValue(forKey: messageID)!
        guard assembly.total == total, assembly.totalBytes == totalBytes,
              assembly.nextIndex == index else { throw SecureChannelError.fragmentOutOfOrder }
        assembly.bytes.append(contentsOf: bytes.dropFirst(Self.headerBytes))
        assembly.nextIndex += 1
        guard assembly.nextIndex == total else {
            assemblies[messageID] = assembly
            return nil
        }
        guard assembly.bytes.count == totalBytes else { throw SecureChannelError.invalidFragment }
        return assembly.bytes
    }

    private static func bigEndian(_ value: UInt32, count: Int) -> Data {
        Data((0..<count).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
    }

    private static func readBigEndian(_ bytes: [UInt8], at offset: Int, count: Int) -> UInt32 {
        bytes[offset..<(offset + count)].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
