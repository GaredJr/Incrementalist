local DailyQuestUtil = {}

local function deepCopy(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}
	for key, value in pairs(source) do
		copy[key] = deepCopy(value)
	end
	return copy
end

function DailyQuestUtil.getDayKey(timestamp)
	return math.floor((timestamp or os.time()) / 86400)
end

function DailyQuestUtil.getNextResetAtUnix(timestamp)
	local dayKey = DailyQuestUtil.getDayKey(timestamp)
	return (dayKey + 1) * 86400
end

local function getHighestUnlockedZoneOrder(playerData, configs)
	local highestOrder = 1
	for zoneId, unlocked in pairs(playerData.unlockedZones or {}) do
		if unlocked and configs.Zones[zoneId] then
			highestOrder = math.max(highestOrder, configs.Zones[zoneId].sortOrder or 1)
		end
	end
	return highestOrder
end

function DailyQuestUtil.isTemplateAvailable(template, playerData, configs)
	if not template then
		return false
	end

	local highestZoneOrder = getHighestUnlockedZoneOrder(playerData, configs)
	if highestZoneOrder < (template.minimumZoneOrder or 1) then
		return false
	end

	if highestZoneOrder > (template.maximumZoneOrder or math.huge) then
		return false
	end

	if (playerData.lifetimeHype or 0) < (template.minimumLifetimeHype or 0) then
		return false
	end

	if (playerData.prestigeCount or 0) < (template.minimumPrestigeCount or 0) then
		return false
	end

	return true
end

local function weightedPick(pool, random)
	local totalWeight = 0
	for _, item in ipairs(pool) do
		totalWeight += item.weight or 1
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = random:NextNumber(0, totalWeight)
	local cumulative = 0
	for index, item in ipairs(pool) do
		cumulative += item.weight or 1
		if roll <= cumulative then
			return index, item
		end
	end

	return #pool, pool[#pool]
end

function DailyQuestUtil.generateDailyBoard(playerData, questConfig, configs, timestamp)
	local now = timestamp or os.time()
	local dayKey = DailyQuestUtil.getDayKey(now)
	local random = Random.new(dayKey)
	local candidatePool = {}

	for _, template in pairs(questConfig.DAILY_TEMPLATES or {}) do
		if DailyQuestUtil.isTemplateAvailable(template, playerData, configs) then
			table.insert(candidatePool, deepCopy(template))
		end
	end

	table.sort(candidatePool, function(left, right)
		return (left.sortOrder or 0) < (right.sortOrder or 0)
	end)

	local quests = {}
	local boardSize = math.min(questConfig.DAILY_BOARD_SIZE or 3, #candidatePool)

	for slot = 1, boardSize do
		local pickedIndex, template = weightedPick(candidatePool, random)
		if not template then
			break
		end

		table.remove(candidatePool, pickedIndex)
		table.insert(quests, {
			id = string.format("daily_%d_%d", dayKey, slot),
			templateId = template.id,
			category = "daily",
			name = template.name,
			description = template.description,
			type = template.type,
			target = template.target,
			progress = 0,
			completed = false,
			claimed = false,
			reward = deepCopy(template.reward),
		})
	end

	return {
		dayKey = dayKey,
		resetAtUnix = DailyQuestUtil.getNextResetAtUnix(now),
		quests = quests,
	}
end

function DailyQuestUtil.isBoardExpired(board, timestamp)
	local now = timestamp or os.time()
	return type(board) ~= "table" or (board.resetAtUnix or 0) <= now
end

return DailyQuestUtil
