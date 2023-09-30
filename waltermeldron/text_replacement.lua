SS13 = require('SS13')

function processMessage(message)
	local frenchWords = dm.global_vars:get_var("GLOB"):get_var("string_cache"):get("french_replacement.json"):get("french")
	for key, value in pairs(frenchWords:to_table()) do
		if type(value) ~= "string" then
			value = dm.global_proc("_pick_list", value)
		end
		message = string.gsub(message, "^"..string.upper(key), string.upper(value))
		message = string.gsub(message, "^"..dm.global_proc("capitalize", key), dm.global_proc("capitalize", value))
		message = string.gsub(message, "^"..key, value)
		message = string.gsub(message, " "..string.upper(key), " "..string.upper(value))
		message = string.gsub(message, " "..dm.global_proc("capitalize", key), " "..dm.global_proc("capitalize", value))
		message = string.gsub(message, " "..key, " "..value)
	end
	if(math.random(1, 100) <= 3) then
		message = message .. dm.global_proc("_pick", " Honh honh honh!"," Honh!"," Zut Alors!")
	end
	return message
end

local function makeFrench(player)
	SS13.unregister_signal(player, "mob_say")
	SS13.unregister_signal(player, "mob_deadsay")
	SS13.register_signal(player, "mob_say", function(source, speech_args)
		local message = processMessage(speech_args:get(1))
		speech_args:set(1, dm.global_proc("trim", message))
	end)
	local allowPlayer = false
	SS13.register_signal(player, "mob_deadsay", function(source, message)
		if allowPlayer then
			return
		end
		message = processMessage(message)
		SS13.set_timeout(0, function()
			allowPlayer = true
			player:call_proc("say_dead", message)
			allowPlayer = false
		end)
		return 1
	end)
	dm.global_proc("_add_trait", player, "kiss_of_garlic_breath", "admin_stuff")
end

local SSdcs = dm.global_vars:get_var("SSdcs")
SS13.unregister_signal(SSdcs, "!mob_created")
SS13.register_signal(SSdcs, "!mob_created", function(_, mob)
	makeFrench(mob)
end)

for _, player in dm.global_vars:get_var("GLOB"):get_var("mob_list") do
	if over_exec_usage(0.8) then
		sleep()
	end
	makeFrench(player)
end