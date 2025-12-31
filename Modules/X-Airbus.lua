--[[
	X-Airbus Library
	FrankLFRS v1.4.1 2025
	Published release v1.4.1
	
	X-Airbus is a set of functions to easily handle ToLiss Airbus DataRef
	
	For ToLiss only
]]


-- Version

local Version = "v1.4.1"


-- Metatable X_Airbus

local X_Airbus = {}


-- ToLissDetected()

local ToLiss_Detected = false

function X_Airbus.ToLissDetected()
	return ToLiss_Detected
end


-- Log message

local function Log_Msg(Message)
	logMsg(string.format("X-Airbus Library: %s", Message))
end

Log_Msg(Version)


-- * * * ToLiss only * * *

if PLANE_ICAO == "A319" or PLANE_ICAO == "A20N" or PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339" then

ToLiss_Detected = true
Log_Msg(string.format("ToLiss aircraft detected (%s)", PLANE_ICAO))


-- IsNEO()

function X_Airbus.IsNEO()
	return PLANE_ICAO == "A20N" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A339"
end

Log_Msg("IsNEO")


-- OnGround(), Flying()

DataRef("_X_Airbus_On_Ground", "sim/flightmodel2/gear/on_ground")

function X_Airbus.OnGround()
	return _X_Airbus_On_Ground == 1
end

Log_Msg("OnGround")

function X_Airbus.Flying()
	return _X_Airbus_On_Ground == 0
end

Log_Msg("Flying")


-- EnginesRunning()

DataRef("_X_Airbus_Num_Engines", "sim/aircraft/engine/acf_num_engines")
DataRef("_X_Airbus_Engine1_Running", "sim/flightmodel/engine/ENGN_running", "readonly", 0)
DataRef("_X_Airbus_Engine2_Running", "sim/flightmodel/engine/ENGN_running", "readonly", 1)
DataRef("_X_Airbus_Engine3_Running", "sim/flightmodel/engine/ENGN_running", "readonly", 2)
DataRef("_X_Airbus_Engine4_Running", "sim/flightmodel/engine/ENGN_running", "readonly", 3)

function X_Airbus.EnginesRunning()
	if _X_Airbus_Num_Engines == 2 then
		return _X_Airbus_Engine1_Running == 1 and _X_Airbus_Engine2_Running == 1
	end
	if _X_Airbus_Num_Engines == 4 then
		return _X_Airbus_Engine1_Running == 1 and _X_Airbus_Engine2_Running == 1 and _X_Airbus_Engine3_Running == 1 and _X_Airbus_Engine4_Running == 1
	end
	return false
end

Log_Msg("EnginesRunning")


-- ParkBrake()

DataRef("_X_Airbus_ParkBrake", "AirbusFBW/ParkBrake")

function X_Airbus.ParkBrake()
	return _X_Airbus_ParkBrake == 1
end

Log_Msg("ParkBrake")


-- ThrottleInput()
-- 1.0 = TOGA, 0.88 = Flex, 0.7 = CL, 0.0 = Idle, -0.0 to -1,0 Reverses

DataRef("_X_Airbus_Throttle_Input", "AirbusFBW/throttle_input", "readonly", 4)

function X_Airbus.ThrottleInput()
	return _X_Airbus_Throttle_Input
end

Log_Msg("ThrottleInput")


-- ChronoTimeND(ND), ChronoTimeND()
-- ND = 1 or 2, void for max ND1 or ND2 time

DataRef("_X_Airbus_Chrono_Time_ND1", "AirbusFBW/ChronoTimeND1")
DataRef("_X_Airbus_Chrono_Time_ND2", "AirbusFBW/ChronoTimeND2")

function X_Airbus.ChronoTimeND(ND)
	if ND == 1 then return _X_Airbus_Chrono_Time_ND1 end
	if ND == 2 then return _X_Airbus_Chrono_Time_ND2 end
	if ND == nil then
		if _X_Airbus_Chrono_Time_ND1 > _X_Airbus_Chrono_Time_ND2 then
			return _X_Airbus_Chrono_Time_ND1
		else
			return _X_Airbus_Chrono_Time_ND2
		end
	end
	return 0
end

Log_Msg("ChronoTimeND")


-- Flaps()
-- 0 = flaps up, 1 = flaps 1, 2 = flaps 2, 3 = flaps 3, 4 = flaps full

DataRef("_X_Airbus_Flap_Lever_Ratio", "AirbusFBW/FlapLeverRatio")

function X_Airbus.Flaps()
	return math.floor((_X_Airbus_Flap_Lever_Ratio*4.0)+0.5)
end

Log_Msg("Flaps")


-- V1()

--[[
AirbusFBW/V1Value
toliss_airbus/pfdoutputs/general/VR_value
toliss_airbus/pfdoutputs/general/ap_speed_value
]]

DataRef("_X_Airbus_V1", "AirbusFBW/V1Value")

function X_Airbus.V1()
	return _X_Airbus_V1
