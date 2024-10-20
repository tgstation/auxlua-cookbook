local SS13 = require("SS13")
SS13.state.supress_runtimes = true

local authToken = "bDpqpyFCndDUhatbhvLpe"

local server = ""
local targetServer = ""

local function wget(url, body, headers, outfile)
	local request = SS13.new("/datum/http_request")
	request:prepare("get", url, body or "", headers, outfile)
	request:begin_async()
	while request:is_complete() == 0 do
		sleep()
	end
	local response = request:into_response()
	if response.errored == 1 then
		error("HTTP request for "..url.." failed to parse the returned json object")
	end
	local status = response.status_code
	if status ~= 200 then
		error("HTTP request for "..url.." returned response code "..status)
	end
	local body = response.body
	return body
end
local json = __JSON
if not json then
    __JSON = assert(loadstring(wget("https://raw.githubusercontent.com/rxi/json.lua/master/json.lua")))()
    json = __JSON
end

local me = SS13.get_runner_client()
local address = me.address or "localhost"
local function doHttp(method, body, post)
    local performFetch = SS13.new("/datum/http_request")
    local todo = "get"
    if post then
        todo = "post"
    end
    performFetch:prepare(todo, "http://"..address..":30020/"..method, body, { Authorization = authToken, Server = server })
    performFetch:begin_async()
    while performFetch:is_complete() == 0 do
        sleep()
    end
    local response = performFetch:into_response()
	if response.errored == 1 then
		return
	end
	local status = response.status_code
	if status ~= 200 then
		return status
	end
    return response.body
end

local function checkTransfer()
    return doHttp("check-transfer", "")
end

local function escape(str)
	str = string.gsub(str, "([^0-9a-zA-Z !'()*._~-])", -- locale independent
	   function (c) return string.format ("%%%02X", string.byte(c)) end)
	str = string.gsub(str, " ", "+")
	return str
end

local function receiveTransfer()
    local result = doHttp("receive-transfer?link="..escape(dm.world.url), "")
    if not result or type(result) == 'number' then
        return
    end
    return json.decode(result)
end

local function finishTransfer()
    return doHttp("finish-transfer", "")
end

local function makeTransfer(data)
    return doHttp("make-transfer?target="..targetServer, json.encode(data), true)
end

local function getServerId(data)
    return doHttp("get-server-id?link="..escape(dm.world.url), "")
end

local serverDataRaw = getServerId()
if not serverDataRaw or type(serverDataRaw) == 'number' then
    return
end
local serverData = json.decode(serverDataRaw)

server = serverData.me
targetServer = serverData.target
print("Initializing as "..server.." with target ".. targetServer)

iconsByHttp = iconsByHttp or {}

local loadIcon = function(http, icon_state, no_cache)
    icon_state = icon_state or ""
	if iconsByHttp[http..icon_state] and not no_cache then
		return iconsByHttp[http]
	end

	local request = SS13.new("/datum/http_request")
	local file_name = "tmp/custom_map_icon.dmi"
	request:prepare("get", http, "", "", file_name)
	request:begin_async()
	while request:is_complete() == 0 do
		sleep()
	end
    if icon_state ~= "" then
	    iconsByHttp[http..icon_state] = SS13.new("/icon", file_name, icon_state)
    else
	    iconsByHttp[http] = SS13.new("/icon", file_name)
    end
    return iconsByHttp[http..icon_state]
end

if SS13.is_valid(SERVER_TELEPORTER) then
    SS13.stop_all_loops()
    SS13.qdel(SERVER_TELEPORTER)
    SS13.qdel(SERVER_RECEIVER)
end

local bodyToUid = {}
local REF = dm.global_procs.REF
local round_id = dm.global_vars.GLOB.round_id

