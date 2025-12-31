-- vATC Sync - Utilities
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

-- Convert frequency to X-Plane format (Hz * 10000 for 8.33 spacing)
function UTILS.freq_to_xplane(freq_str)
    if not freq_str then return 0 end
    local freq = tonumber(freq_str)
    if not freq then return 0 end
    return math.floor(freq * 1000000)
end

-- Convert X-Plane frequency to display format
-- com1_freq_hz returns frequency in 10 Hz units (118.300 = 11830)
function UTILS.xplane_to_freq(hz)
    if not hz or hz == 0 then return "122.800" end
    -- Format: 11830 -> 118.300
    return string.format("%.3f", hz / 100)
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

-- Extract JSON value
function UTILS.extract_json(text, key)
    if not text or not key then return nil end
    local pattern = '"' .. key .. '"%s*:%s*"([^"]*)"'
    local value = text:match(pattern)
    if not value then
        pattern = '"' .. key .. '"%s*:%s*([%d%.%-]+)'
        value = text:match(pattern)
    end
    return value
end

-- Format frequency string to always show 3 decimals (118.3 -> 118.300)
function UTILS.format_freq(freq_str)
    if not freq_str or freq_str == "" then return "---" end
    local freq = tonumber(freq_str)
    if not freq then return freq_str end
    return string.format("%.3f", freq)
end

return UTILS
