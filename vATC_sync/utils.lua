-- ============================================================================
-- vATC Sync - Utilities
-- ============================================================================
--
-- Copyright (c) 2025 vPilot KLMVA
-- Licensed under the MIT License
-- GitHub: https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12
--
-- ============================================================================

local UTILS = {}

-- Calculate distance between two points in nautical miles
function UTILS.calc_distance_nm(lat1, lon1, lat2, lon2)
    if not lat1 or not lon1 or not lat2 or not lon2 then return 9999 end
    local R = 3440.065  -- Earth radius in nm
    local dLat = math.rad(lat2 - lat1)
    local dLon = math.rad(lon2 - lon1)
    local a = math.sin(dLat/2)^2 + math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) * math.sin(dLon/2)^2
    local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c
end

-- Convert frequency to X-Plane format (X-Plane uses units of 0.01 MHz, e.g. 122.800 -> 12280)
-- Accepts either:
--  - a MHz value (122.800 or 118.3) -> converts to X-Plane units (MHz * 100)
--  - an already-converted X-Plane value (>= 1000) -> returned as-is (rounded)
function UTILS.freq_to_xplane(freq_str)
    if not freq_str then return 0 end
    local freq = tonumber(freq_str)
    if not freq then return 0 end

    -- If the number looks already like X-Plane units (>= 1000), return rounded value
    if freq >= 1000 then
        return math.floor(freq + 0.5)
    end

    -- Otherwise treat as MHz and convert to X-Plane units (0.01 MHz)
    return math.floor(freq * 100 + 0.5)
end

-- Convert X-Plane frequency to display format
-- X-Plane uses 0.01 MHz units: 11830 -> 118.300, 12280 -> 122.800
function UTILS.xplane_to_freq(xfreq)
    if not xfreq or xfreq == 0 then return "122.800" end
    local mhz = xfreq / 100
    return string.format("%.3f", mhz)
end

-- Get controller type from callsign
function UTILS.get_ctrl_type(callsign)
    if not callsign then return "UNK" end
    local cs = callsign:upper()
    if cs:find("_DEL") then return "DEL"
    elseif cs:find("_GND") then return "GND"
    elseif cs:find("_TWR") then return "TWR"
    elseif cs:find("_APP") then return "APP"
    elseif cs:find("_DEP") then return "DEP"
    elseif cs:find("_CTR") then return "CTR"
    elseif cs:find("_FSS") then return "FSS"
    elseif cs:find("_ATIS") then return "ATIS"
    end
    return "UNK"
end

-- Convert squawk string to number
function UTILS.squawk_to_num(sq)
    if not sq then return 2000 end
    local n = tonumber(sq)
    return n and n or 2000
end

-- Convert number to squawk string
function UTILS.num_to_squawk(n)
    if not n then return "2000" end
    return string.format("%04d", n)
end

-- Extract JSON value. Returns number for numeric values, string for quoted strings, or nil.
function UTILS.extract_json(text, key)
    if not text or not key then return nil end

    -- Try string value first: "key":"value"
    local pattern_str = '"' .. key .. '"%s*:%s*"([^\"]*)"'
    local value = text:match(pattern_str)
    if value then return value end

    -- Try numeric value: "key":123 or "key":-12.34
    local pattern_num = '"' .. key .. '"%s*:%s*([%d%.%-]+)'
    local numstr = text:match(pattern_num)
    if numstr then
        local n = tonumber(numstr)
        if n then return n end
        return numstr
    end

    return nil
end

-- Format frequency string to always show 3 decimals (118.3 -> 118.300)
function UTILS.format_freq(freq_str)
    if not freq_str or freq_str == "" then return "---" end
    local freq = tonumber(freq_str)
    if not freq then return freq_str end
    return string.format("%.3f", freq)
end

-- Parse METAR for weather info
-- Returns a table like: { qnh=1013, temp=15, wind_dir=220, wind_spd=15, wind_gust=20 }
function UTILS.parse_metar(metar)
    local result = { qnh = nil, temp = nil, wind_dir = nil, wind_spd = nil, wind_gust = nil }
    if not metar or metar == "" then return result end

    -- Wind: try patterns in order (with gust, normal, variable)
    do
        -- Gusts with direction: 22015G25KT
        local dir, spd, gust = metar:match("(%d%d%d)(%d%d)G(%d%d)KT")
        if dir and spd then
            result.wind_dir = tonumber(dir)
            result.wind_spd = tonumber(spd)
            if gust then result.wind_gust = tonumber(gust) end
        else
            -- Direction/speed without gust: 22015KT or 220/15KT (some sources)
            dir, spd = metar:match("(%d%d%d)(%d%d)KT")
            if dir and spd then
                result.wind_dir = tonumber(dir)
                result.wind_spd = tonumber(spd)
            else
                dir, spd = metar:match("(%d%d%d)/(%d%d)KT")
                if dir and spd then
                    result.wind_dir = tonumber(dir)
                    result.wind_spd = tonumber(spd)
                else
                    -- Variable wind with gust: VRB05G10KT or VRB05KT
                    local vrb_spd, vrb_g = metar:match("VRB(%d%d)G(%d%d)KT")
                    if vrb_spd then
                        result.wind_dir = 0
                        result.wind_spd = tonumber(vrb_spd)
                        result.wind_gust = tonumber(vrb_g)
                    else
                        vrb_spd = metar:match("VRB(%d%d)KT")
                        if vrb_spd then
                            result.wind_dir = 0
                            result.wind_spd = tonumber(vrb_spd)
                        else
                            -- Calm: 00000KT -> wind_spd = 0
                            local calm = metar:match("00000KT")
                            if calm then
                                result.wind_dir = 0
                                result.wind_spd = 0
                            end
                        end
                    end
                end
            end
        end
    end

    -- Temperature: matches formats like " 12/05 " or " M02/M05 "
    do
        local temp_str, _ = metar:match(" (M?%d%d)/(M?%d%d)")
        if temp_str then
            if temp_str:sub(1,1) == "M" then
                result.temp = -tonumber(temp_str:sub(2))
            else
                result.temp = tonumber(temp_str)
            end
        end
    end

    -- QNH: Q1021 (hPa) or A2992 (inHg)
    do
        local qnh_hpa = metar:match("Q(%d%d%d%d)")
        if qnh_hpa then
            result.qnh = tonumber(qnh_hpa)
        else
            local qnh_inhg = metar:match("A(%d%d%d%d)")
            if qnh_inhg then
                -- Convert inHg * 100 (e.g., A2992 -> 29.92 inHg) to hPa
                local inhg = tonumber(qnh_inhg) / 100
                local hpa = inhg * 33.8639
                result.qnh = math.floor(hpa + 0.5) -- rounded
            end
        end
    end

    return result
end

return UTILS
