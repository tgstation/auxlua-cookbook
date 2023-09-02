SS13 = require("SS13")

-- Change this to your ckey so that this works. Don't run it with my ckey please :)
local admin = "waltermeldron"

local me = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin)
local spawnLocation = me:get_var("mob"):get_var("loc")

channels = {
    ["Bad Apple - Mr Beast"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1129834362465177730/mrbeast_3_10_false_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1129834335499985137/badapple_beast.mp3",
        duration = 2160
    },
    ["Tick Tock"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1129795771391291463/leavemealone_1_30_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1129788482269761587/leavemealone.mp3",
        duration = 70
    },
    ["Rick Roll"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1129849496482881696/rickroll_1_25_false_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1129845646732562523/rickroll.mp3",
        duration = 2120
    },
    ["Bad Apple"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1129934876100006048/badapple_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1129799410029695137/badapple.mp3",
        duration = 2190
    },
    ["Yeah Baby!"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1129948547672977508/gaming_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1129938689997426818/audio.mp3",
        duration = 100,
    },
    ["PPAP"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130101955818164244/ppap_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130101922645413888/audio.mp3",
        duration = 1530
    },
    ["Heavy is dead"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130103379104911391/heavydead_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130103416115433493/audio.mp3",
        duration = 1670
    },
    ["Assistant's Ultimatum"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130112081656561664/ultimatum_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130112103508877352/audio.mp3",
        duration = 1110
    },
    ["Markiplier"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130131290075713676/markiplier_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130131316764057600/audio.mp3",
        duration = 190
    },
    ["Oppenheimer Style"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130131734508339260/oppenheimer_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130131718477721610/audio.mp3",
        duration = 450
    },
    ["Shadow Wizard Gang"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130170295190290462/shadowwizard_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130170294129139774/audio.mp3",
        duration = 300
    },
    ["Fortnite Battlepass"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130254432832077964/fortnitebattlepass_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130254432542675066/audio.mp3",
        duration = 120
    },
    ["Help me!"] = {
        icon = "https://cdn.discordapp.com/attachments/1129765480295583786/1130255517177086024/helpme_11x10.dmi",
        audio = "https://cdn.discordapp.com/attachments/1129765480295583786/1130255516879298570/audio.mp3",
        duration = 140
    }
}

possibleChannels = {}
for channelName, channel in channels do
    local sound = SS13.new("/obj/effect/mapping_helpers/atom_injector/custom_sound")
    sound:set_var("sound_url", channel.audio)
    SS13.await(sound, "check_validity")

    local icon = SS13.new("/obj/effect/mapping_helpers/atom_injector/custom_icon")
    icon:set_var("icon_url", channel.icon)
    SS13.await(icon, "check_validity")
    
    channel.icon_file = icon:get_var("icon_file")
    channel.sound_file = sound:get_var("sound_file")
    
    dm.global_proc("qdel", icon)
    dm.global_proc("qdel", sound)
    table.insert(possibleChannels, channelName)
    sleep()
end

local currentChannel = channels["Tick Tock"]

local sign = SS13.new("/obj/structure/sign")
sign:set_var("icon_state", "off")
sign:set_var("vis_flags", 16)
local tv = SS13.new("/obj/structure/showcase/machinery/tv", spawnLocation)
tv:get_var("vis_contents"):add(sign)
sign:set_var("pixel_x", 8)
sign:set_var("pixel_y", 10)
sign:set_var("mouse_opacity", 0)

sign:set_var("icon", currentChannel.icon_file)

