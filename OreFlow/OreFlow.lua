--[[
@title OreFlow
@author Erekyu
@version 2.5 

* Start script near rocks and a banking object.
* A single menu will appear.
* OPTIONAL: Click a banking object first to set it manually.
* REQUIRED: Click an ore to start the script. If no bank was chosen, the closest will be used.

This is a modified version of Spade Miner, the original can be found here: https://github.com/spadeorsp8/spade_scripts/blob/main/spadeMiner.lua
--]]

local API = require('api')

local MAX_IDLE_TIME_MINUTES = 10
local POTIONS = { 32769, 32771, 32773, 32775 }
local HIGHLIGHTS = { 7164, 7165 }
local PORTERS = { 51490, 29285, 29283, 29281, 29279, 29277, 29275 }
local menu = API.CreateIG_answer()
local imguiBackground = API.CreateIG_answer()

local config_banking = {
    BANKING_OBJECT_NAMES = { "Furnace", "Anvil", "Forge" }, 
    BANK_SEARCH_RANGE = 150,
    FURNACE_REACH_DISTANCE = 7,
    RETURN_REACH_DISTANCE = 8
}

local selectedBankingObject_Name = nil
local selectedRock = nil
local mining_spot_tile = nil
local script_started = false
local has_manually_selected_bank = false

local current_task = "mining"
local clickedRockId = nil
local clickedRockTile = nil

API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)

local function setupMenu()
    local combinedList = {}
    
    local bankingObjectsFound = {}
    local bankingSearchResults = API.GetAllObjArrayInteract_str(config_banking.BANKING_OBJECT_NAMES, config_banking.BANK_SEARCH_RANGE, {0,12})
    for _, o in ipairs(bankingSearchResults) do
        if not bankingObjectsFound[o.Name] then
            table.insert(combinedList, o.Name)
            bankingObjectsFound[o.Name] = true
        end
    end
    
    if #combinedList > 0 then
        table.insert(combinedList, "-------------------------------")
    end
    
    local oreObjectsFound = {}
    local oreSearchResults = API.ReadAllObjectsArray({0, 12}, {-1}, {})
    for _, o in ipairs(oreSearchResults) do
        if o.Name and (string.find(o.Name, 'rock') or o.Name == 'Seren stone') and o.Distance <= 50 then
            if not oreObjectsFound[o.Name] then
                table.insert(combinedList, o.Name)
                oreObjectsFound[o.Name] = true
            end
        end
    end

    imguiBackground.box_name = "imguiBackground"
    imguiBackground.box_start = FFPOINT.new(1, 60, 0)
    imguiBackground.box_size = FFPOINT.new(400, 100, 0)
    imguiBackground.colour = ImColor.new(10, 13, 29)

    menu.box_name = "OreFlow Setup"
    menu.box_start = FFPOINT.new(1, 60, 0)
    menu.box_size = FFPOINT.new(400, 0, 0)
    menu.stringsArr = combinedList
    menu.colour = ImColor.new(10, 13, 29)
end

local function isBankingObject(name)
    for _, bankName in ipairs(config_banking.BANKING_OBJECT_NAMES) do
        if name == bankName then
            return true
        end
    end
    return false
end

local function getPorter()
    local porterId = nil; for _, id in ipairs(PORTERS) do if API.InvItemcount_1(id) > 0 then porterId = id; break end end; return porterId
end
local function chargeGOTE()
    local buffStatus = API.Buffbar_GetIDstatus(51490, false); local stacks = tonumber(buffStatus.text); if not buffStatus.found then stacks = 0 end; local porterId = getPorter(); if porterId and stacks and stacks <= 50 then print ("Recharging GOTE"); API.DoAction_Ability("Grace of the elves", 5, API.OFF_ACT_GeneralInterface_route); API.RandomSleep2(500, 250, 500) end
end
local function takeMiningPot()
    if API.Buffbar_GetIDstatus(32773).conv_text > 1 then return end; for _, pot in ipairs(POTIONS) do if API.InvItemcount_1(pot) > 0 then print("Drinking potion!"); API.DoAction_Inventory1(pot, 0, 1, API.OFF_ACT_GeneralInterface_route); break end end
end
local function getShinyRock(rocks, maxDistance)
    local shinyRock = nil; local shortestDist = maxDistance; for _, rock in ipairs(rocks) do for _, hl in ipairs(API.GetAllObjArray1(HIGHLIGHTS, maxDistance, {4})) do if API.Math_DistanceF(rock.Tile_XYZ, hl.Tile_XYZ) < shortestDist then shinyRock = rock; shortestDist = API.Math_DistanceF(rock.Tile_XYZ, hl.Tile_XYZ) end end end; return shinyRock
end
local function getProgress(samples)
    local samples = samples or 1; local max = 0; for i = 1, samples do local progress = API.LocalPlayer_HoverProgress(); if progress > max then max = progress end; API.RandomSleep2(250, 0, 0) end; return max
end

