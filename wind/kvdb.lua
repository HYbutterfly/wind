local skynet = require "skynet"
local service = require "skynet.service"

local manager

skynet.init(function()
    local kvdb_manager_service = function()
-- kvdb-manager service

local skynet = require "skynet"

local db = {}

skynet.start(function() 
    skynet.dispatch("lua", function(_,_, name)
		if not db[name] then
			db[name] = skynet.newservice("kvdb")
		end
        skynet.ret(skynet.pack(db[name]))
    end)
end)

-- end of kvdb-manager service
    end

    manager = service.new("kvdb-manager", kvdb_manager_service)
end)



local cache = {}

local function query_db(db_name)
	local db = cache[db_name]
	if not db then
		local service_addr = skynet.call(manager, "lua", db_name)
		db = {}

		function db.set(k, v)
			return skynet.call(service_addr, "lua", 'SET', k, v)
		end

		function db.get(k)
			return skynet.call(service_addr, "lua", 'GET', k)
		end

		cache[db_name] = db
	end
	return db
end

return setmetatable({}, {__index = function (_, db_name)
	return query_db(db_name)
end})