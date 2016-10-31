--wifi.setmode(wifi.STATION)wifi.sta.config("SSID","KEY")wifi.sta.autoconnect(1)
wifi.sta.sethostname("nodemcu")
print("Trying ", wifi.sta.getconfig())
print("waiting 1 second or tmr.stop(0)")
tmr.alarm(0, 1000, 1, function()
  if wifi.sta.getip() then
    tmr.stop(0)
    if mdns then mdns.register(wifi.sta.gethostname(),{service="http",port=80})end print(wifi.sta.getip(),wifi.sta.gethostname())
    local bcast=require("httpd")()
  end
end)
