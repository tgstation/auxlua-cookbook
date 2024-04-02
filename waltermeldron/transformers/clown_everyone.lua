local SS13 = require("SS13")

local function setupCqc(human)
    SS13.qdel(human:get_var("wear_mask"))
    SS13.qdel(human:get_var("shoes"))
    local pastId = human:get_var("wear_id")
    local access
    if SS13.istype(pastId, "/obj/item/card/id") then
        access = pastId:get_var("access"):to_table()
    end

    human:call_proc("equipOutfit", dm.global_proc("_text2path", "/datum/outfit/job/clown"))
    local newId = human:get_var("wear_id")
    if access and SS13.istype(newId, "/obj/item/card/id") then
        newId:set_var("access", access)
    end
end

local SSdcs = dm.global_vars:get_var("SSdcs")
SS13.unregister_signal(SSdcs, "!job_after_spawn")
SS13.register_signal(SSdcs, "!job_after_spawn", function(_, target)
    SS13.set_timeout(0.1, function()
        if SS13.is_valid(target) and SS13.istype(target, "/mob/living/carbon/human") then
            setupCqc(target)
        end
    end)
end)

for _, human in dm.global_vars:get_var("GLOB"):get_var("player_list") do
    if over_exec_usage(0.2) then
        sleep()
    end
    if SS13.istype(human, "/mob/living/carbon/human") then
        setupCqc(human)
    end
end
