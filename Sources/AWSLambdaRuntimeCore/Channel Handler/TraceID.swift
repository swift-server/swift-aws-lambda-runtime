import Dispatch

enum XRay {
    enum Error: Swift.Error {
        case traceIDHasInvalidLength
        case traceIDHasInvalidVersion
        case segmentIDHasInvalidLength
        case traceHasNoDashesAtExpectedPositions
    }
}

// MARK: - XRay.TraceID -
extension XRay {
    struct TraceID {
        typealias Identifier = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

        let version: UInt8
        let timestamp: UInt32
        let identifier: Identifier
    }
}

extension XRay.TraceID {
    init() {
        self.version = 1
        // The time of the original request, in Unix epoch time, in 8 hexadecimal digits.
        self.timestamp = UInt32(DispatchWallTime.now().millisSinceEpoch / 1000)

        var _identifier: Identifier = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        withUnsafeMutableBytes(of: &_identifier) { ptr in
            ptr.storeBytes(of: XRay.generator.next(), toByteOffset: 0, as: UInt64.self)
            ptr.storeBytes(of: XRay.generator.next(upperBound: UInt32.max), toByteOffset: 8, as: UInt32.self)
        }

        self.identifier = _identifier
    }

    init<S: StringProtocol>(trace: S) throws {
        self = try Self.fromString(trace)
    }

    private static func fromString<S: StringProtocol>(_ string: S) throws -> XRay.TraceID {
        let result = try string.utf8.withContiguousStorageIfAvailable { (trace) -> XRay.TraceID in
            guard trace.count == 35 else { // invalid length
                throw XRay.Error.traceIDHasInvalidLength
            }

            guard trace[0] == UInt8(ascii: "1") else {
                throw XRay.Error.traceIDHasInvalidVersion
            }

            guard trace[1] == UInt8(ascii: "-"), trace[10] == UInt8(ascii: "-") else {
                throw XRay.Error.traceHasNoDashesAtExpectedPositions
            }

            let timestamp: UInt32 = Self.hexNumberToUInt32(ascii: trace[2 ..< 10])

            var identifier: Identifier = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            withUnsafeMutableBytes(of: &identifier) { ptr in
                XRay.asciiHexToBytes(ascii: trace[11 ..< 35], target: ptr)
            }

            return XRay.TraceID(version: 1, timestamp: timestamp, identifier: identifier)
        }

        guard let r = result else {
            let trace = String(string)
            return try Self.fromString(trace)
        }

        return r
    }

    private static func hexNumberToUInt32<T: RandomAccessCollection>(ascii: T) -> UInt32 where T.Element == UInt8 {
        assert(ascii.count == 8, "Target needs half as much space as ascii")
        var exp = ascii.count - 1
        var source = ascii.makeIterator()
        var result: UInt32 = 0

        while let value = source.next() {
            var byte: UInt8 = 0

            switch value {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                byte = (value - UInt8(ascii: "0"))
            case UInt8(ascii: "a") ... UInt8(ascii: "f"):
                byte = (value - UInt8(ascii: "a") + 10)
            default:
                preconditionFailure()
            }

            result |= UInt32(byte) << (exp * 4)
            exp -= 1
        }

        assert(exp == -1)
        return result
    }
}

extension XRay.TraceID: Equatable {
    static func == (lhs: XRay.TraceID, rhs: XRay.TraceID) -> Bool {
        guard lhs.version == rhs.version else {
            return false
        }

        guard lhs.timestamp == rhs.timestamp else {
            return false
        }

        return lhs.identifier.0 == rhs.identifier.0
            && lhs.identifier.1 == rhs.identifier.1
            && lhs.identifier.2 == rhs.identifier.2
            && lhs.identifier.3 == rhs.identifier.3
            && lhs.identifier.4 == rhs.identifier.4
            && lhs.identifier.5 == rhs.identifier.5
            && lhs.identifier.6 == rhs.identifier.6
            && lhs.identifier.7 == rhs.identifier.7
            && lhs.identifier.8 == rhs.identifier.8
            && lhs.identifier.9 == rhs.identifier.9
            && lhs.identifier.10 == rhs.identifier.10
            && lhs.identifier.11 == rhs.identifier.11
    }
}

extension XRay.TraceID: CustomStringConvertible {
    private typealias FixedSizeStringArray = (UInt64, UInt64, UInt64, UInt64, UInt8, UInt8, UInt8)

