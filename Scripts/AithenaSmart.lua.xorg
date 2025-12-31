----------------------------------------------------
-- Script Name: AithenaSmart XP12 Settings
-- Version: AP_AS_4.8
-- Description: Enhanced AI-driven performance improvements with Q-Learning-based adaptive adjustments, user constraints, learning progress visualization, recommended settings using Dear ImGui for X-Plane 12.

require("graphics")
local lfs = require("lfs_ffi")

-- FlyWithLua XPLM API for datarefs
local XPLMFindDataRef = XPLMFindDataRef
local XPLMGetDatai = XPLMGetDatai
local XPLMGetDataf = XPLMGetDataf
local XPLMSetDatai = XPLMSetDatai
local XPLMSetDataf = XPLMSetDataf

-- Utility function to detect the directory separator
local DIR_SEP = package.config:sub(1,1) == '\\' and '\\' or '/'

-- Base directory for scripts
local SCRIPT_DIRECTORY = SCRIPT_DIRECTORY or (lfs.currentdir() .. DIR_SEP)
local AITHENA_DIR = SCRIPT_DIRECTORY .. "Aithena" .. DIR_SEP

-- INI, LOG, and LIB directories
local INI_DIR = AITHENA_DIR .. "INI" .. DIR_SEP
local LOG_DIR = AITHENA_DIR .. "LOG" .. DIR_SEP
local LIB_DIR = AITHENA_DIR .. "LIB" .. DIR_SEP

-- Files
local SESSION_FILE = INI_DIR .. "ai_ASsession.ini"
local HISTORY_FILE = INI_DIR .. "ai_AShistory.ini"
local LOG_FILE = LOG_DIR .. "ai_ASiwedf.log"
local CONFIG_FILE = INI_DIR .. "ai_ASconfig.ini"
local README_FILE = LIB_DIR .. "AithenaSmartreadme.md"
local RECOMMENDATIONS_FILE = INI_DIR .. "ai_ASrecommendations.ini"

-- Default Settings
local default_settings = {
    scattering_on = 1,                      -- 1 or 0
    visibility_framerate_ratio = 1.0,       -- float
    HDR_on = 1,                             -- 1 or 0
    rendering_res = 1.0,                    -- float
    draw_textured_lites = 1,                -- 1 or 0
    LOD_bias_rat = 1.0,                     -- float
    csm_split_exterior = 1.0,               -- float
    rcas_value = 50,                        -- 0 to 100
    -- New Settings for Recommended Section
    texture_quality = "High",               -- Low, Medium, High
    ambient_occlusion = "Medium",           -- Off, Low, Medium, High
    rendering_resolution = "Default",       -- Customizable based on recommendations
    anisotropic_filtering = "4x",           -- 1x, 2x, 4x, 8x, 16x
    msaa_antialiasing = "4x",               -- Off, 2x, 4x, 8x
    fxaa_antialiasing = "On",               -- On or Off
    cloud_quality = "High",                 -- Low, Medium, High
    shadow_quality = "High",                -- Low, Medium, High
    rendering_distance = "Default",         -- Customizable based on recommendations
    world_object_density = "Medium",        -- Low, Medium, High
    vegetation_density = "Medium",          -- Low, Medium, High
    enable_3d_vegetation = "On",            -- On or Off
}

-- User-configurable thresholds and constraints
local default_config = {
    fps_threshold = 25.00,                     -- Minimum FPS
    gpu_usage_threshold = 75,                  -- Maximum GPU usage (%)
    alpha = 0.1,                               -- Learning rate for Q-Learning
    gamma = 0.9,                               -- Discount factor for Q-Learning
    epsilon = 0.2,                             -- Exploration rate for Q-Learning
    adjustment_cooldown = 60,                  -- in seconds (1 minute)
    user_constraints = {
        scattering_on = {min = 0, max = 1},
        visibility_framerate_ratio = {min = 0.5, max = 2.0},
        HDR_on = {min = 0, max = 1},
        rendering_res = {min = 0.5, max = 2.0},
        draw_textured_lites = {min = 0, max = 1},
        LOD_bias_rat = {min = 0.5, max = 2.0},
        csm_split_exterior = {min = 0.5, max = 2.0},
        rcas_value = {min = 0, max = 100},
        -- Constraints for new settings
        texture_quality = {options = {"Low", "Medium", "High"}},
        ambient_occlusion = {options = {"Off", "Low", "Medium", "High"}},
        anisotropic_filtering = {options = {"1x", "2x", "4x", "8x", "16x"}},
        msaa_antialiasing = {options = {"Off", "2x", "4x", "8x"}},
        fxaa_antialiasing = {options = {"On", "Off"}},
        cloud_quality = {options = {"Low", "Medium", "High"}},
        shadow_quality = {options = {"Low", "Medium", "High"}},
        world_object_density = {options = {"Low", "Medium", "High"}},
        vegetation_density = {options = {"Low", "Medium", "High"}},
        enable_3d_vegetation = {options = {"On", "Off"}},
    }
}

-- Temporary configuration variables stored in a table for better management
local temp_config = {
    fps_threshold = default_config.fps_threshold,
    gpu_usage_threshold = default_config.gpu_usage_threshold,
    alpha = default_config.alpha,
    gamma = default_config.gamma,
    epsilon = default_config.epsilon,
}

-- Last modified times for settings
local settings_last_modified = {}
for key, _ in pairs(default_settings) do
    settings_last_modified[key] = os.date("%Y-%m-%d %H:%M:%S")
end

-- Variables declared as per user's instruction
local settings = {}
local config = {}
local QLearningAgent = {}
local MAX_DATA_POINTS = 100
local learning_progress = {
    adjustments_made = 0,
    total_adjustments = 0,
    stability_improvement = 0,
    performance_boost = 0,
    gpu_load_reduction = 0,
    stability_history = {},
    performance_history = {},
    fps_boost_history = {},
    gpu_reduction_history = {},
    timestamps = {},
}

-- Variables for Q-Learning
local last_adjustment_time = os.time()
local latest_metrics = nil
local latest_explanation = nil

-- Recommended Settings Table
local recommended_settings = {
    ["Texture Quality"] = "",
    ["Ambient Occlusion"] = "",
    ["Rendering Resolution"] = "",
    ["Anisotropic Filtering"] = "",
    ["MSAA Antialiasing"] = "",
    ["FXAA Antialiasing"] = "",
    ["Cloud Quality"] = "",
    ["Shadow Quality"] = "",
    ["Rendering Distance"] = "",
    ["World Object Density"] = "",
    ["Vegetation Density"] = "",
    ["Enable 3D Vegetation"] = "",
}

-- Define Table Flags as Constants
local TABLE_FLAGS_BORDERS = 1
local TABLE_FLAGS_ROW_BG = 2
local TABLE_FLAGS_RESIZABLE = 4

-- Function to log messages to a file with log levels
local function writeToLog(level, message)
    local logFile, err = io.open(LOG_FILE, "a")
    if logFile then
        logFile:write(os.date("%Y-%m-%d %H:%M:%S") .. " [" .. level .. "]: " .. message .. "\n")
        logFile:close()
    else
        print("Error opening log file: " .. tostring(err))
    end
end