end

Log_Msg("V1")


-- VR()

DataRef("_X_Airbus_VR", "toliss_airbus/pfdoutputs/general/VR_value")

function X_Airbus.VR()
	return _X_Airbus_VR
end

Log_Msg("VR")


-- IAS()

DataRef("_X_Airbus_IAS", "sim/flightmodel/position/indicated_airspeed")

function X_Airbus.IAS()
	return _X_Airbus_IAS
end

Log_Msg("IAS")


-- GS()

DataRef("_X_Airbus_GS", "sim/cockpit2/gauges/indicators/ground_speed_kt")

function X_Airbus.GS()
	return _X_Airbus_GS
end

Log_Msg("GS")


-- MSL()

DataRef("_X_Airbus_MSL", "sim/cockpit2/gauges/indicators/altitude_ft_pilot")

function X_Airbus.MSL()
	return _X_Airbus_MSL
end

Log_Msg("MSL")


-- AGL()

DataRef("_X_Airbus_AGL", "sim/flightmodel/position/y_agl")

function X_Airbus.AGL()
	return _X_Airbus_AGL/0.3048 -- m to ft
end

Log_Msg("AGL")


-- SpawnedMidair()

X_Airbus._SpawnedMidair = X_Airbus.AGL() > 500

function X_Airbus.SpawnedMidair()
	return X_Airbus._SpawnedMidair
end

Log_Msg("SpawnedMidair")


-- VS()

DataRef("_X_Airbus_VS", "toliss_airbus/pfdoutputs/captain/vertical_speed")

function X_Airbus.VS()
	return _X_Airbus_VS
end

Log_Msg("VS")


-- GearLeverDown(), GearLeverUp()

DataRef("_X_Airbus_Gear_Lever_Down", "AirbusFBW/GearLever")

function X_Airbus.GearLeverDown()
	return _X_Airbus_Gear_Lever_Down == 1
end

Log_Msg("GearLeverDown")

function X_Airbus.GearLeverUp()
	return _X_Airbus_Gear_Lever_Down == 0
end

Log_Msg("GearLeverUp")


-- ThrustRatingN1()
-- Expected N1 for takeoff (TOGA or FLEX)

DataRef("_X_Airbus_Thrust_Rating_N1", "AirbusFBW/THRRatingN1")

function X_Airbus.ThrustRatingN1()
	return _X_Airbus_Thrust_Rating_N1
end

Log_Msg("ThrustRatingN1")


-- EngineN1()

DataRef("_X_Airbus_Engine1_N1", "AirbusFBW/fmod/eng/N1Array", "readonly", 0)
DataRef("_X_Airbus_Engine2_N1", "AirbusFBW/fmod/eng/N1Array", "readonly", 1)
DataRef("_X_Airbus_Engine3_N1", "AirbusFBW/fmod/eng/N1Array", "readonly", 2)
DataRef("_X_Airbus_Engine4_N1", "AirbusFBW/fmod/eng/N1Array", "readonly", 3)

function X_Airbus.EngineN1()
	return math.max(_X_Airbus_Engine1_N1, _X_Airbus_Engine2_N1, _X_Airbus_Engine3_N1, _X_Airbus_Engine4_N1)
end

Log_Msg("EngineN1")


-- GroundSpoilers(), SpoilersArmed()

DataRef("_X_Airbus_Ground_Spoilers0", "AirbusFBW/SDSpoilerArray", "readonly", 0)
DataRef("_X_Airbus_Ground_Spoilers1", "AirbusFBW/SDSpoilerArray", "readonly", 1)
DataRef("_X_Airbus_Speedbrake_Ratio", "sim/cockpit2/controls/speedbrake_ratio")

function X_Airbus.GroundSpoilers()
	return _X_Airbus_Ground_Spoilers0 == 1 and _X_Airbus_Ground_Spoilers1 == 1
end

function X_Airbus.SpoilersArmed()
	return _X_Airbus_Speedbrake_Ratio == -0.5
end

Log_Msg("Spoilers")


-- EngineReverses()

DataRef("_X_Airbus_Engine_Reverses", "AirbusFBW/ENGRevArray", "readonly", 0)

function X_Airbus.EngineReverses()
	return _X_Airbus_Engine_Reverses == 2 -- 2 = fully deployed
end

Log_Msg("EngineReverses")


-- AutoBrakeLo(), AutoBrakeMed(), AutoBrakeMax(), AutoBrakeOn()

DataRef("_X_Airbus_Auto_Brake_LO", "AirbusFBW/AutoBrkLo")
DataRef("_X_Airbus_Auto_Brake_MED", "AirbusFBW/AutoBrkMed")
DataRef("_X_Airbus_Auto_Brake_MAX", "AirbusFBW/AutoBrkMax")

function X_Airbus.AutoBrakeLo()
	return _X_Airbus_Auto_Brake_LO ~= 0
end

function X_Airbus.AutoBrakeMed()
	return _X_Airbus_Auto_Brake_MED ~= 0
