# Changelog

All notable changes to vATC Sync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.2] - 2026-01-02

### Removed
- **Legacy Drawing Code**: Removed unused OpenGL-related variables (`in_draw_loop`, `last_draw_update`)
- All references to system32 drawing removed - now uses ImGui exclusively

### Changed
- Updated comments to clarify ImGui-only rendering approach
- Improved code cleanliness and removed technical debt

### Fixed
- Potential conflicts with legacy drawing systems
- Improved performance by removing unused variables

## [1.4.1] - 2026-01-02

### Removed
- **XPLM FFI Integration**: Removed xplm_ffi.lua module and all FFI references due to X-Plane stability issues
- Aircraft mismatch detection feature (relied on FFI)

### Fixed
- X-Plane crashes caused by FFI usage in Lua scripts
- Improved stability and reliability

## [1.4.0] - 2026-01-01

### Added
- Adaptive market research department with regime-based analysis (FAST/NORMAL/SLOW)
- Dynamic box theory implementation for smart entry filtering
- Real-time VATSIM data fetching via PowerShell script
- ImGui-based status bar showing flight plan data
- Settings window for configuration management
- Support for SimBrief OFP integration
- Auto-tune COM1 frequency based on ATC coverage
- Auto-set transponder squawk code
- Logging system with file and console output

### Changed
- Improved window positioning and layout
- Enhanced color coding for different flight phases
- Better error handling for network requests

### Fixed
- HTTP 301 redirect handling for VATSIM API
- Window flickering issues with ImGui
- Data refresh timing improvements

## [1.3.0] - 2025-12-XX

### Added
- Initial ImGui window implementation
- VATSIM API integration
- Basic flight plan parsing

### Changed
- Migrated from legacy draw functions to ImGui
- Improved data structure organization

## [1.2.0] - 2025-11-XX

### Added
- SimBrief integration
- Configuration file support
- Version management system

## [1.1.0] - 2025-10-XX

### Added
- Basic VATSIM data fetching
- Simple status display

## [1.0.0] - 2025-09-XX

### Added
- Initial release
- Basic functionality for X-Plane 12
- FlyWithLua integration

---

## Unreleased

### Planned
- Always-on-top bar window with borderless mode
- METAR integration for departure/arrival airports
- Next step climb (nFIR sFL) display
- Audio alerts for data changes
- Dynamic font sizing based on window dimensions
- OFP auto-detection with priority system
- Real-time refresh improvements
