local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyQuestUtil = require(ReplicatedStorage.Shared.Util.DailyQuestUtil)

local QuestService = {
	_dataService = nil,
	_configs = nil,
	_rewardCallback = nil,
	_analyticsService = nil,
	_sessionService = nil,
	_tutorialService = nil,
}

function QuestService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._configs = dependencies.Configs
	self._analyticsService = dependencies.AnalyticsService
	self._sessionService = dependencies.SessionService
	self._tutorialService = dependencies.TutorialService
end

function QuestService:SetRewardCallback(callback)
	self._rewardCallback = callback
end

local function getStarterQuestConfig(configs, questId)
	return configs.Quests.STARTER[questId]
end

local function findDailyQuest(board, questId)
	for index, quest in ipairs(board.quests or {}) do
		if quest.id == questId then
			return quest, index
		end
	end
	return nil, nil
end

function QuestService:RefreshDailyBoard(player, force)
	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	local now = os.time()
	local hasExistingBoard = type(playerData.dailyBoard) == "table" and #(playerData.dailyBoard.quests or {}) > 0
	if not force and hasExistingBoard and not DailyQuestUtil.isBoardExpired(playerData.dailyBoard, now) then
		return false, "Daily board is still active."
	end

	local generatedBoard = DailyQuestUtil.generateDailyBoard(playerData, self._configs.Quests, self._configs, now)
	local ok, result = self._dataService:Update(player, function(currentData)
		currentData.dailyBoard = generatedBoard
		currentData.lastOnlineUnix = now
		return true
	end)

	if not ok or result ~= true then
		return false, result
	end

	self._analyticsService:Track(player, "daily_board_refreshed", {
		dayKey = generatedBoard.dayKey,
		slots = #generatedBoard.quests,
	})

	return true, generatedBoard
end

function QuestService:RecordProgress(player, questType, amount)
	if amount <= 0 then
		return false
	end

	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false
	end

	local shouldUpdate = false
	for questId, questConfig in pairs(self._configs.Quests.STARTER) do
		local questState = playerData.quests[questId]
		if questConfig.type == questType and questState and not questState.claimed and questState.progress < questConfig.target then
			shouldUpdate = true
			break
		end
	end

	if not shouldUpdate then
		for _, quest in ipairs(playerData.dailyBoard and playerData.dailyBoard.quests or {}) do
			if quest.type == questType and not quest.claimed and (quest.progress or 0) < (quest.target or 0) then
				shouldUpdate = true
				break
			end
		end
	end

	if not shouldUpdate then
		return false
	end

	return self._dataService:Update(player, function(currentData)
		for questId, questConfig in pairs(self._configs.Quests.STARTER) do
			local questState = currentData.quests[questId]
			if questConfig.type == questType and questState and not questState.claimed then
				questState.progress = math.min(questConfig.target, questState.progress + amount)
				questState.completed = questState.progress >= questConfig.target
			end
		end

		for _, quest in ipairs(currentData.dailyBoard.quests or {}) do
			if quest.type == questType and not quest.claimed then
				quest.progress = math.min(quest.target, quest.progress + amount)
				quest.completed = quest.progress >= quest.target
			end
		end

		return true
	end)
end

function QuestService:ClaimQuest(player, questId)
	if type(questId) ~= "string" then
		return false, "Quest id must be a string."
	end

	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	local starterQuestConfig = getStarterQuestConfig(self._configs, questId)
	local dailyQuest, dailyIndex = findDailyQuest(playerData.dailyBoard, questId)
	local questConfig = starterQuestConfig or dailyQuest
	if not questConfig then
		return false, "Unknown quest."
	end

	local ok, stateResult, claimedCategory = self._dataService:Update(player, function(currentData)
		if starterQuestConfig then
			local questState = currentData.quests[questId]
			if not questState then
				return false, "Quest state missing."
			end

			if questState.claimed then
				return false, "Quest reward already claimed."
			end

			if not questState.completed then
				return false, "Quest is not complete yet."
			end

			questState.claimed = true
			currentData.lastOnlineUnix = os.time()
			return true, "starter"
		end

		local currentDaily = currentData.dailyBoard.quests[dailyIndex]
		if not currentDaily then
			return false, "Quest state missing."
		end

		if currentDaily.claimed then
			return false, "Quest reward already claimed."
		end

		if not currentDaily.completed then
			return false, "Quest is not complete yet."
		end

		currentDaily.claimed = true
		currentData.lastOnlineUnix = os.time()
		return true, "daily"
	end)

	if not ok or stateResult ~= true then
		return false, claimedCategory or stateResult
	end

	if not self._rewardCallback then
		return false, "Quest rewards are not configured."
	end

	local rewardOk, rewardResult = self._rewardCallback(player, questConfig.reward, "quest:" .. questId)
	if not rewardOk then
		return false, rewardResult or "Quest reward failed."
	end

	if claimedCategory == "daily" then
		self._analyticsService:Track(player, "daily_claimed", {
			questId = questId,
			templateId = questConfig.templateId,
		})
	end

	local tutorialMeta = self._tutorialService and self._tutorialService:Evaluate(player, "claim_quest") or nil

	if self._sessionService then
		self._sessionService:QueueNotification(player, {
			kind = claimedCategory == "daily" and "daily" or "quest",
			title = claimedCategory == "daily" and "Daily Claimed" or "Quest Claimed",
			message = string.format("%s reward collected.", questConfig.name),
		})
	end

	return true, "Quest claimed.", {
		questId = questId,
		category = claimedCategory,
		reward = questConfig.reward,
		tutorialMeta = tutorialMeta,
	}
end

return QuestService
