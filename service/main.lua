local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local server = require "config.server"
local world = require "wind.eventcenter-world"

skynet.start(function()

	math.randomseed(tonumber(tostring(os.time()):reverse()))
	skynet.error("=============================================")
	skynet.error(os.date("%Y/%m/%d %H:%M:%S ")..server.name.." start")
	skynet.error("=============================================")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("debug_console", 9999)

	skynet.newservice("admin")
	skynet.newservice("login")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	
	skynet.newservice("client")
	-- skynet.newservice("test")
	-- skynet.sleep(300)
	-- world.pub{type = "shutdown", time = os.time()}

	skynet.exit()
end)
