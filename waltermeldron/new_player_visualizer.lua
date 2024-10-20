local SS13 = require('SS13')

admins = {
    ["waltermeldron"] = true,
    ["striders13"] = true,
    ["raveradbury"] = true,
    ["maxipat"] = true,
    ["aiia"] = true,
    ["omegadarkpotato"] = true,
    ["dendydoom"] = true,
    ["darkenedearth"] = true,
    ["cheshify"] = true,
    ["thedragmeme"] = true,
    ["archie700"] = true,
    ["xzero314"] = true,
    ["bmon"] = true
}

local year = 2024
local month = 5
local day = 14

if VISUALIZED_PLAYERS then
    for ref, image in VISUALIZED_PLAYERS do
        for admin, _ in admins do
            local adminClient = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin)
            if adminClient then
                dm.global_proc("_list_remove", adminClient:get_var("images"), image)
            end
        end
    end
end

VISUALIZED_PLAYERS = {}

local REF = function(datum)
    return dm.global_proc("REF", datum)
end

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

local imageIcon = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/huds/antag_hud.dmi")

local function addImages(mob)
    for ref, image in VISUALIZED_PLAYERS do
        local images = mob:get_var("images")
        dm.global_proc("_list_add", images, image)
    end
end

local function addImage(image)
    for admin, _ in admins do
        local adminClient = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin)
        if adminClient then
            dm.global_proc("_list_add", adminClient:get_var("images"), image)
        end
    end
end

local function removeImage(image)
    for admin, _ in admins do
        local adminClient = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin)
        if adminClient then
            dm.global_proc("_list_remove", adminClient:get_var("images"), image)
        end
    end
end

function addAdmin(ckey)
    admins[ckey] = true
    local admin = dm.global_vars:get_var("GLOB"):get_var("directory"):get(ckey)
    addImages(admin)
end

function removeAdmin(ckey)
    admins[ckey] = false
end

local function isBadDate(date)
    if not date then
        return false
    end
    local actualDate = string.split(date, " ")
    if #actualDate == 0 then
        return false
    end
    local date = string.split(actualDate[1], "-")
    if #date ~= 3 then
        return false
    end
    local cYear = tonumber(date[1])
    local cMonth = tonumber(date[2])
    local cDay = tonumber(date[3])
    if cYear < year then
        return false
    elseif cYear > year then
        return true
    end

    if cMonth < month then
        return false
    elseif cMonth > month then
        return true
    end

    if cDay < day then
        return false
    elseif cDay >= day then
        return true
    end
    return true
end

local function doCheck(mob)
    if SS13.istype(mob, "/mob/dead") and admins[mob:get_var("ckey")] then
        addImages(mob:get_var("client"))
        return
    end

    if mob:get_var("client") == nil then
        return
    end

    if isBadDate(mob:get_var("client"):get_var("player_join_date")) then
        local image = dm.global_proc("_image", imageIcon, mob, "Grove")
        image:set_var("pixel_z", -8)
        local ref = REF(mob)
        VISUALIZED_PLAYERS[ref] = image
        addImage(image)
        local callback
        callback = SS13.register_signal(mob, "mob_logout", function(_, mob)
            VISUALIZED_PLAYERS[ref] = nil
            removeImage(image)
            SS13.stop_tracking(image)
            SS13.unregister_signal(mob, "mob_logout", callback)
        end)
    end
end

local SSdcs = dm.global_vars:get_var("SSdcs")
SS13.unregister_signal(SSdcs, "!mob_logged_in")
SS13.register_signal(SSdcs, "!mob_logged_in", function(_, mob)
    doCheck(mob)
end)

for _, ply in dm.global_vars:get_var("GLOB"):get_var("player_list") do
    doCheck(ply) 
end
