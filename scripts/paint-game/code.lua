SS13 = require("SS13")

local usr = dm.usr:get_var("client")

local loc = {
	x = dm.usr:get_var("x"),
	y = dm.usr:get_var("y"),
	z = dm.usr:get_var("z"),
}

local function locate(x, y, z)
	z = z or loc.z
	return dm.global_proc("_locate", x, y, z)
end

local function block(turfA, turfB)
	return dm.global_proc("_block", turfA, turfB)
end

local function setTurf(turf, new_path)
	local location = {
		turf:get_var("x"),
		turf:get_var("y"),
		turf:get_var("z"),
	}
	turf:call_proc("ChangeTurf", new_path)
	return locate(table.unpack(location))
end

local function createSetTurfFunc(new_path)
	return function(turf)
		setTurf(turf, new_path)
	end
end

local function applyOutfit(target, dresscode)
	target:set_var("l_store", nil)
	target:set_var("r_store", nil)
	target:set_var("s_store", nil)
	usr:call_proc("admin_apply_outfit", target, dm.global_proc("_text2path", dresscode))
end

local setAlienTurf = createSetTurfFunc("/turf/open/floor/circuit/green")

for _, turf in block(locate(loc.x - 1, loc.y - 1), locate(loc.x + 1, loc.y + 1)):to_table() do
	setAlienTurf(turf)
end

local greenTurf = locate(loc.x - 1, loc.y - 1)
local redTurf = locate(loc.x - 1, loc.y + 1)
local blueTurf = locate(loc.x + 1, loc.y + 1)
local purpleTurf = locate(loc.x + 1, loc.y - 1)

greenTurf = setTurf(greenTurf, "/turf/open/floor/carpet/neon/simple/green")
redTurf = setTurf(redTurf, "/turf/open/floor/carpet/neon/simple/red")
blueTurf = setTurf(blueTurf, "/turf/open/floor/carpet/neon/simple/blue")
purpleTurf = setTurf(purpleTurf, "/turf/open/floor/carpet/neon/simple/purple")

SS13.wait(1)

local function REF(obj)
	return dm.global_proc("REF", obj)
end

if DESTRUCT_CLEANUP_TURFS then
	DESTRUCT_CLEANUP_TURFS()
end

-- selene: allow(unscoped_variables)
-- If the humans in this table are not deleted, they'll be teleported to a turf when this script is ran again.
humans = humans or {}
local takenTurfs = {}

local function updateScore(data)
	data.human:set_var(
		"maptext",
		string.format("<span class='maptext'>Score: %d<br />%s</span>", data.score, data.class)
	)
end

local function setupHuman(name, location, color)
	if not humans[name] or REF(humans[name].human) == "[0x0]" or humans[name].human:get_var("gc_destroyed") ~= nil then
		humans[name] = {
			human = SS13.new("/mob/living/carbon/human", location),
			color = color,
		}
	else
		humans[name].human:call_proc("forceMove", location)
	end
	local human = humans[name].human
	humans[name].score = 0
	humans[name].highestScore = 0
	humans[name].class = "Prisoner"
	humans[name].rewardsReceived = {}

	applyOutfit(human, "/datum/outfit/job/prisoner")
	human:call_proc("revive", true, true)
	human:set_var("maptext_width", 128)
	human:set_var("maptext_y", 30)
	updateScore(humans[name])

	sleep()
end

setupHuman("green", greenTurf, "#00ff00")
setupHuman("red", redTurf, "#ff0000")
setupHuman("blue", blueTurf, "#0000ff")
setupHuman("purple", purpleTurf, "#6a0dad")

local classes = {
	firstClass = {
		{ "Assistant", "/datum/outfit/job/assistant" },
	},
	secondClass = {
		{ "Scientist", "/datum/outfit/job/scientist" },
		{ "Engineer", "/datum/outfit/job/engineer" },
		{ "Cook", "/datum/outfit/job/cook" },
		{ "Doctor", "/datum/outfit/job/doctor" },
	},
	thirdClass = {
		{ "Chief Medical Officer", "/datum/outfit/job/cmo" },
		{ "Chief Engineer", "/datum/outfit/job/ce" },
		{ "Quartermaster", "/datum/outfit/job/quartermaster" },
		{ "Research Director", "/datum/outfit/job/rd" },
	},
	fourthClass = {
		{ "Captain", "/datum/outfit/job/captain" },
	},
	ertClass = {
		{ "Response Team Leader", "/datum/outfit/centcom/ert/commander" },
		{ "Response Team Medic", "/datum/outfit/centcom/ert/medic" },
		{ "Response Team Engineer", "/datum/outfit/centcom/ert/engineer" },
		{ "Response Team Security", "/datum/outfit/centcom/ert/security" },
	},
	finalClass = {
		{ "Death Commando", "/datum/outfit/centcom/death_commando" },
	},
}

local function applyClass(className, data)
	local class = classes[className][math.random(1, #classes[className])]
	data.class = class[1]
	applyOutfit(data.human, class[2])
end

local function handleRewards(data)
	if data.highestScore >= 10 and not data.rewardsReceived.firstClass then
		data.rewardsReceived.firstClass = true
		applyClass("firstClass", data)
	elseif data.highestScore >= 20 and not data.rewardsReceived.secondClass then
		data.rewardsReceived.secondClass = true
		applyClass("secondClass", data)
	elseif data.highestScore >= 40 and not data.rewardsReceived.thirdClass then
		data.rewardsReceived.thirdClass = true
		applyClass("thirdClass", data)
	elseif data.highestScore >= 60 and not data.rewardsReceived.fourthClass then
		data.rewardsReceived.fourthClass = true
		applyClass("fourthClass", data)
	elseif data.highestScore >= 100 and not data.rewardsReceived.ertClass then
		data.rewardsReceived.ertClass = true
		applyClass("ertClass", data)
	elseif data.highestScore >= 150 and not data.rewardsReceived.finalClass then
		data.rewardsReceived.finalClass = true
		applyClass("finalClass", data)
	end
end

local greenTurfRef = REF(greenTurf)
local redTurfRef = REF(redTurf)
local purpleTurfRef = REF(purpleTurf)
local blueTurfRef = REF(blueTurf)

for _, data in humans do
	SS13.register_signal(data.human, "movable_moved", function(source)
		local pos = source:get_var("loc")
		local turfRef = REF(pos)
		if turfRef == greenTurfRef or turfRef == redTurfRef or turfRef == purpleTurfRef or turfRef == blueTurfRef then
			return
		end
		if takenTurfs[turfRef] == data then
			return
		elseif takenTurfs[turfRef] then
			local theirData = takenTurfs[turfRef]
			theirData.score -= 1
			takenTurfs[turfRef] = nil
			updateScore(theirData)
		end
		data.score += 1
		data.highestScore = math.max(data.highestScore, data.score)
		pos:set_var("color", data.color)
		takenTurfs[turfRef] = data
		handleRewards(data)
		updateScore(data)
	end)
end

function DESTRUCT_CLEANUP_TURFS()
	for turf, _ in takenTurfs do
		local actualTurf = dm.global_proc("_locate", turf)
		if actualTurf then
			actualTurf:set_var("color", nil)
		end
	end
end