local skynet = require "skynet"


local timers = {}

local M = {}

function M.create(delay, func, iteration, on_end)

    local now = skynet.now()

    local timer = {
        delay = delay,
        func = func,
        iteration = iteration or 1,
        on_end = on_end,
        count = 0,
        next_time = now + delay
    }

    table.insert(timers, timer)

    local function cancel()
        timer.destroy = true
    end

    return cancel
end

function M.destroy_all()
    for _,timer in ipairs(timers) do
        timer.destroy = true
    end
end


skynet.fork(function()
    while true do
        skynet.sleep(10)

        local now = skynet.now()

        for i=#timers, 1, -1 do
            local timer = timers[i]
            if timer.destroy then
                table.remove(timers, i)
            else
                if timer.next_time <= now then
                    local c = timer.count + 1
                    timer.count = c
                    timer.next_time = timer.next_time + timer.delay

                    timer.func(c)
                    
                    if timer.iteration > 0 and timer.iteration == c then
                        if timer.on_end then
                            timer.on_end()
                        end
                        table.remove(timers, i)
                    end
                end        
            end
        end
    end
end)


return M