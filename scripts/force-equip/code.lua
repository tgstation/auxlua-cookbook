SS13 = require("SS13")

-- Configuration

-- Outfit to equip them with. Change to the other line if you don't want an outfit.
local OUTFIT = "/datum/outfit/job/prisoner"
-- local OUTFIT = nil

-- Other items to equip
local ITEMS_TO_EQUIP = {
	"/obj/item/gun/energy/e_gun",
	-- Insert more here
}

-- Actual code
if DESTRUCT_FORCE_EQUIP ~= nil then
	DESTRUCT_FORCE_EQUIP()
	DESTRUCT_FORCE_EQUIP = nil
end

local GLOB = dm.global_vars:get_var("GLOB")
local SSdcs = dm.global_vars:get_var("SSdcs")

local function clearOutfit(mob)
	for _, equippedItem in
		mob
			:call_proc(
				"get_equipped_items", --[[ pockets = ]]
				true
			)
			:to_table()
	do
		dm.global_proc("qdel", equippedItem)
	end
end

local function equipMob(mob)
	if not SS13.istype(mob, "/mob/living/carbon/human") then
		return
	end

	if OUTFIT ~= nil then
		clearOutfit(mob)

		mob:call_proc("equipOutfit", dm.global_proc("_text2path", OUTFIT))
	end

	local mobLoc = mob:get_var("loc")

	for _, itemPath in ITEMS_TO_EQUIP do
		local item = SS13.new(itemPath, mobLoc)

		if mob:call_proc("equip_to_appropriate_slot", item) ~= 0 then
			continue
		end

		mob:call_proc("put_in_hands", item)
	end
end

for _, mob in GLOB:get_var("player_list"):to_table() do
	if mob:get_var("mind") ~= nil then
		equipMob(mob)
	end
end

local function equipMobSignal(_source, _job, mob)
	equipMob(mob)
end

SS13.register_signal(SSdcs, "!job_after_latejoin_spawn", equipMobSignal)

DESTRUCT_FORCE_EQUIP = function()
	SS13.unregister_signal(SSdcs, "!job_after_latejoin_spawn", equipMobSignal)
end
