return function(port,pwd,wscb)
  pwd=pwd and crypto.toBase64("admin:"..pwd)
  local reply=function(c,msg,typ,len)
    c:send("HTTP/1.1 "..(tonumber(msg)and msg or 200).." OK\r\nContent-Type: "..(typ or "text/html")..(msg:match("^\31\139")and "\r\nContent-Encoding: gzip" or "").."\r\nConnection: close\r\nContent-Length: "..(len or #msg).."\r\n\r\n"..msg)
  end
  local serve=function(c,path,typ)
    if file.open(path..".gz")then path=path..".gz" elseif not file.open(path)then return reply(c,"404")end
    local len,cur=file.seek("end"),256 file.seek("set")
    c:on("sent",function(c)if cur<len then file.open(path)cur=256+file.seek("set",cur)c:send(file.read(256))end end)
    reply(c,file.read(256)or "",typ,len)
  end
  local wsdec,wsenc,websockets=wscb and function(c)
    if #c<2 then return end
    local second=c:byte(2)
    local len,offset=bit.band(second,0x7f),2
    if len==126 then
      if #c<4 then return end
      len,offset=bit.bor(bit.lshift(c:byte(3),8),c:byte(4)),4
    end
    local mask=bit.band(second,0x80)>0
    if mask then offset=offset+4 end
    if #c<offset+len then return end
    local first,payload=c:byte(1),c:sub(offset+1,offset+len)
    assert(#payload==len,"bad len")
    return mask and crypto.mask(payload,c:sub(offset-3,offset))or payload--,c:sub(offset+len+1),bit.band(first,0xf)--extra,opcode
  end,function(msg)--opcode 0x1 is string, 0x9 is ping, 0xA is pong, 0x80 is FIN, mask is always 0
    if msg==nil then return "\138\0"end--pong is string.char(bit.bor(0x80,0xA),0)
    local len=#msg
    if len<126 then return string.char(0x81,len)..msg end
    return string.char(0x81,126,bit.band(bit.rshift(len,8),0xff),bit.band(len,0xff))..msg
  end,{}
  local bcast=function(s)for _,v in pairs(websockets)do v:send(wsenc(s))end end
  net.createServer(net.TCP,61):listen(port or 80,function(c)
    c:on("receive",function(c,r)
      local url,hdrs,body=r:match("^%w- /(.-) HTTP/1.-\r\n(.-)\r\n\r\n(.*)")
      if not hdrs then return reply(c,"400")end
      local key=hdrs:match("Sec%-WebSocket%-Key: (.-)\r")
      if key and wsenc then
        c:send("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: "..crypto.toBase64(crypto.sha1(key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11")).."\r\n\r\n"..wsenc(wscb and wscb()))
        websockets[c]=c key=nil return c:on("receive",function(m)return wscb and wscb(wsdec(m))end)
      elseif url:match("^edit")then
        if pwd and hdrs:match("Authorization: Basic (.-)\r")~=pwd then return reply(c,"401",'text/html\r\nWWW-Authenticate: Basic realm="Login"')end
        local cmd,arg=url:gsub('%%(%x%x)',function(h)return string.char(tonumber(h,16))end):match("?(%w+)=/(.*)")
        if cmd=="list" then return reply(c,cjson.encode(file.list()))end
        if cmd=="run" then node.output(function(s)node.output(reply(c,s))end,0)return node.input(arg)end
        if cmd=="edit" then return serve(c,arg,"application/octet-stream\r\nContent-Disposition: attachment; filename='"..(arg:match("www/(.*)") or arg).."';")end
        local boundary=hdrs:match("Content%-Type: multipart/form%-data; boundary=(.-)\r")
        if boundary then
          local len=(tonumber(hdrs:match("Content%-Length: (.-)\r")) or 0)-#boundary-9
          if #body then r=body end
          local save=function(c,r)
            local head,tail,path=r:find('^%-%-'..boundary..'\r\nContent%-D.-filename="/(.-)"\r\n.-\r\n\r\n')
            if path then hdrs=nil len=len-tail+head file.open(path,"w")else tail=0 end
            if not hdrs then
              local chunk=r:sub(tail+1,len+tail)
              file.write(chunk)len=len-#chunk
              if len<=0 then file.close()reply(c,"")end
            end
          end
          save(c,r)return c:on("receive",save)
        end
      end
      serve(c,"www/"..(url=="" and "index.htm" or url))
    end)
    c:on("disconnection",function(c)websockets[c]=nil end)
  end)
  return bcast
end
