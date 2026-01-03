-- ============================================================================
-- vATC Sync - Alarm System
-- ============================================================================
--
-- Copyright (c) 2025 vPilot KLMVA
-- Licensed under the MIT License
-- GitHub: https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12
--
-- Audio alerts for data changes and mismatches
--
-- ============================================================================

local ALARMS = {}

-- Previous values for change detection
local prev_data = {
    atc_callsign = "",
    atc_freq = "",
    squawk = "",
    fir = "",
    dep_qnh = "",
    arr_qnh = "",
    last_check = 0
}

-- Alarm settings
local alarm_config = {
    enabled = true,
    data_change = true,
    aircraft_mismatch = true,
    cooldown = 5.0  -- Seconds between same alarm
}

local last_alarm_time = {
    data_change = 0,
    mismatch = 0
}

-- Play beep sound (uses X-Plane command)
local function play_beep()
    if command_once then
        -- FWL command to play system beep
        command_once("sim/operation/failures/rel_otto_off")
    end
end

-- Check if enough time has passed for cooldown
local function can_play_alarm(alarm_type)
    local now = os.time()
    local last = last_alarm_time[alarm_type] or 0
    if (now - last) >= alarm_config.cooldown then
        last_alarm_time[alarm_type] = now
        return true
    end
    return false
end

-- Check for data changes and alert
function ALARMS.check_data_changes(current_data)
    if not alarm_config.enabled or not alarm_config.data_change then
        return
    end

    local now = os.time()
    if (now - prev_data.last_check) < 1 then
        return  -- Check only once per second
    end
    prev_data.last_check = now

    -- Check critical fields for changes
    local changed = false
    local changes = {}

    if current_data.atc_callsign and current_data.atc_callsign ~= prev_data.atc_callsign and prev_data.atc_callsign ~= "" then
        changed = true
        table.insert(changes, "ATC: " .. prev_data.atc_callsign .. " → " .. current_data.atc_callsign)
    end

    if current_data.atc_freq and current_data.atc_freq ~= prev_data.atc_freq and prev_data.atc_freq ~= "" then
        changed = true
        table.insert(changes, "FREQ: " .. prev_data.atc_freq .. " → " .. current_data.atc_freq)
    end

    if current_data.squawk and current_data.squawk ~= prev_data.squawk and prev_data.squawk ~= "" then
        changed = true
        table.insert(changes, "SQWK: " .. prev_data.squawk .. " → " .. current_data.squawk)
    end

    if current_data.fir and current_data.fir ~= prev_data.fir and prev_data.fir ~= "" then
        changed = true
        table.insert(changes, "FIR: " .. prev_data.fir .. " → " .. current_data.fir)
    end

    -- Update previous values
    prev_data.atc_callsign = current_data.atc_callsign or ""
    prev_data.atc_freq = current_data.atc_freq or ""
    prev_data.squawk = current_data.squawk or ""
    prev_data.fir = current_data.fir or ""
    prev_data.dep_qnh = current_data.dep_qnh or ""
    prev_data.arr_qnh = current_data.arr_qnh or ""

    -- Play alarm if changed
    if changed and can_play_alarm("data_change") then
        play_beep()
        if logMsg then
            logMsg("vATC: DATA CHANGE - " .. table.concat(changes, " | "))
        end
    end
end

-- Check aircraft mismatch
function ALARMS.check_aircraft_mismatch(expected_icao, actual_icao)
    if not alarm_config.enabled or not alarm_config.aircraft_mismatch then
        return
    end

    if not expected_icao or not actual_icao then
        return
    end

    -- Normalize
    local exp = expected_icao:gsub("%s+", ""):upper()
    local act = actual_icao:gsub("%s+", ""):upper()

    if exp ~= act and can_play_alarm("mismatch") then
        play_beep()
        if logMsg then
            logMsg("vATC: AIRCRAFT MISMATCH - Expected: " .. exp .. " | Actual: " .. act)
        end
    end
end

-- Configure alarms
function ALARMS.set_config(config)
    if config.enabled ~= nil then alarm_config.enabled = config.enabled end
    if config.data_change ~= nil then alarm_config.data_change = config.data_change end
    if config.aircraft_mismatch ~= nil then alarm_config.aircraft_mismatch = config.aircraft_mismatch end
    if config.cooldown then alarm_config.cooldown = config.cooldown end
end

-- Get current config
function ALARMS.get_config()
    return {
        enabled = alarm_config.enabled,
        data_change = alarm_config.data_change,
        aircraft_mismatch = alarm_config.aircraft_mismatch,
        cooldown = alarm_config.cooldown
    }
end

return ALARMS
