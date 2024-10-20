local SS13 = require('SS13')

local admin = "waltermeldron"
local user = dm.global_vars.GLOB.directory[admin].mob

local direction = 1

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
	request:prepare("get", http, "", "", file_name)
	request:begin_async()
	while request:is_complete() == 0 do
		sleep()
	end
	iconsByHttp[http] = SS13.new("/icon", file_name)
	return iconsByHttp[http]
end

local spaghettiMachine = SS13.new("/obj/machinery", user.loc)
spaghettiMachine.name = "spaghetti machine"
spaghettiMachine.icon = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/machines/recycling.dmi")
spaghettiMachine.icon_state = "separator-AO1"
spaghettiMachine.density = true
spaghettiMachine.plane = -3
spaghettiMachine.layer = 4.7

local x = spaghettiMachine.x
local y = spaghettiMachine.y
local z = spaghettiMachine.z
local function locate(x, y, z)
    return dm.global_procs._locate(x, y, z)
end

local position = locate(x, y, z)

SS13.new("/obj/machinery/conveyor/auto", dm.global_procs._get_step(position, direction), direction)
SS13.new("/obj/machinery/conveyor/auto", locate(x, y, z), direction)
SS13.new("/obj/machinery/conveyor/auto", dm.global_procs._get_step(position, directionInverse), direction)

local spaghetti = true
SS13.register_signal(spaghettiMachine, "atom_bumped", function(_, entering_thing)
    SS13.set_timeout(0, function()
        if not SS13.is_valid(entering_thing) then
            return
        end

        local move_dir = dm.global_procs._get_dir( spaghettiMachine.loc, entering_thing.loc)
        if move_dir ~= directionInverse then
            return
        end

        if spaghetti then
            if not SS13.istype(entering_thing, "/mob/living/carbon/human") then
                return
            end

            dm.global_procs.playsound(spaghettiMachine.loc, 'sound/items/welder.ogg', 50, true)
            local spaghet = SS13.new("/obj/item/food/spaghetti/boiledspaghetti", spaghettiMachine.loc)
            entering_thing:forceMove(spaghet)
        else
            if not SS13.istype(entering_thing, "/obj/item/food/spaghetti/boiledspaghetti") then
                return
            end

            dm.global_procs.playsound(spaghettiMachine.loc, 'sound/items/welder.ogg', 50, true)
            for _, thing in entering_thing.contents do
                thing:forceMove(spaghettiMachine.loc)
            end
            SS13.qdel(entering_thing)

        end
    end)
end)

SS13.register_signal(spaghettiMachine, "tool_act_screwdriver", function()
    dm.global_procs.playsound(spaghettiMachine.loc, 'sound/items/screwdriver.ogg', 50, true)
    spaghetti = not spaghetti
    if spaghetti then
        spaghettiMachine.name = "spaghetti machine"
    else
        spaghettiMachine.name = "de-spaghetti machine"
    end
    return 1
end)
SS13.register_signal(spaghettiMachine, "atom_tried_pass", function(_, mover, border_dir)
    if not SS13.istype(mover, "/mob/living/carbon/human") and not SS13.istype(mover, "/obj/item/food/spaghetti/boiledspaghetti") then
        if dm.global_procs._get_dir(spaghettiMachine, mover) == directionInverse then
            return 1
        end
    end
    return
end)
