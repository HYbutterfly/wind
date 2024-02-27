import Darwin
import Foundation

let BACKLOG = Int32(32)

public struct Socket {
    let handle: Int32

    init() {
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

    static func read(_ fd: Int32, count: Int) -> (Int, [UInt8]) {
        var buffer = [UInt8](repeating: 0, count: count)
        let bytesRead = Darwin.read(fd, &buffer, count)
        return (bytesRead, buffer)
    }

    static func write(_ fd: Int32, buffer: [UInt8]) {
        let bytesWritten = Darwin.write(fd, buffer, buffer.count)
        if bytesWritten < 0 {
            Utils.print_errno(label: "Socket.write")
        }
    }

    func close(_ clientSocket: Int32) {
        Darwin.close(clientSocket)
    }
}
