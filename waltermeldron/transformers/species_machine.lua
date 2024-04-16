local SS13 = require('SS13')

local admin = "waltermeldron"
local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin):get_var("mob")
local targetSpecies = "/datum/species/human/felinid"
local machineName = "felinid machine"

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
spaghettiMachine:set_var("name", machineName)
spaghettiMachine:set_var("icon", loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/machines/recycling.dmi"))
spaghettiMachine:set_var("icon_state", "separator-AO1")
spaghettiMachine:set_var("density", true)
spaghettiMachine:set_var("plane", -3)
spaghettiMachine:set_var("layer", 4.7)

local x = spaghettiMachine:get_var("x")
local y = spaghettiMachine:get_var("y")
local z = spaghettiMachine:get_var("z")
local function locate(x, y, z)
    return dm.global_proc("_locate", x, y, z)
end

SS13.new("/obj/machinery/conveyor/auto", locate(x, y - 1, z), 2)
SS13.new("/obj/machinery/conveyor/auto", locate(x, y, z), 2)
SS13.new("/obj/machinery/conveyor/auto", locate(x, y + 1, z), 2)

SS13.register_signal(spaghettiMachine, "atom_bumped", function(_, entering_thing)
    SS13.set_timeout(0, function()
        if not SS13.is_valid(entering_thing) or not SS13.istype(entering_thing, "/mob/living/carbon/human") or dm.global_proc("is_species", entering_thing, SS13.type(targetSpecies)) == 1 then
            return
        end

        local move_dir = dm.global_proc("_get_dir", spaghettiMachine:get_var("loc"), entering_thing:get_var("loc"))
        if move_dir ~= 1 then
            return
        end

        dm.global_proc("playsound", spaghettiMachine:get_var("loc"), 'sound/items/welder.ogg', 50, true)
        entering_thing:call_proc("set_species", SS13.type(targetSpecies))
        entering_thing:call_proc("forceMove", spaghettiMachine:get_var("loc"))
    end)
end)

SS13.register_signal(spaghettiMachine, "atom_tried_pass", function(_, mover, border_dir)
    if not SS13.istype(mover, "/mob/living/carbon/human") then
        if dm.global_proc("_get_dir", spaghettiMachine, mover) == 1 then
            return 1
        end
    end
    return
end)
