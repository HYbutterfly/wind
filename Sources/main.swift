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

    func on_connect(client: Int32) async {
        print("connect", client)
    }

    func on_message(client: Int32, message: [UInt8]) async {
        print("message", client, String(bytes: message, encoding: .utf8)!)
        Socket.write(client, buffer: message)
    }

    func on_close(client: Int32) async {
        print("close", client)
    }
}

let game = Game()
let listener = MySocketListener(port: 8080, game: game)

Wind.start(listeners: [listener])
