SS13 = require("SS13")

local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get("waltermeldron")

local spawnLocation = user:get_var("mob"):get_var("loc")
local gorilla = SS13.new("/mob/living/simple_animal/hostile/gorilla", spawnLocation)

gorilla:call_proc("toggle_ai", 3)
gorilla:set_var("can_have_ai", false)
gorilla:set_var("move_resist", 5000000)
gorilla:set_var("anchored", 1)
gorilla:set_var("status_flags", 16)
gorilla:set_var("combat_mode", 1)
gorilla:set_var("mob_size", 4)

-- Speed in deciseconds per walk
slowdown = 1
local nextWalk = 0

local allDirsCache = { 1, 2, 4, 8, 5, 9, 6, 10 }
local cardinalCache = { 1, 2, 4, 8 }
local gorillaTarget = nil

KILL_MODE = true

local function destroyInPath(turf)
    local hitSomething = false
    local shouldBreak = true
    for _, direction in allDirsCache do
        local step = dm.global_proc("_get_step", turf, direction)
        if SS13.istype(step, "/turf/open/space") then
            shouldBreak = false
            break
        end
    end
    for _, object in turf:get_var("contents") do
        if object:get_var("density") ~= 0 then
            if (SS13.istype(object, "/obj/structure/grille") or object:get_var("can_atmos_pass") ~= 1) and not shouldBreak then
                continue
            end
            hitSomething = true
            if SS13.istype(object, "/mob/living") then
                object:call_proc("Knockdown", 30)
                object:call_proc("attack_animal", gorilla)
            elseif SS13.istype(object, "/obj") and object:get_var("uses_integrity") ~= 0 then
                gorilla:call_proc("do_attack_animation", object)
                object:call_proc("take_damage", 9999)
                object:call_proc("play_attack_sound", 9999)
            end
        end
        if over_exec_usage(0.9) then
            sleep()
            if gorilla:is_null() then
                return
            end
        end
    end
    if turf:get_var("density") ~= 0 and not SS13.istype(turf, "/turf/closed/indestructible") then
        if shouldBreak then
            gorilla:call_proc("do_attack_animation", turf)
            dm.global_proc("playsound", turf, "sound/effects/meteorimpact.ogg", 100, true)
            turf:call_proc("ScrapeAway")
            hitSomething = true
        end
        if over_exec_usage(0.9) then
            sleep()
            if gorilla:is_null() then
                return
            end
        end
    end
    sleep()
    if gorilla:is_null() then
        return
    end
    if hitSomething then
        gorilla:call_proc("say", "*ooga")
    end
end

local function walk_to_target(target)
    local gorillaTurf = gorilla:call_proc("drop_location")
    local targetTurf = target:call_proc("drop_location")

    local nextDirection = dm.global_proc("_get_dir", gorillaTurf, targetTurf)
    local dirList = {}

    local buckledThing = gorilla:get_var("buckled")
    if buckledThing ~= nil then
        buckledThing:call_proc("attack_animal", gorilla)
        return
    end

    local gorillaLocation = gorilla:get_var("loc")
    if not SS13.istype(gorillaLocation, "/turf") then
        gorillaLocation:call_proc("attack_animal", gorilla)
        return
    end

    if targetTurf:get_var("z") ~= gorillaTurf:get_var("z") then
        gorilla:call_proc("forceMove", dm.global_proc("_locate", gorillaTurf:get_var("x"), gorillaTurf:get_var("y"), targetTurf:get_var("z")))
    end
    local gorillaTurf = gorilla:call_proc("drop_location")
    local includeTurfDir = false
    if bit32.band(nextDirection, (nextDirection - 1)) ~= 0 then
        for _, direction in cardinalCache do
            if bit32.band(direction, nextDirection) ~= 0 then
                table.insert(dirList, direction)
            end
        end
        includeTurfDir = true
    else
        table.insert(dirList, nextDirection)
    end
    for _, direction in dirList do
        local step = dm.global_proc("_get_step", gorillaTurf, direction)
        destroyInPath(step)
    end
    local whereToStep = dm.global_proc("_get_step", gorillaTurf, nextDirection)
    if includeTurfDir then
        destroyInPath(whereToStep)
    end
    local success = gorilla:call_proc("Move", whereToStep, nextDirection)
    if gorilla:call_proc("drop_location") ~= whereToStep then
        gorilla:call_proc("forceMove", whereToStep)
    end
end

local woundList = {
    "/datum/wound/blunt/critical",
    "/datum/wound/blunt/severe",
    "/datum/wound/blunt/moderate"
}

local function main_gorilla_loop()
    local currentTime = dm.world:get_var("time")
    if gorilla:call_proc("incapacitated") ~= 0 or nextWalk > currentTime then
        return
    end
    if over_exec_usage(0.9) then
        sleep()
        if gorilla:is_null() then
            return
        end
    end
    if gorillaTarget ~= nil then
        local targetLocation = gorillaTarget:call_proc("drop_location")
        local gorillaLocation = gorilla:call_proc("drop_location")
        if targetLocation == nil or gorillaLocation == nil then
            gorillaTarget = nil
            return
        end
        if dm.global_proc("_get_dist", targetLocation, gorilla:call_proc("drop_location")) <= 1 then
            sleep()
            if gorilla:is_null() then
                return
            end
            gorillaTarget:call_proc("attack_animal", gorilla)
            if KILL_MODE then
                gorillaTarget:call_proc("gib")
            else
                if SS13.istype(gorillaTarget, "/mob/living/carbon") then
                    for _, limb in gorillaTarget:get_var("bodyparts") do
                        local woundToGive = dm.global_proc("_text2path", woundList[math.random(#woundList)])
                        limb:call_proc("force_wound_upwards", woundToGive, true)
                    end
                end
                gorillaTarget:call_proc("take_overall_damage", gorillaTarget:get_var("maxHealth") * 1.5)
            end
            gorilla:call_proc("say", "*ooga")
            gorillaTarget = nil
            return
        end
        if gorillaTarget:is_null() then
            gorillaTarget = nil
        else
            walk_to_target(gorillaTarget)
        end
    end
    nextWalk = dm.world:get_var("time") + slowdown
end

local currentValidLoop

local function start_gorilla_loop(validLoop)
    while true do
        if gorilla:is_null() or gorilla:get_var("stat") == 4 or gorillaTarget == nil or currentValidLoop ~= validLoop then
            gorillaTarget = nil
            return
        end
        main_gorilla_loop()
        sleep()
    end
end

gorilla:call_proc("_AddElement", { dm.global_proc("_text2path", "/datum/element/relay_attackers")})

SS13.register_signal(gorilla, "atom_was_attacked", function(_, attacker)
    if math.random(10) == 1 then
        gorilla:call_proc("say", "*ooga")
    end
    if gorillaTarget ~= nil then
        return
    end
    local time = dm.world:get_var("time")
    gorilla:call_proc("say", "*ooga")
    nextWalk = dm.world:get_var("time") + 10
    gorillaTarget = attacker
    currentValidLoop = time
    start_gorilla_loop(time)
end)


start_gorilla_loop()