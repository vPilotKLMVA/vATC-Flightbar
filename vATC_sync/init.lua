-- ============================================================================
-- vATC SYNC for X-Plane 12
-- Real-time VATSIM integration with SimBrief flight planning
-- ============================================================================
--
-- Copyright (c) 2025 vPilot KLMVA
-- Licensed under the MIT License
--
-- GitHub: https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12
-- Forum: https://forums.x-plane.org/profile/422092-pilot-mcwillem/
--
-- Uses FlyWithLua modules: dkjson, socket.http
-- ============================================================================

local script_dir = debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./"

-- Logging to file and console
local log_file_path = nil
local function init_log_file()
    if SCRIPT_DIRECTORY then
        log_file_path = SCRIPT_DIRECTORY .. "vATC_Log.txt"
    else
        SCRIPT_DIRECTORY = script_dir
        log_file_path = SCRIPT_DIRECTORY .. "vATC_Log.txt"
    end
    -- Clear log file on script reload
    if log_file_path then
        local f = io.open(log_file_path, "w")
        if f then
            f:write("=== vATC Sync Log Started ===\n")
            f:close()
        end
    end
end

local function log_msg(msg)
    local timestamp = os.date("!%Y-%m-%d %H:%M:%S")
    local line = "[" .. timestamp .. "] " .. tostring(msg)
    logMsg("vATC: " .. tostring(msg))
    -- Write to file
    if log_file_path then
        local f = io.open(log_file_path, "a")
        if f then
            f:write(line .. "\n")
            f:close()
        end
    end
end

local function log_data(label, data)
    if type(data) == "table" then
        log_msg(label .. ": {")
        for k, v in pairs(data) do
            log_msg("  " .. tostring(k) .. " = " .. tostring(v))
        end
        log_msg("}")
    else
        log_msg(label .. ": " .. tostring(data))
    end
end

log_msg("Loading from: " .. script_dir)

-- Load modules
local function safe_load(file, name)
    local ok, result = pcall(dofile, file)
    if ok then
        log_msg(name .. " OK")
        return result
    else
        log_msg("ERROR " .. name .. ": " .. tostring(result))
        return nil
    end
end

local VERSION = safe_load(script_dir .. "version.lua", "version")
local CONFIG = safe_load(script_dir .. "config.lua", "config")
local UTILS = safe_load(script_dir .. "utils.lua", "utils")
local ALARMS = safe_load(script_dir .. "alarms.lua", "alarms")

if not VERSION or not CONFIG or not UTILS then
    log_msg("FATAL: core modules failed")
    return
end

-- Optional modules (won't fail if missing)
if ALARMS then
    log_msg("Alarms: OK")
end

-- Load FWL libraries
local json = nil
local http = nil

local ok_json = pcall(function() json = require("dkjson") end)
if ok_json and json then
    log_msg("dkjson OK")
else
    log_msg("dkjson not found")
end

local ok_http = pcall(function() http = require("socket.http") end)
if ok_http and http then
    log_msg("socket.http OK")
else
    log_msg("socket.http not found")
end

-- Try to load HTTPS support (LuaSec)
local https = nil
local ltn12 = nil
local ok_https = pcall(function() https = require("ssl.https") end)
if ok_https and https then
    log_msg("ssl.https OK")
else
    log_msg("ssl.https not available")
end
pcall(function() ltn12 = require("ltn12") end)

-- ============================================================================
-- DATAREFS
-- ============================================================================
dataref("xp_transponder", "sim/cockpit2/radios/actuators/transponder_code", "writable")
dataref("xp_com1_freq", "sim/cockpit/radios/com1_freq_hz", "writable")
dataref("xp_latitude", "sim/flightmodel/position/latitude", "readonly")
dataref("xp_longitude", "sim/flightmodel/position/longitude", "readonly")
dataref("xp_altitude_agl", "sim/flightmodel/position/y_agl", "readonly")
dataref("xp_altitude_msl", "sim/flightmodel/position/elevation", "readonly")
dataref("xp_on_ground", "sim/flightmodel/failures/onground_any", "readonly")
dataref("xp_groundspeed", "sim/flightmodel/position/groundspeed", "readonly")
dataref("xp_baro_sea", "sim/weather/barometer_sealevel_inhg", "readonly")
dataref("xp_temp_c", "sim/weather/temperature_ambient_c", "readonly")
dataref("xp_wind_dir", "sim/weather/wind_direction_degt", "readonly")
dataref("xp_wind_speed", "sim/weather/wind_speed_kt", "readonly")
dataref("xp_gps_dme_dist", "sim/cockpit2/radios/indicators/gps_dme_distance_nm", "readonly")
dataref("xp_gps_dme_time", "sim/cockpit2/radios/indicators/gps_dme_time_min", "readonly")
dataref("xp_parking_brake", "sim/cockpit2/controls/parking_brake_ratio", "readonly")
dataref("xp_xpdr_mode", "sim/cockpit2/radios/actuators/transponder_mode", "readonly")

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
    vatsim_status = "offline",
    connected = false,
    callsign = "",
    squawk = "2000"
}

local atc = {
    controllers = {},
    nearby = {},
    current = nil,
    next_atc = nil,
    fir = "OFFLINE"
}

