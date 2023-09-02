SS13 = require("SS13")

local GLOB = dm.global_vars:get_var("GLOB")
local SSdcs = dm.global_vars:get_var("SSdcs")
local SSid_access = dm.global_vars:get_var("SSid_access")
local SSmapping = dm.global_vars:get_var("SSmapping")
local rules = "You are a wizard! You can do whatever you want on the station!\nNote: Antimagic is completely disabled\nRespawns are enabled\nPick up IDs to gain score!\nYou have invulnerability and invisibility until you move or click anywhere that isn't your inventory."

if DESTRUCT_MAKE_WIZARD ~= nil then
	DESTRUCT_MAKE_WIZARD()
end

local allHuds = {}
local leaderboard = {}
local players = {}
local idCards = {}

local function REF(atom)
    return dm.global_proc("REF", atom)
end

local function updateLeaderboard(image)
    table.sort(leaderboard, function(a, b)
        return a.idsPickedUp > b.idsPickedUp
    end)
    local leaderboard_text = ""
    for i = 1, 5 do
        local playerData = leaderboard[i]
        if playerData then 
            leaderboard_text = leaderboard_text .. "<br/>[" .. playerData.idsPickedUp .. "] " .. playerData.name
        end
    end
    local text = string.format("<span class='maptext' style='color: %s'>Most IDs collected%s</span>", "#ffffff", leaderboard_text)
    if image then
        image:set_var(
            "maptext",
            text
        )
    else
        for _, currentImage in allHuds do
            currentImage:set_var(
                "maptext",
                text
            )
        end
    end
end

