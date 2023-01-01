local common = require 'inet.common'
local bitops = require 'inet.bitops'

local format = string.format
local floor = math.floor
local min = math.min
local max = math.max
local pow = math.pow
local insert = table.insert

local lshift = bitops.lshift
local rshift = bitops.rshift
local band = bitops.band
local extract = bitops.extract
local replace = bitops.replace
local bxor = bitops.bxor
local bmask = bitops.bmask

if not pow then
	function pow(x, y) return x ^ y end
end

local get_mt = common.get_mt

local mixed_networks

local mt2fam = {}

local inet = {}
inet.__index = inet

local inet4 = setmetatable({}, inet)
inet4.__index = inet4
mt2fam[inet4] = 4

local inet6 = setmetatable({}, inet)
inet6.__index = inet6
mt2fam[inet6] = 6

local function is_inet4(t)
	local mt = get_mt(t)
	return mt == inet4
end

local function is_inet6(t)
	local mt = get_mt(t)
	return mt == inet6
end

local function is_inet(t)
	local mt = get_mt(t)
	return mt == inet4 or mt == inet6
end

function inet:__len()
	local mask = self.mask
	if mask == nil then return 0 end -- make metatable inspectable
	return mask
end
inet4.__len = inet.__len
inet6.__len = inet.__len
-- add a 'public' len method for luajit
inet.len = inet.__len
inet4.len = inet.__len
inet6.len = inet.__len

function inet:subnets(n)
	if type(n) ~= 'number' then return nil, 'n must be a number' end
	local hostmask = is_inet6(self) and 128 or 32
	if n < 0 or n > hostmask then return nil, 'invalid mask given' end
	local mask = self.mask
	local bits = n - mask
	local subnets = pow(2, bits)
	return subnets
end

function inet:family()
	local mt = assert(getmetatable(self))
	local ret = assert(mt2fam[mt])
	return ret
end

function inet:full_family()
	return format('ipv%d', self:family())
end

local ipv4_parser
local ipv6_parser
do
	local lpeg = require 'lpeg'
	local C, Ct = lpeg.C, lpeg.Ct
	local S, R = lpeg.S, lpeg.R
	local B, Cc = lpeg.B, lpeg.Cc

	local digit = R('09')

	local ipv4addr
	do
		local dot = S('.')
		local zero = S('0')
		local octet0 = B(zero) * Cc('0')
		local octet1 = R('19')
		local octet2 = R('19') * digit
		local octet31 = S('1') * digit * digit
		local octet32 = R('04') * digit
		local octet325 = S('5') * R('05')
		local octet3 = octet31 + (S('2') * (octet32 + octet325))
		local octet = zero^0 * (C(octet3 + octet2 + octet1) + octet0) / tonumber
		ipv4addr = octet * dot * octet * dot * octet * dot * octet
		local mask12 = R('12') * digit
		local mask3 = S('3') * R('02')
		local netmask = S('/') * C(mask12 + mask3 + digit)
		ipv4_parser = ipv4addr * (netmask + Cc()) * -1
	end

	do
		local function hextonumber(hex) return tonumber(hex, 16) end
		local hexdigit = R('09') + R('af') + R('AF')
		local piece = C(hexdigit * (hexdigit^-3)) / hextonumber
		local col = S(':')
		local colcol = C(col * col)
		local picol = piece * col
		local colpi = col * piece
		local ipv4embed = ipv4addr / function(a,b,c,d)
			return lshift(a, 8) + b, lshift(c, 8) + d
		end
		local last32bits = (ipv4embed + (picol * piece))
		local full = picol * picol * picol * picol * picol * picol * last32bits
		local partial = (piece * (colpi^-6))^-1 * colcol * ((picol^-6)*(ipv4embed+piece))^-1
		local netmask = S('/') * C((digit^-3)) / tonumber
		local pieces = full + partial
		ipv6_parser = Ct(pieces) * ((netmask + Cc())^-1) * -1
	end
end

