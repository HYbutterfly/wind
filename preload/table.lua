function table.randsort(t)
    local len = #t
    for i = 1, len do
        local index = math.random(1, len)
        t[i], t[index] = t[index], t[i]
    end
    return t
end


function table.splice(t, index1, index2)
    assert(type(t) == 'table' and #t > 0)
    index1 = index1 or 1
    index2 = index2 or #t

    assert(index2 - index1 < #t)

    local r = {}
    for i = index2, index1, -1 do
        table.insert(r, table.remove(t, i))
    end
    return r
end

function table.slice(t, index1, index2)
    assert(type(t) == 'table' and #t > 0)
    index1 = index1 or 1
    index2 = index2 or #t

    assert(index2 - index1 < #t)

    local r = {}
    for i = index1, index2 do
        table.insert(r, table.clone(t[i]))
    end
    return r
end


function table.find_one(t, item)
	for i,v in ipairs(t) do
		if v == item then
			return true
		end
	end
	return false
end

function table.clone( obj )
    local function _copy( obj )
        if type(obj) ~= 'table' then
            return obj
        else
            local tmp = {}
            for k,v in pairs(obj) do
                tmp[_copy(k)] = _copy(v)
            end
            return setmetatable(tmp, getmetatable(obj))
        end
    end
    return _copy(obj)
end

function table.filter(t, filter)
	local filter_type = type(filter)
	if filter_type == "table" then
	    local new = {}
	    for k,v in pairs(t) do
	        if filter[k] == false then
	        
	        else
	            new[k] = v
	        end
	    end
	    return new
	else
		assert(filter_type == "function")
		local new = {}
		for k,v in pairs(t) do
			if filter(k, v) ~= false then
				new[k] = v
			end
		end
		return new
	end
end