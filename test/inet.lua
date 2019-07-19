local inet = require 'inet'
local test = require 'test'

local insert = table.insert

local function parse(addr)
	local ret, err = inet(addr)
	assert(ret, (err or '')..' '..addr)
	return ret, err
end

local function dontparse(...)
	test.fail(parse, ...)
end

local function all_the_same(t)
	local first
	for i=1,#t do
		local ip = parse(t[i])
		if not first then
			first = ip
		else
			assert(first == ip)
		end
	end
end

local function rfc4291()
	-- RFC 4291 - IP Version 6 Addressing Architecture
	assert(tostring(parse('2001:DB8:0:0:8:800:200C:417A'))
		== string.lower('2001:DB8::8:800:200C:417A'))
	assert(tostring(parse('FF01:0:0:0:0:0:0:101')) == string.lower('FF01::101'))
	assert(tostring(parse('0:0:0:0:0:0:0:1')) == '::1')
	assert(tostring(parse('0:0:0:0:0:0:0:0')) == '::')
	assert(tostring(parse('::')) == '::')
end

local function rfc5952()
	-- RFC 5952 - A Recommendation for IPv6 Address Text Representation
	-- 1.  Introduction
	all_the_same {
		'2001:db8:0:0:1:0:0:1',
		'2001:0db8:0:0:1:0:0:1',
		'2001:db8::1:0:0:1',
		'2001:db8::0:1:0:0:1',
		'2001:0db8::1:0:0:1',
		'2001:db8:0:0:1::1',
		'2001:db8:0000:0:1::1',
		'2001:DB8:0:0:1::1',
	}

	-- 2.1.  Leading Zeros in a 16-Bit Field
	all_the_same {
		'2001:db8:aaaa:bbbb:cccc:dddd:eeee:0001',
		'2001:db8:aaaa:bbbb:cccc:dddd:eeee:001',
		'2001:db8:aaaa:bbbb:cccc:dddd:eeee:01',
		'2001:db8:aaaa:bbbb:cccc:dddd:eeee:1',
	}

	-- 2.2.  Zero Compression
	all_the_same {
		'2001:db8:aaaa:bbbb:cccc:dddd::1',
		'2001:db8:aaaa:bbbb:cccc:dddd:0:1',
	}
	all_the_same {
		'2001:db8:0:0:0::1',
		'2001:db8:0:0::1',
		'2001:db8:0::1',
		'2001:db8::1',
	}
	all_the_same {
		'2001:db8::aaaa:0:0:1',
		'2001:db8:0:0:aaaa::1',
	}

	-- 2.3.  Uppercase or Lowercase
	all_the_same {
		'2001:db8:aaaa:bbbb:cccc:dddd:eeee:aaaa',
		'2001:db8:aaaa:bbbb:cccc:dddd:eeee:AAAA',
		'2001:db8:aaaa:bbbb:cccc:dddd:eeee:AaAa',
	}

	-- 4.1.    Handling Leading Zeros in a 16-Bit Field
	assert(parse('2001:0db8::0001'):ipstring() == '2001:db8::1')
	assert(parse('2001:0db8:0000:1::0001'):ipstring() == '2001:db8:0:1::1')

	-- 4.2.1.  Shorten as Much as Possible
	assert(parse('2001:db8:0:0:0:0:2:1'):ipstring() == '2001:db8::2:1')
	assert(parse('2001:db8::0:1'):ipstring() == '2001:db8::1')

	-- 4.2.2.  Handling One 16-Bit 0 Field
	assert(parse('2001:db8::1:1:1:1:1'):ipstring() == '2001:db8:0:1:1:1:1:1')

	-- 4.2.3.  Choice in Placement of "::"
	assert(parse('2001:db8:0:0:1::1'):ipstring() == '2001:db8::1:0:0:1')

	-- 4.3.    Lowercase
	assert(parse('2001:DB8::ABCD:EF'):ipstring() == '2001:db8::abcd:ef')

	-- 5.      Text Representation of Special Addresses
	assert(parse('::ffff:192.0.2.1'):ipstring4() == '::ffff:192.0.2.1')
	assert(parse('0:0:0:0:0:ffff:192.0.2.1'):ipstring4() == '::ffff:192.0.2.1')
	assert(parse('1:2:3:0:0:ffff:0.0.0.0'):ipstring4() == '1:2:3::ffff:0.0.0.0')
	assert(parse('1:2:3:0:0:ffff::'):ipstring4() == '1:2:3::ffff:0.0.0.0')
