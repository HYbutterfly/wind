local skynet = require "skynet"
require "skynet.manager"


local function get_logger_name()
	return "logs/error_" ..os.date("%Y%m%d")..".lua"
end

local daemon = skynet.getenv("daemon")
local logger

if daemon then
	local filename = get_logger_name()
	local f = io.open(filename, "w")

	logger = {
		day = os.date("%Y%m%d"),
		name = filename,
		f = f
	}
end

-- register protocol text before skynet.start would be better.
skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(_, address, msg)
		if not daemon then
			print(string.format("[:%08x] %s", address, msg))
		else
			local text = string.format("[:%08x %s] %s", address, os.date("%H:%M:%S"), msg)
			local day = os.date("%Y%m%d")
			if day ~= logger.day then
				logger.f:close()
				logger.day = day
				logger.name = get_logger_name()
				logger.f = io.open(logger.name, "w")
			end
			logger.f:write(text .. "\n")
			logger.f:flush()
		end
	end
}

skynet.register_protocol {
	name = "SYSTEM",
	id = skynet.PTYPE_SYSTEM,
	unpack = function(...) return ... end,
	dispatch = function()
		-- reopen signal
		print("SIGHUP")
		if logger then
			logger.f:close()
			logger.f = io.open(logger.name, "a")
		end
	end
}

skynet.start(function()
end)