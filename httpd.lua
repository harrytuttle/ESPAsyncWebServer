return function(port,pwd,wscb)
  local websockets,gzmagic={},string.char(0x5e,0x1f,0x8b)
  local reply=function(c,msg,typ,len)
    c:send("HTTP/1.1 "..(tonumber(msg)and msg or 200).." OK\r\nContent-Type: "..(typ or "text/html")..(msg:match(gzmagic)and "\r\nContent-Encoding: gzip" or "").."\r\nConnection: close\r\nContent-Length: "..(len or #msg).."\r\n\r\n"..msg)
  end
  local serve=function(c,path,typ)
    if file.exists(path..".gz")then path=path..".gz" elseif not file.exists(path)then return reply(c,"404")end
    file.open(path,"r")file.seek("end")local len=file.seek()file.seek("set")
    c:on("sent",function(c)if file.seek()<len then c:send(file.read(1024))end end)
    reply(c,file.read(512)or "",typ,len)
  end
  local wsdec,wsenc=function(c)
    if #c<2 then return end
    local second=c:byte(2)
    local len,offset=bit.band(second,0x7f),2
    if len==126 then
      if #c<4 then return end
      len,offset=bit.bor(bit.lshift(c:byte(3),8),c:byte(4)),4
    end
    local mask=band(second,0x80)>0
    if mask then offset=offset+4 end
    if #c<offset+len then return end
    local first,payload = c:byte(1),c:sub(offset+1,offset+len)
    assert(#payload==len,"bad len")
    if mask then payload=crypto.mask(payload,c:sub(offset-3,offset))end
    local extra=c:sub(offset+len+1)
    local opcode=bit.band(first,0xf)
    return payload,extra,opcode
  end,function(msg)--opcode 0x1 is string, 0x9 is ping, 0xA is pong, 0x80 is FIN, mask is always 0
    if not msg then return string.char(bit.bor(0x80,0xA),0)end
    local len = #msg
    if len<126 then return string.char(bit.bor(0x80,0x1),len)..msg end
    return string.char(bit.bor(0x80,0x1),126,bit.band(bit.rshift(len,8),0xff),bit.band(len,0xff))..msg
  end
  local bcast=function(s)for _,v in pairs(websockets)do v:send(wsenc(s))end end
  net.createServer(net.TCP,61):listen(port or 80,function(c)
    c:on("receive",function(c,r)
      local url,hdrs,body=r:match("^%w- /(.-) HTTP/1.-\r\n(.-)\r\n\r\n(.*)")
      if not hdrs then return reply(c,"400")end
      local key=hdrs:match("Sec%-WebSocket%-Key: (.-)\r")
      if key then
        c:send("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: "..crypto.toBase64(crypto.sha1(key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11")).."\r\n\r\n"..wsenc("hello"))
        c:on("receive",function(m)if wscb then wscb(wsdec(m))end end)websockets[c]=c key=nil
        return tmr.alarm(5,2500,1,function()c:send(wsenc(""..node.heap()))end)
      elseif url:match("^edit")then
        if hdrs:match("Authorization: Basic (.-)\r")~=crypto.toBase64("admin:"..(pwd or "")) then return reply(c,"401",'text/html\r\nWWW-Authenticate: Basic realm="Login"')end
        local cmd,arg=url:gsub('%%(%x%x)',function(h)return string.char(tonumber(h,16))end):match("?(%w+)=/(.*)")
      end
    end)
    c:on("disconnection",function(c)websockets[c]=nil end)
  end)
  return bcast
end
