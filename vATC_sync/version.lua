-- ============================================================================
-- vATC Sync - Version Info
-- ============================================================================
--
-- Copyright (c) 2025 vPilot KLMVA
-- Licensed under the MIT License
-- GitHub: https://github.com/vPilotKLMVA/vATC-Flightbar
--
-- ============================================================================

local VERSION = {
    major = 1,
    minor = 4,
    patch = 7,
    build = "2026.01.03",

    get = function(self)
        return string.format("v%d.%d.%d", self.major, self.minor, self.patch)
    end,

    get_full = function(self)
        return string.format("v%d.%d.%d (%s)", self.major, self.minor, self.patch, self.build)
    end
}

return VERSION