local function build_bip(o1, o2, o3, o4)
	return lshift(o1, 24) + lshift(o2, 16) + lshift(o3, 8) + o4
end

local function inet4_from_string(ipstr)
	local o1, o2, o3, o4, mask = ipv4_parser:match(ipstr)
	if not o1 then return nil, 'parse error' end

	local bip = build_bip(o1, o2, o3, o4)
	return bip, tonumber(mask)
end

local function inet4_from_number(bip)
	if bip < 0 or bip > 0xffffffff then
		return nil, 'out of range'
	end
	return bip
end

local function inet4_from_table(t)
	if #t ~= 4 then return nil, 'invalid length' end
	for i=1,4 do
		local v = t[i]
		if type(v) ~= 'number' then return nil, 'invalid number' end
		if v < 0 or v > 255 then return nil, 'octet out of range' end
	end
	return build_bip(t[1], t[2], t[3], t[4])
end

local inet4_constructors = {
	string = inet4_from_string,
	number = inet4_from_number,
	table  = inet4_from_table,
}

local function inet6_from_string(ipstr)
	local pcs, netmask = ipv6_parser:match(ipstr)
	if not pcs then return nil, 'parse error' end
	if #pcs > 8 then return nil, 'too many pieces' end
	local zero_pieces = 8 - #pcs
	for i=1,#pcs do
		if pcs[i] == '::' then
			pcs[i] = 0
			for j=#pcs,i,-1 do
				pcs[j+zero_pieces] = pcs[j]
			end
			for j=1,zero_pieces do
				pcs[i+j] = 0
			end
		end
	end
	if #pcs > 8 then return nil, 'too many pieces' end
	if netmask ~= nil and netmask > 128 then
		return nil, 'invalid netmask'
	end
	return pcs, netmask
end

local function inet6_from_table(t)
	if #t ~= 8 then return nil, 'invalid length' end
	for i=1,8 do
		local v = t[i]
		if type(v) ~= 'number' then return nil, 'invalid number' end
		if v < 0 or v > 0xffff then return nil, 'piece out of range' end
	end
	return { t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8] }
end

local inet6_constructors = {
	string = inet6_from_string,
	table  = inet6_from_table,
}

local function decide_mask(from_ip, override, high)
	local newmask = from_ip
	if override then
		if type(override) == 'number' and override >= 0 and override <= high then
			if from_ip ~= nil then
				return nil, 'multiple masks supplied'
			end
			newmask = override
		else
			return nil, 'invalid mask'
		end
	else
		if not newmask then
			newmask = high
		end
	end
	return newmask
end

local function generic_new(constructors, high, ip, mask)
	local type_ip = type(ip)
	local constructor = constructors[type_ip]
	if not constructor then
		return nil, 'invalid ip argument'
	end
	local iir, ourmask = constructor(ip)
	if not iir then
		return nil, ourmask
	end
	local outmask, err = decide_mask(ourmask, mask, high)
	if not outmask then return nil, err end

	return iir, outmask
end

local function new_inet4(ip, mask, strict)
	strict = (strict == nil and false) or strict

	local bip, outmask = generic_new(inet4_constructors, 32, ip, mask)
	if not bip then return nil, outmask end

	local masked = band(bip, bmask(32 - outmask))
	if masked ~= bip then
		if strict then
			local str_ip = inet4.ipstring({bip = bip, mask = outmask})
			error(str_ip..' has host bits set')
		else
			bip = masked
		end
	end

	return setmetatable({
		bip = bip,
		mask = outmask,
	}, inet4)
end

local function new_inet6(ip, mask)
	local pcs, outmask = generic_new(inet6_constructors, 128, ip, mask)
	if not pcs then return nil, outmask end

	-- TODO validate pcs/outmask as we do for inet4

	local r = setmetatable({
		pcs = pcs,
		mask = outmask,
	}, inet6)

	-- ensure that the result is balanced
	if not r:is_balanced() then
		r:balance()
		return nil, tostring(r)..' unbalanced'
	end

	return r
end

