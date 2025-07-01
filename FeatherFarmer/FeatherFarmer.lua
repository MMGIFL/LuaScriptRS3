--[[
@title Feather Farmer
@author Erekyu
@version 1.5

* Start this script in a chicken pen
* The script will automatically attack chickens.
* It will only loot Feathers and Bones.
* It will automatically bury any bones it picks up before fighting the next chicken.
* Make sure you have a weapon equipped.
--]]

local API = require('api')

-- ===================================================================
-- SCRIPT CONFIGURATION
-- ===================================================================
local config = {
    -- A list of NPC IDs for Chickens. This list covers most common chicken types.
    CHICKEN_IDS = { 41, 6333, 10178, 1017 }, 

    -- Item IDs for the loot we want
    BONES_ID = 526,
    FEATHER_ID = 314,

    -- The maximum distance to look for chickens and loot
    SEARCH_DISTANCE = 30,
}

-- ===================================================================
-- SCRIPT SETUP (No changes needed below)
-- ===================================================================

local STATES = {
    IDLE = "Idle",
    FIGHTING = "Fighting",
    LOOTING = "Looting",
    BURYING = "Burying"
}

local current_task = STATES.IDLE
local lastTargetId = nil

API.SetDrawTrackedSkills(true)

local function findNextChicken()
    print("Searching for a new chicken to attack...")
    local allChickens = API.GetAllObjArrayInteract(config.CHICKEN_IDS, config.SEARCH_DISTANCE, {1})
    
    if not allChickens or #allChickens == 0 then
        return nil
    end

    for _, chicken in ipairs(allChickens) do
        local isAttackable = (chicken.Health == nil or chicken.Health > 0)
        
        if isAttackable then
            return chicken
        end
    end
    
    return nil
end

local function findLoot()
    print("Searching for loot...")
    local lootToGet = { config.BONES_ID, config.FEATHER_ID }
    local lootOnGround = API.GetAllObjArray1(lootToGet, config.SEARCH_DISTANCE, {3})
    
    if #lootOnGround > 0 then
        return lootOnGround[1]
    end
    
    return nil
end

local function buryBones()
    print("Burying bones...")
    if API.DoAction_Inventory1(config.BONES_ID, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        API.RandomSleep2(800, 200, 300)
        return true
    end
    return false
end

print("Feather Farmer. Ensure you are in a chicken pen.")

while API.Read_LoopyLoop() do
    
    if API.GetGameState2() ~= 3 or not API.PlayerLoggedIn() then
        print("Bad game state, exiting.")
        break
    end

    if current_task == STATES.IDLE then
        if API.InvItemFound1(config.BONES_ID) then
            current_task = STATES.BURYING
        else
            local loot = findLoot()
            if loot then
                current_task = STATES.LOOTING
            elseif API.LocalPlayer_IsInCombat_() then
                print("Already in combat, switching to fighting state to wait it out.")
                current_task = STATES.FIGHTING
            else
                local chicken = findNextChicken()
                if chicken then
                    print("Found chicken. Attacking...")
                    API.DoAction_NPC(0x2e, API.OFF_ACT_AttackNPC_route, { chicken.Id }, config.SEARCH_DISTANCE)
                    lastTargetId = chicken.Id
                    current_task = STATES.FIGHTING
                    API.RandomSleep2(1000, 300, 500)
                else
                    print("No chickens available. Waiting...")
                    API.RandomSleep2(2000, 500, 500)
                end
            end
        end

    elseif current_task == STATES.FIGHTING then
        if not API.LocalPlayer_IsInCombat_() then
            print("Target defeated. Looking for loot.")
            current_task = STATES.LOOTING
            lastTargetId = nil
            API.RandomSleep2(1000, 200, 400)
        end

    elseif current_task == STATES.LOOTING then
        local lootItem = findLoot()
        if lootItem then
            print("Looting " .. lootItem.Name)
            API.DoAction_G_Items_Direct(0x3e, API.OFF_ACT_Pickup_route, lootItem)
            API.RandomSleep2(800, 200, 300)
            current_task = STATES.IDLE 
        else
            print("No more loot found.")
            current_task = STATES.IDLE
        end

    elseif current_task == STATES.BURYING then
        if not buryBones() then
            print("Finished burying or no bones left.")
            current_task = STATES.IDLE
        end
    end
    
    API.RandomSleep2(200, 100, 200)
end