end

local function misc()
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

	--print(parse('0:0:0:0:0:0:13.1.68.3'))
	assert(tostring(parse('2001:0DB8:0000:CD30:0000:0000:0000:0000/60'))
		== '2001:db8:0:cd30::/60')
	assert(tostring(parse('2001:0DB8::CD30:0:0:0:0/60')) == '2001:db8:0:cd30::/60')
	assert(tostring(parse('2001:0DB8:0:CD30::/60')) == '2001:db8:0:cd30::/60')
	dontparse('2001:0DB8:0:CD3/60')

	assert(tostring(parse('1:0:0:1::/64') * 1) == '1:0:0:2::/64')
	assert(tostring(parse('1::/64') * 5 / 32 * 3) == '1:3:0:5::/32')
	assert(tostring(parse('5::64') / 32 * -3) == '4:fffd::64/32')
	assert(tostring(parse('2::/32') ^ 1) == '2::/33')
	assert(tostring(parse('2::/32') ^ -1) == '2::/31')
	assert(tostring(parse('2::/128') * 5) == '2::5')
	assert(tostring(parse('2::/127') * 5) == '2::a/127')
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
	assert(ip:family() == 4, 'incorrect family')
	assert(tostring(ip) == '10.0.0.0/24', 'not human readable')

	assert(inet('10.0.0.0/32') == inet('10.0.0.0'))
	assert(inet('10.0.0.0/31') ~= inet('10.0.0.0'))

	assert(tostring(ip+1) == '10.0.0.1/24', 'ip adding is broken')
	assert(tostring(ip+9-1) == '10.0.0.8/24', 'ip subtract is broken')
	assert(tostring(ip*1) == '10.0.1.0/24', 'ip multiplification is broken')
	assert(tostring(ip/8) == '10.0.0.0/8', 'ip division is broken')
	assert(tostring(ip^1) == '10.0.0.0/25', 'ip power is broken')

	-- test inet4.__lt
	assert(inet('10.0.0.0/24') < inet('10.0.0.0/30'), 'inet less than is broken')
	assert(not (inet('10.0.0.0/30') > inet('10.0.0.0/30')), 'inet less than is broken')
	assert(inet('10.0.0.0/30') >= inet('10.0.0.0/30'), 'inet less than is broken')
	assert(inet('10.0.0.0/30') <= inet('10.0.0.0/30'), 'inet less than is broken')
	assert(inet('10.0.0.0/30') > inet('10.0.0.0/24'), 'inet less than is broken')
	assert(not (inet('10.0.0.0/24') > inet('10.0.0.0/30')), 'inet less than is broken')
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

	-- test inet4:flip
	assert(inet('10.0.0.1/24'):flip() == inet('10.0.1.1/24'), 'inet4.flip() is broken')
	assert(inet('10.0.0.0/24'):flip() == inet('10.0.1.0/24'), 'inet4.flip() is broken')
	assert(inet('10.0.0.0/24'):flip():flip() == inet('10.0.0.0/24'), 'inet4.flip() is broken')
	assert(inet('10.20.30.0/24'):flip() == inet('10.20.31.0/24'))
	assert(inet('10.20.30.5/24'):flip() == inet('10.20.31.5/24'))
	assert(inet('10.20.30.5/32'):flip() == inet('10.20.30.4/32'))
	assert(inet('0.0.0.0/0'):flip() == nil)
	assert(inet('::/0'):flip() == nil)
	assert(inet('::1/32'):flip() == inet('0:1::1/32'))
	assert(inet('::1/48'):flip() == inet('0:0:1::1/48'))

	assert(inet('2001:db8::/35'):contains(inet('2001:db8::/35')))
	assert(inet('2001:db8::/35'):contains(inet('2001:db8::/64')))
	assert(inet('2001:db8::/35'):contains(inet('2001:db8:1::/64')))
	assert(inet('::/0'):contains(inet('::/0')))
	assert(inet('::/0'):contains(inet('2001:db8::/35')))

	assert(#inet('::/0') == 0, 'incorrect netmask')

	assert(inet('2001:db8::/64')   <  inet('2001:db8:1::/64'))
	assert(inet('2001:db8:1::/64') <= inet('2001:db8:1::/64'))
	assert(inet('2001:db8:1::/48') <  inet('2001:db8:2::/48'))
	assert(inet('2001:db8:1::/48') <= inet('2001:db8:2::/48'))
	assert(inet('2001:db8:1::/48') <= inet('2001:db8:1::/48'))
	assert(inet('2001:db8:2::/48') >= inet('2001:db8:1::/48'))
	assert(inet('2001:db8:1::/32') <  inet('2001:db8:1::/48'))
	assert(inet('2001:db8:1::/32') <= inet('2001:db8:1::/48'))

	--XXX assert(inet('2001:db8:1:2:3:4:10/64') - inet('2001:db8:1::/64') == 42)

	do
		local ips = {
			inet('::'),
			inet('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff'),
		}
		for i=1,#ips do
			ip = ips[i]
			for j=1,128 do
				local foo = ip / j
				local bar = foo:flip()
				assert(foo ~= bar)
				assert(foo == bar:flip())
			end
		end
	end

	do
		local nets = {}
		for i=0,128,16 do
			local net = inet('::', i)
			insert(nets, net * i)
		end
		for i=2,#nets do
			local net = nets[i]
			insert(nets, net*-i)
			insert(nets, net*i)
		end
		for i=1,#nets do
			local net = nets[i]
			insert(nets, net-i)
			insert(nets, net+i)
		end
		table.sort(nets)
		--[[
		for i=1,#nets do
			print(i, nets[i]:cidrstring())
		end
		]]--
	end

	-- test inspectablity of metatable
	assert(#(getmetatable(inet('0.0.0.0/0'))) ~= nil)
	assert(#(getmetatable(inet('::/0'))) ~= nil)

	-- TODO inet6.__le
	-- TODO inet6.__eq

	assert(not inet.is4(false))
	assert(not inet.is4('foo'))
	assert(not inet.is4(42))
	assert(inet.is4(inet('0.0.0.0')))
	assert(not inet.is4(inet('::')))

	assert(not inet.is6(false))
	assert(not inet.is6('foo'))
	assert(not inet.is6(42))
	assert(not inet.is6(inet('0.0.0.0')))
	assert(inet.is6(inet('::')))

	assert(not inet.is(false))
	assert(not inet.is('foo'))
	assert(not inet.is(42))
	assert(inet.is(inet('0.0.0.0')))
	assert(inet.is(inet('::')))

	assert(inet.version == 1)

	-- check out of bounds handling
	assert(inet('0.0.0.0') - 1 == nil)
	assert(inet('255.255.255.255') + 1 == nil)
	assert(inet('::') - 1 == nil)
	assert(inet('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff') + 1 == nil)
	assert(inet('0.0.0.0/24') * -1 == nil)
	assert(inet('255.255.255.0/24') * 1 == nil)
end

local t = test.new()
t:depend(test.new(rfc4291))
t:depend(test.new(rfc5952))
t:depend(test.new(misc))
return t
