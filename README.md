# vATC Sync for X-Plane 12

[![Version](https://img.shields.io/badge/version-1.4.5-blue.svg)](https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![X-Plane](https://img.shields.io/badge/X--Plane-12-orange.svg)](https://www.x-plane.com/)

**vATC Sync** is a FlyWithLua script for X-Plane 12 that provides real-time VATSIM integration with SimBrief flight planning, displaying critical flight information in an elegant status bar.

## Features

- 🎯 **Real-time VATSIM Data**: Live ATC frequencies, controllers, and coverage areas
- 📋 **SimBrief Integration**: Automatic flight plan import from SimBrief
- 📡 **Auto-Tune COM1**: Automatically tune to active ATC frequencies
- 🔢 **Auto-Set Squawk**: Set transponder code from flight plan
- 🌍 **Flight Progress Tracking**: Departure, cruise, and arrival information
- 🎨 **Color-Coded Status**: Visual feedback for different flight phases
- ⚙️ **Customizable Settings**: Configure behavior through ImGui interface
- 📊 **Comprehensive Logging**: Debug and monitor script activity

## Requirements

### Software
- **X-Plane 12** (any version)
- **FlyWithLua NG+** (Next Generation Plus Edition)
  - Download: [FlyWithLua NG+ for X-Plane 12](https://forums.x-plane.org/files/file/82888-flywithlua-ng-next-generation-plus-edition-for-x-plane-12-win-lin-mac/)
  - Required for ImGui support and floating windows
- **PowerShell** (Windows) or **pwsh** (macOS/Linux)

### FlyWithLua Modules (Included)
- `dkjson` - JSON parsing
- `luasocket` - HTTP requests

## Installation

**Quick Start:**
1. **Install FlyWithLua NG+**
   - Download from [X-Plane.org](https://forums.x-plane.org/files/file/82888-flywithlua-ng-next-generation-plus-edition-for-x-plane-12-win-lin-mac/)
   - Extract to `X-Plane 12/Resources/plugins/`
2. **Install vATC Sync**
   - Copy `vATC_sync/` folder to `FlyWithLua/Scripts/`
   - Copy `vATC_v1.4.5.lua` to `FlyWithLua/Scripts/`
3. **Configure SimBrief**
   - Start X-Plane and open vATC Settings
   - Enter your SimBrief Pilot ID
4. **Restart X-Plane**

## Usage

The status bar appears automatically at the top of your screen. Access settings through the FlyWithLua macro menu.

### Status Bar Sections

| Section | Information |
|---------|-------------|
| **Departure** | DEP, Callsign, ATC, Freq, Gate, SID, RWY, SQWK, QNH, TA/RA, ETD, Dist |
| **Cruise** | FIR, Next waypoint, Distance to go |
| **Arrival** | ATC, ETA, QNH, Temp, Wind, STAR, APP, ARR |

## Configuration

Open settings window via FlyWithLua macro menu:
- SimBrief Pilot ID
- Show/hide header row
- Auto-tune COM1
- Auto-set squawk
- Auto-fetch SimBrief

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Bar not appearing | Check FlyWithLua installation and X-Plane Log.txt |
| VATSIM data not updating | Verify PowerShell installation and internet connection |
| SimBrief not loading | Check Pilot ID and OFP availability |

See [Troubleshooting Guide](Documentation/TROUBLESHOOTING.md) for details.

## Abbreviations

- **ATC**: Air Traffic Control
- **ETD/ETA**: Estimated Time Departure/Arrival
- **FIR**: Flight Information Region
- **OFP**: Operational Flight Plan
- **QNH**: Altimeter pressure setting
- **SID/STAR**: Standard Instrument Departure/Arrival
- **VATSIM**: Virtual Air Traffic Simulation Network

## Support

- **Forum**: [X-Plane.org Profile](https://forums.x-plane.org/profile/422092-pilot-mcwillem/)
- **GitHub**: [Issues & Features](https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12/issues)
- **FlyWithLua NG+**: [Download Plugin](https://forums.x-plane.org/files/file/82888-flywithlua-ng-next-generation-plus-edition-for-x-plane-12-win-lin-mac/)

## License

MIT License - Copyright (c) 2025 vPilot KLMVA

See [LICENSE](LICENSE) file for full text.

## Credits

- **Author**: vPilot KLMVA
- **FlyWithLua**: Carsten Lynker
- **VATSIM Network**
- **SimBrief Dispatch Services**

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

**Made with ❤️ for the flight simulation community**

GitHub: https://github.com/vPilotKLMVA/-LuaScripts-for-X-Plane-12
