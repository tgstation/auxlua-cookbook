SS13 = require("SS13")

local admin = "waltermeldron"
local adminUser = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin)

local SCROLL_SPAWN_AMOUNT = 1

local MODE_RUNITE = 1
local MODE_GRIND = 2
local MODE_CLICKER = 3
local MODE_PRECISION = 4
local MODE = MODE_RUNITE
local NON_GRIND_SPEED_BOOST = 2
local TIER_CAP = 5
local CRAFTABLE_TIER_CAP = 50
local CRAFTABLE_QUALITY_REQ_MULT = 0
local FANTASY_TIER_PER_QUALITY = 8
local QUALITY_CAP
if TIER_CAP then
	QUALITY_CAP = TIER_CAP * FANTASY_TIER_PER_QUALITY
end
local CRAFTABLE_QUALITY_CAP = CRAFTABLE_TIER_CAP * FANTASY_TIER_PER_QUALITY

local UPPER_REFINEMENT_LIMIT = (2 ^ 1023) * 1.999

local function notifyPlayer(ply, msg)
	ply:call_proc("balloon_alert", ply, msg)
end

local function getXpReq(data)
	if MODE == MODE_GRIND then
		return 10 * 2 ^ (math.ceil((data.level + 1) / 10) - 1)
	else
		return 100
	end
end

local function replaceBadChars(str)
	local result = string.gsub(str, "([^ -~]+)", "")
	return result
end

local function norm1000()
	local x 
	repeat
	   x = math.ceil(math.log(1/math.random())^.5*math.cos(math.pi*math.random())*150+500)
	until x >= 1 and x <= 1000
	return x
end

local function hsvToRgb(h, s, v, a)
	h = math.abs((h % 360) / 360)
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

refiningSound = refiningSound or {}
anvilIcon = anvilIcon or nil
if #refiningSound == 0 or anvilIcon == nil then
	refiningSound = {}
	local refiningSoundUrl = {
		"https://raw.githubusercontent.com/tgstation/auxlua-cookbook/main/waltermeldron/assets/blacksmith/blacksmith.ogg",
		"https://raw.githubusercontent.com/tgstation/auxlua-cookbook/main/waltermeldron/assets/blacksmith/blacksmith2.ogg",
		"https://raw.githubusercontent.com/tgstation/auxlua-cookbook/main/waltermeldron/assets/blacksmith/blacksmith3.ogg"
	}
	for _, url in refiningSoundUrl do
		local request = SS13.new("/datum/http_request")
		local file_name = "tmp/custom_map_sound.ogg"
		request:call_proc("prepare", "get", url, "", "", file_name)
		request:call_proc("begin_async")
		while request:call_proc("is_complete") == 0 do
			sleep()
		end
		table.insert(refiningSound, SS13.new("/sound", file_name))
	end
	do
		local request = SS13.new("/datum/http_request")
		local file_name = "tmp/custom_map_icon.dmi"
		request:call_proc("prepare", "get", "https://raw.githubusercontent.com/tgstation/auxlua-cookbook/main/waltermeldron/assets/blacksmith/anvil.dmi", "", "", file_name)
		request:call_proc("begin_async")
		while request:call_proc("is_complete") == 0 do
			sleep()
		end
		anvilIcon = SS13.new("/icon", file_name)
	end
end

local function pairsByValue (t, f)
	local a = {}
	local valueKey = {}
	for n, value in pairs(t) do 
		table.insert(a, value) 
		valueKey[value] = n
	end
	table.sort(a, f)
	local i = 0
	local iter = function ()
	  i = i + 1
	  if a[i] == nil then return nil
	  else return valueKey[a[i]], a[i]
	  end
	end
	return iter
end

local anyItemInTheGame = SS13.new("/obj/item/a_gift/anything")
anyItemInTheGame:call_proc("get_gift_type")
sleep()

