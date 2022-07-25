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
	[20] = {
		"/obj/item/shadowcloak",
		"/obj/item/spear/grey_tide",
		"/obj/item/clothing/shoes/jackboots/fast",
		"/obj/item/dice/d20/fate/stealth/one_use",
		"/obj/item/clothing/suit/armor/reactive/table",
		"/obj/item/clothing/head/helmet/abductor",
	},
}

local function dropEverything(target)
	for _, item in target:call_proc("get_all_worn_items"):to_table() do
		if not target:call_proc("dropItemToGround", item) then
			dm.global_proc("qdel", item)
			target:call_proc("regenerate_icons")
		end
	end
end

local function applyOutfit(target, dresscode)
	dropEverything(target)
	target:call_proc("equipOutfit", dm.global_proc("_text2path", dresscode))
end

local function updateVisualData(data)
	data.human:set_var(
		"maptext",
		string.format(
			"<span class='maptext' style='color: %s'>Level: %d<br />%s</span>",
			data.color,
			data.level,
			data.class
		)
	)
end

local deathOperative = false

local FUNCTION_TABLE = {
	[30] = function(data)
		local choice = SS13.await(SS13.global_proc, "tgui_input_list", data.human, "Choose a class", "Class Picker", {
			"Intern",
			"Syndicate Recruit",
			"No class",
		})
		if data.class == "Classless" then
			return
		end
		if choice == "Intern" then
			data.class = "Intern"
			applyOutfit(data.human, "/datum/outfit/centcom/centcom_intern/unarmed")
		elseif choice == "Syndicate Recruit" then
			data.class = "Syndicate Recruit"
			applyOutfit(data.human, "/datum/outfit/pirate")
		else
			data.class = "Classless"
		end
		updateVisualData(data)
	end,
	[31] = function(data)
		if data.class ~= "Intern" and data.class ~= "Syndicate Recruit" and data.class ~= "Classless" then
			data.class = "Classless"
		end
		updateVisualData(data)
	end,
	[40] = function(data)
		if data.class == "Intern" then
			data.class = "Head Intern"
			applyOutfit(data.human, "/datum/outfit/centcom/centcom_intern/leader")
		elseif data.class == "Syndicate Recruit" then
			data.class = "Syndicate Operative"
			applyOutfit(data.human, "/datum/outfit/mobster")
		end
		updateVisualData(data)
	end,
	[50] = function(data)
		if data.class == "Head Intern" then
			data.class = "Centcom Officer"
			applyOutfit(data.human, "/datum/outfit/centcom/ert/security")
		elseif data.class == "Syndicate Operative" then
			data.class = "Syndicate Assassin"
			applyOutfit(data.human, "/datum/outfit/assassin")
		end
		updateVisualData(data)
	end,
	[60] = function(data)
		if data.class == "Centcom Officer" then
			data.class = "Centcom Commander"
			applyOutfit(data.human, "/datum/outfit/centcom/commander/mod")
		elseif data.class == "Syndicate Assassin" then
			data.class = "Syndicate Admiral"
			applyOutfit(data.human, "/datum/outfit/centcom/soviet")
		end
		updateVisualData(data)
	end,
	[65] = function(data)
		if deathOperative then
			return
		end

		if data.class == "Classless" then
			local choice =
				SS13.await(SS13.global_proc, "tgui_input_list", data.human, "Choose a class", "Class Picker", {
					"Death Commando",
					"No class",
				})
			if deathOperative or not choice or choice == "No class" then
				return
			end
			data.class = "Death Commando"
			applyOutfit(data.human, "/datum/outfit/centcom/death_commando")
		end
		updateVisualData(data)
	end,
}

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

local humans = {}

local function setupHuman(name, human, color)
	humans[name] = {
		human = human,
		exp = 0,
		level = 0,
		class = human:get_var("job") or "Prisoner",
		color = color,
	}

	human:set_var("maptext_width", 128)
	human:set_var("maptext_y", 30)
	updateVisualData(humans[name])
end

local function handleLevelUp(data)
	if ITEM_TABLE[data.level] then
		local items = ITEM_TABLE[data.level]
		local item = SS13.new(items[math.random(#items)], dm.global_proc("_get_step", data.human, 0))
		if not data.human:call_proc("equip_to_slot_if_possible", item, 8192, false, true) then
			data.human:call_proc("equip_to_slot_if_possible", item, 8192, false, true)
		end
	end
	if FUNCTION_TABLE[data.level] then
		SS13.set_timeout(1, function()
			FUNCTION_TABLE[data.level](data)
		end)
	end
end

local function notifyPlayer(ply, msg)
	ply:call_proc("balloon_alert", ply, msg)
end

local function addExp(data, exp, cause)
	data.exp += exp

	while data.exp >= data.level * 20 do
		data.exp = data.exp - data.level * 20
		data.level = data.level + 1
		handleLevelUp(data)
	end
	notifyPlayer(data.human, string.format("%s (%d xp)", cause, exp))
	updateVisualData(data)
end

for _, ply in dm.global_vars:get_var("GLOB"):get_var("player_list"):to_table() do
	setupHuman(REF(ply), ply, rgbToHex(hsvToRgb(math.random(), 1, 1, 1)))
	sleep()
end

for _, data in humans do
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
	SS13.register_signal(data.human, "mob_say", function()
		addExp(data, 1000, "cheat")
	end)
end

function DESTRUCT_CLEANUP_HUMANS()
	for _, data in humans do
		data.human:set_var("maptext", "")
		SS13.unregister_signal(data.human, "movable_moved")
		SS13.unregister_signal(data.human, "mob_won_videogame")
		SS13.unregister_signal(data.human, "mob_say")
	end
end
