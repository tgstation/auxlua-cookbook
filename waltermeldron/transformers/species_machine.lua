local SS13 = require('SS13')

local admin = "waltermeldron"
local user = dm.global_vars.GLOB.directory[admin].mob
local targetSpecies = "/datum/species/human/felinid"
local machineName = "felinid machine"

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
spaghettiMachine.name = machineName
spaghettiMachine.icon = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/machines/recycling.dmi")
spaghettiMachine.icon_state = "separator-AO1"
spaghettiMachine.density = true
spaghettiMachine.plane = -3
spaghettiMachine.layer = 4.7

local x = spaghettiMachine.x
local y = spaghettiMachine.y
local z = spaghettiMachine.z
local locate = dm.global_procs._locate

SS13.new("/obj/machinery/conveyor/auto", locate(x, y - 1, z), 2)
SS13.new("/obj/machinery/conveyor/auto", locate(x, y, z), 2)
SS13.new("/obj/machinery/conveyor/auto", locate(x, y + 1, z), 2)

SS13.register_signal(spaghettiMachine, "atom_bumped", function(_, entering_thing)
    SS13.set_timeout(0, function()
        if not SS13.is_valid(entering_thing) or not SS13.istype(entering_thing, "/mob/living/carbon/human") or dm.global_procs.is_species(entering_thing, SS13.type(targetSpecies)) == 1 then
            return
        end

        local move_dir = dm.global_procs._get_dir(spaghettiMachine.loc, entering_thing.loc)
        if move_dir ~= 1 then
            return
        end

        dm.global_procs.playsound(spaghettiMachine.loc, 'sound/items/tools/welder.ogg', 50, true)
        entering_thing:set_species(SS13.type(targetSpecies))
        entering_thing:forceMove(spaghettiMachine.loc)
    end)
end)

SS13.register_signal(spaghettiMachine, "atom_tried_pass", function(_, mover, border_dir)
    if not SS13.istype(mover, "/mob/living/carbon/human") then
        if dm.global_procs._get_dir(spaghettiMachine, mover) == 1 then
            return 1
        end
    end
    return
end)
