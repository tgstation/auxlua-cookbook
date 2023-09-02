local function getXpReq(level)
	local scale = math.floor(level / 10)
	return 10 * (2 ^ (scale+1))
end

function doHit(refinedAmount, Crafting)
    local limit = 50 * (2 ^ (Crafting * 0.15))
    local previousRefinedAmount = refinedAmount
    local increaseAmount = 50 * (2 ^ (Crafting * 0.1))
    if refinedAmount < limit then
        refinedAmount += increaseAmount
    else
        local exceededAmount = ((refinedAmount - limit) / (50 * (Crafting + 1)))
        refinedAmount += increaseAmount / (2 ^ exceededAmount)
    end
    return refinedAmount
end

local browser = SS13.new("/datum/browser", dm.usr, "Blacksmith Guide", "Blacksmith Guide", 600, 700)
local data = ""
for i = 0, 100, 10 do
    local refinedAmount = -100
    for _ = 1, 10 do
        refinedAmount = doHit(refinedAmount, i)
    end
    local quality = math.ceil(math.log((refinedAmount + 1) / 500) / math.log(2))
    local expReward = 10 * (2 ^ quality)
    data = data .. "Iteration: "..i.." | RefinedAmount: "..math.ceil(refinedAmount).." | Quality: "..quality.." | Experience Reward: "..expReward.." | Experience Required: "..getXpReq(i).."<br/>"
end
browser:call_proc("set_content", data)
browser:call_proc("open")