--[[
@title Manure Turner
@author Erekyu
@description Turns manure mounds continuously.
--]]

-- ===================================================================
--    DEPENDENCIES  
-- ===================================================================
local API = require("api")
local Slib = require("slib") 

-- ===================================================================
--    CONFIGURATION 
-- ===================================================================

local MANURE_MOUND_NAME = "Manure mound"
local INTERACT_ACTION = "Turn"
local INTERACT_RANGE = 15
local TIRED_MESSAGE = "You tire yourself out and so you take a break from turning the manure."

print("Manure Turner script started.")

-- ===================================================================
--    MAIN LOOP     
-- ===================================================================

local isTurningManure = false

while API.Read_LoopyLoop() do
    
    local manureMound = nil
    local isPlayerTired = false

    manureMound = API.GetAllObjArrayFirst({MANURE_MOUND_NAME}, INTERACT_RANGE, {0, 12})
    if not manureMound then
        print("Could not find '" .. MANURE_MOUND_NAME .. "' within " .. INTERACT_RANGE .. " tiles. Stopping script.")
        API.Write_LoopyLoop(false)
        goto continue
    end
    isPlayerTired = Slib:RecentMessageCheck(TIRED_MESSAGE)

    if isPlayerTired then
        print("Tired message detected. Will re-interact on the next cycle.")
        isTurningManure = false
        API.RandomSleep2(1500, 500, 300) 
    end

    if not isTurningManure then
        print("Player is idle. Interacting with the mound to start turning.")
        
        Interact:Object(MANURE_MOUND_NAME, INTERACT_ACTION, INTERACT_RANGE)
        
        isTurningManure = true
        
        API.RandomSleep2(2000, 500, 300) 
    else
        print("Player is busy turning manure. Waiting for 'tired' message.")
    end

    ::continue::
    API.RandomSleep2(500, 200, 100) 
end

print("Manure Turner script has finished.")

