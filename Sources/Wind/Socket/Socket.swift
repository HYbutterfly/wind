import Darwin
import Foundation

let BACKLOG = Int32(32)

public enum SocketPacketHeadFormat {
    case none
    case bigEndian2byte
    case bigEndian4byte
    case littleEndian2byte
    case littleEndian4byte

    func size() -> Int {
        switch self {
        case .none:
            return 0
        case .bigEndian2byte:
            return 2
        case .littleEndian2byte:
            return 2
        case .bigEndian4byte:
            return 4
        case .littleEndian4byte:
            return 4
        }
    }
}

public struct Socket {
    let handle: Int32
    let headfmt: SocketPacketHeadFormat

    init(headfmt: SocketPacketHeadFormat) {
        self.headfmt = headfmt
        self.handle = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard self.handle != -1 else {
            fatalError("Error creating socket: \(errno)")
        }
    }

    func listen(port: UInt16) {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = INADDR_ANY
        addr.sin_port = in_port_t(port).bigEndian
        var reuse = 1
        if setsockopt(self.handle, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size)) == -1 {
            fatalError("Error setsockopt: \(errno)")
        }
        var result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(self.handle, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result != -1 else {
            fatalError("Error binding socket: \(errno)")
        }
        result = Darwin.listen(self.handle, BACKLOG)
        guard result != -1 else {
            fatalError("Error listen socket: \(errno)")
        }
    }

    func connect(host: String, port: UInt16) -> Int32? {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(self.handle, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if result == -1 {
            return nil
        }
        return self.handle
    }

    func accept() -> Int32 {
        var clientAddress = sockaddr()
        var clientAddressLength = socklen_t(MemoryLayout<sockaddr>.size)
        let clientSocket = Darwin.accept(self.handle, &clientAddress, &clientAddressLength)
        guard clientSocket != -1 else {
            fatalError("Error accepting connection: \(errno)")
        }
        return clientSocket
    }

    func read(_ fd: Int32, count: Int) -> (Int, [UInt8]) {
        var buffer = [UInt8](repeating: 0, count: count)
        let bytesRead = Darwin.read(fd, &buffer, count)
        if bytesRead > 0 {
            let data = buffer[0..<bytesRead]
            buffer = Array(data)
        }
        return (bytesRead, buffer)
    }

    func write(_ fd: Int32, buffer: [UInt8]) {
        var packet = buffer
        if let head = Util.socket_packet_head_encode(fmt: headfmt, length: buffer.count) {
            packet = head + packet
        }
        let bytesWritten = Darwin.write(fd, packet, packet.count)
        if bytesWritten < 0 {
            Util.print_errno(label: "Socket.write")
        }
    }

    func close(_ fd: Int32) {
        Darwin.close(fd)
    }
}