local craftable = {
	["Clothing"] = {
		minimumLevel = 50,
		materialsRequired = 10,
		typepath = "/obj/item/clothing",
		blacklist = {
			"/obj/item/clothing/mask/facehugger"
		},
		materialUnits = 5,
	},
	["Melee"] = {
		minimumLevel = 100,
		materialsRequired = 20,
		typepath = "/obj/item/melee",
		blacklist = {
			"/obj/item/melee/supermatter_sword"
		},
		materialUnits = 15,
	},
	["Gun"] = {
		minimumLevel = 150,
		materialsRequired = 20,
		typepath = "/obj/item/gun",
		blacklist = {
			"/obj/item/gun/magic",
			"/obj/item/gun/energy/pulse",
			"/obj/item/gun/energy/laser/instakill",
			"/obj/item/gun/energy/meteorgun"
		},
		materialUnits = 15,
	},
	["Ammo"] = {
		minimumLevel = 150,
		materialsRequired = 10,
		typepath = "/obj/item/ammo_box",
		materialUnits = 5,
	},
	["Grenade"] = {
		minimumLevel = 200,
		materialsRequired = 30,
		typepath = "/obj/item/grenade",
		materialUnits = 10,
	},
	["Magic Tool"] = {
		minimumLevel = 300,
		materialsRequired = 30,
		typepath = "/obj/item/gun/magic",
		blacklist = {
			"/obj/item/gun/magic/wand/death/debug",
			"/obj/item/gun/magic/wand/resurrection/debug",
			"/obj/item/gun/magic/wand/safety/debug"
		},
		materialUnits = 10,
	},
	["Any"] = {
		minimumLevel = 500,
		materialsRequired = 15,
		typepath = "/obj/item",
		blacklist = {
			"/obj/item/paper",
			"/obj/item/circuit_component"
		},
		materialUnits = 10,
	}
}

for _, craftData in craftable do
	craftData.typepath = dm.global_proc("_text2path", craftData.typepath)
	if craftData.blacklist then
		for index, blacklistType in craftData.blacklist do
			craftData.blacklist[index] = dm.global_proc("_text2path", blacklistType)
		end
	end
end

for index, typepath in dm.global_vars:get_var("GLOB"):get_var("possible_gifts") do
	if over_exec_usage(0.7) then
		sleep()
	end
	for _, craftData in craftable do
		if over_exec_usage(0.7) then
			sleep()
		end
		craftData.items = craftData.items or {}
		if dm.global_proc("_ispath", typepath, craftData.typepath) == 1 then
			local isBlacklisted = false
			if craftData.blacklist then
				for _, blacklistType in craftData.blacklist do
					if dm.global_proc("_ispath", typepath, blacklistType) == 1 then
						isBlacklisted = true
						break
					end
				end
			end
			if not isBlacklisted then
				table.insert(craftData.items, typepath)
			end
		end
	end
end

