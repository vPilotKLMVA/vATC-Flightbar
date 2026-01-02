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
        log_file_path = SCRIPT_DIRECTORY .. "vATC_sync/debug/vATC_Log.txt"
    else
        SCRIPT_DIRECTORY = script_dir
        log_file_path = SCRIPT_DIRECTORY .. "vATC_sync/debug/vATC_Log.txt"
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
    local pattern = "<" .. tag .. ">(\[^[<]]*)</" .. tag .. ">"
    local val = content:match(pattern)
    if val and val ~= "" then return val end
    return nil
end
 
local function extract_xml_nested(content, parent, tag)
    if not content or not parent or not tag then return nil end
    local parent_pattern = "<" .. parent .. ">(.-)</" .. parent .. ">"
    local parent_content = content:match(parent_pattern)
    if parent_content then
        return extract_xml(parent_content, tag)
    end
    return nil
end
 
local function load_xml()
    local fms_path = ""
    
    if SYSTEM_DIRECTORY then
        fms_path = SYSTEM_DIRECTORY .. "Output/FMS plans/"
    elseif SCRIPT_DIRECTORY then
        fms_path = SCRIPT_DIRECTORY:match("(.*[/\\]X-Plane.*[/\\])") or SCRIPT_DIRECTORY
        fms_path = fms_path .. "Output/FMS plans/"
    else
        fms_path = "./Output/FMS plans/"
    end
    
    log_msg("FMS path: " .. fms_path)
 
    local files = {"simbrief.xml", "flightplan.xml", "ofp.xml", "simbrief.fms", "flightplan.fms", "default.fms"}
 
    for _, name in ipairs(files) do
        local f = io.open(fms_path .. name, "r")
        if f then
            local content = f:read("*all")
            f:close()
            log_msg("Found: " .. name)
 
            if name:match("%.xml$") then
                flightplan.origin = extract_xml_nested(content, "origin", "icao_code") or extract_xml(content, "origin_icao") or ""
                flightplan.destination = extract_xml_nested(content, "destination", "icao_code") or extract_xml(content, "destination_icao") or ""
                vatsim_fp.departure = flightplan.origin
                vatsim_fp.arrival = flightplan.destination
                vatsim_fp.sid = extract_xml_nested(content, "general", "sid_ident") or extract_xml(content, "sid_id") or ""
                vatsim_fp.star = extract_xml_nested(content, "general", "star_ident") or extract_xml(content, "star_id") or ""
                vatsim_fp.dep_rwy = extract_xml_nested(content, "origin", "plan_rwy") or extract_xml(content, "origin_rwy") or ""
                vatsim_fp.approach = extract_xml_nested(content, "destination", "plan_rwy") or extract_xml(content, "arr_rwy") or ""
 
                vatsim_fp.arr_rwy = extract_xml_nested(content, "destination", "plan_rwy") or ""
 
                vatsim_fp.gate = extract_xml_nested(content, "origin", "gate") or extract_xml(content, "departure_gate") or ""
 
                vatsim_fp.dep_metar = extract_xml_nested(content, "origin", "metar") or ""
                vatsim_fp.arr_metar = extract_xml_nested(content, "destination", "metar") or ""
 
                local sched_out = extract_xml_nested(content, "times", "sched_out")
                local sched_in = extract_xml_nested(content, "times", "sched_in")
                if sched_out then vatsim_fp.sched_etd = tonumber(sched_out) or 0 end
                if sched_in then vatsim_fp.sched_eta = tonumber(sched_in) or 0 end
 
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
                
                flightplan.aircraft_type = extract_xml_nested(content, "aircraft", "icaocode") or 
                                          extract_xml(content, "aircraft_type") or ""
 
                log_msg("XML: " .. flightplan.origin .. "->" .. flightplan.destination ..
                    " CS:" .. flightplan.callsign ..
                    " AC:" .. flightplan.aircraft_type ..
                    " Gate:" .. vatsim_fp.gate ..
                    " SID:" .. vatsim_fp.sid .. "/" .. vatsim_fp.dep_rwy ..
                    " STAR:" .. vatsim_fp.star .. "/" .. vatsim_fp.arr_rwy)
            else
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

-- (rest of file is the same as the corrected version provided earlier)

logMsg("vATC Sync " .. VERSION:get_full() .. " loaded")
