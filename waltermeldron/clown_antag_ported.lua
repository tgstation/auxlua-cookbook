local SS13 = require("SS13")

SS13.wait(1)

local ADMIN_MODE = false
local user = SS13.get_runner_client()
local SHOULD_ASK_GHOSTS = SS13.await(SS13.global_proc, "tgui_alert", user, "Ask ghosts for a maintenance clown?", "Maintenance Clown", { "No", "Yes" }) == "Yes"
local function notifyPlayer(ply, msg)
	ply:balloon_alert(ply, msg)
end
function getPlane(new_plane, z_reference)
	local SSmapping = dm.global_vars.SSmapping
	if SSmapping.max_plane_offset ~= 0 then
		local turfPlaneOffsets = 0
		if SSmapping.max_plane_offset ~= nil and SS13.istype(z_reference, "/atom") then
			if z_reference.z ~= nil then
				turfPlaneOffsets = SSmapping.z_level_to_plane_offset[z_reference.z]
			else
				if SSmapping.plane_to_offset ~= 0 then
					turfPlaneOffsets = SSmapping.plane_to_offset[tostring(z_reference.plane)]
				else
					turfPlaneOffsets = z_reference.plane
				end
			end
		end
		local plane_offset_blacklist = SSmapping.plane_offset_blacklist
		if plane_offset_blacklist == nil or plane_offset_blacklist[tostring(new_plane)] then
			return new_plane
		else
			return new_plane - 100 * turfPlaneOffsets
		end
	else
		return new_plane
	end