-- Magical
local function makeWizard(oldmob, job)
    local mind = oldmob.vars.mind
	if mind ~= nil then
        if job == nil or job:is_null() then
            job = mind.vars.assigned_role
            if job == nil or job:is_null() or job.vars.outfit == nil then
                job = dm.global_vars:get_var("SSjob"):get_var("name_occupations"):get("Assistant")
            end
        end
        SS13.register_signal(mind, "antagonist_gained", function(_, wizard_antag)
            local mob = mind:get_var("current")
            wizard_antag:set_var("allow_rename", false)
            dm.global_proc("qdel", wizard_antag:get_var("ritual"))
            local ckey = mob:get_var("ckey")
            mob:set_var("real_name", mob:get_var("key"))
            local outfit = job.vars.outfit
            local id
            if outfit ~= nil then
                outfit = dm.global_proc("_new", outfit)
                id = SS13.new(outfit.vars.id, mob)
                id:set_var("registered_name", ckey)
                SSid_access:call_proc("apply_trim_to_card", id, outfit.vars.id_trim)
                local ref = REF(id)
                idCards[ref] = mind
                SS13.register_signal(id, "parent_qdeleting", function(_)
                    idCards[ref] = nil
                end)
            end
            local image = SS13.new("/atom/movable/screen/text", mob)
            image:set_var("screen_loc", "WEST:4,CENTER-0:17")
            local hud = mob:get_var("hud_used")
            local hudElements = hud:get_var("static_inventory")
            hudElements:add(image)
            image:set_var("loc", nil)
            table.insert(allHuds, image)
            hud:call_proc("show_hud", hud:get_var("hud_version"))
            if not players[ckey] then
                players[ckey] = {
                    name = ckey,
                    idsPickedUp = 0,
                    idCard = id
                }
                table.insert(leaderboard, players[ckey])
            end
            updateLeaderboard(image)
            local playerData = players[ckey]
            dm.global_proc("to_chat", mob, "<span class='big bold hypnophrase'>" .. rules .. "</span>")
            dm.global_proc("_add_trait", mob, "pacifism", "admin_voodoo")
            dm.global_proc("_add_trait", mob, "magically_phased", "admin_voodoo")
            mob:set_var("density", false)
            mob:set_var("invisibility", 60)
            mob:set_var("status_flags", 16)
            mob:set_var("alpha", 127)
            mob:call_proc("set_sight", 1084)
            local pacifismRemoved = false
            function register_mob_signals(old, mob_target)
                function removePacifism()
                    if not pacifismRemoved then
                        if not mob:is_null() then
                            dm.global_proc("_remove_trait", mob, "pacifism", "admin_voodoo")
                            dm.global_proc("_remove_trait", mob, "magically_phased", "admin_voodoo")
                            mob:set_var("density", true)
                            mob:set_var("invisibility", 0)
                            mob:set_var("status_flags", 15)
                            mob:set_var("alpha", 255)
                            mob:call_proc("set_sight", 0)
                            pacifismRemoved = true
                        end
                    end
                end
                if old ~= nil and not old:is_null() then
                    SS13.unregister_signal(old, "addtrait anti_magic")
                    SS13.unregister_signal(old, "mob_equipped_item")
                    SS13.unregister_signal(old, "addtrait anti_magic_no_selfblock")
                    SS13.unregister_signal(old, "mob_statchange")
                    SS13.unregister_signal(old, "mob_logout")
                end
                SS13.register_signal(mob_target, "addtrait anti_magic", function(_, trait)
                    local traits = mob_target:get_var("status_traits")
                    traits:remove(trait)
                end)
                SS13.register_signal(mob_target, "addtrait anti_magic_no_selfblock", function(_, trait)
                    local traits = mob_target:get_var("status_traits")
                    traits:remove(trait)
                end)
                SS13.register_signal(mob_target, "mob_equipped_item", function(_, item)
                    dm.global_proc("qdel", item:call_proc("GetComponent", dm.global_proc("_text2path", "/datum/component/anti_magic")))
                end)
                SS13.register_signal(mob_target, "mob_update_sight", function()
                    if not pacifismRemoved then
                        mob_target:call_proc("set_sight", 1084)
                    end
                end)
                mob_target:call_proc("update_sight")
                SS13.register_signal(mob_target, "mob_clickon", function(_, item, modifiers)
                    if mob_target:call_proc("incapacitated") == true then
                        return
                    end

                    if item:get_var("loc") ~= mob_target then
                        if dm.global_proc("_get_dist", mob_target, item) > 1 then
                            return
                        end
                    end
                    local itemRef = REF(item)
                    local playerMind = idCards[itemRef]
                    if playerMind and playerMind ~= mind and item:get_var("registered_name") ~= mob_target:get_var("ckey") then
                        playerData.idsPickedUp += 1
                        dm.global_proc("qdel", item)
                        SS13.set_timeout(0.1, function()
                            updateLeaderboard()
                        end)
                    end
                end)
                SS13.register_signal(mob_target, "movable_moved", function(_, _)
                    removePacifism()
                end)
                local dusted = false
                SS13.register_signal(mob_target, "mob_statchange", function(_, new_stat)
                    if new_stat == 4 then
                        if SSmapping:call_proc("level_trait", mob_target:get_var("z"), "CentCom") then
                            if not dusted and not mob_target:get_var("gc_destroyed") then
                                dusted = true
                                SS13.set_timeout(1, function()
                                    mob_target:call_proc("dust")
                                end)
                            end
                        elseif id ~= nil and not id:is_null() then
                            id:call_proc("forceMove", id:call_proc("drop_location"))
                        end
                    end
                end)
                SS13.register_signal(mob_target, "mob_logout", function(_)
                    if SSmapping:call_proc("level_trait", mob_target:get_var("z"), "CentCom") and not dusted and not mob_target:get_var("gc_destroyed") then
                        dusted = true
                        SS13.set_timeout(1, function()
                            mob_target:call_proc("dust")
                        end)
                    end
                end)
            end
            SS13.register_signal(mind, "mind_transferred", function(_, old)
                local current = mind:get_var("current")
                if old ~= nil and not old:is_null() then
                    dm.global_proc("_remove_trait", old, "pacifism", "admin_voodoo")
                end
                register_mob_signals(old, current)
                if id ~= nil and not id:is_null() then
                    id:call_proc("forceMove", current)
                end
            end)
            for _, telescroll in mob:get_var("contents"):of_type("/obj/item/teleportation_scroll") do
                dm.global_proc("qdel", telescroll)
            end
            for _, spellbook in mob:get_var("back"):get_var("contents"):of_type("/obj/item/spellbook") do
                for _, spell in spellbook:get_var("entries"):of_type("/datum/spellbook_entry/summon") do
                    spell:set_var("limit", 0)
                    spell:set_var("cost", 100)
                end
            end
            mob:call_proc("forceMove", dm.global_proc("get_safe_random_station_turf"))
            register_mob_signals(mob, mob)
            SS13.unregister_signal(mind, "antagonist_gained")
        end)
        mind:call_proc("make_wizard")
	end
end

-- Initial wizard creation
for _, mob in GLOB.vars.alive_player_list:to_table() do
    makeWizard(mob)
    sleep()
end

function give_leaderboard_to_dead_players()
    for _, mob in GLOB.vars.dead_player_list:to_table() do
        local image = SS13.new("/atom/movable/screen/text", mob)
        image:set_var("screen_loc", "WEST:4,CENTER-0:17")
        local hud = mob:get_var("hud_used")
        local hudElements = hud:get_var("static_inventory")
        hudElements:add(image)
        table.insert(allHuds, image)
        hud:call_proc("show_hud", hud:get_var("hud_version"))
        updateLeaderboard(image)
        sleep()
    end
end

local function latejoinSpawnCallback(_source, job, mob)
    makeWizard(mob, job)
end

SS13.register_signal(SSdcs, "!job_after_latejoin_spawn", latejoinSpawnCallback)

DESTRUCT_MAKE_WIZARD = function()
    SS13.unregister_signal(SSdcs, "!job_after_latejoin_spawn")
    for _, image in allHuds do
        if image ~= nil and not image:is_null() then
            dm.global_proc("qdel", image)
        end
    end
    DESTRUCT_MAKE_WIZARD = nil
end
