-- ============================================================================
-- vATC Sync - Configuration
-- ============================================================================
--
-- Copyright (c) 2025 vPilot KLMVA
-- Licensed under the MIT License
-- GitHub: https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12
--
-- ============================================================================

local CONFIG = {
    callsign = "AUTO",
    poll_interval = 15,
    simbrief_pilot_id = "",

    auto_tune_com1 = false,
    auto_set_squawk = false,
    auto_fetch_simbrief = true,
    show_header_row = true,

-- if vatsimm dat is not available, or no atc controllers set auto default
    unicom_freq = 122.800,
    vfr_squawk = 2000,

    controller_priority = {
        DEL = 1, GND = 2, TWR = 3, APP = 4, DEP = 4, CTR = 5, FSS = 6
    },

    max_range_gnd_twr = 10,
    max_range_app = 50,
    max_range_ctr = 500,

    show_bar = true,
    bar_color = {0.12, 0.12, 0.12, 0.9},

    data_file = "vATC_sync/debug/vatsim_data.json",
    settings_file = "vATC_sync/vATC_sync_settings.ini"
}

function CONFIG:get_data_path()
    local dir = SCRIPT_DIRECTORY or "./"
    -- ensure trailing slash (handles both UNIX and Windows separators)
    local last_char = string.sub(dir, -1)
    if last_char ~= "/" and last_char ~= "\\" then
        dir = dir .. "/"
    end
    return dir
end

-- Returns the full path to the data file ensuring the path is well-formed.
function CONFIG:get_data_file_path()
    return (self:get_data_path() or "./") .. (self.data_file or "vatsim_data.json")
end

-- Basic validation helper to ensure config values are sensible. Returns true if ok,
-- otherwise returns false and a table with error messages.
function CONFIG:validate()
    local errors = {}

    if type(self.callsign) ~= "string" or self.callsign == "" then
        table.insert(errors, "callsign must be a non-empty string")
    end

    if type(self.poll_interval) ~= "number" or self.poll_interval < 5 then
        table.insert(errors, "poll_interval should be a number >= 5 (seconds)")
    end

    if type(self.unicom_freq) ~= "number" then
        table.insert(errors, "unicom_freq should be a number (e.g. 122.8)")
    end

    if type(self.vfr_squawk) ~= "number" or self.vfr_squawk < 0 or self.vfr_squawk > 7777 then
        table.insert(errors, "vfr_squawk should be a number between 0 and 7777")
    end

    if type(self.bar_color) ~= "table" or #self.bar_color < 3 then
        table.insert(errors, "bar_color should be a table with RGB(A) values between 0 and 1")
    else
        for i, c in ipairs(self.bar_color) do
            if type(c) ~= "number" or c < 0 or c > 1 then
                table.insert(errors, "bar_color values must be numbers between 0 and 1")
                break
            end
        end
    end

    if type(self.data_file) ~= "string" or self.data_file == "" then
        table.insert(errors, "data_file must be a non-empty string path")
    end

    if #errors == 0 then
        return true
    end
    return false, errors
end

return CONFIG