end

function X_Airbus.AutoBrakeMax()
	return _X_Airbus_Auto_Brake_MAX ~= 0
end

function X_Airbus.AutoBrakeOn()
	return _X_Airbus_Auto_Brake_LO == 2 or _X_Airbus_Auto_Brake_MED == 2 or _X_Airbus_Auto_Brake_MAX == 2
end

Log_Msg("AutoBrake")


-- ViewInside(), ViewExterior()

DataRef("_X_Airbus_View_External", "sim/graphics/view/view_is_external")

function X_Airbus.ViewInside()
	return _X_Airbus_View_External == 0
end

function X_Airbus.ViewExterior()
	return _X_Airbus_View_External == 1
end

Log_Msg("Views")


-- APUAvailable(), APUMaster(), APUStarter(), APUBleed(), APUFlapOpenRatio()

DataRef("_X_Airbus_APU_Available", "AirbusFBW/APUAvail")
DataRef("_X_Airbus_APU_Master", "AirbusFBW/APUMaster")
DataRef("_X_Airbus_APU_Starter", "AirbusFBW/APUStarter")
DataRef("_X_Airbus_APU_Bleed", "AirbusFBW/APUBleedSwitch")
DataRef("_X_Airbus_APU_Flap_Open_Ratio", "AirbusFBW/APUFlapOpenRatio") 

function X_Airbus.APUAvailable()
	return _X_Airbus_APU_Available == 1
end

function X_Airbus.APUMaster()
	return _X_Airbus_APU_Master == 1
end

function X_Airbus.APUStarter()
	return _X_Airbus_APU_Starter == 1
end

function X_Airbus.APUBleed()
	return _X_Airbus_APU_Bleed == 1
end

function X_Airbus.APUFlapOpenRatio()
	return _X_Airbus_APU_Flap_Open_Ratio
end

Log_Msg("APU")


-- LeftWiperSpeed(), RightWiperSpeed()
-- 0 = off, 1 = slow, 2 = fast

DataRef("_X_Airbus_Left_Wiper_Speed", "AirbusFBW/LeftWiperSwitch") 
DataRef("_X_Airbus_Right_Wiper_Speed", "AirbusFBW/RightWiperSwitch")

function X_Airbus.LeftWiperSpeed()
	return _X_Airbus_Left_Wiper_Speed
end

function X_Airbus.RightWiperSpeed()
	return _X_Airbus_Right_Wiper_Speed
end

Log_Msg("WiperSpeed")


-- PrecipitationRatio()
-- 0.0 = 0% to 1.0 = 100% rain

DataRef("_X_Airbus_Precipitation_Ratio", "sim/weather/aircraft/precipitation_on_aircraft_ratio")

function X_Airbus.PrecipitationRatio()
	return _X_Airbus_Precipitation_Ratio
end

Log_Msg("PrecipitationRatio")


-- NWSAngle()

DataRef("_X_Airbus_NWS_Angle", "AirbusFBW/NoseWheelSteeringAngle")

function X_Airbus.NWSAngle()
	return _X_Airbus_NWS_Angle
end

Log_Msg("NWSAngle")


-- APPROn()

DataRef("_X_Airbus_APPR_On", "AirbusFBW/APPRilluminated")

function X_Airbus.APPROn()
	return _X_Airbus_APPR_On == 1
end

Log_Msg("APPROn")


-- EngineMode()
-- 0 = crank, 1 = norm, 2 = ignition

DataRef("_X_Airbus_Engine_Mode", "AirbusFBW/ENGModeSwitch")

function X_Airbus.EngineMode()
	return _X_Airbus_Engine_Mode
end

Log_Msg("EngineMode")


-- EnginesInletIce()
-- You should have a warning above 0.025

DataRef("_X_Airbus_Engine1_Inlet_Ice", "sim/flightmodel/failures/inlet_ice_per_engine", "readonly", 0)
DataRef("_X_Airbus_Engine2_Inlet_Ice", "sim/flightmodel/failures/inlet_ice_per_engine", "readonly", 1)
DataRef("_X_Airbus_Engine3_Inlet_Ice", "sim/flightmodel/failures/inlet_ice_per_engine", "readonly", 2)
DataRef("_X_Airbus_Engine4_Inlet_Ice", "sim/flightmodel/failures/inlet_ice_per_engine", "readonly", 3)

function X_Airbus.EnginesInletIce()
	return math.max(_X_Airbus_Engine1_Inlet_Ice, _X_Airbus_Engine2_Inlet_Ice, _X_Airbus_Engine3_Inlet_Ice, _X_Airbus_Engine4_Inlet_Ice)
end

Log_Msg("EnginesInletIce")


-- Loaded

Log_Msg("Library loaded")


-- * * * ToLiSS only * * *

else
	Log_Msg(string.format("ToLiss aircraft not detected (%s)", PLANE_ICAO))
end


-- Return X_Airbus

return X_Airbus
