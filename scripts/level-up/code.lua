SS13 = require("SS13")

local ITEM_TABLE = {
	[5] = {
		"/obj/item/restraints/handcuffs/cable",
		"/obj/item/restraints/legcuffs/bola",
		"/obj/item/clothing/glasses/nightmare_vision",
		"/obj/item/clothing/gloves/tackler/offbrand",
		"/obj/item/clothing/shoes/jackboots",
	},
	[10] = {
		"/obj/item/clothing/glasses/hud/security",
		"/obj/item/clothing/gloves/tackler/combat",
		"/obj/item/clothing/glasses/sunglasses",
		"/obj/item/storage/belt/military/assault",
		"/obj/item/storage/medkit/regular",
	},
	[30] = {
		"/obj/item/shadowcloak",
		"/obj/item/spear/grey_tide",
		"/obj/item/clothing/shoes/jackboots/fast",
		"/obj/item/dice/d20/fate/stealth/one_use",
		"/obj/item/clothing/suit/armor/reactive/table",
	},
}

local admin = dm.usr:get_var("ckey")

local function notifyPlayer(ply, msg)
	ply:call_proc("balloon_alert", ply, msg)
end

local function getXpReq(data)
	return data.level * 10
end

local function updateVisualData(data)
	local statAmounts = 5
	local statString = ""
	for _ = 1, statAmounts do
		statString = statString .. "<br/>%s"
	end
	data.image:set_var(
		"maptext",
		string.format(
			"<span class='maptext' style='color: %s'>Level: %d<br />Experience %d/%d<br />%s<br/>"..statString.."%s</span>",
			data.color,
			data.level,
			data.exp,
			getXpReq(data),
			data.class,
			"Vitality: "..data.stats.Vitality,
			"Defense: "..data.stats.Defense,
			"Strength: "..data.stats.Strength,
			"Dexterity: "..data.stats.Dexterity,
			"Speed: "..data.stats.Speed,
			data.unallocatedPoints ~= 0 and "<br />Unallocated Stat Points: "..data.unallocatedPoints or ""
		)
	)
	if data.unallocatedPoints ~= 0 then
		data.button:set_var("maptext", "<span class='maptext'>Spend Stat Points</span>")
	else
		data.button:set_var("maptext", "")
	end
end

local soundEffectToSteal = SS13.new("/obj/effect/fun_balloon/sentience", dm.usr:get_var("loc"))
local levelUpSound = soundEffectToSteal:get_var("pop_sound_effect")
dm.global_proc("qdel", soundEffectToSteal)

local FUNCTION_TABLE = {}

local function hsvToRgb(h, s, v, a)
	local r, g, b

	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	i = i % 6

	if i == 0 then
		r, g, b = v, t, p
	elseif i == 1 then
		r, g, b = q, v, p
	elseif i == 2 then
		r, g, b = p, v, t
	elseif i == 3 then
		r, g, b = p, q, v
	elseif i == 4 then
		r, g, b = t, p, v
	elseif i == 5 then
		r, g, b = v, p, q
	end

	return { r * 255, g * 255, b * 255, a * 255 }
end

local function rgbToHex(rgb)
	local hexadecimal = "#"

	for _, value in pairs(rgb) do
		local hex = ""

		while value > 0 do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub("0123456789ABCDEF", index, index) .. hex
		end

		if string.len(hex) == 0 then
			hex = "00"
		elseif string.len(hex) == 1 then
			hex = "0" .. hex
		end

		hexadecimal = hexadecimal .. hex
	end

	return hexadecimal
end

local function REF(obj)
	return dm.global_proc("REF", obj)
end

if DESTRUCT_CLEANUP_HUMANS then
	DESTRUCT_CLEANUP_HUMANS()
end

local physTypes = {
	brute_mod = "Defense",
	burn_mod = "Defense",
	tox_mod = "Defense",
	oxy_mod = "Defense",
	clone_mod = "Defense",
	cold_mod = "Defense",
	heat_mod = "Defense",
	pressure_mod = "Defense",
	siemens_coeff = "Defense",
	stamina_mod = "Strength",
	stun_mod = "Strength",
	bleed_mod = "Vitality"
}

