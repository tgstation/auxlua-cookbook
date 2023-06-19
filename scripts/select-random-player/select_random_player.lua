local BE_SPECIAL = "Traitor"

function selectRandomPlayer(be_special)

    local players = dm.global_vars:get_var("GLOB"):get_var("alive_player_list")
    local playerTable = {}

    for _, player in players do
        local client = player:get_var("client")
        if not client then continue end
        local be_special_client = client:get_var("prefs"):get_var("be_special")
        for _, special in be_special_client do
            if special == be_special then
                table.insert(playerTable, player)
                break
            end
        end
    end

    if #playerTable == 0 then 
        dm.global_proc("message_admins", "Unable to select a player for the role of " .. be_special)
        return 
    end

    local player = playerTable[math.random( #playerTable )]
    dm.global_proc("message_admins", "Selected player " .. dm.global_proc("key_name_admin", player) .. " for the role of " .. be_special)
end

sleep()
selectRandomPlayer(BE_SPECIAL)