local function new_inet(ip, mask)
	local is_ipv6
	local type_ip = type(ip)
	if type_ip == 'string' then
		is_ipv6 = string.find(ip, ':', 1, true)
	elseif type_ip == 'number' then
		is_ipv6 = false
	elseif is_inet4(ip) then
		mask = mask or ip:len()
		ip = ip.bip
		is_ipv6 = false
	elseif is_inet6(ip) then
		mask = mask or ip:len()
		ip = ip.pcs
		is_ipv6 = true
	elseif type_ip == 'table' then
		local n = #ip
		if n == 8 then
			is_ipv6 = true
		elseif n == 4 then
			is_ipv6 = false
		else
			return nil, 'invalid table'
		end
	else
		return nil, 'invalid ip type'
	end

	if is_ipv6 then
		return new_inet6(ip, mask)
	else
		return new_inet4(ip, mask, true)
	end
end

local function tostr4(self, withmask)
	-- return human readable
	local bip, mask = self.bip, self.mask
	local o1, o2, o3, o4
	o1 = band(rshift(bip, 24), 0xff)
	o2 = band(rshift(bip, 16), 0xff)
	o3 = band(rshift(bip, 8), 0xff)
	o4 = band(bip, 0xff)
	if (mask == nil or mask == 32 or withmask == false) and withmask ~= true then
		return string.format('%d.%d.%d.%d', o1, o2, o3, o4)
	else
		return string.format('%d.%d.%d.%d/%d', o1, o2, o3, o4, mask)
	end
end

function inet4:__tostring()
	return tostr4(self)
end

function inet4:ipstring()
	return tostr4(self, false)
end

function inet4:cidrstring()
	return tostr4(self, true)
end

function inet4:__add(n)
	local type_n = type(n)
	if type_n == 'number' then
		return new_inet4(self.bip + n, self.mask)
	elseif type_n == 'table' and is_inet6(n) then
		return inet6.__add(n, self)
	else
		return nil, 'invalid argument'
	end
end

function inet4:__sub(n)
	local type_n = type(n)
	if type_n == 'number' then
		return new_inet4(self.bip - n, self.mask)
	elseif type_n == 'table' and is_inet4(n) then
		return self.bip - n.bip
	else
		return nil, 'invalid argument'
	end
end

function inet4:__mul(n)
	local new = self.bip + (n * pow(2, 32 - self.mask))
	return new_inet4(new, self.mask)
end

function inet4:__div(n)
	return new_inet4(self.bip, n)
end

function inet4:__pow(n)
	return new_inet4(self.bip, self.mask + n)
end

function inet4:clone()
	return new_inet4(self.bip, self.mask)
end

function inet4:contains(other)
	if is_inet6(other) then return false end
	if self.mask >= other.mask then
		return false
	end
	local mask = self.mask -- make test
	local self_netbits = replace(self.bip, 0, 0, 32-mask)
	local other_netbits = replace(other.bip, 0, 0, 32-mask)
	return self_netbits == other_netbits
end

function inet4:__lt(other)
	if not is_inet4(other) then
		if is_inet6(other) then
			return true
		end
		return nil
	end
	if self.bip == other.bip then
		return self.mask < other.mask
	end
	return self.bip < other.bip
end

function inet4:__le(other)
	if not is_inet4(other) then
		if is_inet6(other) then
			return true
		end
		return nil
	end
	if self.mask < other.mask then
		return false
	end
	local mask = other.mask
	if mask == 32 then
		return self.bip == other.bip
	else
		local selfnet = replace(self.bip, 0, 0, 32-mask)
		local othernet = replace(other.bip, 0, 0, 32-mask)
		return selfnet == othernet
	end
end

function inet4:__eq(other)
	if getmetatable(other) ~= inet4 then return false end
	return self.bip == other.bip and self.mask == other.mask
end

function inet4:network()
	local hostbits = 32 - self.mask
	return new_inet4(lshift(rshift(self.bip, hostbits), hostbits), self.mask)
