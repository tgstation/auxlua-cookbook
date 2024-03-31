SS13 = require('SS13')

local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get("waltermeldron")
local allPaintings = {}
local paintingsNameMap = {}

for _, value in dm.global_vars:get_var("SSpersistent_paintings"):get_var("paintings") do
    if value:get_var("width") > 64 or value:get_var("height") > 64 then
        continue
    end
    table.insert(allPaintings, value)
	paintingsNameMap[value:get_var("title")] = value
end

if DO_CLEANUP ~= nil then
	DO_CLEANUP()
	DO_CLEANUP = nil
end

SS13.register_signal(dm.global_vars:get_var("SSdcs"), "!mob_created", function(_, mob)
	if SS13.istype(mob, "/mob/living/simple_animal/hostile/skeleton") and mob:get_var("loc") == user:get_var("mob"):get_var("loc") then
		mob:set_var("hud_possible", nil)
		SS13.unregister_signal(dm.global_vars:get_var("SSdcs"))
	end
end)

local target = SS13.new("/mob/living/basic/bear", user:get_var("mob"):get_var("loc"))
target:set_var("real_name", "living painting")
target:set_var("desc", "It seems to constantly be shapeshifting its form.")
target:set_var("attack_verb_continuous", "bashes")
target:set_var("attack_verb_simple", "bash")
target:set_var("friendly_verb_continuous", "frames")
target:set_var("friendly_verb_simple", "frame")
target:get_var("faction"):add("neutral")
target:set_var("density", false)
target:set_var("move_resist", 600000)
target:set_var("status_flags", 0)
dm.global_proc("qdel", target:get_var("ai_controller"))
target:set_var("plane", -9)
target:set_var("pass_flags", 17)

target:call_proc("_AddElement", { dm.global_proc("_text2path", "/datum/element/relay_attackers")})

local frames = {
	"Let the painting decide",
	"frameless",
	"simple",
	"iron",
	"bamboo",
	"bones",
	"bronze",
	"clown",
	"frog",
	"silver",
	"necropolis",
	"gold",
	"diamond",
	"rainbow",
	"supermatter"
}

local emptyIcon = SS13.new("/icon", "icons/obj/art/artstuff.dmi", "24x24")
emptyIcon:call_proc("DrawBox", nil, 0, 0, 64, 64)

local bigEmptyIcon = SS13.new("/icon", "icons/obj/art/artstuff_64x64.dmi", "36x24")
local smallEmptyIcon = SS13.new("/icon", "icons/obj/art/artstuff.dmi", "24x24")

local toClean = {}

local ttsVoices = {}

for _, value in dm.global_vars:get_var("SStts"):get_var("available_speakers") do
	table.insert(ttsVoices, value)
end

