import Foundation

public struct Wind {
    static func start(listeners: [SocketListener]) {
        DispatchQueue(label: "socket").async {
            var thread = SocketThread(listeners: listeners)
            thread.run()
        }
        RunLoop.current.run()
    }
}
