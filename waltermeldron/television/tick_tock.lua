SS13 = require("SS13")

local me = dm.global_vars:get_var("GLOB"):get_var("directory"):get("waltermeldron")

local sign = SS13.new("/obj/structure/sign")
sign:set_var("icon_state", "off")
local tv = SS13.new("/obj/structure/showcase/machinery/tv", me:get_var("mob"):get_var("loc"))
tv:get_var("vis_contents"):add(sign)
sign:set_var("pixel_x", 8)
sign:set_var("pixel_y", 10)
sign:set_var("mouse_opacity", 0)

local sound = SS13.new("/obj/effect/mapping_helpers/atom_injector/custom_sound")
sound:set_var("sound_url", "https://cdn.discordapp.com/attachments/1129765480295583786/1130137242938118264/TF2_Tick_Tock_Joji_RvVdFXOFcjw.mp3")
SS13.await(sound, "check_validity")
sign:set_var("icon_preview", sound:get_var("sound_file"))

local icon = SS13.new("/obj/effect/mapping_helpers/atom_injector/custom_icon")
icon:set_var("icon_url", "https://cdn.discordapp.com/attachments/1129765480295583786/1129795771391291463/leavemealone_1_30_11x10.dmi")
SS13.await(icon, "check_validity")
sign:set_var("icon", icon:get_var("icon_file"))

dm.global_proc("qdel", icon)
dm.global_proc("qdel", sound)

sign:set_var("icon_state", "on")

local loopingSound = SS13.new("/datum/looping_sound/local_forecast", tv)
tv:set_var("icon_preview", loopingSound)
local soundFile = sign:get_var("icon_preview"):get_var("file")
loopingSound:get_var("mid_sounds"):set(1, soundFile)
loopingSound:get_var("mid_sounds"):set(soundFile, 1)
loopingSound:set_var("mid_length", 250)
loopingSound:call_proc("start")

SS13.register_signal(tv, "parent_qdeleting", function()
    dm.global_proc("qdel", sign)
    dm.global_proc("qdel", loopingSound)
end)