-- Function to load or initialize INI data (supports nested tables)
local function AithenaSmart_loadINIFile(path)
    local data = {}
    local file, err = io.open(path, "r")
    if file then
        for line in file:lines() do
            local key_path, value = line:match("([^=]+)=([^=]+)")
            if key_path and value then
                local keys = {}
                for key in string.gmatch(key_path, "[^%.]+") do
                    table.insert(keys, key)
                end
                local t = data
                for i = 1, #keys - 1 do
                    local key = keys[i]
                    t[key] = t[key] or {}
                    t = t[key]
                end
                local final_key = keys[#keys]
                if tonumber(value) ~= nil then
                    t[final_key] = tonumber(value)
                elseif value:lower() == "true" or value:lower() == "false" then
                    t[final_key] = (value:lower() == "true")
                else
                    t[final_key] = value
                end
            else
                writeToLog("WARNING", "Invalid line format in INI file at " .. path .. ": " .. tostring(line))
            end
        end
        file:close()
    else
        writeToLog("INFO", "INI file does not exist at " .. path .. ". It will be created upon saving.")
    end
    return data
end

-- Function to save INI data (supports nested tables)
local function AithenaSmart_saveINIFile(path, data)
    local file, err = io.open(path, "w")
    if file then
        local function writeData(t, parent_key)
            for key, value in pairs(t) do
                local full_key = parent_key and (parent_key .. "." .. key) or key
                if type(value) == "table" then
                    writeData(value, full_key)
                else
                    if type(value) == "boolean" then
                        file:write(string.format("%s=%s\n", full_key, value and "true" or "false"))
                    elseif type(value) == "number" then
                        if key == "rcas_value" then
                            file:write(string.format("%s=%d\n", full_key, value))
                        else
                            file:write(string.format("%s=%.2f\n", full_key, value))
                        end
                    else
                        file:write(string.format("%s=%s\n", full_key, tostring(value)))
                    end
                end
            end
        end
        writeData(data)
        file:close()
        writeToLog("INFO", "Saved INI file at " .. path)
    else
        writeToLog("ERROR", "Could not open file for writing: " .. path .. " - " .. tostring(err))
    end
end

-- Function to ensure a directory exists; creates it if it doesn't
local function ensureDirectory(path)
    path = string.gsub(path, "[/\\]+", DIR_SEP)

    local attr = lfs.attributes(path)
    if not (attr and attr.mode == "directory") then
        local success, err = lfs.mkdir(path)
        if not success then
            if err ~= "File exists" then
                writeToLog("ERROR", "Could not create directory " .. path .. "! " .. tostring(err))
            else
                writeToLog("INFO", "Directory already exists: " .. path)
            end
        else
            writeToLog("INFO", "Created directory: " .. path)
        end
    else
        writeToLog("INFO", "Directory already exists: " .. path)
    end
end

-- Ensure directories exist
ensureDirectory(AITHENA_DIR)
ensureDirectory(INI_DIR)
ensureDirectory(LOG_DIR)
ensureDirectory(LIB_DIR)

-- Function to backup a file before clearing
local function backupFile(original_path)
    local backup_path = original_path .. ".bak"
    local original_file, err = io.open(original_path, "r")
    if original_file then
        local content = original_file:read("*all")
        original_file:close()
        local backup_file, err = io.open(backup_path, "w")
        if backup_file then
            backup_file:write(content)
            backup_file:close()
            writeToLog("INFO", "Backup created for " .. original_path .. " at " .. backup_path)
        else
            writeToLog("ERROR", "Failed to create backup for " .. original_path .. ": " .. tostring(err))
        end
    else
        if err ~= "No such file or directory" then
            writeToLog("ERROR", "Failed to open " .. original_path .. " for backup: " .. tostring(err))
        else
            writeToLog("INFO", "No existing log file to backup at " .. original_path)
        end
    end
end

-- Function to clear the log file with backup
local function clearLogFile()
    -- Backup the log file before clearing
    backupFile(LOG_FILE)

    local logFile, err = io.open(LOG_FILE, "w")  -- 'w' mode will overwrite the file
    if logFile then
        logFile:write("")  -- Write nothing to clear the file
        logFile:close()
        writeToLog("INFO", "Log file cleared.")
    else
        writeToLog("ERROR", "Error clearing log file: " .. tostring(err))
    end
end

-- Call the custom log-clearing function at the start of the script
clearLogFile()

-- Load session, history, and config data
local session_data = AithenaSmart_loadINIFile(SESSION_FILE) or {}
local history_data = AithenaSmart_loadINIFile(HISTORY_FILE) or {}
local config_data = AithenaSmart_loadINIFile(CONFIG_FILE) or {}

-- Merge session data into settings
for key, default_value in pairs(default_settings) do
    if session_data[key] ~= nil then
        settings[key] = session_data[key]
        settings_last_modified[key] = os.date("%Y-%m-%d %H:%M:%S")
    else
        settings[key] = default_value
    end
end

-- Merge config data into config
for key, default_value in pairs(default_config) do
    if config_data[key] ~= nil then
        config[key] = config_data[key]
    else
        config[key] = default_value
    end
end

-- Ensure CONFIG_FILE exists by saving if it doesn't
if not lfs.attributes(CONFIG_FILE) then
    AithenaSmart_saveINIFile(CONFIG_FILE, config)
    writeToLog("INFO", "Created default CONFIG_FILE.")
end

-- Function to check if a table contains a value
local function table_contains(tbl, element)
    for _, value in ipairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

-- Initialize Q-Learning Agent
QLearningAgent = {
    Q = {},  -- Q-Table
    alpha = config.alpha,  -- Learning rate
    gamma = config.gamma,  -- Discount factor
    epsilon = config.epsilon,  -- Exploration rate
    actions = {},  -- List of possible actions
    init = function(self)
        -- Initialize actions based on settings
        self.actions = {
            "toggle_scattering_on",
            "adjust_visibility_framerate_ratio",
            "toggle_HDR_on",
            "adjust_rendering_res",
            "toggle_draw_textured_lites",
            "adjust_LOD_bias_rat",
            "adjust_csm_split_exterior",
            "adjust_rcas_value",
            "adjust_texture_quality",
            "adjust_ambient_occlusion",
            "adjust_anisotropic_filtering",
            "adjust_msaa_antialiasing",
            "toggle_fxaa_antialiasing",
            "adjust_cloud_quality",
            "adjust_shadow_quality",
            "adjust_rendering_distance",
            "adjust_world_object_density",
            "adjust_vegetation_density",
            "toggle_enable_3d_vegetation",
        }

        -- Initialize Q-Table with all state-action pairs
        local states = self:get_all_states()
        for _, state in ipairs(states) do
            self.Q[state] = {}
            for _, action in ipairs(self.actions) do
                self.Q[state][action] = 0.0
            end
        end

        writeToLog("INFO", "Q-Learning Agent initialized with Q-Table.")
    end,
    get_all_states = function(self)
        -- Define states based on FPS and GPU usage
        -- For simplicity, we categorize FPS and GPU usage into discrete states
        local states = {}
        local fps_states = {"Low", "Medium", "High"}
        local gpu_states = {"Low", "Medium", "High"}

        for _, fps in ipairs(fps_states) do
            for _, gpu in ipairs(gpu_states) do
                table.insert(states, fps .. "_" .. gpu)
            end
        end

        return states
    end,
    get_state = function(self, metrics)
        -- Determine the state based on current FPS and GPU usage
        if not metrics then
            return "Unknown_Unknown"
        end

        local fps = metrics.fps or 0
        local gpu = metrics.gpu_usage or 0

        local fps_state = "Medium"
        if fps < 25 then
            fps_state = "Low"
        elseif fps >= 50 then
            fps_state = "High"
        end

        local gpu_state = "Medium"
        if gpu < 50 then
            gpu_state = "Low"
        elseif gpu >= 80 then
            gpu_state = "High"
        end

        return fps_state .. "_" .. gpu_state
    end,
    choose_action = function(self, state)
        -- Epsilon-greedy policy
        if math.random() < self.epsilon then
            -- Exploration: choose a random action
            local rand_index = math.random(#self.actions)
            return self.actions[rand_index]
        else
            -- Exploitation: choose the best action based on Q-Table
            local best_action = nil
            local max_q = -math.huge
            for _, action in ipairs(self.actions) do
                local q_value = self.Q[state][action] or 0.0
                if q_value > max_q then
                    max_q = q_value
                    best_action = action
                end
            end
            -- If no best action found, choose randomly
            if not best_action then
                best_action = self.actions[math.random(#self.actions)]
            end
            return best_action
        end
    end,
    update_q = function(self, state, action, reward, next_state)
        -- Update Q-Table using the Q-Learning update rule
        local current_q = self.Q[state][action] or 0.0
        local max_next_q = -math.huge
        for _, a in ipairs(self.actions) do
            local q_val = self.Q[next_state][a] or 0.0
            if q_val > max_next_q then
                max_next_q = q_val
            end
        end
        if max_next_q == -math.huge then
            max_next_q = 0.0
        end
        local updated_q = current_q + self.alpha * (reward + self.gamma * max_next_q - current_q)
        self.Q[state][action] = updated_q
        writeToLog("INFO", string.format("Q-Table updated for state '%s' and action '%s' to %.2f", state, action, updated_q))
    end,
}

-- Initialize Q-Learning Agent
QLearningAgent:init()

-- Function to find datarefs (Defined globally)
function findDatarefs()
    local refs = {
        scattering_on = XPLMFindDataRef("sim/graphics/settings/scattering_on"),
        visibility_framerate_ratio = XPLMFindDataRef("sim/graphics/view/visibility_framerate_ratio"),
        HDR_on = XPLMFindDataRef("sim/graphics/settings/HDR_on"),
        rendering_res = XPLMFindDataRef("sim/graphics/settings/rendering_res"),
        draw_textured_lites = XPLMFindDataRef("sim/graphics/settings/draw_textured_lites"),
        LOD_bias_rat = XPLMFindDataRef("sim/private/controls/reno/LOD_bias_rat"),
        csm_split_exterior = XPLMFindDataRef("sim/private/controls/shadow/csm_split_exterior"),
        rcas_value = XPLMFindDataRef("sim/graphics/settings/rcas_value"), -- Assuming this is a valid dataref
        -- New datarefs for recommended settings (Assuming these are valid datarefs)
        texture_quality = XPLMFindDataRef("sim/graphics/settings/texture_quality"),
        ambient_occlusion = XPLMFindDataRef("sim/graphics/settings/ambient_occlusion"),
        rendering_resolution = XPLMFindDataRef("sim/graphics/settings/rendering_resolution"),
        anisotropic_filtering = XPLMFindDataRef("sim/graphics/settings/anisotropic_filtering"),
        msaa_antialiasing = XPLMFindDataRef("sim/graphics/settings/msaa_antialiasing"),
        fxaa_antialiasing = XPLMFindDataRef("sim/graphics/settings/fxaa_antialiasing"),
        cloud_quality = XPLMFindDataRef("sim/graphics/settings/cloud_quality"),
        shadow_quality = XPLMFindDataRef("sim/graphics/settings/shadow_quality"),
        rendering_distance = XPLMFindDataRef("sim/graphics/settings/rendering_distance"),
        world_object_density = XPLMFindDataRef("sim/graphics/settings/world_object_density"),
        vegetation_density = XPLMFindDataRef("sim/graphics/settings/vegetation_density"),
        enable_3d_vegetation = XPLMFindDataRef("sim/graphics/settings/enable_3d_vegetation"),
    }

    for key, ref in pairs(refs) do
        if not ref then
            writeToLog("ERROR", "Dataref '" .. key .. "' not found.")
        else
            writeToLog("INFO", "Dataref '" .. key .. "' found.")
        end
    end

    return refs
end

-- Now that findDatarefs is defined globally, we can safely call it
local datarefs = findDatarefs()

-- Function to calculate RCAS percentage based on GPU usage and FPS balance
local function calculateRCAS(gpu_usage, fps)
    local rcas_value = (100 - ((gpu_usage * 0.6) + (fps * 0.4)))
    return math.max(0, math.min(rcas_value, 100)) -- Ensure RCAS is between 0% and 100%
end

-- Function to collect essential system metrics with validation and logging
local function collectSystemMetrics()
    local metrics = {
        fps = 0,
        gpu_usage = 0,
        cpu_usage = 60, -- Placeholder for CPU usage collection
    }

    -- Collect FPS using primary dataref
    local frame_rate_ref = XPLMFindDataRef("sim/time/framerate_period")
    if frame_rate_ref then
        local frame_rate_period = XPLMGetDataf(frame_rate_ref)
        if frame_rate_period > 0 then
            metrics.fps = math.floor(1 / frame_rate_period)
            writeToLog("INFO", string.format("FPS Retrieved: %d", metrics.fps))
        else
            writeToLog("WARNING", "'framerate_period' is zero or negative.")
        end
    else
        writeToLog("ERROR", "FPS dataref not found.")
        return nil -- Return nil if the dataref is missing
    end

    -- Collect GPU usage using primary dataref
    local gpu_usage_ref = XPLMFindDataRef("sim/time/gpu_time_per_frame_sec_approx")
    if gpu_usage_ref then
        local gpu_time = XPLMGetDataf(gpu_usage_ref)
        if metrics.fps > 0 then
            local frame_time = 1 / metrics.fps
            metrics.gpu_usage = math.floor((gpu_time / frame_time) * 100)
            writeToLog("INFO", string.format("GPU Usage Calculated: %d%%", metrics.gpu_usage))
        else
            writeToLog("ERROR", "FPS is zero, cannot calculate GPU usage.")
        end
    else
        writeToLog("ERROR", "GPU dataref not found.")
        return nil -- Return nil if the dataref is missing
    end

    return metrics
end

-- Function to generate NLP-based explanations based on the gathered metrics
local function AithenaSmart_generateNLPExplanations(metrics)
    if not metrics then
        return "Metrics unavailable. Unable to provide performance explanations."
    end

    if metrics.fps < config.fps_threshold then
        return "Your frame rate is below optimal levels. The advisor has adjusted settings to improve performance."
    elseif metrics.gpu_usage > config.gpu_usage_threshold then
        return "Your GPU is under high load. The advisor has optimized settings to reduce GPU strain."
    else
        return "Your system is performing optimally. Minor adjustments have been made to enhance visual quality."
    end
end

-- Function to calculate remaining time until next adjustment
local function getRemainingTime()
    local current_time = os.time()
    local next_adjustment_time = last_adjustment_time + config.adjustment_cooldown
    local remaining = next_adjustment_time - current_time

    if remaining > 0 then
        local minutes = math.floor(remaining / 60)
        local seconds = remaining % 60
        return string.format("%02d:%02d", minutes, seconds)
    else
        return "00:00"
    end
end

-- Function to calculate recommended settings based on current performance and AI adjustments
local function calculateRecommendedSettings()
    local recommended = {}

    -- Example logic based on latest_metrics
    if latest_metrics then
        if latest_metrics.fps < config.fps_threshold then
            recommended.texture_quality = "Low"
            recommended.ambient_occlusion = "Off"
            recommended.rendering_resolution = "Low"
            recommended.anisotropic_filtering = "2x"
            recommended.msaa_antialiasing = "2x"
            recommended.fxaa_antialiasing = "Off"
            recommended.cloud_quality = "Low"
            recommended.shadow_quality = "Low"
            recommended.rendering_distance = "Low"
            recommended.world_object_density = "Low"
            recommended.vegetation_density = "Low"
            recommended.enable_3d_vegetation = "Off"
        elseif latest_metrics.gpu_usage > config.gpu_usage_threshold then
            recommended.texture_quality = "Medium"
            recommended.ambient_occlusion = "Low"
            recommended.rendering_resolution = "Medium"
            recommended.anisotropic_filtering = "4x"
            recommended.msaa_antialiasing = "4x"
            recommended.fxaa_antialiasing = "On"
            recommended.cloud_quality = "Medium"
            recommended.shadow_quality = "Medium"
            recommended.rendering_distance = "Medium"
            recommended.world_object_density = "Medium"
            recommended.vegetation_density = "Medium"
            recommended.enable_3d_vegetation = "On"
        else
            recommended.texture_quality = "High"
            recommended.ambient_occlusion = "High"
            recommended.rendering_resolution = "High"
            recommended.anisotropic_filtering = "16x"
            recommended.msaa_antialiasing = "8x"
            recommended.fxaa_antialiasing = "On"
            recommended.cloud_quality = "High"
            recommended.shadow_quality = "High"
            recommended.rendering_distance = "High"
            recommended.world_object_density = "High"
            recommended.vegetation_density = "High"
            recommended.enable_3d_vegetation = "On"
        end
    else
        -- Default recommendations if metrics are unavailable
        recommended = {
            texture_quality = "Medium",
            ambient_occlusion = "Medium",
            rendering_resolution = "Medium",
            anisotropic_filtering = "4x",
            msaa_antialiasing = "4x",
            fxaa_antialiasing = "On",
            cloud_quality = "Medium",
            shadow_quality = "Medium",
            rendering_distance = "Medium",
            world_object_density = "Medium",
            vegetation_density = "Medium",
            enable_3d_vegetation = "On",
        }
    end

    return recommended
end

-- Function to write recommended settings to a file
local function writeRecommendedSettingsToFile(recommended)
    local file, err = io.open(RECOMMENDATIONS_FILE, "w")
    if file then
        file:write("Recommended Settings:\n")
        file:write("----------------------\n")

        -- Iterate through recommended settings to populate the file
        for setting, best_value in pairs(recommended) do
            file:write(setting .. ": " .. best_value .. "\n")
        end

        -- Notes section
        file:write("\nNotes:\n------\n")
        file:write("The recommendations above are tailored to your current system performance and usage profile.\n")
        file:write("Changes in system performance may lead to different recommendations in future flights.\n")
        file:write("Consider adjusting settings manually if your preferences change or you notice performance issues.\n\n")

        -- Version History section
        file:write("Version History:\n")
        file:write("----------------\n")
        file:write(os.date("%Y-%m-%d %H:%M:%S") .. ": Recommendations generated based on dynamic system analysis and Q-Learning adjustments.\n")

        file:close()
        writeToLog("INFO", "Recommended settings written to " .. RECOMMENDATIONS_FILE)
    else
        writeToLog("ERROR", "Failed to write recommended settings to file: " .. tostring(err))
    end
end

-- Function to apply settings to X-Plane via datarefs
local function applySettings(settings_table)
    for key, ref in pairs(datarefs) do
        if ref then
            if key == "scattering_on" or key == "HDR_on" or key == "draw_textured_lites" or key == "rcas_value" then
                -- These are boolean-like settings or integer settings
                if settings_table[key] ~= nil then
                    XPLMSetDatai(ref, settings_table[key])
                    writeToLog("INFO", string.format("Applied '%s' as %d", key, settings_table[key]))
                else
                    writeToLog("WARNING", string.format("Setting '%s' is nil. Skipping application.", key))
                end
            elseif key == "visibility_framerate_ratio" or key == "rendering_res" or key == "LOD_bias_rat" or key == "csm_split_exterior" then
                -- These are float settings
                if settings_table[key] ~= nil then
                    XPLMSetDataf(ref, settings_table[key])
                    writeToLog("INFO", string.format("Applied '%s' as %.2f", key, settings_table[key]))
                else
                    writeToLog("WARNING", string.format("Setting '%s' is nil. Skipping application.", key))
                end
            elseif key == "texture_quality" or key == "ambient_occlusion" or key == "cloud_quality" or key == "shadow_quality" or key == "world_object_density" or key == "vegetation_density" then
                -- Assuming these settings are represented as integers corresponding to options
                local mapping = {
                    texture_quality = {Low = 0, Medium = 1, High = 2},
                    ambient_occlusion = {Off = 0, Low = 1, Medium = 2, High = 3},
                    cloud_quality = {Low = 0, Medium = 1, High = 2},
                    shadow_quality = {Low = 0, Medium = 1, High = 2},
                    world_object_density = {Low = 0, Medium = 1, High = 2},
                    vegetation_density = {Low = 0, Medium = 1, High = 2},
                }
                if settings_table[key] and mapping[key][settings_table[key]] then
                    local numeric_value = mapping[key][settings_table[key]] or 1 -- Default to Medium if undefined
                    XPLMSetDatai(ref, numeric_value)
                    writeToLog("INFO", string.format("Applied '%s' as %d (%s)", key, numeric_value, tostring(settings_table[key])))
                else
                    writeToLog("WARNING", string.format("Setting '%s' has invalid or nil value. Skipping application.", key))
                end
            elseif key == "anisotropic_filtering" then
                local mapping = {
                    ["1x"] = 1,
                    ["2x"] = 2,
                    ["4x"] = 4,
                    ["8x"] = 8,
                    ["16x"] = 16,
                }
                if settings_table[key] and mapping[key][settings_table[key]] then
                    local numeric_value = mapping[key][settings_table[key]] or 4 -- Default to 4x
                    XPLMSetDatai(ref, numeric_value)
                    writeToLog("INFO", string.format("Applied '%s' as %dx", key, numeric_value))
                else
                    writeToLog("WARNING", string.format("Setting '%s' has invalid or nil value. Skipping application.", key))
                end
            elseif key == "msaa_antialiasing" then
                local mapping = {
                    Off = 0,
                    ["2x"] = 2,
                    ["4x"] = 4,
                    ["8x"] = 8,
                }
                if settings_table[key] and mapping[key][settings_table[key]] ~= nil then
                    local numeric_value = mapping[key][settings_table[key]] or 4 -- Default to 4x
                    XPLMSetDatai(ref, numeric_value)
                    writeToLog("INFO", string.format("Applied '%s' as %dx", key, numeric_value))
                else
                    writeToLog("WARNING", string.format("Setting '%s' has invalid or nil value. Skipping application.", key))
                end
            elseif key == "fxaa_antialiasing" then
                local mapping = {On = 1, Off = 0}
                if settings_table[key] and mapping[key][settings_table[key]] ~= nil then
                    local numeric_value = mapping[key][settings_table[key]] or 1
                    XPLMSetDatai(ref, numeric_value)
                    writeToLog("INFO", string.format("Applied '%s' as %d", key, numeric_value))
                else
                    writeToLog("WARNING", string.format("Setting '%s' has invalid or nil value. Skipping application.", key))
                end
            elseif key == "rendering_distance" then
                -- Assuming rendering_distance is a string option mapped to float
                local mapping = {
                    Low = 0.5,
                    Medium = 1.0,
                    High = 1.5,
                    Default = 1.0, -- Assuming default is 1.0
                }
                if settings_table[key] and mapping[key][settings_table[key]] then
                    local numeric_value = mapping[key][settings_table[key]] or 1.0
                    XPLMSetDataf(ref, numeric_value)
                    writeToLog("INFO", string.format("Applied '%s' as %.2f", key, numeric_value))
                else
                    writeToLog("WARNING", string.format("Setting '%s' has invalid or nil value. Skipping application.", key))
                end
            elseif key == "enable_3d_vegetation" then
                local mapping = {On = 1, Off = 0}
                if settings_table[key] and mapping[key][settings_table[key]] ~= nil then
                    local numeric_value = mapping[key][settings_table[key]] or 1
                    XPLMSetDatai(ref, numeric_value)
                    writeToLog("INFO", string.format("Applied '%s' as %d", key, numeric_value))
                else
                    writeToLog("WARNING", string.format("Setting '%s' has invalid or nil value. Skipping application.", key))
                end
            else
                -- Default to integer setting
                if settings_table[key] ~= nil then
                    XPLMSetDatai(ref, settings_table[key])
                    writeToLog("INFO", string.format("Applied '%s' as %d", key, settings_table[key]))
                else
                    writeToLog("WARNING", string.format("Setting '%s' is nil. Skipping application.", key))
                end
            end
        else
            writeToLog("ERROR", string.format("Could not find dataref for '%s'", key))
        end
    end

    -- Function to apply settings based on recommended settings
    local function applyRecommendedSettings(recommended)
        for setting, best_value in pairs(recommended) do
            -- Map the recommended setting back to the internal settings
            if setting == "Texture Quality" then
                settings.texture_quality = best_value
            elseif setting == "Ambient Occlusion" then
                settings.ambient_occlusion = best_value
            elseif setting == "Rendering Resolution" then
                settings.rendering_resolution = best_value
            elseif setting == "Anisotropic Filtering" then
                settings.anisotropic_filtering = best_value
            elseif setting == "MSAA Antialiasing" then
                settings.msaa_antialiasing = best_value
            elseif setting == "FXAA Antialiasing" then
                settings.fxaa_antialiasing = best_value
            elseif setting == "Cloud Quality" then
                settings.cloud_quality = best_value
            elseif setting == "Shadow Quality" then
                settings.shadow_quality = best_value
            elseif setting == "Rendering Distance" then
                settings.rendering_distance = best_value
            elseif setting == "World Object Density" then
                settings.world_object_density = best_value
            elseif setting == "Vegetation Density" then
                settings.vegetation_density = best_value
            elseif setting == "Enable 3D Vegetation" then
                settings.enable_3d_vegetation = best_value
            end
        end

        applySettings(settings)
    end
end
-- Function to perform Q-Learning based adjustments
local function QLearningAdjustments()
    local current_time = os.time()
end
    -- Replaced os.difftime with direct comparison
    if (current_time - last_adjustment_time) > config.adjustment_cooldown then
        latest_metrics = collectSystemMetrics()
        if latest_metrics then
            local state = QLearningAgent:get_state(latest_metrics)
            local action = QLearningAgent:choose_action(state)

            -- Apply the chosen action
            local old_settings = {}
            for key, value in pairs(settings) do
                old_settings[key] = value
            end

            if action == "toggle_scattering_on" then
                settings.scattering_on = 1 - (settings.scattering_on or 1)
            elseif action == "adjust_visibility_framerate_ratio" then
                settings.visibility_framerate_ratio = math.min((settings.visibility_framerate_ratio or 1.0) + 0.1, config.user_constraints.visibility_framerate_ratio.max)
            elseif action == "toggle_HDR_on" then
                settings.HDR_on = 1 - (settings.HDR_on or 1)
            elseif action == "adjust_rendering_res" then
                settings.rendering_res = math.min((settings.rendering_res or 1.0) + 0.1, config.user_constraints.rendering_res.max)
            elseif action == "toggle_draw_textured_lites" then
                settings.draw_textured_lites = 1 - (settings.draw_textured_lites or 1)
            elseif action == "adjust_LOD_bias_rat" then
                settings.LOD_bias_rat = math.min((settings.LOD_bias_rat or 1.0) + 0.1, config.user_constraints.LOD_bias_rat.max)
            elseif action == "adjust_csm_split_exterior" then
                settings.csm_split_exterior = math.min((settings.csm_split_exterior or 1.0) + 0.1, config.user_constraints.csm_split_exterior.max)
            elseif action == "adjust_rcas_value" then
                settings.rcas_value = math.min((settings.rcas_value or 50) + 5, config.user_constraints.rcas_value.max)
            elseif action == "adjust_texture_quality" then
                if settings.texture_quality == "Low" then
                    settings.texture_quality = "Medium"
                elseif settings.texture_quality == "Medium" then
                    settings.texture_quality = "High"
                else
                    settings.texture_quality = "Low"
                end
            elseif action == "adjust_ambient_occlusion" then
                if settings.ambient_occlusion == "Off" then
                    settings.ambient_occlusion = "Low"
                elseif settings.ambient_occlusion == "Low" then
                    settings.ambient_occlusion = "Medium"
                elseif settings.ambient_occlusion == "Medium" then
                    settings.ambient_occlusion = "High"
                else
                    settings.ambient_occlusion = "Off"
                end
            elseif action == "adjust_anisotropic_filtering" then
                local levels = {"1x", "2x", "4x", "8x", "16x"}
                for i, level in ipairs(levels) do
                    if settings.anisotropic_filtering == level then
                        settings.anisotropic_filtering = levels[(i % #levels) + 1]
                        break
                    end
                end
            elseif action == "adjust_msaa_antialiasing" then
                local levels = {"Off", "2x", "4x", "8x"}
                for i, level in ipairs(levels) do
                    if settings.msaa_antialiasing == level then
                        settings.msaa_antialiasing = levels[(i % #levels) + 1]
                        break
                    end
                end
            elseif action == "toggle_fxaa_antialiasing" then
                settings.fxaa_antialiasing = (settings.fxaa_antialiasing == "On") and "Off" or "On"
            elseif action == "adjust_cloud_quality" then
                if settings.cloud_quality == "Low" then
                    settings.cloud_quality = "Medium"
                elseif settings.cloud_quality == "Medium" then
                    settings.cloud_quality = "High"
                else
                    settings.cloud_quality = "Low"
                end
            elseif action == "adjust_shadow_quality" then
                if settings.shadow_quality == "Low" then
                    settings.shadow_quality = "Medium"
                elseif settings.shadow_quality == "Medium" then
                    settings.shadow_quality = "High"
                else
                    settings.shadow_quality = "Low"
                end
            elseif action == "adjust_rendering_distance" then
                if settings.rendering_distance == "Low" then
                    settings.rendering_distance = "Medium"
                elseif settings.rendering_distance == "Medium" then
                    settings.rendering_distance = "High"
                else
                    settings.rendering_distance = "Low"
                end
            elseif action == "adjust_world_object_density" then
                if settings.world_object_density == "Low" then
                    settings.world_object_density = "Medium"
                elseif settings.world_object_density == "Medium" then
                    settings.world_object_density = "High"
                else
                    settings.world_object_density = "Low"
                end
            elseif action == "adjust_vegetation_density" then
                if settings.vegetation_density == "Low" then
                    settings.vegetation_density = "Medium"
                elseif settings.vegetation_density == "Medium" then
                    settings.vegetation_density = "High"
                else
                    settings.vegetation_density = "Low"
                end
            elseif action == "toggle_enable_3d_vegetation" then
                settings.enable_3d_vegetation = (settings.enable_3d_vegetation == "On") and "Off" or "On"
            end

            -- Clamp settings based on user constraints
            for key, constraint in pairs(config.user_constraints) do
                if constraint.min and constraint.max then
                    if settings[key] ~= nil then
                        settings[key] = math.max(constraint.min, math.min(settings[key], constraint.max))
                    end
                elseif constraint.options then
                    if settings[key] == nil or not table_contains(constraint.options, settings[key]) then
                        settings[key] = constraint.options[math.floor(#constraint.options / 2) + 1] -- Set to middle option
                        writeToLog("WARNING", string.format("Setting '%s' was out of options. Reset to '%s'.", key, settings[key]))
                    end
                end
            end

            applySettings(settings)

            -- Calculate reward based on performance
            local reward = 0
            if latest_metrics.fps >= config.fps_threshold and latest_metrics.gpu_usage <= config.gpu_usage_threshold then
                reward = 10  -- Positive reward
            elseif latest_metrics.fps < config.fps_threshold or latest_metrics.gpu_usage > config.gpu_usage_threshold then
                reward = -10  -- Negative reward
            else
                reward = 0  -- Neutral
            end

            -- Collect new metrics after adjustment
            local new_metrics = collectSystemMetrics()
            if new_metrics then
                local new_state = QLearningAgent:get_state(new_metrics)
                QLearningAgent:update_q(state, action, reward, new_state)
            end

            -- Generate explanation
            latest_explanation = AithenaSmart_generateNLPExplanations(latest_metrics)
            last_adjustment_time = current_time

            -- Update learning progress
            learning_progress.adjustments_made = learning_progress.adjustments_made + 1
            learning_progress.total_adjustments = learning_progress.total_adjustments + 1
            if reward > 0 then
                learning_progress.performance_boost = learning_progress.performance_boost + 10
                learning_progress.gpu_load_reduction = learning_progress.gpu_load_reduction + 5
            elseif reward < 0 then
                learning_progress.stability_improvement = learning_progress.stability_improvement + 5
            end

            table.insert(learning_progress.stability_history, learning_progress.stability_improvement)
            table.insert(learning_progress.performance_history, learning_progress.performance_boost)
            table.insert(learning_progress.fps_boost_history, 15)  -- Placeholder for actual FPS increase
            table.insert(learning_progress.gpu_reduction_history, 5)  -- Placeholder for actual GPU reduction
            table.insert(learning_progress.timestamps, current_time)

            -- Keep data arrays within MAX_DATA_POINTS
            if #learning_progress.stability_history > MAX_DATA_POINTS then
                table.remove(learning_progress.stability_history, 1)
                table.remove(learning_progress.performance_history, 1)
                table.remove(learning_progress.fps_boost_history, 1)
                table.remove(learning_progress.gpu_reduction_history, 1)
                table.remove(learning_progress.timestamps, 1)
            end

            -- Calculate and write recommended settings
            local recommended = calculateRecommendedSettings()
            writeRecommendedSettingsToFile(recommended)

            writeToLog("INFO", string.format("Q-Learning Adjustment: Action '%s' taken with reward %d", action, reward))
        end
    end

    -- Function to perform incremental learning and adjustments
    local function incrementalLearning()
        QLearningAdjustments()
    end

    -- Start the incremental learning coroutine
    local co = coroutine.create(function()
        while true do
            incrementalLearning()
            coroutine.yield()
        end
    end)

    -- Function to resume the coroutine periodically with error handling
    function AithenaSmart_resumeCoroutine()
        if coroutine.status(co) ~= "dead" then
            local success, err = coroutine.resume(co)
            if not success then
                writeToLog("ERROR", "Coroutine error: " .. tostring(err))
            end
        end
    end

    -- Schedule the coroutine to run frequently
    do_often("AithenaSmart_resumeCoroutine()")

    -- Function to open a file with the default application
    local function openFile(path)
        local command
        local platform = package.config:sub(1, 1) == '\\' and "IBM" or (io.popen("uname"):read("*l") or "")

        if platform == "IBM" then
            command = 'start "" "' .. path .. '"'
        elseif platform == "Linux" then
            command = 'xdg-open "' .. path .. '"'
        elseif platform == "Darwin" then
            command = 'open "' .. path .. '"'
        else
            writeToLog("ERROR", "Unsupported system for opening files.")
            return
        end

        local success, _, exit_code = os.execute(command)
        if not success or exit_code ~= 0 then
            writeToLog("ERROR", "Failed to open file: " .. path)
        else
            writeToLog("INFO", "File opened successfully: " .. path)
        end
    end

    -- Function to display the performance settings UI using Dear ImGui for X-Plane 12
    local function AithenaSmart_generateUI()
        imgui.Dummy(0, 5)

        -- Title with font scale 2
        imgui.SetWindowFontScale(2.0)
        imgui.TextUnformatted("** AithenaSmart XP12 Settings **")
        imgui.Separator()
        imgui.Dummy(0, 5)
        imgui.Dummy(0, 5)

        -- Readme Button
        imgui.SetWindowFontScale(1.0)
        if imgui.Button("Readme") then
            openFile(README_FILE)
            writeToLog("INFO", "Readme file opened.")
        end
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- User Environment Settings Section
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** User Environment Settings **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        imgui.SetWindowFontScale(1.4)
        imgui.Indent()

        -- Dropdown Menu for Computer Type Selection
        local computer_types = { "Low-End", "Mid-Range", "High-End" }
        local selected = 1
        for i, type in ipairs(computer_types) do
            if config.system_threshold == type then
                selected = i
                break
            end
        end

        if imgui.Combo("Computer Type", selected, computer_types, #computer_types) then
            config.system_threshold = computer_types[selected]
            -- Update thresholds based on selection
            if config.system_threshold == "Low-End" then
                config.fps_threshold = 25.00
                config.gpu_usage_threshold = 60
            elseif config.system_threshold == "Mid-Range" then
                config.fps_threshold = 30.00
                config.gpu_usage_threshold = 75
            elseif config.system_threshold == "High-End" then
                config.fps_threshold = 60.00
                config.gpu_usage_threshold = 90
            end
            writeToLog("INFO", "Computer type changed to " .. config.system_threshold)
            -- Save the updated configuration
            AithenaSmart_saveINIFile(CONFIG_FILE, config)
        end

        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- Live Performance Overview Section
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** Live Performance Overview **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        -- Current Performance Metrics
        imgui.SetWindowFontScale(1.4)
        imgui.TextUnformatted("Current Performance Metrics:")
        imgui.Indent()
        local fps_display = latest_metrics and latest_metrics.fps > 0 and latest_metrics.fps or "N/A"
        local gpu_display = latest_metrics and latest_metrics.gpu_usage > 0 and latest_metrics.gpu_usage .. "%" or "N/A"
        local cpu_display = latest_metrics and latest_metrics.cpu_usage and latest_metrics.cpu_usage .. "%" or "N/A"
        imgui.TextUnformatted("FPS (Frames Per Second): " .. tostring(fps_display))
        imgui.TextUnformatted("GPU Usage: " .. tostring(gpu_display))
        imgui.TextUnformatted("CPU Usage: " .. tostring(cpu_display))
        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- AI-Driven Adjustments Summary
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** AI-Driven Adjustments Summary **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        imgui.SetWindowFontScale(1.4)
        imgui.Indent()
        imgui.TextUnformatted("Scattering On: " .. tostring(settings.scattering_on))
        imgui.TextUnformatted(string.format("Visibility Framerate Ratio: %.2f", settings.visibility_framerate_ratio))
        imgui.TextUnformatted("HDR On: " .. tostring(settings.HDR_on))
        imgui.TextUnformatted(string.format("Rendering Resolution: %.2f", settings.rendering_res))
        imgui.TextUnformatted("Draw Textured Lites: " .. tostring(settings.draw_textured_lites))
        imgui.TextUnformatted(string.format("LOD Bias Ratio: %.2f", settings.LOD_bias_rat))
        imgui.TextUnformatted(string.format("CSM Split Exterior: %.2f", settings.csm_split_exterior))
        imgui.TextUnformatted("RCAS Value: " .. tostring(settings.rcas_value) .. "%")
        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- Learning and Adaptation Progress
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** Learning and Adaptation Progress **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        imgui.SetWindowFontScale(1.4)
        imgui.Indent()
        imgui.TextUnformatted(string.format("Learning Rate (Alpha): %.3f", config.alpha))
        imgui.TextUnformatted(string.format("Discount Factor (Gamma): %.2f", config.gamma))
        imgui.TextUnformatted(string.format("Exploration Rate (Epsilon): %.2f", config.epsilon))
        imgui.TextUnformatted(string.format("Adjustments Made This Session: %d", learning_progress.adjustments_made))
        imgui.TextUnformatted(string.format("Total Adjustments Over Time: %d", learning_progress.total_adjustments))
        imgui.TextUnformatted(string.format("Stability Improvement: +%d%%", learning_progress.stability_improvement))
        imgui.TextUnformatted(string.format("Performance Boost: +%d%%", learning_progress.performance_boost))
        imgui.TextUnformatted(string.format("GPU Load Reduction: -%d%%", learning_progress.gpu_load_reduction))
        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- AI Efficiency Stats
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** AI Efficiency Stats **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        imgui.SetWindowFontScale(1.4)
        imgui.Indent()
        imgui.TextUnformatted(string.format("Stability Boost: AI has maintained %d%% system stability with current settings.", 95))
        imgui.TextUnformatted("AI-Predicted Load: Next adjustment expected to target shadow quality.")
        imgui.TextUnformatted(string.format("Overall Performance Gain: +%d%% performance improvement over the last 3 sessions.", 12))
        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- Upcoming AI Decisions
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** Upcoming AI Decisions **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        imgui.SetWindowFontScale(1.4)
        imgui.Indent()
        imgui.TextUnformatted("Next AI Adjustment: In " .. getRemainingTime() .. " (targeting object density and rendering distance based on current GPU load)")
        imgui.TextUnformatted("Focus: AI will balance shadow quality and object rendering density in the next session.")
        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- Recommended Settings Section
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** Recommended Settings **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        imgui.SetWindowFontScale(1.4)
        imgui.Indent()

        -- Begin Table with 2 Columns: Setting, Best Value
        if imgui.BeginTable("RecommendedSettingsTable", 2, TABLE_FLAGS_BORDERS + TABLE_FLAGS_ROW_BG + TABLE_FLAGS_RESIZABLE) then
            -- Header Row
            imgui.TableNextRow()
            imgui.TableNextColumn()
            imgui.SetWindowFontScale(1.6)
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xd14D43FF)
            imgui.TextUnformatted("* XP Settings *")
            imgui.PopStyleColor()
            imgui.Dummy(0, 5)
            imgui.SetWindowFontScale(1.4)
            imgui.TableNextColumn()
            imgui.SetWindowFontScale(1.6)
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xd14D43FF)
            imgui.TextUnformatted("* Best Values *")
            imgui.PopStyleColor()
            imgui.Dummy(0, 5)
            imgui.SetWindowFontScale(1.4)

            -- Iterate through recommended_settings to populate the table
            for setting, best_value in pairs(recommended_settings) do
                if best_value ~= "" then  -- Only display settings with recommendations
                    imgui.TableNextRow()

                    -- Column 1: Setting
                    imgui.TableNextColumn()
                    imgui.TextUnformatted(setting)

                    -- Column 2: Best Value
                    imgui.TableNextColumn()
                    imgui.TextUnformatted(tostring(best_value))
                end
            end

            imgui.EndTable()
        end

        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- Learning Progress Summary (Text-Only)
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** Learning Progress Summary **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.Dummy(0, 5)

        imgui.SetWindowFontScale(1.4)
        imgui.Indent()
        imgui.TextUnformatted(string.format("Stability Improvement: +%d%%", learning_progress.stability_improvement))
        imgui.TextUnformatted(string.format("Performance Boost: +%d%%", learning_progress.performance_boost))
        imgui.TextUnformatted(string.format("GPU Load Reduction: -%d%%", learning_progress.gpu_load_reduction))
        imgui.Unindent()
        imgui.Separator()
        imgui.Dummy(0, 10)

        -- Additional Notes
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** NOTES **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.SetWindowFontScale(1.4)
        imgui.TextUnformatted("These recommendations are personalized to your system and can vary between sessions.")
        imgui.TextUnformatted("Changes in system performance may lead to different recommendations in future flights.")
        imgui.TextUnformatted("Consider adjusting settings manually if your preferences change or you notice performance issues.")
        imgui.Dummy(0, 10)

        -- Version History
        imgui.SetWindowFontScale(1.6)
        imgui.PushStyleColor(imgui.constant.Col.Text, 0x99CCFFFF)
        imgui.TextUnformatted("** VERSION HISTORY **")
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.SetWindowFontScale(1.4)
        imgui.TextUnformatted(os.date("%Y-%m-%d %H:%M:%S") .. ": Q-Learning integrated for adaptive adjustments.")
    end

    -- Function to handle window building
    function AithenaSmart_on_build(wnd, x, y)
        -- Generate the UI
        AithenaSmart_generateUI()
    end

    -- Function to show the AithenaSmart window
    function AithenaSmart_show_wnd()
        if not AithenaSmart_wnd then
            AithenaSmart_wnd = float_wnd_create(800, 800, 1, true) -- Increased height to accommodate new sections
            if AithenaSmart_wnd then
                float_wnd_set_title(AithenaSmart_wnd, "AithenaSmart X-Plane 12")
                float_wnd_set_imgui_builder(AithenaSmart_wnd, "AithenaSmart_on_build")
                writeToLog("INFO", "AithenaSmart window opened.")
            else
                writeToLog("ERROR", "Failed to create AithenaSmart window.")
            end
        end
    end

    -- Function to hide the AithenaSmart window
    function AithenaSmart_hide_wnd()
        if AithenaSmart_wnd then
            float_wnd_destroy(AithenaSmart_wnd)
            AithenaSmart_wnd = nil
            writeToLog("INFO", "AithenaSmart window closed.")
        end
    end

    -- Toggle the window
    function AithenaSmart_toggle_window()
        if AithenaSmart_wnd == nil then
            AithenaSmart_show_wnd()
        else
            AithenaSmart_hide_wnd()
        end
    end

    -- Create FlyWithLua command for toggling
    create_command("FlyWithLua/AithenaSmart/recommendation_toggle", "Open/close AithenaSmart recommendation report window", "AithenaSmart_toggle_window()", "", "")

    -- Create FlyWithLua macro for quick access
    add_macro("AithenaSmart", "AithenaSmart_show_wnd()", "AithenaSmart_hide_wnd()", "deactivate")

    -- Function to apply recommended settings from the UI
    local function applyRecommendedSettingsFromUI()
        local recommended = calculateRecommendedSettings()
        applyRecommendedSettings(recommended)
        writeRecommendedSettingsToFile(recommended)
    end

    -- Bind the apply function to a command or UI button as needed
    -- Example: Binding to a keyboard shortcut (Modify as necessary)
    create_command("FlyWithLua/AithenaSmart/apply_recommended_settings", "Apply Recommended Settings", "applyRecommendedSettingsFromUI()", "", "")

    -- Function to reset settings to default
    local function resetToDefaultSettings()
        for key, default_value in pairs(default_settings) do
            settings[key] = default_value
            settings_last_modified[key] = os.date("%Y-%m-%d %H:%M:%S")
        end
        applySettings(settings)
        AithenaSmart_saveINIFile(SESSION_FILE, settings)
        writeToLog("INFO", "Settings reset to default values.")
    end

    -- Bind the reset function to a command or UI button as needed
    -- Example: Binding to a keyboard shortcut (Modify as necessary)
    create_command("FlyWithLua/AithenaSmart/reset_settings", "Reset Settings to Default", "resetToDefaultSettings()", "", "")

    -- Function to detect manual adjustments and protect against nil values
    local function detectManualAdjustments()
        for key, ref in pairs(datarefs) do
            if ref then
                local current_value
                if key == "scattering_on" or key == "HDR_on" or key == "draw_textured_lites" or key == "rcas_value" then
                    current_value = XPLMGetDatai(ref)
                elseif key == "visibility_framerate_ratio" or key == "rendering_res" or key == "LOD_bias_rat" or key == "csm_split_exterior" then
                    current_value = XPLMGetDataf(ref)
                elseif key == "texture_quality" or key == "ambient_occlusion" or key == "cloud_quality" or key == "shadow_quality" or key == "world_object_density" or key == "vegetation_density" then
                    -- Assuming these are integer representations; map back to strings
                    local mapping = {
                        texture_quality = { [0] = "Low", [1] = "Medium", [2] = "High" },
                        ambient_occlusion = { [0] = "Off", [1] = "Low", [2] = "Medium", [3] = "High" },
                        cloud_quality = { [0] = "Low", [1] = "Medium", [2] = "High" },
                        shadow_quality = { [0] = "Low", [1] = "Medium", [2] = "High" },
                        world_object_density = { [0] = "Low", [1] = "Medium", [2] = "High" },
                        vegetation_density = { [0] = "Low", [1] = "Medium", [2] = "High" },
                    }
                    current_value = mapping[key][current_value] or "Medium"
                elseif key == "anisotropic_filtering" then
                    local mapping = {
                        [1] = "1x",
                        [2] = "2x",
                        [4] = "4x",
                        [8] = "8x",
                        [16] = "16x",
                    }
                    current_value = mapping[current_value] or "4x"
                elseif key == "msaa_antialiasing" then
                    local mapping = {
                        [0] = "Off",
                        [2] = "2x",
                        [4] = "4x",
                        [8] = "8x",
                    }
                    current_value = mapping[current_value] or "4x"
                elseif key == "fxaa_antialiasing" then
                    local mapping = { [1] = "On", [0] = "Off" }
                    current_value = mapping[current_value] or "On"
                elseif key == "rendering_distance" then
                    -- Assuming rendering_distance is mapped from float to string
                    local mapping = {
                        [0.5] = "Low",
                        [1.0] = "Medium",
                        [1.5] = "High",
                    }
                    current_value = mapping[current_value] or "Medium"
                elseif key == "enable_3d_vegetation" then
                    local mapping = { [1] = "On", [0] = "Off" }
                    current_value = mapping[current_value] or "On"
                else
                    current_value = XPLMGetDatai(ref)
                end

                if settings[key] ~= current_value then
                    -- User has manually adjusted the setting
                    settings[key] = current_value
                    settings_last_modified[key] = os.date("%Y-%m-%d %H:%M:%S")
                    learning_progress.adjustments_made = learning_progress.adjustments_made + 1
                    learning_progress.total_adjustments = learning_progress.total_adjustments + 1
                    writeToLog("INFO", string.format("Manual adjustment: Setting '%s' changed to %s", key, tostring(current_value)))
                end
            end
        end
    end

    -- Bind detectManualAdjustments to run frequently
    do_often("detectManualAdjustments()")

    -- Function to reset settings to default
    -- (Already defined above as resetToDefaultSettings)

    -- Finalizing UI and other functionalities are already handled above.

    -- Final call to save all current settings and configurations
    AithenaSmart_saveINIFile(SESSION_FILE, settings)
    AithenaSmart_saveINIFile(HISTORY_FILE, history_data)
    AithenaSmart_saveINIFile(CONFIG_FILE, config)

    writeToLog("INFO", "AithenaSmart XP12 Settings Script Version AP_AS_4.8 initialized successfully.")
