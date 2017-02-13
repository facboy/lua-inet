-- ipv4 / 24 = network
-- ipv6/56 * 5 = 5 /56 further down

local bit32 = require 'bit32'

local inet, inet4, inet6

inet = {}
inet.__index = inet

function inet.new(ip, mask)
	local ipv6 = string.find(ip, ':', 1, true)
	if ipv6 then
		return inet6.new(ip, mask)
	else
		return inet4.new(ip, mask)
	end
end

function inet:__len()
	return self.mask
end

local lshift = bit32.lshift
local rshift = bit32.rshift
local band = bit32.band
local replace = bit32.replace
local bxor = bit32.bxor

inet4 = {}
inet4.__index = inet4
inet4.__len = inet.__len

local ipv4_parser
local ipv6_parser
do
	local lpeg = require 'lpeg'
	local C, Ct = lpeg.C, lpeg.Ct
	local S, R = lpeg.S, lpeg.R
	local B, Cc = lpeg.B, lpeg.Cc

	local digit = R('09')

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
		local octet = zero^0 * (C(octet3 + octet2 + octet1) + octet0)
		local ipv4 = octet * dot * octet * dot * octet * dot * octet
		local mask12 = R('12') * digit
		local mask3 = S('3') * R('02')
		local netmask = S('/') * C(mask12 + mask3 + digit)
		ipv4_parser = ipv4 * (netmask + C('')) * -1
	end

	do
		local function hextonumber(hex) return tonumber(hex, 16) end
		local hexdigit = R('09') + R('af') + R('AF')
		local piece = C(hexdigit * (hexdigit^-3)) / hextonumber
		local col = S(':')
		local colcol = C(col * col)
		local picol = piece * col
		local colpi = col * piece
		local full = picol * picol * picol * picol * picol * picol * picol * piece
		local partial = (piece * (colpi^-6))^-1 * colcol * ((picol^-6)*piece)^-1
		local netmask = S('/') * C((digit^-3)) / tonumber
		ipv6_parser = Ct(full + partial) * ((netmask + C(''))^-1) * -1
	end
end

local function parse4(ipstr)
	local o1, o2, o3, o4, mask = ipv4_parser:match(ipstr)
	if o1 == nil then return nil end

	local bip = lshift(o1, 24) + lshift(o2, 16) + lshift(o3, 8) + o4
	return bip, tonumber(mask)
end

function inet4.new(ip, mask)
	local bip, ourmask
	if type(ip) == 'string' then
		bip, ourmask = parse4(ip)
		if bip == nil then
			return nil
		end
	elseif type(ip) == 'number' then
		bip = ip
	end
	if mask then
		if type(mask) == 'number' and mask >= 0 and mask <= 32 then
			ourmask = mask
		else
			error('invalid mask')
		end
	else
		if not ourmask then
			ourmask = 32
		end
	end
	return setmetatable({
		bip = bip,
		mask = ourmask,
	}, inet4)
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
	return inet4.new(self.bip + n, self.mask)
end

function inet4:__sub(n)
	return inet4.new(self.bip - n, self.mask)
end

function inet4:__mul(n)
	local new = self.bip + (n * math.pow(2, 32 - self.mask))
	return inet4.new(new, self.mask)
end

function inet4:__div(n)
	return inet4.new(self.bip, n)
end

function inet4:__pow(n)
	return inet4.new(self.bip, self.mask + n)
end

function inet4:__lt(other)
	if self.mask <= other.mask then
		return false
	end
	local mask = other.mask
	local selfnet = replace(self.bip, 0, 0, 32-mask)
	local othernet = replace(other.bip, 0, 0, 32-mask)
	return selfnet == othernet
end

function inet4:__le(other)
	if self.mask < other.mask then
		return false
	end
	local mask = other.mask
	local selfnet = replace(self.bip, 0, 0, 32-mask)
	local othernet = replace(other.bip, 0, 0, 32-mask)
	return selfnet == othernet
end

function inet4:__eq(other)
	return self.bip == other.bip and self.mask == other.mask
end

function inet4:network()
	local hostbits = 32 - self.mask
	return inet4.new(lshift(rshift(self.bip, hostbits), hostbits), self.mask)
end

function inet4:netmask()
	local hostbits = 32 - self.mask
	return inet4.new(replace(0xffffffff, 0, 0, hostbits), 32)
end

function inet4:flip()
	-- find twin by flipping the last network bit
	local mask = self.mask
	if mask == 0 then return nil end
	local hostbits = 32 - mask
	local flipbit = 1 << hostbits
	return inet4.new(self.bip ~ flipbit, mask)
end

