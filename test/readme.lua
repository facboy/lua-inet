local lpeg = require 'lpeg'
local test = require 'test'
local io = require 'io'

local format = string.format
local pack = table.pack
local concat = table.concat

local readme_parser
do
	local P = lpeg.P
	local Ct = lpeg.Ct
	local C = lpeg.C
	local Cc = lpeg.Cc

	local sp = P(' ')
	local eq = P('=')
	local nl = P('\n')
	local non_nl = P(1)-nl
	local rest_of_line = non_nl^0

	local div = sp^1 * P('-- returns ')
	local assign_mid = sp^1 * eq * sp^1

	local not_str = (sp^0 * nl) + div + assign_mid
	local str = C((P(1)-not_str)^1)
	local example = Ct(Cc('example') * str * div * sp^0 * str)
	local assign_left = P('local ')^-1 * str
	local assign_right = str
	local assignment = Ct(Cc('assignment') * assign_left * assign_mid * assign_right)
	local comment = P('--') * rest_of_line
	local indented_line = sp^2 * (comment + example + assignment) * sp^0
	local anyline = rest_of_line - (sp * rest_of_line)
	local non_match = Ct(Cc('unable to parse line') * C(rest_of_line))
	local line = indented_line + anyline + non_match

	readme_parser = Ct((line * nl)^0 * line^-1 * -1)
end

local env = {
	tostring = tostring,
	require = require,
}

local function run(name, code)
	local f = assert(load(code, name, 't', env))
	local ret = pack(pcall(f))
	if ret[1] then
		return ret
	else
		print()
		print('code:', code)
		print('error:', ret[2])
		print()
		return { true, nil, n=3 }
	end
end

local function run_example(name, code)
	return run(name, format('return %s', code))
end

local function pack2str(t)
	local new = {}
	local n = t.n
	for i=2,n do
		local v = t[i]
		local vt = type(v)
		if vt == 'nil' then
			new[i] = 'nil'
		else
			new[i] = format('%s "%s"', vt, v)
		end
	end
	return concat(new, ', ', 2, n)
end

local function compare_packs(a, b)
	local n = a.n
	if n ~= b.n then return false end
	for i=1,n do
		local va = a[i]
		local vb = b[i]
		local vat = type(va)
		local vbt = type(vb)
		if vat ~= vbt then return false end
		if va ~= vb then return false end
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
	assert(compare_packs(r1, r2), errmsg)
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
