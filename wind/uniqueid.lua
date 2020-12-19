local skynet = require "skynet"
local service = require "skynet.service"

local uniqueid = {}
local service_addr


function uniqueid.gen(name)
    return skynet.call(service_addr, "lua", "gen", name)
end

function uniqueid.free(name, id)
    return skynet.call(service_addr, "lua", "free", name, id)
end


skynet.init(function()
    local uniqueid_service = function()
-- uniqueid service

local skynet = require "skynet"
local db = require "wind.mongo"

local function create_sequential_num(name, persistent, start_num)
    local doc
    if persistent then
        doc = db.wind_uniqueid.miss_find_one {name = name}
        if doc then
            assert(doc.type == "sequential_num")
        else
            doc = db.wind_uniqueid.miss_insert {name = name, type = "sequential_num", start = start_num, last = start_num}
        end
    else
        doc = {name = name, start = start_num, last = start_num}
    end

    local self = {}
    
    function self.gen()
        doc.last = doc.last + 1
        local id = tostring(doc.last)
        return id
    end

    function self.free(id)
        -- pass     
    end
    return self
end

local function create_random_num(name, persistent, length)
    local doc
    if persistent then
        doc = db.wind_uniqueid.miss_find_one {name = name}
        if doc then
            assert(doc.type == "random_num")
        else
            doc = db.wind_uniqueid.miss_insert {name = name, type = "random_num", generated = {}}
        end
    else
        doc = {name = name, generated = {}}
    end

    local self = {}
    
    function self.gen()
        local id
        repeat
            id = tostring(math.random(10^(length-1)+1, 10^length-1))
        until not doc.generated[id]
        doc.generated[id] = true
        return id
    end

    function self.free(id)
        doc.generated[id] = nil        
    end
    return self
end


local function create_day_index(name, persistent, index_length)
    local doc
    if persistent then
        doc = db.wind_uniqueid.miss_find_one {name = name}
        if doc then
            assert(doc.type == "day_index")
        else
            doc = db.wind_uniqueid.miss_insert {name = name, type = "day_index", day = os.date("%Y%m%d"), index = 0}
        end
    else
        doc = {name = name, day = os.date("%Y%m%d"), index = 0}
    end

    local self = {}
    
    function self.gen()
        local today = os.date("%Y%m%d")
        if today == doc.day then
            doc.index = doc.index + 1
        else
            doc.day = today
            doc.index = 1
        end

        if index_length then
            return string.format("%s%0"..index_length.."d", doc.day, doc.index)
        else
            return doc.day .. doc.index
        end
    end

    function self.free()
        -- pass
    end

    return self
end

local generator = {}

local commond = {}

function commond.gen(name)
    local uid = assert(generator[name], string.format("Undefined generator:%s", name))
    return uid.gen()
end

function commond.free(name, id)
    local uid = assert(generator[name], string.format("Undefined generator:%s", name))
    return uid.free(id)
end

local function init()
    generator.userid = create_random_num("userid", true, 6)
    generator.roomid = create_random_num("roomid", false, 6)
    generator.mailid = create_day_index("mailid", true, 6)
    generator.gameid = create_sequential_num("gameid", false, 100000)
end

skynet.start(function() 
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = assert(commond[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
    init()
end)

-- end of uniqueid service
    end

    service_addr = service.new("uniqueid", uniqueid_service)
end)

return uniqueid