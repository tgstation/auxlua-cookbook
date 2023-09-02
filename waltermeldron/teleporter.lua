SS13 = require("SS13")

local me = dm.global_vars:get_var("GLOB"):get_var("directory"):get("waltermeldron"):get_var("mob")

local size = 5

local dropLocation = me:call_proc("drop_location")

local xLoc = dropLocation:get_var("x")
local yLoc = dropLocation:get_var("y")
local zLoc = dropLocation:get_var("z")

local originalIcon

function locate(x, y)
    return dm.global_proc("_locate", x, y, zLoc)
end

local outsideBorderOffset = math.floor(size / 2) + size * 2 + 1
for index, turf in dm.global_proc("_block", locate(xLoc - outsideBorderOffset, yLoc + outsideBorderOffset), locate(xLoc + outsideBorderOffset, yLoc - outsideBorderOffset)) do 
    if index % 25 == 0 then
        sleep()
    end

    local xPos = turf:get_var("x")
    local yPos = turf:get_var("y")
    local zPos = turf:get_var("z")

    turf:call_proc("ChangeTurf", dm.global_proc("_text2path", "/turf/closed/indestructible"))
    local newTurf = dm.global_proc("_locate", xPos, yPos, zPos)
    newTurf:set_var("color", "#000")
end

local outerBorderOffset = outsideBorderOffset - 1
for index, turf in dm.global_proc("_block", locate(xLoc - outerBorderOffset, yLoc - outerBorderOffset), locate(xLoc + outerBorderOffset, yLoc + outerBorderOffset)) do 
    if index % 25 == 0 then
        sleep()
    end

    local xPos = turf:get_var("x")
    local yPos = turf:get_var("y")
    local zPos = turf:get_var("z")

    turf:call_proc("ChangeTurf", dm.global_proc("_text2path", "/turf/open/indestructible/white"))
    local newTurf = dm.global_proc("_locate", xPos, yPos, zPos)
    newTurf:set_var("color", "#000")
end

local insideBorderOffset = math.floor(size / 2)
for index, turf in dm.global_proc("_block", locate(xLoc - insideBorderOffset, yLoc + insideBorderOffset), locate(xLoc + insideBorderOffset, yLoc - insideBorderOffset)) do 
    if index % 25 == 0 then
        sleep()
    end

    turf:call_proc("ChangeTurf", dm.global_proc("_text2path", "/turf/closed/indestructible/fakeglass"))
end

local insideOffset = insideBorderOffset - 1
for index, turf in dm.global_proc("_block", locate(xLoc - insideOffset, yLoc + insideOffset), locate(xLoc + insideOffset, yLoc - insideOffset)) do 
    if index % 25 == 0 then
        sleep()
    end

    turf:call_proc("ChangeTurf", dm.global_proc("_text2path", "/turf/open/indestructible/white"))
end

dropLocation = dm.global_proc("_locate", xLoc, yLoc, zLoc)

local bottomLeftCornerOffset = size * 3
local bottomLeftCorner = locate(xLoc - bottomLeftCornerOffset, yLoc - bottomLeftCornerOffset)

local xBottom = bottomLeftCorner:get_var("x")
local yBottom = bottomLeftCorner:get_var("y")

local invisibleHolder = SS13.new("/obj", dropLocation)

invisibleHolder:set_var("resistance_flags", 243)

local lighter = SS13.new("/obj/item", dropLocation)

lighter:set_var("icon_state", "latexballon_blow")
lighter:set_var("name", "Bluespace Room")
lighter:set_var("w_class", 6)
lighter:set_var("desc", "Contains a label on the side: <span class='notice'>Use in hand</span>.")
lighter:set_var("resistance_flags", 243)

local processingPlayers = {}
local antiPeople = {}

local teleportDestination = SS13.new("/obj/item", dropLocation)

