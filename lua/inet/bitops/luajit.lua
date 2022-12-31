--[[ ctn: use luajit bitops ]]

local bit = require('bit')

local bit32 = {}

-------------------------------------------------------------------------------

---
-- bitops always returns signed numbers, but inet expects unsigned
local function fix_sign(n)
  if n >= 0 then
    return n
  end
  return 2^32 + n
end

local function mask(w)
  return bit.bnot(bit.lshift(0xFFFFFFFF, w))
end

function bit32.arshift(x, disp)
  return fix_sign(bit.arshift(x, disp))
end

function bit32.band(...)
  return fix_sign(bit.band(...))
end

function bit32.bnot(x)
  return fix_sign(bit.bnot(x))
end

function bit32.bor(...)
  return fix_sign(bit.bor(...))
end

function bit32.btest(...)
  return bit32.band(...) ~= 0
end

function bit32.bxor(...)
  return fix_sign(bit.bxor(...))
end

local function fieldargs(f, w)
  w = w or 1
  assert(f >= 0, "field cannot be negative")
  assert(w > 0, "width must be positive")
  assert(f + w <= 32, "trying to access non-existent bits")
  return f, w
end

function bit32.extract(n, field, width)
  local f, w = fieldargs(field, width)
  return fix_sign(bit.band(bit.rshift(n, f), mask(w)))
end

function bit32.replace(n, v, field, width)
  local f, w = fieldargs(field, width)
  local m = mask(w)
  -- return (n & ~(m << f)) | ((v & m) << f)
  return fix_sign(bit.bor(bit.band(n, bit.bnot(bit.lshift(m, f))), bit.lshift(bit.band(v, m), f)))
end

function bit32.lrotate(x, disp)
  return fix_sign(bit.rol(x, disp))
end

function bit32.lshift(x, disp)
  return fix_sign(bit.lshift(x, disp))
end

function bit32.rrotate(x, disp)
  return fix_sign(bit.ror(x, disp))
end

function bit32.rshift(x, disp)
  return fix_sign(bit.rshift(x, disp))
end

function bit32.bmask(w)
  return fix_sign(bit.lshift(0xFFFFFFFF, w))
end

-------------------------------------------------------------------------------

return bit32
