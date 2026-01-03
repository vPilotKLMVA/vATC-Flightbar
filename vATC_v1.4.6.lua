-- ============================================================================
-- vATC SYNC for X-Plane 12 - Main Loader
-- ============================================================================
--
-- Copyright (c) 2025 vPilot KLMVA
-- Licensed under the MIT License
-- GitHub: https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12
-- Forum: https://forums.x-plane.org/profile/422092-pilot-mcwillem/
--
-- This is the main loader file for vATC Sync.
-- FlyWithLua loads this file, which then loads the vATC_sync module.
--
-- ============================================================================

-- Load the main vATC_sync module
if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("vATC Sync: ERROR - Requires floating windows support (FlyWithLua NG)")
    return
end

if not SCRIPT_DIRECTORY then
    logMsg("vATC Sync: ERROR - SCRIPT_DIRECTORY not available")
    return
end

-- Load the init.lua from vATC_sync folder
local module_path = SCRIPT_DIRECTORY .. "vATC_sync/init.lua"
local f = io.open(module_path, "r")
if not f then
    logMsg("vATC Sync: ERROR - Cannot find " .. module_path)
    return
end
f:close()

-- Execute the module
local ok, err = pcall(dofile, module_path)
if not ok then
    logMsg("vATC Sync: ERROR loading module - " .. tostring(err))
else
    logMsg("vATC Sync: Main loader complete")
end
