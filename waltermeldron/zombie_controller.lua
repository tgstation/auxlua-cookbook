local SS13 = require("SS13")
local HandlerGroup = require("handler_group")

local IS_LOCAL = false
local admin = "waltermeldron"
local LOCAL_CLASS = "Zombie (AI)"
local ALLOW_ZOMBIE_CONTROLLABLE = true
local DESTRUCTIBLE_SPAWNERS = true
local ALLOW_TANK_SPAWN = false

local tickLag = function(tickUsageStart, worldTime)
	if dm.world:get_var("time") ~= worldTime then
		print("We slept somewhere!")
		return true
	end
	return (dm.world:get_var("tick_usage") - tickUsageStart) >= 50 or over_exec_usage(0.5)
end
if not IS_LOCAL then
	SS13.await(SS13.global_proc, "__lua_set_execution_limit", 50000)
end

local LAST_TIME_TAKEN
local WORLD_TIME
local TIME_AVG = {}
local SLEEPING_AT = {}
local TOTAL_TIME_TAKEN = {}
local TOTAL_CALL_COUNT = {}

local startPerfTrack = function()
	WORLD_TIME = dm.world:get_var("time")
	local lineNumber = debug.info(2, 'l')
	TIME_AVG[lineNumber] = 0
	TOTAL_TIME_TAKEN[lineNumber] = 0
	TOTAL_CALL_COUNT[lineNumber] = (TOTAL_CALL_COUNT[lineNumber] or 0) + 1
	LAST_TIME_TAKEN = os.clock()
end

local istype_old = SS13.istype
SS13.istype = function(datum, text)
	if not datum then
		return false
	end
	if text == "/datum" or text == "/atom" or text == "/atom/movable" then
		return istype_old(datum, text)
	end
	local datumType = tostring(datum:get_var("type"))
	return string.find(datumType, text) ~= nil
end

local checkPerf = function(ignoreSleep)
	local lineNumber = debug.info(2, 'l')
	if WORLD_TIME ~= dm.world:get_var("time") then
		if ignoreSleep then
			return
		end
		SLEEPING_AT[lineNumber] = true
		WORLD_TIME = dm.world:get_var("time")
	end
	local currTime = os.clock()
	local currentDiff = currTime - LAST_TIME_TAKEN
	local prevDiff = TIME_AVG[lineNumber] or currentDiff
	TIME_AVG[lineNumber] = 0.8 * prevDiff + 0.2 * currentDiff
	TOTAL_TIME_TAKEN[lineNumber] = (TOTAL_TIME_TAKEN[lineNumber] or 0) + currentDiff
	TOTAL_CALL_COUNT[lineNumber] = (TOTAL_CALL_COUNT[lineNumber] or 0) + 1
	LAST_TIME_TAKEN = currTime
end

sleep()

local BLOCK_ACTIVATION = 1

iconsByHttp = iconsByHttp or {}

local function getPlane(new_plane, z_reference)
	local SSmapping = dm.global_vars:get_var("SSmapping")
	if SSmapping:get_var("max_plane_offset") ~= 0 then
		local turfPlaneOffsets = 0
		if SSmapping:get_var("max_plane_offset") ~= nil and SS13.istype(z_reference, "/atom") then
			if z_reference:get_var("z") ~= nil then
				turfPlaneOffsets = SSmapping:get_var("z_level_to_plane_offset"):get(z_reference:get_var("z"))
			else
				if SSmapping:get_var("plane_to_offset") ~= 0 then
					turfPlaneOffsets = SSmapping:get_var("plane_to_offset"):get(tostring(z_reference:get_var("plane")))
				else
					turfPlaneOffsets = z_reference:get_var("plane")
				end
			end
		end
		local plane_offset_blacklist = SSmapping:get_var("plane_offset_blacklist")
		if plane_offset_blacklist == nil or plane_offset_blacklist:get(tostring(new_plane)) then
			return new_plane
		else
			return new_plane - 100 * turfPlaneOffsets
		end
	else
		return new_plane
	end
end

local setClass
local REF = function(ref)
	return dm.global_proc("REF", ref)
end

ALL_HUMAN_DATA = ALL_HUMAN_DATA or {}
local function getZombieMutation(human)
	return ALL_HUMAN_DATA[REF(human)]
end

local hasTrait = function (target, trait)
	return dm.global_proc("_has_trait", target, trait) == 1
end

local isZombie = function(human)
	if not SS13.istype(human, "/mob/living/carbon/human") then
		return false
	end
	local dna = human:get_var("dna")
	if not dna then
		return false
	end
	return SS13.istype(dna:get_var("species"), "/datum/species/zombie/infectious") 
end

local infectTarget = function(human, def_type)
	local infection = human:call_proc("get_organ_slot", "zombie_infection")
	if SS13.is_valid(infection) then
		return
	end
	if def_type ~= "bypass" then
		local armour = human:call_proc("getarmor", def_type, "bio")
		if dm.global_proc("_prob", armour) == 1 then
			return
		end
	end
	infection = SS13.new("/obj/item/organ/internal/zombie_infection")
	infection:call_proc("Insert", human)
end

soundsByHttp = soundsByHttp or {}

local loadSound = function(http)
	if soundsByHttp[http] then
		return soundsByHttp[http]
	end

	local request = SS13.new("/datum/http_request")
	local file_name = "tmp/custom_map_sound.ogg"
	request:call_proc("prepare", "get", http, "", "", file_name)
	request:call_proc("begin_async")
	while request:call_proc("is_complete") == 0 do
		sleep()
	end
	soundsByHttp[http] = SS13.new("/sound", file_name)
	return soundsByHttp[http]
end

local tankFootstepSound = {
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/footstep1.ogg"),
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/footstep2.ogg"),
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/footstep3.ogg")
}

local tankDeathSound = {
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/death1.ogg"),
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/death2.ogg"),
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/death3.ogg")
}

local tankRoarSounds = {
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/roar1.ogg"),
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/roar2.ogg"),
	loadSound("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/roar3.ogg")
}

local loadIcon = function(http)
	if iconsByHttp[http] then
		return iconsByHttp[http]
	end

	local request = SS13.new("/datum/http_request")
	local file_name = "tmp/custom_map_icon.dmi"
	request:call_proc("prepare", "get", http, "", "", file_name)
	request:call_proc("begin_async")
	while request:call_proc("is_complete") == 0 do
		sleep()
	end
	iconsByHttp[http] = SS13.new("/icon", file_name)
	return iconsByHttp[http]
end

local function locate(x, y, z)
	return dm.global_proc("_locate", x, y, z)
end

local function rangeTurfs(location, radius)
	local x = location:get_var("x")
	local y = location:get_var("y")
	local z = location:get_var("z")
	return dm.global_proc("_block", locate(x - radius, y - radius, z), locate(x + radius, y + radius, z))
end

local function to_chat(user, message)
	dm.global_proc("to_chat", user, message)
end

local function RegisterClassSignal(humanData, target, signal, func)
	-- Registers a signal on humanData.human if there are only 3 arguments
	-- Otherwise, acts the same as a regular register signal call, but cleanups on class removal.
	if func == nil then
		table.insert(humanData.classCleanup, {
			target = humanData.human,
			signal = target,
			callback = SS13.register_signal(humanData.human, target, signal)
		})
	else
		table.insert(humanData.classCleanup, {
			target = target,
			signal = signal,
			callback = SS13.register_signal(target, signal, func)
		})
	end
end

