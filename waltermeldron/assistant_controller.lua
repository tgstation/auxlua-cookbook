local SS13 = require("SS13")
local HandlerGroup = require("handler_group")

local admin = "waltermeldron"
local AUTO_PICKUP = true



local defaultAutoPickup = AUTO_PICKUP
local tickLag = function(tickUsageStart, worldTime)
	if dm.world:get_var("time") ~= worldTime then
		print("We slept somewhere!")
		return true
	end
	return (dm.world:get_var("tick_usage") - tickUsageStart) >= 50 or over_exec_usage(0.5)
end

local createHref = function(target, args, content)
	brackets = brackets == nil and true or false
	return "<a href='?src="..dm.global_proc("REF", target)..";"..args.."'>"..content.."</a>"
end

local LAST_TIME_TAKEN = os.clock()
local WORLD_TIME = dm.world:get_var("time")
local TIME_AVG = {}
local SLEEPING_AT = {}
local TOTAL_TIME_TAKEN = {}
local TOTAL_CALL_COUNT = {}

local spawnHuman
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

-- Uncomment if not perf tracking to not have any perf loss
-- startPerfTrack = function() end
-- checkPerf = function(ignoreSleep) end

sleep()

local function to_chat(user, message)
	dm.global_proc("to_chat", user, message)
end

local REF = function(ref)
	return dm.global_proc("REF", ref)
end

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

local hasTrait = function (target, trait)
	return dm.global_proc("_has_trait", target, trait) == 1
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

startAiControllerLoop()
local chasedTargets = {}
local mobRefToDatum = {}

CURRENT_CHASED_TARGETS = chasedTargets
CURRENT_MOB_REF_TO_DATUM = mobRefToDatum

local aiRefs = {}


local zombieControllerTargets = {}
local zombieControllers = {}

local sayText = function(player, chatName, message, big, override_sanitize)
	message = dm.global_proc("_copytext", dm.global_proc("trim", message), 1, 1024)
	player:call_proc("log_talk", message, 2)
	local rendered_text = player:call_proc("say_quote", message)
	if override_sanitize then
		rendered_text = message
	end
	local rendered = "<span class='nicegreen'><b>[Controller Talk] " .. chatName .. "</b> " .. rendered_text  .. "</span>"
	if big then
		rendered = "<span class='big'>" .. rendered .. "</span>"
		for _, player in zombieControllers do
			player:call_proc("playsound_local", player:get_var("loc"), "sound/effects/glockenspiel_ping.ogg", 100)
		end
	end
	dm.global_proc("relay_to_list_and_observers", rendered, zombieControllers, player)
end

iconsByHttp = iconsByHttp or {}

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