function setupPlayer(player)
	local randomPainting
	local paintingIcon
	local pixelX
	local pixelY
	local iconState
	local frameType
	local frameIcon
	local iconScale = 1
	local offsetX = 0
	local offsetY = 0
	local offsetYScale = 0
	local selectPainting = SS13.new("/atom/movable/screen/text")
	local selectFrame = SS13.new("/atom/movable/screen/text")
	local selectSize = SS13.new("/atom/movable/screen/text")

	selectFrame:set_var("screen_loc", "WEST:4,CENTER-0:-11")
	selectFrame:set_var("maptext_width", 120)
	selectFrame:set_var("maptext_height", 15)
	selectFrame:set_var("mouse_opacity", 2)
	selectFrame:set_var("maptext", "<span class='maptext' style='color: #ffa8a8;'>Select Frame</span>")
	selectPainting:set_var("screen_loc", "WEST:4,CENTER-0:0")
	selectPainting:set_var("maptext_width", 120)
	selectPainting:set_var("maptext_height", 15)
	selectPainting:set_var("mouse_opacity", 2)
	selectPainting:set_var("maptext", "<span class='maptext' style='color: #ffa8a8;'>Select Random Painting</span>")
	selectSize:set_var("screen_loc", "WEST:4,CENTER-0:11")
	selectSize:set_var("maptext_width", 120)
	selectSize:set_var("maptext_height", 15)
	selectSize:set_var("mouse_opacity", 2)
	selectSize:set_var("maptext", "<span class='maptext' style='color: #ffa8a8;'>Select Size</span>")
	function updateIcon()
		local offsets = {
			["11x11"] = { 11, 10 },
			["19x19"] = { 7, 7 },
			["23x19"] = { 5, 7 },
			["23x23"] = { 5, 5 },
			["24x24"] = { 4, 4 },
			["36x24"] = { 14, 4 },
			["45x27"] = { 9, 4 },
		}
	
		local w = paintingIcon:call_proc("Width")
		local h = paintingIcon:call_proc("Height")
		iconState = w .. "x" .. h
		local offset = offsets[iconState]
		pixelX = offset[1]
		pixelY = offset[2]
		offsetX = 0
		offsetY = 0
		offsetYScale = 0
		local chosenFrameType = frameType
		if chosenFrameType == nil then
			chosenFrameType = randomPainting:get_var("frame_type")
		end

		if w > 32 or h > 32 then
			if chosenFrameType == "frameless" then
				frameIcon = bigEmptyIcon
				bigEmptyIcon:call_proc("DrawBox", nil, 0, 0, 64, 64)
			else
				frameIcon = SS13.new("/icon", "icons/obj/art/artstuff_64x64.dmi", iconState .. "frame_" .. chosenFrameType)
			end
			if w == 36 then
				offsetX = -16
			elseif w == 45 then
				offsetX = -16
			end

			if h == 24 then
				offsetYScale = 14
			elseif h == 27 then
				offsetYScale = 16
			end
		else
			if chosenFrameType == "frameless" then
				frameIcon = smallEmptyIcon
				smallEmptyIcon:call_proc("DrawBox", nil, 0, 0, 32, 32)
			else
				frameIcon = SS13.new("/icon", "icons/obj/art/artstuff.dmi", iconState .. "frame_" .. chosenFrameType)
			end
		end
		frameIcon:call_proc("Blend", paintingIcon, 6, pixelX + 1, pixelY + 1)

		player:set_var("icon", emptyIcon)
		player:call_proc("update_appearance")
	end
	local isOpen = false
	SS13.register_signal(selectPainting, "screen_element_click", function(_, _, _ , params, clickingUser)
		if isOpen or (clickingUser ~= player and clickingUser ~= user:get_var("mob")) then
			return
		end
		local isOpen = false
		SS13.set_timeout(0, function()
			local modifiers = dm.global_proc("_params2list", params)
			if modifiers:get("right") == "1" then
				isOpen = true
				local response = SS13.await(SS13.global_proc, "tgui_input_list", player, "Select Painting", "Painting Selection", paintingsNameMap)
				isOpen = false
				if response == nil then
					return
				end
				randomPainting = paintingsNameMap[response]
			else
				randomPainting = allPaintings[math.random(#allPaintings)]
			end
			paintingIcon = SS13.new("/icon", "data/paintings/images/" .. randomPainting:get_var("md5")  .. ".png")
			player:set_var("voice", ttsVoices[math.random(#ttsVoices)])
			player:set_var("name", randomPainting:get_var("title"))
			updateIcon()
		end)
	end)
	local isOpen = false
	SS13.register_signal(selectFrame, "screen_element_click", function(_, _, _ , _, clickingUser)
		if isOpen or (clickingUser ~= player and clickingUser ~= user:get_var("mob")) then
			return
		end
		SS13.set_timeout(0, function()
			isOpen = true
			local response = SS13.await(SS13.global_proc, "tgui_input_list", player, "Select Frame Type", "Frame Type Selection", frames)
			isOpen = false
			if response == nil then
				return
			end
			if response == "Let the painting decide" then
				frameType = nil
			else
				frameType = response
			end
			player:call_proc("update_appearance")
			updateIcon()
		end)
	end)
	local isOpen = false
	SS13.register_signal(selectSize, "screen_element_click", function(_, _, _ , _, clickingUser)
		if isOpen or (clickingUser ~= player and clickingUser ~= user:get_var("mob")) then
			return
		end
		SS13.set_timeout(0, function()
			isOpen = true
			local response = SS13.await(SS13.global_proc, "tgui_input_number", player, "Select Size", "Select Size", iconScale, 5, 1, 0, false)
			isOpen = false
			if response == nil then
				return
			end
			iconScale = response
			player:call_proc("update_appearance")
		end)
	end)

	SS13.register_signal(player, "atom_update_overlays", function(_, list)
		if randomPainting ~= nil then
			local matrix = dm.global_proc("_matrix", iconScale, 0, 0, 0, iconScale, 0)
			local theFrame = dm.global_proc("mutable_appearance", frameIcon)
			theFrame:set_var("pixel_x", offsetX)
			theFrame:set_var("pixel_y", math.floor(offsetY + offsetYScale * (iconScale - 1) + 0.5))
			theFrame:set_var("appearance_flags", 512)
			theFrame:set_var("transform", matrix)
			list:add(theFrame)
		end
	end)
	SS13.register_signal(player, "parent_qdeleting", function()
		toClean[player] = nil
	end)
	SS13.register_signal(player, "mob_hud_created", function()
		local hud = player:get_var("hud_used")
		local hudElements = hud:get_var("static_inventory")
		hudElements:add(selectFrame)
		hudElements:add(selectPainting)
		hudElements:add(selectSize)
		hud:call_proc("show_hud", hud:get_var("hud_version"))
	end)

	toClean[player] = { selectPainting = selectPainting, selectFrame = selectFrame, selectSize = selectSize  }
end

setupPlayer(target)

function DO_CLEANUP()
	for player, cleanTarget in toClean do
		SS13.unregister_signal(player, "atom_update_overlays")
		SS13.unregister_signal(player, "parent_qdeleting")
		local selectPainting = cleanTarget.selectPainting
		local selectFrame = cleanTarget.selectFrame
		local selectSize = cleanTarget.selectSize
		local hud = player:get_var("hud_used")
		local hudElements = hud:get_var("static_inventory")
		hudElements:remove(selectFrame)
		hudElements:remove(selectPainting)
		hudElements:remove(selectSize)
		hud:call_proc("show_hud", hud:get_var("hud_version"))
		dm.global_proc("qdel", selectPainting)
		dm.global_proc("qdel", selectFrame)
	end
	SS13.unregister_signal(dm.global_vars:get_var("SSdcs"), "!mob_created")
end