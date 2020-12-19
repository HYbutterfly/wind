local skynet = require "skynet"
require "skynet.manager"
local service = require "skynet.service"

local subscriber = {}
local manager


skynet.init(function()
    local ec_manager_service = function()
-- ec-manager service

local skynet = require "skynet"

local worker = {}

skynet.start(function() 
    skynet.dispatch("lua", function(_,_, name)
        if not worker[name] then
            worker[name] = skynet.newservice("eventcenter")
        end
        skynet.ret(skynet.pack(worker[name]))
    end)
end)

-- end of ec-manager service
    end

    skynet.register_protocol {
        name = "WIND_EVENT",
        id = 255,
        unpack = skynet.unpack,
        dispatch = function(_, _, id, event)
            local u = subscriber[id]
            if u then
                u.callback(event)
                u.count = u.count + 1
                if u.count == u.limit then
                    u.unsub()
                end
            end
        end
    }
    manager = service.new("eventcenter-manager", ec_manager_service)
end)


local ec = {}

local cache = {}

local function query_worker(name)
    if not cache[name] then
        cache[name] = skynet.call(manager, "lua", name)
    end
    return cache[name]
end


function ec.sub(pattern, callback, limit)
    local worker = query_worker(assert(pattern.type))

    limit = limit or math.huge
    local u = {pattern = pattern, callback = callback, limit = limit, count = 0}
    local id = tostring(u):sub(10, -1) -- "0x123456789012"
    skynet.call(worker, "lua", "SUB", id, pattern, limit)
    subscriber[id] = u

    function u.unsub()
        if subscriber[id] then
            subscriber[id] = nil
            skynet.send(worker, "lua", "UNSUB", id)
        end
    end

    return u
end

function ec.sub_once(pattern, callback)
    return ec.sub(pattern, callback, 1)
end

function ec.pub(event)
    local worker = query_worker(assert(event.type))
    skynet.send(worker, "lua", "PUB", event)
end

return ec