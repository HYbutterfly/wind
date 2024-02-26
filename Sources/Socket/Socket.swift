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
        var serverAddress = sockaddr_in()
        serverAddress.sin_family = sa_family_t(AF_INET)
        serverAddress.sin_addr.s_addr = INADDR_ANY
        serverAddress.sin_port = in_port_t(port).bigEndian

        var result = withUnsafePointer(to: &serverAddress) {
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

    func accept() -> Int32 {
        var clientAddress = sockaddr()
        var clientAddressLength = socklen_t(MemoryLayout<sockaddr>.size)
        let clientSocket = Darwin.accept(self.handle, &clientAddress, &clientAddressLength)
        guard clientSocket != -1 else {
            fatalError("Error accepting connection: \(errno)")
        }
        return clientSocket
    }

    func read(_ clientSocket: Int32, count: Int) -> (Int, [UInt8]) {
        var buffer = [UInt8](repeating: 0, count: count)
        let bytesRead = Darwin.read(clientSocket, &buffer, count)
        return (bytesRead, buffer)
    }

    func write(_ clientSocket: Int32, buffer: [UInt8]) {
        let bytesWritten = Darwin.write(clientSocket, buffer, buffer.count)
        if bytesWritten < 0 {
            Utils.print_errno(label: "Socket.write")
        }
    }

    func close(_ clientSocket: Int32) {
        Darwin.close(clientSocket)
    }
}