local transformers = {
    ["/mob/living/carbon/human"] = {
        sender = function(human)
            local humanDna = human.dna
            if not humanDna or not human.key then
                return
            end
            return {
                key = human.key,
                variable_mappings = {
                    real_name = human.real_name,
                    underwear = human.underwear,
                    underwear_color = human.underwear_color,
                    undershirt = human.undershirt,
                    socks = human.socks,
                    age = human.age,
                    physique = human.physique,
                    voice = human.voice,
                    voice_filter = human.voice_filter,
                },
                job = "Prisoner",--human.job,
                unique_identity = humanDna.unique_identity,
                unique_enzymes = humanDna.unique_enzymes,
                unique_features = humanDna.unique_features,
                dna_features = list.to_table(humanDna.features, true),
                blood_type = humanDna.blood_type,
                species = tostring(humanDna.species.type),
            }
        end,
        receiver = function(data, teleporter)
            local human = SS13.new("/mob/living/carbon/human", teleporter:drop_location())
            for variable, value in data.variable_mappings do
                human[variable] = value
            end
            human:set_species(SS13.type(data.species), false)
            if human.dna then
                human.dna.features = data.dna_features
                human.dna.blood_type = data.blood_type
                human.dna.real_name = human.real_name
                human.dna.unique_identity = data.unique_identity
                human.dna.unique_enzymes = data.unique_enzymes
                human.dna.unique_features = data.unique_features
            end
            human.name = human.real_name
            human.icon_render_keys = {}
            human:updateappearance(false)
            human:update_body(true)
            human:update_mutations_overlay()
            local selectedOutfit = SS13.type("/datum/outfit/centcom/centcom_intern/unarmed")
            if data.job then
                local job = dm.global_vars.SSjob.name_occupations[data.job]
                if job and job.outfit then
                    selectedOutfit = job.outfit
                end
            end
            human:equipOutfit(selectedOutfit)
            local mind = SS13.new("/datum/mind", data.key)
            mind:transfer_to(human, true)
            mind.special_role = "Dimensional Traveler"
            local antag = SS13.new("/datum/antagonist/custom")
            antag.name = "Dimensional Traveler"
            antag.show_to_ghosts = true
            antag.antagpanel_category = "Spacetime Aberrations"
            local objective = SS13.new("/datum/objective")
            objective.owner = mind
            objective.explanation_text = "Your memory is fuzzy as you hop dimensions. You aren't aware of your past allegiances until you return back to your original dimension."
            objective.completed = true
            list.add(antag.objectives, objective)
            mind:add_antag_datum(antag)
            return human
        end
    },
    ["/mob/living/silicon/robot"] = {
        sender = function(human)
            local laws = {}
            if human.laws then
                laws = {
                    inherent = list.to_table(human.laws.inherent),
                    ion = list.to_table(human.laws.ion),
                    supplied = list.to_table(human.laws.supplied),
                    zeroth = human.laws.zeroth,
                    hacked = list.to_table(human.laws.hacked),
                }
            end

            return {
                key = human.key,
                custom_name = human.custom_name,
                laws = laws,
                model = tostring(human.model.type),
                voice = human.voice,
            }
        end,
        receiver = function(data, teleporter)
            local robot = SS13.new("/mob/living/silicon/robot", teleporter:drop_location())
            robot.custom_name = data.custom_name
            robot.model:transform_to(SS13.type(data.model), true)
            robot.scrambledcodes = true
            robot:set_connected_ai(nil)
            for variable, lawList in data.laws do
                robot.laws[variable] = lawList
            end
            robot.voice = data.voice
            local mind = SS13.new("/datum/mind", data.key)
            mind:transfer_to(robot, true)
            mind.special_role = "Dimensional Traveler"
            local antag = SS13.new("/datum/antagonist/custom")
            antag.name = "Dimensional Traveler"
            antag.show_to_ghosts = true
            antag.antagpanel_category = "Spacetime Aberrations"
            local objective = SS13.new("/datum/objective")
            objective.owner = mind
            objective.explanation_text = "Your memory is fuzzy as you hop dimensions. You aren't aware of your past allegiances until you return back to your original dimension."
            objective.completed = true
            list.add(antag.objectives, objective)
            mind:add_antag_datum(antag)
            return robot
        end
    },
    ["/mob/living/silicon/ai"] = {
        sender = function(human)
            local laws = {}
            if human.laws then
                laws = {
                    inherent = list.to_table(human.laws.inherent),
                    ion = list.to_table(human.laws.ion),
                    supplied = list.to_table(human.laws.supplied),
                    zeroth = human.laws.zeroth,
                    hacked = list.to_table(human.laws.hacked),
                }
            end

            return {
                key = human.key,
                real_name = human.real_name,
                laws = laws,
                voice = human.voice
            }
        end,
        receiver = function(data, teleporter)
            local gaming = SS13.new("/mob")
            gaming.real_name = data.real_name
            local robot = SS13.new("/mob/living/silicon/ai", teleporter:drop_location(), nil, SS13.new("/mob"))
            robot.real_name = data.real_name
            robot.name = data.real_name
            for variable, lawList in data.laws do
                robot.laws[variable] = lawList
            end
            robot.voice = data.voice
            local mind = SS13.new("/datum/mind", data.key)
            mind:transfer_to(robot, true)
            mind.special_role = "Dimensional Traveler"
            local antag = SS13.new("/datum/antagonist/custom")
            antag.name = "Dimensional Traveler"
            antag.show_to_ghosts = true
            antag.antagpanel_category = "Spacetime Aberrations"
            local objective = SS13.new("/datum/objective")
            objective.owner = mind
            objective.explanation_text = "Your memory is fuzzy as you hop dimensions. You aren't aware of your past allegiances until you return back to your original dimension."
            objective.completed = true
            list.add(antag.objectives, objective)
            mind:add_antag_datum(antag)
            return robot
        end
    }
}

