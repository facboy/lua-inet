local lpeg = require 'lpeg'
local test = require 'test'
local io = require 'io'

local format = string.format
local pack = table.pack
local concat = table.concat

local readme_parser
do
	local P = lpeg.P
	local S = lpeg.S
	local V = lpeg.V
	local C = lpeg.C
	local Cc = lpeg.Cc
	local Ct = lpeg.Ct

	local sp = P(' ')
	local eq = P('=')
	local nl = P('\n')
	local non_nl = P(1)-nl
	local rest_of_line = non_nl^0

	local extraline = (nl * sp * sp)^-1
	local line_or_space = extraline + sp^1
	local div = line_or_space * P('-- returns') * line_or_space
	local assign_mid = sp^1 * eq * sp^1

	local table = P{"{" * ((1 - S('{}')) + V(1))^0 * "}"}
	local not_str = (sp^0 * nl) + div + assign_mid + P('{')
	local plainstr = (P(1)-not_str)^1
	local str = C(plainstr * (table * plainstr^0)^0)
	local example = Ct(Cc('example') * str * div * str)
	local assign_left = P('local ')^-1 * str
	local assign_right = str
	local assignment = Ct(Cc('assignment') * assign_left * assign_mid * assign_right)
	local comment = P('--') * rest_of_line
	local indented_line = sp^2 * (comment + example + assignment) * sp^0
	local section = P('=')^1
	local install_hdr = P('Install') * nl * section * nl
	local install_section = install_hdr * ((rest_of_line * nl) - section)^1 * section
	local anyline = rest_of_line - (sp * rest_of_line)
	local non_match = Ct(Cc('unable to parse line') * C(rest_of_line))
	local line = indented_line + install_section + anyline + non_match

	readme_parser = Ct((line * nl)^0 * line^-1 * -1)
end

local env = {
	tostring = tostring,
	require = require,
}

local function run_error(code, err)
	print()
	print('code:', code)
	print('error:', err)
	print()
	return { true, nil, n=3 }
end

local function run(name, code)
	local f, err = load(code, name, 't', env)
	if not f then
		return run_error(code, err)
	end
	local ret = pack(pcall(f))
	if ret[1] then
		return ret
	else
		return run_error(code, ret[2])
	end
end

local function run_example(name, code)
	return run(name, format('return %s', code))
end

local function get_meta_function(t, fname)
	return rawget(getmetatable(t) or {}, fname)
end

local function table2str(t)
	local nt = {}
	for i=1,#t do
		nt[i] = tostring(t[i])
	end
	return '{ ' .. concat(nt, ', ') .. ' }'
end

local function pack2str(t)
	local new = {}
	local n = t.n
	for i=2,n do
		local v = t[i]
		local vt = type(v)
		if vt == 'nil' then
			new[i] = 'nil'
		elseif vt == 'table' then
			local tostr = get_meta_function(v, '__tostring') or table2str
			new[i] = tostr(v)
		else
			new[i] = format('%s "%s"', vt, v)
		end
	end
	return concat(new, ', ', 2, n)
end

local function compare_tables(a, b)
	local aeq = get_meta_function(a, '__eq')
	local beq = get_meta_function(b, '__eq')
	if aeq or beq then
		if aeq ~= beq then return false end
		if a ~= b then return false end
	end
	local a_key_cnt = 0
	for _,_ in pairs(a) do
		a_key_cnt = a_key_cnt + 1
	end
	for k,vb in pairs(b) do
		a_key_cnt = a_key_cnt - 1
		local va = a[k]
		if va == nil then return false end
		local vat = type(va)
		local vbt = type(vb)
		if vat ~= vbt then return false end
		if vat == 'table' then
			if not compare_tables(va, vb) then return false end
		else
			if va ~= vb then return false end
		end
	end
	if a_key_cnt ~= 0 then
		return false
	end
	return true
end

local function hdl_assignment(line)
	local code = format('%s = %s', line[2], line[3])
	run('assignment', code)
end

local function hdl_example(line)
	local t1 = line[2]
	local t2 = line[3]
	local r1 = run_example('left side', t1)
	local r2 = run_example('right side', t2)
	local errmsg = format('"%s" returns %s, not %s', t1, pack2str(r1), pack2str(r2))
	assert(compare_tables(r1, r2), errmsg)
end

local handlers = {
	assignment = hdl_assignment,
	example = hdl_example,
}

local function readme_test()
	local data = assert(io.open('README.rst', 'r')):read('*a')
	local lines = assert(readme_parser:match(data))
	for i=1,#lines do
		local line = lines[i]
		local kind = line[1]
		local handler = handlers[kind]
		if not handler then
			print('unknown handler', kind, line[2])
		end
		handler(line)
	end
end

return test.new(readme_test)