local emptyHandOnly = false
local dead_players_by_zlevel = dm.global_vars:get_var("SSmobs"):get_var("dead_players_by_zlevel")
local SSspacial_grid = dm.global_vars:get_var("SSspatial_grid")
local makeZombieController = function(location)
	local controller = SS13.new("/mob/camera", location)
	local controllerData = {
		human = controller
	}
	controller:set_var("real_name", "Assistant Controller ("..tostring(math.random(101, 999))..")")
	controller:set_var("name", controller:get_var("real_name"))
	controller:set_var("invisibility", 60)
	controller:set_var("see_invisible", 25)
	controller:set_var("layer", 5)
	controller:set_var("plane", getPlane(-3, location))
	controller:call_proc("set_sight", 60)
	controller:set_var("mouse_opacity", 1)
	controller:set_var("color", "#33cc33")
	controller:set_var("icon", loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/silicon/cameramob.dmi"))
	controller:set_var("icon_state", "marker")
	controller:set_var("lighting_cutoff_red", 5)
	controller:set_var("lighting_cutoff_green", 35)
	controller:set_var("lighting_cutoff_blue", 20)
	dm.global_proc("_add_trait", controller, "mute", "zs_controller")
	table.insert(zombieControllers, controller)
	local nextRally = 0
	local controllerRef = REF(controller)
	local rallyTimer
	SS13.register_signal(controller, "mob_clickon", function(_, object, modifiers)
		if modifiers:get("shift") then
			return
		end
		if hasTrait(object, "rage_ai") then
			SS13.set_timeout(0, function()
				local item
				if modifiers:get("right") then
					item = object:get_var("held_items"):get(2)
				else
					item = object:get_var("held_items"):get(1)
				end
				if item then
					object:set_var("next_click", 0)
					SS13.await(object, "ClickOn", item, "")
				end
			end)
			return
		end
		SS13.end_loop(rallyTimer)
		zombieControllerTargets[controllerRef] = {
			target = object,
			right = modifiers:get("right") == "1",
			passive = modifiers:get("ctrl") == "1"
		}
		if not SS13.istype(object, "/turf") then
			to_chat(controller, "<span class='notice'>You rally nearby assistants to attack "..tostring(object).."</span>")
			rallyTimer = SS13.start_loop(30, 1, function()
				zombieControllerTargets[controllerRef] = nil
			end)
		else
			to_chat(controller, "<span class='notice'>You rally nearby assistants to the targeted location</span>")
			rallyTimer = SS13.start_loop(10, 1, function()
				zombieControllerTargets[controllerRef] = nil
			end)
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
        local i=(#zombieControllers + 1)
        while i > 1 do
            i = i - 1
            local controllerTarget = zombieControllers[i]
            if controllerTarget == controller then 
                table.remove(zombieControllers, i)
                break
            end
        end
	end)
	grantAbility(controllerData, {
		name = "Check Controls",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_mod.dmi",
		icon_state = "panel",
		abilityType = "normal",
		cooldown = 0,
		onActivate = function(humanData, action, target)
			to_chat(controller, "<span class='boldnotice'>Assistant Controller Controls:</span>")
			to_chat(controller, "<span class='notice'>All specified clicks can also be done </span>")
			to_chat(controller, "<span class='notice'>Ctrl left/right click an object to get assistants to left/right click it in non-combat mode</span>")
			to_chat(controller, "<span class='notice'>Left/right click an object to get assistants to left/right click it in combat mode</span>")
			to_chat(controller, "<span class='notice'>Left click an assistant to get them to click the left item in their hand. Right click an assistant to get them to click the right item in their hand</span>")
			to_chat(controller, "<span class='notice'>Auto-pickup determines whether assistants will pick up items from the floor automatically. They will automatically switch worse items for better ones.</span>")
			to_chat(controller, "<span class='notice'>Use only empty hands determines whether assistants will only use their empty hand to click stuff. If they are carrying two items, they'll drop one so that they have an empty hand.</span>")
		end
	})
	local isOpen = false
	grantAbility(controllerData, {
		name = "Send Message To Other Controllers",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_xeno.dmi",
		icon_state = "alien_whisper",
		abilityType = "normal",
		cooldown = 0,
		onActivate = function(humanData, action, target)
			if isOpen then
				return
			end
			SS13.set_timeout(0, function()
				isOpen = true
				local chatMessage = SS13.await(SS13.global_proc, "tgui_input_text", controller, "Send message to controllers", "Message controllers")
				isOpen = false
				sayText(controller, controller:get_var("name"), chatMessage, false, false)
			end)
		end
	})
	if defaultAutoPickup then
		grantAbility(controllerData, {
			name = "Toggle Auto Pickup",
			icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_spells.dmi",
			icon_state = "summons",
			abilityType = "normal",
			cooldown = 0,
			onActivate = function(humanData, action, target)
				AUTO_PICKUP = not AUTO_PICKUP
				if AUTO_PICKUP then
					sayText(controller, controller:get_var("name"), "enabled auto pickup", false, true)
				else
					sayText(controller, controller:get_var("name"), "disabled auto pickup", false, true)
				end
			end
		})
	end
	grantAbility(controllerData, {
		name = "Toggle Use Only Empty Hand",
		icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_spells.dmi",
		icon_state = "arcane_barrage",
		abilityType = "normal",
		cooldown = 0,
		onActivate = function(humanData, action, target)
			emptyHandOnly = not emptyHandOnly
			if emptyHandOnly then
				sayText(controller, controller:get_var("name"), "enabled empty hand only", false, true)
			else
				sayText(controller, controller:get_var("name"), "disabled empty hand only", false, true)
			end
		end
	})

	return controller
end

local function labelDisplay(label_name, content)
	return "<div style='display: flex; margin-top: 4px;'><div style='flex-grow: 1; color: #98B0C3;'>"..label_name..":</div><div>"..content.."</div></div>"
end

local function getReadablePerfStat(number)
	return tostring(math.floor(number * 1000000) / 1000)
end

local function openMobSettings(user, human)
    local userCkey = user:get_var("ckey")
    local browser = SS13.new_untracked("/datum/browser", user, "SettingsMenu", "SettingsMenu", 300, 300)
    local data = ""
    data = data.."<h1>Settings Menu</h1></hr>"
    data = data..labelDisplay("Refresh", createHref(human, "refresh=1", "Refresh"))
    data = data..labelDisplay("Send message", createHref(human, "send_message=1", "Send message"))
    data = data..labelDisplay("Make controller", createHref(human, "make_controller=1", "Make controller"))
    data = data..labelDisplay("Make assistant", createHref(human, "make_assistant=1", "Make assistant"))
    data = data.."</hr>"
    data = data.."<b>TOTAL ASSISTANT AI: "..tostring(#ZOMBIE_AI).."</b><br>"
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

local SSspacedrift = dm.global_vars:get_var("SSspacedrift")
local SSmove_manager = dm.global_vars:get_var("GLOB"):get_var("move_manager")
local createAi = function(human)
    local split_personality = SS13.new("/datum/brain_trauma/severe/split_personality")
    local holder_mob = SS13.new("/mob/living/split_personality", human, split_personality)
    human:call_proc("mind_initialize")
    local mind = human:get_var("mind")
    mind:call_proc("transfer_to", holder_mob)
    human:set_var("atom_integrity", 1)
    dm.global_proc("_add_trait", human, "rage_ai", "rage_admin")
	local aiData = {
		processing = true,
		zombie = human,
		valid = true,
		tick = 0,
		crawler = true,
		nextRandomWander = 100,
		setTarget = function(self, target)
			if self.target then
				self:clearTarget()
			end
			self.target = target
			self.processing = true
		end,
		clearTarget = function(self)
			checkPerf(true)
			if not self.target then
				return
			end
			checkPerf(true)
			if self.pathingDatum then
				self.pathingDatum:set_var("target", dm.global_proc("_get_step", human, 0))
			end
			self.target = nil
			checkPerf(true)
		end,
		execute = function(self)
			startPerfTrack()
			if not SS13.is_valid(human) then
				self:cleanup()
				return
			end
			checkPerf()
			if not self.processing or not self.valid then
				return
			end
			if human:get_var("stat") ~= 0 then
				self.processing = false
				return
			end
			checkPerf()
			local worldTime = dm.world:get_var("time")
			if not SS13.istype(human:get_var("loc"), "/turf") or human:get_var("handcuffed") then
				if self.pathingDatum then
					SSmove_manager:call_proc("stop_looping", human, SSspacedrift)
				end
				SS13.set_timeout(0, function()
					human:call_proc("execute_resist")
				end)
				return
			end
			checkPerf()
			if human:get_var("body_position") == 1 then
				self.nextGetup = self.nextGetup or 0
				if worldTime > self.nextGetup then 
					SS13.set_timeout(0, function()
						human:call_proc("on_floored_end")
						human:call_proc("set_resting", false)
					end)
					self.nextGetup = worldTime + 50
				end
			end
			checkPerf()
			if hasTrait(human, "block_transformations") then
				if self.pathingDatum then
					SSmove_manager:call_proc("stop_looping", human, SSspacedrift)
				end
				return
			end
			checkPerf()
			self.nextTargetSearch = self.nextTargetSearch or 0
			local closestTarget
			local zombieLocation = dm.global_proc("_get_step", human, 0)
			if not zombieLocation then
				return
			end
            local closestDist = 1000
            local tryGetTarget = function(table)
                for _, targetData in table do
					local target = targetData.target
                    if not SS13.is_valid(target) then
                        continue
                    end
                    local location = target
                    if not SS13.istype(target, "/turf") then
                        location = dm.global_proc("_get_step", target, 0)
                    end
                    local distance = dm.global_proc("_get_dist", zombieLocation, location) 
                    if distance > 14 then
                        continue
                    end
                    if distance < closestDist then
                        closestDist = distance
                        closestTarget = targetData
                    end
                end
            end
			if self.itemTarget then
				if SS13.istype(self.itemTarget:get_var("loc"), "/turf") then
					if dm.global_proc("_get_dist", self.itemTarget, zombieLocation) > 10 then
						self.itemTarget = nil
					else
						self:setTarget(self.itemTarget)
					end
				elseif self.itemTarget:get_var("loc") ~= human then
					self.itemTarget = nil
				else
					if self.itemTarget == self.target then
						self:clearTarget()
					end
				end
			end

			if not self.itemTarget or self.itemTarget ~= self.target then
				checkPerf()
				tryGetTarget(zombieControllerTargets)
				checkPerf()
				if closestTarget and (not self.target or self.target ~= closestTarget.target) then
					self.passive = closestTarget.passive
					self.rightClick = closestTarget.right
					if SS13.istype(closestTarget.target, "/turf") then
						checkPerf()
						self:setTarget(closestTarget.target)
						checkPerf()
					else
						checkPerf()
						self:setTarget(dm.global_proc("get_atom_on_turf", closestTarget.target))
						checkPerf()
					end
				end
			end

			if self.pathingDatum then
				self.pathingDatum:set_var("delay", human:get_var("cached_multiplicative_slowdown"))
			end

			if not SS13.is_valid(self.target) then
				self:clearTarget()
				if worldTime >= self.nextRandomWander then
					SS13.start_loop(0, 1, function()
						if SS13.is_valid(self.target) then
							return
						end
						local dir = dm.global_proc("_pick_list", dm.global_vars:get_var("GLOB"):get_var("cardinals"))
						human:call_proc("Move", dm.global_proc("_get_step", human, dir), dir)
					end)
					self.nextRandomWander = worldTime + math.random(50, 100)
				end
				return
			end
			checkPerf()
			local location = dm.global_proc("_get_step", self.target, 0)
			local distance = dm.global_proc("_get_dist", zombieLocation, location) 
			checkPerf()
			if distance >= 14 then
				self:clearTarget()
				return
			end
			local targetIsItem = SS13.istype(self.target, "/obj/item")
			local newHandTarget = human:get_var("active_hand_index")
			checkPerf()
			local highestForceItem = 0
			if emptyHandOnly then
				highestForceItem = 1000
			end
			local held_items = human:get_var("held_items")

			for index=1, 2 do
				local item = held_items:get(index)
				if emptyHandOnly then
					if not item then
						newHandTarget = index
						break
					end
					if item:get_var("force") < highestForceItem and self.itemTarget ~= item then
						newHandTarget = index
						highestForceItem = item:get_var("force")
					end
				else
					if item and item:get_var("force") > highestForceItem then
						newHandTarget = index
						highestForceItem = item:get_var("force")
					end
				end
			end
			checkPerf()
			if newHandTarget ~= human:get_var("active_hand_index") then
				human:call_proc("swap_hand", newHandTarget)
			end
			if emptyHandOnly then
				local heldItem = human:call_proc("get_active_held_item")
				if heldItem then
					human:call_proc("dropItemToGround", heldItem)
				end
				if heldItem == self.itemTarget then
					self.itemTarget = nil
				end
			end
			checkPerf()
			local didClick = false
			if AUTO_PICKUP then
				for _, item in dm.global_proc("_range", 1, zombieLocation) do
					if SS13.istype(item, "/obj/item") and SS13.istype(item:get_var("loc"), "/turf") and item:get_var("force") > highestForceItem then
						SS13.set_timeout(0, function()
							human:call_proc("swap_hand")
							local heldItem = human:call_proc("get_active_held_item")
							if heldItem then
								human:call_proc("dropItemToGround", heldItem)
							end
							SS13.await(human, "ClickOn", item, "")
						end)
						didClick = true
						break
					end
				end
			end
			checkPerf()
            if not didClick and (human:get_var("body_position") ~= 1 or self.crawler) and not hasTrait(self.target, "rage_ai") then
                SS13.set_timeout(0, function()
                    human:set_var("combat_mode", not self.passive)
					local paramString = ""
					if self.rightClick then
						paramString = "right=1"
					end
					SS13.await(human, "ClickOn", self.target, paramString)
					if SS13.is_valid(self.target) and self.target:get_var("loc") == human then
						self.itemTarget = self.target
					end
                end)
            end
			checkPerf()

			if self.isPathing and self.pathingTarget ~= self.target then
				self.pathingDatum:set_var("target", self.target)
			end

			if not self.isPathing then 
				checkPerf()
				self.pathingDatum = SSmove_manager:call_proc("move_to", human, self.target, 1, human:get_var("cached_multiplicative_slowdown"), 1e31, SSspacedrift)
				self.isPathing = true
				self.pathingTarget = self.target
				local handler = HandlerGroup.new()
				local lastPosition = human:get_var("loc")
				local timeSinceLastMove = dm.world:get_var("time")
				handler:register_signal(human, "movable_moved_from_loop", function(_, moveLoop, oldDir, direction)
					local zombieLocation = dm.global_proc("_get_step", human, 0)
					local location = dm.global_proc("_get_step", self.target, 0)
					local distance = dm.global_proc("_get_dist", zombieLocation, location) 
					if distance <= 1 then
						return
					end
					local currTime = dm.world:get_var("time")
					local shouldRest = false
					if zombieLocation ~= lastPosition then
						lastPosition = zombieLocation
						timeSinceLastMove = currTime
					elseif currTime - timeSinceLastMove > 15 then
						shouldRest = true
					end
					local target = dm.global_proc("_get_step", human, oldDir)
					human:set_var("combat_mode", not self.passive)
					local toClickOn
					for _, data in target:get_var("contents") do
                        if hasTrait(data, "rage_ai") then
							if data:get_var("body_position") ~= 1 and human:get_var("resting") ~= 1 and shouldRest then
								human:call_proc("set_resting", true)
							end
                            continue
                        end
						if data:get_var("density") == 1 then
							toClickOn = data
							if bit32.band(data:get_var("flags_1"), 8) ~= 0 then
								break
							end
						end
					end
					if toClickOn and distance > 1 then
						SS13.set_timeout(0, function()
							local paramString = ""
							if self.rightClick then
								paramString = "right=1"
							end
							SS13.await(human, "ClickOn", self.target, paramString)
						end)
					end
				end)
				self.pathingDatum:call_proc("UnregisterSignal", self.pathingDatum:get_var("target"))
				SS13.register_signal(self.pathingDatum, "parent_qdeleting", function()
					self.isPathing = false
					self.pathingTarget = false
					self.pathingDatum = nil
					handler:clear()
				end)
				checkPerf()
            end
		end,
		cleanup = function(self)
			self:clearTarget()
			SSmove_manager:call_proc("stop_looping", human, SSspacedrift)
			self.valid = false
			self.processing = false
            mind:call_proc("transfer_to", human)
		end
	}
	if not hasTrait(human, "relaying_attacker") then
		human:call_proc("_AddElement", { SS13.type("/datum/element/relay_attackers") } )
	end
	SS13.register_signal(human, "atom_was_attacked", function(_, attacker, attack_flags)
		aiData:setTarget(dm.global_proc("get_atom_on_turf", attacker))
	end)
	local insideList = true
	SS13.register_signal(human, "mob_statchange", function(_, new_stat)
		if not aiData.valid then
			return
		end
		if new_stat ~= 0 then
			if aiData.pathingDatum then
				SSmove_manager:call_proc("stop_looping", human, SSspacedrift)
			end
			-- aiData:cleanup()
		else
            aiData.processing = true
        end
	end)
	SS13.register_signal(human, "parent_qdeleting", function()
		aiData:cleanup()
	end)
    SS13.register_signal(human, "atom_examine", function(_, examining_mob, examine_list)
		if examining_mob:get_var("ckey") == admin then
			examine_list:add("<hr/><span class='notice'>"..createHref(human, "settings=1", "Open settings menu").."</span>")
		end
	end)
    SS13.register_signal(human, "handle_topic", function(_, user, href_list)
		SS13.set_timeout(0, function()
			if user:get_var("ckey") ~= admin then
				return
			end

			if href_list:get("settings") or href_list:get("refresh") then
				openMobSettings(user, human)
			end

            if href_list:get("make_controller") then
                makeZombieController(user:get_var("loc"))
			elseif href_list:get("make_assistant") then
				spawnHuman(user:get_var("loc"))
            elseif href_list:get("send_message") then
				local chatMessage = SS13.await(SS13.global_proc, "tgui_input_text", user, "Send message to controllers", "Message controllers")
				if not chatMessage then
					return
				end
				sayText(user, "Controller Overseer", chatMessage, true, false)
            end
        end)
    end)
	table.insert(ZOMBIE_AI, aiData)
	return aiData
end

local location = SS13.get_runner_client():get_var("mob"):get_var("loc")
-- spawnHuman = function(loc)
--     local player = SS13.new("/mob/living/carbon/human", loc)
--     player:call_proc("equipOutfit", SS13.type("/datum/outfit/job/assistant"))
--     player:get_var("physiology"):set_var("siemens_coeff", 0)
--     createAi(player)
--     player:call_proc("mind_initialize")
-- 	local martialArts = SS13.new_untracked("/datum/martial_art/psychotic_brawling")
--     martialArts:call_proc("teach", player)
-- end
-- Assistant with toolbox
-- spawnHuman = function(loc)
--     local player = SS13.new("/mob/living/carbon/human", loc)
--     player:call_proc("equipOutfit", SS13.type("/datum/outfit/job/prisoner"))
--     local toolbox = SS13.new("/obj/item/storage/toolbox")
--     toolbox:set_var("force", 21)
--     toolbox:set_var("name", "robust toolbox")
--     toolbox:set_var("wound_bonus", -30)
--     player:get_var("physiology"):set_var("siemens_coeff", 0)
--     player:call_proc("put_in_active_hand", toolbox)
--     dm.global_proc("_add_trait", toolbox, "nodrop", "toolbox_mania")
--     createAi(player)
-- end
-- spawnHuman = function(loc)
--     local player = SS13.new("/mob/living/carbon/human", loc)
--     player:call_proc("equipOutfit", SS13.type("/datum/outfit/job/assistant"))
--     player:get_var("physiology"):set_var("siemens_coeff", 0)
--     createAi(player)
-- end
-- -- Clown
spawnHuman = function(loc)
    local player = SS13.new("/mob/living/carbon/human", loc)
    player:call_proc("equipOutfit", SS13.type("/datum/outfit/job/clown"))
    local toolbox = SS13.new("/obj/item/melee/energy/sword/bananium")
    toolbox:set_var("force", 6)
	toolbox:set_var("demolition_mod", 6)
    toolbox:set_var("name", "robust sword")
    toolbox:set_var("wound_bonus", -30)
    player:get_var("physiology"):set_var("siemens_coeff", 0)
    player:call_proc("put_in_active_hand", toolbox)
	player:call_proc("ClickOn", toolbox, {})
    dm.global_proc("_add_trait", toolbox, "nodrop", "toolbox_mania")
    dm.global_proc("_add_trait", player, "noslip_all", "toolbox_mania")
    createAi(player)
end
spawnHuman(location)