local vatsim_fp = {
    departure = "",
    arrival = "",
    gate = "",
    sid = "",
    star = "",
    dep_rwy = "",
    arr_rwy = "",
    approach = "",
    dep_metar = "",
    arr_metar = "",
    dep_metar_qnh = "1013",  -- Extracted from METAR
    arr_metar_qnh = "1013",  -- Extracted from METAR
    sched_etd = 0,  -- Unix timestamp
    sched_eta = 0,  -- Unix timestamp
    cruise_fl = "",  -- Cruise flight level
    step_climb_fl = ""  -- Next step climb FL (nFIR sFL)
}

local flightplan = {
    loaded = false,
    origin = "",
    destination = "",
    dest_lat = 0,
    dest_lon = 0,
    callsign = "",
    aircraft_type = ""  -- Added missing field
}

local progress = {
    phase = "PARKED",
    dist_to_dest = 0,
    eta_seconds = 0,
    groundspeed_kts = 0,
    altitude_ft = 0,
    qnh_hpa = 1013,
    etd_time = nil,      -- Time when brakes released at departure
    eta_actual = nil,    -- Time when brakes set at arrival
    brake_was_set = true -- Track brake state changes
}

local display = {
    visible = true,
    manually_hidden = false,
    pinned = true  -- NEW: Pin/unpin toggle
}
local active_callsign = ""
local last_poll = 0
local last_fms_check = 0
local draw_cache = {        -- Cached draw values to prevent flickering
    origin = "---", dest = "---", cs = "---", sqwk = "2000",
    freq = "122.800", atc_type = "UNICOM", fir = "---", fir_freq = "",
    next_fir = "---", dist = "---", etd = "---", eta = "---",
    dep_qnh = "1013", arr_qnh = "1013", ta = "STBY",
    arr_temp = "---", arr_wind = "---",
    gate = "---", sid = "---", dep_rwy = "---", star = "---", approach = "---",
    dep_metar_qnh = "1013", arr_metar_qnh = "1013",  -- NEW: METAR QNH
    step_climb_fl = "---",  -- NEW: Next step climb FL
    connected = false, vatsim_status = "offline", phase = "PARKED"
}

-- ============================================================================
-- VATSIM DATA
-- ============================================================================
local vatsim_data = nil