local specialRefining = {
	["/obj/item/stack/sheet/plasteel"] = {
		noAnvilRequired = true,
		hitsRequiredToFinish = 3,
		onHitComplete = function(data, user)
			local plasteel = data.item
			local location = plasteel:get_var("loc")
			if not SS13.istype(location, "/turf") then
				return false
			end
			for _, object in location:get_var("contents") do
				if object:get_var("density") == 1 then
					notifyPlayer(user, "not enough room here!")
					return false
				end
			end
			if plasteel:get_var("amount") >= 50 then
				local anvil = SS13.new("/obj/structure/table/reinforced", location)
				anvil:set_var("icon", anvilIcon)
				anvil:set_var("icon_state", "anvil")
				anvil:set_var("canSmoothWith", {})
				anvil:set_var("smoothing_groups", {})
				anvil:set_var("smoothing_flags", 0)
				anvil:set_var("name", "anvil")
				anvil:set_var("desc", "Although it looks pretty weird, this is definitely an anvil. Used by blacksmiths to improve gear")
				dm.global_proc("_add_trait", anvil, "anvil", "blacksmith")
				return true
			else
				notifyPlayer(user, "need a stack of 50 plasteel")
			end
			return false
		end
	},
	["/obj/item/stack/sheet"] = {
		onRefineStart = function(humanData, data)
			local item = data.item
			local craftableNames = {}
			local nameMapping = {}
			for name, craftData in pairsByValue(craftable, function(a, b) return a.minimumLevel < b.minimumLevel end) do
				if craftData.craftableAmount then
					humanData.crafted[craftData] = humanData.crafted[craftData] or 0
					if humanData.crafted[craftData] >= craftData.craftableAmount then
						continue
					end
				end
				local newName = name .. " (level "..tostring(craftData.minimumLevel).." required)"
				table.insert(craftableNames, newName)
				nameMapping[newName] = craftData
			end
			local response = SS13.await(SS13.global_proc, "tgui_input_list", human, "Select what to craft", "Crafting selection", craftableNames)
			if response == nil or item:is_null() or humanData.human:is_null() then
				return false
			end
			local craftingData = nameMapping[response]
			if humanData.level < craftingData.minimumLevel then
				notifyPlayer(humanData.human, "level not high enough!")
				return false
			end
			if item:get_var("amount") < craftingData.materialsRequired then
				notifyPlayer(humanData.human, "not enough materials!")
				return false
			end
			data.qualityHardCap = math.max(data.qualityHardCap, CRAFTABLE_QUALITY_CAP)
			data.crafting = craftingData
			notifyPlayer(humanData.human, "you ready your hammer")
			return true
		end,
		getQuality = function(data, expectedQuality)
			if data.crafting then
				return math.max(expectedQuality - (data.crafting.minimumLevel / 10) * CRAFTABLE_QUALITY_REQ_MULT, 0) 
			end
			return expectedQuality
		end,
		onRefineComplete = function(humanData, data, quality, oldLocation)
			if data.crafting then
				local materials = data.item
				if materials:get_var("amount") < data.crafting.materialsRequired or quality <= 0 then
					data.failed = true
					return
				end
				humanData.crafted[data.crafting] = humanData.crafted[data.crafting] or 0
				humanData.crafted[data.crafting] += 1
				local possibleItems = data.crafting.items
				local toSpawn = possibleItems[math.random(#possibleItems)]
				dm.global_proc("_remove_trait", materials, "being_refined", "blacksmith")
				data.item = SS13.new(toSpawn, oldLocation)
				data.item:set_var("material_flags", 7)
				local materialComp = {}
				local custom_materials = materials:get_var("mats_per_unit") 
				if custom_materials then
					for mat, amount in custom_materials do
						materialComp[mat] = amount * (data.crafting.materialUnits or data.crafting.materialsRequired)
					end
				end
				data.item:call_proc("set_custom_materials",materialComp)
				data.item:call_proc("visible_message", "<span class='notice'>The "..replaceBadChars(tostring(data.item)).." is formed from "..tostring(materials).."</span>")
				materials:call_proc("use", data.crafting.materialsRequired)
			end
		end
	}
}

local classNames = {
	[0] = "Amateur",
	[50] = "Novice",
	[100] = "Capable",
	[150] = "Competent",
	[200] = "Skilled",
	[225] = "Expert",
	[250] = "Master",
	[300] = "Grandmaster",
	[400] = "Legendary",
	[500] = "Celestial",
	[750] = "God",
	[1000] = "Admin"
}

local magnitudes = {
	[0] = "",
	[2] = "million",
	[3] = "billion",
	[4] = "trillion",
	[5] = "quadrillion",
	[6] = "quintillion",
	[7] = "sextillion",
	[8] = "septillion",
	[9] = "octillion",
	[10] = "nonillion",
	[11] = "decillion",
	[12] = "undecillion",
	[13] = "duodecillion",
	[14] = "tredecillion",
	[15] = "quattuordecillion",
	[16] = "quindecillion",
	[17] = "sexdecillion",
	[18] = "septendecillion",
	[19] = "octodecillion",
	[20] = "novemdecillion",
	[21] = "vigintillion",
	[22] = "unvigintillion",
	[23] = "duovigintillion",
	[24] = "tresvigintillion",
	[25] = "quattuorvigintillion",
	[26] = "quinvigintillion",
	[27] = "sesvigintillion",
	[28] = "septemvigintillion",
	[29] = "octovigintillion",
	[30] = "novemvigintillion",
	[31] = "trigintillion",
	[32] = "untrigintillion",
	[33] = "duotrigintillion",
	[34] = "trestrigintillion",
	[35] = "quattuortrigintillion",
	[36] = "quintrigintillion",
	[37] = "sestrigintillion",
	[38] = "septentrigintillion",
	[39] = "adminizillion",
	[40] = "watermillion",
	[50] = "googleplex"
}
local function magnitudeToString(experience)
	local magnitude = math.floor(math.max(math.log(math.max(experience, 1)) / math.log(10), 0) / 3)
	experience = (experience / (10 ^ (magnitude * 3)))
	if experience == 0 then
		experience = 0
	end
	local magnitudeString = magnitudes[magnitude]
	local experienceRounded = math.floor(experience * 100) / 100
	if magnitudeString then
		if #magnitudeString == 0 then
			return tostring(experienceRounded)
		end
		return tostring(experienceRounded).." "..magnitudeString
	end
	local iteration = 1
	local magnitudePosition = magnitude
	while iteration < 10 do
		magnitudePosition -= 1
		magnitudeString = magnitudes[magnitudePosition]
		if magnitudeString then
			break
		end
		iteration += 1
	end
	if magnitudeString then
		experienceRounded = math.floor(experience * (10 ^ (3 * iteration)) * 100) / 100
		if #magnitudeString == 0 then
			return tostring(experienceRounded)
		end
		return tostring(experienceRounded).." "..magnitudeString
	end
	return tostring(experienceRounded).." E+"..tostring(magnitude * 3)
end

local function updateVisualData(data)
	data.image:set_var(
		"maptext",
		string.format(
			"<span class='maptext'>Level: %d<br />Experience %s/%s<br />%s<br/></span>",
			data.level,
			magnitudeToString(data.exp),
			magnitudeToString(getXpReq(data)),
			data.class
		)
	)
end

local function addExp(data, exp, cause)
	data.exp += math.floor(exp)
	local originalLevel = data.level
	local iterations = 0
	while data.exp >= getXpReq(data) do
		if iterations >= 100 then
			break
		end
		data.exp = data.exp - getXpReq(data)
		data.level = data.level + 1
		iterations += 1
	end

	local highestSatisfiedReq = 0
	for levelReq, class in classNames do
		if levelReq > highestSatisfiedReq and levelReq <= data.level then
			data.class = class .. " Blacksmith"
			highestSatisfiedReq = levelReq
		end
	end

	if cause ~= nil then
		notifyPlayer(data.human, string.format("%s (%s xp)", cause, magnitudeToString(math.floor(exp))))
	end
	if originalLevel ~= data.level then
		local turf = dm.global_proc("_get_step", data.human, 0)
		notifyPlayer(data.human, "level up!")
	end
	updateVisualData(data)

	if data.exp >= getXpReq(data) then
		SS13.set_timeout(0.1, function()
			addExp(data, 0, nil)
		end)
	end
end

local function REF(obj)
	return dm.global_proc("REF", obj)
end

local function determineQuality(refiningData, skipCustom)
	local quality = math.ceil(math.log((math.max(refiningData.refinedAmount, 0) + 501) / 500) / math.log(2))
	if not skipCustom then
		if refiningData.specialData.getQuality then
			quality = refiningData.specialData.getQuality(refiningData, quality)
		end
		quality = math.min(quality, refiningData.qualityHardCap)
	end
	return quality
end

local function getQualityRange(quality)
	local quality = quality
	local lowerBound = 500 * (2 ^ (quality - 1)) - 1
	local upperBound = 500 * (2 ^ quality) - 1
	return { lowerBound = lowerBound, upperBound = upperBound, range = upperBound - lowerBound }
end

local function setupHuman(human)
	local humanData = {
		human = human,
		exp = 0,
		level = 1,
		class = classNames[0].. " Blacksmith",
		image = SS13.new("/atom/movable/screen/text"),
		unallocatedPoints = 0,
		crafted = {}
	}
	humanData.image:set_var("screen_loc", "WEST:4,CENTER-0:17")
	local hud = human:get_var("hud_used")
	local hudElements = hud:get_var("static_inventory")
	hudElements:add(humanData.image)
	hud:call_proc("show_hud", hud:get_var("hud_version"))
	updateVisualData(humanData)

	local hammer = SS13.new("/obj/item/nullrod/hammer", human:call_proc("drop_location"))
	hammer:set_var("name", "smithing hammer")
	hammer:set_var("desc", "A blacksmith's trusty hammer. Used to smith weapons.")
	dm.global_proc("qdel", hammer:call_proc("GetComponent", dm.global_proc("_text2path", "/datum/component/anti_magic")))
	human:call_proc("put_in_hands", hammer)

	local function finishRefining(refiningData, oldLoc)
		local refinedAmountMultiplier = (norm1000() / 1000) + 0.5
		local refinedAmount = refiningData.refinedAmount * refinedAmountMultiplier
		local quality = determineQuality(refiningData)
		if refiningData.maximum_quality then
			quality = math.min(refiningData.maximum_quality, quality)
		end
		local expectedTier = math.floor(quality / FANTASY_TIER_PER_QUALITY)
		if refiningData.specialData.onRefineComplete then
			refiningData.specialData.onRefineComplete(humanData, refiningData, expectedTier, oldLoc)
		end
		if refiningData.failed then
			dm.global_proc("playsound", refiningData.item:call_proc("drop_location"), "sound/items/knell"..math.random(1, 4)..".ogg", 30, true)
			refiningData.item:call_proc("visible_message", "<span class='danger'>The "..replaceBadChars(tostring(refiningData.item)).." falls apart as the refinement is completed.</span>")
			refiningData.item:call_proc("burn")
			return
		end
		refiningData.refined = true
		if expectedTier ~= 0 then
			refiningData.item:call_proc("_AddComponent", { dm.global_proc("_text2path", "/datum/component/fantasy"), expectedTier, nil, false, true })
		end
		dm.global_proc("_add_trait", refiningData.item, "blacksmith_refined", "blacksmith")
		dm.global_proc("_remove_trait", refiningData.item, "being_refined", "blacksmith")
		dm.global_proc("playsound", refiningData.item:call_proc("drop_location"), "sound/effects/coin2.ogg", 30, true)
		local uncappedQuality = determineQuality(refiningData, true)
		if MODE == MODE_GRIND then
			addExp(humanData, 10 * 2 ^ (uncappedQuality), "created a quality "..tostring(quality).." item")
		end
		local ghostSound = nil
		if expectedTier >= 10 then
			ghostSound = "sound/effects/coin2.ogg"
		end
		notifyText = tostring(human).." has crafted a "..replaceBadChars(tostring(refiningData.item))
		dm.global_proc("notify_ghosts", notifyText, refiningData.item, notifyText, nil, false, "", ghostSound)
	end

	local refiningProgress = {}
	local nextAttack = 0
	local isOpen = false
	SS13.register_signal(hammer, "item_pre_attack_secondary", function(_, target, user)
		local time = dm.world:get_var("time")
		if user ~= human or not SS13.istype(target, "/obj/item") or user:get_var("combat_mode") == 1 then
			return
		end
		if dm.global_proc("_has_trait", target, "blacksmith_refined") == 1 then
			notifyPlayer(user, "already refined!")
			return 1
		end
		if isOpen then
			return 1
		end
		SS13.set_timeout(0, function()
			local targetRef = REF(target)
			local itemProgress = refiningProgress[targetRef]
			if not itemProgress or itemProgress.item:is_null() or itemProgress.item ~= target then
				return
			end
			isOpen = true
			local input = SS13.await(SS13.global_proc, "tgui_input_number", user, "Set maximum quality level", "Set maximum quality level", 1000, 10000000000, -99)
			isOpen = false
			if input == nil then
				return
			end
			itemProgress.maximum_quality = input
		end)
		return 1
	end)

	SS13.register_signal(hammer, "parent_qdeleting", function()
		if not hud:is_null() and not human:is_null() then
			hudElements:remove(humanData.image)
			hud:call_proc("show_hud", hud:get_var("hud_version"))
			SS13.unregister_signal(human, "atom_examine")
			SS13.unregister_signal(human, "ctrl_click")
			dm.global_proc("_remove_trait", human, "blacksmith", "blacksmith")
		end
	end)

	local isOpen = false
	SS13.register_signal(hammer, "item_pre_attack", function(_, target, user)
		local time = dm.world:get_var("time")
		if user ~= human or not SS13.istype(target, "/obj/item") or user:get_var("combat_mode") == 1 then
			return
		end
		if nextAttack > time or isOpen then
			return 1
		end
		if dm.global_proc("_has_trait", target, "blacksmith_refined") == 1 then
			notifyPlayer(user, "already refined!")
			return 1
		end
		if MODE ~= MODE_CLICKER then
			nextAttack = time + 10
		end
		local specialRefiningData = {}
		local pathLength = 0
		for typepath, data in specialRefining do
			if SS13.istype(target, typepath) then
				if pathLength < #typepath then
					specialRefiningData = data
					pathLength = #typepath
				end
			end
		end

		if not specialRefiningData.noAnvilRequired then
			local location = target:get_var("loc")
			if not SS13.istype(location, "/turf") then
				notifyPlayer(user, "need to do this on an anvil!")
				return 1
			end
			local anvilExists = false
			for _, object in location:get_var("contents") do
				if dm.global_proc("_has_trait", object, "anvil") == 1 then
					anvilExists = true
					break
				end
			end
			if not anvilExists then
				notifyPlayer(user, "need to do this on an anvil!")
				return 1
			end
		end
		SS13.set_timeout(0, function()
			local targetRef = REF(target)
			local itemProgress = refiningProgress[targetRef]
			local shouldStart = true
			if not itemProgress or itemProgress.item:is_null() or itemProgress.item ~= target then
				if dm.global_proc("_has_trait", target, "being_refined") == 1 then
					notifyPlayer(user, "you didn't begin this refinement process!")
					return
				end
				dm.global_proc("_add_trait", target, "being_refined", "blacksmith")
				itemProgress = {
					refinedAmount = 0,
					hitAmount = 0,
					item = target,
					diminishing = 0,
					specialData = specialRefiningData,
					completionImage = SS13.new("/image", nil, target),
					qualityHardCap = QUALITY_CAP or 10000
				}
				if specialRefiningData.onRefineStart then
					isOpen = true
					local result = specialRefiningData.onRefineStart(humanData, itemProgress)
					isOpen = false
					if not result then
						dm.global_proc("_remove_trait", target, "being_refined", "blacksmith")
						return
					end
					shouldStart = false
				end
				itemProgress.completionImage:set_var("appearance_flags", 74)
				local function updateCompletionImage()
					local expectedQuality = determineQuality(itemProgress, true)
					local qualityAmount = 8
					local maxQuality = 360 / 5
					local currentQualityDisplay = math.floor(expectedQuality / qualityAmount) * qualityAmount
					local lowerBound = math.log(math.max(getQualityRange(currentQualityDisplay).lowerBound, 1))
					local upperBound = math.log(getQualityRange(currentQualityDisplay + qualityAmount - 1).upperBound)
					local barAmount = 32
					local refinedAmount = math.log(math.max(itemProgress.refinedAmount, 1))
					local progress = math.max((refinedAmount - lowerBound) / (upperBound - lowerBound), 0)
					local hueLoops = math.floor(currentQualityDisplay / maxQuality)
					local barProgressCount = 0
					local barRight = ""
					local currentPos = 1
					while currentPos <= barAmount do
						if (currentPos - 1) / barAmount <= progress then
							barProgressCount += 1
						else
							barRight = barRight .. "|"
						end
						currentPos += 1
					end
					local qualities = ""
					for i = 1, qualityAmount do
						if barProgressCount <= 0 then
							break
						end
						local bars = ""
						for i = 1, barAmount / qualityAmount do
							if barProgressCount <= 0 then
								break
							end
							bars = bars .. "|"
							barProgressCount -= 1
						end
						qualities = qualities .. "<span style='color: " .. rgbToHex(hsvToRgb(math.max(((i - 1) + currentQualityDisplay) * 5, 0), 1, 1, 1)) .. "'>"..bars.. "</span>"
					end
					if hueLoops > 0 then
						itemProgress.completionImage:call_proc("add_filter", "glowing", 2, dm.global_proc("outline_filter", 2, rgbToHex(hsvToRgb(math.max(hueLoops * 30, 0), 2, 1, 0.2))))
					end
					itemProgress.completionImage:set_var("maptext", "<div class='maptext' style='background-color: ".. rgbToHex(hsvToRgb(math.max(expectedQuality * 5, 0), 1, 0.5, 1)) .. "; font-size: 4px;'>"..qualities.."<span style='color: #000000ff'>"..barRight.."</span></div>")
				end
				itemProgress.updateCompletionImage = updateCompletionImage
				refiningProgress[targetRef] = itemProgress
				if not specialRefiningData.hitsRequiredToFinish then
					for _, client in dm.global_vars:get_var("GLOB"):get_var("clients") do
						if not client then
							continue
						end
						local clientMob = client:get_var("mob")
						dm.global_proc("_list_add", client:get_var("images"), itemProgress.completionImage)
					end
					updateCompletionImage()
					local finishedRefining = false
					local function onMoved(old_loc)
						if finishedRefining then
							return
						end
						finishedRefining = true
						finishRefining(itemProgress, old_loc)
						for _, client in dm.global_vars:get_var("GLOB"):get_var("clients") do
							if not client then
								continue
							end
							local clientMob = client:get_var("mob")
							dm.global_proc("_list_remove", client:get_var("images"), itemProgress.completionImage)
						end
						dm.global_proc("qdel", itemProgress.completionImage)
						SS13.unregister_signal(target, "atom_attack_hand")
						SS13.unregister_signal(target, "movable_moved")
						SS13.unregister_signal(target, "atom_examine")
					end
					SS13.register_signal(target, "atom_attack_hand", function(_, user)
						onMoved(target:get_var("loc"))
						return 1
					end)
					SS13.register_signal(target, "movable_moved", function(_, old_loc)
						onMoved(old_loc)
						return
					end)
					SS13.register_signal(target, "atom_examine", function(_, examining_mob, examine_list)
						if dm.global_proc("_has_trait", examining_mob, "blacksmith") == 1 or examining_mob:get_var("stat") == 4 then
							local expectedQuality = determineQuality(itemProgress)
							if expectedQuality == 0 then
								expectedQuality = 0
							end
							local expectedTier = math.floor(expectedQuality / FANTASY_TIER_PER_QUALITY)
							examine_list:add("<span class='boldnotice'>You deduce that the item's tier will be around <span style='color: hsl("..tostring(math.min(math.max(expectedTier * 5 + 50, 0), 310))..", 100%, 25%)'>"..expectedTier.."</span></span>")
							examine_list:add("<span class='boldnotice'>The current quality is <span style='color: hsl("..tostring(math.min(math.max(expectedQuality * 5 + 50, 0), 310))..", 100%, 25%)'>"..expectedQuality.."</span></span>")
							examine_list:add("<span class='boldnotice'>The current refinement is "..magnitudeToString(itemProgress.refinedAmount).."</span>")
						end
					end)
				end
			end
			if not shouldStart then
				return
			end
			local visualColor = "#ffffff"
			if not specialRefiningData.hitsRequiredToFinish then
				local materials = {}
				local pointValueTotal = 0
				local location = target:get_var("loc")
				for _, object in location:get_var("contents") do
					if SS13.istype(object, "/obj/item/stack/sheet") and dm.global_proc("_has_trait", object, "being_refined") == 0 then
						for mat, amount in object:get_var("mats_per_unit") do
							if not materials[mat] then
								materials[mat] = amount * 5
							else
								materials[mat] += amount * 5
							end
						end
						pointValueTotal = object:get_var("point_value") * 3
						object:call_proc("use", 1)
						break
					end
				end
				local custom_materials = target:get_var("custom_materials")
				if custom_materials then
					for mat, amount in custom_materials do
						if not materials[mat] then
							materials[mat] = amount
						else
							materials[mat] += amount
						end
					end
				end
				local pointValueLevelBoost = pointValueTotal / 20
				-- target:call_proc("set_custom_materials", materials)
				local levelModifier = humanData.level
				if MODE == MODE_RUNITE or MODE == MODE_CLICKER then
					levelModifier = math.max(determineQuality(itemProgress, true) + 2, 0) * 10 * NON_GRIND_SPEED_BOOST
				end

				if MODE == MODE_CLICKER then
					addExp(humanData, (1 + math.floor(pointValueLevelBoost)) * NON_GRIND_SPEED_BOOST, nil)
				end
				local increaseAmount = 50 * (2 ^ (((levelModifier + pointValueLevelBoost) * 0.1)))
				local limit = increaseAmount * 5
				local previousRefinedAmount = itemProgress.refinedAmount
				local expectedQuality = determineQuality(itemProgress)

				if expectedQuality >= itemProgress.qualityHardCap and itemProgress.diminishing ~= 3 then
					notifyPlayer(user, "hit the tier limit!")
					itemProgress.diminishing = 3
				end

				if itemProgress.refinedAmount < limit then
					itemProgress.refinedAmount += increaseAmount
				else
					if itemProgress.diminishing == 0 then
						notifyPlayer(user, "reaching the limit!")
						itemProgress.diminishing = 1
					end
					local exceededAmount = (itemProgress.refinedAmount - limit) / increaseAmount
					itemProgress.refinedAmount += increaseAmount / (2 ^ exceededAmount)
				end
				itemProgress.refinedAmount = math.min(itemProgress.refinedAmount, UPPER_REFINEMENT_LIMIT)
				local increasedAmount = itemProgress.refinedAmount - previousRefinedAmount
				if itemProgress.diminishing == 3 or math.abs(itemProgress.refinedAmount - previousRefinedAmount) < 50 then
					visualColor = "#ff0000"
					itemProgress.diminishing = math.max(2, itemProgress.diminishing)
				elseif itemProgress.diminishing ~= 0 then
					visualColor = "#ffa8a8"
				end
				itemProgress.updateCompletionImage()
			end
			dm.global_proc("playsound", target, refiningSound[math.random(#refiningSound)], 50)
			SS13.new("/obj/effect/temp_visual/block", target:get_var("loc"), visualColor)
			itemProgress.hitAmount += 1
			if specialRefiningData.hitsRequiredToFinish and itemProgress.hitAmount >= specialRefiningData.hitsRequiredToFinish then
				if specialRefiningData.onHitComplete(itemProgress, user) then
					dm.global_proc("qdel", target)
					return
				end
			end
		end)
		return 1
	end)
	if MODE == MODE_RUNITE then
		SS13.register_signal(human, "atom_attackby", function(_, item)
			if SS13.istype(item, "/obj/item/stack/sheet/mineral/runite") then
				local amount = item:get_var("amount")
				addExp(humanData, amount * 200, "absorbed "..tostring(amount).." runite")
				dm.global_proc("qdel", item)
			end
		end)
	end
	SS13.register_signal(human, "atom_examine", function(_, examining_mob, examine_list)
		if SS13.istype(examining_mob, "/mob/dead") then
			examine_list:add("<hr/><span class='notice'>They are level "..humanData.level.."</span>")
			examine_list:add("<span class='notice'>Experience: "..magnitudeToString(humanData.exp).."/"..magnitudeToString(getXpReq(humanData)).."</span>")
			examine_list:add("<hr/>")
		end
	end)
	local isOpen = false
	SS13.register_signal(human, "ctrl_click", function(_, clicker)
		if isOpen then
			return
		end
		if clicker:get_var("ckey") == admin then
			SS13.set_timeout(0, function()
				isOpen = true
				local input = SS13.await(SS13.global_proc, "tgui_input_number", clicker, "Set Level", "Set Level", -1, 10000, -1)
				isOpen = false
				if input == nil or input == -1 then
					return
				end
				humanData.exp = 0
				humanData.level = input
				addExp(humanData, 0, nil)
			end)
		end
	end)

	dm.global_proc("_add_trait", human, "blacksmith", "blacksmith")
end

for i = 1, SCROLL_SPAWN_AMOUNT do
	local tempScroll = SS13.new("/obj/item/upgradescroll")
	local scrollIcon = tempScroll:get_var("icon")
	dm.global_proc("qdel", tempScroll)

	local scroll = SS13.new("/obj/item", adminUser:get_var("mob"):get_var("loc"))
	scroll:set_var("icon", scrollIcon)
	scroll:set_var("icon_state", "scroll")
	if MODE == MODE_RUNITE then
		scroll:set_var("name", "scroll of runite blacksmithing")
		scroll:set_var("desc", "Somehow, this piece of paper can teach you how to be a 'grandmaster blacksmith'. <i>What the hell is a grandmaster blacksmith?</i>")
	else
		scroll:set_var("name", "scroll of blacksmithing")
		scroll:set_var("desc", "Somehow, this piece of paper can teach you how to be a 'blacksmith'. <i>What the hell is a blacksmith?</i>")
	end

	local soundEffects = {
		"sound/effects/pageturn1.ogg",
		"sound/effects/pageturn2.ogg",
		"sound/effects/pageturn3.ogg"
	}
	local isLearning = false
	SS13.register_signal(scroll, "item_attack_self", function(_, user)
		if dm.global_proc("_has_trait", user, "blacksmith") == 1 or isLearning then
			return 1
		end
		isLearning = true
		SS13.set_timeout(0, function()
			if user:get_var("ckey") == admin then
				setupHuman(user)
				dm.global_proc("qdel", scroll)
				return
			end
			dm.global_proc("playsound", user, soundEffects[math.random(#soundEffects)], 30, true)
			if SS13.await(SS13.global_proc, "do_after", user, 50, scroll) == 0 then
				isLearning = false
				return
			end
			dm.global_proc("playsound", user, soundEffects[math.random(#soundEffects)], 30, true)
			if SS13.await(SS13.global_proc, "do_after", user, 50, scroll) == 0 then
				isLearning = false
				return
			end
			dm.global_proc("playsound", user, soundEffects[math.random(#soundEffects)], 30, true)
			if SS13.await(SS13.global_proc, "do_after", user, 50, scroll) == 0 then
				isLearning = false
				return
			end
			user:call_proc("dropItemToGround", scroll)
			setupHuman(user)
			dm.global_proc("qdel", scroll)
		end)
		return 1
	end)
end