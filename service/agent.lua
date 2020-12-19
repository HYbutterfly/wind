local skynet = require "skynet"
local agent = require "snax.agentserver"
local db = require "wind.mongo"
local lobby = require "doudizhu.lobby"
local ec = require "wind.eventcenter-local"

local handle = {}
local request = {}
local command = {}

function command.send2client(name, args)
    agent.send_request(name, args)
end

function handle.request(cmd, args)
    local f = assert(request[cmd], cmd)
    return f(args)
end

function handle.command(cmd, ...)
    local f = assert(command[cmd], cmd)
    return f(...)
end

function handle.exit()
    ec.pub{type = "exit", time = os.time()}
    skynet.error('------------ exit ------------')
end

function handle.start(id, addr)
    me = db.user.miss_find_one{id = id}

    -- load loginc module
    lobby(me, request, command)
    ec.pub {
        type = "login",
        time = os.time(),
        ip = addr,
    }
end

function handle.init()
    skynet.error('------------ init ------------')
end

agent.start(handle)