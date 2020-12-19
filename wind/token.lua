local skynet = require "skynet"
local crypt = require "skynet.crypt"
local server = require "config.server"

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode

local TOKEN_VALID_TIME = 30*24*60*60 


local token = {}


function token.encode(id)
    local create_time = os.time()
    return base64encode(server.name).."#"..base64encode(id).."@"..base64encode(create_time) 
end

function token.decode(t)
    local server_name, id, create_time = t:match("(.+)#(.+)@(.+)")
    if create_time then
        return base64decode(server_name), base64decode(id), tonumber(base64decode(create_time))
    end
end

function token.auth(t)
    if type(t) == 'string' then
        local server_name, id, create_time = t:match("(.+)#(.+)@(.+)")
        if create_time then
            server_name = base64decode(server_name)
            id = base64decode(id)
            create_time = tonumber(base64decode(create_time))

            if server_name == server.name then
                local expire_time = create_time + TOKEN_VALID_TIME
                if expire_time > os.time() then
                    return nil, id, expire_time
                else
                    return AUTH_ERROR.token_expires
                end
            end
        end
        return AUTH_ERROR.invalid_token
    end
    return AUTH_ERROR.invalid_token
end


return token