local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local cjson = require "cjson"


local M = {
    protocol = "http",
    bodylimit = 8192
}

local handle = {
    get = {},
    post = {}
}

function M.get(path, cb)
    handle.get[path] = cb
end

function M.post(path, cb)
    handle.post[path] = cb
end

M.cross_origin_header = {
    ["access-control-allow-origin"] = "*",
    ["access-control-allow-methods"] = "*",
    ["access-control-allow-headers"] = "x-requested-with,content-type",
    ["content-type"] = "application/json"
}

function M.jsonhandle(f)
	return function(req, res)
		local ok, data = pcall(cjson.decode, req.body)
		if ok then
			local result = f(data, req)
			res.send(cjson.encode(result))
		end
	end
end


local SSLCTX_SERVER = nil
local function gen_interface(protocol, fd)
    if protocol == "http" then
        return {
            init = nil,
            close = nil,
            read = sockethelper.readfunc(fd),
            write = sockethelper.writefunc(fd),
        }
    elseif protocol == "https" then
        local tls = require "http.tlshelper"
        if not SSLCTX_SERVER then
            SSLCTX_SERVER = tls.newctx()
            -- gen cert and key
            -- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
            local certfile = skynet.getenv("certfile") or "./server-cert.pem"
            local keyfile = skynet.getenv("keyfile") or "./server-key.pem"
            print(certfile, keyfile)
            SSLCTX_SERVER:set_cert(certfile, keyfile)
        end
        local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
        return {
            init = tls.init_responsefunc(fd, tls_ctx),
            close = tls.closefunc(tls_ctx),
            read = tls.readfunc(fd, tls_ctx),
            write = tls.writefunc(fd, tls_ctx),
        }
    else
        error(string.format("Invalid protocol: %s", protocol))
    end
end

local function response(id, write, ...)
	local ok, err = httpd.write_response(write, ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

local function accept(id, addr)
    socket.start(id)
    local interface = gen_interface(M.protocol, id)
    if interface.init then
        interface.init()
    end
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(interface.read, M.bodylimit)
    if code then
        if code ~= 200 then
            response(id, interface.write, code)
        else
            method = method:lower()
            local path, query = urllib.parse(url)
            local h = handle[method] and handle[method][path]
            if h then
                local req = {
                    addr = addr,
                    query = query,
                    header = header,
                    body = body
                }
    
                local res = {
                    send = function(body, header)
                        response(id, interface.write, code, body, header)
                    end
                }
                h(req, res)
            else
                skynet.error(string.format('No handle of method: "%s", path: "%s", client: "%s"', method, path, addr))
            end
        end
    else
        if url == sockethelper.socket_error then
            skynet.error("socket closed")
        else
            skynet.error(url)
        end
    end
    socket.close(id)
    if interface.close then
        interface.close()
    end
end

function M.listen(host, port)
    if not port then
        port = host
        host = "0.0.0.0"
    end
	skynet.error(string.format('Listen at "%s://%s:%d"', M.protocol, host, port))
	local id = socket.listen(host, tonumber(port))

    socket.start(id, function(id, addr)
        accept(id, addr)
    end)
end

return M