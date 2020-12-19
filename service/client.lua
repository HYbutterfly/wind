local skynet = require "skynet"
local httpc = require "http.httpc"
local cjson = require "cjson"
local socket = require "skynet.socket"

local TOKEN, fd
print = skynet.error

local function login(tel)
    local status, body = httpc.request("POST", "http://127.0.0.1:9015", "/login", nil, nil, cjson.encode{tel = tel})
    if status ~= 200 then
        return print(status)
    end
    local token = cjson.decode(body).token
    return token
end

local function connect()
    fd = socket.open("127.0.0.1", 8888)
    skynet.sleep(50)
    socket.write(fd, string.pack(">s2", TOKEN))
    local ok = socket.readline(fd)
    if ok == '200 OK' then
        print("connect gameserver ok")
        return true
    else
        print("connect gameserver failed", ok)
    end
end

local function start_read()
    skynet.fork(function()
        while true do  
            skynet.sleep(10)
            local sz = socket.read(fd, 2)
            if sz == false then
                print("socket closed")
                return
            end
            sz = string.byte(sz:sub(1, 1))*256 + string.byte(sz:sub(2, 2))
            print("server:", socket.read(fd, sz))
        end
    end)
end

local session = 0
local function send_request(name, args)
    session = session + 1
    local pack = string.pack(">s2", cjson.encode{session, name, args})
    socket.write(fd, pack)
end


local function main()

    local token = login("13972143923")
    if not token then
        return
    else
        TOKEN = token
        print("login suc ...")
    end

    connect()
    start_read()
    send_request("handshake", {msgindex = 0})
    send_request("base_info")
    send_request("sign")

    skynet.sleep(100)
    send_request("base_info")


    -- socket.close(fd)
    -- connect()
    -- send_request("hello", {msg = "world"})

    -- skynet.timeout(500, function()
    --     send_request("quit")
    -- end)

    
end

skynet.start(main)