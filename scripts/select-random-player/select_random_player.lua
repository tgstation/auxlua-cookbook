-- Change this to change what antagonist preference to check for when filtering through players to randomly select.
-- For example, if you want a player with their changeling preferences on, change this to "Changeling"
local BE_SPECIAL = "Traitor"

-- This is unscoped as auxlua allows for global functions to be called from a menu, allowing you to call this function without needing to rerun this script.
-- selene: allow(unscoped_variables)
function selectRandomPlayer(beSpecial)
    local players = dm.global_vars:get_var("GLOB"):get_var("alive_player_list")
    local playerTable = {}

    for _, player in players do
        local client = player:get_var("client")
        if not client then 
            continue 
        end
        local mind = player:get_var("mind")
        if mind:get_var("special_role") ~= nil then
            continue
        end
        local beSpecialClient = client:get_var("prefs"):get_var("be_special"):to_table()
        if table.find(beSpecialClient, beSpecial) == nil then
            continue
        end
        table.insert(playerTable, player)
    end

    if #playerTable == 0 then 
        dm.global_proc("message_admins", "Unable to select a player for the role of " .. beSpecial)
        return 
    end

    local player = playerTable[math.random( #playerTable )]
    dm.global_proc("message_admins", "Selected player " .. dm.global_proc("key_name_admin", player) .. " for the role of " .. beSpecial)
end

sleep()
selectRandomPlayer(BE_SPECIAL)