local playingChannel
local animationEnd = 0
local channel = 1023
local listeners = {}
local function playBadApple(players)
    while animationEnd > dm.world:get_var("time") and not tv:is_null() and tv:get_var("gc_destroyed") == nil do
        if playingChannel == nil then
            break
        end
        if tv:is_null() or tv:get_var("gc_destroyed") ~= nil then
            break
        end
        local location = tv:get_var("loc")
        for _, player in players do
            if animationEnd <= dm.world:get_var("time") then
                break
            end
            if playingChannel == nil then
                break
            end
            if player:is_null() then
                continue
            end
            local playerPos = player:call_proc("drop_location")
            local dist = dm.global_proc("_get_dist", playerPos, location)
            local volume = 20
            local playLocation = location
            if not SS13.istype(location, "/turf") or dist > 12 or location:get_var("z") ~= playerPos:get_var("z") then
                playLocation = nil
                volume = 0
            end
            player:call_proc("playsound_local", playLocation, playingChannel.sound_file, volume, false, nil, 6, channel, true, playingChannel.sound_file, 17, 1, 1, true)
        end
        sleep()
    end
    animationEnd = 0
    for _, player in dm.global_vars:get_var("GLOB"):get_var("player_list") do
        player:call_proc("stop_sound_channel", channel)
    end
    if not sign:is_null() then
        sign:set_var("icon_state", "off")
        dm.global_proc("_flick", "off", sign)
    end
end

local function playClip()
    if currentChannel.duration > 300 then
        sign:set_var("icon_state", "on")
    end
    SS13.set_timeout(0, function()
        if animationEnd > dm.world:get_var("time") then
            return
        end
        dm.global_proc("_flick", "on", sign)
        playingChannel = currentChannel
        animationEnd = dm.world:get_var("time") + playingChannel.duration
        playingChannel.sound_file:set_var("status", 0)
        local playerList = {}
        local adminMidiType = dm.global_proc("_text2path", "/datum/preference/toggle/sound_midi")
        local tvZLoc = tv:call_proc("drop_location"):get_var("z")
        local sleepCount = 1
        for _, player in dm.global_vars:get_var("GLOB"):get_var("player_list") do
            if sleepCount % 50 == 0 then
                sleep()
            end
            if player:is_null() then
                continue 
            end
            if (SS13.istype(player, "/mob/dead/observer") or player:call_proc("drop_location"):get_var("z") == tvZLoc) and player:get_var("client"):get_var("prefs"):call_proc("read_preference", adminMidiType) ~= 0 then
                player:call_proc("playsound_local", nil, playingChannel.sound_file, 0, false, nil, 6, channel, true, playingChannel.sound_file, 17, 1, 1, true)
                table.insert(playerList, player)
            end
            sleepCount += 1
        end
        playingChannel.sound_file:set_var("status", 16)
        playBadApple(playerList)
        if playingChannel ~= nil then
            currentChannel = channels[possibleChannels[math.random(#possibleChannels)]]
            sign:set_var("icon", currentChannel.icon_file)
        end
    end)
end

SS13.register_signal(tv, "parent_qdeleting", function()
    dm.global_proc("qdel", sign)
    for _, player in dm.global_vars:get_var("GLOB"):get_var("player_list") do
        player:call_proc("stop_sound_channel", channel)
    end
end)
SS13.register_signal(tv, "atom_attack_hand", playClip)
SS13.register_signal(tv, "ctrl_shift_click", function(_, clicker)
    if clicker:get_var("ckey") == admin then
        playClip()
    end
end)
local isOpen = false
SS13.register_signal(tv, "ctrl_click", function(_, clicker)
    if isOpen then
        return
    end
    if clicker:get_var("ckey") == admin then
        SS13.set_timeout(0, function()
            isOpen = true
            local input = SS13.await(SS13.global_proc, "tgui_input_list", clicker, "Select Channel", "Select Channel", channels)
            isOpen = false
            if input == nil then
                return
            end
            currentChannel = channels[input]
            playingChannel = nil
            dm.global_proc("_flick", "off", sign)
            sign:set_var("icon_state", "off")
            sign:set_var("icon", currentChannel.icon_file)
        end)
    end
end)
SS13.register_signal(tv, "tool_act_screwdriver", function()
    return 1
end)
SS13.register_signal(tv, "tool_secondary_act_screwdriver", function()
    return 1
end)
SS13.register_signal(tv, "tool_act_crowbar", function()
    return 1
end)
SS13.register_signal(tv, "tool_secondary_act_crowbar", function()
    return 1
end)