end

function inet4:netmask()
	local mask = self.mask
	if mask == 0 then
		return new_inet4(0, 32)
	elseif mask == 32 then
		return new_inet4(0xffffffff, 32)
	end
	local hostbits = 32 - mask
	return new_inet4(replace(0xffffffff, 0, 0, hostbits), 32)
end

function inet4:hostmask()
	local mask = self.mask
	if mask == 0 then
		return new_inet4(0xffffffff, 32)
	elseif mask == 32 then
		return new_inet4(0, 32)
	end
	local hostbits = 32 - mask
	return new_inet4(replace(0xffffffff, 0, hostbits, mask), 32)
end

function inet4:flip()
	-- find twin by flipping the last network bit
	local mask = self.mask
	if mask == 0 then return nil end
	local hostbits = 32 - mask
	local flipbit = lshift(1, hostbits)
	return new_inet4(bxor(self.bip, flipbit), mask)
end

function inet4:bits(n)
	if type(n) ~= 'number' then return nil, 'n must be a number' end
	if n < 1 or n > 32 or 32 % n ~= 0 then return nil, 'invalid value for n' end
	local t = {}
	local bip = self.bip
	for i=32-n,0,-n do
		insert(t, extract(bip, i, n))
	end
	return t
end

-- each ipv6 address is stored as eight pieces
-- 1111:2222:3333:4444:5555:6666:7777:8888
-- in the table pcs.

function inet6:is_balanced()
	local pcs = self.pcs
	for i=1,8 do
		local piece = pcs[i]
		if piece < 0 or piece > 0xffff then
			return false
		end
	end
	return true
end

local function do_balance(pcs, quick)
	local i = 8
	while i > 1 do
		if quick and pcs[i] > 0 then
			break
		end
		while pcs[i] < 0 do
			pcs[i] = pcs[i] + 0x10000
			pcs[i-1] = pcs[i-1] - 1
		end
		i = i - 1
	end
	i = 8
	while i > 1 do
		local extra = rshift(pcs[i], 16)
		if quick and extra == 0 then
			break
		end
		pcs[i] = band(pcs[i], 0xffff)
		pcs[i-1] = pcs[i-1] + extra
		i = i - 1
	end
	if pcs[1] < 0 or pcs[1] > 0xffff then
		return nil, 'out of range'
	end
	return true
end

function inet6:balance(quick)
	local ok, err = do_balance(self.pcs, quick)
	if not ok then return nil, err end
	return self
end

local function tohex(n)
	if n == nil then return nil end
	return format('%x', n)
end

local function tostr6(self, withmask, embeddedipv4)
	-- return human readable
	local pcs = self.pcs
	local zeros = {}

	if embeddedipv4 == nil then
		embeddedipv4 = mixed_networks:contains(self)
	end

	local ipv6pieces = 8
	if embeddedipv4 then
		ipv6pieces = 6
	end

	-- count zero clusters
	local first_zero = 0
	local prev_was_zero = false
	for i=1,ipv6pieces do
		if pcs[i] == 0 then
			if prev_was_zero then
				zeros[first_zero] = zeros[first_zero] + 1
			else
				first_zero = i
				zeros[first_zero] = 1
			end
			prev_was_zero = true
		else
			prev_was_zero = false
		end
	end

	-- find the first largest zero cluster
	local zeros_begin = nil
	local zeros_cnt = 1
	for begin=1,ipv6pieces do
		local cnt = zeros[begin] or 0
		if cnt > zeros_cnt then
			zeros_begin = begin
			zeros_cnt = cnt
		end
	end

	-- format ipv6 address
	local out = ''
	local i = 1
	while i <= ipv6pieces do
		if i == zeros_begin then
			if i > 1 then
				out = out .. ':'
			else
				out = out .. '::'
			end
			i = i + zeros_cnt
		else
			local p = pcs[i]
			local hexdigits = tohex(p)
			out = out .. hexdigits
			if i ~= 8 then
				out = out .. ':'
			end
			i = i + 1
		end
	end

	if embeddedipv4 then
		out = out .. new_inet4(lshift(pcs[7], 16) + pcs[8]):ipstring()
	end

	local mask = self.mask
	if (mask == nil or mask == 128 or withmask == false) and withmask ~= true then
		return out
	else
		return string.format('%s/%d', out, mask)
	end
