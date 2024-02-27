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
    }

    func add_event(fd: UInt, filter: Int16) {
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

    mutating func run() {
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
                    let (size, message) = Socket.read(client, count: 128)
                    if size < 0 {
                        Utils.print_errno(label: "Socket.read")
                    } else if size == 0 {
                        listener.socket.close(client)
                        DispatchQueue.main.async {
                            Task { await listener.on_close(client: client) }
                        }
                    } else {
                        DispatchQueue.main.async {
                            Task { await listener.on_message(client: client, message: message) }
                        }
                    }
                default:
                    print()
                }
            }
        }
    }
}
