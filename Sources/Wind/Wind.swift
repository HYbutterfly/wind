import Foundation

public struct Wind {
    static func start(listeners: [SocketListener]) {
        DispatchQueue(label: "socket").async {
            let _ = SocketThread(listeners: listeners)
        }
        RunLoop.current.run()
    }
}
