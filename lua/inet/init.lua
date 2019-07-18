local core = require 'inet.core'
local set  = require 'inet.set'

local new_inet = core.new_inet

local M = {}
local mt = {}

function mt.__call(_, ...)
	return new_inet(...)
end

do
	local mixed_networks = set.new()
	mixed_networks:add(new_inet('::ffff:0:0/96')) -- RFC 5156
	mixed_networks:add(new_inet('64:ff9b::/96')) -- RFC 6052
	M.mixed_networks = mixed_networks
	core.set_mixed_networks(mixed_networks)
end

M.is4 = core.is_inet4
M.is6 = core.is_inet6
M.is  = core.is_inet

M.is_set = set.is_set
M.set    = set.new

return setmetatable(M, mt)
