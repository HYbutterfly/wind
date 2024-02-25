// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

class MySocketListener: SocketListener {
    var socket = Socket()
    var port: UInt16
    var game: Game

    init(port: UInt16, game: Game) {
        self.port = port
        self.game = game
    }

    func on_connect(client: Int32) {
        print("connect", client)
    }

    func on_message(client: Int32, message: [UInt8]) {
        print("message", client, String(bytes: message, encoding: .utf8)!)
    }

    func on_close(client: Int32) {
        print("close", client)
    }
}

let game = Game()
let listener = MySocketListener(port: 8080, game: game)

let socket = DispatchQueue(label: "socket", attributes: .init(rawValue:0))

socket.async {
    var thread = SocketThread()
    thread.add_listener(listener: listener)
    thread.run()
}

RunLoop.current.run()