SS13 = require("SS13")

local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get("waltermeldron")
local markedDatum = user:get_var("holder"):get_var("marked_datum")

SS13.register_signal(markedDatum, "spacemove", function()
    return 1
end)