    var description: String {
        var bytes: FixedSizeStringArray = (0, 0, 0, 0, 0, 0, 0)
        return withUnsafeMutableBytes(of: &bytes) { (ptr) -> String in
            self.writeIntoUnsafePointer(ptr: ptr)
            return String(decoding: ptr, as: Unicode.UTF8.self)
        }
    }

    func writeIntoUnsafePointer(ptr: UnsafeMutableRawBufferPointer) {
        assert(ptr.count >= 35)

        ptr[0] = UInt8(ascii: "1")
        ptr[1] = UInt8(ascii: "-")
        ptr[2] = XRay.hexLookup[Int(timestamp >> 28)]
        ptr[3] = XRay.hexLookup[Int(timestamp >> 24) & 0x0F]
        ptr[4] = XRay.hexLookup[Int(timestamp >> 20) & 0x0F]
        ptr[5] = XRay.hexLookup[Int(timestamp >> 16) & 0x0F]
        ptr[6] = XRay.hexLookup[Int(timestamp >> 12) & 0x0F]
        ptr[7] = XRay.hexLookup[Int(timestamp >> 8) & 0x0F]
        ptr[8] = XRay.hexLookup[Int(timestamp >> 4) & 0x0F]
        ptr[9] = XRay.hexLookup[Int(timestamp & 0x0F)]
        ptr[10] = UInt8(ascii: "-")
        ptr[11] = XRay.hexLookup[Int(identifier.0 >> 4)]
        ptr[12] = XRay.hexLookup[Int(identifier.0 & 0x0F)]
        ptr[13] = XRay.hexLookup[Int(identifier.1 >> 4)]
        ptr[14] = XRay.hexLookup[Int(identifier.1 & 0x0F)]
        ptr[15] = XRay.hexLookup[Int(identifier.2 >> 4)]
        ptr[16] = XRay.hexLookup[Int(identifier.2 & 0x0F)]
        ptr[17] = XRay.hexLookup[Int(identifier.3 >> 4)]
        ptr[18] = XRay.hexLookup[Int(identifier.3 & 0x0F)]
        ptr[19] = XRay.hexLookup[Int(identifier.4 >> 4)]
        ptr[20] = XRay.hexLookup[Int(identifier.4 & 0x0F)]
        ptr[21] = XRay.hexLookup[Int(identifier.5 >> 4)]
        ptr[22] = XRay.hexLookup[Int(identifier.5 & 0x0F)]
        ptr[23] = XRay.hexLookup[Int(identifier.6 >> 4)]
        ptr[24] = XRay.hexLookup[Int(identifier.6 & 0x0F)]
        ptr[25] = XRay.hexLookup[Int(identifier.7 >> 4)]
        ptr[26] = XRay.hexLookup[Int(identifier.7 & 0x0F)]
        ptr[27] = XRay.hexLookup[Int(identifier.8 >> 4)]
        ptr[28] = XRay.hexLookup[Int(identifier.8 & 0x0F)]
        ptr[29] = XRay.hexLookup[Int(identifier.9 >> 4)]
        ptr[30] = XRay.hexLookup[Int(identifier.9 & 0x0F)]
        ptr[31] = XRay.hexLookup[Int(identifier.10 >> 4)]
        ptr[32] = XRay.hexLookup[Int(identifier.10 & 0x0F)]
        ptr[33] = XRay.hexLookup[Int(identifier.11 >> 4)]
        ptr[34] = XRay.hexLookup[Int(identifier.11 & 0x0F)]
    }
}

// MARK: - XRay.SegmentID -
extension XRay {
    struct SegmentID: RawRepresentable, Equatable {
        typealias RawValue = UInt64

        var rawValue: UInt64

        init() {
            self.rawValue = XRay.generator.next()
        }

        init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        init<S: StringProtocol>(string: S) throws {
            self = try Self.fromString(string)
        }

        private static func fromString<S: StringProtocol>(_ string: S) throws -> XRay.SegmentID {
            let result = try string.utf8.withContiguousStorageIfAvailable { (trace) -> XRay.SegmentID in
                guard trace.count == 16 else { // invalid length
                    throw XRay.Error.segmentIDHasInvalidLength
                }

                var _segmentID: UInt64 = 0
                withUnsafeMutableBytes(of: &_segmentID) { ptr in
                    XRay.asciiHexToBytes(ascii: trace[0 ..< 16], target: ptr)
                }

                return XRay.SegmentID(rawValue: _segmentID)
            }

            guard let r = result else {
                let segment = String(string)
                return try Self.fromString(segment)
            }

            return r
        }

