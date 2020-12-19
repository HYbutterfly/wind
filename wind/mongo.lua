local skynet = require "skynet"
require "skynet.manager"
local service = require "skynet.service"
local miss = require "miss-mongo"

local mongo = {}
local service_addr

local function miss_one(coll, o)
	local query = {_id = o._id}
	local event = {}

	function event.assign(k, v)
		mongo.update(coll, query, {["$set"] = {[k] = v}})
	end

	function event.unset(k)
		mongo.update(coll, query, {["$unset"] = {[k] = ""}})
	end

	function event.tpush(k, v)
		mongo.update(coll, query, {["$push"] = {[k] = v}})
	end

	function event.tinsert(k, index, v)
		mongo.update(coll, query, {["$push"] = {
			[k] = {
				["$each"] = {v},
				["$position"] = index
			}
		}})
	end

	function event.tpop(k, i)
		mongo.update(coll, query, {["$pop"] = {[k] = i}})
	end

	local function handler(e, ...)
		-- print("miss:", e, ...)
		local f = event[e]
		f(...)
	end

	local proxy = miss.miss(o, handler)
	return proxy
end


function mongo.insert(...)
    return skynet.call(service_addr, "lua", "insert", ...)
end

function mongo.remove(...)
    return skynet.call(service_addr, "lua", "remove", ...)
end

function mongo.find_one(...)
    return skynet.call(service_addr, "lua", "find_one", ...)
end

function mongo.find_one_or_insert(coll, query, fields, obj)
    if not obj then
        obj = assert(fields)
        fields = nil
    end
    local one = mongo.find_one(coll, query, fields)
    if not one then
        one = obj
        one._id = mongo.insert(coll, obj)
    end
    return one
end

function mongo.find_all(...)
    return skynet.call(service_addr, "lua", "find_all", ...)
end

function mongo.update(...)
    return skynet.call(service_addr, "lua", "update", ...)
end

function mongo.count(...)
    return skynet.call(service_addr, "lua", "count", ...)
end

function mongo.sum(...)
    return skynet.call(service_addr, "lua", "sum", ...)
end

function mongo.miss_find_one(coll, ...)
	local o = skynet.call(service_addr, "lua", "find_one", coll, ...)
	if o then
		return miss_one(coll, o)
	end
end

function mongo.miss_find_one_or_insert(coll, ...)
    local o = mongo.find_one_or_insert(coll, ...)
    return miss_one(coll, o)
end

function mongo.miss_find_all(coll, ...)
	local obj_list = skynet.call(service_addr, "lua", "find_all", coll, ...)
	for i,o in ipairs(obj_list) do
		obj_list[i] = miss_one(coll, o)
	end
	return obj_list
end

function mongo.miss_insert(coll, o)
	o._id = skynet.call(service_addr, "lua", "insert", coll, o)
	return miss_one(coll, o)
end

skynet.init(function()
    local mongo_service = function()

-- mongo service
local skynet = require "skynet"
local service = require "skynet.service"

skynet.start(function()
    local slave = {}
    local balance = 1
    skynet.dispatch("lua", function (_, _, ...)
        local s = slave[balance]
        balance = balance + 1
        if balance > #slave then
            balance = 1
        end
        local r = skynet.call(s, "lua", ...)
        skynet.ret(skynet.pack(r))
    end)

    local function mongo_worker ()
        local skynet = require "skynet"
        local mongo = require "skynet.db.mongo"
        local conf = require "config.mongo"
        
        local conn, db
        local command = {}
        
        function command.insert(coll_name, obj)
            db[coll_name]:insert(obj)
            return obj._id
        end
        
        function command.remove(coll_name, query, single)
            return db[coll_name]:delete(query, single)
        end
        
        function command.find_one(coll_name, query, fields)
            return db[coll_name]:findOne(query, fields)
        end
        
        function command.find_all(coll_name, query, fields, sorter, limit, skip)
            local t = {}
            local it = db[coll_name]:find(query, fields)
            if not it then
                return t
            end
        
            if sorter then
                if #sorter > 0 then
                    it = it:sort(table.unpack(sorter))
                else
                    it = it:sort(sorter)
                end
            end
        
            if limit then
                it:limit(limit)
                if skip then
                    it:skip(skip)
                end
            end
        
            while it:hasNext() do
                local obj = it:next()
                table.insert(t, obj)
            end
        
            return t
        end
        
        function command.update(coll_name, query, update, upsert, multi)
            return db[coll_name]:update(query, update, upsert, multi)
        end

        -- Ex
        function command.count(coll_name, query)
            local it = db[coll_name]:find(query)
            return it:count()
        end

        function command.sum(coll_name, query, key)
            local pipeline = {}
            if query then
                table.insert(pipeline,{["$match"] = query})
            end
           
            table.insert(pipeline,{["$group"] = {_id = false, [key] = {["$sum"] = "$" .. key}}})
           
            local result = db:runCommand("aggregate", coll_name, "pipeline", pipeline, "cursor", {}, "allowDiskUse", true)

            if result and result.ok and result.ok == 1 then
                if result.cursor and result.cursor.firstBatch then
                    local r = result.cursor.firstBatch[1]
                    return r and r[key] or 0
                end
            end
            return 0
        end



        skynet.start(function()
            skynet.dispatch("lua", function (_, _, cmd, ...)
                local f = assert(command[cmd], cmd)
                skynet.ret(skynet.pack(f(...)))
            end)

            conn = mongo.client(conf)
            conn:getDB(conf.db_name)
            db = conn[conf.db_name]
        end)
    end

    for i=1, skynet.getenv "thread" do
        table.insert(slave, service.new("mongo-slave"..i, mongo_worker))
    end
end)

-- end of mongo service
    end

    service_addr = service.new("mongo-master", mongo_service)
end)


local cache = {}

local function collection(coll)
    local c = cache[coll]
    if not c then
        c = setmetatable({}, {__index = setmetatable({}, {__index = function (_, k)
            return function (...)
                local f = assert(mongo[k], k)
                return f(coll, ...)
            end
        end})})
        cache[coll] = c
    end
    return c
end

return setmetatable({}, {__index = function(_, coll)
    return collection(coll)
end})