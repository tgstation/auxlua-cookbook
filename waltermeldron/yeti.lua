local SS13 = require("SS13")

local yeti = SS13.new("/mob/living/basic/gorilla", SS13.get_runner_client():get_var("mob"):call_proc("drop_location"))

yeti:set_var("name", "Yeti King")
yeti:set_var("desc", "<span class='userdanger'><font color='#48ffd8'>Oh fuck..</font></span>")
yeti:set_var("real_name", "Yeti King")
yeti:set_var("color", "#48ffa8")
yeti:set_var("minimum_survivable_temperature", 0)
yeti:set_var("maximum_survivable_temperature", 500000000)
yeti:set_var("move_resist", 500000)
yeti:set_var("mob_respiration_type", 0)
yeti:get_var("damage_coeff"):set("oxygen", 0)

yeti:call_proc("init_mind")
local cool_rate_per_second = 200
local gas_fill_per_second = 300

local max_gas = 100
local spewing_gases = {
    ["/datum/gas/healium"] = 1,
    ["/datum/gas/water_vapor"] = 10,
}

local gas_on = false

SS13.register_signal(yeti, "living_life", function(source, seconds_per_tick)
    if source:get_var("stat") ~= 0 then
        return
    end

    source:set_var("bodytemperature", 60)

    if not gas_on then
        return
    end

    local air = source:call_proc("return_air")
    if not air then
        return
    end

    local current_turf = dm.global_proc("_get_step", source, 0)
    local temp = air:get_var("temperature")
    if cool_rate_per_second > 0 then
        air:set_var("temperature", math.max(temp - cool_rate_per_second * seconds_per_tick, 160))
    elseif cool_rate_per_second == -1 then
        air:set_var("temperature", math.max(350, temp))
    end

    for gas, rate in spewing_gases do
        air:call_proc("assert_gas", SS13.type(gas))
        local vapor = air:get_var("gases"):get(SS13.type(gas))
        local moles = vapor:get(1)
        if moles < max_gas * rate then
            local new_moles = math.min(moles + gas_fill_per_second * seconds_per_tick * rate, max_gas * rate)
            vapor:set(1, new_moles)
        end
    end
    current_turf:call_proc("air_update_turf", true, false)
end)

local _reverseBeartrap = SS13.new("/obj/item/reverse_bear_trap")
local summon_sparks = SS13.new("/datum/action/cooldown")
summon_sparks:set_var("name", "Spawn sparks")
summon_sparks:set_var("button_icon", _reverseBeartrap:get_var("icon"))
summon_sparks:set_var("button_icon_state", _reverseBeartrap:get_var("icon_state"))
summon_sparks:call_proc("Grant", yeti)
dm.global_proc("qdel", _reverseBeartrap)
local beartrapActivated = {}
SS13.register_signal(summon_sparks, "action_trigger", function()
    local sparks = SS13.new("/datum/effect_system/spark_spread")
    sparks:call_proc("set_up", 5, 1, yeti)
    sparks:call_proc("attach", yeti)
    sparks:call_proc("start")
    summon_sparks:call_proc("StartCooldown", 50)
    return 1
end)

local toggle_gas = SS13.new("/datum/action/cooldown")
toggle_gas:set_var("name", "Toggle gas")
toggle_gas:set_var("button_icon_state", "origami_on")
toggle_gas:call_proc("Grant", yeti)
local beartrapActivated = {}
SS13.register_signal(toggle_gas, "action_trigger", function()
    if gas_on then
        gas_on = false
        toggle_gas:set_var("button_icon_state", "origami_on")
    else
        gas_on = true
        toggle_gas:set_var("button_icon_state", "origami_off")
    end
    toggle_gas:call_proc("StartCooldown", 10)
    toggle_gas:call_proc("build_all_button_icons")
    return 1
end)