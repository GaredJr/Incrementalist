local TutorialUtil = {}

local function hasAnyClaimedQuest(playerData)
	for _, questState in pairs(playerData.quests or {}) do
		if type(questState) == "table" and questState.claimed == true then
			return true
		end
	end

	for _, questState in ipairs(playerData.dailyBoard and playerData.dailyBoard.quests or {}) do
		if type(questState) == "table" and questState.claimed == true then
			return true
		end
	end

	return false
end

local function hasAnyNonStarterSticker(playerData, configs)
	for stickerId, count in pairs(playerData.ownedStickers or {}) do
		if stickerId ~= configs.Economy.STARTER_STICKER_ID and (count or 0) > 0 then
			return true
		end
	end

	return false
end

local function hasAnyStandardUpgrade(playerData, configs)
	for upgradeId, upgradeConfig in pairs(configs.Upgrades or {}) do
		if upgradeConfig.type == "standard" and (playerData.upgrades[upgradeId] or 0) > 0 then
			return true
		end
	end

	return false
end

local function hasAnyNonStarterZone(playerData, configs)
	for zoneId, unlocked in pairs(playerData.unlockedZones or {}) do
		if unlocked and zoneId ~= configs.Economy.STARTER_ZONE_ID then
			return true
		end
	end

	return false
end

local function getCompletedStepsMap(configs)
	local completedSteps = {}

	for _, stepId in ipairs(configs.Tutorial.ORDER or {}) do
		completedSteps[stepId] = false
	end

	return completedSteps
end

local function getNextIncompleteStepId(completedSteps, configs)
	for _, stepId in ipairs(configs.Tutorial.ORDER or {}) do
		if completedSteps[stepId] ~= true then
			return stepId
		end
	end

	return nil
end

function TutorialUtil.createState(configs)
	return {
		currentStepId = configs.Tutorial.ORDER[1],
		completedSteps = getCompletedStepsMap(configs),
		completed = false,
	}
end

function TutorialUtil.createCompletedState(configs)
	local state = TutorialUtil.createState(configs)

	for stepId, _ in pairs(state.completedSteps) do
		state.completedSteps[stepId] = true
	end

	state.currentStepId = nil
	state.completed = true
	return state
end

function TutorialUtil.hasMigrationProgress(playerData, configs)
	return hasAnyNonStarterSticker(playerData, configs)
		or hasAnyStandardUpgrade(playerData, configs)
		or hasAnyClaimedQuest(playerData)
		or hasAnyNonStarterZone(playerData, configs)
		or (playerData.prestigeCount or 0) > 0
end

function TutorialUtil.normalizeState(existingState, configs)
	if type(existingState) ~= "table" then
		return TutorialUtil.createState(configs)
	end

	local normalized = {
		currentStepId = existingState.currentStepId,
		completedSteps = getCompletedStepsMap(configs),
		completed = existingState.completed == true,
	}

	if type(existingState.completedSteps) == "table" then
		for stepId, completed in pairs(existingState.completedSteps) do
			if normalized.completedSteps[stepId] ~= nil then
				normalized.completedSteps[stepId] = completed == true
			end
		end
	end

	if normalized.completed then
		for stepId, _ in pairs(normalized.completedSteps) do
			normalized.completedSteps[stepId] = true
		end
		normalized.currentStepId = nil
		return normalized
	end

	local nextIncompleteStepId = getNextIncompleteStepId(normalized.completedSteps, configs)
	normalized.currentStepId = nextIncompleteStepId
	normalized.completed = nextIncompleteStepId == nil

	return normalized
end

function TutorialUtil.isStepSatisfied(stepId, playerData, configs)
	if stepId == "collect_once" then
		return (playerData.lifetimeHype or 0) > 0
	end

	if stepId == "print_basic_smile" then
		return (playerData.ownedStickers.basic_smile or 0) > configs.Economy.STARTER_STICKER_COUNT
			or (playerData.ownedStickers.neon_cat or 0) > 0
			or (playerData.ownedStickers.holo_dragon or 0) > 0
			or (playerData.ownedStickers.cosmic_ghost or 0) > 0
	end

	if stepId == "merge_neon_cat" then
		return (playerData.ownedStickers.neon_cat or 0) > 0
			or (playerData.ownedStickers.holo_dragon or 0) > 0
			or (playerData.ownedStickers.cosmic_ghost or 0) > 0
	end

	if stepId == "buy_tap_power_lv1" then
		return (playerData.upgrades.tap_power or 0) >= 1
	end

	if stepId == "claim_any_quest" then
		return hasAnyClaimedQuest(playerData)
	end

	if stepId == "unlock_neon_alley" then
		return playerData.unlockedZones.neon_alley == true
	end

	return false
end

function TutorialUtil.advanceFromState(existingState, playerData, configs)
	local updatedState = TutorialUtil.normalizeState(existingState, configs)
	local completedStepIds = {}

	while updatedState.currentStepId and TutorialUtil.isStepSatisfied(updatedState.currentStepId, playerData, configs) do
		local stepId = updatedState.currentStepId
		updatedState.completedSteps[stepId] = true
		table.insert(completedStepIds, stepId)
		updatedState.currentStepId = getNextIncompleteStepId(updatedState.completedSteps, configs)
	end

	updatedState.completed = updatedState.currentStepId == nil
	return updatedState, completedStepIds
end

return TutorialUtil