local receivedMobs = {}

local grabMobData = function(mob)
    for transformerType, transformer in transformers do
        if SS13.istype(mob, transformerType) then
            local data = transformer.sender(mob)
            if not data then
                return
            end
            local oldId = receivedMobs[REF(mob)]
            if not oldId then
                data.id = round_id.." "..mob.tag
            else
                data.id = oldId
            end
            data.mobType = transformerType
            return data
        end
    end
end

local applyMobData = function(data, spawnLocation)
    local transformer = transformers[data.mobType]
    local creature = transformer.receiver(data, spawnLocation)
    if creature then
        receivedMobs[REF(creature)] = data.id
    end
    return creature
end

local teleporter = SS13.new("/obj/machinery", me.mob.loc)
SERVER_TELEPORTER = teleporter
teleporter.name = "transdimensional sender"
teleporter.icon = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/machines/telepad.dmi")
teleporter.icon_state = "lpad-idle"
teleporter.density = false
teleporter.uses_integrity = false
teleporter.resistance_flags = 499

local case = SS13.new("/obj", teleporter)

case.icon = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/smooth_structures/normal/clockwork_window.dmi")
case.icon_state = "clockwork_window-0"
case.layer = 4.5
case.color = { 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0.4, 0, 0, 0, 0 }
case.mouse_opacity = 0
case.resistance_flags = 499
list.add(teleporter.vis_contents, case)

local filter = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/effects/alphacolors.dmi", "white", true)
local alpha_mask_filter = dm.global_procs.alpha_mask_filter(0, -32, filter, nil)
case:add_filter("casing", 1, alpha_mask_filter)

local function senderBringCaseUp()
    case:transition_filter("casing", { y = 0 }, 10)
    teleporter.density = true
end

local function senderBringCaseDown()
    case:transition_filter("casing", { y = -32 }, 10)
    teleporter.density = false
end

local receiver = SS13.new("/obj/machinery", me.mob.loc)
SERVER_RECEIVER = receiver
receiver.name = "transdimensional receiver"
receiver.icon = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/machines/telepad.dmi")
receiver.icon_state = "lpad-idle"
receiver.density = false
receiver.uses_integrity = false
receiver.resistance_flags = 499
receiver.color = { 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0 }

local case = SS13.new("/obj", receiver)

case.icon = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/obj/smooth_structures/normal/clockwork_window.dmi")
case.icon_state = "clockwork_window-0"
case.layer = 4.5
case.color = { 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0.4, 0, 0, 0, 0 }
case.mouse_opacity = 0
case.appearance_flags = bit32.bor(case.appearance_flags, 2)
case.resistance_flags = 499
list.add(receiver.vis_contents, case)

local filter = loadIcon("https://raw.githubusercontent.com/tgstation/tgstation/master/icons/effects/alphacolors.dmi", "white", true)
local alpha_mask_filter = dm.global_procs.alpha_mask_filter(0, -32, filter, nil)
case:add_filter("casing", 1, alpha_mask_filter)

