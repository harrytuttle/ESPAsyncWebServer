local band = bit.band
local bor = bit.bor
local rshift = bit.rshift
local lshift = bit.lshift
local char = string.char
local byte = string.byte
local sub = string.sub
local applyMask = crypto.mask
local toBase64 = crypto.toBase64
local sha1 = crypto.sha1

local wsdec,wsenc=function(c)
  if #c < 2 then return end
  local second = byte(c, 2)
  local len = band(second, 0x7f)
  local offset
  if len == 126 then
    if #c < 4 then return end
    len = bor(
      lshift(byte(c, 3), 8),
      byte(c, 4))
    offset = 4
  elseif len == 127 then
    if #c < 10 then return end
    len = bor(
      -- Ignore lengths longer than 32bit
      lshift(byte(c, 7), 24),
      lshift(byte(c, 8), 16),
      lshift(byte(c, 9), 8),
      byte(c, 10))
    offset = 10
  else
    offset = 2
  end
  local mask = band(second, 0x80) > 0
  if mask then
    offset = offset + 4
  end
  if #c < offset + len then return end

  local first = byte(c, 1)
  local payload = sub(c, offset + 1, offset + len)
  assert(#payload == len, "Length mismatch")
  if mask then
    payload = applyMask(payload, sub(c, offset - 3, offset))
  end
  local extra = sub(c, offset + len + 1)
  local opcode = band(first, 0xf)
  return extra, payload, opcode
end,function(msg)--opcode 0x1 is string, 0x9 is ping, 0xA is pong, 0x80 is FIN, mask is always 0
  if not msg then return string.char(bit.bor(0x80,0xA),0)end
  local len = #msg
  if len<126 then return string.char(bit.bor(0x80,0x1),len)..msg end
  return string.char(bit.bor(0x80,0x1),126,bit.band(bit.rshift(len,8),0xff),bit.band(len,0xff))..msg
end
