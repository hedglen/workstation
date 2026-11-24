-- Adaptive rendering for the 4K OLED workstation. Never changes HDR, audio,
-- subtitles, timing, decoding, or the ModernZ/Scimitar configuration.
local mp = require 'mp'
local msg = require 'mp.msg'
local shader = mp.find_config_file('shaders/FSRCNNX_x2_8-0-4-1.glsl')
local mode = 'auto'
local baseline, last = {}, nil
local options = {'scale','cscale','dscale','deband','deband-iterations',
                 'deband-threshold','deband-range','deband-grain','glsl-shaders'}
for _, name in ipairs(options) do
    baseline[name] = mp.get_property_native('options/' .. name)
end
local function set(name, value)
    if value == nil then return end
    local ok, err = mp.set_property_native('options/' .. name, value)
    if not ok then msg.warn(name .. ': ' .. tostring(err)) end
end
local function restore()
    for _, name in ipairs(options) do set(name, baseline[name]) end
    last = nil
end
local function apply()
    local w = mp.get_property_number('video-params/w', 0)
    local h = mp.get_property_number('video-params/h', 0)
    if w <= 0 or h <= 0 then return end
    local long, short = math.max(w,h), math.min(w,h)
    local gamma = mp.get_property('video-params/gamma', '')
    local fps = mp.get_property_number('container-fps', 0)
    local hdr = gamma == 'pq' or gamma == 'hlg' or gamma == 'st2084'
    local sd = long <= 1024 and short <= 576
    local hd = long <= 1280 and short <= 720
    local fhd = long <= 1920 and short <= 1080
    local tier = sd and 'SD' or hd and '720p' or fhd and '1080p' or
        (long <= 2560 and short <= 1440) and '1440p' or
        (long <= 4096 and short <= 2160) and '4K' or 'Above 4K'
    local neural = mode == 'auto' and shader and fhd and not hdr and gamma ~= ''
        and fps <= (hd and 60.1 or 30.1)
    local deband = mode == 'auto' and hd and not hdr and gamma ~= ''
    local key = table.concat({mode,tier,tostring(hdr),tostring(not not neural),tostring(deband)},':')
    if key == last then return end
    restore()
    if mode == 'auto' then
        set('scale','ewa_lanczos')
        set('cscale','ewa_lanczos')
        set('dscale','mitchell')
        -- Override only while auto is active; restore previous custom shaders in reference.
        set('glsl-shaders', neural and {shader} or {})
        set('deband', deband)
        if deband then
            set('deband-iterations',1)
            set('deband-threshold',sd and 24 or 16)
            set('deband-range',12)
            set('deband-grain',8)
        end
    elseif mode == 'performance' then
        set('scale','bilinear')
        set('cscale','bilinear')
        set('dscale','bilinear')
        set('glsl-shaders',{})
        set('deband',false)
    elseif mode == 'restoration' and not hdr then
        set('scale','ewa_lanczos')
        set('cscale','ewa_lanczos')
        set('glsl-shaders',shader and fhd and fps <= (hd and 60.1 or 30.1) and {shader} or {})
        set('deband',true)
        set('deband-iterations',2)
        set('deband-threshold',32)
        set('deband-range',12)
        set('deband-grain',12)
    end
    last = key
    msg.info('Adaptive: ' .. mode .. ' / ' .. tier .. (hdr and ' HDR' or ' SDR') ..
        (neural and ' / FSRCNNX' or ''))
end
local timer = mp.add_timeout(0.12, apply)
timer:kill()
local function schedule()
    timer:kill()
    timer:resume()
end
for _, prop in ipairs({'video-params/w','video-params/h','video-params/gamma','container-fps'}) do
    mp.observe_property(prop,'native',schedule)
end
mp.register_event('file-loaded',schedule)
mp.register_event('end-file',function() timer:kill(); restore() end)
-- Replace only the old Ctrl+F8 manual shader toggle, not any mouse bindings.
local function select_mode(value)
    mode = value
    last = nil
    apply()
    mp.osd_message('Rendering: ' .. mode, 2)
end
mp.add_forced_key_binding('Ctrl+F8','adaptive-toggle',function()
    select_mode(mode == 'auto' and 'reference' or 'auto')
end)
mp.add_key_binding('Ctrl+F9','adaptive-cycle',function()
    local next_mode = {auto='reference',reference='restoration',restoration='performance',performance='auto'}
    select_mode(next_mode[mode] or 'auto')
end)
if not shader then msg.warn('FSRCNNX missing; conventional scaling remains available.') end
