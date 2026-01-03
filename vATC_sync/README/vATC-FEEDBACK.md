local VERSION = {

    major = 1,

    minor = 4,

    patch = 0,

    build = "2026.01.01",

=============================================================== User feedback

=====================================================================================================================================

### **IMPROVE**

1. \- Bar  
   must be appear always on top >
   remove floatwindow drwa3 but imgui floatwindow  no borders (not depend on system 32
2. \- Macro Menu FWL
   create menu vATC\_sync > then floating window with imgui  	filed with     checkbox inputfield or and txt info whatever we need
3. OFP need auto detect latest ofp witrh our as whe disccused priority
4. refresh realtime 
5. dynamic font size when bar winso is increase or decrease fo better ( is change
   



#### \- ADD

1. changelog.md file also the changelog voor latest en all previous versions
2. readme.md whit all info about de lua script for users
   such as ; install, neede environ, an HOW TO?
   license
3. creat setting flowatindow options coller or waht is primary usefull
   



\- maken main haeder copyrwrite vPilot, gtihub, licen

\- add readme file foot installing en configuration



#### -CHANGE

\- TXT formt to .md

1.  add bar collum with actual metar voor segmet departure behind QNH
2. header  after aFIR; add nFIR sFL = step nxt stepclimb if available or  default crz ofp fl
   



#### -REQUEST

1. create small alarm beep when data change in bar.
2. create alarm when data not macth with xplm aircraft
3. add bar collum with actual metar voor segmet departure behind Qnh
4. if exist in ofp.xlm set nxt sclb (step CLIMB 
5. make mainhaeder copyrwrite vPilot, gtihub, license
6. add readme file for installing en configuration other user explained avabraitons etc listed, add soluiton, licnece en copyricht files, GITHUB REPO PAKAGES AND https://forums.x-plane.org/profile/422092-pilot-mcwillem

   
7. \- USE possible XPLM integration voor dat in bar when off line



&nbsp;```lua

&nbsp;	-- find the right lib to load

&nbsp;			local XPLMlib = ""

&nbsp;			if SYSTEM == "IBM" then

&nbsp;				-- Windows OS (no path and file extension needed)

&nbsp;				XPLMlib = "XPLM\_64"  -- 64bit

&nbsp;			elseif SYSTEM == "LIN" then

&nbsp;				-- Linux OS (we need the path "Resources/plugins/" here for some reason)

&nbsp;				XPLMlib = "Resources/plugins/XPLM\_64.so"  -- 64bit

&nbsp;			elseif SYSTEM == "APL" then

&nbsp;				-- Mac OS (we need the path "Resources/plugins/" here for some reason)

&nbsp;				XPLMlib = "Resources/plugins/XPLM.framework/XPLM" -- 64bit and 32 bit

&nbsp;			else

&nbsp;				return -- this should not happen

&nbsp;			end

```





























 			local ffi = require ("ffi")



 			-- find the right lib to load

 			local XPLMlib = ""

 			if SYSTEM == "IBM" then

 				-- Windows OS (no path and file extension needed)

 				XPLMlib = "XPLM\_64"  -- 64bit

 			elseif SYSTEM == "LIN" then

 				-- Linux OS (we need the path "Resources/plugins/" here for some reason)

 				XPLMlib = "Resources/plugins/XPLM\_64.so"  -- 64bit

 			elseif SYSTEM == "APL" then

 				-- Mac OS (we need the path "Resources/plugins/" here for some reason)

 				XPLMlib = "Resources/plugins/XPLM.framework/XPLM" -- 64bit and 32 bit

 			else

 				return -- this should not happen

 			end



 			-- load the lib and store in local variable

 			local XPLM = ffi.load(XPLMlib)



 			-- create declarations of C types

 			local cdefs = \[\[

 			  typedef void \*XPLMDataRef;

 			  XPLMDataRef XPLMFindDataRef(const char \*inDataRefName);

 			  int  XPLMGetDatab(XPLMDataRef          inDataRef,

 								 void \*               outValue,    /\* Can be NULL \*/

 								 int                  inOffset,

 								 int                  inMaxBytes);

 			]]   -- this is only kept for the VR part.



 			-- add these types to the FFI:

 			ffi.cdef(cdefs)

 			-- telling which aircraft is pax, which is cargo :

 			AircraftSimPath = "PlaceHolder"

 			-- Access to acf\_livery\_path



 			-- added 19th november 2023 :

 			-- dataref("AircraftPath","sim/aircraft/view/acf\_livery\_path","readonly",0)

 			-- https://forums.x-plane.org/index.php?/forums/topic/296938-with-1208-beta-12-mapping-simaircraftviewacf\_livery\_path-sends-fwl-into-an-internal-loop/\&page=2#comment-2633523

 			-- If you followed the discussion in the FWL forum you may have noticed that this particular dataref is not the best candidate for retrieval through the "modern"  FWL dataref interface.

 			-- With the attached code snippet it can be retrieved when needed through the ffi interface and that may be a more future proof solution.

 			local acf\_livery\_path\_dr = ffi.new("XPLMDataRef")

 			local acf\_livery\_path\_dr = XPLM.XPLMFindDataRef("sim/aircraft/view/acf\_livery\_path");

 			local buffer  = ffi.new("char\[256]")

 			local n = XPLM.XPLMGetDatab(acf\_livery\_path\_dr, buffer, 0, 255)

 			AircraftSimPath = ffi.string(buffer)

 			-- let's try to see if it is a P2F aircraft if the word "P2F" can be found in the simulator path.

 			if AircraftSimPath:match("P2F") or AircraftSimPath:match("freighter") or AircraftSimPath:match("Freighter") or AircraftSimPath:match("cargo") then AircraftIsP2F = 1 GUI\_AircraftIsP2F = true MuteCabinRelatedSounds = 1 GUI\_MuteCabinRelatedSounds = true else AircraftIsP2F = 0 GUI\_AircraftIsP2F = false MuteCabinRelatedSounds = 0 GUI\_MuteCabinRelatedSounds = false end -- contains cargo if cargo is in the livery



 			--dataref("target\_alt", "sim/cockpit/autopilot/altitude", "readonly")

 			target\_alt = FCUaltitude -- init

 			-- special init for PilotHead

 			PilotHead = 0 -- prevent external view when WRITABLE, let it readonly

 			dataref("PilotHead", "sim/graphics/view/pilots\_head\_psi", "readonly")

 			print("====== Datarefs loaded ==============================================")



 		end -- end of DatarefLoad function only activated when the API is ready by chronometer

 		DatarefLoad() -- LOAD THAT IMMEDIATELY !  BECAUSE USERS FAIL TO HAVE  if SC\_altitudeAGL < AGL\_onGround and SC\_speed < 30 and SC\_Eng1N1 < 10  and SC\_Eng2N1 < 10 then running OK.



 		--########################################

 		--# INITIAL COMMANDS                     #

 		--########################################

