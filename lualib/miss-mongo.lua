local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort


local M = {}

local proxy_key = {}
local proxy_parent = {}
local proxy_handler = {}
local proxy_source = {}


local function mongo_key(k)
	if type(k) == 'number' then
		return (k-1)
	else
		return k
	end
end

local function proxy_path(proxy, tail)
	tail = mongo_key(tail)

	local path = mongo_key(proxy_key[proxy])

	while true do
		proxy = proxy_parent[proxy]
		if proxy then
			local k = proxy_key[proxy]
			if k then
				path = mongo_key(k).."."..path
			else
				break
			end
		else
			break
		end
	end
	return (path and tail and path..'.'..tail) or path or tail
end

local function destroy_proxy(proxy)
	proxy_key[proxy] = nil
	proxy_parent[proxy] = nil
	proxy_handler[proxy] = nil
	proxy_source[proxy] = nil
end

function table.insert(proxy, index, obj)

	local len = #proxy
	if not obj then
		obj = index
		index = len + 1
	end

	local tail = index - len == 1

	local source = proxy_source[proxy]
	if not source then
		return table_insert(proxy, index, obj)
	end

	local handler = proxy_handler[proxy]
	local path = proxy_path(proxy)
	
	table_insert(source, index, obj)

	if tail then
		if type(obj) == 'table' then
			rawset(proxy, index, M.proxy(obj, index, proxy, handler))
		end
		if len == 0 then
			handler("assign", path, source)
		else
			handler("tpush", path, obj)
		end
	else
		if type(obj) == 'table' then
			local tmp = {}
			for i=index,len do
				table.insert(tmp, proxy[i])
			end
			rawset(proxy, index, M.proxy(obj, index, proxy, handler))
			for i,p in ipairs(tmp) do
				proxy_key[p] = index + i
				rawset(proxy, index + i, p)
			end
		end

		handler("tinsert", path, index - 1, obj)
	end
end

function table.remove(proxy, index)
	local source = proxy_source[proxy]
	if not source then
		return table_remove(proxy, index)
	end

	local len = #proxy
	index = index or len

	local obj = table_remove(source, index)
	if type(obj) == 'table' then
		destroy_proxy(proxy[index])

		for i=index+1,len do
			local p = proxy[i]
			proxy_key[p] = i - 1
			rawset(proxy, i - 1, p)
		end
	end

	local path = proxy_path(proxy)
	local handler = proxy_handler[proxy]

	if index == len then
		handler("tpop", path, 1)
	elseif index == 1 then
		handler("tpop", path, -1)
	else
		handler("assign", path, source)
	end

	return obj
end

function table.sort(proxy, func)
	local source = proxy_source[proxy]
	if not source then
		return table_sort(proxy, func)
	end
	
	if #source == 0 then
		return
	else
		local path = proxy_path(proxy)
		local handler = proxy_handler[proxy]

		table_sort(source, func)
		handler("assign", path, source)
	end
end

function M.proxy(source, key, parent, handler)
	
	local mt = {}
	local proxy = setmetatable({}, mt)

	mt.__index = source
	mt.__gc = function () destroy_proxy(proxy) end
	mt.__len = function () return #source end
	mt.__pairs = function () return next, source, nil end
	mt.__newindex = function (_, k, v)
		source[k] = v
		if type(v) == 'table' then
			rawset(proxy, k, M.proxy(v, k, proxy, handler))
		end

		local path = proxy_path(proxy, k)

		local handler = proxy_handler[proxy]
		if v ~= nil then
			handler("assign", path, v)
		else
			handler("unset", path)
		end
	end

	proxy_key[proxy] = key
	proxy_handler[proxy] = handler
	proxy_parent[proxy] = parent
	proxy_source[proxy] = source

	for k,v in pairs(source) do
		if type(v) == 'table' then
			rawset(proxy, k, M.proxy(v, k, proxy, handler))
		end
	end

	return proxy
end

function M.miss(source, handler)
	return M.proxy(source, nil, nil, handler)
end

function M.source(proxy)
	return proxy_source[proxy]
end


return M