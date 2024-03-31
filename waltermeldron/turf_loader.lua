SS13 = require("SS13")

-- TGMC cave walls: https://cdn.discordapp.com/attachments/1129765480295583786/1137051226962399282/cave.dmi cave
-- TGMC frost walls: https://cdn.discordapp.com/attachments/1129765480295583786/1137134773077282876/frostwall.dmi frostwall
-- TGMC reinforced walls: https://cdn.discordapp.com/attachments/1129765480295583786/1137135418157060146/rwall.dmi rwall

local TURF_URL_TO_LOAD = "https://cdn.discordapp.com/attachments/1129765480295583786/1137051226962399282/cave.dmi?ex=6606e479&is=65f46f79&hm=5000dbca5fd3d49b9b79d78739a11dcbdeda8b785018724395994a99f1719c76&"
local TURF_TYPE = "/turf/closed/indestructible/riveted"
local TURF_NAME = "cave wall"
local TURF_COLOR = nil
local ICON_STATE = "cave"

local admin = "waltermeldron"
local adminUser = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin)

CACHED_ICONS = CACHED_ICONS or {}

if not CACHED_ICONS[TURF_URL_TO_LOAD] then
    local request = SS13.new("/datum/http_request")
    local file_name = "tmp/custom_map_icon.dmi"
    request:call_proc("prepare", "get", TURF_URL_TO_LOAD, "", "", file_name)
    request:call_proc("begin_async")
    while request:call_proc("is_complete") == 0 do
        sleep()
    end
    CACHED_ICONS[TURF_URL_TO_LOAD] = SS13.new("/icon", file_name)
end
local turfIcon = CACHED_ICONS[TURF_URL_TO_LOAD]

function setTurfData(turf)
    local previousIconState = turf:get_var("base_icon_state")
    turf:set_var("base_icon_state", ICON_STATE)
    turf:set_var("icon", turfIcon)
    if previousIconState ~= ICON_STATE then
        local icon_state = turf:get_var("icon_state")
        turf:set_var("icon_state", string.gsub(icon_state, previousIconState, ICON_STATE))
    end
    turf:set_var("name", TURF_NAME)
    if TURF_COLOR then
        turf:set_var("color", TURF_COLOR)
    end
end

local location = adminUser:get_var("mob"):get_var("loc")
if not location or location:get_var("z") == nil then
    return
end

local z = location:get_var("z")
local maxX = dm.world:get_var("maxy")
local maxY = dm.world:get_var("maxx")

SS13.wait(1)

for x = 1, maxX do
    for y = 1, maxY do
        if over_exec_usage(0.5) then
            sleep()
        end
        local turf = dm.global_proc("_locate", x, y, z)
        if not SS13.istype(turf, TURF_TYPE) then
            continue
        end
        setTurfData(turf)
    end
end
