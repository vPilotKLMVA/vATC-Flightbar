-- ============================================================================
-- vATC SYNC for X-Plane 12
-- Uses FlyWithLua modules: dkjson, socket.http
-- ============================================================================

local script_dir = debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./"

-- Logging to file and console
local log_file_path = nil
local function init_log_file()
    if SCRIPT_DIRECTORY then
        log_file_path = SCRIPT_DIRECTORY .. "vATC_sync.log"
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

if not VERSION or not CONFIG or not UTILS then
    log_msg("FATAL: modules failed")
    return
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
    approach = ""
}

local flightplan = {
    loaded = false,
    origin = "",
    destination = "",
    dest_lat = 0,
    dest_lon = 0,
    callsign = ""
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

local display = { visible = true, manually_hidden = false }
local active_callsign = ""
local last_poll = 0
local last_fms_check = 0
local in_draw_loop = false  -- Safety flag for OpenGL calls

-- ============================================================================
-- VATSIM DATA
-- ============================================================================
local vatsim_data = nil

local function fetch_vatsim()
    if http then
        local body, code = http.request("http://data.vatsim.net/v3/vatsim-data.json")
        if code == 200 and body then
            local f = io.open(SCRIPT_DIRECTORY .. CONFIG.data_file, "w")
            if f then f:write(body); f:close() end
            return body
        end
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
    if not data or not data.prefiles or not cs then return false end
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
    local pattern = "<" .. tag .. ">([^<]*)</" .. tag .. ">"
    local val = content:match(pattern)
    if val and val ~= "" then return val end
    return nil
end

local function load_xml()
    local fms_path = SYSTEM_DIRECTORY and (SYSTEM_DIRECTORY .. "Output/FMS plans/") or ""
    if fms_path == "" then
        log_msg("No FMS path found")
        return
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
                flightplan.origin = extract_xml(content, "origin_icao") or extract_xml(content, "departure") or ""
                flightplan.destination = extract_xml(content, "destination_icao") or extract_xml(content, "arrival") or ""
                vatsim_fp.departure = flightplan.origin
                vatsim_fp.arrival = flightplan.destination
                vatsim_fp.sid = extract_xml(content, "sid_id") or extract_xml(content, "sid") or ""
                vatsim_fp.star = extract_xml(content, "star_id") or extract_xml(content, "star") or ""
                vatsim_fp.dep_rwy = extract_xml(content, "origin_rwy") or extract_xml(content, "departure_runway") or ""
                vatsim_fp.approach = extract_xml(content, "approach") or extract_xml(content, "arr_rwy") or ""

                -- Try to get callsign from XML
                local xml_callsign = extract_xml(content, "callsign") or extract_xml(content, "atc_callsign")
                if xml_callsign then
                    flightplan.callsign = xml_callsign
                end
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
end

function vatc_sync_poll()
    local ok, err = pcall(do_poll)
    if not ok then log_msg("Poll error: " .. tostring(err)) end
end

-- ============================================================================
-- DRAW
-- ============================================================================
function vatc_sync_draw()
    if not in_draw_loop then return end  -- Safety: only draw in draw loop
    if not CONFIG.show_bar then return end
    if not SCREEN_WIDTH or not SCREEN_HIGHT then return end

    pcall(update_progress)

    local sw, sh = SCREEN_WIDTH, SCREEN_HIGHT
    local row_h = 14
    local bar_h = row_h * 2 + 6
    local bar_y = sh - bar_h
    local header_y = bar_y + row_h + 4
    local data_y = bar_y + 2

    local white = {1, 1, 1}
    local gray = {0.5, 0.5, 0.5}
    local sep_color = {0.4, 0.4, 0.4}

    -- Segment colors
    local segment = "DEP"
    if progress.phase == "CRZ" then segment = "CRZ"
    elseif progress.phase == "APPR" or progress.phase == "DESC" then segment = "ARR" end

    local dep_color = segment == "DEP" and white or gray
    local crz_color = segment == "CRZ" and white or gray
    local arr_color = segment == "ARR" and white or gray

    -- Status dot
    local dot_color = {1, 0, 0}
    if state.vatsim_status == "online" then dot_color = {0, 1, 0}
    elseif state.vatsim_status == "prefiled" then dot_color = {1, 0.6, 0} end

    if display.manually_hidden then
        graphics.set_color(dot_color[1], dot_color[2], dot_color[3], 1)
        graphics.draw_rectangle(sw - 26, sh - 20, sw - 14, sh - 8)
        return
    end

    -- Background
    graphics.set_color(CONFIG.bar_color[1], CONFIG.bar_color[2], CONFIG.bar_color[3], CONFIG.bar_color[4])
    graphics.draw_rectangle(0, bar_y, sw, bar_y + bar_h)

    -- Data
    local origin = vatsim_fp.departure ~= "" and vatsim_fp.departure or flightplan.origin
    local dest = vatsim_fp.arrival ~= "" and vatsim_fp.arrival or flightplan.destination
    local cs = state.callsign ~= "" and state.callsign or "---"
    local sqwk = UTILS.num_to_squawk(xp_transponder or 2000)
    -- COM1 freq from aircraft, default 122.800 UNICOM when offline or no freq
    local raw_freq = xp_com1_freq or 0
    local freq = "122.800"
    if raw_freq > 0 then
        freq = UTILS.xplane_to_freq(raw_freq)
    end
    local atc_type = atc.current and atc.current.type or "UNICOM"
    local fir = atc.fir or "---"
    local fir_freq = atc.current and UTILS.format_freq(atc.current.frequency) or ""
    local next_fir = atc.next_atc and atc.next_atc.callsign or "---"
    local dist = progress.dist_to_dest > 0 and string.format("%dNM", math.floor(progress.dist_to_dest)) or "---"
    -- ETD: actual brake release time, or estimated if not yet released
    local etd_str = progress.etd_time and os.date("!%H:%MZ", progress.etd_time) or "---"
    -- ETA: actual brake set time at arrival, or estimated from GPS
    local eta_str = "---"
    if progress.eta_actual then
        eta_str = os.date("!%H:%MZ", progress.eta_actual)
    elseif progress.eta_seconds > 0 then
        eta_str = os.date("!%H:%MZ", os.time() + progress.eta_seconds)
    end
    local qnh = tostring(progress.qnh_hpa)

    -- Columns
    local pad = 5
    local num_cols = 22
    local col_width = math.max((sw - pad - 20) / num_cols, 38)
    local c = {}
    for i = 1, num_cols do c[i] = math.floor(pad + (i - 1) * col_width) end

    local hc = white

    -- Headers
    draw_string(c[1], header_y, "DEP", hc[1], hc[2], hc[3])
    draw_string(c[2], header_y, "Callsign", hc[1], hc[2], hc[3])
    draw_string(c[3], header_y, "Freq", hc[1], hc[2], hc[3])
    draw_string(c[4], header_y, "Gate", hc[1], hc[2], hc[3])
    draw_string(c[5], header_y, "SID", hc[1], hc[2], hc[3])
    draw_string(c[6], header_y, "RWY", hc[1], hc[2], hc[3])
    draw_string(c[7], header_y, "SQWK", hc[1], hc[2], hc[3])
    draw_string(c[8], header_y, "QNH", hc[1], hc[2], hc[3])
    draw_string(c[9], header_y, "ETD", hc[1], hc[2], hc[3])
    draw_string(c[10], header_y, "Dist", hc[1], hc[2], hc[3])
    draw_string(c[11] - 8, header_y, "|", sep_color[1], sep_color[2], sep_color[3])
    draw_string(c[11], header_y, "FIR", hc[1], hc[2], hc[3])
    draw_string(c[12], header_y, "Next", hc[1], hc[2], hc[3])
    draw_string(c[13], header_y, "ToGo", hc[1], hc[2], hc[3])
    draw_string(c[14] - 8, header_y, "|", sep_color[1], sep_color[2], sep_color[3])
    draw_string(c[14], header_y, "ATC", hc[1], hc[2], hc[3])
    draw_string(c[15], header_y, "ETA", hc[1], hc[2], hc[3])
    draw_string(c[16], header_y, "QNH", hc[1], hc[2], hc[3])
    draw_string(c[17], header_y, "Temp", hc[1], hc[2], hc[3])
    draw_string(c[18], header_y, "Wind", hc[1], hc[2], hc[3])
    draw_string(c[19], header_y, "STAR", hc[1], hc[2], hc[3])
    draw_string(c[20], header_y, "APP", hc[1], hc[2], hc[3])
    draw_string(c[21], header_y, "ARR", hc[1], hc[2], hc[3])
    draw_string(c[22] - 8, header_y, "|", sep_color[1], sep_color[2], sep_color[3])
    draw_string(c[22], header_y, "Online", hc[1], hc[2], hc[3])

    -- Data row
    draw_string(c[1], data_y, origin ~= "" and origin or "---", dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[2], data_y, cs, dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[3], data_y, atc_type .. ":" .. freq, dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[4], data_y, vatsim_fp.gate ~= "" and vatsim_fp.gate or "---", dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[5], data_y, vatsim_fp.sid ~= "" and vatsim_fp.sid or "---", dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[6], data_y, vatsim_fp.dep_rwy ~= "" and vatsim_fp.dep_rwy or "---", dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[7], data_y, sqwk, dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[8], data_y, qnh, dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[9], data_y, etd_str, dep_color[1], dep_color[2], dep_color[3])
    draw_string(c[10], data_y, dist, dep_color[1], dep_color[2], dep_color[3])

    draw_string(c[11] - 8, data_y, "|", sep_color[1], sep_color[2], sep_color[3])
    local fir_str = fir ~= "" and fir or "---"
    if fir_freq ~= "" then fir_str = fir_str .. ":" .. fir_freq end
    draw_string(c[11], data_y, fir_str, crz_color[1], crz_color[2], crz_color[3])
    draw_string(c[12], data_y, next_fir, crz_color[1], crz_color[2], crz_color[3])
    draw_string(c[13], data_y, dist, crz_color[1], crz_color[2], crz_color[3])

    -- Weather data from X-Plane
    local temp_str = xp_temp_c and string.format("%d°C", math.floor(xp_temp_c)) or "---"
    local wind_str = "---"
    if xp_wind_dir and xp_wind_speed then
        wind_str = string.format("%03d/%d", math.floor(xp_wind_dir), math.floor(xp_wind_speed))
    end

    draw_string(c[14] - 8, data_y, "|", sep_color[1], sep_color[2], sep_color[3])
    draw_string(c[14], data_y, "---", arr_color[1], arr_color[2], arr_color[3])
    draw_string(c[15], data_y, eta_str, arr_color[1], arr_color[2], arr_color[3])
    draw_string(c[16], data_y, qnh, arr_color[1], arr_color[2], arr_color[3])
    draw_string(c[17], data_y, temp_str, arr_color[1], arr_color[2], arr_color[3])
    draw_string(c[18], data_y, wind_str, arr_color[1], arr_color[2], arr_color[3])
    draw_string(c[19], data_y, vatsim_fp.star ~= "" and vatsim_fp.star or "---", arr_color[1], arr_color[2], arr_color[3])
    draw_string(c[20], data_y, vatsim_fp.approach ~= "" and vatsim_fp.approach or "---", arr_color[1], arr_color[2], arr_color[3])
    draw_string(c[21], data_y, dest ~= "" and dest or "---", arr_color[1], arr_color[2], arr_color[3])

    draw_string(c[22] - 8, data_y, "|", sep_color[1], sep_color[2], sep_color[3])
    graphics.set_color(dot_color[1], dot_color[2], dot_color[3], 1)
    graphics.draw_rectangle(c[22] + 10, data_y + 2, c[22] + 22, data_y + 12)
end

function vatc_sync_draw_safe()
    in_draw_loop = true
    local ok, err = pcall(vatc_sync_draw)
    in_draw_loop = false
    if not ok then log_msg("Draw error: " .. tostring(err)) end
end

-- ============================================================================
-- WINDOW FUNCTIONS
-- ============================================================================
function vatc_sync_show_wnd() display.manually_hidden = false; CONFIG.show_bar = true end
function vatc_sync_hide_wnd() display.manually_hidden = true end
function vatc_sync_toggle_wnd() display.manually_hidden = not display.manually_hidden end

-- ============================================================================
-- INIT
-- ============================================================================
init_log_file()
log_msg("========================================")
log_msg("Initializing vATC Sync...")
log_msg("Script dir: " .. tostring(SCRIPT_DIRECTORY))
log_msg("Log file: " .. tostring(log_file_path))
load_xml()
last_poll = os.time()
last_fms_check = os.time()
fetch_vatsim()

-- FlyWithLua callbacks
do_often("vatc_sync_poll()")
do_every_draw("vatc_sync_draw_safe()")

log_msg("vATC Sync " .. VERSION:get_full() .. " ready")
logMsg("vATC Sync " .. VERSION:get_full() .. " loaded")
