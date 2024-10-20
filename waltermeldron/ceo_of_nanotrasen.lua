local SS13 = require("SS13")

local client = SS13.get_runner_client()

local target = client:get_var("holder"):get_var("marked_datum")

if not SS13.istype(target, "/mob/living/carbon/human") then
	print("ERROR: Need to mark a human target")
	return
end

local ANTAG_COUNT = 5
local doInit = false

if not __CEO_job then
	__CEO_job = SS13.new("/datum/job/unassigned")
	doInit = true
end
__CEO_job:set_var("title", "CEO of Nanotrasen")
__CEO_job:set_var("rpg_title", "Star Emperor")

local function setupCEO()
	target:call_proc("mind_initialize")
	local mind = target:get_var("mind")
	mind:call_proc("set_assigned_role", __CEO_job)
	local antag = SS13.new_untracked("/datum/antagonist/custom")
	antag:set_var("antag_hud_name", "fugitive_hunter")
	antag:set_var("name", "CEO of Nanotrasen")
	antag:set_var("show_to_ghosts", true)
	antag:set_var("antagpanel_category", "CentCom")
	mind:call_proc("add_antag_datum", antag)
	mind:set_var("special_role", "CEO")
end

if doInit then
	setupCEO()
end

local function setupAntag(human)
    local mind = human:get_var("mind")
	if not mind then
		return false
	end
    local antag = SS13.new("/datum/antagonist/custom")
	antag:set_var("antag_hud_name", "battlecruiser_crew")
	antag:set_var("name", "Syndicate Sleeper Assassin")
	local objectives = antag:get_var("objectives")
	local objective = SS13.new_untracked("/datum/objective/assassinate")
	objective:set_var("owner", mind)
	objective:set_var("target", target:get_var("mind"))
	objective:call_proc("update_explanation_text")
	objectives:add(objective)
	objective = SS13.new_untracked("/datum/objective/custom")
	objective:set_var("owner", mind)
	objective:set_var("explanation_text", "You are not a rule 4 antagonist. Do not use this as a license to grief when it isn't related to your objectives. Stick to your objectives.")
	objective:set_var("completed", true)
	objectives:add(objective)
	antag:set_var("show_to_ghosts", true)
	antag:set_var("antagpanel_category", "Assassins")
	dm.global_proc("to_chat", human, "<span class='userdanger'>bzzzt..</span>")
	local turf = dm.global_proc("_get_step", human, 0)
	dm.global_proc("do_sparks", 2, true, turf)
	human:call_proc("playsound_local", turf, "sound/machines/ding.ogg", 50, false)
	SS13.set_timeout(2, function()
		dm.global_proc("to_chat", human, "<span class='hypnophrase' style='font-size: 32px'>DING!</span>")
		mind:call_proc("add_antag_datum", antag)
		dm.global_proc("to_chat", human, "<span class='userdanger'>Directives received</span><br><span class='danger'>1. Kill the CEO of Nanotrasen</span>")
		human:call_proc("playsound_local", turf, "sound/ambience/antag/tatoralert.ogg", 100, false)
		mind:set_var("special_role", "Assassin")
	end)
	return true
end


local players = dm.global_vars:get_var("GLOB"):get_var("alive_player_list"):to_table()

local antags = 0
local count = #players
while antags < ANTAG_COUNT and #players > 0 do
	if over_exec_usage(0.7) then
		sleep()
	end
	local index = math.random(1, #players)
	local selectedPlayer = players[index]
	local client = selectedPlayer:get_var("client")
	table.remove(players, index)
	local mind = selectedPlayer:get_var("mind")
	local role = mind:get_var("assigned_role")
	if not role or not mind or not client or SS13.istype(role, "/datum/job/unassigned") then
		continue
	end
	if bit32.band(role:get_var("departments_bitflags"), 128) ~= 0 then
		continue
	end
	if mind:get_var("special_role") then
		continue
	end
	
	local wantsToBe = false
	for _, string in client:get_var("prefs"):get_var("be_special") do
		if string == "Traitor" then
			wantsToBe = true
			break
		end
	end

	if not wantsToBe then
		continue
	end

	if not SS13.istype(selectedPlayer, "/mob/living/carbon/human") then
		continue
	end

	setupAntag(selectedPlayer)
	antags += 1
end

print("Selected", antags, "antags")