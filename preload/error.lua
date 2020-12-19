local errors = {}

function errmsg(ec)
	if not ec then
		return "nil"
	end
	return errors[ec].desc
end

local function add(err)
	assert(errors[err.code] == nil, string.format("have the same error code[%x], msg[%s]", err.code, err.message))
	errors[err.code] = {desc = err.desc , type = err.type}
	return err.code
end

SYSTEM_ERROR = {
	success            = add{code = 0x0000, desc = "请求成功"},
    unknow             = add{code = 0x0001, desc = "未知错误"},
    invalid_client     = add{code = 0x0002, desc = "非法客户端"},
	argument           = add{code = 0x0003, desc = "参数错误"},
	decode_failure     = add{code = 0x0004, desc = "解析协议失败"},
    service_maintance  = add{code = 0x0005, desc = "服务维护"},
}

AUTH_ERROR = {
	account_nil			= add{code = 0x0101, desc = "帐号为空"},
	password_nil       	= add{code = 0x0102, desc = "密码为空"},
}

GAME_ERROR = {
	has_sign 			= add{code = 0x0201, desc = "今天已经签到了"},
	matching_or_inroom  = add{code = 0x0202, desc = "已经在匹配或已加入房间"},
	over_room_limit 	= add{code = 0x0203, desc = "金币不足或超过限制"},
	already_ready 		= add{code = 0x0204, desc = "你已经在准备中"},
	not_in_matching 	= add{code = 0x0205, desc = "不在匹配状态中"},
	already_showcards 	= add{code = 0x0206, desc = "你已经明牌了"},
}

DESK_ERROR = {

}


return errors