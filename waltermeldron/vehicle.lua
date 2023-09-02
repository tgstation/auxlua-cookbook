SS13 = require("SS13")

local RAM_POWER_NONE = 1
local RAM_POWER_MOBS = 2
local RAM_POWER_OBJECTS = 3
local RAM_POWER_WALL = 4
local RAM_POWER_ALL = 5

-- Change this to your ckey so that this works. Don't run it with my ckey please :)
local admin = "waltermeldron"
-- If set to false, ignores the width and height and searches for an industrial_lift on the user's current turf
local fromScratch = false
-- X radius width of the vehicle
local width = 1
-- Y radius width of the vehicle
local height = 1
-- Tiles per second at which the vehicle can move at
local speed = 10
-- The level at which this vehicle can ram objects
local ramPower = RAM_POWER_ALL
-- The level at which this vehicle can ram objects when emagged
local emaggedRamPower = ramPower + 1
-- Whether to increase the destructive level of the vehicle
local veryDestructive = false
local createWindow = true

local function getPassThroughs()
	if ramPower < RAM_POWER_OBJECTS then
		return {
			SS13.type("/obj/machinery"),
			SS13.type("/obj/structure")
		}
	else
		return {
			SS13.type("/obj/machinery/power/supermatter_crystal"),
			SS13.type("/obj/structure/holosign"),
			SS13.type("/obj/machinery/field"),
		}
	end
end

local emagged = false
local me = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin)
local spawnLocation = me:get_var("mob"):get_var("loc")

local icon = SS13.new_untracked("/icon", "icons/turf/floors.dmi")
local icon_state = "rockvault"
local vehicleChair
local tramPiece
if fromScratch then
	local spawnX = spawnLocation:get_var("x")
	local spawnY = spawnLocation:get_var("y")
	local spawnZ = spawnLocation:get_var("z")

	local xOffset = (width - 1)
	local yOffset = (height - 1)

	local bottomLeft = dm.global_proc("_locate", spawnX - xOffset, spawnY - yOffset, spawnZ)
	local topRight = dm.global_proc("_locate", spawnX + xOffset, spawnY + yOffset, spawnZ)

	local turfs = dm.global_proc("_block", bottomLeft, topRight)

	tramPiece = SS13.new("/obj/structure/industrial_lift", bottomLeft)
	local mainTramMaster = tramPiece:get_var("lift_master_datum")
	local fillerPieces = {}
	for _, turf in turfs do
		if over_exec_usage(0.7) then
			sleep()
		end
		local fillerPiece
		if turf == bottomLeft then
			fillerPiece = tramPiece
		else
			fillerPiece = SS13.new("/obj/structure/industrial_lift", turf)
		end
		fillerPiece:set_var("canSmoothWith", {})
		fillerPiece:set_var("smoothing_groups", {})
		fillerPiece:set_var("smoothing_flags", 0)
		fillerPiece:set_var("icon", icon)
		fillerPiece:set_var("icon_state", icon_state)
		if turf ~= bottomLeft then
			SS13.qdel(fillerPiece:get_var("lift_master_datum"))
			table.insert(fillerPieces, fillerPiece)
		end
	end

	if width == 1 and height == 1 and createWindow then
		local window = SS13.new("/obj/structure/window/reinforced/tram/front", bottomLeft)
		SS13.register_signal(window, "parent_qdeleting", function()
			if SS13.is_valid(mainTramMaster) then
				SS13.qdel(mainTramMaster)
			end
		end)
		local registeredUnbuckle = false
		window:set_var("can_buckle", 1)
		window:set_var("plane", -4)
		window:set_var("layer", 5)
		SS13.register_signal(window, "prebuckle", function(_, clicker)
			if not SS13.is_valid(vehicleChair) then
				return 1
			end
			if vehicleChair:call_proc("has_buckled_mobs") == 1 then
				return 1
			end
			if clicker:get_var("stat") == 4 or not SS13.istype(clicker, "/mob/living") then
				return 1
			end
			local dist = dm.global_proc("_get_dist", clicker:get_var("loc"), vehicleChair:get_var("loc"))
			if (dist == -1 and clicker:get_var("loc") ~= vehicleChair:get_var("loc")) or dist > 1 then
				return 1
			end
			window:set_var("density", 0)
			clicker:call_proc("Move", vehicleChair:get_var("loc"))
			vehicleChair:call_proc("buckle_mob", clicker, true, false)
			window:set_var("density", 1)
			return 1
		end)
		SS13.register_signal(window, "atom_emag_act", function(_, emagger)
			if emagged then
				return
			end
			dm.global_proc("to_chat", emagger, "<span danger='notice'>You disable the safety protocols on the vehicle.</span>")
			emagged = true
			ramPower = emaggedRamPower
			mainTramMaster:set_var("ignored_smashthroughs", dm.global_proc("typecacheof", getPassThroughs()))
		end)
		
	end
	tramPiece:set_var("lift_master_datum", mainTramMaster)
	for _, fillerPiece in fillerPieces do
		mainTramMaster:call_proc("add_lift_platforms", fillerPiece)
	end
else
	for _, object in spawnLocation:get_var("contents") do
		if SS13.istype(object, "/obj/structure/industrial_lift") then
			tramPiece = object
			break
		end
	end

	if not tramPiece then
		print("No tram piece found!")
		return
	end
