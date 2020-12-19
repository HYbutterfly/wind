local skynet = require "skynet"
local web = require "wind.web"
local db = require "wind.mongo"
local token = require "wind.token"
local uniqueid = require "wind.uniqueid"


--
-- 为了简单, 给电话就给登录了, 并没有校验其他东西
-- 登录成功, 返回给客户端一个token 用于连接游戏服
--
web.post("/login", web.jsonhandle(function(self, req)
	local tel = assert(self.tel)
	local u = db.user.find_one({tel = tel}, {_id = false})
	if not u then
		local uid = uniqueid.gen("userid") 
		u = {
			tel = tel,

			-- user data
			id = uid, 								-- ID: 7位随机数字
			nickname = "玩家"..uid, 				-- 昵称
			gold = 0, 								-- 金币
			diamond = 0, 							-- 钻石
			backpack = {}, 							-- 背包
			reg_time = os.time(), 					-- 注册时间
			reg_ip = req.addr:match("(.+):(%d+)") 	-- 注册IP
		}
		db.user.insert(u)
	end
	return {token = token.encode(u.id)}
end))


skynet.start(function()
	web.listen(9015)
end)