local function parse6(ipstr)
	local pcs, netmask = ipv6_parser:match(ipstr)
	if not pcs then return nil end
	if #pcs > 8 then return nil, 'too many pieces' end
	local zero_pieces = 8 - #pcs
	for i=1,#pcs do
		if pcs[i] == '::' then
			pcs[i] = 0
			for j=1,#pcs-i do
				pcs[i+j+zero_pieces] = pcs[i+j]
			end
			for j=1,zero_pieces do
				pcs[i+j] = 0
			end
		end
	end
	if #pcs > 8 then return nil, 'too many pieces' end
	if netmask == '' then
		netmask = 128
	elseif netmask > 128 then
		return nil, 'invalid netmask'
	end
	return pcs, netmask
end

inet6 = setmetatable({}, inet)
inet6.__index = inet6
inet6.__len = inet.__len

function inet6.new(ip, netmask)
	local pcs, err
	if type(ip) == 'string' then
		pcs, err = parse6(ip)
		if pcs == nil then
			return nil, err
		end
		if not netmask then
			netmask = err
		end
	elseif type(ip) == 'table' then
		pcs = { ip[1], ip[2], ip[3], ip[4],
		        ip[5], ip[6], ip[7], ip[8] }
		if not netmask then
			netmask = 128
		end
	else
		return nil
	end

	local r = setmetatable({
		pcs = pcs,
		mask = netmask,
	}, inet6)

	-- ensure that the result is balanced
	if not r:is_balanced() then
		r:balance()
		return nil, tostring(r)..' unbalanced'
	end

	return r
end

-- each ipv6 address is stored as eight pieces
-- 1111:2222:3333:4444:5555:6666:7777:8888
-- in the table pcs.

function inet6:is_balanced()
	local pcs = self.pcs
	local i = 8
	for i=i,8 do
		local piece = pcs[i]
		if piece < 0 or piece > 0xffff then
			return false
		end
	end
	return true
end

function inet6:balance(quick)
	local pcs = self.pcs
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
	pcs[1] = band(pcs[1], 0xffff)
	return self
end

local function tostr6(self, withmask)
	-- return human readable
	local pcs = self.pcs
	local zeros = {}

	-- count zero clusters
	local first_zero = 0
	local prev_was_zero = false
	for i=1,#pcs do
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

	-- find the largest zero cluster
	local zeros_begin = nil
	local zeros_cnt = 0
	for begin,cnt in pairs(zeros) do
		if cnt > zeros_cnt then
			zeros_begin = begin
			zeros_cnt = cnt
		end
	end

	-- format ipv6 address
	local out = ''
	local i = 1
	while i <= 8 do
		if i == zeros_begin then
			if i > 1 then
				out = out .. ':'
			else
				out = out .. '::'
			end
			i = i + zeros_cnt
		else
			local p = pcs[i]
			local hexdigits = string.format('%x', p)
			out = out .. hexdigits
			if i ~= 8 then
				out = out .. ':'
			end
			i = i + 1
		end
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

function inet6:cidrstring()
	return tostr6(self, true)
end

function inet6:clone()
	return inet6.new(self.pcs, self.mask)
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
	return inet6.new(self.pcs, n)
end

function inet6:__pow(n)
	return inet6.new(self.pcs, self.mask + n)
end

function inet6:__add(n)
	local new = self:clone()
	local pcs = new.pcs
	pcs[8] = pcs[8] + n
	new:balance(true)
	return new
end

function inet6:__sub(n)
	return self + (n*-1)
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
			newpcs[i] = pcs[i] >> netbitsleft << netbitsleft
		end
	end
	return inet6.new(newpcs, netbits)
end

function inet6:flip()
	-- find twin by flipping the last network bit
	local mask = self.mask
	if mask == 0 then return nil end
	local block = (mask >> 4)+1
	local maskbits = mask & 0xf
	local bitno = 16 - maskbits
	if bitno == 16 then
		block = block - 1
		bitno = 0
	end
	local flipbit = 1 << bitno
	local r = self:clone()
	local val = r.pcs[block]
	r.pcs[block] = r.pcs[block] ~ flipbit
	--print(mask, block, maskbits, bitno, flipbit, self, r:balance())
	return r
end


function inet6:__mul(n)
	local new = self:clone()
	local mask = new.mask
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
	--print(p, netbitoverflow, hex(shiftet), hex(high_shift), hex(low_shift))
	if was_negative then
		high_shift = -high_shift
		low_shift = -low_shift
	end
	if p > 2 then
		pcs[p-1] = pcs[p-1] + high_shift
	end
	pcs[p] = pcs[p] + low_shift
	new:balance()
	-- print(mask % 8)
	return new
end

return inet.new