teleportDestination:set_var("icon_state", "latexballon_blow")
teleportDestination:set_var("name", "Exit")
teleportDestination:set_var("w_class", 6)
teleportDestination:set_var("desc", "Contains a label on the side: <span class='notice'>Use in hand</span>.")
teleportDestination:set_var("resistance_flags", 243)

local turfs = {}

for x = 1, 5 do
    for y = 1, 5 do
        if x == 3 and y == 3 then
            table.insert(turfs, "skip")
            continue
        end
        table.insert(turfs, locate(xBottom + size * x, yBottom + size * y))
    end
end

originalIcon = dropLocation:get_var("icon")

function REF(ent)
    return dm.global_proc("REF", ent)
end

SS13.register_signal(lighter, "atom_attack_hand", function(_, player)
    if antiPeople[REF(player)] then
        return 1
    end
end)

SS13.register_signal(teleportDestination, "atom_attack_hand", function(_, player)
    if not antiPeople[REF(player)] then
        return 1
    end
end)

function teleportToLocation(self, player, location, onTeleport)
    local playerRef = dm.global_proc("REF", player)

    dm.global_proc("playsound", self, "sound/machines/ding.ogg", 100, true)
    dm.global_proc("playsound", location, "sound/machines/ding.ogg", 100, true)
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
        onTeleport()
	    player:call_proc("forceMove", location:call_proc("drop_location"))
        dm.global_proc("playsound", self, "sound/weapons/emitter2.ogg", 100, true)
        dm.global_proc("playsound", location, "sound/weapons/emitter2.ogg", 100, true)
        local sparks = SS13.new("/datum/effect_system/spark_spread/quantum")
        sparks:call_proc("set_up", 5, 1, self)
        sparks:call_proc("attach", self:call_proc("drop_location"))
        sparks:call_proc("start")
        sparks:call_proc("attach", location:call_proc("drop_location"))
        sparks:call_proc("start")
    end)
end

SS13.register_signal(lighter, "item_attack_self", function(self, player)
    local playerRef = dm.global_proc("REF", player)

    if processingPlayers[playerRef] or antiPeople[playerRef] then
        return
    end
    teleportToLocation(self, player, teleportDestination, function()
        antiPeople[playerRef] = player
    end)
	return 1
end)

SS13.register_signal(teleportDestination, "item_attack_self", function(self, player)
    local playerRef = dm.global_proc("REF", player)

    if processingPlayers[playerRef] or not antiPeople[playerRef] then
        return
    end
    teleportToLocation(self, player, lighter, function()
        antiPeople[playerRef] = nil
    end)
	return 1
end)

SS13.register_signal(lighter, "parent_qdeleting", function(self)
	local newDropLocation = self:call_proc("drop_location")
	for _, player in antiPeople do
        if not player:is_null() and not player:get_var("gc_destroyed") then
		    player:call_proc("forceMove", newDropLocation)
        end
	end
    dm.global_proc("qdel", invisibleHolder)
end)

local currentTurfs = {}
local trackedObjects = {}

