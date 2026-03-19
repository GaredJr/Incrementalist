local PrestigeService = {
	_dataService = nil,
	_economyService = nil,
	_questService = nil,
	_configs = nil,
	_formulaUtil = nil,
	_publishState = nil,
	_analyticsService = nil,
	_sessionService = nil,
}

function PrestigeService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._economyService = dependencies.EconomyService
	self._questService = dependencies.QuestService
	self._configs = dependencies.Configs
	self._formulaUtil = dependencies.FormulaUtil
	self._publishState = dependencies.PublishState
	self._analyticsService = dependencies.AnalyticsService
	self._sessionService = dependencies.SessionService
end

function PrestigeService:RequestReprint(player)
	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	local runLifetimeHype = playerData.lifetimeHype - (playerData.reprintCheckpointHype or 0)
	local reward = self._formulaUtil.getPrestigeReward(runLifetimeHype, self._configs)
	if reward <= 0 then
		return false, "Need more Hype before Reprint becomes worth it."
	end

	local ok, collectionMeta = self._economyService:ResetBoardForReprint(player, reward)
	if not ok then
		return false, collectionMeta
	end

	self._questService:RecordProgress(player, "reprint", 1)
	self._analyticsService:Track(player, "reprint_completed", {
		inkReward = reward,
		runLifetimeHype = runLifetimeHype,
	})

	if self._sessionService then
		self._sessionService:QueueNotification(player, {
			kind = "reprint",
			title = "Board Reprinted",
			message = string.format("You locked in %d Ink Shards from that run.", reward),
		})
	end

	self._publishState(player, "ReprintCompleted", {
		inkShardsEarned = reward,
		runLifetimeHype = runLifetimeHype,
		collectionMeta = collectionMeta,
	})

	return true, reward
end

return PrestigeService