end
local mainTramMaster = tramPiece:get_var("lift_master_datum")
mainTramMaster:set_var("create_multitile_platform", true)
mainTramMaster:call_proc("order_platforms_by_z_level")
local mainPlatform = mainTramMaster:get_var("lift_platforms"):get(1)
mainPlatform:set_var("radial_travel", false)
sleep()
mainTramMaster:set_var("ignored_smashthroughs", dm.global_proc("typecacheof", getPassThroughs()))
sleep()
vehicleChair = SS13.new("/obj/structure/chair/office/tactical", spawnLocation)
vehicleChair:set_var("anchored", true)
local directions = { 1, 2, 4, 8 }
local reverseDirections = {
	[1] = 2,
	[2] = 1,
	[4] = 8,
	[8] = 4
}
local moveCooldown = 0
local function isTurfBlocked(turf, direction, user)
	local targetTurf = dm.global_proc("_get_step", turf, direction)
	if targetTurf:get_var("density") and SS13.istype(targetTurf, "/turf/closed/indestructible") and ramPower < RAM_POWER_ALL then
		return true
	end
	if targetTurf:get_var("density") == 1 and ramPower < RAM_POWER_WALL then
		return true
	end
	local turfAfter = dm.global_proc("_get_step", targetTurf, direction)
	local turfBefore = dm.global_proc("_get_step", targetTurf, reverseDirections[direction])
	for _, object in targetTurf:get_var("contents") do
		if SS13.istype(object, "/mob/living") then
			if ramPower < RAM_POWER_MOBS then
				if object:get_var("anchored") == 1 or turfAfter:get_var("density") == 1 then
					return true
				end
				if object:call_proc("Move", turfAfter, direction) ~= 1 then
					return true
				end
			elseif veryDestructive then
				if turfAfter:get_var("density") == 1 then
					object:call_proc("gib")
				end
			end
		elseif SS13.istype(object, "/obj") then
			if ramPower < RAM_POWER_OBJECTS then
				local tryMove = 0
				if object:get_var("anchored") ~= 1 and turfAfter:get_var("density") ~= 1 then
					tryMove = object:call_proc("Move", turfAfter, direction)
				end
				if object:get_var("density") == 1 then
					if SS13.istype(object, "/obj/machinery/door") then
						SS13.set_timeout(0, function()
							object:call_proc("bumpopen", user)
						end)
					end
					if (bit32.band(object:get_var("flags_1"), 8) == 0 or object:get_var("dir") == reverseDirections[direction]) and tryMove ~= 1 then
						return true
					end
				end
			else
				if object:get_var("density") == 0 and object:get_var("anchored") == 0 and turfAfter:get_var("density") ~= 1 then
					object:call_proc("Move", turfAfter, direction)
				end
			end
		end
	end
	if ramPower < RAM_POWER_OBJECTS then
		for _, object in turfBefore:get_var("contents") do
			if object:get_var("density") == 1 and object:get_var("anchored") == 1 then
				if (bit32.band(object:get_var("flags_1"), 8) == 0 or object:get_var("dir") == direction) then
					if dm.global_proc("_list_find", mainPlatform:get_var("lift_load"), object) == 0 then
						return true
					end
				end
			end
		end
	end
	return false
end

SS13.register_signal(vehicleChair, "atom_relaymove", function(_, user, direction)
	local currentTime = dm.world:get_var("time")
	if moveCooldown > currentTime then
		return 1
	end
	for _, validDir in directions do 
		if bit32.band(validDir, direction) ~= 0 then
			direction = validDir
			break
		end
	end
	vehicleChair:call_proc("setDir", direction)
	moveCooldown = currentTime + 1

	local realWidth = mainPlatform:get_var("width")
	local realHeight = mainPlatform:get_var("height")
	local realX = mainPlatform:get_var("x")
	local realY = mainPlatform:get_var("y")
	local turfsChecking = {}
	local blocked = false
	for _, turf in mainPlatform:get_var("locs") do
		if over_exec_usage(0.9) then
			return 1
		end
		if direction == 1 then -- North
			if turf:get_var("y") == realY + realHeight - 1 then
				if isTurfBlocked(turf, direction, user) then
					blocked = true
				end
			end
		elseif direction == 2 then -- South
			if turf:get_var("y") == realY then
				if isTurfBlocked(turf, direction, user) then
					blocked = true
				end
			end
		elseif direction == 4 then -- East
			if turf:get_var("x") == realX + realWidth - 1 then
				if isTurfBlocked(turf, direction, user) then
					blocked = true
				end
			end
		elseif direction == 8 then -- West
			if turf:get_var("x") == realX then
				if isTurfBlocked(turf, direction, user) then
					blocked = true
				end
			end
		end
	end

	if blocked then
		return 1
	end
	moveCooldown = currentTime + (1 / speed) * 10
	mainTramMaster:call_proc("move_lift_horizontally", direction)
	return 1
end)

SS13.register_signal(vehicleChair, "atom_emag_act", function(_, emagger)
	if emagged then
		return
	end
	dm.global_proc("to_chat", emagger, "<span danger='notice'>You disable the safety protocols on the vehicle.</span>")
	emagged = true
	ramPower = emaggedRamPower
	mainTramMaster:set_var("ignored_smashthroughs", dm.global_proc("typecacheof", getPassThroughs()))
end)

SS13.register_signal(mainTramMaster, "parent_qdeleting", function()
	if SS13.is_valid(vehicleChair) then
		SS13.qdel(vehicleChair)
	end
	if SS13.is_valid(mainPlatform) then
		SS13.qdel(mainPlatform)
	end
end)
function doNothing()
	return 1 
end
SS13.register_signal(vehicleChair, "tool_act_screwdriver", doNothing)
SS13.register_signal(vehicleChair, "tool_secondary_act_screwdriver", doNothing)
SS13.register_signal(vehicleChair, "tool_act_crowbar", doNothing)
SS13.register_signal(vehicleChair, "tool_secondary_act_crowbar", doNothing)
SS13.register_signal(vehicleChair, "tool_act_wrench", doNothing)
SS13.register_signal(vehicleChair, "tool_secondary_act_crowbar", doNothing)