end

function inet6:__tostring()
	return tostr6(self)
end

function inet6:ipstring()
	return tostr6(self, false)
end

function inet6:ipstring4()
	return tostr6(self, false, true)
end

function inet6:ipstring6()
	return tostr6(self, false, false)
end

function inet6:cidrstring()
	return tostr6(self, true)
end

function inet6:clone()
	return new_inet6(self.pcs, self.mask)
end

function inet6:contains(other)
	-- self contains other
	local mask = self.mask

	if mask > other.mask then
		return false
	end

	local snet = self:network()
	local foo, err = other:__div(mask)
	if not foo then
		print(err)
	end
	local onet = (other / mask):network()

	return snet == onet
end

function inet6:__lt(other)
	if not is_inet6(other) then
		if is_inet4(other) then
			return false
		end
		return nil
	end
	-- self < other
	local spcs = self.pcs
	local opcs = other.pcs

	for i=1,8 do
		if spcs[i] < opcs[i] then
			return true
		end
		if spcs[i] > opcs[i] then
			return false
		end
	end

	return self.mask < other.mask
end

function inet6:__le(other)
	if not is_inet6(other) then
		if is_inet4(other) then
			return false
		end
		return nil
	end
	-- self <= other
	local spcs = self.pcs
	local opcs = other.pcs
	for i=1,8 do
		if spcs[i] < opcs[i] then
			return true
		end
		if spcs[i] > opcs[i] then
			return false
		end
	end

	return self.mask <= other.mask
end

function inet6:__eq(other)
	if self.mask ~= other.mask then
		return false
	end
	local spcs = self.pcs
	local opcs = other.pcs
	for i=1,8 do
		if spcs[i] ~= opcs[i] then
			return false
		end
	end
	return true
end

function inet6:__div(n)
	return new_inet6(self.pcs, n)
end

function inet6:__pow(n)
	return new_inet6(self.pcs, self.mask + n)
end

function inet6:__add(n)
	local new = self:clone()
	local pcs = new.pcs
	local type_n = type(n)
	if type_n == 'number' then
		pcs[8] = pcs[8] + n
	elseif type_n == 'table' and is_inet4(n) then
		if new:len() ~= 96 then return nil, 'inet6 must be a /96' end
		if n:len()   ~= 32 then return nil, 'inet4 must be a /32' end
		if not mixed_networks:contains(new) then
			return nil, 'inet6 is not a mixed notation network'
		end
		if new ~= new:network() then
			return nil, 'inet6 must be a network address'
		end
		local bip = n.bip
		pcs[7] = band(rshift(bip, 16), 0xffff)
		pcs[8] = band(bip, 0xffff)
		new.mask = 128
	else
		return nil, 'invalid argument'
	end
	return new:balance(true)
end

function inet6:__sub(n)
	local type_n = type(n)
	if type_n == 'number' then
		return self + (n*-1)
	elseif type_n == 'table' and is_inet6(n) then
		local spcs = self.pcs
		local npcs = n.pcs

		local dpcs = {}
		for i=1,8 do
			dpcs[i] = spcs[i] - npcs[i]
		end
		local ok, err = do_balance(dpcs)
		if not ok then return nil, err, dpcs end

		local ret = 0
		for i=1,8 do
			local v = dpcs[i]
			if (i < 7 and v > 0) or v < 0 or v > 0xffff then
				return nil, 'result is out of range', dpcs
			end
			local bits = (8 - i) * 16
			ret = ret + lshift(band(v, 0xffff), bits)
		end

		if self.len() == 128 and n.len() == 96 and mixed_networks:contains(self)
			  and mixed_networks:contains(n) then
			return new_inet4(ret)
		else
			return ret
		end
	else
		return nil, 'invalid argument'
	end
