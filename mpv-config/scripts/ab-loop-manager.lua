-- Independent A/B/reset semantics. Scimitar button 12 is mapped to F11 in iCUE.
local function mark_a()
    local p = mp.get_property_number("time-pos")
    if not p then return end
    mp.set_property_number("ab-loop-a", p)
    mp.osd_message(string.format("A-B start: %.2f s", p))
end
local function mark_b()
    local p = mp.get_property_number("time-pos")
    if not p then return end
    mp.set_property_number("ab-loop-b", p)
    mp.osd_message(string.format("A-B end: %.2f s", p))
end
local function reset()
    mp.set_property("ab-loop-a", "no")
    mp.set_property("ab-loop-b", "no")
    mp.osd_message("A-B loop cleared")
end
for _, key in ipairs({"F21", "KP3", "KP_PGDWN"}) do
    mp.add_forced_key_binding(key, "mark-a-" .. key, mark_a)
end
for _, key in ipairs({"F24", "F11"}) do
    mp.add_forced_key_binding(key, "mark-b-" .. key, mark_b)
end
for _, key in ipairs({"F20", "KP2", "KP_DOWN"}) do
    mp.add_forced_key_binding(key, "reset-ab-" .. key, reset)
end
mp.register_script_message("mark-a", mark_a)
mp.register_script_message("mark-b", mark_b)
mp.register_script_message("reset", reset)