        var stringValue: String {
            var bytes: (UInt64, UInt64) = (0, 0)

            return withUnsafeMutableBytes(of: &bytes) { (ptr) -> String in
                self.writeIntoUnsafePointer(ptr: ptr)
                return String(decoding: ptr, as: Unicode.UTF8.self)
            }
        }

        func writeIntoUnsafePointer(ptr: UnsafeMutableRawBufferPointer) {
            assert(ptr.count >= 16)

            let rawValue = self.rawValue.bigEndian
            // TODO: I've no idea if that's an approach i like
            //       maybe just shift in the other direction.
            ptr[0] = XRay.hexLookup[Int(rawValue >> 60)]
            ptr[1] = XRay.hexLookup[Int((rawValue >> 56) & 0x0F)]
            ptr[2] = XRay.hexLookup[Int((rawValue >> 52) & 0x0F)]
            ptr[3] = XRay.hexLookup[Int((rawValue >> 48) & 0x0F)]
            ptr[4] = XRay.hexLookup[Int((rawValue >> 44) & 0x0F)]
            ptr[5] = XRay.hexLookup[Int((rawValue >> 40) & 0x0F)]
            ptr[6] = XRay.hexLookup[Int((rawValue >> 36) & 0x0F)]
            ptr[7] = XRay.hexLookup[Int((rawValue >> 32) & 0x0F)]
            ptr[8] = XRay.hexLookup[Int((rawValue >> 28) & 0x0F)]
            ptr[9] = XRay.hexLookup[Int((rawValue >> 24) & 0x0F)]
            ptr[10] = XRay.hexLookup[Int((rawValue >> 20) & 0x0F)]
            ptr[11] = XRay.hexLookup[Int((rawValue >> 16) & 0x0F)]
            ptr[12] = XRay.hexLookup[Int((rawValue >> 12) & 0x0F)]
            ptr[13] = XRay.hexLookup[Int((rawValue >> 8) & 0x0F)]
            ptr[14] = XRay.hexLookup[Int((rawValue >> 4) & 0x0F)]
            ptr[15] = XRay.hexLookup[Int(rawValue & 0x0F)]
        }
    }
}

extension XRay.SegmentID: CustomStringConvertible {
    var description: String {
        self.stringValue
    }
}

// MARK: - SampleDecision -
extension XRay {
    internal enum SampleDecision {
        case sample // 1
        case reject // 0
        case unknown // empty
        case requested // "?" value not document, spotted in https://github.com/aws/aws-xray-sdk-java/blob/829f4c92f099349dbb14d6efd5c19e8452c3f6bc/aws-xray-recorder-sdk-core/src/main/java/com/amazonaws/xray/entities/TraceHeader.java#L41
        init<S: StringProtocol>(string: S) throws {
            switch string {
            case "1":
                self = .sample
            case "0":
                self = .reject
            case "?":
                self = .requested
            case "":
                self = .unknown
            default:
                preconditionFailure()
            }
        }

        var stringValue: String {
            switch self {
            case .sample:
                return "1"
            case .reject:
                return "0"
            case .requested:
                return "?"
            case .unknown:
                return ""
            }
        }
    }
}

// MARK: - Utils -
extension XRay {
    private static let hexLookup: [UInt8] = [
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "a"), UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"),
    ]

    /// thread safe secure random number generator.
    private static var generator = SystemRandomNumberGenerator()

    private static func asciiHexToBytes<T: RandomAccessCollection>(ascii: T, target: UnsafeMutableRawBufferPointer) where T.Element == UInt8 {
        assert(ascii.count / 2 == target.count, "Target needs half as much space as ascii")

        var source = ascii.makeIterator()
        var targetIndex = 0

        while let major = source.next(), let minor = source.next() {
            var byte: UInt8 = 0

            switch major {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                byte = (major - UInt8(ascii: "0")) << 4
            case UInt8(ascii: "a") ... UInt8(ascii: "f"):
                byte = (major - UInt8(ascii: "a") + 10) << 4
            default:
                preconditionFailure()
            }

            switch minor {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                byte |= (minor - UInt8(ascii: "0"))
            case UInt8(ascii: "a") ... UInt8(ascii: "f"):
                byte |= (minor - UInt8(ascii: "a") + 10)
            default:
                preconditionFailure()
            }

            target[targetIndex] = byte
            targetIndex += 1
        }
    }
}
