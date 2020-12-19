local skynet = require "skynet"
local web = require "wind.web"
local db = require "wind.mongo"
local token = require "wind.token"


web.post("/login", web.jsonhandle(function(self)
	local account = assert(self.account)
	local password = assert(self.password)
	
	local u = db.admin_user.miss_find_one {account = account}
	if not u then
		return {err = "account non-existent"}
	end
	if password ~= u.password then
		return {err = "bad password"}
	end
	local t = token.encode(account)
	
	return {token = t}
end))


web.post("/test", function(req, res)
	res.send("im admin server")
end)


skynet.start(function()
	web.listen(9011)
end)