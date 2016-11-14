--wifi.setmode(wifi.STATION)wifi.sta.config("SSID","KEY")wifi.sta.autoconnect(1)
local hostname,pwd=wifi.ap.getconfig()
wifi.sta.sethostname(hostname)
print("Trying ", wifi.sta.getconfig(),"\n...wait 1 second or tmr.stop(0)")
tmr.alarm(0, 1000, 1, function()
  if wifi.sta.getip() then
    tmr.stop(0)
    if mdns then mdns.register(hostname,{service="http",port=80})end
    print(wifi.sta.getip(),hostname)
    bcast=require("httpd")(nil,pwd,nil,function(msg)return msg and uart.write(0,msg)or"connected"end)
    --tmr.alarm(5,2500,1,function()bcast(""..node.heap())end)
    uart.on("data",1,bcast,1)
  end
end)
