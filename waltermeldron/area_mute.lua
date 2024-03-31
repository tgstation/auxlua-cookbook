SS13 = require("SS13")

local admin = SS13.get_runner_ckey()
local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin):get_var("mob")
local area = dm.global_proc("_get_step", user, 0):get_var("loc")

local function setupMutingProcedure(human)
	SS13.unregister_signal(human, "movable_pre_hear")
    SS13.register_signal(human, "movable_pre_hear", function(_, listData)
        if human:get_var("ckey") == admin then
            return
        end
        local humanLoc = dm.global_proc("_get_step", human, 0)
        if not humanLoc then
            return
        end
        local humanArea = humanLoc:get_var("loc")
        if humanArea:get_var("type") ~= area:get_var("type") then
            return
        end
        local speaker = listData:get(2)
        local speakerLoc = dm.global_proc("_get_step", speaker, 0)
        if not speakerLoc then
            return 1
        end
        local speakerArea = speakerLoc:get_var("loc")
        if speakerArea:get_var("type") ~= area:get_var("type") then
            return 1
        end
    end)
end

local function main()
	local SSdcs = dm.global_vars:get_var("SSdcs")
	SS13.unregister_signal(SSdcs, "!mob_created")
	SS13.register_signal(SSdcs, "!mob_created", function(_, target)
		SS13.set_timeout(0, function()
			if SS13.is_valid(target) and SS13.istype(target, "/mob/living") then
                setupMutingProcedure(target)
			end
		end)
	end)

	for _, human in dm.global_vars:get_var("GLOB"):get_var("mob_list") do
		if over_exec_usage(0.7) then
			sleep()
		end
		if SS13.istype(human, "/mob/living") then
			setupMutingProcedure(human)
		end
	end
end

main()