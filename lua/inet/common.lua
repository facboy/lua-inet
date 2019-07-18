local M = {}

function M.get_mt(t)
	if type(t) ~= 'table' then return nil end
	return getmetatable(t)
end

return M
