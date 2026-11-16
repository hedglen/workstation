-- Favorited paths stored locally in mpv's active config, not in Git.
-- ModernZ-compatible removal uses mpv's built-in selection interface.
local input = require "mp.input"
local file = mp.command_native({"expand-path", "~~/favorites.txt"})
local function read()
    local a, f = {}, io.open(file, "r")
    if not f then return a end
    for line in f:lines() do
        if line ~= "" then table.insert(a, line) end
    end
    f:close()
    return a
end
local function write(a)
    local f = io.open(file, "w")
    if not f then mp.osd_message("Favorites: unable to write file"); return false end
    for _, p in ipairs(a) do f:write(p, "\n") end
    f:close()
    return true
end
local function add()
    local p = mp.get_property("path")
    if not p or p == "" then return end
    local a = read()
    for _, v in ipairs(a) do if v == p then mp.osd_message("Already a favorite"); return end end
    table.insert(a, p)
    if write(a) then mp.osd_message("Added favorite") end
end
local function open()
    local a = read()
    if #a == 0 then mp.osd_message("No favorites yet"); return end
    -- This playlist is explicit (Scimitar button 4), not automatic folder scanning.
    mp.commandv("loadlist", file, "replace")
end
local function remove()
    local a = read()
    if #a == 0 then mp.osd_message("No favorites to remove"); return end
    local labels = {}
    for i, p in ipairs(a) do
        labels[i] = p:match("[^/\\]+$") or p
    end
    input.select({
        prompt = "Remove favorite:",
        items = labels,
        submit = function(index)
            if not index or not a[index] then return end
            table.remove(a, index)
            if write(a) then mp.osd_message("Removed favorite") end
        end,
    })
end
mp.register_script_message("favorites-open", open)
mp.register_script_message("favorites-add", add)
mp.register_script_message("favorites-remove-menu", remove)