local grantAbility = function(humanData, abilityData)
	local abilityType = abilityData.abilityType
	local action = SS13.new("/datum/action/cooldown")
	if abilityType == "targeted" then
		action:set_var("click_to_activate", true)
		action:set_var("unset_after_click", true)
		action:set_var("ranged_mousepointer", loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/effects/mouse_pointers/cult_target.dmi"))
	end
	action:set_var("button_icon", loadIcon(abilityData.icon))
	action:set_var("button_icon_state", abilityData.icon_state)
	action:set_var("background_icon_state", "bg_heretic")
	action:set_var("overlay_icon_state", "bg_heretic_border")
	action:set_var("active_overlay_icon_state", "bg_nature_border")
	action:set_var("cooldown_time", (abilityData.cooldown or 0) * 10)
	SS13.register_signal(humanData.human, "mob_ability_base_started", function(source, actionTarget, target) 
		if REF(actionTarget) == REF(action) then
			local returnValue = abilityData.onActivate(humanData, action, target)
			if action:get_var("unset_after_click") == 1 then
				action:call_proc("unset_click_ability", source, false)
			end
			source:set_var("next_click", dm.world:get_var("time") + action:get_var("click_cd_override"))
			return returnValue
		end
	end)
	action:set_var("name", abilityData.name)
	action:call_proc("Grant", humanData.human)
	return action
end

local zombieControllerTargets = {}

local dead_players_by_zlevel = dm.global_vars:get_var("SSmobs"):get_var("dead_players_by_zlevel")
local SSspacial_grid = dm.global_vars:get_var("SSspatial_grid")
local makeZombieController = function(location)
	local controller = SS13.new("/mob/camera", location)
	local controllerData = {
		human = controller
	}
	controller:set_var("name", "Zombie Controller ("..tostring(math.random(101, 999))..")")
	controller:set_var("invisibility", 60)
	controller:set_var("see_invisible", 25)
	controller:set_var("layer", 5)
	controller:set_var("plane", getPlane(-3, location))
	controller:get_var("faction"):add("zombie")
	controller:call_proc("set_sight", 60)
	controller:set_var("mouse_opacity", 1)
	controller:set_var("color", "#33cc33")
	controller:set_var("icon", loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/silicon/cameramob.dmi"))
	controller:set_var("icon_state", "marker")
	controller:set_var("lighting_cutoff_red", 5)
	controller:set_var("lighting_cutoff_green", 35)
	controller:set_var("lighting_cutoff_blue", 20)
	dm.global_proc("_add_trait", controller, "mute", "zs_controller")
	local nextRally = 0
	local controllerRef = REF(controller)
	local rallyTimer
	SS13.register_signal(controller, "mob_ctrl_clicked", function(_, object)
		SS13.end_loop(rallyTimer)
		zombieControllerTargets[controllerRef] = object
		if not SS13.istype(object, "/turf") then
			to_chat(controller, "<span class='notice'>You rally nearby zombies to attack "..tostring(object).."</span>")
			rallyTimer = SS13.start_loop(30, 1, function()
				zombieControllerTargets[controllerRef] = nil
			end)
		else
			to_chat(controller, "<span class='notice'>You rally nearby zombies to the targeted location</span>")
			rallyTimer = SS13.start_loop(10, 1, function()
				zombieControllerTargets[controllerRef] = nil
			end)
		end

		local potentialTargets = dm.global_proc("get_hearers_in_range", 8, controller)
		for _, zombie in potentialTargets do
			if not isZombie(zombie) then
				continue
			end
			local mutData = getZombieMutation(zombie)
			if not mutData or mutData.class ~= "Zombie (AI)" then
				continue
			end
			mutData.zombieAi.nextTargetSearch = 0
		end
	end)
	local oldZ
	SS13.register_signal(controller, "mob_client_move_possessed_object", function(_, new_loc, direct)
		local newZ = new_loc:get_var("z")
		if newZ ~= oldZ then
			if oldZ then
				local oldZList = dead_players_by_zlevel:get(oldZ)
				oldZList:remove(controller)
			end
			if newZ then
				local newZList = dead_players_by_zlevel:get(newZ)
				newZList:add(controller)
			end
			oldZ = newZ
		end
		controller:call_proc("abstract_move", new_loc)
		return 1
	end)
	SS13.register_signal(controller, "parent_qdeleting", function()
		if oldZ then
			local zList = dead_players_by_zlevel:get(oldZ)
			zList:remove(controller)
		end
	end)
	if not ALLOW_TANK_SPAWN then
		return controller
	end
	local promotedTank
	local cooldown = 900
	grantAbility(controllerData, {
		name = "Promote Tank",
		icon = "https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/zombie.dmi",
		icon_state = "tank",
		abilityType = "targeted",
		cooldown = cooldown,
		onActivate = function(humanData, action, target)
			if SS13.is_valid(promotedTank) and promotedTank:get_var("stat") ~= 4 then
				controller:call_proc("balloon_alert", controller, "promoted tank still alive!")
				return 1
			end
			if not SS13.istype(target, "/mob/living/carbon/human") then
				controller:call_proc("balloon_alert", controller, "invalid target")
				return 1
			end
			local mutation = getZombieMutation(target)
			if not mutation or mutation.class ~= "Zombie (AI)" or not mutation.spawned then
				controller:call_proc("balloon_alert", controller, "invalid target")
				return 1
			end

			SS13.set_timeout(0, function()
				local objective = dm.global_proc("sanitize", SS13.await(SS13.global_proc, "tgui_input_text", controller, "Please input an objective for this tank", "Tank objective"))
				setClass(mutation, "Tank")
				local players = SS13.await(dm.global_vars:get_var("SSpolling"), "poll_ghost_candidates", "The mode is looking for volunteers to become a Tank to do the following: "..objective, nil, nil, 100, nil, true, target, target, "Tank")
				if not SS13.is_valid(target) then
					if SS13.is_valid(action) then
						action:call_proc("StartCooldownSelf", 1)
					end
					return
				end
				if not players or players.len == 0 then
					dm.global_proc("message_admins", "Not enough players volunteered for the Tank role.")
					setClass(mutation, "Zombie (AI)")
					if SS13.is_valid(action) then
						action:call_proc("StartCooldownSelf", 1)
					end
					return
				end
				local client = dm.global_proc("_pick_list", players)
				dm.global_proc("message_admins", "Selected "..dm.global_proc("key_name_admin", client).." for the role of tank.")
				local zombieMind = SS13.new("/datum/mind", client:get_var("key"))
				zombieMind:call_proc("transfer_to", target, true)
				promotedTank = target
				HandlerGroup.register_once(promotedTank, "living_death", function()
					if SS13.is_valid(action) then
						action:call_proc("StartCooldownSelf", cooldown * 10)
					end
				end)
				to_chat(promotedTank, "<span class='userdanger'>Your goal is to do the following: "..objective.."</span>")
			end)
		end
	})

	return controller
end

local function makePlayersVulnerable(position)
	local players = dm.global_proc("get_hearers_in_range", 6, position)
	if not players then
		return
	end
	for _, player in players:of_type("/mob/living/carbon/human") do
		local handler = HandlerGroup.new()
		handler:register_signal(player, "atom_expose_reagents", function(_, reagents)
			for reagent, amount in reagents do
				if SS13.istype(reagent, "/datum/reagent/toxin/acid/fluacid") then
					infectTarget(player)
				end
			end
		end)
		SS13.set_timeout(5, function()
			handler:clear()
		end)
	end
end

local ZOMBIE_AI = {}
CURRENT_ZOMBIE_AI_LIST = ZOMBIE_AI

local startAiControllerLoop = function()
	local currentRun = {}
	local resumed = false
	local currentLoop
	currentLoop = SS13.start_loop(0.5, -1, function()
		if __ZS_AI_LOOP ~= currentLoop then
			local exists_zombie = #ZOMBIE_AI > 0
			if not exists_zombie then
				SS13.end_loop(currentLoop)
				return
			end
		end
		if not resumed then
			currentRun = {}
			local i=(#ZOMBIE_AI + 1)
			while i > 1 do
				i = i - 1
				local zombie = ZOMBIE_AI[i]
				if not zombie.valid then 
					table.remove(ZOMBIE_AI, i)
					continue
				end
				if zombie.processing then
					table.insert(currentRun, zombie)
				end
			end
			resumed = true

		end

		local tickStart = dm.world:get_var("tick_usage")
		local timeStart = dm.world:get_var("time")
		local length = #currentRun
		while length > 0 do
			if tickLag(tickStart, timeStart) then
				return
			end
			local zombie = table.remove(currentRun)
			length -= 1
			zombie:execute()
		end

		resumed = false
	end)
	__ZS_AI_LOOP = currentLoop
end

local isZombieTarget = function(target)
	if isZombie(target) then
		return false
	end
	return SS13.istype(target, "/mob/living/carbon/human") or (SS13.istype(target, "/mob/living/silicon") and target:get_var("client"))
end
startAiControllerLoop()
local chasedTargets = {}
local mobRefToDatum = {}

CURRENT_CHASED_TARGETS = chasedTargets
CURRENT_MOB_REF_TO_DATUM = mobRefToDatum

local SSspacedrift = dm.global_vars:get_var("SSspacedrift")
local SSmove_manager = dm.global_vars:get_var("SSmove_manager")
local createZombieAi = function(zombieData)
	local zombieMob = zombieData.human
	local aiData = {
		processing = true,
		zombie = zombieMob,
		zombieData = zombieData,
		valid = true,
		tick = 0,
		crawler = math.random(1, 5) == 1,
		nextRandomWander = 100,
		setTarget = function(self, target)
			checkPerf(true)
			if self.target then
				self:clearTarget()
			end
			checkPerf(true)
			if self.pathingDatum then
				SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
			end
			checkPerf(true)
			self.target = target
			local targetRef = REF(target)
			local chasedTarget = chasedTargets[targetRef]
			checkPerf(true)
			if not chasedTarget then
				chasedTarget = 0
				mobRefToDatum[targetRef] = target
			end
			checkPerf(true)
			chasedTarget += 1
			chasedTargets[targetRef] = chasedTarget
			self.processing = true
		end,
		clearTarget = function(self)
			if not self.target then
				return
			end
			checkPerf(true)
			local targetRef = REF(self.target)
			checkPerf(true)
			local chasedTarget = chasedTargets[targetRef]
			checkPerf(true)
			if chasedTarget then
				chasedTarget -= 1
				if chasedTarget == 0 then
					chasedTargets[targetRef] = nil
					mobRefToDatum[targetRef] = nil
				else
					chasedTargets[targetRef] = chasedTarget
				end
			end
			checkPerf(true)
			if self.pathingDatum then
				SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
			end
			self.target = nil
		end,
		execute = function(self)
			startPerfTrack()
			if not SS13.is_valid(zombieMob) then
				self:cleanup()
				return
			end
			checkPerf()
			if not self.processing or not self.valid then
				return
			end
			if zombieMob:get_var("stat") ~= 0 then
				self.processing = false
				return
			end
			checkPerf()
			local worldTime = dm.world:get_var("time")
			self.nextClickOn = self.nextClickOn or 0
			if not SS13.istype(zombieMob:get_var("loc"), "/turf") then
				if self.pathingDatum then
					SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
				end
				SS13.set_timeout(0, function()
					zombieMob:call_proc("execute_resist")
				end)
				return
			end
			checkPerf()
			if zombieMob:get_var("body_position") == 1 then
				self.nextGetup = self.nextGetup or 0
				if worldTime > self.nextGetup then 
					SS13.set_timeout(0, function()
						zombieMob:call_proc("on_floored_end")
					end)
					self.nextGetup = worldTime + 50
				end
			end
			checkPerf()
			if hasTrait(zombieMob, "block_transformations") then
				if self.pathingDatum then
					SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
				end
				return
			end
			checkPerf()
			self.nextTargetSearch = self.nextTargetSearch or 0
			local closestTarget
			local zombieLocation = dm.global_proc("_get_step", zombieMob, 0)
			if not zombieLocation then
				return
			end
			if worldTime >= self.nextTargetSearch then
				self.nextTargetSearch = worldTime + 100
				local closestDist = 1000
				checkPerf()
				local potentialTargets = dm.global_proc("get_hearers_in_LOS", 7, zombieMob)
				checkPerf()
				for _, target in ipairs(potentialTargets:to_table()) do
					if not isZombieTarget(target) then
						continue
					end
					if target:get_var("stat") == 4 then
						continue
					end
					local location = dm.global_proc("_get_step", target, 0)
					local distance = dm.global_proc("_get_dist", zombieLocation, location)
					if distance > 4 then
						continue
					end
					if distance < closestDist then
						closestDist = distance
						closestTarget = target
					end
				end
				checkPerf()
				if not closestTarget then
					local tryGetTarget = function(table)
						for _, target in table do
							if not SS13.is_valid(target) then
								continue
							end
							local location = target
							if not SS13.istype(target, "/turf") then
								local location = dm.global_proc("_get_step", target, 0)
							end
							local distance = dm.global_proc("_get_dist", zombieLocation, location) 
							if distance > 9 then
								continue
							end
							if distance < closestDist then
								closestDist = distance
								closestTarget = target
							end
						end
					end
					checkPerf()
					tryGetTarget(zombieControllerTargets)
					checkPerf()
					-- if not closestTarget then
					-- 	checkPerf()
					-- 	tryGetTarget(mobRefToDatum)
					-- 	checkPerf()
					-- end
				end
				if not closestTarget and SS13.istype(self.target, "/turf") then
					self:clearTarget()
				end
			end

			if closestTarget and (not self.target or REF(self.target) ~= REF(closestTarget)) then
				if SS13.istype(closestTarget, "/turf") then
					checkPerf()
					self:setTarget(closestTarget)
					checkPerf()
				else
					checkPerf()
					self:setTarget(dm.global_proc("get_atom_on_turf", closestTarget))
					checkPerf()
				end
			end

			if self.pathingDatum then
				self.pathingDatum:set_var("delay", zombieMob:get_var("cached_multiplicative_slowdown"))
			end

			if not SS13.is_valid(self.target) then
				self:clearTarget()
				if worldTime >= self.nextRandomWander then
					SS13.start_loop(0, 1, function()
						if SS13.is_valid(self.target) then
							return
						end
						local dir = dm.global_proc("_pick_list", dm.global_vars:get_var("GLOB"):get_var("cardinals"))
						zombieMob:call_proc("Move", dm.global_proc("_get_step", zombieMob, dir), dir)
					end)
					self.nextRandomWander = worldTime + math.random(50, 100)
				end
				return
			end
			checkPerf()
			if (SS13.istype(self.target, "/mob/living") and self.target:get_var("stat") == 4) or isZombie(self.target) then
				self:clearTarget()
				return
			end
			checkPerf()
			local location = dm.global_proc("_get_step", self.target, 0)
			local distance = dm.global_proc("_get_dist", zombieLocation, location) 
			checkPerf()
			if distance >= 10 then
				self:clearTarget()
				return
			end
			checkPerf()

			if distance > 1 then
				self.nextClickOn = worldTime + 10
			end

			checkPerf()
			if (distance ~= -1 and distance <= 1) or zombieLocation == location then
				if worldTime >= self.nextClickOn and (zombieMob:get_var("body_position") ~= 1 or self.crawler)  then
					SS13.set_timeout(0, function()
						zombieMob:call_proc("ClickOn", self.target, {})
					end)
				end
			end
			checkPerf()

			if self.isPathing and self.pathingTarget ~= self.target then
				SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
			end

			if not self.isPathing and distance > 1 then 
				checkPerf()
				self.pathingDatum = SSmove_manager:call_proc("home_onto", zombieMob, self.target, zombieMob:get_var("cached_multiplicative_slowdown"), 1e31, SSspacedrift)
				self.isPathing = true
				self.pathingTarget = self.target
				local handler = HandlerGroup.new()
				handler:register_signal(zombieMob, "movable_moved_from_loop", function(_, moveLoop, oldDir, direction)
					local target = dm.global_proc("_get_step", zombieMob, oldDir)
					zombieMob:set_var("combat_mode", 1)
					local toClickOn
					for _, data in target:get_var("contents") do
						if isZombie(data) then
							continue
						end
						if data:get_var("density") == 1 and REF(data) ~= REF(zombieMob) then
							toClickOn = data
							if bit32.band(data:get_var("flags_1"), 8) ~= 0 then
								break
							end
						end
					end
					if toClickOn then
						SS13.set_timeout(0, function()
							zombieMob:call_proc("ClickOn", toClickOn, {})
						end)
					end
				end)
				SS13.register_signal(self.pathingDatum, "parent_qdeleting", function()
					self.isPathing = false
					self.pathingTarget = false
					self.pathingDatum = nil
					handler:clear()
				end)
				checkPerf()
			elseif distance <= 1 then
				checkPerf()
				SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
				checkPerf()
			end
		end,
		cleanup = function(self)
			self:clearTarget()
			SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
			self.valid = false
			self.processing = false
		end
	}
	if not hasTrait(zombieMob, "relaying_attacker") then
		zombieMob:call_proc("_AddElement", { SS13.type("/datum/element/relay_attackers") } )
	end
	RegisterClassSignal(zombieData, "atom_was_attacked", function(_, attacker, attack_flags)
		aiData.target = dm.global_proc("get_atom_on_turf", attacker)
	end)
	RegisterClassSignal(zombieData, "living_disarm_hit", function(_, attacker, attack_flags)
		zombieMob:call_proc("Knockdown", 20)
		zombieMob:call_proc("Paralyze", 20)
		SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
	end)
	local insideList = true
	RegisterClassSignal(zombieData, "mob_statchange", function(_, new_stat)
		if not aiData.valid then
			return
		end
		if new_stat ~= 0 then
			aiData.processing = false
			if insideList then
				for index, ref in ZOMBIE_AI do
					if ref == aiData then
						table.remove(ZOMBIE_AI, index)
					end
				end
				insideList = false
			end
			if aiData.pathingDatum then
				SSmove_manager:call_proc("stop_looping", zombieMob, SSspacedrift)
			end
			aiData:clearTarget()
		else
			aiData.processing = true
			if not insideList then
				table.insert(ZOMBIE_AI, aiData)
				insideList = true
			end
		end
	end)
	RegisterClassSignal(zombieData, "parent_qdeleting", function()
		aiData:cleanup()
	end)
	RegisterClassSignal(zombieData, "mob_login", function()
		SS13.set_timeout(0, function()
			dm.global_proc("to_chat", zombieMob, "<span class='userdanger'>Your body is being controlled by a zombie! Wait until the zombification is cured.</span>")
			zombieMob:call_proc("ghostize", true)
		end)
	end)
	table.insert(ZOMBIE_AI, aiData)
	return aiData
end

ABILITIES = {
	["boomer_explode"] = {
		name = "Detonate yourself",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_slime.dmi",
		icon_state = "gel_cocoon",
		abilityType = "normal",
		cooldown = 10,
		onActivate = function(humanData, action)
			SS13.set_timeout(0, function()
				humanData.classData:explode(humanData, false, 1)
			end)
		end
	},
	["boomer_spew"] = {
		name = "Spew bile",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_slime.dmi",
		icon_state = "consume",
		abilityType = "targeted",
		cooldown = 30,
		onActivate = function(humanData, action, target)
			SS13.set_timeout(0, function()
				dm.global_proc("playsound", humanData.human, "sound/effects/splat.ogg", 100, true)
				local fluidGroup = SS13.new_untracked("/datum/fluid_group", 9)
				local position = humanData.human:call_proc("drop_location")
				local targetTurfs = dm.global_proc("get_line", position, target)
				makePlayersVulnerable(position)
				local currentDirection
				local previousTurf = position
				local endLoop = false
				local turfTarget
				local timer = SS13.start_loop(0.1, 5, function(i)
					if endLoop then
						return
					end
					if turfTarget then
						previousTurf = turfTarget
					end
					if i >= targetTurfs.len - 1 then
						turfTarget = dm.global_proc("_get_step", previousTurf, currentDirection)
					else
						turfTarget = targetTurfs:get(i+1)
						currentDirection = dm.global_proc("_get_dir", previousTurf, turfTarget)
					end

					local atmosAdjacentTurfs = turfTarget:get_var("atmos_adjacent_turfs")
					local canPass = false
					if atmosAdjacentTurfs and not atmosAdjacentTurfs:get(previousTurf) then
						canPass = true
					end
					local prevAtmosAdjacentTurfs = previousTurf:get_var("atmos_adjacent_turfs")
					if atmosAdjacentTurfs and prevAtmosAdjacentTurfs then
						for _, turf in atmosAdjacentTurfs do
							for _, turf2 in prevAtmosAdjacentTurfs do
								if REF(turf) == REF(turf2) then
									canPass = true
									break
								end
							end
							if canPass then
								break
							end
						end
					end

					if not canPass then
						SS13.end_loop(timer)
						endLoop = true
						return
					end

					local spawnFluid = function(position)
						local foo = SS13.new_untracked("/obj/effect/particle_effect/fluid/foam/short_life", position, fluidGroup)
						foo:set_var("color", "#5050FF")
						foo:get_var("reagents"):call_proc("add_reagent", SS13.type("/datum/reagent/toxin/acid/fluacid"), 30)
					end
					local angle = 225
					if currentDirection == 1 or currentDirection == 2 or currentDirection == 4 or currentDirection == 8 then
						angle = 90
					end
					spawnFluid(dm.global_proc("_get_step", turfTarget, dm.global_proc("_turn", currentDirection, angle)))
					spawnFluid(turfTarget)
					spawnFluid(dm.global_proc("_get_step", turfTarget, dm.global_proc("_turn", currentDirection, -angle)))
				end)
			end)
		end
	},
	["smoker_hook"] = {
		name = "Entangle",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_cult.dmi",
		icon_state = "carve",
		abilityType = "targeted",
		cooldown = 15,
		onActivate = function(humanData, action, target)
			if hasTrait(humanData.human, "immobilized") then
				return BLOCK_ACTIVATION
			end
			SS13.set_timeout(0, function()
				SS13.qdel(humanData.meathook)
				humanData.meathook = SS13.new("/obj/item/ammo_casing/magic/hook", humanData.human)
				SS13.register_signal(humanData.meathook, "fire_casing", function(_, _, _, _, _, _, _, _, _, thrown_proj)
					if not SS13.is_valid(thrown_proj) then
						return
					end
					-- thrown_proj:set_var("icon_state", "lobster_claw")
					-- local chain = thrown_proj:get_var("initial_chain")
					-- chain:set_var("icon_state", "tentacle")
					-- chain:get_var("visuals"):set_var("icon_state", "tentacle")
					-- local uiBlockedCallback
					-- uiBlockedCallback = SS13.register_signal(humanData.human, "addtrait uiblocked", function()
					-- 	SS13.unregister_signal(humanData.human, "addtrait uiblocked", uiBlockedCallback)
					-- 	for _, source in humanData.human:get_var("_status_traits"):get("uiblocked") do
					-- 		local thing = dm.global_proc("_locate", source)
					-- 		if not thing or not SS13.istype(thing, "/datum/hook_and_move") then
					-- 			continue
					-- 		end
					-- 		local chain = thing:get_var("return_chain")
					-- 		chain:set_var("icon_state", "tentacle")
					-- 		chain:get_var("visuals"):set_var("icon_state", "tentacle")
					-- 	end
					-- end)
					SS13.register_signal(thrown_proj, "projectile_self_on_hit", function(_, firer, target, Angle, hit_limb_zone, blocked)
						SS13.set_timeout(0, function()
							-- if SS13.is_valid(humanData.human) then
							-- 	SS13.unregister_signal(humanData.human, "addtrait uiblocked", uiBlockedCallback)
							-- end
							if not hasTrait(target, "hooked") then
								return
							end
							dm.global_proc("_add_trait", target, "block_transformations", "zs_hooked")
							HandlerGroup.register_once(target, "removetrait hooked", function()
								dm.global_proc("_remove_trait", target, "block_transformations", "zs_hooked")
							end)
						end)
					end)
				end)
				humanData.meathook:call_proc("fire_casing", target, humanData.human, nil, nil, nil, "chest", 0, humanData.human)

				dm.global_proc("playsound", humanData.human, "sound/weapons/batonextend.ogg", 100)
			end)
		end
	},
	["tank_roar"] = {
		name = "Roar",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_items.dmi",
		icon_state = "berserk_mode",
		abilityType = "normal",
		cooldown = 15,
		onActivate = function(humanData, action, target)
			local sound = tankRoarSounds[math.random(#tankRoarSounds)]
			dm.global_proc("playsound", humanData.human, sound, 80, true, 15, 1.5, nil, 0, true, true, 8)
			SS13.set_timeout(0, function()
				humanData.human:call_proc("emote", "me", 1, "roars!", true)
			end)
		end
	},
	["jockey_leap"] = {
		name = "Leap",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_items.dmi",
		icon_state = "jetboot",
		abilityType = "targeted",
		cooldown = 15,
		onActivate = function(humanData, action, target)
			if SS13.is_valid(humanData.riding) then
				return BLOCK_ACTIVATION
			end
			SS13.set_timeout(0, function()
				dm.global_proc("playsound", humanData.human, "sound/weapons/fwoosh.ogg", 100, true)
				HandlerGroup.register_once(humanData.human, "movable_pre_impact", function(human, hit_target, thrownthing)
					if not SS13.istype(hit_target, "/mob/living/carbon/human") or hasTrait(hit_target, "zs_being_ridden") or isZombie(hit_target) or hasTrait(hit_target, "floored") then
						return
					end
					human:set_var("remote_control", hit_target)
					human:set_var("pixel_z", 12)
					human:set_var("layer", 4.1)
					human:call_proc("forceMove", hit_target:get_var("loc"))
					hit_target:call_proc("add_traits", { "block_transformations", "zs_being_ridden", "sleep_immunity" }, "zombie_riding")
					hit_target:set_var("mobility_flags", bit32.band(hit_target:get_var("mobility_flags"), bit32.bnot(384)))
					humanData.riding = hit_target
					local cooldown = 0
					local cancelRiding
					local ridingHandler = HandlerGroup.new()
					ridingHandler:register_signal(hit_target, "atom_relaymove", function(_, user, direction)
						if REF(user) ~= REF(human) then
							return
						end
						local worldTime = dm.world:get_var("time")
						if worldTime < cooldown then
							return 1
						end
						hit_target:call_proc("Move", dm.global_proc("_get_step", user, direction))
						cooldown = worldTime + 10
						return 1
					end)
					ridingHandler:register_signal(hit_target, "mob_statchange", function(_, new_stat)
						if new_stat ~= 0 then
							cancelRiding()
						end
					end)
					ridingHandler:register_signal(hit_target, "movable_moved", function(_, oldloc, dir)
						if REF(human:get_var("remote_control")) ~= REF(hit_target) then
							cancelRiding()
							return
						end
						human:call_proc("setDir", dir)
						human:call_proc("forceMove", hit_target:get_var("loc"))
					end)
					ridingHandler:register_signal(hit_target, "parent_qdeleting", function()
						cancelRiding()
					end)
					ridingHandler:register_signal(human, "parent_qdeleting", function()
						cancelRiding()
					end)
					ridingHandler:register_signal(human, "mob_statchange", function(_, new_stat)
						if new_stat ~= 0 then
							cancelRiding()
						end
					end)
					ridingHandler:register_signal(hit_target, "addtrait floored", function()
						cancelRiding()
					end)
					ridingHandler:register_signal(human, "addtrait floored", function()
						cancelRiding()
					end)
					local dismount = {
						name = "Dismount",
						icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_minor_antag.dmi",
						icon_state = "infect",
						abilityType = "normal",
						cooldown = 0,
						onActivate = function()
							cancelRiding()
						end
					}
					hit_target:call_proc("emote", "scream")
					local timerId = SS13.start_loop(5, -1, function()
						hit_target:call_proc("emote", "scream")
					end)
					local dismountAbility
					cancelRiding = function()
						ridingHandler:clear()
						human:set_var("remote_control", nil)
						human:set_var("pixel_z", 0)
						humanData.riding = nil
						hit_target:call_proc("remove_traits", { "block_transformations", "zs_being_ridden", "sleep_immunity" }, "zombie_riding")
						hit_target:set_var("mobility_flags", bit32.bor(hit_target:get_var("mobility_flags"), 384))
						SS13.end_loop(timerId)
						SS13.qdel(dismountAbility)
					end
					dismountAbility = grantAbility(humanData, dismount)
				end)
				humanData.human:call_proc("throw_at", target, 5, 3, humanData.human, false, false, nil, 2000, true)
				SS13.set_timeout(5, function()
					if SS13.is_valid(humanData.human) then
						SS13.unregister_signal(humanData.human, "movable_pre_impact", callback)
					end
				end)
			end)
		end
	},
}

local zombieMutIcons = {}
local setIcon = function(humanData, icon)
	local zombieIcon = zombieMutIcons[icon]
	if not zombieIcon then
		zombieIcon = SS13.new("/mutable_appearance")
		zombieIcon:set_var("icon", loadIcon("https://raw.githubusercontent.com/tgstation/auxlua-cookbook/master/waltermeldron/assets/zombie/zombie.dmi"))
		zombieIcon:set_var("icon_state", icon)
		zombieIcon:set_var("appearance_flags", 837)
		zombieMutIcons[icon] = zombieIcon
	end
	humanData.human:set_var("alpha", 0)
	humanData.human:call_proc("add_overlay", zombieIcon)
	humanData.zombieIcon = zombieIcon
end

local resetIcon = function(humanData)
	humanData.human:set_var("alpha", 255)
	humanData.human:call_proc("cut_overlay", humanData.zombieIcon)
end

CLASSES = {
	["Non-Zombie"] = {
		human = true,
		abilities = {},
		onGain = function(self, humanData)
			RegisterClassSignal(humanData, "atom_entered", function(human, entered)
				if hasTrait(entered, "zs_zombie_cure") then
					SS13.set_timeout(0, function()
						local tumour = human:call_proc("get_organ_slot", "zombie_infection")
						if SS13.is_valid(tumour) then
							SS13.qdel(tumour)
							dm.global_proc("to_chat", human, "<span class='notice'>You feel a wave of relief and tranquility, and your mind feels clear.</span>")
						end
						human:call_proc("setToxLoss", 0)
						SS13.qdel(entered)
					end)
				end
			end)
			RegisterClassSignal(humanData, "carbon_gain_organ", function(_, organ, special)
				if SS13.istype(organ, "/obj/item/organ/internal/zombie_infection") then
					-- Adds ORGAN_UNREMOVABLE and ORGAN_HIDDEN
					organ:set_var("organ_flags", bit32.bor(organ:get_var("organ_flags"), 768))
				end
			end)
		end,
	},
	["Zombie Controller"] = {
		onGain = function(self, humanData)
			local mind = humanData.human:get_var("mind")
			local controller = makeZombieController(humanData.human:get_var("loc"))
			if mind then
				mind:call_proc("transfer_to", controller)
			end
			SS13.qdel(humanData.human)
		end
	},
	["Zombie"] = {
		derived = "Zombie (AI)",
		aiEnabled = false
	},
	["Zombie (AI)"] = {
		slowdown = 0.75,
		slowdownRandom = 0.5,
		damageResist = 0,
		noRevive = true,
		aiEnabled = true,
		onGain = function(self, humanData)
			if self.aiEnabled then
				local aiData = createZombieAi(humanData)
				humanData.zombieAi = aiData
				SS13.set_timeout(0, function()
					humanData.human:call_proc("ghostize", true)
				end)
			end
			local head = humanData.human:call_proc("get_bodypart", "head")
			if head then
				head:set_var("bodypart_flags", bit32.bor(head:get_var("bodypart_flags"), 1))
			end
			RegisterClassSignal(humanData, "atom_entered", function(human, entered)
				if hasTrait(entered, "zs_zombie_cure") then
					SS13.set_timeout(0, function()
						if human:get_var("stat") ~= 4 then
							human:call_proc("death")
						end
						local humanMind = human:call_proc("notify_revival", "You are being unzombified!")
						human:call_proc("grab_ghost")
						if humanData.zombieAi then
							humanData.zombieAi:cleanup()
							humanData.zombieAi = nil
						end
						local tumour = human:call_proc("get_organ_slot", "zombie_infection")
						if SS13.is_valid(tumour) then
							SS13.qdel(tumour)
							dm.global_proc("to_chat", human, "<span class='notice'>You feel a wave of relief and tranquility, and your mind feels clear.</span>")
						end
						SS13.qdel(entered)
						setClass(humanData, "Non-Zombie")
					end)
				end
			end)
		end,
		onLoss = function(self, humanData)
			if humanData.zombieAi then
				humanData.zombieAi:cleanup()
				humanData.zombieAi = nil
			end
			local head = humanData.human:call_proc("get_bodypart", "head")
			if head then
				head:set_var("bodypart_flags", bit32.band(head:get_var("bodypart_flags"), bit32.bnot(1)))
			end
		end
	},
	["Boomer"] = {
		abilities = {
			"boomer_explode",
			"boomer_spew"
		},
		explode = function(self, humanData, gibbed, extraRange)
			local human = humanData.human
			dm.global_proc("playsound", humanData.human, "sound/effects/splat.ogg", 100, true)
			local position = human:call_proc("drop_location")
			makePlayersVulnerable(position)
			if not gibbed or gibbed == 0 then
				human:call_proc("gib")
			end
			dm.global_proc("explosion", position, 0, 0, 3, 0, 5)
			local foo = SS13.new("/datum/effect_system/fluid_spread/foam/short")
			foo:call_proc("set_up", 2 + extraRange)
			foo:set_var("location", position)
			foo:get_var("chemholder"):call_proc("add_reagent", SS13.type("/datum/reagent/toxin/acid/fluacid"), 15)
			foo:call_proc("start")
		end,
		onGain = function(self, humanData)
			humanData.human:set_var("resistance_flags", 48)
			setIcon(humanData, "boomer")
			RegisterClassSignal(humanData, "living_death", function(human, gibbed)
				SS13.set_timeout(0, function()
					self:explode(humanData, gibbed, 0)
				end)
			end)
			RegisterClassSignal(humanData, "atom_expose_reagents", function(_, reagents)
				for reagent, amount in reagents do
					if SS13.istype(reagent, "/datum/reagent/toxin/acid/fluacid") then
						return 1
					end
				end
			end)
		end,
		onLoss = function(self, humanData)
			resetIcon(humanData)
			humanData.human:set_var("resistance_flags", 0)
			SS13.stop_tracking(humanData.zombieBoomer)
		end
	},
	["Jockey"] = {
		slowdown = -1.5,
		damage = 11,
		noRevive = true,
		abilities = {
			"jockey_leap"
		},
		traits = {
			"passtable",
			"ventcrawler_always"
		},
		onGain = function(self, humanData)
			setIcon(humanData, "jockey")
			humanData.human:set_var("pass_flags", 1)
		end,
		onLoss = function(self, humanData)
			resetIcon(humanData)
			humanData.human:set_var("pass_flags", 0)
		end
	},
	["Smoker"] = {
		damage = 31,
		slowdown = 0.5,
		abilities = {
			"smoker_hook"
		},
		noRevive = true,
		onGain = function(self, humanData)
			setIcon(humanData, "smoker")
		end,
		onLoss = function(self, humanData)
			resetIcon(humanData)
		end
	},
	["Tank"] = {
		slowdown = 0,
		damage = 30,
		damageResist = 50,
		noRevive = true,
		traits = {
			"ignoredamageslowdown",
			"shock_immunity",
			"push_immunity",
			"stun_immunity",
			"baton_resistance",
			"resist_high_pressure",
			"resist_low_pressure",
			"bomb_immunity",
			"rad_immunity",
			"no_blood_overlay",
			"no_stagger",
			"noslip_all",
			"noflash"
		},
		abilities = {
			"tank_roar"
		},
		onGain = function(self, humanData)
			setIcon(humanData, "tank")
			local sound = tankRoarSounds[math.random(#tankRoarSounds)]
			dm.global_proc("playsound", humanData.human, sound, 80, true, 15, 1.5, nil, 0, true, true, 8)
			for _, item in humanData.human:get_var("held_items") do
				if SS13.istype(item, "/obj/item/mutant_hand/zombie") then
					RegisterClassSignal(humanData, item, "item_afterattack", function(_, target, user, proximity, click_params)
						if proximity == 0 then
							return
						end
						local position = dm.global_proc("_get_step", user, 0)
						local direction = dm.global_proc("_get_dir", user, target)
						if SS13.istype(target, "/mob") then
							local targetTurf = position
							for i=1, 8 do
								targetTurf = dm.global_proc("_get_step", targetTurf, direction)
							end
							target:call_proc("Knockdown", 20)
							target:call_proc("throw_at", targetTurf, 8, 2)
						end

						if SS13.istype(target, "/turf/closed/wall") then
							humanData.human:call_proc("UnarmedAttack", target, 1, {})
						end
					end)
				end
			end
			local stepCount = 0
			local nextPlay = 0
			humanData.human:call_proc("_RemoveElement", { SS13.type("/datum/element/footstep"), "footstep_human", 1, -6 })
			RegisterClassSignal(humanData, "movable_moved", function(_, target)
				local worldTime = dm.world:get_var("time")
				if humanData.human:get_var("body_position") == 1 then
					return
				end
				stepCount += 1
				if stepCount < 2 then
					return
				end
				if nextPlay > worldTime then
					return
				end
				nextPlay = worldTime + 6
				local sound = tankFootstepSound[math.random(#tankFootstepSound)]
				dm.global_proc("playsound", humanData.human, sound, 20, true, 15, 1.5, nil, 0, true, true, 8)
				stepCount = 0
			end)
			RegisterClassSignal(humanData, "living_death", function()
				local sound = tankDeathSound[math.random(#tankDeathSound)]
				dm.global_proc("playsound", humanData.human, sound, 40, true, 15, 1.5, nil, 0, true, true, 8)
			end)
			humanData.human:call_proc("_AddElement", { SS13.type("/datum/element/wall_tearer"), true, 80, 3 })
			humanData.human:set_var("status_flags", 0)
		end,
		onLoss = function(self, humanData)
			humanData.human:call_proc("_AddElement", { SS13.type("/datum/element/footstep"), "footstep_human", 1, -6 })
			humanData.human:set_var("status_flags", 15)
			resetIcon(humanData)
		end,
	}
}

local LOADING = {}
for className, class in CLASSES do
	if class.derived then
		LOADING[className] = class
	end
end

local allLoaded = false
local attempts = 0
while not allLoaded and attempts < 100 do
	allLoaded = true
	for className, class in LOADING do
		if not class.derived then
			LOADING[className] = nil
			continue
		end

		local derivedClass = CLASSES[class.derived]
		if LOADING[derivedClass] then
			allLoaded = false
			continue
		end

		for key, value in derivedClass do
			if class[key] == nil then
				class[key] = value
			end
		end
		LOADING[className] = nil
	end
	attempts += 1
end

if attempts >= 100 then
	print("Something wrong with the class structure!")
end

local REF = function(target)
	return dm.global_proc("REF", target)
end

local createHref = function(target, args, content)
	brackets = brackets == nil and true or false
	return "<a href='?src="..dm.global_proc("REF", target)..";"..args.."'>"..content.."</a>"
end

local function labelDisplay(label_name, content)
	return "<div style='display: flex; margin-top: 4px;'><div style='flex-grow: 1; color: #98B0C3;'>"..label_name..":</div><div>"..content.."</div></div>"
end

local function getReadablePerfStat(number)
	return tostring(math.floor(number * 1000000) / 1000)
end

local function openMobSettings(user, humanData)
	local userCkey = user:get_var("ckey")
	local browser = SS13.new_untracked("/datum/browser", user, "SettingsMenu", "SettingsMenu", 300, 300)
	local data = ""
	data = data.."<h1>Settings Menu</h1></hr>"
	data = data..labelDisplay("Refresh", createHref(humanData.human, "refresh=1", "Refresh"))
	data = data..labelDisplay("Cure", createHref(humanData.human, "spawn_cure=1", "Spawn Cure Crate"))
	data = data..labelDisplay("Cure", createHref(humanData.human, "spawn_cure_spawner=1", "Spawn Cure Spawner"))
	data = data..labelDisplay("Zombie AI", createHref(humanData.human, "spawn_zombie_ai=1", "Spawn Zombie AI"))
	data = data..labelDisplay("Zombie Spawner", createHref(humanData.human, "spawn_zombie_spawner=1", "Spawn Zombie Spawner"))
	data = data..labelDisplay("Supplies", createHref(humanData.human, "spawn_supply_crate=1", "Spawn Supply Crate"))
	data = data..labelDisplay("Supplies", createHref(humanData.human, "spawn_supply_crate=1;timed=1", "Spawn Timed Supply Crate"))
	data = data.."</hr>"
	data = data.."<b>TOTAL ZOMBIE AI: "..tostring(#ZOMBIE_AI).."</b><br>"
	local prevLine
	local TIME_AVG_KEYS = {}
	for key, value in TIME_AVG do
		table.insert(TIME_AVG_KEYS, key)
	end
	table.sort(TIME_AVG_KEYS)
	for _, line in ipairs(TIME_AVG_KEYS) do
		local avg = TIME_AVG[line]
		local total = TOTAL_TIME_TAKEN[line]
		local count = TOTAL_CALL_COUNT[line]
		if not prevLine then
			prevLine = line
			continue
		end
		local isSleeping = SLEEPING_AT[line]
		local status = " "
		if isSleeping then
			status = "S"
		end
		data = data..tostring(prevLine).."-"..line.." ["..status.."]: "..getReadablePerfStat(avg).." | "..getReadablePerfStat(total).." | "..tostring(count).."<br>"
		prevLine = line
	end
	browser:call_proc("set_content", data)
	browser:call_proc("open")
end

local damageTypes = {
	"bleed_mod",
	"brain_mod",
	"burn_mod",
	"brute_mod",
	"cold_mod",
	"heat_mod",
	"hunger_mod",
	"oxy_mod",
	"pressure_mod",
	"stamina_mod",
	"siemens_coeff",
	"tox_mod",
}

setClass = function(humanData, class)
	local previousClass = CLASSES[humanData.class]
	if previousClass.onLoss then
		previousClass:onLoss(humanData)
	end
	for _, callback in humanData.classCleanup do
		if type(callback) == 'function' then
			callback()
		else
			SS13.unregister_signal(callback.target, callback.signal, callback.callback)
		end
	end
	humanData.classCleanup = {}
	if previousClass.traits then
		humanData.human:call_proc("remove_traits", previousClass.traits, "zs_class")
	end
	humanData.class = nil
	humanData.human:call_proc("remove_movespeed_modifier", SS13.type("/datum/movespeed_modifier/admin_varedit"))
	SS13.unregister_signal(humanData.human, "mob_ability_base_started")
	for _, item in humanData.human:get_var("held_items") do
		if SS13.istype(item, "/obj/item/mutant_hand/zombie") then
			item:set_var("force", 21)
		end
	end
	if previousClass.damageResist then
		local phys = humanData.human:get_var("physiology")
		for _, damageType in damageTypes do
			if damageType == "siemens_coeff" then
				phys:set_var(damageType, phys:get_var(damageType) + 0.8)
			else
				phys:set_var(damageType, phys:get_var(damageType) + 0.01 * previousClass.damageResist)
			end
		end
	end
	if class == nil then
		return
	end
	local newClass = CLASSES[class]
	local abilities = newClass.abilities or {}
	local abilityDatums = {}
	for _, ability in abilities do
		table.insert(abilityDatums, grantAbility(humanData, ABILITIES[ability]))
	end
	table.insert(humanData.classCleanup, function()
		for _, abilityDatum in abilityDatums do
			SS13.qdel(abilityDatum)
		end
	end)
	humanData.class = class
	humanData.classData = newClass
	if newClass.slowdown then
		local slowdown = newClass.slowdown
		if newClass.slowdownRandom then
			local addedSlowdown = math.floor((math.random() * newClass.slowdownRandom) * 1000) / 1000
			if math.random(0, 1) == 1 then
				addedSlowdown = -addedSlowdown
			end
			slowdown += addedSlowdown
		end
		humanData.human:call_proc("add_or_update_variable_movespeed_modifier", SS13.type("/datum/movespeed_modifier/admin_varedit"), true, newClass.slowdown)
	end
	if isZombie(humanData.human) then
		if newClass.human then
			if humanData.oldSpecies then
				humanData.human:call_proc("set_species", humanData.oldSpecies)
			else
				humanData.human:call_proc("set_species", SS13.type("/datum/species/human"))
			end

			humanData.human:set_var("voice", humanData.oldVoice)
		end
	else
		if not newClass.human then
			humanData.human:call_proc("set_species", SS13.type("/datum/species/zombie/infectious"))
			humanData.oldVoice = humanData.human:get_var("voice")
			humanData.human:set_var("voice", "Man (Big)")
		end
	end

	if isZombie(humanData.human) then
		if newClass.damage then
			for _, item in humanData.human:get_var("held_items") do
				if SS13.istype(item, "/obj/item/mutant_hand/zombie") then
					item:set_var("force", newClass.damage)
				end
			end
		end
		local infection = humanData.human:call_proc("get_organ_slot", "zombie_infection")
		if newClass.noRevive then
			if infection:get_var("old_species") then
				humanData.oldSpecies = infection:get_var("old_species")
			end
			infection:set_var("old_species", nil)
		else
			infection:call_proc("UnregisterSignal", humanData.human, "living_death")
		end
		humanData.human:call_proc("remove_traits", { "nodeath" }, "species")
	end
	if newClass.traits then
		humanData.human:call_proc("remove_traits", newClass.traits, "zs_class")
	end
	if newClass.damageResist then
		local phys = humanData.human:get_var("physiology")
		for _, damageType in damageTypes do
			if damageType == "siemens_coeff" then
				phys:set_var(damageType, phys:get_var(damageType) - 0.8)
			else
				phys:set_var(damageType, phys:get_var(damageType) - 0.01 * newClass.damageResist)
			end
		end
	end
	if newClass.onGain then
		newClass:onGain(humanData)
	end
end

local createCureInjector = function(location)
	local implanter = SS13.new("/obj/item/implanter", location)
	implanter:set_var("name", "biocure injector")
	implanter:set_var("desc", "An injector that cures PAX-201, commonly known for causing zombification, within humans")
	local cure = SS13.new("/obj/item/implant")
	cure:set_var("allow_multiple", true)
	cure:set_var("name", "pax-201 cure")
	implanter:set_var("imp", cure)
	implanter:call_proc("update_appearance")
	cure:call_proc("add_traits", { "zs_zombie_cure" }, "innate")
	return implanter
end

local function setupZombieMutation(human)
	local humanRef = REF(human)
	if ALL_HUMAN_DATA[humanRef] then
		setClass(ALL_HUMAN_DATA[humanRef], nil)
	end
	local humanData = {
		human = human,
		class = "Non-Zombie",
		classCleanup = {}
	}
	if IS_LOCAL and human:get_var("ckey") == admin then
		sleep()
		setClass(humanData, LOCAL_CLASS)
	else
		if isZombie(human) then
			setClass(humanData, "Zombie")
		else
			setClass(humanData, "Non-Zombie")
		end
	end
	ALL_HUMAN_DATA[humanRef] = humanData
	SS13.unregister_signal(human, "ctrl_click")
	SS13.unregister_signal(human, "species_gain")
	SS13.unregister_signal(human, "species_loss")
	SS13.unregister_signal(human, "atom_examine")
	SS13.unregister_signal(human, "handle_topic")
	SS13.unregister_signal(human, "parent_preqdeleted")
	SS13.register_signal(human, "atom_examine", function(_, examining_mob, examine_list)
		if SS13.istype(examining_mob, "/mob/dead") or examining_mob:get_var("ckey") == admin then
			examine_list:add("<hr/><span class='notice'>Class: "..humanData.class.."</span>")
			local infectionStatus = "Not infected"
			local infection = human:call_proc("get_organ_slot", "zombie_infection")
			if SS13.is_valid(infection) then
				infectionStatus = "<span class='danger'>Infected</span>"
			end
			examine_list:add("<span class='notice'>Infection Status: "..infectionStatus.."</span>")
			if examining_mob:get_var("ckey") == admin then
				examine_list:add("<span class='notice'>"..createHref(human, "settings=1", "Open settings menu").."</span>")
			end
			examine_list:add("<hr/>")
		end
	end)
	SS13.register_signal(human, "species_loss", function(_, lost_species)
		if SS13.istype(lost_species, "/datum/species/zombie/infectious") then
			setClass(humanData, "Non-Zombie")
		end
	end)
	SS13.register_signal(human, "handle_topic", function(_, user, href_list)
		SS13.set_timeout(0, function()
			if user:get_var("ckey") ~= admin then
				return
			end

			if href_list:get("settings") or href_list:get("refresh") then
				openMobSettings(user, humanData)
			end

			if href_list:get("spawn_supply_crate") then
				local pod = dm.global_proc("podspawn", {
					target = user:get_var("loc"),
					style = 3,
				})

				local crate = SS13.new("/obj/structure/closet/crate/secure/gear", pod)
				crate:set_var("name", "secure supply crate")

				if href_list:get("timed") then
					crate:set_var("req_access", { "admin" })
					crate:set_var("anchored", true)
					crate:call_proc("say", "Disengaging secure locks in 30 seconds")
					SS13.start_loop(10, 3, function(i)
						if not SS13.is_valid(crate) then
							return
						end
						if i == 3 then
							crate:call_proc("bust_open")
							crate:call_proc("say", "Secure locks disengaged.")
						else
							crate:call_proc("say", "Disengaging secure locks in "..tostring(3-i).."0 seconds")
						end
					end)
				end

				for i = 1, 4 do
					SS13.new_untracked("/obj/item/gun/energy/laser", crate)
				end
				for i = 1, 2 do
					SS13.new_untracked("/obj/item/defibrillator/compact/loaded", crate)
				end
				for i = 1, 3 do
					SS13.new_untracked("/obj/item/storage/medkit/tactical_lite", crate)
				end
			elseif href_list:get("spawn_cure") then
				local crate = SS13.new("/obj/structure/closet/crate/secure/freezer", user:get_var("loc"))
				crate:set_var("base_icon_state", "freezer")
				crate:set_var("icon_state", "freezer")
				crate:set_var("name", "secure biocrate")

				for i = 1, 5 do
					createCureInjector(crate)
				end
			elseif href_list:get("spawn_cure_spawner") then
				local crate = SS13.new("/obj/structure/closet/crate/secure/freezer", user:get_var("loc"))
				crate:set_var("base_icon_state", "freezer")
				crate:set_var("icon_state", "freezer")
				crate:set_var("name", "biocure generator")
				crate:set_var("anchored", true)
				local crateLoop = SS13.start_loop(5, -1, function()
					if not SS13.is_valid(crate) then
						return
					end
					local hitLimit = function(location)
						local count = 0
						for _, item in location:get_var("contents") do
							if SS13.istype(item, "/obj/item/implanter") then
								count += 1
							end
						end

						if count >= 5 then
							return true
						end
						return false
					end
					if crate:get_var("opened") == 1 then
						local location = crate:get_var("loc")
						if not hitLimit(location) then
							createCureInjector(location)
							local sparks = SS13.new("/datum/effect_system/spark_spread/quantum")
							sparks:call_proc("set_up", 2, true, crate)
							sparks:call_proc("attach", location)
							sparks:call_proc("start")
						end
					else
						if not hitLimit(crate) then
							createCureInjector(crate)
						end
					end
				end)
				SS13.register_signal(crate, "parent_qdeleting", function()
					SS13.end_loop(crateLoop)
				end)
			elseif href_list:get("spawn_zombie_ai") then
				local zombo = SS13.new("/mob/living/carbon/human", user:get_var("loc"))
				local zomboData = getZombieMutation(zombo)
				if not zomboData then
					zomboData = setupZombieMutation(zombo)
				end
				zomboData.spawned = true
				zombo:call_proc("equipOutfit", SS13.type("/datum/outfit/job/assistant"))
				setClass(zomboData, "Zombie (AI)")
			elseif href_list:get("spawn_zombie_spawner") then
				local totalZombies = 0
				local zombieSpawn = SS13.new("/obj/structure/geyser", user:get_var("loc"))
				zombieSpawn:set_var("name", "biological lump")
				zombieSpawn:set_var("color", "#008000")
				if not DESTRUCTIBLE_SPAWNERS then
					zombieSpawn:set_var("resistance_flags", 499)
				end
				zombieSpawn:set_var("anchored", true)
				zombieSpawn:set_var("layer", 4.1)
				zombieSpawn:set_var("pixel_y", -4)

				local spawnZombieFunc = function(force, forceSpecial)
					if not SS13.is_valid(zombieSpawn) then
						return
					end
					if totalZombies >= 5 and not force then
						return
					end
					local spawnLocation = zombieSpawn:get_var("loc")
					local zombieClass = "Zombie (AI)"
					local zombieMind
					if math.random(1, 10) == 1 or forceSpecial then
						local class = dm.global_proc("_pick_list", { "Boomer", "Jockey", "Smoker" })
						local players = SS13.await(dm.global_vars:get_var("SSpolling"), "poll_ghost_candidates", "The mode is looking for volunteers to become a "..class, nil, nil, 300, nil, true, zombieSpawn, zombieSpawn, class)
						if not players or players.len == 0 then
							dm.global_proc("message_admins", "Not enough players volunteered for the "..class.." role.")
							return
						end
						local client = dm.global_proc("_pick_list", players)
						dm.global_proc("message_admins", "Selected "..dm.global_proc("key_name_admin", client).." for the role of "..class..".")
						zombieMind = SS13.new("/datum/mind", client:get_var("key"))
						zombieClass = class
					end

					local zombo = SS13.new("/mob/living/carbon/human", spawnLocation)
					local zomboData = getZombieMutation(zombo)
					if not zomboData then
						zomboData = setupZombieMutation(zombo)
					end
					zomboData.spawned = true
					zombo:call_proc("equipOutfit", SS13.type("/datum/outfit/job/assistant"))
					if zombieMind then
						zombieMind:call_proc("transfer_to", zombo, true)
					end
					setClass(zomboData, zombieClass)
					totalZombies += 1
					dm.global_proc("_add_trait", zombo, "block_transformations", "zs_spawner")
					zombo:set_var("plane", getPlane(-6, spawnLocation))
					zombo:set_var("pixel_z", -32)
					zombo:set_var("anchored", true)
					dm.global_proc("_animate", zombo, { pixel_z = 0 }, 10)
					SS13.wait(1)
					zombo:set_var("plane", getPlane(-4, spawnLocation))
					zombo:set_var("anchored", false)
					dm.global_proc("_remove_trait", zombo, "block_transformations", "zs_spawner")
					local spent = false
					local handler = HandlerGroup.new()
					handler:register_signal(zombo, "living_death", function()
						totalZombies -= 1
						handler:clear()
					end)
					handler:register_signal(zombo, "parent_qdeleting", function()
						totalZombies -= 1
						handler:clear()
					end)
				end

				local spawnLoop = SS13.start_loop(60, -1, spawnZombieFunc)
				SS13.register_signal(zombieSpawn, "parent_qdeleting", function()
					SS13.end_loop(spawnLoop)
				end)
				SS13.register_signal(zombieSpawn, "ctrl_click", function(_, clicker)
					if clicker:get_var("ckey") == admin then
						spawnZombieFunc(true)
					end
				end)
				SS13.register_signal(zombieSpawn, "ctrl_shift_click", function(_, clicker)
					if clicker:get_var("ckey") == admin then
						spawnZombieFunc(true, true)
					end
				end)
			end
		end)
	end)
	SS13.register_signal(human, "species_gain", function(_, gained_species)
		if SS13.istype(gained_species, "/datum/species/zombie/infectious") and humanData.class == "Non-Zombie" then
			if not ALLOW_ZOMBIE_CONTROLLABLE then
				setClass(humanData, "Zombie (AI)")
				return
			end
			setClass(humanData, "Zombie")
			SS13.set_timeout(0.5, function()
				local input = SS13.await(SS13.global_proc, "tgui_alert", human, "You're a zombie now! Do you want to let the computer take control? You'll be allowed to re-enter your body once you are cured.", "Zombie Control", { "No", "Yes" })
				if input == "Yes" then
					setClass(humanData, "Zombie (AI)")
				end
			end)
		end
	end)
	SS13.register_signal(human, "parent_preqdeleted", function()
		setClass(humanData, nil)
	end)
	local isOpen = false
	SS13.register_signal(human, "ctrl_click", function(_, clicker)
		if isOpen then
			return
		end
		if clicker:get_var("ckey") == admin then
			SS13.set_timeout(0, function()
				local listDisplay = {}
				for className, classData in CLASSES do
					table.insert(listDisplay, className)
				end
				isOpen = true
				local input = SS13.await(SS13.global_proc, "tgui_input_list", clicker, "Set class", "Set class", listDisplay)
				isOpen = false
				if input == nil or input == -1 then
					return
				end
				setClass(humanData, input)
			end)
		end
	end)

	return humanData
end

local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin):get_var("mob")
if IS_LOCAL then
	local human = SS13.new("/mob/living/carbon/human", user:get_var("loc"))
	human:set_var("ckey", admin)
	sleep()
	setupZombieMutation(human)
else
	local SSdcs = dm.global_vars:get_var("SSdcs")
	SS13.unregister_signal(SSdcs, "!mob_created")
	SS13.register_signal(SSdcs, "!mob_created", function(_, target)
		SS13.set_timeout(1, function()
			if SS13.is_valid(target) and SS13.istype(target, "/mob/living/carbon/human") then
				if not getZombieMutation(target) then
					setupZombieMutation(target)
				end
			end
		end)
	end)

	local tickStart = dm.world:get_var("tick_usage")
	local timeStart = dm.world:get_var("time")
	for _, human in dm.global_vars:get_var("GLOB"):get_var("mob_list") do
		if tickLag(tickStart, timeStart) then
			sleep()
			timeStart = dm.world:get_var("time")
		end
		if SS13.istype(human, "/mob/living/carbon/human") and SS13.is_valid(human) then
			setupZombieMutation(human)
		end
	end
end