local function doFurnaceBanking()
    print("Inventory is full. Using banking object: " .. selectedBankingObject_Name)
    local banking_object = API.GetAllObjArrayInteract_str({selectedBankingObject_Name}, config_banking.BANK_SEARCH_RANGE, {0,12})[1]
    if not banking_object then print("Could not find the selected banking object '" .. selectedBankingObject_Name .. "'. Stopping script."); return false end
    print("Walking to " .. banking_object.Name .. "...")
    local timeout = 0
    while banking_object and banking_object.Distance > config_banking.FURNACE_REACH_DISTANCE and timeout < 20 do
        if not API.ReadPlayerMovin2() then API.DoAction_Object1(0x3f, API.OFF_ACT_GeneralObject_route0, { banking_object.Id }, 50) end
        API.RandomSleep2(1000, 250, 500)
        banking_object = API.GetAllObjArrayInteract_str({selectedBankingObject_Name}, config_banking.BANK_SEARCH_RANGE, {0,12})[1]
        timeout = timeout + 1
    end
    if not banking_object or timeout >= 20 then print("Failed to reach banking object, timed out."); return false end
    print("Arrived at " .. banking_object.Name)
    print("Depositing ores into metal bank...")
    API.DoAction_Object1(0x29, 80, { banking_object.Id }, 50)
    API.RandomSleep2(1500, 500, 1000)
    print("Returning to saved mining location...")
    if not mining_spot_tile then print("Mining spot location was not saved! Cannot return."); return false end
    local return_point = WPOINT.new(mining_spot_tile.x, mining_spot_tile.y, mining_spot_tile.z)
    API.DoAction_Tile(return_point)
    API.RandomSleep2(1000, 500, 1000)
    while API.ReadPlayerMovin2() do API.RandomSleep2(250, 100, 100) end
    print("Returned to mining spot. Resuming.")
    current_task = "mining"
    clickedRockId = nil; clickedRockTile = nil
    return true
end

setupMenu()

while API.Read_LoopyLoop() do

    if not script_started then
        API.DrawSquareFilled(imguiBackground)
        API.DrawComboBox(menu, false)

        if menu.return_click then
            menu.return_click = false
            local choice = menu.string_value

            if isBankingObject(choice) then
                selectedBankingObject_Name = choice
                has_manually_selected_bank = true
                print("Manual banking object selected: " .. selectedBankingObject_Name)
                print("Please now select an ore to begin.")

            elseif string.find(choice, "---") then
            
            else
                selectedRock = choice
                print("Ore selected: " .. selectedRock)

                if not has_manually_selected_bank then
                    local default_bank = API.GetAllObjArrayInteract_str(config_banking.BANKING_OBJECT_NAMES, config_banking.BANK_SEARCH_RANGE, {0,12})[1]
                    if default_bank then
                        selectedBankingObject_Name = default_bank.Name
                        print("No bank manually selected. Defaulting to closest: " .. selectedBankingObject_Name)
                    else
                        print("Could not find a default banking object! Stopping script.")
                        API.Write_LoopyLoop(false); break
                    end
                end

                local nearbyRocks = API.GetAllObjArrayInteract_str({ selectedRock }, 50, { 0, 12 })
                if nearbyRocks and #nearbyRocks > 0 then
                    mining_spot_tile = nearbyRocks[1].Tile_XYZ
                    print("Mining location saved. Starting script!")
                    script_started = true
                else
                    print("Could not find '"..selectedRock.."' nearby to save location! Please restart script closer to the rocks.")
                    API.Write_LoopyLoop(false); break
                end
            end
        end

    else
        if API.GetGameState2() ~= 3 or not API.PlayerLoggedIn() then print("Bad game state, exiting."); break end
        API.DoRandomEvents()
        takeMiningPot()
        chargeGOTE()
        
        if current_task == "mining" then
            if API.InvFull_() then
                current_task = "banking"
            else
                local rocks = API.GetAllObjArrayInteract_str({ selectedRock }, 50, { 0, 12 })
                local shinyRock = getShinyRock(rocks, 50)
                if shinyRock then
                    if not clickedRockTile or API.Math_DistanceF(clickedRockTile, shinyRock.Tile_XYZ) ~= 0 then
                        API.RandomSleep2(500, 1000, 1500)
                        API.DoAction_Object_Direct(0x3a, API.OFF_ACT_GeneralObject_route0, shinyRock)
                        clickedRockId = shinyRock.Id; clickedRockTile = shinyRock.Tile_XYZ
                    end
                else
                    if selectedRock ~= "Seren stone" and clickedRockTile and clickedRockId and getProgress(5) < math.random(145, 165) then
                        API.DoAction_Object2(0x3a, API.OFF_ACT_GeneralObject_route0, { clickedRockId }, 50, WPOINT.new(clickedRockTile.x, clickedRockTile.y, 0))
                    end
                    if not API.CheckAnim(25) and #rocks > 0 then
                        local randomRock = rocks[math.random(1, #rocks)]
                        API.DoAction_Object_Direct(0x3a, API.OFF_ACT_GeneralObject_route0, randomRock)
                        clickedRockId = randomRock.Id; clickedRockTile = randomRock.Tile_XYZ
                    end
                end
            end
        elseif current_task == "banking" then
            local success = doFurnaceBanking()
            if not success then break end
        end
    end

    API.RandomSleep2(500, 250, 500)
end
