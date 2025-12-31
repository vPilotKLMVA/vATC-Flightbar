-- vATC Sync - Version Info
local VERSION = {
    major = 1,
    minor = 3,
    patch = 6,
    build = "2025.12.31",

    get = function(self)
        return string.format("v%d.%d.%d", self.major, self.minor, self.patch)
    end,

    get_full = function(self)
        return string.format("v%d.%d.%d (%s)", self.major, self.minor, self.patch, self.build)
    end
}

return VERSION