local function fetch_vatsim()
    local url = "https://data.vatsim.net/v3/vatsim-data.json"
    local body = nil
    local code = nil

    -- Try HTTPS first (preferred - LuaSec)
    if https then
        log_msg("Fetching VATSIM data (HTTPS)...")
        body, code = https.request(url)
        log_msg("HTTPS response: " .. tostring(code))

        if code == 200 and body then
            local f = io.open(SCRIPT_DIRECTORY .. CONFIG.data_file, "w")
            if f then
                f:write(body)
                f:close()
                log_msg("VATSIM data saved (" .. #body .. " bytes)")
            end
            return body
        end
    end

    -- Fallback: curl (available on modern Windows/Mac/Linux)
    log_msg("Fetching via curl...")
    local output_file = SCRIPT_DIRECTORY .. CONFIG.data_file
    local cmd = 'curl -s -o "' .. output_file .. '" "' .. url .. '"'
    local result = os.execute(cmd)
    if result == 0 or result == true then
        log_msg("curl fetch completed")
    else
        log_msg("curl fetch failed: " .. tostring(result))
    end

    return nil
end

local function read_vatsim()
    local path = SCRIPT_DIRECTORY .. CONFIG.data_file
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

local function parse_vatsim(content)
    if not content or not json then return nil end
    local ok, data = pcall(json.decode, content)
    if ok and data then return data end
    return nil
end

-- ============================================================================
-- FIND PILOT/PREFILE
-- ============================================================================
local function find_pilot(data, cs)
    if not data or not data.pilots or not cs then return nil end
    for _, p in ipairs(data.pilots) do
        if p.callsign and p.callsign:upper() == cs:upper() then
            return p
        end
    end
    return nil
end

-- Find pilot by matching position (within ~2nm for better matching)
local function find_pilot_by_position(data)
    if not data or not data.pilots then return nil end
    local my_lat, my_lon = xp_latitude, xp_longitude
    if not my_lat or not my_lon then return nil end

    local best_pilot = nil
    local best_dist = 999

    for _, p in ipairs(data.pilots) do
        if p.latitude and p.longitude then
            local dist = UTILS.calc_distance_nm(my_lat, my_lon, p.latitude, p.longitude)
            -- Match within 2nm, pick closest
            if dist < 2.0 and dist < best_dist then
                best_pilot = p
                best_dist = dist
            end
        end
    end

    if best_pilot then
        log_msg("Found pilot by position: " .. best_pilot.callsign .. " at " .. string.format("%.2f", best_dist) .. "nm")
    end

    return best_pilot
end

local function find_prefile(data, cs)
    if not data or not data.prefiles and not cs then return false end
    if not data.prefiles then return false end
    for _, p in ipairs(data.prefiles) do
        if p.callsign and p.callsign:upper() == cs:upper() then
            if p.flight_plan then
                vatsim_fp.departure = p.flight_plan.departure or ""
                vatsim_fp.arrival = p.flight_plan.arrival or ""
            end
            return true
        end
    end
    return false
end

-- ============================================================================
-- CONTROLLERS
-- ============================================================================
local function parse_controllers(data)
    local ctrls = {}
    if not data or not data.controllers then return ctrls end

    for _, c in ipairs(data.controllers) do
        if c.callsign and c.frequency and c.frequency ~= "199.998" then
            local ctype = UTILS.get_ctrl_type(c.callsign)
            if ctype ~= "ATIS" and ctype ~= "UNK" then
                table.insert(ctrls, {
                    callsign = c.callsign,
                    frequency = c.frequency,
                    latitude = c.latitude or 0,
                    longitude = c.longitude or 0,
                    type = ctype,
                    distance = 0,
                    priority = CONFIG.controller_priority[ctype] or 99
                })
            end
        end
    end
    return ctrls
end

local function update_nearby()
    local my_lat, my_lon = xp_latitude, xp_longitude
    local nearby = {}

    for _, ctrl in ipairs(atc.controllers) do
        local dist = 9999
        if ctrl.latitude ~= 0 and ctrl.longitude ~= 0 then
            dist = UTILS.calc_distance_nm(my_lat, my_lon, ctrl.latitude, ctrl.longitude)
        end
        ctrl.distance = dist

        local max_range = 0
        if ctrl.type == "DEL" or ctrl.type == "GND" or ctrl.type == "TWR" then
            max_range = CONFIG.max_range_gnd_twr
        elseif ctrl.type == "APP" or ctrl.type == "DEP" then
            max_range = CONFIG.max_range_app
        elseif ctrl.type == "CTR" then
            max_range = CONFIG.max_range_ctr
        end

        if dist <= max_range then
            table.insert(nearby, ctrl)
        end
    end

    table.sort(nearby, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.distance < b.distance
    end)

    atc.nearby = nearby
    atc.current = nearby[1]
    atc.next_atc = nearby[2]
end

-- ============================================================================
-- XML FLIGHTPLAN (SimBrief OFP)
-- ============================================================================
local function extract_xml(content, tag)
    if not content or not tag then return nil end
    local pattern = "<" .. tag .. ">( [^<]*)</" .. tag .. ">"
    local val = content:match(pattern)
    if val and val ~= "" then return val end
    return nil
end

local function extract_xml_nested(content, parent, tag)
    if not content or not parent or not tag then return nil end
    -- Find parent section first
    local parent_pattern = "<" .. parent .. ">(. -)</" .. parent .. ">"
    local parent_content = content:match(parent_pattern)
    if parent_content then
        return extract_xml(parent_content, tag)
    end
    return nil
end

local function load_xml()
    local fms_path = ""
    
    -- Try different possible FMS paths for FlyWithLua
    if SYSTEM_DIRECTORY then
        fms_path = SYSTEM_DIRECTORY .. "Output/FMS plans/"
    elseif SCRIPT_DIRECTORY then
        -- Guess from script directory
        fms_path = SCRIPT_DIRECTORY:match("(.*[/\\]X-Plane.*[/\\])") or SCRIPT_DIRECTORY
        fms_path = fms_path .. "Output/FMS plans/"
    else
        fms_path = "./Output/FMS plans/"
    end
    
    log_msg("FMS path: " .. fms_path)

    -- Try XML files first (more data), then FMS
    local files = {"simbrief.xml", "flightplan.xml", "ofp.xml", "simbrief.fms", "flightplan.fms", "default.fms"}

    for _, name in ipairs(files) do
        local f = io.open(fms_path .. name, "r")
        if f then
            local content = f:read("*all")
            f:close()
            log_msg("Found: " .. name)

            if name:match("%.xml$") then
                -- Parse XML (SimBrief OFP format)
                -- Try nested format first (SimBrief), then flat format
                flightplan.origin = extract_xml_nested(content, "origin", "icao_code") or extract_xml(content, "origin_icao") or ""
                flightplan.destination = extract_xml_nested(content, "destination", "icao_code") or extract_xml(content, "destination_icao") or ""
                vatsim_fp.departure = flightplan.origin
                vatsim_fp.arrival = flightplan.destination
                vatsim_fp.sid = extract_xml_nested(content, "general", "sid_ident") or extract_xml(content, "sid_id") or ""
                vatsim_fp.star = extract_xml_nested(content, "general", "star_ident") or extract_xml(content, "star_id") or ""
                vatsim_fp.dep_rwy = extract_xml_nested(content, "origin", "plan_rwy") or extract_xml(content, "origin_rwy") or ""
                vatsim_fp.approach = extract_xml_nested(content, "destination", "plan_rwy") or extract_xml(content, "arr_rwy") or ""

                -- ARR runway from destination
                vatsim_fp.arr_rwy = extract_xml_nested(content, "destination", "plan_rwy") or ""

                -- Gate from origin
                vatsim_fp.gate = extract_xml_nested(content, "origin", "gate") or extract_xml(content, "departure_gate") or ""

                -- METAR from origin and destination
                vatsim_fp.dep_metar = extract_xml_nested(content, "origin", "metar") or ""
                vatsim_fp.arr_metar = extract_xml_nested(content, "destination", "metar") or ""

                -- Scheduled times (ETD/ETA) from times section
                local sched_out = extract_xml_nested(content, "times", "sched_out")
                local sched_in = extract_xml_nested(content, "times", "sched_in")
                if sched_out then vatsim_fp.sched_etd = tonumber(sched_out) or 0 end
                if sched_in then vatsim_fp.sched_eta = tonumber(sched_in) or 0 end

                -- Try to get callsign from XML (icao_airline + flight_number)
                local airline = extract_xml_nested(content, "general", "icao_airline") or ""
                local fltnr = extract_xml_nested(content, "general", "flight_number") or ""
                if airline ~= "" and fltnr ~= "" then
                    flightplan.callsign = airline .. fltnr
                else
                    local xml_callsign = extract_xml(content, "callsign") or extract_xml(content, "atc_callsign")
                    if xml_callsign then
                        flightplan.callsign = xml_callsign
                    end
                end
                
                -- Get aircraft type
                flightplan.aircraft_type = extract_xml_nested(content, "aircraft", "icaocode") or 
                                          extract_xml(content, "aircraft_type") or ""

                log_msg("XML: " .. flightplan.origin .. "->" .. flightplan.destination ..
                    " CS:" .. flightplan.callsign ..
                    " AC:" .. flightplan.aircraft_type ..
                    " Gate:" .. vatsim_fp.gate ..
                    " SID:" .. vatsim_fp.sid .. "/" .. vatsim_fp.dep_rwy ..
                    " STAR:" .. vatsim_fp.star .. "/" .. vatsim_fp.arr_rwy)
            else
                -- Parse FMS format
                flightplan.origin = content:match("ADEP%s+([%w]+)") or ""
                flightplan.destination = content:match("ADES%s+([%w]+)") or ""
            end

            if flightplan.origin ~= "" then
                flightplan.loaded = true
                log_msg("Loaded: " .. flightplan.origin .. " -> " .. flightplan.destination)
                return
            end
        end
    end
    log_msg("No flightplan found")
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function update_progress()
    progress.groundspeed_kts = math.floor((xp_groundspeed or 0) * 1.94384)
    progress.altitude_ft = math.floor((xp_altitude_msl or 0) * 3.28084)
    progress.qnh_hpa = math.floor((xp_baro_sea or 29.92) * 33.8639 + 0.5)

    if xp_gps_dme_dist and xp_gps_dme_dist > 0 then
        progress.dist_to_dest = xp_gps_dme_dist
    end
    if xp_gps_dme_time and xp_gps_dme_time > 0 then
        progress.eta_seconds = xp_gps_dme_time * 60
    end

    local alt_agl = (xp_altitude_agl or 0) * 3.28084
    local on_ground = (xp_on_ground == 1) or (alt_agl < 50)
    local brake_set = (xp_parking_brake or 0) > 0.5

    -- Track ETD: when brakes released at departure (first time after being parked)
    if progress.brake_was_set and not brake_set and on_ground and not progress.etd_time then
        progress.etd_time = os.time()
        log_msg("ETD recorded: " .. os.date("!%H:%MZ", progress.etd_time))
    end

    -- Track ETA: when brakes set at arrival (after flight)
    if not progress.brake_was_set and brake_set and on_ground and progress.etd_time and not progress.eta_actual then
        -- Only set ETA if we actually flew (altitude was > 1000ft at some point)
        if progress.phase == "PARKED" or progress.phase == "TAXI" then
            progress.eta_actual = os.time()
            log_msg("ETA recorded: " .. os.date("!%H:%MZ", progress.eta_actual))
        end
    end

    progress.brake_was_set = brake_set

    if on_ground then
        progress.phase = progress.groundspeed_kts < 5 and "PARKED" or "TAXI"
    elseif progress.dist_to_dest < 30 and alt_agl < 5000 then
        progress.phase = "APPR"
    elseif progress.altitude_ft > 20000 then
        progress.phase = "CRZ"
    else
        progress.phase = "CLIMB"
    end
end

local last_log_time = 0
local function update()
    local now = os.time()
    local do_log = (now - last_log_time) >= 30  -- Log every 30 seconds

    -- Default: OFFLINE (red) - use X-Plane local data
    state.vatsim_status = "offline"
    state.connected = false

    -- Always use X-Plane actual values
    state.squawk = UTILS.num_to_squawk(xp_transponder or 2000)

    -- Use XML/FMS flightplan if loaded
    if flightplan.loaded then
        if flightplan.callsign ~= "" then
            state.callsign = flightplan.callsign
        else
            state.callsign = flightplan.origin .. "-" .. flightplan.destination
        end
        atc.fir = "LOCAL"
    else
        state.callsign = "---"
        atc.fir = "OFFLINE"
    end

    -- Try to get VATSIM data
    local content = read_vatsim()
    local data = parse_vatsim(content)

    if not data then
        if do_log then
            log_msg("UPDATE: No VATSIM data available")
            last_log_time = now
        end
        return
    end

    atc.controllers = parse_controllers(data)
    update_nearby()

    local pilot = nil
    local has_prefile = false

    -- Auto-detect pilot by position, or use configured callsign
    if CONFIG.callsign == "AUTO" then
        pilot = find_pilot_by_position(data)
        if pilot then
            active_callsign = pilot.callsign
        end
    else
        active_callsign = CONFIG.callsign
        pilot = find_pilot(data, active_callsign)
        has_prefile = find_prefile(data, active_callsign)
    end

    if pilot then
        -- ONLINE (green)
        state.vatsim_status = "online"
        state.connected = true
        state.callsign = pilot.callsign
        state.squawk = pilot.transponder or UTILS.num_to_squawk(xp_transponder or 2000)

        if pilot.flight_plan then
            vatsim_fp.departure = pilot.flight_plan.departure or ""
            vatsim_fp.arrival = pilot.flight_plan.arrival or ""
        end

        atc.fir = atc.current and atc.current.callsign or "VATSIM"

        if do_log then
            log_msg("ONLINE: " .. pilot.callsign .. " | " .. vatsim_fp.departure .. "->" .. vatsim_fp.arrival)
            last_log_time = now
        end

    elseif has_prefile then
        -- PREFILED (orange)
        state.vatsim_status = "prefiled"
        state.connected = false
        state.callsign = active_callsign
        atc.fir = "PREFILED"
        if do_log then
            log_msg("PREFILED: " .. active_callsign)
            last_log_time = now
        end
    else
        -- OFFLINE (red)
        if do_log then
            log_msg("OFFLINE")
            last_log_time = now
        end
    end
end

-- ============================================================================
-- DRAW CACHE UPDATE (must be before do_poll)
-- ============================================================================
local function update_draw_cache()
    pcall(update_progress)

    local dc = draw_cache
    dc.origin = vatsim_fp.departure ~= "" and vatsim_fp.departure or flightplan.origin
    dc.dest = vatsim_fp.arrival ~= "" and vatsim_fp.arrival or flightplan.destination
    dc.cs = state.callsign ~= "" and state.callsign or "---"
    dc.sqwk = UTILS.num_to_squawk(xp_transponder or 2000)

    local raw_freq = xp_com1_freq or 0
    dc.freq = raw_freq > 0 and UTILS.xplane_to_freq(raw_freq) or "122.800"
    dc.atc_type = atc.current and atc.current.type or "UNICOM"
    dc.fir = atc.fir or "---"
    dc.fir_freq = atc.current and UTILS.format_freq(atc.current.frequency) or ""
    dc.next_fir = atc.next_atc and atc.next_atc.callsign or "---"
    dc.dist = progress.dist_to_dest > 0 and string.format("%dNM", math.floor(progress.dist_to_dest)) or "---"

    -- ETD
    if vatsim_fp.sched_etd > 0 then
        dc.etd = os.date("!%H:%MZ", vatsim_fp.sched_etd)
    elseif progress.etd_time then
        dc.etd = os.date("!%H:%MZ", progress.etd_time)
    else
        dc.etd = "---"
    end

    -- ETA
    if vatsim_fp.sched_eta > 0 then
        dc.eta = os.date("!%H:%MZ", vatsim_fp.sched_eta)
    elseif progress.eta_actual then
        dc.eta = os.date("!%H:%MZ", progress.eta_actual)
    elseif progress.eta_seconds > 0 then
        dc.eta = os.date("!%H:%MZ", os.time() + progress.eta_seconds)
    else
        dc.eta = "---"
    end

    -- DEP weather
    local dep_wx = UTILS.parse_metar(vatsim_fp.dep_metar)
    dc.dep_qnh = tostring(dep_wx.qnh or progress.qnh_hpa)
    dc.dep_metar_qnh = dep_wx.qnh and tostring(dep_wx.qnh) or "----"

    -- Transponder mode
    local xpdr_mode = xp_xpdr_mode or 1
    if xpdr_mode == 0 then dc.ta = "OFF"
    elseif xpdr_mode == 2 then dc.ta = "ON"
    elseif xpdr_mode >= 3 then dc.ta = "TA"
    else dc.ta = "STBY" end

    -- ARR weather
    local arr_wx = UTILS.parse_metar(vatsim_fp.arr_metar)
    dc.arr_qnh = tostring(arr_wx.qnh or progress.qnh_hpa)
    dc.arr_metar_qnh = arr_wx.qnh and tostring(arr_wx.qnh) or "----"

    if arr_wx.temp then
        dc.arr_temp = string.format("%d°C", arr_wx.temp)
    elseif xp_temp_c then
        dc.arr_temp = string.format("%d°C", math.floor(xp_temp_c))
    else
        dc.arr_temp = "---"
    end

    if arr_wx.wind_dir and arr_wx.wind_spd then
        dc.arr_wind = string.format("%03d/%d", arr_wx.wind_dir, arr_wx.wind_spd)
    elseif xp_wind_dir and xp_wind_speed then
        dc.arr_wind = string.format("%03d/%d", math.floor(xp_wind_dir), math.floor(xp_wind_speed))
    else
        dc.arr_wind = "---"
    end

    -- Flight plan data
    dc.gate = vatsim_fp.gate ~= "" and vatsim_fp.gate or "---"
    dc.sid = vatsim_fp.sid ~= "" and vatsim_fp.sid or "---"
    dc.dep_rwy = vatsim_fp.dep_rwy ~= "" and vatsim_fp.dep_rwy or "---"
    dc.star = vatsim_fp.star ~= "" and vatsim_fp.star or "---"
    dc.approach = vatsim_fp.approach ~= "" and vatsim_fp.approach or "---"

    -- Colors
    dc.connected = state.connected
    dc.vatsim_status = state.vatsim_status
    dc.phase = progress.phase
end

-- ============================================================================
-- POLL
-- ============================================================================
local function do_poll()
    local now = os.time()

    if now - last_poll >= CONFIG.poll_interval then
        fetch_vatsim()
        last_poll = now
    end

    if now - last_fms_check >= 30 then
        load_xml()
        last_fms_check = now
    end

    update()
    update_draw_cache()

    -- ALARM SYSTEM: Check for data changes
    if ALARMS then
        local alarm_data = {
            atc_callsign = draw_cache.atc_type,
            atc_freq = draw_cache.freq,
            squawk = draw_cache.sqwk,
            fir = draw_cache.fir,
            dep_qnh = draw_cache.dep_qnh,
            arr_qnh = draw_cache.arr_qnh
        }
        ALARMS.check_data_changes(alarm_data)
    end
end

function vatc_sync_poll()
    local ok, err = pcall(do_poll)
    if not ok then log_msg("Poll error: " .. tostring(err)) end
end

-- ============================================================================
-- IMGUI WINDOWS (PURE IMGUI - NO float_wnd)
-- ============================================================================
local BAR_HEIGHT = 50
local bar_visible = true
local settings_visible = false

-- Settings state (for imgui input)
local settings_state = {
    simbrief_id = "",
    auto_tune_com1 = false,
    auto_set_squawk = false,
    auto_fetch_simbrief = true,
    show_header_row = true
}

-- Load settings from file
local function load_settings()
    local path = SCRIPT_DIRECTORY .. (CONFIG.settings_file or "vATC_sync_settings.ini")
    local f = io.open(path, "r")
    if not f then return end
    for line in f:lines() do
        local key, val = line:match("([^=]+)=(.+)")
        if key and val then
            key = key:match("^%s*(.-)%s*$")  -- trim
            val = val:match("^%s*(.-)%s*$")
            if key == "simbrief_pilot_id" then
                CONFIG.simbrief_pilot_id = val
                settings_state.simbrief_id = val
            elseif key == "auto_tune_com1" then
                CONFIG.auto_tune_com1 = (val == "true")
                settings_state.auto_tune_com1 = CONFIG.auto_tune_com1
            elseif key == "auto_set_squawk" then
                CONFIG.auto_set_squawk = (val == "true")
                settings_state.auto_set_squawk = CONFIG.auto_set_squawk
            elseif key == "auto_fetch_simbrief" then
                CONFIG.auto_fetch_simbrief = (val == "true")
                settings_state.auto_fetch_simbrief = CONFIG.auto_fetch_simbrief
            elseif key == "show_header_row" then
                CONFIG.show_header_row = (val == "true")
                settings_state.show_header_row = CONFIG.show_header_row
            elseif key == "callsign" then
                CONFIG.callsign = val
            end
        end
    end
    f:close()
    log_msg("Settings loaded")
end

-- Save settings to file
local function save_settings()
    local path = SCRIPT_DIRECTORY .. (CONFIG.settings_file or "vATC_sync_settings.ini")
    local f = io.open(path, "w")
    if not f then
        log_msg("ERROR: Cannot save settings")
        return
    end
    f:write("simbrief_pilot_id=" .. (CONFIG.simbrief_pilot_id or "") .. "\n")
    f:write("auto_tune_com1=" .. tostring(CONFIG.auto_tune_com1) .. "\n")
    f:write("auto_set_squawk=" .. tostring(CONFIG.auto_set_squawk) .. "\n")
    f:write("auto_fetch_simbrief=" .. tostring(CONFIG.auto_fetch_simbrief) .. "\n")
    f:write("show_header_row=" .. tostring(CONFIG.show_header_row) .. "\n")
    f:write("callsign=" .. (CONFIG.callsign or "AUTO") .. "\n")
    f:close()
    log_msg("Settings saved")
end

-- Helper to convert RGB 0-1 to imgui color (ABGR hex)
local function rgb_to_imgui(r, g, b, a)
    a = a or 1
    return math.floor(a * 255) * 0x1000000 +
           math.floor(b * 255) * 0x10000 +
           math.floor(g * 255) * 0x100 +
           math.floor(r * 255)
end

-- Colors
local COL_BG = rgb_to_imgui(0.12, 0.12, 0.12, 0.95)
local COL_HEADER = rgb_to_imgui(0.5, 0.5, 0.5, 1)
local COL_WHITE = rgb_to_imgui(1, 1, 1, 1)
local COL_GRAY = rgb_to_imgui(0.5, 0.5, 0.5, 1)
local COL_CYAN = rgb_to_imgui(0, 0.9, 1, 1)
local COL_RED = rgb_to_imgui(1, 0, 0, 1)
local COL_GREEN = rgb_to_imgui(0, 1, 0, 1)
local COL_ORANGE = rgb_to_imgui(1, 0.6, 0, 1)
local COL_SEP = rgb_to_imgui(0.4, 0.4, 0.4, 1)

-- ============================================================================
-- FLIGHT BAR (borderless overlay)
-- ============================================================================
-- Draw vATC bar using pure ImGui (no float_wnd)
function vatc_draw_bar()
    if display.manually_hidden or not bar_visible then return end

    -- Safety: check if imgui.constant exists FIRST
    if not imgui or not imgui.constant then
        return
    end

    local sw = SCREEN_WIDTH or 1920
    local sh = SCREEN_HEIGHT or 1080
    local h = CONFIG.show_header_row and BAR_HEIGHT or 30

    -- Position at top of screen (safe now, after check)
    imgui.SetNextWindowPos(0, sh - h)
    imgui.SetNextWindowSize(sw, h)

    local window_flags = imgui.constant.WindowFlags.NoTitleBar +
                        imgui.constant.WindowFlags.NoResize +
                        imgui.constant.WindowFlags.NoMove +
                        imgui.constant.WindowFlags.NoCollapse +
                        imgui.constant.WindowFlags.NoScrollbar +
                        imgui.constant.WindowFlags.NoScrollWithMouse +
                        imgui.constant.WindowFlags.NoBringToFrontOnFocus +
                        imgui.constant.WindowFlags.NoFocusOnAppearing

    -- Push borderless style
    imgui.PushStyleVar(imgui.constant.StyleVar.WindowBorderSize, 0)
    imgui.PushStyleVar(imgui.constant.StyleVar.WindowRounding, 0)
    imgui.PushStyleVar(imgui.constant.StyleVar.WindowPadding, 5, 5)

    if not imgui.Begin("vATC Sync Bar", true, window_flags) then
        imgui.PopStyleVar(3)
        imgui.End()
        return
    end

    -- DYNAMIC FONT SCALING
    local screen_width = SCREEN_WIDTH or 1920
    local base_width = 1920
    local font_scale = math.max(0.8, math.min(1.5, screen_width / base_width))
    imgui.SetWindowFontScale(font_scale)

    local dc = draw_cache

    -- Determine colors based on phase and online status
    local segment = dc.phase == "CRZ" and "CRZ" or (dc.phase == "APPR" and "ARR" or "DEP")
    local online_col = dc.connected and COL_CYAN or COL_WHITE

    local dep_col = segment == "DEP" and online_col or COL_GRAY
    local crz_col = segment == "CRZ" and online_col or COL_GRAY
    local arr_col = segment == "ARR" and online_col or COL_GRAY

    -- Status indicator color
    local status_col = COL_RED
    if dc.vatsim_status == "online" then status_col = COL_GREEN
    elseif dc.vatsim_status == "prefiled" then status_col = COL_ORANGE end

    -- Build FIR string
    local fir_str = dc.fir or "---"
    if dc.fir_freq and dc.fir_freq ~= "" then fir_str = fir_str .. ":" .. dc.fir_freq end

    -- Header row (optional) - ENHANCED with METAR QNH and Step Climb
    if CONFIG.show_header_row then
        imgui.PushStyleColor(imgui.constant.Col.Text, COL_HEADER)
        imgui.TextUnformatted("DEP      Callsign   ATC    Freq       Gate  SID      RWY   SQWK  QNH   METAR-QNH  TA  ETD     Dist  |  FIR:Freq      sFL   NextATC   ToGo  |  ARR  ETA     QNH   METAR Temp  Wind")
        imgui.PopStyleColor()
    end

    -- Data row - DEP section (ENHANCED with METAR QNH)
    imgui.PushStyleColor(imgui.constant.Col.Text, dep_col)
    imgui.TextUnformatted(string.format("%-8s %-10s %-6s %-10s %-5s %-8s %-5s %-5s %-5s %-5s %-5s %-7s %-5s",
        dc.origin or "---",
        dc.cs or "---",
        dc.atc_type or "UNICOM",
        dc.freq or "122.800",
        dc.gate or "---",
        dc.sid or "---",
        dc.dep_rwy or "---",
        dc.sqwk or "2000",
        dc.dep_qnh or "1013",
        dc.dep_metar_qnh or "1013",  -- NEW: METAR QNH
        dc.ta or "STBY",
        dc.etd or "---",
        dc.dist or "---"))
    imgui.PopStyleColor()

    -- CRZ + ARR section on same line
    imgui.SameLine()
    imgui.PushStyleColor(imgui.constant.Col.Text, COL_SEP)
    imgui.TextUnformatted("|")
    imgui.PopStyleColor()
    imgui.SameLine()

    imgui.PushStyleColor(imgui.constant.Col.Text, crz_col)
    imgui.TextUnformatted(string.format("%-12s %-5s %-9s %-5s",
        fir_str,
        dc.step_climb_fl or "---",  -- NEW: Step climb FL
        dc.next_fir or "---",
        dc.dist or "---"))
    imgui.PopStyleColor()

    imgui.SameLine()
    imgui.PushStyleColor(imgui.constant.Col.Text, COL_SEP)
    imgui.TextUnformatted("|")
    imgui.PopStyleColor()
    imgui.SameLine()

    imgui.PushStyleColor(imgui.constant.Col.Text, arr_col)
    imgui.TextUnformatted(string.format("%-4s %-7s %-5s %-5s %-5s %-9s %-8s %-5s %-4s",
        "---",
        dc.eta or "---",
        dc.arr_qnh or "1013",
        dc.arr_metar_qnh or "1013",  -- NEW: Arrival METAR QNH
        dc.arr_temp or "---",
        dc.arr_wind or "---",
        dc.star or "---",
        dc.approach or "---",
        dc.dest or "---"))
    imgui.PopStyleColor()

    -- Status indicator
    imgui.SameLine()
    imgui.PushStyleColor(imgui.constant.Col.Text, status_col)
    imgui.TextUnformatted(" [*]")
    imgui.PopStyleColor()

    -- Pop style vars and end window
    imgui.PopStyleVar(3)
    imgui.End()
end

-- Simple enable/disable functions (no window objects needed)
function vatc_create_bar()
    bar_visible = true
end

function vatc_destroy_bar()
    bar_visible = false
end

function vatc_sync_show_wnd()
    bar_visible = true
end

function vatc_sync_hide_wnd()
    bar_visible = false
end

function vatc_sync_toggle_wnd()
    bar_visible = not bar_visible
end

-- ============================================================================
-- SETTINGS WINDOW (pure ImGui)
-- ============================================================================
function vatc_draw_settings()
    if not settings_visible then return end

    -- Safety: check if imgui exists FIRST
    if not imgui or not imgui.constant then
        return
    end

    imgui.SetNextWindowSize(350, 320)
    imgui.SetNextWindowPos((SCREEN_WIDTH or 1920) / 2 - 175, (SCREEN_HEIGHT or 1080) / 2 - 160)

    if not imgui.Begin("vATC Sync Settings", true) then
        imgui.End()
        return
    end

    imgui.SetWindowFontScale(1.2)

    imgui.TextUnformatted("vATC Sync Settings")
    imgui.Separator()
    imgui.Dummy(0, 5)

    -- SimBrief Pilot ID
    imgui.TextUnformatted("SimBrief Pilot ID:")
    local changed, new_val = imgui.InputText("##simbrief_id", settings_state.simbrief_id, 32)
    if changed then
        settings_state.simbrief_id = new_val
        CONFIG.simbrief_pilot_id = new_val
    end
    imgui.Dummy(0, 10)

    -- Checkboxes
    imgui.TextUnformatted("Options:")
    imgui.Separator()

    local chg1, val1 = imgui.Checkbox("Show header row", settings_state.show_header_row)
    if chg1 then
        settings_state.show_header_row = val1
        CONFIG.show_header_row = val1
    end

    local chg2, val2 = imgui.Checkbox("Auto-tune COM1", settings_state.auto_tune_com1)
    if chg2 then
        settings_state.auto_tune_com1 = val2
        CONFIG.auto_tune_com1 = val2
    end

    local chg3, val3 = imgui.Checkbox("Auto-set squawk", settings_state.auto_set_squawk)
    if chg3 then
        settings_state.auto_set_squawk = val3
        CONFIG.auto_set_squawk = val3
    end

    local chg4, val4 = imgui.Checkbox("Auto-fetch SimBrief", settings_state.auto_fetch_simbrief)
    if chg4 then
        settings_state.auto_fetch_simbrief = val4
        CONFIG.auto_fetch_simbrief = val4
    end

    imgui.Dummy(0, 15)
    imgui.Separator()

    -- Save button
    if imgui.Button("Save Settings") then
        save_settings()
    end

    imgui.SameLine()
    if imgui.Button("Close") then
        settings_visible = false
    end

    imgui.Dummy(0, 10)
    imgui.TextUnformatted("v" .. VERSION:get())

    imgui.End()
end

function vatc_create_settings()
    settings_visible = true
end

function vatc_destroy_settings()
    settings_visible = false
end

function vatc_toggle_settings()
    settings_visible = not settings_visible
end

-- ============================================================================
-- Temp file: lines 1095-1125 FIXED VERSION

-- ============================================================================
-- IMGUI DRAWING CALLBACK - ImGui only, with throttle (FlyWithLua NG+ compliant)
-- ============================================================================
local last_draw_time = 0

function vatc_draw_windows()
    -- Throttle to max 20 FPS (REQUIRED by FlyWithLua)
    local now = os.clock()
    if now - last_draw_time < 0.05 then return end
    last_draw_time = now

    -- Simple draw - NO pcall, NO heavy code
    vatc_draw_bar()
    if settings_visible then
        vatc_draw_settings()
    end
end

-- Register ImGui callback (FlyWithLua uses do_every_draw for ImGui rendering)
do_every_draw("vatc_draw_windows()")

-- ============================================================================
-- INIT
-- ============================================================================
init_log_file()
log_msg("========================================")
log_msg("Initializing vATC Sync...")
log_msg("Script dir: " .. tostring(SCRIPT_DIRECTORY))
log_msg("Log file: " .. tostring(log_file_path))

-- Load settings from file
load_settings()

load_xml()
last_poll = os.time()
last_fms_check = os.time()
fetch_vatsim()
update_draw_cache()

-- FlyWithLua callbacks
do_often("vatc_sync_poll()")

-- Create commands and macros
create_command("FlyWithLua/vATC_Sync/toggle_bar", "Toggle vATC Sync bar", "vatc_sync_toggle_wnd()", "", "")
create_command("FlyWithLua/vATC_Sync/settings", "Open vATC Sync settings", "vatc_toggle_settings()", "", "")

add_macro("vATC Sync", "vatc_sync_show_wnd()", "vatc_sync_hide_wnd()", "activate")
add_macro("vATC Settings", "vatc_create_settings()", "vatc_destroy_settings()", "deactivate")

log_msg("vATC Sync " .. VERSION:get_full() .. " ready")
logMsg("vATC Sync " .. VERSION:get_full() .. " loaded")