SS13.register_signal(lighter, "movable_moved", function(self)
    local turfs_in_view = dm.global_proc("circle_view_turfs", self, 3)
    local validTurfs = {}
    for key, objData in trackedObjects do
        if objData.this:is_null() then
            trackedObjects[key] = nil
            continue
        end
    end
    for _, turfInView in turfs_in_view do
        validTurfs[REF(turfInView)] = true
    end
    local notCapturedObjects = {}
    for _, universeTurf in ipairs(turfs) do
        if universeTurf == "skip" then
            continue
        end
        local objects = dm.global_proc("_range", math.floor(size / 2), universeTurf)
        local lastPosition = currentTurfs[universeTurf]
        if lastPosition then
            for _, obj in objects do
                if not SS13.istype(obj, "/atom/movable") or SS13.istype(obj, "/mob/dead") then
                    continue
                end
                local objRef = REF(obj)
                local objLocation = trackedObjects[objRef]
                if not objLocation or objLocation.turf ~= lastPosition.turf then
                    objLocation = {
                        x = lastPosition.x,
                        y = lastPosition.y,
                        turf = lastPosition.turf,
                        universeTurf = universeTurf,
                        this = obj
                    }
                end
                objLocation.xLocal = obj:get_var("x") - universeTurf:get_var("x")
                objLocation.yLocal = obj:get_var("y") - universeTurf:get_var("y")
                trackedObjects[objLocation.this] = objLocation
                notCapturedObjects[objRef] = objLocation
            end
        end
    end
    sleep()
    for index, universeTurf in ipairs(turfs) do
        if universeTurf == "skip" then
            continue
        end
        local appearanceFlags = universeTurf:get_var("appearance_flags")
        if bit32.band(appearanceFlags, 512) == 0 then
            appearanceFlags +=  512
        end
        if bit32.band(appearanceFlags, 256) ~= 0 then
            appearanceFlags -= 256
        end

        universeTurf:set_var("appearance_flags", appearanceFlags)
        dm.global_proc("_list_cut", universeTurf:get_var("vis_contents"))
        universeTurf:set_var("plane", -1)
        local locationTurf = self:get_var("loc")
        local xPosition = locationTurf:get_var("x") - 2 + math.floor((index-1) / 5)
        local yPosition = locationTurf:get_var("y") - 2 + ((index-1) % 5)
        local turf = dm.global_proc("_locate", xPosition, yPosition, locationTurf:get_var("z"))
        local newTurfData = { x = xPosition, y = yPosition, turf = REF(turf) }
        currentTurfs[universeTurf] = newTurfData
        local universeTurfBelow = dm.global_proc("_locate", universeTurf:get_var("x"), universeTurf:get_var("y") - 1, universeTurf:get_var("z"))
        universeTurfBelow:set_var("maptext", "")
        universeTurfBelow:set_var("plane", -10)
        if (not SS13.istype(locationTurf, "/turf")) or not validTurfs[REF(turf)] then
            universeTurf:set_var("icon", originalIcon)
            universeTurf:set_var("icon_state", "black")
            universeTurf:set_var("transform", dm.global_proc("_matrix", size, 0, 0, 0, size, 0))
            if not SS13.istype(locationTurf, "/turf") then
                universeTurfBelow:set_var("maptext", "<span class='maptext' style='font-size: 48px'>Inside "..tostring(locationTurf).."</span>")
                universeTurfBelow:set_var("maptext_width", size * 16)
                universeTurfBelow:set_var("color", nil)
                universeTurfBelow:set_var("icon", nil)
                universeTurfBelow:set_var("maptext_x", -size * 8)
                universeTurfBelow:set_var("plane", -1)
            end
            continue
        end

        for _, objData in trackedObjects do
            if objData.this:is_null() then
                continue
            end
            if objData.turf == newTurfData.turf then
                local newTurf = dm.global_proc("_locate", universeTurf:get_var("x") + objData.xLocal, universeTurf:get_var("y") + objData.yLocal, universeTurf:get_var("z"))
                objData.this:call_proc("abstract_move", newTurf)
                notCapturedObjects[REF(objData.this)] = nil
            end
        end

        dm.global_proc("_list_add", universeTurf:get_var("vis_contents"), turf)
        dm.global_proc("_list_remove", universeTurf:get_var("vis_contents"), self)
        universeTurf:set_var("color", "null")
        if universeTurf:get_var("icon") == nil then
            universeTurf:set_var("icon", originalIcon)
            universeTurf:set_var("icon_state", "black")
        else
            universeTurf:set_var("icon", turf:get_var("icon"))
            universeTurf:set_var("icon_state", turf:get_var("icon_state"))
        end
        universeTurf:set_var("transform", dm.global_proc("_matrix", size, 0, 0, 0, size, 0))
    end

    for _, data in notCapturedObjects do
        if not data.this:is_null() then
            data.this:call_proc("abstract_move", invisibleHolder)
        end
    end

end)

SS13.register_signal(teleportDestination, "parent_qdeleting", function()
	dm.global_proc("qdel", lighter)
end)
