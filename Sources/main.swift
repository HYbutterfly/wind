// The Swift Programming Language
// https://docs.swift.org/swift-book

let socket = Socket().listen(port: 8080)

while true {
    let client = socket.accept()
    Task{
        while true {
            let msg = socket.read(clientSocket: client, count: 5)
            print("client:", String(bytes: msg, encoding: .utf8)!)
            socket.write(clientSocket: client, buffer: msg)
        }
    }
}
