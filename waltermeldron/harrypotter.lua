SS13 = require("SS13")

SS13.wait(1)

local IS_LOCAL = false
local SILENT = true
local admin = "waltermeldron"

local antiMagicFlag = 1

local function locate(x, y, z)
    return dm.global_proc("_locate", x, y, z)
end

local function rangeTurfs(location, radius)
    local x = location:get_var("x")
    local y = location:get_var("y")
    local z = location:get_var("z")
    return dm.global_proc("_block", locate(x - radius, y - radius, z), locate(x + radius, y + radius, z))
end

local function hasMana(humanData, cost)
    if humanData.mana < cost then
        return false
    end
    return true
end

local function hasWand(humanData)
    for _, item in humanData.human:get_var("held_items") do
        if item:get_var("type") == SS13.type("/obj/item/staff") then
            return true
        end
    end
    return false
end

local function to_chat(user, message)
    dm.global_proc("to_chat", user, message)
end

SPELLS = {
    {
        spellName = "Force Wall",
        manaCost = 15,
        activationSound = "sound/magic/forcewall.ogg",
        activationRegex = "^I beseech thee, conjure a (%d+)-wide magic wall to block my foes[!\\.]*$",
        canActivate = function(self, humanData, size)
            local sizeNumber = tonumber(size)
            if sizeNumber == nil then
                return false
            end
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData, size)
            local sizeNumber = tonumber(size)
            local maxSize = math.floor(humanData.mana / 5) + 3
            sizeNumber = math.min(maxSize, sizeNumber, 5)
            local extraManaCost = math.max(sizeNumber - 3, 0) * 5
            humanData.mana -= extraManaCost
            local player = humanData.human

            local leftTurf = dm.global_proc("_get_step", player:call_proc("drop_location"), player:get_var("dir"))
            local rightTurf = leftTurf
            local leftDir = dm.global_proc("_turn", player:get_var("dir"), -90)
            local rightDir = dm.global_proc("_turn", player:get_var("dir"), 90)
            local turfs = { leftTurf }
            local noMoreRight = false
            local noMoreLeft = false
            local doRight
            local function doLeft()
                leftTurf = dm.global_proc("_get_step", leftTurf, leftDir)
                if leftTurf:get_var("density") == 1 then
                    noMoreLeft = true
                    if not noMoreRight then
                        doRight()
                    end
                    return
                end
                table.insert(turfs, leftTurf)
            end
            doRight = function()
                rightTurf = dm.global_proc("_get_step", rightTurf, rightDir)
                if rightTurf:get_var("density") == 1 then
                    noMoreRight = true
                    if not noMoreLeft then
                        doLeft()
                    end
                    return
                end
                table.insert(turfs, rightTurf)
            end
            for i = 1, (sizeNumber-1) do
                if noMoreLeft and noMoreRight then
                    break
                end
                if (i % 2 == 0 and not noMoreLeft) or noMoreRight then
                    doLeft()
                else
                    doRight()
                end
            end
            for _, turf in turfs do
                SS13.new_untracked("/obj/effect/forcefield/wizard", turf, player, antiMagicFlag)
            end
        end,
    },
    {
        spellName = "Knock",
        manaCost = 30,
        activationSound = "sound/magic/knock.ogg",
        activationRegex = "^I beseech thee, open the passage ways around me[!\\.]*$",
        canActivate = function(self, humanData)
            return true
        end,
        spellFunction = function(self, humanData)
            local target = humanData.human:call_proc("drop_location")
            local turfs = rangeTurfs(target, 3)
            
            for _, turf in turfs do
                local listen_lookup = turf:get_var("_listen_lookup")
                if listen_lookup then
                    turf:call_proc("_SendSignal", "atom_magic_unlock", { turf, humanData.human, humanData.human })
                end
            end
        end,
    },
    {
        spellName = "Charge",
        manaCost = 50,
        activationSound = "sound/magic/charge.ogg",
        activationRegex = "^I beseech thee, charge the apparatus within my hands[!\\.]*$",
        canActivate = function(self, humanData)
            return true
        end,
        spellFunction = function(self, humanData)     
            local to_charge = humanData.human:call_proc("get_active_held_item") or humanData.human:call_proc("get_inactive_held_item")
            if not to_charge then
                return
            end
            local returnData
            local listen_lookup = to_charge:get_var("_listen_lookup")
            if listen_lookup then
                returnData = to_charge:call_proc("_SendSignal", "item_magic_charged", { to_charge, humanData.human, humanData.human })
            end

            if returnData == nil then
                return
            end

            local charge_return = SEND_SIGNAL(to_charge, COMSIG_ITEM_MAGICALLY_CHARGED, src, cast_on)

            if(not SS13.is_valid(to_charge)) then
                to_chat(cast_on, "<span class='warning'>The charge spell seems to react adversely with "..to_charge:get_var("name").."!</span>")
                return
            end
        
            if(bit32.band(charge_return, 2)) then
                to_chat(humanData.human, "<span class='warning'>The charge spell seems to react negatively to "..to_charge:get_var("name")..", becoming uncomfortably warm!</span>")
            elseif(bit32.band(charge_return, 1)) then
                to_chat(humanData.human, "<span class='notice'>"..to_charge:get_var("name").." suddenly feels very warm!</span>")
            else
                to_chat(humanData.human, "<span class='notice'>"..to_charge:get_var("name").." doesn't seem to be react to the charge spell.</span>")
            end
        
        end,
    },
    {
        spellName = "Blink",
        manaCost = 10,
        activationSound = nil,
        activationRegex = "^I beseech thee, allow me to blink (%d+) step[s]* forward[!\\.]*$",
        canActivate = function(self, humanData, distance)
            local distanceNumber = tonumber(distance)
            if distanceNumber == nil then
                return false
            end
            return true
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData, distance)
            local distanceNumber = tonumber(distance)
            local maxDistance = math.floor(humanData.mana / 10) + 1
            distanceNumber = math.min(maxDistance, distanceNumber, 5)
            local extraManaCost = math.max(distanceNumber - 1, 0) * 10
            
            local target = humanData.human:call_proc("drop_location")
            for i = 1, distanceNumber do 
                target = dm.global_proc("_get_step", target, humanData.human:get_var("dir"))
                if target == nil then
                    return
                end
            end

            humanData.mana -= extraManaCost
            local result = dm.global_proc("do_teleport", humanData.human, target, nil, nil, nil, "sound/magic/blink.ogg", "sound/magic/blink.ogg", "magic")
            if result == 1 then
                local sparks = SS13.new("/datum/effect_system/spark_spread/quantum")
                sparks:call_proc("set_up", 5, 1, humanData.human)
                sparks:call_proc("attach", humanData.human:call_proc("drop_location"))
                sparks:call_proc("start")

                local sparks = SS13.new("/datum/effect_system/spark_spread/quantum")
                sparks:call_proc("set_up", 5, 1, target)
                sparks:call_proc("attach", target)
                sparks:call_proc("start")
            end
        end,
    },
    {
        spellName = "Lightning Bolt",
        manaCost = 50,
        activationSound = 'sound/magic/lightningbolt.ogg',
        activationRegex = "^I beseech thee, conjure a lightning bolt to kill my foes[!\\.]*$",
        callCount = 0,
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            dm.global_proc("_add_trait", humanData.human, "tesla_shock_immunity", "lightning_bolt_spell_"..tostring(self.callCount))
            SS13.set_timeout(6, function()
                dm.global_proc("_remove_trait", humanData.human, "tesla_shock_immunity", "lightning_bolt_spell"..tostring(self.callCount))
            end)
            local to_fire = SS13.new("/obj/projectile/magic/aoe/lightning")
            to_fire:set_var("zap_range", 15)
            to_fire:set_var("zap_power", 20000)
            to_fire:set_var("zap_flags", 8)
            to_fire:set_var("firer", humanData.human)
            to_fire:set_var("fired_from", humanData.human)
            local target = humanData.human:call_proc("drop_location")
            for i = 1, 8 do 
                target = dm.global_proc("_get_step", target, humanData.human:get_var("dir"))
            end
            to_fire:call_proc("preparePixelProjectile", target, humanData.human)
            to_fire:set_var("antimagic_flags", antiMagicFlag)
            to_fire:call_proc("fire")
        end,
    },
    {
        spellName = "Lesser Fireball",
        manaCost = 30,
        activationSound = 'sound/magic/fireball.ogg',
        activationRegex = "^I beseech thee, conjure a lesser fireball to kill my foes[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            local to_fire = SS13.new("/obj/projectile/magic/fireball")
            to_fire:set_var("exp_light", 1)
            to_fire:set_var("exp_flash", 0)
            to_fire:set_var("firer", humanData.human)
            to_fire:set_var("fired_from", humanData.human)
            local target = humanData.human:call_proc("drop_location")
            for i = 1, 8 do 
                target = dm.global_proc("_get_step", target, humanData.human:get_var("dir"))
            end
            to_fire:call_proc("preparePixelProjectile", target, humanData.human)
            to_fire:set_var("antimagic_flags", antiMagicFlag)
            to_fire:call_proc("fire")
        end,
    },
    {
        spellName = "Fireball",
        manaCost = 60,
        activationSound = 'sound/magic/fireball.ogg',
        activationRegex = "^I beseech thee, conjure a fireball to kill my foes[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            local to_fire = SS13.new("/obj/projectile/magic/fireball")
            to_fire:set_var("firer", humanData.human)
            to_fire:set_var("fired_from", humanData.human)
            local target = humanData.human:call_proc("drop_location")
            for i = 1, 8 do 
                target = dm.global_proc("_get_step", target, humanData.human:get_var("dir"))
            end
            to_fire:call_proc("preparePixelProjectile", target, humanData.human)
            to_fire:set_var("antimagic_flags", antiMagicFlag)
            to_fire:call_proc("fire")
        end,
    },
    {
        spellName = "Greater Fireball",
        manaCost = 100,
        activationSound = nil,
        activationRegex = "^I beseech thee, conjure a greater fireball to kill my foes[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            local target = humanData.human:call_proc("drop_location")
            for i = 1, 8 do 
                target = dm.global_proc("_get_step", target, humanData.human:get_var("dir"))
            end
            local to_fire = SS13.new("/obj/projectile/magic/fireball")
            to_fire:set_var("damage", 30)
            to_fire:set_var("exp_heavy", 1)
            to_fire:set_var("exp_light", 3)
            to_fire:set_var("firer", humanData.human)
            to_fire:set_var("fired_from", humanData.human)
            to_fire:call_proc("preparePixelProjectile", target, humanData.human)
            to_fire:set_var("antimagic_flags", antiMagicFlag)
            to_fire:call_proc("fire")
        end,
    },
    {
        spellName = "Tactical Nuke Fireball",
        manaCost = 200,
        activationSound = nil,
        activationRegex = "^I beseech thee, conjure a god damn nuke to kill my foes[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            local target = humanData.human:call_proc("drop_location")
            for i = 1, 8 do 
                target = dm.global_proc("_get_step", target, humanData.human:get_var("dir"))
            end
            local to_fire = SS13.new("/obj/projectile/magic/fireball")
            to_fire:set_var("damage", 999)
            to_fire:set_var("exp_heavy", 5)
            to_fire:set_var("exp_light", 10)
            to_fire:set_var("exp_")
            to_fire:set_var("firer", humanData.human)
            to_fire:set_var("fired_from", humanData.human)
            to_fire:call_proc("preparePixelProjectile", target, humanData.human)
            to_fire:set_var("antimagic_flags", antiMagicFlag)
            to_fire:call_proc("fire")
        end,
    },
    {
        spellName = "Lesser Heal",
        manaCost = 50,
        activationSound = nil,
        activationRegex = "^I beseech thee, lesser heal the soul standing in front of me[!\\.]*$",
        canActivate = function(self, humanData)
            return true
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            local target = dm.global_proc("_get_step", humanData.human, humanData.human:get_var("dir"))
            local healAmt = 20
            local healed = false
            for _, human in target:get_var("contents") do
                if not SS13.istype(human, "/mob/living") then
                    continue
                end
                if human:get_var("stat") == 4 then
                    continue
                end
                if human:get_var("health") == human:get_var("maxHealth") then
                    continue
                end
                human:call_proc("heal_overall_damage", healAmt, healAmt)
                SS13.new("/obj/effect/temp_visual/heal", human:call_proc("drop_location"), "#00ff00")
                dm.global_proc("playsound", human:call_proc("drop_location"), "sound/magic/staff_healing.ogg", 30)
                healed = true
                break
            end
            if not healed then
                humanData.mana += self.manaCost
            end
        end,
    },
    {
        spellName = "Greater Heal",
        manaCost = 200,
        activationSound = nil,
        activationRegex = "^I beseech thee, greater heal the soul standing in front of me[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            local target = dm.global_proc("_get_step", humanData.human, humanData.human:get_var("dir"))
            local healAmt = 20
            local healed = false
            for _, human in target:get_var("contents") do
                if not SS13.istype(human, "/mob/living") then
                    continue
                end
                if human:get_var("stat") == 4 then
                    continue
                end
                if human:get_var("health") == human:get_var("maxHealth") then
                    continue
                end
                human:call_proc("fully_heal")
                SS13.new("/obj/effect/temp_visual/heal", human:call_proc("drop_location"), "#00ff00")
                dm.global_proc("playsound", human:call_proc("drop_location"), "sound/magic/staff_healing.ogg", 30)
                healed = true
                break
            end
            if not healed then
                humanData.mana += self.manaCost
            end
        end,
    },
    {
        spellName = "Lesser Timestop",
        manaCost = 100,
        activationSound = nil,
        activationRegex = "^I beseech thee, cast lesser timestop for those around me[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            SS13.new("/obj/effect/timestop/magic", humanData.human:call_proc("drop_location"), 1, 100, { humanData.human })

        end
    },
    {
        spellName = "Timestop",
        manaCost = 150,
        activationSound = nil,
        activationRegex = "^I beseech thee, cast timestop for those around me[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            SS13.new("/obj/effect/timestop/magic", humanData.human:call_proc("drop_location"), 2, 150, { humanData.human })
        end
    },
    {
        spellName = "Greater Timestop",
        manaCost = 200,
        activationSound = nil,
        activationRegex = "^I beseech thee, cast greater timestop for those around me[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            SS13.new("/obj/effect/timestop/magic", humanData.human:call_proc("drop_location"), 3, 200, { humanData.human })
        end
    },
    {
        spellName = "Fear",
        manaCost = 30,
        activationSound = nil,
        activationRegex = "^I beseech thee, cast fear on the one named ([%s%w-'\"]+) near me[!\\.]*$",
        canActivate = function(self, humanData, name)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData, name)
            local foundPlayer = false
            for _, player in dm.global_vars:get_var("GLOB"):get_var("alive_player_list") do
                if string.find(string.lower(player:get_var("name")), string.lower(name)) ~= nil and dm.global_proc("_get_dist", player, humanData.human) <= 7 then
                    local phobia = SS13.new_untracked("/datum/brain_trauma/mild/phobia")
                    player:call_proc("gain_trauma", phobia, 1)
                    phobia:call_proc("freak_out", humanData.human)
                    player:call_proc("cure_trauma_type", SS13.type("/datum/brain_trauma/mild/phobia"), 1)
                    foundPlayer = true
                    break
                end
            end
            if not foundPlayer then
                humanData.mana += self.manaCost
            end
        end
    },
    {
        spellName = "Mass Hallucination",
        manaCost = 60,
        activationSound = nil,
        activationRegex = "^I beseech thee, conjure up illusions on the ones around me[!\\.]*$",
        canActivate = function(self, humanData)
            return hasWand(humanData)
        end,
        -- Arguments from the regex
        spellFunction = function(self, humanData)
            local hallucinations = {}
            for i=1, 3 do
                table.insert(hallucinations, dm.global_proc("get_random_valid_hallucination_subtype"))
            end
            local currentAmount = 0
            for _, player in dm.global_vars:get_var("GLOB"):get_var("alive_player_list") do
                if currentAmount > 7 then
                    break
                end
                if humanData.human ~= player and dm.global_proc("_get_dist", player, humanData.human) <= 7 then
                    for _, hallucination in hallucinations do
                        player:call_proc("_cause_hallucination", { hallucination, "(lua) spell casted by "..humanData.human:get_var("real_name") })
                    end
                    currentAmount += 1
                end
            end
        end
    },
}

