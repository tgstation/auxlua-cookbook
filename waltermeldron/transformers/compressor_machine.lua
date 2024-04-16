local SS13 = require('SS13')

local admin = "waltermeldron"
local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin):get_var("mob")

local direction = 4

local direction_inverse = {
    [1] = 2,
    [2] = 1,
    [4] = 8,
    [8] = 4
}

local directionInverse = direction_inverse[direction]

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

local spaghettiMachine = SS13.new("/obj/machinery", user:get_var("loc"))
spaghettiMachine:set_var("name", "compressor")
spaghettiMachine:set_var("icon", loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/machines/recycling.dmi"))
spaghettiMachine:set_var("icon_state", "separator-AO1")
spaghettiMachine:set_var("density", true)
spaghettiMachine:set_var("plane", -4)
spaghettiMachine:set_var("layer", 4.7)

local x = spaghettiMachine:get_var("x")
local y = spaghettiMachine:get_var("y")
local z = spaghettiMachine:get_var("z")
local function locate(x, y, z)
    return dm.global_proc("_locate", x, y, z)
end

local position = locate(x, y, z)

SS13.new("/obj/machinery/conveyor/auto", dm.global_proc("_get_step", position, direction), direction)
SS13.new("/obj/machinery/conveyor/auto", locate(x, y, z), direction)
SS13.new("/obj/machinery/conveyor/auto", dm.global_proc("_get_step", position, directionInverse), direction)

local traits_to_add = {
    "resist_low_pressure",
    "resist_high_pressure",
    "resist_cold",
    "resist_heat",
    "no_breath",
    "rad_immunity",
    "bomb_immunity"
}

local spaghetti = true
SS13.register_signal(spaghettiMachine, "atom_bumped", function(_, entering_thing)
    SS13.set_timeout(0, function()
        if not SS13.is_valid(entering_thing) then
            return
        end

        local move_dir = dm.global_proc("_get_dir", spaghettiMachine:get_var("loc"), entering_thing:get_var("loc"))
        if move_dir ~= directionInverse then
            return
        end

        if spaghetti then
            if not SS13.istype(entering_thing, "/mob/living") then
                return
            end

            dm.global_proc("playsound", spaghettiMachine:get_var("loc"), 'sound/items/welder.ogg', 50, true)
            local spaghet = SS13.new_untracked("/obj/item/blackbox", spaghettiMachine:get_var("loc"))
            spaghet:set_var("name", "compressed object")
            spaghet:set_var("w_class", 3)
            entering_thing:call_proc("forceMove", spaghet)
            entering_thing:call_proc("add_traits", traits_to_add, "lua_compressor")
            local enterRef = dm.global_proc("REF", entering_thing)
            SS13.register_signal(spaghet, "atom_attack_hand", function(_, user)
                if dm.global_proc("REF", user) == enterRef then
                    return 1
                end
            end)
        else
            if not SS13.istype(entering_thing, "/obj/item/blackbox") then
                return
            end

            dm.global_proc("playsound", spaghettiMachine:get_var("loc"), 'sound/items/welder.ogg', 50, true)
            for _, thing in entering_thing:get_var("contents") do
                thing:call_proc("forceMove", spaghettiMachine:get_var("loc"))
                thing:call_proc("remove_traits", traits_to_add, "lua_compressor")
            end
            SS13.qdel(entering_thing)

        end
    end)
end)

SS13.register_signal(spaghettiMachine, "tool_act_screwdriver", function()
    dm.global_proc("playsound", spaghettiMachine:get_var("loc"), 'sound/items/screwdriver.ogg', 50, true)
    spaghetti = not spaghetti
    if spaghetti then
        spaghettiMachine:set_var("name", "compressor")
    else
        spaghettiMachine:set_var("name", "uncompressor")
    end
    return 1
end)
SS13.register_signal(spaghettiMachine, "atom_tried_pass", function(_, mover, border_dir)
    if not SS13.istype(mover, "/mob/living") and not SS13.istype(mover, "/obj/item/blackbox") then
        if dm.global_proc("_get_dir", spaghettiMachine, mover) == directionInverse then
            return 1
        end
    end
    return
end)
