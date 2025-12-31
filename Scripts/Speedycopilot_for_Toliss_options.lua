-- The New Speedy Copilot settings for the ToLiSs A319/A320/A321/A340-600

TL_The_PNF_delays_the_APU_on_departure = "activate"
-- The APU start can be postponed (usually to comply with environmental regulations) until before start flow. ACTIVATE is default.

TL_The_PNF_ovewrites_any_uplinked_THS = "deactivate"
-- The APU start can be postponed (usually to comply with environmental regulations) until before start flow. ACTIVATE is default.

TL_The_PNF_updates_the_MCDU = "activate"
-- The First Officer will set  theZFW and Takeoff flaps settings in the MCDU during the cockpit preparation flow.

TL_The_PNF_starts_the_APU_after_landing = "activate"
-- The PM starts the APU in his after landing flow. DEACTIVATE is default.

TL_The_PNF_releases_PARK_BRK_with_chocks = "activate"
-- Usually when chocks are in place, parking brake is released (FCOM 3.03.25). However, this is inactive by default because third-parties jetways will stay attached to the aircraft only if the parking brake is kept set. DEACTIVATE is default.

TL_FoTunesRadiosInPreparationFlow = "activate"
-- PM will set 122.800 on COM1 and COM2, or not.

TL_synchronizedFD = "activate"
-- The FO will keep his FD synchonized with the FD on Captain side.

TL_Low_pressure_air_requested_when_on_stand = "activate"
-- You can request a pre-conditionned air unit. Normally you coordinate via interphone so as to not have both the Packs and LP air providing the mixer  unit simultaneously. ACTIVATE is default.

Reduce_main_panel_lights = "activate"
-- Activating this will keep as set the main panel flood lights in approach and landing phases. DEACTIVATE is default.

Minimises_landing_lights = "activate"
-- Activating this will make the PM retract early the landing lights instead of waiting for FL100. ACTIVATE is default.

TL_Global_Say_Rotate = "activate"
-- Deactivate this will remove "rotate" PM call. ACTIVATE is default.

TL_Global_Say_Mins = "activate"
-- Deactivate this will remove "Minimums" PM call for Baro minimums (MDA / DA). DEACTIVATE is default.

TL_Check_yaw_during_flight_controls_check = "activate"
-- You can deactivate the yaw check if you do not have a rudder axis or if you want to ease the flight control process in the simulation. We recommand to let it activated here in the persistent option, and maybe deactivate it using the in-flight menu when temporary required. ACTIVATE is default.

TL_QuickGlance_option = "deactivate"
-- When active, when you look towards approach path and runway area or when you turn a landing light on, the PM starts the runway entry flow. When inactive, only the light will signal the runway entry to the PM. ACTIVATE is default.

TL_Cabin_on_unlock = "activate"
-- When active, the user can use the pedestal cabin lock mecanism to jump instantly to the cabin..

TL_prevent_wakeup_the_baby = "activate"
-- When active, the user will be force-switched to external view to avoid the lound master caution ring during APU and engine tests.

TL_online_transponder_option = "deactivate"
-- When active, transponder is kept OFF (it used to be an IVAO rule) during all taxi operations..

TL_Bottom_bar_has_solid_background = "deactivate"

TL_Use_GHD_airstairs_at_gate = "deactivate"
-- You will be serviced by the GHD airstairs when doors on the left are open. Turning that OFF is great for users who do not use third-party airstairs. DEACTIVATE is default.

TL_Use_GHD_airstairs_at_left_forw_door = "deactivate"
-- If a jetway is attached to the 1L door, native stairs can be removed at that door. ACTIVATE is default.

TL_Display_normal_messages = "activate"
-- With "activate" all text messages are displayed. Keeping this is higly recommanded. ACTIVATE is default.

TL_VR_message = "deactivate"
-- With "activate" text messages are displayed in a virtual reality compatible format in a popup window. DEACTIVATE is default.

TL_transfer_exterior_lights_to_the_PM_on_ground = "deactivate"
-- With "activate" the landing lights and strobe lights will be actuated by the PM on line-up clearance. 2021 Airbus procedures have normally transferred that action to the PF, therefore  DEACTIVATE is default.

TL_crew_preferred = "none"
-- Default is none : no crew is preferred. Everything is random then. Other options are UK and US.

-- -- Following option(s) are only edited by hand in this config file -- --
TL_Keep_secondary_sounds = "activate"
-- FlyWithLua has a limit of wave files. Deactivating this removes some flight attendants and passengers sounds. ACTIVATE is default.
-- That's a hidden option you cannot change through the in-game options panel. It's only kept on the off chance it can serve one day.


-- -- -- NOISE ABATEMENT PROCEDURE
-- NADP 2 (Noise Abatement Departure Procedure 2) is :
-- On reaching an altitude equivalent to at least 800 feet AGL (TL_thrust_reduction_altitude), decrease aircraft body angle whilst maintaining a positive rate of climb, accelerate towards Flaps Up speed and reduce thrust with the initiation of the first flaps/slats retraction or reduce thrust after flaps/slats retraction.
-- At 3000 feet AGL (TL_Accel_Altitude), accelerate to normal en-route climb speed.
TL_thrust_reduction_altitude = 1500 -- AGL
TL_Accel_Altitude = 1500
-- This can be edited by hand when X-Plane is not running. It is overwritten when X-Plane is running.
-- In flight, YOU MUST change options via the X-Plane menu.
-- Only two values are acceptable : "activate" or "deactivate".