end
local function setupAntag(mind)
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
	function reducePhysDamage(player, amount)
		local phys = player.physiology
		for _, damageType in damageTypes do
			phys[damageType] = phys[damageType] - 0.01 * amount
		end
	end
	local antagData = {
		level = 1,
		image = SS13.new("/atom/movable/screen/text"),
		showInfo = SS13.new("/atom/movable/screen/text"),
		button = SS13.new("/atom/movable/screen/text"),
		unallocatedPoints = 5,
		stats = {
			Knife = 0,
			Beartrap = 0,
			Traversing = 0,
			Body = 0,
		},
		stats_upgrade = {
			Knife = {
				[1] = "increased attack speed",
				[2] = "increased stamina damage on secondary attack",
				[3] = "increased damage",
				[4] = "increased attack speed",
				[5] = "increased attack speed"
			},
			Beartrap = {
				[1] = "-10s activation time",
				[2] = "-10s activation time",
				[3] = "apply through helmets",
				[4] = "explode on target death",
				[5] = "increased explosion radius and power"
			},
			Traversing = {
				[1] = "reduced shoe slowdown",
				[2] = "smash locked doors down with hands, shock immunity",
				[3] = "slip immunity, +5s c/d reduction on hit",
				[4] = "reduced shoe slowdown",
				[5] = "pull people into the floorboards"
			},
			Body = {
				[1] = "+10% damage reduction, virus and rad immunity",
				[2] = "+5% damage reduction, immune to flash",
				[3] = "+5% damage reduction, thermal vision",
				[4] = "+3% damage reduction, space immunity",
				[5] = "+2% damage reduction, x-ray vision"
			}
		},
		stats_description = {
			Knife = "Your ability to handle a knife. You also have a secondary attack, which you can use by right clicking with a knife, that deals stamina damage and drastically reduces the brute damage you deal. The skill is transferrable to any knife. Higher damage knives will give more lethality and stamina damage.",
			Beartrap = "Your ability to apply reverse beartraps to people. Killing someone using your reverse beartraps is required for you to gain levels. Reverse beartraps have a base 30 second timer before they set off and you can put them on people by clicking them with it whilst it's in hand your hands.",
			Traversing = "Your ability to travel quickly around the station. Use in maintenance to jump into the floorboards where you can then scurry around to find your next victim. When exiting floorboards, it enters into cooldown for 100 seconds. Attacking people with a knife will decrease the cooldown by 5 seconds. You can also pry open doors you don't have access to by left clicking on them with your left hand.",
			Body = "Your ability to survive rough conditions and adapt to your environment. By default, you are immune to knockdown similarly to a hulk, but you can still take stamina damage, which will slow you down."
		},
		stats_upgrade_function = {
			Knife = {},
			Beartrap = {},
			Traversing = {
				[1] = function()
					local shoes = mind.current.shoes
					if shoes then
						shoes.slowdown = 0.25
						mind.current:update_equipment_speed_mods()
					end
				end,
				[2] = function()
					dm.global_procs._add_trait(mind.current, "shock_immunity", "clown_antag")
				end,
				[3] = function()
					dm.global_procs._add_trait(mind.current, "noslip_all", "clown_antag")
				end,
				[4] = function()
					local shoes = mind.current.shoes
					if shoes then
						shoes.slowdown = 0.05
						mind.current:update_equipment_speed_mods()
					end
				end
			},
			Body = {
				[1] = function()
					local player = mind.current
					reducePhysDamage(player, 10)
					player:add_traits({
						"virus_immunity",
						"rad_immunity"
					}, "clown_antag")
				end,
				[2] = function()
					local player = mind.current
					reducePhysDamage(player, 5)
					dm.global_procs._add_trait(player, "noflash", "clown_antag")
					player:update_sight()
				end,
				[3] = function()
					local player = mind.current
					reducePhysDamage(player, 5)
					dm.global_procs._add_trait(player, "thermal_vision", "clown_antag")
					player:update_sight()
				end,
				[4] = function()
					local player = mind.current
					reducePhysDamage(player, 3)
					player:add_traits({
						"resist_low_pressure",
						"resist_high_pressure",
						"resist_cold",
						"resist_heat"
					}, "clown_antag")
				end,
				[5] = function()
					local player = mind.current
					reducePhysDamage(player, 2)
					dm.global_procs._add_trait(player, "xray_vision", "clown_antag")
					player:update_sight()
				end,
			}
		}
	}

	if ADMIN_MODE then
		antagData.level = 50
		antagData.unallocatedPoints = 50
	end
	antagData.button.screen_loc = "WEST:4,CENTER-0:-11"
	antagData.button.maptext_width = 120
	antagData.button.maptext_height = 15
	antagData.image.screen_loc = "WEST:4,CENTER-0:17"
	antagData.button.mouse_opacity = 2
	antagData.showInfo.screen_loc = "WEST:4,CENTER-0:0"
	antagData.showInfo.maptext_width = 120
	antagData.showInfo.maptext_height = 15
	antagData.showInfo.mouse_opacity = 2
	antagData.showInfo.maptext = "<span class='maptext' style='color: #ffa8a8;'>Show Help</span>"
	local jumpIntoFloorboards = SS13.new("/datum/action/cooldown", mind)
	jumpIntoFloorboards.name = "Jump into the floorboards"
	jumpIntoFloorboards.button_icon_state = "origami_on"
	jumpIntoFloorboards:Grant(mind.current)
	local maintenanceAreas = {
		"/area/station/maintenance",
		"/area/centcom/tdome",
		"/area/station/service/theater/abandoned",
		"/area/station/service/electronic_marketing_den",
		"/area/station/service/abandoned_gambling_den",
		"/area/station/science/research/abandoned",
		"/area/station/service/library/abandoned",
		"/area/station/service/kitchen/abandoned",
		"/area/station/service/hydroponics/garden/abandoned",
		"/area/station/medical/abandoned"
	}
	local abstract_icon = SS13.new("/obj/effect/abstract", nil)
	abstract_icon.icon_state = "mfoam"
	local jaunter = nil
	local active = false
	local floorboardVictim
	local function exitFloorboards(turf, force)
		local player = jumpIntoFloorboards.owner
		if not force then
			local area = turf.loc
			local inValidArea = false
			for _, areaType in maintenanceAreas do
				if SS13.istype(area, areaType) then
					inValidArea = true
					break
				end
			end
			if turf.density ~= 0 or (not inValidArea and not ADMIN_MODE) or SS13.istype(turf, "/turf/open/space") or SS13.istype(turf, "/turf/open/openspace") then
				notifyPlayer(player, "need to do this in maintenance!")
				return
			end
			for _, item in turf.contents do
				if item.density == 1 and not SS13.istype(item, "/mob") then
					notifyPlayer(player, "there is something blocking your entry here!")
					return
				end
			end
		end
		active = true
		if not ADMIN_MODE then
			jumpIntoFloorboards:StartCooldown(1000)
		end
		player.anchored = true
		dm.global_procs._add_trait(player, "block_transformations", "clown_antag")
		player.density = false
		player.pixel_z = -32
		if floorboardVictim ~= nil and SS13.is_valid(floorboardVictim) then
			floorboardVictim:Knockdown(20)
			floorboardVictim.pixel_z = -14
			floorboardVictim.anchored = true
			dm.global_procs._add_trait(floorboardVictim, "block_transformations", "clown_antag")
			floorboardVictim.density = false
			floorboardVictim.plane = getPlane(-6, turf)
			floorboardVictim.layer = 1.9
		end
		player.plane = getPlane(-6, turf)
		player.layer = 2
		abstract_icon:forceMove(turf)
		abstract_icon.appearance = dm.global_procs.getFlatIcon(turf)
		abstract_icon.plane = turf.plane
		turf.alpha = 1
		dm.global_procs._animate(abstract_icon, { pixel_w = 32 }, 5)
		SS13.wait(0.5)
		local itemsToUnset = {}
		for _, item in turf.contents do
			if item.anchored ~= 0 and not SS13.istype(item, "/mob") then
				itemsToUnset[item] = item.invisibility
				item.invisibility = 101
			end
		end
		player:forceMove(turf)
		if floorboardVictim ~= nil and SS13.is_valid(floorboardVictim) then
			floorboardVictim:forceMove(turf)
		end
		SS13.unregister_signal(player, "mob_statchange")
		dm.global_procs.qdel(jaunter)
		jaunter = nil
		if floorboardVictim ~= nil and SS13.is_valid(floorboardVictim) then
			dm.global_procs._animate(floorboardVictim, { pixel_z = floorboardVictim.base_pixel_z + 24 }, 3, 1, 1)
			dm.global_procs._animate(nil, { pixel_z = floorboardVictim.base_pixel_z + 16 }, 2)
		end
		dm.global_procs._animate(player, { pixel_z = player.base_pixel_z + 6 }, 3, 1, 1)
		dm.global_procs._animate(nil, { pixel_z = player.base_pixel_z }, 2)
		SS13.wait(0.5)
		if floorboardVictim ~= nil and SS13.is_valid(floorboardVictim) then
			local directions = {1, 2, 4, 8}
			floorboardVictim:throw_at(dm.global_procs._get_step(turf, directions[math.random(#directions)]), 10, 10)
			floorboardVictim.plane = getPlane(-4, turf)
			floorboardVictim.layer = 4
			floorboardVictim.anchored = false
			dm.global_procs._remove_trait(floorboardVictim, "block_transformations", "clown_antag")
			floorboardVictim.density = true
			floorboardVictim.pixel_z = floorboardVictim.base_pixel_z
			floorboardVictim = nil
		end
		player.plane = getPlane(-4, turf)
		dm.global_procs._animate(abstract_icon, { pixel_w = 0 }, 5)
		SS13.wait(0.5)
		turf.alpha = 255
		for item, lastInvis in itemsToUnset do
			if SS13.is_valid(item) then
				item.invisibility = lastInvis
			end
		end
		abstract_icon:moveToNullspace()
		player.layer = 4
		player.anchored = false
		dm.global_procs._remove_trait(player, "block_transformations", "clown_antag")
		player.density = true
		jumpIntoFloorboards.name = "Jump into the floorboards"
		jumpIntoFloorboards.button_icon_state = "origami_on"
		jumpIntoFloorboards:build_all_button_icons()
		active = false
	end
	SS13.register_signal(jumpIntoFloorboards, "action_trigger", function()
		SS13.set_timeout(0, function()
			if active then
				return
			end
			if jaunter == nil then
				local player = jumpIntoFloorboards.owner
				local turf = player.loc
				if not SS13.istype(turf, "/turf") then
					notifyPlayer(player, "too tight to do this here!")
					return
				end
				local area = turf.loc
				local inValidArea = false
				for _, areaType in maintenanceAreas do
					if SS13.istype(area, areaType) then
						inValidArea = true
						break
					end
				end
				if turf.density ~= 0 or (not inValidArea and not ADMIN_MODE) or SS13.istype(turf, "/turf/open/space") or SS13.istype(turf, "/turf/open/openspace") then
					notifyPlayer(player, "need to do this in maintenance!")
					return
				end
				for _, item in turf.contents do
					if item.density == 1 and not SS13.istype(item, "/mob") then
						notifyPlayer(player, "there is something blocking your escape here!")
						return
					end
				end
				player:quick_equip()
				local pulled = player.pulling
				local shouldPull = false
				if pulled ~= nil and SS13.istype(pulled, "/mob/living/carbon/human") and antagData.stats.Traversing >= 5 then
					if not SS13.istype(pulled.head, "/obj/item/reverse_bear_trap") then
						shouldPull = true
					else
						notifyPlayer(player, "no chance")
					end
				end
				active = true
				player:Stun(1)
				player.anchored = true
				dm.global_procs._add_trait(player, "block_transformations", "clown_antag")
				player.density = false
				if shouldPull then
					pulled:Knockdown(10)
					pulled:forceMove(turf)
					pulled.pixel_z = pulled.base_pixel_z + 16
					pulled.anchored = true
					dm.global_procs._add_trait(pulled, "block_transformations", "clown_antag")
					pulled.density = false
					pulled.plane = getPlane(-4, turf)
				end
				player.plane = getPlane(-4, turf)
				abstract_icon:forceMove(turf)
				abstract_icon.appearance = dm.global_procs.getFlatIcon(turf)
				abstract_icon.plane = turf.plane
				turf.alpha = 1
				dm.global_procs._animate(abstract_icon, { pixel_w = 32 }, 5)
				SS13.wait(0.5)
				local itemsToUnset = {}
				for _, item in turf.contents do
					if item.anchored ~= 0 and not SS13.istype(item, "/mob") then
						itemsToUnset[item] = item.invisibility
						item.invisibility = 101
					end
				end
				if SS13.is_valid(player) then
					player.plane = getPlane(-6, turf)
					player.layer = 2
					if shouldPull and SS13.is_valid(pulled) then
						pulled.plane = getPlane(-6, turf)
						pulled.layer = 1.9
						dm.global_procs._animate(pulled, { pixel_z = player.base_pixel_z + 24 }, 3, 1, 1)
						dm.global_procs._animate(nil, { pixel_z = -14 }, 2, 1, 1)
					end
					dm.global_procs._animate(player, { pixel_z = player.base_pixel_z + 6 }, 3, 1, 1)
					dm.global_procs._animate(nil, { pixel_z = -32 }, 2, 1, 1)
				end
				SS13.wait(0.5)
				dm.global_procs._animate(abstract_icon, { pixel_w = 0 }, 5)
				if SS13.is_valid(player) and player.stat == 0 then
					jaunter = SS13.new("/obj/effect/dummy/phased_mob", player:drop_location(), player)
					player:add_traits({
						"magically_phased",
						"resist_low_pressure",
						"resist_high_pressure",
						"resist_cold",
						"resist_heat",
						"no_breath",
						"rad_immunity",
						"bomb_immunity",
						"xray_vision",
						"emotemute",
						"mute",
					}, "jaunting_clown")
					player:update_sight()
					if shouldPull and SS13.is_valid(pulled) then
						pulled:forceMove(player)
						pulled:add_traits({
							"magically_phased",
							"resist_low_pressure",
							"resist_high_pressure",
							"resist_cold",
							"resist_heat",
							"no_breath",
							"rad_immunity",
							"bomb_immunity",
							"emotemute",
							"mute",
						}, "jaunting_clown")
					end
					SS13.register_signal(jaunter, "spell_mob_eject_jaunt", function(_)
						player:remove_traits({
							"magically_phased",
							"resist_low_pressure",
							"resist_high_pressure",
							"resist_cold",
							"resist_heat",
							"no_breath",
							"rad_immunity",
							"bomb_immunity",
							"emotemute",
							"xray_vision",
							"mute"
						}, "jaunting_clown")
						player:update_sight()
						if shouldPull and SS13.is_valid(pulled) then
							pulled:remove_traits({
								"magically_phased",
								"resist_low_pressure",
								"resist_high_pressure",
								"resist_cold",
								"resist_heat",
								"no_breath",
								"rad_immunity",
								"bomb_immunity",
								"emotemute",
								"mute"
							}, "jaunting_clown")
							player:update_sight()
						end
					end)
					SS13.register_signal(player, "mob_statchange", function(_, new_stat)
						if new_stat ~= 0 then
							exitFloorboards(turf, true)
						end
					end)
					jumpIntoFloorboards.name = "Jump out of the floorboards"
					jumpIntoFloorboards.button_icon_state = "origami_off"
					jumpIntoFloorboards:build_all_button_icons()
				end
				for item, lastInvis in itemsToUnset do
					if SS13.is_valid(item) then
						item.invisibility = lastInvis
					end
				end
				player.layer = 4
				player.plane = getPlane(-4, turf)
				player.pixel_z = player.base_pixel_z
				player.anchored = false
				dm.global_procs._remove_trait(player, "block_transformations", "clown_antag")
				player.density = true
				if shouldPull and SS13.is_valid(pulled) then
					pulled.layer = 4
					pulled.plane = getPlane(-4, turf)
					pulled.pixel_z = pulled.base_pixel_z
					pulled.anchored = false
					dm.global_procs._remove_trait(pulled, "block_transformations", "clown_antag")
					pulled.density = true
					floorboardVictim = pulled
				end
				active = false
				SS13.wait(0.5)
				abstract_icon:moveToNullspace()
				turf.alpha = 255
			else
				local turf = dm.global_procs._get_step(jaunter, 0)
				exitFloorboards(turf, false)
			end
		end)
	end)
	local _reverseBeartrap = SS13.new("/obj/item/reverse_bear_trap")
	local spawnReverseBeartrap = SS13.new("/datum/action/cooldown", mind)
	spawnReverseBeartrap.name = "Spawn reverse beartrap"
	spawnReverseBeartrap.button_icon = _reverseBeartrap.icon
	spawnReverseBeartrap.button_icon_state = _reverseBeartrap.icon_state
	spawnReverseBeartrap:Grant(mind.current)
	dm.global_procs.qdel(_reverseBeartrap)
	local beartrapActivated = {}
	SS13.register_signal(spawnReverseBeartrap, "action_trigger", function()
		if jaunter ~= nil then
			return
		end
		SS13.set_timeout(0, function()
			local beartrap = SS13.new("/obj/item/reverse_bear_trap")
			local player = spawnReverseBeartrap.owner
			local result = player:equip_to_slot_or_del(beartrap, 8192, true)
			if result == 1 then
				if not ADMIN_MODE then
					spawnReverseBeartrap:StartCooldown(300)
				end
				SS13.register_signal(beartrap, "item_equip", function(_, equipper)
					local original = beartrapActivated[dm.global_procs.REF(beartrap)]
					if original == equipper and beartrap.ticking ~= 1 then
						beartrapActivated[dm.global_procs.REF(beartrap)] = nil
					end
					SS13.set_timeout(1, function()
						if beartrap.ticking == 1 and beartrap.loc == equipper then
							beartrapActivated[dm.global_procs.REF(beartrap)] = equipper
							local activationTimeReduction = 200
							if antagData.stats.Beartrap >= 1 then
								activationTimeReduction = activationTimeReduction + 100
							end
							if antagData.stats.Beartrap >= 2 then
								activationTimeReduction = activationTimeReduction + 100
							end
							beartrap.kill_countdown = beartrap.kill_countdown - activationTimeReduction
						end
					end)
				end)
				SS13.register_signal(beartrap, "item_pre_attack", function(_, attackingPerson)
					if antagData.stats.Beartrap < 3 then
						return
					end
					if SS13.istype(attackingPerson, "/mob/living/carbon/human") then
						local headSlot = attackingPerson:get_item_by_slot(64)
						if headSlot ~= nil then
							attackingPerson:doUnEquip(headSlot, true, attackingPerson:drop_location(), false, true, true)
							headSlot:visible_message("<span class='danger'>The " .. headSlot.name .. " gets knocked to the ground!</span>")
						end
					end
				end)
				SS13.register_signal(beartrap, "atom_attack_hand", function(_, attackingUser)
					if beartrap.loc ~= attackingUser and attackingUser ~= mind.current then
						dm.global_procs.playsound(beartrap, "sound/effects/explosion1.ogg", 50, true)
						dm.global_procs.qdel(beartrap)
						return
					end
				end)
			end
		end)
	end)

	local function updateVisualData()
		local statAmounts = 4
		local statString = ""
		for _ = 1, statAmounts do
			statString = statString .. "<br/>%s"
		end
		antagData.image.maptext = string.format(
            "<span class='maptext'>Level: %d<br/>"..statString.."%s</span>",
            antagData.level,
            "Knife: "..antagData.stats.Knife,
            "Beartrap: "..antagData.stats.Beartrap,
            "Traversing: "..antagData.stats.Traversing,
            "Body: "..antagData.stats.Body,
            antagData.unallocatedPoints ~= 0 and "<br />Unallocated Ability Points: "..antagData.unallocatedPoints or ""
        )
		if antagData.unallocatedPoints ~= 0 then
			antagData.button.maptext = "<span class='maptext' style='color: #ffa8a8;'>Spend Ability Points</span>"
		else
			antagData.button.maptext = ""
		end
	end
	local function doLevelUp()
		antagData.level = antagData.level + 1
		antagData.unallocatedPoints = antagData.unallocatedPoints + 1
		notifyPlayer(mind.current, "level up!")
		updateVisualData()
	end

	local killedPlayers = {}
	SS13.register_signal(dm.global_vars.SSdcs, "!mob_death", function(_, deadPlayer, gibbed)
		if not SS13.istype(deadPlayer, "/mob/living/carbon/human") or not deadPlayer or gibbed then
			return
		end
		local beartrap = deadPlayer.head
		if beartrap ~= nil and SS13.istype(beartrap, "/obj/item/reverse_bear_trap") and beartrapActivated[dm.global_procs.REF(beartrap)] == deadPlayer and beartrap.ticking ~= 1 then
			if not killedPlayers[dm.global_procs.REF(deadPlayer)] and deadPlayer.key ~= nil then
				doLevelUp()
				killedPlayers[dm.global_procs.REF(deadPlayer)] = true
			end
			if antagData.stats.Beartrap >= 4 then
				local lightRadius = 2
				local flameRadius = 0
				local flashRadius = 0
				if antagData.stats.Beartrap >= 5 then
					lightRadius = 3
					flameRadius = 5
					flashRadius = 7
				end
				dm.global_procs.explosion(deadPlayer, 0, 0, lightRadius, flameRadius, flashRadius)
			end
		end
	end)
	local isOpen = false
	SS13.register_signal(antagData.button, "screen_element_click", function(_, _, _ , _, clickingUser)
		if isOpen or antagData.unallocatedPoints <= 0 or clickingUser ~= mind.current then
			return
		end
		SS13.set_timeout(0, function()
			isOpen = true
			local response = SS13.await(SS13.global_proc, "tgui_input_list", mind.current, "Select Stat Point", "Stat Point Selection", antagData.stats)
			isOpen = false
			if antagData.unallocatedPoints <= 0 then
				notifyPlayer(mind.current, "insufficient stat points!")
				return
			end
			if response == nil then
				return
			end
			local currentValue = antagData.stats[response]
			if antagData.level <= 1 and currentValue >= 3 then
				notifyPlayer(mind.current, "need to reach level 2 before upgrading beyond level 3")
				return
			elseif antagData.level <= 2 and currentValue >= 4 then
				notifyPlayer(mind.current, "need to reach level 3 before upgrading beyond level 4")
				return
			end
			if currentValue >= 5 then
				notifyPlayer(mind.current, "max ability level reached!")
			else
				antagData.stats[response] = antagData.stats[response] + 1
				notifyPlayer(mind.current, antagData.stats_upgrade[response][antagData.stats[response]])
				local func = antagData.stats_upgrade_function[response][antagData.stats[response]]
				if func then
					func()
				end
				antagData.unallocatedPoints = antagData.unallocatedPoints - 1
			end
			updateVisualData()
		end)
	end)
	SS13.register_signal(antagData.showInfo, "screen_element_click", function(_, _, _ , _, clickingUser)
		local browser = SS13.new("/datum/browser", clickingUser, "Maintenance Clown Help", "Maintenance Clown Help", 600, 700)
		local data = "<h2>Maintenance Clown Infodex</h2>"
		data = data .. "As the maintenance clown, your goal is to embrace and cause anarchy. To gain levels, so that you can upgrade your abilities, you must kill people using your reverse beartraps."
		data = data .. "<br/>You start with 3 ability points. Depending on your preferred playstyle, you can choose how to allocate your points. It's recommended to get at least 1 point in traversal so that you have a decent amount of movespeed."
		for stat, levelData in antagData.stats_upgrade do
			data = data .. "<h3>"..stat.."</h3>"
			data = data .. antagData.stats_description[stat] .. "<br/>"
			for level, info in levelData do
				data = data .. "<span style='color: hsl("..tostring(120 - level * 24)..", 100%, 75%)'>Level "..level..": "..info.."</span>"
				if level ~= 5 then
					data = data .. "<br/>"
				end
			end
		end
		browser:set_content(data)
		browser:open()
	end)
	local function registerSignals(player)
		SS13.register_signal(player, "atom_examine", function(_, observing, examineList)
			if SS13.istype(observing, "/mob/dead") then
				list.add(examineList, string.format(
					"<hr/><span class='danger'><b>Maintenance Clown</b><br/>Level: %d<br/>%s | %s | %s | %s<br/>%s</span>",
					antagData.level,
					"Knife: "..antagData.stats.Knife,
					"Beartrap: "..antagData.stats.Beartrap,
					"Traversing: "..antagData.stats.Traversing,
					"Body: "..antagData.stats.Body,
					"Unallocated Ability Points: "..antagData.unallocatedPoints
				))
			end
		end)
		SS13.register_signal(player, "human_pre_attack_hand", function(_, target)
			local locked = SS13.istype(target, "/obj/machinery/door") and (target.locked ~= 0 or target.welded ~= 0)
			if SS13.istype(target, "/obj/machinery/door") and (target:allowed(player) == 0 or locked) and target.density == 1 then
				if locked then
					if antagData.stats.Traversing >= 2 and player.combat_mode == 1 then
						player:do_attack_animation(target, "smash")
						player:Stun(10)
						player:visible_message("<span class='danger'>"..player.name.." uses their sheer strength to smash the "..target.name.."</span>", "<span class='danger'>You use your sheer strength to smash the "..target.name..", leaving you momentarily stunned.</span>")
						target:take_damage(50, "brute", "", false)
						dm.global_procs.playsound(target, "sound/effects/meteorimpact.ogg", 100, true)
					else
						return
					end
				else
					target:try_to_crowbar(nil, player, true)
				end
				return 1
			end
		end)
		local isAttacking = false
		SS13.register_signal(player, "mob_item_attack", function(player_mob, target_mob, _, params)
			local attackingItem = player.held_items[player.active_hand_index]
			if not SS13.istype(attackingItem, "/obj/item/knife") then
				return
			end
			local damageBuff = 0
			if antagData.stats.Knife >= 3 then
				damageBuff = 5
			end
			if SS13.istype(target_mob, "/mob/living/carbon/human") and target_mob.stat ~= 4 and target_mob.key and dm.global_procs.REF(target_mob) ~= dm.global_procs.REF(player_mob) then
				if math.random(10) == 1 then
					player:emote("laugh")
					player:add_mood_event("bloodlust", dm.global_procs._text2path("/datum/mood_event/chemical_laughter"))
				end
				local floorboardCooldownReduction = 50
				if antagData.stats.Traversing >= 3 then
					floorboardCooldownReduction = floorboardCooldownReduction + 50
				end
				jumpIntoFloorboards.next_use_time = jumpIntoFloorboards.next_use_time - floorboardCooldownReduction
			end
			if antagData.stats.Knife >= 1 then
				SS13.set_timeout(0, function()
					local newSpeed = player.next_move - 2
					if antagData.stats.Knife >= 4 then
						newSpeed = newSpeed - 2
					end
					if antagData.stats.Knife >= 5 then
						newSpeed = newSpeed - 2
					end
					player.next_move = newSpeed
				end)
			end
			local paramList = dm.global_procs._params2list(params)
			if damageBuff > 0 and not isAttacking and paramList["right"] ~= "1" then
				isAttacking = true
				local originalForce = attackingItem.force
				attackingItem.force = originalForce + damageBuff
				SS13.set_timeout(0, function()
					attackingItem.force = originalForce
					isAttacking = false
				end)
			end
			if not isAttacking and paramList["right"] == "1" then
				isAttacking = true
				local originalForce = attackingItem.force
				attackingItem.force = originalForce * 0.25
				SS13.set_timeout(0, function()
					attackingItem.force = originalForce
					isAttacking = false
				end)
				local multiplier = 1
				if antagData.stats.Knife >= 2 then
					multiplier = 1.5
				end
				target_mob:apply_damage((originalForce + damageBuff) * multiplier, "stamina")
			end
		end)
		local hud = player.hud_used
		local hudElements = hud.static_inventory
		list.add(hudElements, antagData.image)
		list.add(hudElements, antagData.button)
		list.add(hudElements, antagData.showInfo)
		hud:show_hud(hud.hud_version)
		updateVisualData()
	end
	local function unregisterSignals(player)
		SS13.unregister_signal(player, "human_early_unarmed_attack")
		SS13.unregister_signal(player, "atom_examine")
		SS13.unregister_signal(player, "mob_item_attack")
		SS13.unregister_signal(player, "mob_clickon")
		local hud = player.hud_used
		local hudElements = hud.static_inventory
		list.remove(hudElements, antagData.image)
		list.remove(hudElements, antagData.button)
		list.remove(hudElements, antagData.showInfo)
	end
	SS13.register_signal(mind, "mind_transferred", function(_, old)
		unregisterSignals(old)
		registerSignals(mind.current)
	end)
	registerSignals(mind.current)
end

local function createPlayer()
	local spawnPosition = user.mob.loc
	local client
	local markedDatum = user.holder.marked_datum
	local showToGhosts = true
	if SHOULD_ASK_GHOSTS then
		local players = SS13.await(dm.global_vars.SSpolling, "poll_ghost_candidates", "The mode is looking for volunteers to become Clown for Maintenance Clown", nil, nil, 300, nil, true, spawnPosition, spawnPosition, "Maintenance Clown")
		if #players == 0 then
			dm.global_procs.message_admins("Not enough players volunteered for the Maintenance Clown role.")
			return
		end
		client = dm.global_procs._pick_list(players)
		dm.global_procs.message_admins("Selected "..dm.global_procs.key_name_admin(client).." for the role of Maintenance Clown.")
	elseif SS13.istype(markedDatum, "/client") then
		client = markedDatum
	elseif SS13.istype(markedDatum, "/mob") then
		client = markedDatum.client
		dm.global_procs.qdel(markedDatum)
	else
		client = user
		showToGhosts = false
	end
	if not SS13.istype(client, "/client") then
		client = client.client
	end
	local mind = SS13.new("/datum/mind", client.key)
	local player = SS13.new("/mob/living/carbon/human", spawnPosition)
	mind:transfer_to(player, true)
	sleep()
	player:add_traits({
		"dismember_immunity"
	}, "clown_antag_inherent")
	mind:set_assigned_role(dm.global_vars.SSjob:GetJobType(dm.global_procs._text2path("/datum/job/clown")))
	mind.special_role = "Maintenance Clown"
	local antag = SS13.new("/datum/antagonist/custom")
	antag.antag_hud_name = "cultmaster"
	antag.name = "Maintenance Clown"
	antag.show_to_ghosts = false
	antag.antagpanel_category = "Maintenance Clown"
	antag.ui_name = nil
	local objective = SS13.new("/datum/objective")
	objective.owner = mind
	objective.explanation_text = "Deliver Honkmother's Vision upon the station and embrace Anarchy. Gain levels and upgrade your ability by killing people with your beartraps."
	objective.completed = true
	list.add(antag.objectives, objective)
	mind:add_antag_datum(antag)
	sleep()
	player.status_flags = 13
	player:equipOutfit(dm.global_procs._text2path("/datum/outfit/job/clown"))
	player.client.prefs:apply_prefs_to(player, true)
	sleep()
	player:apply_pref_name(dm.global_procs._text2path("/datum/preference/name/clown"), client)
	dm.global_procs.to_chat(player, "<span class='bolddanger'>Recently I've been visited by a lot of VISIONS. They're all about the great HONKMOTHER, and the belief It brings. I will do EVERYTHING to spread the belief of ANARCHISM, to show that ANARCHY must be embraced.</span>")
	dm.global_procs.to_chat(player, "<span class='notice'>Kill people using your reverse beartraps to increase your level so that you can upgrade your abilities. The maximum level of each ability is level 5.</span>")
	local knife = SS13.new("/obj/item/knife/butcher")
	knife.name = "sharpened butcher's cleaver"
	knife.force = 20
	player:equip_to_slot_or_del(knife, 8192, true)
	local shirt = player.w_uniform
	shirt.has_sensor = 0
	shirt.sensor_mode = 0
	player:update_suit_sensors()
	local shoes = player.shoes
	dm.global_procs._add_trait(shoes, "nodrop", "clown_antag")
	shoes.resistance_flags = 243
	function punishTheClown()
		if SS13.is_valid(shoes) then
			dm.global_procs._remove_trait(shoes, "nodrop", "clown_antag")
		end
		if not SS13.is_valid(player) then
			return
		end
		local heart_failure = SS13.new("/datum/disease/heart_failure")
		heart_failure.stage = 5
		
		player:ForceContractDisease(heart_failure, false, true)
		player:add_mood_event("my_shoes", dm.global_procs._text2path("/datum/mood_event/depression_severe"))
		player:set_heartattack(true)
		dm.global_procs._add_trait(player, "committed_suicide", "clown_antag")
	end
	SS13.register_signal(shoes, "item_post_unequip", punishTheClown)
	SS13.register_signal(shoes, "parent_preqdeleted", punishTheClown)
	sleep()
	local betterEyes = SS13.new("/obj/item/organ/internal/eyes/night_vision/goliath")
	betterEyes:Insert(player, false, 1)

	local idCard = player.wear_id
	list.add(idCard.access, "maint_tunnels")
	idCard.registered_name = player.real_name
	local bankAccount = idCard.registered_account
	bankAccount.account_balance = 500
	bankAccount.account_holder = player.real_name
	bankAccount.account_job = SS13.new("/datum/job/clown")
	sleep()
	setupAntag(mind)
end

createPlayer()
