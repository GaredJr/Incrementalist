local ZoneService = {
	_dataService = nil,
	_economyService = nil,
	_collectionService = nil,
	_questService = nil,
	_configs = nil,
	_publishState = nil,
	_analyticsService = nil,
	_sessionService = nil,
	_tutorialService = nil,
}

function ZoneService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._economyService = dependencies.EconomyService
	self._collectionService = dependencies.CollectionService
	self._questService = dependencies.QuestService
	self._configs = dependencies.Configs
	self._publishState = dependencies.PublishState
	self._analyticsService = dependencies.AnalyticsService
	self._sessionService = dependencies.SessionService
	self._tutorialService = dependencies.TutorialService
end

function ZoneService:_publish(player, reason, meta)
	if self._publishState then
		self._publishState(player, reason, meta)
	end
end

function ZoneService:UnlockZone(player, zoneId)
	if type(zoneId) ~= "string" then
		return false, "Zone id must be a string."
	end

	local zoneConfig = self._configs.Zones[zoneId]
	if not zoneConfig then
		return false, "Unknown zone."
	end

	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	if playerData.unlockedZones[zoneId] then
		return false, "Zone is already unlocked."
	end

	if zoneConfig.requiredZoneId and not playerData.unlockedZones[zoneConfig.requiredZoneId] then
		return false, "Unlock the previous zone first."
	end

	local spendOk, spendErr = self._economyService:SpendCurrency(player, "hype", zoneConfig.unlockCost or 0)
	if not spendOk then
		return false, spendErr
	end

	local ok, result = self._dataService:Update(player, function(currentData)
		currentData.unlockedZones[zoneId] = true
		currentData.zoneId = zoneId
		currentData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or result ~= true then
		return false, result
	end

	local rewardMeta
	if zoneConfig.rewardStickerId then
		local stickerOk, stickerResult = self._economyService:GrantSticker(
			player,
			zoneConfig.rewardStickerId,
			zoneConfig.rewardAmount or 1,
			"zone_unlock:" .. zoneId
		)
		if stickerOk then
			rewardMeta = stickerResult
		end
	end

	self._questService:RecordProgress(player, "unlock_zone", 1)
	self._analyticsService:Track(player, "zone_unlocked", {
		zoneId = zoneId,
		cost = zoneConfig.unlockCost or 0,
	})

	local tutorialMeta = self._tutorialService and self._tutorialService:Evaluate(player, "unlock_zone") or nil

	if self._sessionService then
		self._sessionService:QueueNotification(player, {
			kind = "zone",
			title = "Zone Unlocked",
			message = string.format("%s is ready to explore.", zoneConfig.name),
		})
	end

	self:_publish(player, "ZoneUnlocked", {
		zoneId = zoneId,
		rewardStickerId = zoneConfig.rewardStickerId,
		rewardAmount = zoneConfig.rewardAmount or 0,
		message = string.format("%s unlocked.", zoneConfig.name),
		collectionMeta = rewardMeta and rewardMeta.collectionMeta or nil,
		rewardMeta = rewardMeta,
		tutorialMeta = tutorialMeta,
	})

	return true, zoneId
end

function ZoneService:SelectZone(player, zoneId)
	if type(zoneId) ~= "string" then
		return false, "Zone id must be a string."
	end

	local zoneConfig = self._configs.Zones[zoneId]
	if not zoneConfig then
		return false, "Unknown zone."
	end

	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	if not playerData.unlockedZones[zoneId] then
		return false, "Zone is still locked."
	end

	local ok, result = self._dataService:Update(player, function(currentData)
		currentData.zoneId = zoneId
		currentData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or result ~= true then
		return false, result
	end

	self._analyticsService:Track(player, "zone_selected", {
		zoneId = zoneId,
	})

	self:_publish(player, "ZoneSelected", {
		zoneId = zoneId,
		message = string.format("Now showcasing %s.", zoneConfig.name),
	})

	return true, zoneId
end

return ZoneService
