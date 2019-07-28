local core = require 'inet.core'
local common = require 'inet.common'

local is_inet = core.is_inet
local get_mt = common.get_mt

local insert = table.insert
local remove = table.remove
local sort = table.sort

local M = {}

local function table_compact(t, n)
	-- remove nil entries, and reorder
	local i = 0
	for j=1,n do
		if t[j] then
			if i > 0 then
				t[i] = t[j]
				i = i + 1
			end
		elseif i == 0 then
			i = j
		end
	end
	if i > 0 then
		for j=i,n do
			t[j] = nil
		end
	end
end

function M.aggregate(t)
	local flag = true
	local n = #t
	for i=1,n do
		t[i] = t[i]:network()
	end
	while flag do -- loop until no aggregatable addresses are found
		flag = false
		for i=1,n do
			local ia = t[i]
			if ia then
				local ib = ia:flip() -- counterpart
				for j=1,n do
					if j ~= i then
						if ia == t[j] then
							-- duplicate found
							t[j] = nil
							flag = true
						elseif t[j] == ib then
							-- counterpart found, aggregating
							t[i] = (ia ^ -1):network()
							t[j] = nil
							flag = true
						end
					end
				end
			end
		end
	end
	table_compact(t, n)
end

local function has(set, addr)
	assert(set)
	for i=1,#set do
		local elem = set[i]
		if elem >= addr then
			local exclude = set.exclude
			if exclude then
				return not has(exclude, addr)
			else
				return true
			end
		end
	end
	return false
end

function M.iterator(set)
	local excl = set.exclude
	local i = 1
	if #set < 1 then return nil, 'empty set' end
	local addr = set[i]
	local net = set[i]:network()
	local function iter()
		if not addr then return end
		local ret
		ret = addr/32
		addr = addr + 1
		if addr:network() ~= net then
			i = i + 1
			addr = set[i]
			if addr then
				net = set[i]:network()
			end
		end
		if has(excl, ret) then
			return iter()
		end
		return ret
	end

	return iter
end

-- iterate over the set repeatedly
function M.loopiterator(set)
	local orig_iter = M.iterator(set)
	local function iter()
		local addr = orig_iter()
		if not addr then
			orig_iter = M.iterator(set)
			addr = orig_iter()
		end
		return addr
	end
	return iter
end

local inet_set = {}
inet_set.__index = inet_set

local function check_net(self, net)
	if not is_inet(net) then return nil, 'invalid net' end
	local set_fam = self.family
	local net_fam = net:family()
	if set_fam then
		if set_fam ~= net_fam then
			return nil, 'invalid family'
		end
	else
		self.family = net_fam
	end
	return true
end

function inet_set:add(net)--, aggregate)
	if not check_net(self, net) then return check_net(self, net) end
	insert(self.nets, net)
	M.aggregate(self.nets)
	return true
end

function inet_set:remove(net)
	if not check_net(self, net) then return check_net(self, net) end
	local nets = self.nets
	local ret = false
	for i=1,#nets do
		local n = nets[i]
		if n == net then
			ret = true
			remove(nets, i)
		elseif n:contains(net) then
			ret = true
			remove(nets, i)
			for j=#n+1,#net do
				local sn = (net / j):network()
				if sn:contains(net) then
					sn = sn:flip()
				end
				self:add(sn)
			end
		end
	end
	return ret
end

function inet_set:contains(net)
	if not check_net(self, net) then return check_net(self, net) end
	local nets = self.nets
	for i=1,#nets do
		local n = nets[i]
		if n == net or n:contains(net) then
			return n
		end
	end
	return false
end

function inet_set:list()
	local nets = self.nets
	sort(nets)
	return nets
end

function inet_set:flush()
	self.nets = {}
	self.family = nil
	return true
end

local function new_set()
	return setmetatable({
		nets = {},
	}, inet_set)
end

M.new = new_set

function M.is_set(t)
	local mt = get_mt(t)
	return mt == inet_set
end

return M