local createHref = function(target, args, content)
	brackets = brackets == nil and true or false
	return "<a href='?src="..dm.global_proc("REF", target)..";"..args.."'>"..content.."</a>"
end

local function labelDisplay(label_name, content)
    return "<div style='display: flex; margin-top: 4px;'><div style='flex-grow: 1; color: #98B0C3;'>"..label_name..":</div><div>"..content.."</div></div>"
end

local function openMobSettings(user, humanData)
	local userCkey = user:get_var("ckey")
	local browser = SS13.new_untracked("/datum/browser", user, "Modifying "..humanData.human:get_var("real_name").." Stats", "Modifying "..humanData.human:get_var("real_name").." Stats", 300, 200)
	local data = ""
    data = data.."<h1>"..humanData.human:get_var("real_name").." Stats</h1></hr>"
	data = data..labelDisplay("Max Mana", createHref(humanData.human:get_var("dna"), "max_mana=1", tostring(humanData.maxMana)))
	data = data..labelDisplay("Mana Regen Rate", createHref(humanData.human:get_var("dna"), "mana_regen_rate=1", tostring(humanData.manaRegenRate)))
	browser:call_proc("set_content", data)
	browser:call_proc("open")
end

local function setupSpells(human)
    local humanData = {
        human = human,
        mana = 5000,
        maxMana = math.random(50, 500),
        -- Mana regen per second
        manaRegenRate = math.floor((math.random() * 3 + 0.5) * 100) / 100,
        -- Mana exhaustion multiplier effect
        manaExhaustionMult = 0.99,
        spells = {}
    }
    local function updateStamDamage()
        humanData.mana = math.min(humanData.mana, humanData.maxMana)
        -- Clone loss was removed, rip
        -- human:call_proc("setCloneLoss", (100 - (100 * (humanData.mana / humanData.maxMana))) * humanData.manaExhaustionMult)
    end
    SS13.unregister_signal(human, "living_life")
    SS13.unregister_signal(human, "mob_say")
	SS13.unregister_signal(human, "ctrl_click")
    SS13.unregister_signal(human, "atom_attackby")
    SS13.unregister_signal(human, "atom_examine")
    SS13.unregister_signal(human:get_var("dna"), "handle_topic")
	SS13.register_signal(human, "atom_examine", function(_, examining_mob, examine_list)
		if SS13.istype(examining_mob, "/mob/dead") or examining_mob:get_var("ckey") == admin then
			examine_list:add("<hr/><span class='notice'>Mana: "..humanData.mana.."</span>")
			examine_list:add("<span class='notice'>Max Mana: "..humanData.maxMana.."</span>")
			examine_list:add("<span class='notice'>Mana Regeneration Rate: "..humanData.manaRegenRate.."</span>")
            if examining_mob:get_var("ckey") == admin then
                local settingsData = createHref(human:get_var("dna"), "settings=1", "Modify Stats")
			    examine_list:add("<span class='notice'>"..settingsData.."</span>")
            end
			examine_list:add("<hr/>")
		end
	end)
    local isOpen = false
    SS13.register_signal(human:get_var("dna"), "handle_topic", function(_, user, href_list)
        if user:get_var("ckey") ~= admin then
            return
        end

        if href_list:get("settings") then
            openMobSettings(user, humanData)
        end
        
        if isOpen then
            return
        end

        if href_list:get("max_mana") then
            isOpen = true
			local newMaxMana = SS13.await(SS13.global_proc, "tgui_input_number", user, "Please input new max mana", "New max mana", humanData.maxMana, 500000, 1)
			isOpen = false
			if newMaxMana == nil then
				return
			end
            humanData.mana = newMaxMana
			humanData.maxMana = newMaxMana
			openMobSettings(user, humanData)
        elseif href_list:get("mana_regen_rate") then
            isOpen = true
			local newRegenRate = SS13.await(SS13.global_proc, "tgui_input_number", user, "Please input new mana regen rate", "TV audio volume", humanData.manaRegenRate, 50000, 0)
			isOpen = false
			if newRegenRate == nil then
				return
			end
			humanData.manaRegenRate = newRegenRate
			openMobSettings(user, humanData)
        end
    end)
    SS13.register_signal(human, "mob_say", function(_, speech_args)
        local message = speech_args:get(1)
        local returnValue = {}
        local spell
        for _, potentialSpell in SPELLS do
            if humanData.spells[potentialSpell.spellName] == nil then
                continue
            end
            returnValue = {string.match(string.lower(message), string.lower(potentialSpell.activationRegex))}
            if #returnValue ~= 0 then
                spell = potentialSpell
                break
            end
        end
        if #returnValue == 0 then
            return
        end
        if not spell:canActivate(humanData, unpack(returnValue)) then
            return
        end
        if humanData.mana < spell.manaCost then
            speech_args:set(1, "")
            human:call_proc("visible_message", "<span class='notice'>"..human:get_var("name").." tries to utter something, but can't seem to get the words out.</span>", "<span class='danger'>You try to utter something, but can't draw the energy to do so.</span>")
            return
        end
        humanData.mana -= spell.manaCost
        if spell.activationSound then
            dm.global_proc("playsound", human, spell.activationSound, 30)
        end
        spell:spellFunction(humanData, unpack(returnValue))
        updateStamDamage()
    end)
    SS13.register_signal(human, "living_life", function(_, seconds_per_tick)
        humanData.mana = math.min(humanData.maxMana, humanData.mana + humanData.manaRegenRate * seconds_per_tick)
        updateStamDamage()
    end)
    SS13.register_signal(human, "atom_attackby", function(_, item, attacker)
        if SS13.istype(item, "/obj/item/stack/sheet/bluespace_crystal") then
            local amount = item:get_var("amount")
            local maxUsableAmount = humanData.maxMana - humanData.mana
            local usedAmount = math.min(amount, maxUsableAmount)
            if item:call_proc("use", usedAmount) == 1 then
                humanData.mana += usedAmount
                humanData.maxMana += math.floor(usedAmount / 10)
                updateStamDamage()
                attacker:call_proc("visible_message", "<span class='notice'>The bluespace crystals gently shatter in "..attacker:get_var("name").."'s hands and a blue hue envelopes "..human:get_var("name").."</span>")
            end
            return 1
        end
    end)
    local isOpen = false
	SS13.register_signal(human, "ctrl_click", function(_, clicker)
		if isOpen then
			return
		end
		if clicker:get_var("ckey") == admin then
			SS13.set_timeout(0, function()
                local listDisplay = {}
                local infoMapping = {}
                for _, spell in SPELLS do
                    if humanData.spells[spell.spellName] ~= nil then
                        local key = "(Remove)"..spell.spellName
                        table.insert(listDisplay, key)
                        infoMapping[key] = spell.spellName
                    end
                end
                for _, spell in SPELLS do
                    if humanData.spells[spell.spellName] == nil then
                        local key = "(Add)"..spell.spellName
                        table.insert(listDisplay, key)
                        infoMapping[key] = spell.spellName
                    end
                end
				isOpen = true
				local input = SS13.await(SS13.global_proc, "tgui_input_list", clicker, "Add or remove a spell", "Add/Remove Spell", listDisplay)
				isOpen = false
				if input == nil or input == -1 then
					return
				end
                local toChange = infoMapping[input]
                if humanData.spells[toChange] == nil then
                    humanData.spells[toChange] = true
                else
                    humanData.spells[toChange] = nil
                end
			end)
		end
	end)

    if not SILENT then
        dm.global_proc("to_chat", human, "<span class='notice' style='font-size: 24px'>You feel a mystical energy around you, blue and soothing. It empowers you to seek the mystic arts.</span>")
    end
end

local user = dm.global_vars:get_var("GLOB"):get_var("directory"):get(admin):get_var("mob")
if IS_LOCAL then
    setupSpells(user)
else
    if(SS13.await(SS13.global_proc, "tgui_alert", user, "Update all mobs?", "Update all mobs?", { "No", "Yes" }) ~= "Yes") then
        return
    end

    local SSdcs = dm.global_vars:get_var("SSdcs")
    SS13.unregister_signal(SSdcs, "!mob_created")
    SS13.register_signal(SSdcs, "!mob_created", function(_, target)
        SS13.set_timeout(3, function()
            if SS13.is_valid(target) and SS13.istype(target, "/mob/living/carbon/human") then
                setupSpells(target)
            end
        end)
    end)

    for _, human in dm.global_vars:get_var("GLOB"):get_var("mob_list") do
        if over_exec_usage(0.7) then
            sleep()
        end
        if SS13.istype(human, "/mob/living/carbon/human") then
            setupSpells(human)
        end
    end
end