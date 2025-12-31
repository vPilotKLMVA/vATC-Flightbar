-- vATC Sync - Configuration
local CONFIG = {
    callsign = "AUTO",
    poll_interval = 15,

    auto_tune_com1 = true,
    auto_set_squawk = true,

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

    data_file = "vatsim_data.json"
}

function CONFIG:get_data_path()
    return SCRIPT_DIRECTORY or "./"
end

return CONFIG