local function receiverBringCaseUp()
    case:transition_filter("casing", { y = 0 }, 10)
    receiver.density = true
end

local function receiverBringCaseDown()
    case:transition_filter("casing", { y = -32 }, 10)
    receiver.density = false
end

local TELEPORTER_STATE_NONE = 0
local TELEPORTER_STATE_RECEIVING = 1
local TELEPORTER_STATE_SENDING = 2

local stasis_traits = {
    "block_transformations",
    "in_stasis"
}

local teleporterState = TELEPORTER_STATE_NONE
local sendingMob
local sendingKey

local linkTo = dm.global_procs._link

local sentKeys = {}

local holdLocation = dm.global_procs._locate(169, 65, 1)

local illusionHolder = SS13.new("/obj/structure", holdLocation)
illusionHolder.resistance_flags = 499

local resetPlayer = function(human)
    if human.buckled == teleporter then
        human:set_buckled(nil)
    end
    SS13.unregister_signal(human, "mob_login")
    human:remove_traits(stasis_traits, "lua_teleporter")
    human.anchored = false
end

local receive = function(data)
    if not data or not SS13.is_valid(receiver) then
        return
    end
    local human
    local key = data.id
    if SS13.is_valid(sentKeys[key]) then
        human = sentKeys[key]
        resetPlayer(human)
    else
        human = applyMobData(data, receiver)
    end
    dm.global_procs.playsound(receiver, "sound/machines/ding.ogg", 100, true)
    human:forceMove(receiver)
    human:add_filter("disappear_effect", 10, dm.global_procs.wave_filter(10, 0, 50, 5, 0))
    human:transition_filter("disappear_effect", { offset = 0, size = 0 }, 20, 1, 0)
    SS13.set_timeout(2, function()
        if not SS13.is_valid(human) then
            return
        end
        human:remove_filter("disappear_effect")
        if not SS13.is_valid(receiver) then
            return
        end
        human:forceMove(receiver:drop_location())
        dm.global_procs.playsound(receiver, "sound/weapons/emitter2.ogg", 100, true)
        local sparks = SS13.new("/datum/effect_system/spark_spread/quantum")
        sparks:set_up(5, 1, receiver)
        sparks:attach(receiver:drop_location())
        sparks:start()
    end)
end

local send = function(human, serverLink)
    if not SS13.is_valid(human) or not SS13.is_valid(teleporter) then
        return
    end
    if human.client then
        linkTo(human.client, serverLink)
    end
    sentKeys[sendingKey] = human
    dm.global_procs.playsound(teleporter, "sound/machines/ding.ogg", 100, true)
    human:add_filter("disappear_effect", 10, dm.global_procs.wave_filter(10, 0, 0, 0, 0))
    human:transition_filter("disappear_effect", { offset = 5, size = 50 }, 20, 1, 0)
    SS13.set_timeout(1.8, function()
        if not SS13.is_valid(human) then
            return
        end
        human:remove_filter("disappear_effect")
        if not SS13.is_valid(teleporter) then
            return
        end
        human:set_buckled(nil)
        human:forceMove(illusionHolder)
        dm.global_procs.playsound(teleporter, "sound/weapons/emitter2.ogg", 100, true)
        local sparks = SS13.new("/datum/effect_system/spark_spread/quantum")
        sparks:set_up(5, 1, teleporter)
        sparks:attach(teleporter:drop_location())
        sparks:start()
    end)
    SS13.register_signal(human, "mob_login", function()
        SS13.set_timeout(0, function()
            if human.client.holder or human.ckey == "waltermeldron" then
                dm.global_procs.to_chat(human, "<span class='hypnophrase'>Since you are an admin, you are bypassing the lock that prevents players from connecting back to this server until they re-enter the portal again.</span>")
                return
            end
            dm.global_procs.to_chat(human, "<span class='hypnophrase' style='font-size: 32px'>You feel that your soul is in another dimension, and you get pulled into that dimension...</span>")
            linkTo(human.client, serverLink)
        end)
    end)
    sendingKey = nil
    sendingMob = nil
end

local clearSendingMob = function()
    if SS13.is_valid(sendingMob) then
        resetPlayer(sendingMob)
        sendingMob = nil
    end
