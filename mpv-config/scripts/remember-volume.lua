-- Save and restore volume and mute, independently of per-video resume position.
local state = mp.command_native({"expand-path", "~~/volume.conf"})
local function restore()
    local f = io.open(state, "r")
    if not f then return end
    local s = f:read("*a") or ""
    f:close()
    local vol = tonumber(s:match("volume=([%d%.]+)"))
    local mute = s:match("mute=(%a+)")
    if vol then mp.set_property_number("volume", math.min(100, math.max(0, vol))) end
    if mute == "yes" or mute == "no" then mp.set_property("mute", mute) end
end
local function save()
    local f = io.open(state, "w")
    if not f then return end
    f:write("volume=", tostring(mp.get_property_number("volume", 80)), "\n")
    f:write("mute=", tostring(mp.get_property("mute", "no")), "\n")
    f:close()
end
restore()
mp.register_event("shutdown", save)
