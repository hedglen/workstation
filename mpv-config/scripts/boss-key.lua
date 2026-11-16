-- Original button 10: pause playback and minimize.
local function boss()
    mp.set_property("pause", "yes")
    mp.add_timeout(0.05, function()
        mp.set_property("window-minimized", "yes")
    end)
end
for _, key in ipairs({"F22", "KP0", "KP_INS", "INS"}) do
    mp.add_forced_key_binding(key, "boss-" .. key, boss)
end
mp.register_script_message("boss-key", boss)
