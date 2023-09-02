SS13 = require("SS13")

local me = dm.global_vars:get_var("GLOB"):get_var("directory"):get("waltermeldron"):get_var("mob")

local rod = SS13.new("/obj/effect/immovablerod", me:get_var("loc"))

local controller = SS13.new("/mob/living", rod)
controller:set_var("name", "Immovable Rod")

local currentDirection = nil

local directionMapping = {
    [1] = 2,
    [2] = 1,
    [4] = 8,
    [8] = 4,
}

local cooldown = 0
SS13.register_signal(rod, "atom_relaymove", function(_, player, direction)
    if player ~= controller then
        return
    end
    local world_time = dm.world:get_var("time")
    if cooldown > world_time then
        return 1
    end
    cooldown = world_time + 5
    if currentDirection ~= nil then
        if directionMapping[currentDirection] == direction then
            dm.global_vars:get_var("SSmove_manager"):call_proc("stop_looping", rod)
            currentDirection = nil
            return 1
        end
    end
    rod:call_proc("walk_in_direction", direction)
    currentDirection = direction
    return 1
end)