end

function inet6:network()
	local netbits = self.mask
	local pcs = self.pcs
	local newpcs = { 0, 0, 0, 0, 0, 0, 0, 0 }
	for i=1,8 do
		if netbits >= i*16 then
			newpcs[i] = pcs[i]
		elseif netbits <= (i-1)*16 then
			break -- the rest is already zero
		else
			local netbitsleft = 16-(netbits-((i-1)*16))
			newpcs[i] = lshift(rshift(pcs[i], netbitsleft), netbitsleft)
		end
	end
	return new_inet6(newpcs, netbits)
end

local function build_inet6_mask(z1, o1, z2)
	assert(z1 + o1 + z2 == 128)
	local pcs = { 0, 0, 0, 0, 0, 0, 0, 0 }
	local b, l = z1, o1
	if l > 0 then
		local e = b + l - 1
		local bpcs = floor(b / 16) + 1
		local epcs = floor(e / 16) + 1
		for j=bpcs,epcs do
			local o = (j-1) * 16
			local bo = max(0,b-o)
			local width = min(15,e-o)+1 - bo
			local fbit = 16 - width - bo
			local v = replace(pcs[j], 0xffff, fbit, width)
			pcs[j] = v
		end
	end
	return new_inet6(pcs)
end

function inet6:netmask()
	local mask = self.mask
	return build_inet6_mask(0, mask, 128 - mask)
end

function inet6:hostmask()
	local mask = self.mask
	return build_inet6_mask(mask, 128 - mask, 0)
end

function inet6:flip()
	-- find twin by flipping the last network bit
	local mask = self.mask
	if mask == 0 then return nil end
	local block = rshift(mask, 4)+1
	local maskbits = band(mask, 0xf)
	local bitno = 16 - maskbits
	if bitno == 16 then
		block = block - 1
		bitno = 0
	end
	local flipbit = lshift(1, bitno)
	local r = self:clone()
	local val = r.pcs[block]
	r.pcs[block] = bxor(val, flipbit)
	--print(mask, block, maskbits, bitno, flipbit, self, r:balance())
	return r
end


function inet6:__mul(n)
	local new = self:clone()
	local mask = new.mask
	if mask == 0 then return nil, 'unable to perform operation' end
	local pcs = new.pcs
	local netbitoverflow = mask % 16
	local netbitremainder = (128-mask) % 16
	local p = (mask - netbitoverflow) / 16
	if netbitremainder ~= 0 then
		p = p + 1
	end
	local was_negative = false
	if n < 0 then
		n = n * -1
		was_negative = true
	end
	local shiftet = lshift(n, netbitremainder)
	local high_shift = rshift(shiftet, 16)
	local low_shift = band(shiftet, 0xffff)
	--print(p, netbitoverflow, tohex(shiftet), tohex(high_shift), tohex(low_shift))
	if was_negative then
		high_shift = -high_shift
		low_shift = -low_shift
	end
	if p > 2 then
		pcs[p-1] = pcs[p-1] + high_shift
	end
	pcs[p] = pcs[p] + low_shift
	return new:balance()
end

function inet6:bits(n)
	if type(n) ~= 'number' then return nil, 'n must be a number' end
	if n < 1 or n > 32 or 128 % n ~= 0 then return nil, 'invalid value for n' end
	local t = {}
	local pcs = self.pcs
	if n == 32 then
		for i=1,8,2 do
			insert(t, lshift(pcs[i], 16) + pcs[i+1])
		end
	else
		for i=1,8 do
			local p = pcs[i]
			for j=16-n,0,-n do
				insert(t, extract(p, j, n))
			end
		end
	end
	return t
end

local M = {}

function M.set_mixed_networks(mixed_set)
	mixed_networks = mixed_set
end

M.is_inet4 = is_inet4
M.is_inet6 = is_inet6
M.is_inet  = is_inet
M.new_inet = new_inet

return M