end

local possiblyInvalid = false
local processing = false

SS13.start_loop(3, -1, function()
    if not SS13.is_valid(teleporter) then
        return
    end

    possiblyInvalid = false
    local result = checkTransfer()
    if possiblyInvalid then
        return
    end
    if processing then
        return
    end
    if result == 401 then
        print("Received 401 error whilst trying to check for transfer!")
        SS13.stop_all_loops()
        if sendingMob then
            resetPlayer(sendingMob)
        end
        return
    end

    if result == "No transfer" then
        clearSendingMob()
        receiverBringCaseDown()
        senderBringCaseDown()
        teleporterState = TELEPORTER_STATE_NONE
        return
    end
    if result == "Timeout" then
        clearSendingMob()
        receiverBringCaseDown()
        senderBringCaseDown()
        teleporterState = TELEPORTER_STATE_NONE
        teleporter:say("Unable to establish link to dimension!")
        return
    end
    
    if teleporterState == TELEPORTER_STATE_RECEIVING then
        return
    end

    if result == "Transferring" or result == "Transferred" then
        teleporterState = TELEPORTER_STATE_SENDING
    end

    if teleporterState == TELEPORTER_STATE_NONE then
        if result == "Ready" then
            processing = true
            teleporterState = TELEPORTER_STATE_RECEIVING
            local received = receiveTransfer()
            receiverBringCaseUp()
            SS13.wait(1)
            receive(received)
            SS13.wait(3)
            receiverBringCaseDown()
            processing = false
            teleporterState = TELEPORTER_STATE_NONE
        end
    elseif teleporterState == TELEPORTER_STATE_SENDING then
        if result == "Transferred" then
            processing = true
            local link = finishTransfer()
            senderBringCaseUp()
            SS13.wait(1)
            if link ~= 401 then
                send(sendingMob, link)
            end
            SS13.wait(3)
            senderBringCaseDown()
            teleporterState = TELEPORTER_STATE_NONE
            processing = false
        end
    end
end)

local lastCall = 0

function onTargetEnter(user)
    if not SS13.is_valid(teleporter) then
        return
    end
    if teleporterState ~= TELEPORTER_STATE_NONE then
        return
    end
    if lastCall == dm.world.time then
        return
    end
    lastCall = dm.world.time
    local userData = grabMobData(user)
    if not userData then
        return
    end
    teleporterState = TELEPORTER_STATE_SENDING
    user:forceMove(teleporter:drop_location())
    user:set_buckled(teleporter)
    user.anchored = true
    user:add_traits(stasis_traits, "lua_teleporter")
    senderBringCaseUp()
    SS13.set_timeout(0, function()
        local result = makeTransfer(userData)
        if result ~= "OK" or not SS13.is_valid(teleporter) then
            teleporterState = TELEPORTER_STATE_NONE
            resetPlayer(user)
            senderBringCaseDown()
            return
        end
        user:setDir(2)
        sendingMob = user
        sendingKey = userData.id
        possiblyInvalid = true
    end)
end

SS13.register_signal(teleporter, "parent_qdeleting", function()
    SS13.qdel(illusionHolder)
end)
local trackingTurf
local startTrackingTurf
startTrackingTurf = function(turf)
    if trackingTurf == turf then
        return
    end
    if trackingTurf then
        SS13.unregister_signal(trackingTurf, "atom_entered")
        SS13.unregister_signal(trackingTurf, "parent_qdeleting")
    end
    trackingTurf = turf
    if not turf then
        return
    end
    SS13.register_signal(trackingTurf, "atom_entered", function(_, arrived, old_loc)
        onTargetEnter(arrived)
    end)
    SS13.register_signal(trackingTurf, "parent_qdeleting", function()
        startTrackingTurf(nil)
    end)
end
startTrackingTurf(teleporter.loc)
SS13.register_signal(teleporter, "movable_moved", function()
    startTrackingTurf(teleporter.loc)
end)
SS13.register_signal(teleporter, "parent_qdeleting", function()
    startTrackingTurf(nil)
    if SS13.is_valid(sendingMob) then
        resetPlayer(sendingMob)
    end
end)