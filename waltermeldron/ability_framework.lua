local SS13 = require("SS13")

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

local grantAbility = function(mob, abilityData)
	local abilityType = abilityData.ability_type
	local action = SS13.new("/datum/action/cooldown")
	if abilityType == "targeted" then
		action:set_var("click_to_activate", true)
		action:set_var("unset_after_click", true)
		action:set_var("ranged_mousepointer", loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/effects/mouse_pointers/cult_target.dmi"))
	end
	action:set_var("button_icon", loadIcon(abilityData.icon))
	action:set_var("button_icon_state", abilityData.icon_state)
	action:set_var("background_icon_state", "bg_heretic")
	action:set_var("overlay_icon_state", "bg_heretic_border")
	action:set_var("active_overlay_icon_state", "bg_nature_border")
	action:set_var("cooldown_time", (abilityData.cooldown or 0) * 10)
	SS13.register_signal(mob, "mob_ability_base_started", function(source, actionTarget, target) 
		if REF(actionTarget) == REF(action) then
			local returnValue = abilityData:onActivate(mob, action, target)
			if action:get_var("unset_after_click") == 1 then
				action:call_proc("unset_click_ability", source, false)
			end
			source:set_var("next_click", dm.world:get_var("time") + action:get_var("click_cd_override"))
			return returnValue
		end
	end)
	action:set_var("name", abilityData.name)
	action:call_proc("Grant", mob)
	return action
end

-- Put your code stuff down here

local runner = SS13.get_runner_client()
local YOUR_MOB_HERE = runner:get_var("holder"):get_var("marked_datum")

if not SS13.istype(YOUR_MOB_HERE, "/mob") then
    return false
end

grantAbility(YOUR_MOB_HERE, {
    name = "Switch damage types",
    ability_type = "normal",
    icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_minor_antag.dmi",
    icon_state = "infect",
    cooldown = 0,
    onActivate = function(self, mob, action, target)
        -- Put your code here when this button is pressed
    end
})