local inet = require 'inet'
local test = require 'test'

local function parse(addr)
	local ret, err = inet(addr)
	assert(ret, (err or '')..' '..addr)
	return ret, err
end

local function dontparse(...)
	test.fail(parse, ...)
end

return test.new(function()
	local ip
	-- parsing
	parse('1:2:3:4:5:6:7:8')
	parse('::1/33')
	parse('1::/33')
	parse('1:2:3:4:5:6:7::/33')
	parse('::2:3:4:5:6:7:8/33')
	parse('2a03:5440:1010::80/64')
	dontparse('::1::/33')
	dontparse('::1/33a')
	dontparse('::1/150')
	dontparse('1:2:3:4::2:3:4:5:6:7:8/33')
	assert(tostring(parse('1:0:0:1::/64') * 1) == '1:0:0:2::/64')
	assert(tostring(parse('1::/64') * 5 / 32 * 3) == '1:3:0:5::/32')
	assert(tostring(parse('5::64') / 32 * -3) == '4:fffd::64/32')
	assert(tostring(parse('2::/32') ^ 1) == '2::/33')
	assert(tostring(parse('2::/32') ^ -1) == '2::/31')
	assert(tostring(parse('2::/128') * 5) == '2::5')
	assert(tostring(parse('2::/49') - 1)
		== '1:ffff:ffff:ffff:ffff:ffff:ffff:ffff/49')
	assert(tostring(parse('2::/49') - 1 + 2) == '2::1/49')
	assert(tostring(parse('1:ffff:ffff:fe00::/56') * 2) == '2::/56')
	assert(tostring(parse('1:ffff:ffff:fe00::/56') * 2 * -2)
		== '1:ffff:ffff:fe00::/56')
	ip = inet('10.0.0.0/33')
	assert(ip == nil)

	ip = inet('10.0.0.0/24')
	assert(type(ip) == 'table')
	assert(#ip == 24, 'incorrect netmask')
	assert(tostring(ip) == '10.0.0.0/24', 'not human readable')

	assert(inet('10.0.0.0/32') == inet('10.0.0.0'))
	assert(inet('10.0.0.0/31') ~= inet('10.0.0.0'))

	assert(tostring(ip+1) == '10.0.0.1/24', 'ip adding is broken')
	assert(tostring(ip+9-1) == '10.0.0.8/24', 'ip subtract is broken')
	assert(tostring(ip*1) == '10.0.1.0/24', 'ip multiplification is broken')
	assert(tostring(ip/8) == '10.0.0.0/8', 'ip division is broken')
	assert(tostring(ip^1) == '10.0.0.0/25', 'ip power is broken')

	-- test inet4.__lt
	assert(inet('10.0.0.0/24') > inet('10.0.0.0/30'), 'inet less than is broken')
	assert(not (inet('10.0.0.0/30') > inet('10.0.0.0/30')), 'inet less than is broken')
	assert(inet('10.0.0.0/30') >= inet('10.0.0.0/30'), 'inet less than is broken')
	assert(inet('10.0.0.0/30') <= inet('10.0.0.0/30'), 'inet less than is broken')
	assert(inet('10.0.0.0/30') < inet('10.0.0.0/24'), 'inet less than is broken')
	assert(not (inet('10.0.0.0/24') < inet('10.0.0.0/30')), 'inet less than is broken')
	assert(not (inet('10.0.0.0/30') < inet('10.0.0.0/30')), 'inet less than is broken')
	assert(not (inet('20.0.0.0/30') < inet('10.0.0.0/24')), 'inet less than is broken')

	-- test inet4.__le
	assert(inet('10.0.1.2/24') <= inet('10.0.0.0/16'))
	assert(not (inet('10.0.1.0/24') <= inet('10.0.0.0/24')))

	assert(inet('127.0.0.1/8'):netmask() == inet('255.0.0.0'))


	-- test inet*.__eq
	assert(inet('10.0.0.0/30') == inet('10.0.0.0/30'), 'inet4 eq is broken')
	assert(inet('10.0.1.0/30') ~= inet('10.0.0.0/30'), 'inet4 eq is broken')
	assert(inet('10.0.0.0/31') ~= inet('10.0.0.0/30'), 'inet4 eq is broken')
	assert(inet('::1') == inet('::1'), 'inet6 eq is broken')
	assert(inet('::1') ~= inet('::2'), 'inet6 eq is broken')
	assert(inet('::1/64') ~= inet('::1/56'), 'inet6 eq is broken')

	-- test inet*.ipstring
	assert((ip+1):ipstring() == '10.0.0.1', 'ip4 string is broken')
	assert(inet('::1/64'):ipstring() == '::1', 'ip6 string is broken')

	-- test inet*.network
	assert(inet('10.0.0.1/30'):network() == inet('10.0.0.0/30'), 'inet4.network() is broken')
	assert(inet('1::2/64'):network() == inet('1::/64'), 'inet6.network() is broken')
	ip = inet('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff/62')
	assert((ip/22):network() == inet('ffff:fc00::/22'), 'inet6.network() is broken')
	assert((ip/27):network() == inet('ffff:ffe0::/27'), 'inet6.network() is broken')

	--- test inet4:flip
	assert(inet('10.0.0.1/24'):flip() == inet('10.0.1.1/24'), 'inet4.flip() is broken')
	assert(inet('10.0.0.0/24'):flip() == inet('10.0.1.0/24'), 'inet4.flip() is broken')
	assert(inet('10.0.0.0/24'):flip():flip() == inet('10.0.0.0/24'), 'inet4.flip() is broken')
	assert(inet('10.20.30.0/24'):flip() == inet('10.20.31.0/24'))
	assert(inet('10.20.30.5/24'):flip() == inet('10.20.31.5/24'))
	assert(inet('10.20.30.5/32'):flip() == inet('10.20.30.4/32'))
	assert(inet('0.0.0.0/0'):flip() == nil)
	local ips = {
		inet('::'),
		inet('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff'),
	}
	assert(inet('::/0'):flip() == nil)
	assert(inet('::1/32'):flip() == inet('0:1::1/32'))
	assert(inet('::1/48'):flip() == inet('0:0:1::1/48'))
	for i=1,#ips do
		ip = ips[i]
		for j=1,128 do
			local foo = ip / j
			local bar = foo:flip()
			assert(foo ~= bar)
			assert(foo == bar:flip())
		end
	end

	-- TODO inet6.__le
	-- TODO inet6.__eq
end)
