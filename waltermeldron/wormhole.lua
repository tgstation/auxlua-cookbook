SS13 = require("SS13")

local me = dm.global_vars:get_var("GLOB"):get_var("directory"):get("waltermeldron"):get_var("mob")

local dropLocation = me:call_proc("drop_location")

local lighter = SS13.new("/obj/structure", dropLocation)
local item = SS13.new_untracked("/obj/item", dropLocation)

lighter:set_var("icon", item:get_var("icon"))
lighter:set_var("icon_state", "anom")
lighter:set_var("name", "wormhole")
lighter:set_var("anchored", true)
lighter:set_var("density", true)
lighter:set_var("uses_integrity", false)

SS13.qdel(item)

local processingPlayers = {}
local playerCooldown = {}

function REF(ent)
    return dm.global_proc("REF", ent)
end

local function abductPlayer(self, player)
    local playerRef = dm.global_proc("REF", player)

    if processingPlayers[playerRef] then
        return
    end
    dm.global_proc("playsound", self, "sound/machines/ding.ogg", 100, true)
    player:call_proc("dropItemToGround", self)
    player:call_proc("Stun", 20, true)
    player:call_proc("add_filter", "disappear_effect", 10, dm.global_proc("wave_filter", 10, 0, 0, 0, 0))
    player:call_proc("transition_filter", "disappear_effect", { offset = 5, size = 50 }, 20, 1, 0)
    processingPlayers[playerRef] = true
    SS13.set_timeout(1.8, function()
        if player == nil or player:is_null() or player:get_var("gc_destroyed") then
            return
        end
        player:call_proc("remove_filter", "disappear_effect")
        player:set_var("alpha", 255)
        if self == nil or self:is_null() or self:get_var("gc_destroyed") then
            return
        end
        processingPlayers[playerRef] = nil
	    player:call_proc("forceMove", self)
        dm.global_proc("playsound", self, "sound/weapons/emitter2.ogg", 100, true)
        local sparks = SS13.new("/datum/effect_system/spark_spread/quantum")
        sparks:call_proc("set_up", 5, 1, self)
        sparks:call_proc("attach", self:call_proc("drop_location"))
        sparks:call_proc("start")
    end)
end

SS13.register_signal(lighter, "atom_bumped", function(self, player)
    if(SS13.istype(player, "/mob/living")) then
        abductPlayer(self, player)
    end
end)

SS13.register_signal(lighter, "atom_relaymove", function(self, player, direction)
    if not SS13.istype(self:get_var("loc"), "/turf") then
        return
    end

    local playerRef = REF(player)
    local currentTime = dm.world:get_var("time")

    if playerCooldown[playerRef] and playerCooldown[playerRef] > currentTime then
        return 1
    end

    playerCooldown[playerRef] = currentTime + 5
    local newTurf = dm.global_proc("_get_step", self:get_var("loc"), direction)
    self:call_proc("Move", newTurf, direction)
    dm.global_proc("to_chat", player, "<span class='notice'>You move the wormhole "..dm.global_proc("dir2text", direction)..".</span>")
    for _, targetObj in newTurf:get_var("contents") do
        if SS13.istype(targetObj, "/mob/living") then
            abductPlayer(self, targetObj)
        end
        if SS13.istype(targetObj, "/obj/machinery/door") then
            SS13.set_timeout(0, function()
                targetObj:call_proc("bumpopen", player)
            end)
        end
    end
    return 1
end)

SS13.register_signal(lighter, "parent_qdeleting", function(self)
	local newDropLocation = self:call_proc("drop_location")
	for _, player in self:get_var("contents"):to_table() do
		player:call_proc("forceMove", newDropLocation)
	end
end)
