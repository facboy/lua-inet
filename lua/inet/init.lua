local core = require 'inet.core'
local set  = require 'inet.set'

local new_inet = core.new_inet

local M = {}
local mt = {}

function mt.__call(_, ...)
	return new_inet(...)
end

M.is4 = core.is_inet4
M.is6 = core.is_inet6
M.is  = core.is_inet

M.set = set.new

return setmetatable(M, mt)