local function recalculateStats(data)
	local human = data.human

	human:call_proc("add_or_update_variable_movespeed_modifier", dm.global_proc("_text2path", "/datum/movespeed_modifier/admin_varedit"), true, -data.stats.Speed * 0.02)
	human:set_var("maxHealth", 100 + data.stats.Vitality * 3)
	human:set_var("next_move_modifier", 1 - data.stats.Dexterity * 0.01)
	human:call_proc("add_or_update_variable_actionspeed_modifier", dm.global_proc("_text2path", "/datum/actionspeed_modifier/base"), true, 1 - data.stats.Dexterity * 0.02)
	local phys = data.human:get_var("physiology")
	for physType, var in physTypes do
		phys:set_var(physType, phys:get_var(physType) * (1 - data.stats[var]*0.01))
	end
	local species = data.human:get_var("dna"):get_var("species")
	species:set_var("punchdamagehigh", 10 + math.floor(data.stats.Strength*0.4))
	species:set_var("punchdamagelow", 1 + math.floor(data.stats.Strength*0.4))
end

local function undoStats(data)
	local human = data.human
	human:call_proc("remove_movespeed_modifier", dm.global_proc("_text2path", "/datum/movespeed_modifier/admin_varedit"))
	human:call_proc("add_or_update_variable_actionspeed_modifier", dm.global_proc("_text2path", "/datum/actionspeed_modifier/base"), true, 1)
	human:set_var("maxHealth", 100)
	human:set_var("next_move_modifier", 1)
	local phys = data.human:get_var("physiology")
	for physType, _ in physTypes do
		phys:set_var(physType, 1)
	end
	local species = data.human:get_var("dna"):get_var("species")
	species:set_var("punchdamagehigh", 10)
	species:set_var("punchdamagelow", 1)
end

local humans = {}

local function setupHuman(name, human, color)
	humans[name] = {
		human = human,
		exp = 0,
		level = 1,
		class = human:get_var("job") or "Unassigned",
		color = color,
		image = SS13.new("/atom/movable/screen/text", dm.usr),
		button = SS13.new("/atom/movable/screen/text", dm.usr),
		unallocatedPoints = 0,
		stats = {
			Strength = 0,
			Vitality = 0,
			Dexterity = 0,
			Defense = 0,
			Speed = 0,
		}
	}
	local humanData = humans[name]
	humanData.button:set_var("screen_loc", "WEST:4,CENTER-0:0")
	humanData.button:set_var("maptext_width", 80)
	humanData.button:set_var("maptext_height", 15)
	humanData.image:set_var("screen_loc", "WEST:4,CENTER-0:17")
	humanData.button:set_var("mouse_opacity", 2)
	local hud = human:get_var("hud_used")
	local hudElements = hud:get_var("static_inventory")
	hudElements:add(humanData.image)
	hudElements:add(humanData.button)
	humanData.image:set_var("loc", nil)
	humanData.button:set_var("loc", nil)
	hud:call_proc("show_hud", hud:get_var("hud_version"))
	updateVisualData(humanData)

	local isOpen = false
	SS13.register_signal(humanData.button, "atom_click", function()
		if isOpen or humanData.unallocatedPoints <= 0 then
			return
		end
		SS13.set_timeout(0, function()
			isOpen = true
			local response = SS13.await(SS13.global_proc, "tgui_input_list", human, "Select Stat Point", "Stat Point Selection", humanData.stats)
			isOpen = false
			if humanData.unallocatedPoints <= 0 then
				notifyPlayer(human, "insufficient stat points!")
				return
			end
			if response == nil then
				return
			end
			undoStats(humanData)
			local currentValue = humanData.stats[response]
			if currentValue >= 99 then
				notifyPlayer(human, "max stat level reached!")
			else
				humanData.stats[response] += 1
				humanData.unallocatedPoints -= 1
			end
			recalculateStats(humanData)
			updateVisualData(humanData)
		end)
	end)

	return humanData
