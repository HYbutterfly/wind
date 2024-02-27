import Foundation

struct Util {
    static func print_errno(label: String) {
        print(String(format: "\(label) errno: %d, message: %@", errno, String(cString: strerror(errno))))
    }
}

public struct Wind {
    static func start(listeners: [SocketListener]) {
        DispatchQueue(label: "socket").async {
            let _ = SocketThread(listeners: listeners)
        }
        RunLoop.current.run()
    }
    static let util = Util.self
}
