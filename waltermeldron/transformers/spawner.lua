local SS13 = require("SS13")

local location = SS13.get_runner_client():get_var("mob"):get_var("loc")

SS13.start_loop(1, -1, function()
    local human = SS13.new("/mob/living/carbon/human", location)
    human:call_proc("equipOutfit", SS13.type("/datum/outfit/job/assistant"))
end)