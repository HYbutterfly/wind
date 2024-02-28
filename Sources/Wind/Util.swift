import Foundation

struct Util {
    static func print_errno(label: String) {
        print(String(format: "\(label) errno: %d, message: %@", errno, String(cString: strerror(errno))))
    }

    static func socket_packet_head_encode(fmt: SocketPacketHeadFormat, length: Int) -> [UInt8]? {
        switch fmt {
        case .none:
            return nil
        case .bigEndian2byte:
            var head = UInt16(length).bigEndian
            return withUnsafeBytes(of: &head) { Array($0) }
        case .bigEndian4byte:
            var head = UInt32(length).bigEndian
            return withUnsafeBytes(of: &head) { Array($0) }
        case .littleEndian2byte:
            var head = UInt16(length).littleEndian
            return withUnsafeBytes(of: &head) { Array($0) }
        case .littleEndian4byte:
            var head = UInt32(length).littleEndian
            return withUnsafeBytes(of: &head) { Array($0) }
        }
    }

    static func socket_packet_head_decode(fmt: SocketPacketHeadFormat, data: [UInt8], from: Int) -> Int? {
        let usable = data.count - from
        switch fmt {
        case .bigEndian2byte:
            if usable < 2 {
                return nil
            } else {
                let length = data[from..<data.count].withUnsafeBufferPointer {
                    $0.baseAddress!.withMemoryRebound(to: UInt16.self, capacity: 1) {
                        $0.pointee.bigEndian
                    }
                }
                return Int(length)
            }
        case .bigEndian4byte:
            if usable < 4 {
                return nil
            } else {
                let length = data[from..<data.count].withUnsafeBufferPointer {
                    $0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) {
                        $0.pointee.bigEndian
                    }
                }
                return Int(length)
            }
        case .littleEndian2byte:
            if usable < 2 {
                return nil
            } else {
                let length = data[from..<data.count].withUnsafeBufferPointer {
                    $0.baseAddress!.withMemoryRebound(to: UInt16.self, capacity: 1) {
                        $0.pointee.littleEndian
                    }
                }
                return Int(length)
            }
        case .littleEndian4byte:
            if usable < 4 {
                return nil
            } else {
                let length = data[from..<data.count].withUnsafeBufferPointer {
                    $0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) {
                        $0.pointee.littleEndian
                    }
                }
                return Int(length)
            }
        case .none:
            fatalError("SocketPacketHeadFormat is none")
        }
    }
}