end

local function handleLevelUp(data)
	if ITEM_TABLE[data.level] then
		local items = ITEM_TABLE[data.level]
		local item = SS13.new(items[math.random(#items)], dm.global_proc("_get_step", data.human, 0))
		if not data.human:call_proc("equip_to_slot_if_possible", item, 8192, false, true) then
			data.human:call_proc("equip_to_slot_if_possible", item, 8192, false, true)
		end
	elseif data.level % 5 == 0 then
		local item = SS13.new("/obj/item/a_gift/anything", dm.global_proc("_get_step", data.human, 0))
		if not data.human:call_proc("equip_to_slot_if_possible", item, 8192, false, true) then
			data.human:call_proc("equip_to_slot_if_possible", item, 8192, false, true)
		end
	end
	if FUNCTION_TABLE[data.level] then
		SS13.set_timeout(1, function()
			FUNCTION_TABLE[data.level](data)
		end)
	end
	data.unallocatedPoints += math.max(1 * (3 - math.floor(data.level / 5)), 1)
end

local function addExp(data, exp, cause)
	data.exp += exp
	
	local originalLevel = data.level
	while data.exp >= getXpReq(data) do
		data.exp = data.exp - getXpReq(data)
		data.level = data.level + 1
		handleLevelUp(data)
	end
	notifyPlayer(data.human, string.format("%s (%d xp)", cause, exp))
	if originalLevel ~= data.level then
		local turf = dm.global_proc("_get_step", data.human, 0)
		dm.global_proc("playsound", turf, levelUpSound, 15)
		SS13.new("/obj/effect/temp_visual/gravpush", turf)
	end
	updateVisualData(data)
end

for _, ply in dm.global_vars:get_var("GLOB"):get_var("player_list"):to_table() do
	if not SS13.istype(ply, "/mob/living/carbon/human") then
		continue
	end
	setupHuman(REF(ply), ply, rgbToHex(hsvToRgb(math.random(), 0.5, 1, 1)))
	sleep()
end

local deadMobs = {}
local function applySignals(data)
	local excercise = 0
	SS13.register_signal(data.human, "movable_moved", function()
		if excercise >= 50 then
			excercise = 0
			addExp(data, 1, "exercise")
		end
		excercise = excercise + 1
	end)
	local amountWon = 0
	SS13.register_signal(data.human, "mob_won_videogame", function()
		if amountWon > 5 then
			SS13.unregister_signal(data.human, "mob_won_videogame")
			return
		end
		local expToAward = 12 - amountWon * 2
		addExp(data, expToAward, "won game")
		amountWon += 1
	end)
	local slappedPeople = {}
	SS13.register_signal(data.human, "living_slap_mob", function(_, slapped)
		local slappedRef = REF(slapped)
		if slappedPeople[slappedRef] then
			return
		end
		addExp(data, 5, "slapped person")
		slappedPeople[slappedRef] = true	
	end)
	local pointedObjects = {}
	SS13.register_signal(data.human, "mob_pointed", function(_, pointed_object)
		if not SS13.istype(pointed_object, "/mob/living/carbon/human") then
			return
		end
		local pointedRef = REF(pointed_object)
		if pointed_object:get_var("client") == nil or pointedObjects[pointedRef] then
			return
		end
		addExp(data, 5, "pointed at person")
		pointedObjects[pointedRef] = true
	end)
	SS13.register_signal(data.human, "atom_examine", function(_, examining_mob, examine_list)
	
		examine_list:add("<span class='notice'>They are level "..data.level.."</span>")
		if examining_mob:get_var("ckey") == admin then
			examine_list:add("<span class='boldwarning'><hr/>ADMIN INFO</span>")
			examine_list:add("<span class='notice'>Experience: "..data.exp.."/"..getXpReq(data).."</span>")
			examine_list:add(string.format("<span class='notice'>%s|%s|%s|%s|%s</span>",
				"Vitality: "..data.stats.Vitality,
				"Defense: "..data.stats.Defense,
				"Strength: "..data.stats.Strength,
				"Dexterity: "..data.stats.Dexterity,
				"Speed: "..data.stats.Speed
			))
			examine_list:add("<hr/>")
		end
	end)
	SS13.register_signal(data.human, "human_melee_unarmed_attack", function(human, target, proximity)
		if not SS13.istype(target, "/mob") then
			return
		end

		if target:get_var("stat") ~= 4 or not human:get_var("combat_mode") or proximity == 0 then
			return
		end
		local targetRef = REF(target)
		
		local possibleData = humans[targetRef]

		if possibleData == nil then
			if deadMobs[targetRef] then
				return
			end
			if SS13.istype(target, "/mob/living/simple_animal/hostile") then
				if SS13.istype(target, "/mob/living/simple_animal/hostile/bubblegum") then
					addExp(data, 500, "killed bubblegum")
				elseif SS13.istype(target, "/mob/living/simple_animal/hostile/colossus") then
					addExp(data, 350, "killed colossus")
				elseif SS13.istype(target, "/mob/living/simple_animal/hostile/megafauna/dragon") then
					addExp(data, 250, "killed dragon")
				elseif SS13.istype(target, "/mob/living/simple_animal/hostile/megafauna/blood_drunk_miner") then
					addExp(data, 250, "killed miner")
				elseif SS13.istype(target, "/mob/living/simple_animal/hostile/megafauna") then
					addExp(data, 150, "killed megafauna")
				else
					addExp(data, math.max(5, math.min(100, target:get_var("melee_damage_upper"))), "killed combatant")
				end
			else
				addExp(data, 5, "killed non-combatant")
			end
			deadMobs[targetRef] = true
		else
			if possibleData.exp == 0 then
				return
			end
			addExp(data, possibleData.exp, "stolen player xp")
			possibleData.exp = 0
		end
	end)
	local isOpen = false
	SS13.register_signal(data.human, "ctrl_click", function(_, clicker)
		if isOpen then
			return
		end
		if clicker:get_var("ckey") == admin then
			SS13.set_timeout(0, function()
				isOpen = true
				local input = SS13.await(SS13.global_proc, "tgui_input_number", clicker, "Add Experience", 0, 0, 1000000000)
				isOpen = false
				if input == nil or input == 0 then
					return
				end
				local reason = SS13.await(SS13.global_proc, "tgui_input_text", clicker, "Reason for adding experience", "Add Experience", "gifted by gods")
				addExp(data, input, reason)
			end)
		end
	end)
end

local SSdcs = dm.global_vars:get_var("SSdcs")
SS13.register_signal(SSdcs, "!crewmember_joined", function(_, target)
	local data = setupHuman(REF(target), target, rgbToHex(hsvToRgb(math.random(), 1, 1, 1)))
	applySignals(data)
end)

for _, data in humans do
	applySignals(data)
	sleep()
end

function DESTRUCT_CLEANUP_HUMANS()
	SS13.unregister_signal(SSdcs, "!crewmember_joined")
	
	for _, data in humans do
		undoStats(data)
		local hud = data.human:get_var("hud_used")
		local hudElements = hud:get_var("static_inventory")
		dm.global_proc("_list_remove", hudElements, data.image)
		dm.global_proc("_list_remove", hudElements, data.button)
		dm.global_proc("qdel", data.image)
		dm.global_proc("qdel", data.button)
		if REF(data.human) == "[0x0]" or data.human:get_var("gc_destroyed") ~= nil then
			continue
		end
		SS13.unregister_signal(data.human, "movable_moved")
		SS13.unregister_signal(data.human, "mob_won_videogame")
		SS13.unregister_signal(data.human, "mob_pointed")
		SS13.unregister_signal(data.human, "living_slap_mob")
		SS13.unregister_signal(data.human, "atom_examine")
		SS13.unregister_signal(data.human, "human_melee_unarmed_attack")
		SS13.unregister_signal(data.human, "ctrl_click")
		sleep()
	end
end
