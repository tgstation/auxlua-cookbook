SS13 = require("SS13")

local function setupCqc(human)
    local martialArts = SS13.new_untracked("/datum/martial_art/cqc")
    martialArts:call_proc("teach", human)
end

local SSdcs = dm.global_vars:get_var("SSdcs")
SS13.unregister_signal(SSdcs, "!mob_created")
SS13.register_signal(SSdcs, "!mob_created", function(_, target)
    SS13.set_timeout(3, function()
        if SS13.is_valid(target) and SS13.istype(target, "/mob/living/carbon/human") then
            setupCqc(target)
        end
    end)
end)

for _, human in dm.global_vars:get_var("GLOB"):get_var("player_list") do
    if over_exec_usage(0.7) then
        sleep()
    end
    if SS13.istype(human, "/mob/living/carbon/human") then
        setupCqc(human)
    end
end
