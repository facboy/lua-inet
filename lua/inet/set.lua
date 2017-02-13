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
					if j ~= i and t[j] == ib then
						-- counterpart found, aggregating
						t[i] = (ia ^ -1):network()
						t[j] = nil
						flag = true
					end
				end
			end
		end
	end
	table_compact(t, n)
end

return M
