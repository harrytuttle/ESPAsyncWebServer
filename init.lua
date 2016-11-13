--wifi.setmode(wifi.STATION)wifi.sta.config("SSID","KEY")wifi.sta.autoconnect(1)
wifi.sta.sethostname(wifi.ap.getconfig())
print("Trying ", wifi.sta.getconfig())
print("waiting 1 second or tmr.stop(0)")
tmr.alarm(0, 1000, 1, function()
  if wifi.sta.getip() then
    tmr.stop(0)
    if mdns then mdns.register(wifi.sta.gethostname(),{service="http",port=80})end
    print(wifi.sta.getip(),wifi.sta.gethostname())
    bcast=require("httpd")(nil,nil,nil,function(msg)return msg and uart.write(0,msg)or"connected"end)
    --tmr.alarm(5,2500,1,function()bcast(""..node.heap())end)
    uart.on("data",1,bcast,1)
  end
end)
