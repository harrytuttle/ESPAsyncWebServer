-- usage:
-- f=f or require("ds18b20")(4) for i,j in pairs(f()) do print(i,j.val,string.format("\"\\%d\\%d\\%d\\%d\\%d\\%d\\%d\\%d\"",j.addr:byte(1,8)),j.offset) end
-- then:
-- f=f or require("ds18b20")(4,{room1={addr="\40\200\176\3\0\0\128\107"}}) return (cjson or sjson).encode(f("room1"))
return function(pin,sensors)
  ow.setup(pin)
  if not sensors then
    sensors={}
    ow.reset_search(pin)
    repeat
      local addr=ow.search(pin)
      if addr then table.insert(sensors,{addr=addr}) end
      --tmr.wdclr()
    until not addr
  end
  return function(name)
    for key,sensor in pairs(sensors) do
      if not name or name == key then
        --ow.reset(pin)ow.select(pin,sensor.addr)ow.write_bytes(pin,"\68\190",1) -- ??? why not?
        ow.reset(pin)ow.select(pin,sensor.addr)ow.write(pin,0x44,1)
        ow.reset(pin)ow.select(pin,sensor.addr)ow.write(pin,0xBE,1)
        local data=ow.read_bytes(pin,9)
        if ow.crc8(string.sub(data,1,8))==data:byte(9) then
          local t=data:byte(1)+data:byte(2)*256
          if t>32767 then t=t-65536 end
  	      sensor.val=t*(sensor.addr:byte(1)==0x28 and 0.0625 or 0.5)+(sensor.offset or 0) --DS18B20, 4 fractional bits or DS18S20, 1 fractional bit
        end
      end
    end
    return name and sensors[name] or sensors
  end
end
