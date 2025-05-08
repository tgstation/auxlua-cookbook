local SS13 = require("SS13")

local REF = dm.global_procs.REF

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

local grantAbility = function(mob, abilityData)
	local abilityType = abilityData.ability_type
	local action = SS13.new("/datum/action/cooldown")
	if abilityType == "targeted" then
		action.click_to_activate = true
		action.unset_after_click = true
		action.ranged_mousepointer = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/effects/mouse_pointers/cult_target.dmi")
	end
	action.button_icon = loadIcon(abilityData.icon)
	action.button_icon_state = abilityData.icon_state
	action.background_icon_state = "bg_heretic"
	action.overlay_icon_state = "bg_heretic_border"
	action.active_overlay_icon_state = "bg_nature_border"
	action.cooldown_time = (abilityData.cooldown or 0) * 10
	SS13.register_signal(mob, "mob_ability_base_started", function(source, actionTarget, target) 
		if REF(actionTarget) == REF(action) then
			local returnValue = abilityData:onActivate(mob, action, target)
			if action.unset_after_click == 1 then
				action:unset_click_ability(source, false)
			end
			source.next_click = dm.world.time + action.click_cd_override
			return returnValue
		end
	end)
	action.name = abilityData.name
	action:Grant(mob)
	return action
end

-- Put your code stuff down here

local runner = SS13.get_runner_client()
local YOUR_MOB_HERE = runner.holder.marked_datum

if not SS13.istype(YOUR_MOB_HERE, "/mob") then
    return false
end

grantAbility(YOUR_MOB_HERE, {
    name = "Switch damage types",
	-- "normal" or "targeted"
	-- "targeted" means that target in the onActivate function is set to whatever the user targets with the ability.
    ability_type = "targeted",
    icon = "https://raw.githubusercontent.com/tgstation/tgstation/master/icons/mob/actions/actions_minor_antag.dmi",
    icon_state = "infect",
    cooldown = 0,
    onActivate = function(self, mob, action, target)
        -- Put your code here when this button is pressed
		print("test")
    end
})