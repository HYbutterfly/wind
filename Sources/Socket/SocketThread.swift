import Foundation
import Darwin

enum IdentType {
   case Listener(SocketListener)
   case Client(SocketListener)
}

public struct SocketThread {
    let queue: Int32
    var listeners: [SocketListener] = []
    var ident_type: [UInt: IdentType] = [:]

    init() {
        queue = kqueue()
        if queue == -1 {
            fatalError("Failed to create kqueue")
        }
    }

    mutating func add_listener(listener: SocketListener) {
        listener.socket.listen(port: listener.port)
        print("Listen on \(listener.port)")
        listeners.append(listener)
        ident_type[UInt(listener.socket.handle)] = .Listener(listener)
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
                let event = changeList[Int(i)-1]
                switch ident_type[event.ident] {

                case .Listener(let listener):
                    let client = listener.socket.accept()
                    let ident = UInt(client)
                    listener.on_connect(client: client)
                    self.ident_type[ident] = .Client(listener)
                    add_event(fd: ident, filter: Int16(EVFILT_READ))

                case .Client(let listener):
                    let client = Int32(event.ident)
                    let message = listener.socket.read(clientSocket: client, count: 128)
                    listener.on_message(client: client, message: message)

                default:
                    print()
                }
            }
        }
    }
}