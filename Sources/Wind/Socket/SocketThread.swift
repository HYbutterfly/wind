import Darwin
import Foundation

enum IdentType {
    case Listener(SocketListener)
    case Client(SocketListener)
}

public struct SocketThread {
    let queue: Int32
    var listeners: [SocketListener]
    var ident_type: [UInt: IdentType] = [:]
    var client_last: [Int32: [UInt8]] = [:]

    init(listeners: [SocketListener]) {
        self.listeners = listeners
        queue = kqueue()
        if queue == -1 {
            fatalError("Failed to create kqueue")
        }
        for listener in listeners {
            listener.socket.listen(port: listener.port)
            print("Listen on \(listener.port)")
            ident_type[UInt(listener.socket.handle)] = .Listener(listener)
        }
        mainloop()
    }

    private func add_event(fd: UInt, filter: Int16) {
        var event = kevent(
            ident: fd,
            filter: filter,
            flags: UInt16(EV_ADD),
            fflags: 0,
            data: 0,
            udata: nil
        )
        let result = kevent(queue, &event, 1, nil, 0, nil)
        if result == -1 {
            fatalError("Failed to register event with kqueue")
        }
    }

    private mutating func mainloop() {
        for listener in listeners {
            add_event(fd: UInt(listener.socket.handle), filter: Int16(EVFILT_READ))
        }

        var changeList = Array(repeating: kevent(), count: 64)
        while true {
            let eventCount = kevent(queue, nil, 0, &changeList, 64, nil)
            if eventCount == -1 {
                fatalError("Failed to wait for events")
            }
            for i in 1...eventCount {
                let event = changeList[Int(i) - 1]
                switch ident_type[event.ident] {

                case .Listener(let listener):
                    let client = listener.socket.accept()
                    let ident = UInt(client)
                    DispatchQueue.main.async {
                        Task { await listener.on_connect(client: client) }
                    }
                    ident_type[ident] = .Client(listener)
                    add_event(fd: ident, filter: Int16(EVFILT_READ))

                case .Client(let listener):
                    let client = Int32(event.ident)
                    let (size, message) = listener.socket.read(client, count: 128)
                    if size < 0 {
                        Util.print_errno(label: "Socket.read")
                    } else if size == 0 {
                        client_cleanup(listener: listener, client: client)
                        DispatchQueue.main.async {
                            Task { await listener.on_close(client: client) }
                        }
                    } else {
                        if listener.socket.headfmt == .none {
                            DispatchQueue.main.async {
                                Task { await listener.on_message(client: client, message: message) }
                            }
                        } else {
                            if let last = client_last[client] {
                                client_last[client] = last + message
                            } else {
                                client_last[client] = message
                            }
                            try_dispatch_client_packet(client, headfmt: listener.socket.headfmt)
                        }
                    }
                default:
                    print()
                }
            }
        }
    }

    mutating func client_cleanup(listener: SocketListener, client: Int32) {
        listener.socket.close(client)
        client_last[client] = nil
    }

    mutating func try_dispatch_client_packet(_ client: Int32, headfmt: SocketPacketHeadFormat) {
        if let last = client_last[client] {
            var index = 0
            while true {
                if let length = Util.socket_packet_head_decode(fmt: headfmt, data: last, from: index) {
                    if index + length <= last.count {
                        index += headfmt.size()
                        let packet = last[index...(index + length - 1)]
                        let message = Array(packet)
                        DispatchQueue.main.async {
                            Task { await listener.on_message(client: client, message: message) }
                        }
                        index += length
                    } else {
                        break
                    }
                } else {
                    break
                }
            }
            if index != 0 {
                if index == last.count {
                    client_last[client] = nil
                } else {
                    let remaining = last[index..<last.count]
                    client_last[client] = Array(remaining)
                }
            }
        }
    }
}
