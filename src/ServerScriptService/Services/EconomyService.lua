local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutomationUtil = require(ReplicatedStorage.Shared.Util.AutomationUtil)

local EconomyService = {
	_dataService = nil,
	_questService = nil,
	_collectionService = nil,
	_upgradeService = nil,
	_tutorialService = nil,
	_configs = nil,
	_formulaUtil = nil,
	_publishState = nil,
	_tickAccumulator = 0,
	_heartbeatConnection = nil,
}

local function normalizePositiveInteger(value)
	local numberValue = tonumber(value)
	if not numberValue then
		return 0
	end

	return math.max(0, math.floor(numberValue + 0.5))
end

function EconomyService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._questService = dependencies.QuestService
	self._collectionService = dependencies.CollectionService
	self._tutorialService = dependencies.TutorialService
	self._configs = dependencies.Configs
	self._formulaUtil = dependencies.FormulaUtil
	self._publishState = dependencies.PublishState
end

function EconomyService:SetUpgradeService(upgradeService)
	self._upgradeService = upgradeService
end

function EconomyService:_publish(player, reason, meta)
	if self._publishState then
		self._publishState(player, reason, meta)
	end
end

function EconomyService:GrantCurrency(player, currencyName, amount, source, countTowardQuests)
	amount = normalizePositiveInteger(amount)
	if amount <= 0 then
		return false, "Amount must be positive."
	end

	local ok, err = self._dataService:Update(player, function(playerData)
		if currencyName == "hype" then
			playerData.hype += amount
			playerData.lifetimeHype += amount
		elseif currencyName == "inkShards" then
			playerData.inkShards += amount
		else
			return false, "Unknown currency."
		end

		playerData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or err ~= true then
		return false, err
	end

	if currencyName == "hype" and countTowardQuests ~= false then
		self._questService:RecordProgress(player, "collect_hype", amount)
	end

	return true, {
		currency = currencyName,
		amount = amount,
		source = source,
	}
end

function EconomyService:SpendCurrency(player, currencyName, amount)
	amount = normalizePositiveInteger(amount)
	if amount <= 0 then
		return false, "Amount must be positive."
	end

	local ok, err = self._dataService:Update(player, function(playerData)
		local currentAmount = playerData[currencyName]
		if type(currentAmount) ~= "number" then
			return false, "Unknown currency."
		end

		if currentAmount < amount then
			return false, "Not enough " .. currencyName .. "."
		end

		playerData[currencyName] -= amount
		playerData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or err ~= true then
		return false, err
	end

	return true
end

function EconomyService:GrantSticker(player, stickerId, amount, source)
	amount = normalizePositiveInteger(amount)
	if amount <= 0 or not self._configs.Stickers[stickerId] then
		return false, "Unknown sticker reward."
	end

	local ok, err = self._dataService:Update(player, function(playerData)
		playerData.ownedStickers[stickerId] = (playerData.ownedStickers[stickerId] or 0) + amount
		playerData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or err ~= true then
		return false, err
	end

	local collectionOk, collectionMeta = self._collectionService:SyncBook(player, source or ("sticker:" .. stickerId))
	if not collectionOk then
		return false, collectionMeta
	end

	return true, {
		stickerId = stickerId,
		amount = amount,
		collectionMeta = collectionMeta,
	}
end

function EconomyService:GrantReward(player, reward, source)
	if reward.currency then
		return self:GrantCurrency(player, reward.currency, reward.amount, source, true)
	end

	if reward.stickerId then
		return self:GrantSticker(player, reward.stickerId, reward.amount, source)
	end

	return false, "Unsupported reward payload."
end

function EconomyService:HandleCollect(player)
	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	local reward = self._formulaUtil.getManualCollectReward(playerData, self._configs)
	local ok, result = self:GrantCurrency(player, "hype", reward, "manual_collect", true)
	if not ok then
		return false, result
	end

	self:_publish(player, "Collected", {
		source = "manual_collect",
		amount = reward,
		tutorialMeta = self._tutorialService and self._tutorialService:Evaluate(player, "collect") or nil,
	})

	return true, result
end

function EconomyService:HandlePrintSticker(player, stickerId)
	if type(stickerId) ~= "string" or not self._configs.Stickers[stickerId] then
		return false, "Unknown sticker."
	end

	local stickerConfig = self._configs.Stickers[stickerId]
	if (stickerConfig.tier or 0) ~= 1 or not stickerConfig.printCost then
		return false, "That sticker cannot be printed directly."
	end

	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	if not playerData.unlockedZones[stickerConfig.zoneId] then
		return false, "Unlock the sticker's zone first."
	end

	local spendOk, spendErr = self:SpendCurrency(player, "hype", stickerConfig.printCost)
	if not spendOk then
		return false, spendErr
	end

	local rewardOk, rewardMeta = self:GrantSticker(player, stickerId, 1, "print:" .. stickerId)
	if not rewardOk then
		return false, rewardMeta
	end

	self._questService:RecordProgress(player, "print_sticker", 1)

	self:_publish(player, "StickerPrinted", {
		stickerId = stickerId,
		amount = 1,
		cost = stickerConfig.printCost,
		collectionMeta = rewardMeta.collectionMeta,
		tutorialMeta = self._tutorialService and self._tutorialService:Evaluate(player, "print_sticker") or nil,
	})

	return true, rewardMeta
end

function EconomyService:HandleMerge(player, stickerId, options)
	if type(stickerId) ~= "string" or not self._configs.Stickers[stickerId] then
		return false, "Unknown sticker."
	end

	local nextStickerId = self._formulaUtil.getNextStickerId(stickerId, self._configs)
	if not nextStickerId then
		return false, "This sticker cannot be merged further."
	end

	local ok, stateResult = self._dataService:Update(player, function(playerData)
		if not self._formulaUtil.canMergeSticker(playerData, stickerId, self._configs) then
			return false, "Need two matching stickers to merge."
		end

		playerData.ownedStickers[stickerId] -= 2
		playerData.ownedStickers[nextStickerId] = (playerData.ownedStickers[nextStickerId] or 0) + 1
		playerData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or stateResult ~= true then
		return false, stateResult
	end

	self._questService:RecordProgress(player, "merge_sticker", 1)
	local collectionOk, collectionMeta = self._collectionService:SyncBook(player, options and options.source or ("merge:" .. stickerId))
	if not collectionOk then
		return false, collectionMeta
	end

	if not (options and options.suppressPublish) then
		self:_publish(player, "MergeCompleted", {
			fromStickerId = stickerId,
			toStickerId = nextStickerId,
			collectionMeta = collectionMeta,
			tutorialMeta = self._tutorialService and self._tutorialService:Evaluate(player, "merge_sticker") or nil,
		})
	elseif self._tutorialService then
		self._tutorialService:Evaluate(player, "merge_sticker")
	end

	return true, nextStickerId, collectionMeta
end

function EconomyService:ApplyOfflineProgress(player)
	local playerData = self._dataService:GetData(player)
	if not playerData then
		return 0, 0
	end

	local elapsedSeconds = math.max(0, os.time() - (playerData.lastOnlineUnix or os.time()))
	local reward, cappedSeconds = self._formulaUtil.getOfflineReward(playerData, elapsedSeconds, self._configs)

	if reward > 0 then
		self:GrantCurrency(player, "hype", reward, "offline_progress", true)
	end

	self._dataService:Update(player, function(data)
		data.lastOnlineUnix = os.time()
		return true
	end)

	return reward, cappedSeconds
end

function EconomyService:ResetBoardForReprint(player, inkReward)
	local ok, stateResult = self._dataService:Update(player, function(playerData)
		playerData.inkShards += inkReward
		playerData.prestigeCount += 1
		playerData.reprintCheckpointHype = playerData.lifetimeHype
		playerData.hype = 0
		playerData.ownedStickers = {
			[self._configs.Economy.STARTER_STICKER_ID] = self._configs.Economy.STARTER_STICKER_COUNT,
		}

		for zoneId, unlocked in pairs(playerData.unlockedZones or {}) do
			local zoneConfig = self._configs.Zones[zoneId]
			if unlocked and zoneConfig and zoneConfig.rewardStickerId then
				playerData.ownedStickers[zoneConfig.rewardStickerId] =
					(playerData.ownedStickers[zoneConfig.rewardStickerId] or 0) + (zoneConfig.rewardAmount or 1)
			end
		end

		for upgradeId, _ in pairs(self._configs.Upgrades) do
			playerData.upgrades[upgradeId] = 0
		end

		playerData.settings.autoMerge = false
		playerData.settings.autoBuy = false
		playerData.zoneId = playerData.unlockedZones[playerData.zoneId] and playerData.zoneId or self._configs.Economy.STARTER_ZONE_ID
		playerData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or stateResult ~= true then
		return false, stateResult
	end

	local collectionOk, collectionMeta = self._collectionService:SyncBook(player, "reprint")
	if not collectionOk then
		return false, collectionMeta
	end

	return true, collectionMeta
end

function EconomyService:_runAutoMerge(player)
	local playerData = self._dataService:GetData(player)
	if not playerData or not playerData.settings.autoMerge then
		return {
			count = 0,
			lastStickerId = nil,
		}
	end

	if not self._formulaUtil.isSettingUnlocked("autoMerge", playerData, self._configs) then
		return {
			count = 0,
			lastStickerId = nil,
		}
	end

	local orderedStickerIds = self._formulaUtil.getOrderedConfigIds(self._configs.Stickers)
	local mergesPerformed = 0
	local lastStickerId = nil

	for _, stickerId in ipairs(orderedStickerIds) do
		while mergesPerformed < self._configs.Economy.AUTO_MERGE_MAX_ACTIONS_PER_TICK do
			local canMerge = self._formulaUtil.canMergeSticker(self._dataService:GetData(player), stickerId, self._configs)
			if not canMerge then
				break
			end

			local ok, nextStickerId = self:HandleMerge(player, stickerId, {
				suppressPublish = true,
				source = "auto_merge",
			})
			if not ok then
				break
			end

			mergesPerformed += 1
			lastStickerId = nextStickerId
		end

		if mergesPerformed >= self._configs.Economy.AUTO_MERGE_MAX_ACTIONS_PER_TICK then
			break
		end
	end

	return {
		count = mergesPerformed,
		lastStickerId = lastStickerId,
	}
end

function EconomyService:_runAutoBuy(player)
	local playerData = self._dataService:GetData(player)
	if not playerData or not playerData.settings.autoBuy or not self._upgradeService then
		return {
			count = 0,
			purchasedUpgradeIds = {},
		}
	end

	if not self._formulaUtil.isSettingUnlocked("autoBuy", playerData, self._configs) then
		return {
			count = 0,
			purchasedUpgradeIds = {},
		}
	end

	local orderedUpgrades = AutomationUtil.getOrderedUpgrades(self._configs, "standard")
	local purchasedUpgradeIds = {}
	local purchaseCount = 0
	local canContinue = true

	while canContinue and purchaseCount < self._configs.Economy.AUTO_BUY_MAX_PURCHASES_PER_TICK do
		canContinue = false
		local currentData = self._dataService:GetData(player)

		for _, entry in ipairs(orderedUpgrades) do
			local currentLevel = currentData.upgrades[entry.id] or 0
			if currentLevel < entry.config.maxLevel then
				local cost = self._formulaUtil.getUpgradeCost(entry.config, currentLevel)
				if (currentData[entry.config.currency] or 0) >= cost then
					local ok = self._upgradeService:PurchaseUpgrade(player, entry.id, {
						suppressPublish = true,
						source = "auto_buy",
					})
					if ok then
						purchaseCount += 1
						table.insert(purchasedUpgradeIds, entry.id)
						canContinue = true
						break
					end
				end
			end
		end
	end

	return {
		count = purchaseCount,
		purchasedUpgradeIds = purchasedUpgradeIds,
	}
end

function EconomyService:Start()
	if self._heartbeatConnection then
		return
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self._tickAccumulator += deltaTime

		while self._tickAccumulator >= self._configs.Economy.AUTO_PRODUCTION_TICK_SECONDS do
			self._tickAccumulator -= self._configs.Economy.AUTO_PRODUCTION_TICK_SECONDS
			self:RunPassiveProductionTick(self._configs.Economy.AUTO_PRODUCTION_TICK_SECONDS)
		end
	end)
end

function EconomyService:RunPassiveProductionTick(tickSeconds)
	for _, player in ipairs(self._dataService:GetLoadedPlayers()) do
		local playerData = self._dataService:GetData(player)
		if playerData then
			local income = self._formulaUtil.getTotalProductionPerSecond(playerData, self._configs) * tickSeconds
			local roundedIncome = normalizePositiveInteger(income)

			if roundedIncome > 0 then
				self:GrantCurrency(player, "hype", roundedIncome, "passive_tick", true)
			end

			local autoMergeMeta = self:_runAutoMerge(player)
			local autoBuyMeta = self:_runAutoBuy(player)

			if roundedIncome > 0 or autoMergeMeta.count > 0 or autoBuyMeta.count > 0 then
				self:_publish(player, "ProductionTick", {
					amount = roundedIncome,
					autoMerged = autoMergeMeta.count,
					autoBought = autoBuyMeta.count,
					autoBoughtUpgradeIds = autoBuyMeta.purchasedUpgradeIds,
				})
			end
		end
	end
end

return EconomyService
