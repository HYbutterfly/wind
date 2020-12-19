local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
local token = require "wind.token"

local CMD = {}
local SOCKET = {}
local gate
local user = {}
local handshake = {}

local function login(id, fd, addr)
	local u = user[id]
	if u then
		skynet.call(gate, "lua", "kick", u.fd)
		user[u.fd] = nil
		u.fd = fd
		skynet.call(u.agent, "lua", "wd_reconnect", fd, addr)
	else
		local a = skynet.newservice("agent")
		skynet.call(a, "lua", "wd_start", { gate = gate, id = id, client = fd, addr = addr, watchdog = skynet.self() })
		u = {
			id = id,
			fd = fd,
			agent = a,
		}
		user[id] = u
		user[fd] = u
	end
end

local function logout(id)
	local u = user[id]
	if u then
		user[u.fd] = nil
		user[id] = nil
		skynet.call(gate, "lua", "kick", u.fd)
		skynet.send(u.agent, "lua", "wd_exit")
	end
end

function SOCKET.open(fd, addr)
	skynet.error("New client from : " .. addr)
	handshake[fd] = addr:match("(.+):(%d+)")
	skynet.send(gate, "lua", "accept", fd)
end


function SOCKET.close(fd)
	skynet.error("socket close",fd)
	handshake[fd] = nil

	local u = user[fd]
	if u then
		user[fd] = nil
		skynet.send(u.agent, "lua", "wd_disconnect", fd)
	end
end

function SOCKET.error(fd, msg)
	print("socket error",fd, msg)
	handshake[fd] = nil
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
	skynet.error("socket data:", fd, msg)
	local err, id = token.auth(msg)
	if not err then
		local addr = handshake[fd]
		handshake[fd] = nil
		login(id, fd, addr)
		socketdriver.send(fd, "200 OK\n")
		return
	end
	socketdriver.send(fd, "401 BadToken\n")
	skynet.call(gate, "lua", "kick", fd)
end

function CMD.start(conf)
	skynet.call(gate, "lua", "open" , conf)
end

function CMD.logout(id)
	logout(id)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	gate = skynet.newservice("gate")
end)
