gpio.mode(4,gpio.OUTPUT)--builtin led
gpio.mode(6,gpio.OUTPUT)--green led
gpio.mode(7,gpio.OUTPUT)--blue led
gpio.mode(8,gpio.OUTPUT)--red led
gpio.mode(2,gpio.INT)--main btn
local state=function()
  return cjson.encode({adc=adc.read(0),heap=node.heap(),btn=gpio.read(2),red=gpio.read(8),green=gpio.read(6),blue=gpio.read(7),builtin=gpio.read(4)})
end
local bcast
bcast=require("httpd")(nil,pwd,"witty.htm",function(msg)
  if msg==nil then return state()end
  if #msg<3 then return end
  --print(#msg,type(msg),msg)
  local data=cjson.decode(msg)
  if type(data.red)=="number" then gpio.write(8,data.red)end
  if type(data.green)=="number" then gpio.write(6,data.green)end
  if type(data.blue)=="number" then gpio.write(7,data.blue)end
  if type(data.builtin)=="number" then gpio.write(4,data.builtin)end
  bcast(state())
end)
local alarm=tmr.create()
alarm:alarm(5000,tmr.ALARM_AUTO,function()bcast(state())end)
gpio.trig(2,"both",function()bcast(state())end)
