import Foundation


protocol SocketListener {
    var port: UInt16 { get set }
    var socket: Socket { get set }

    func on_connect(client: Int32) async

    func on_message(client: Int32, message: [UInt8]) async

    func on_close(client: Int32) async
}