-- ============================================================================
-- vATC Sync Loader
-- Place this file in: X-Plane 12/Resources/plugins/FlyWithLua/Scripts/
-- Place vATC_sync folder in same location
-- ============================================================================

-- Load the main module
local script_dir = SCRIPT_DIRECTORY or debug.getinfo(1, "S").source:match("@(.*/)") or "./"
dofile(script_dir .. "vATC_sync/init.lua")

-- ============================================================================
-- CREATE COMMAND (Toggle status bar)
-- ============================================================================
create_command("FlyWithLua/vATCSync/toggle", "Toggle vATC Sync status bar", "vatc_sync_toggle_wnd()", "", "")
