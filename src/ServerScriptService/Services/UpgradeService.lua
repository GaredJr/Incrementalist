local UpgradeService = {
	_dataService = nil,
	_economyService = nil,
	_questService = nil,
	_configs = nil,
	_formulaUtil = nil,
	_publishState = nil,
	_analyticsService = nil,
	_tutorialService = nil,
}

function UpgradeService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._economyService = dependencies.EconomyService
	self._questService = dependencies.QuestService
	self._configs = dependencies.Configs
	self._formulaUtil = dependencies.FormulaUtil
	self._publishState = dependencies.PublishState
	self._analyticsService = dependencies.AnalyticsService
	self._tutorialService = dependencies.TutorialService
end

function UpgradeService:_getUpgradeConfig(upgradeId)
	if self._configs.Upgrades[upgradeId] then
		return self._configs.Upgrades[upgradeId]
	end

	if self._configs.Prestige[upgradeId] and self._configs.Prestige[upgradeId].id then
		return self._configs.Prestige[upgradeId]
	end

	return nil
end

local function getUnlockRewards(upgradeConfig, oldLevel, newLevel)
	local rewards = {}
	for _, reward in ipairs(upgradeConfig.unlockRewards or {}) do
		if oldLevel < reward.level and newLevel >= reward.level then
			table.insert(rewards, reward)
		end
	end
	return rewards
end

function UpgradeService:PurchaseUpgrade(player, upgradeId, options)
	if type(upgradeId) ~= "string" then
		return false, "Upgrade id must be a string."
	end

	local upgradeConfig = self:_getUpgradeConfig(upgradeId)
	if not upgradeConfig then
		return false, "Unknown upgrade."
	end

	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	local currentLevel = playerData.upgrades[upgradeId] or 0
	if currentLevel >= upgradeConfig.maxLevel then
		return false, "Upgrade is already maxed."
	end

	local price = self._formulaUtil.getUpgradeCost(upgradeConfig, currentLevel)
	local spendOk, spendErr = self._economyService:SpendCurrency(player, upgradeConfig.currency, price)
	if not spendOk then
		return false, spendErr
	end

	local newLevel = currentLevel + 1
	local ok, stateResult = self._dataService:Update(player, function(data)
		data.upgrades[upgradeId] = newLevel
		data.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or stateResult ~= true then
		return false, stateResult
	end

	self._questService:RecordProgress(player, "buy_upgrade", 1)

	local rewardMeta = {}
	for _, reward in ipairs(getUnlockRewards(upgradeConfig, currentLevel, newLevel)) do
		local rewardOk, stickerResult = self._economyService:GrantSticker(
			player,
			reward.stickerId,
			reward.amount or 1,
			"upgrade_unlock:" .. upgradeId
		)
		if rewardOk then
			table.insert(rewardMeta, stickerResult)
		end
	end

	self._analyticsService:Track(player, "upgrade_purchased", {
		upgradeId = upgradeId,
		newLevel = newLevel,
		source = options and options.source or "manual",
	})

	local tutorialMeta = self._tutorialService and self._tutorialService:Evaluate(player, "buy_upgrade") or nil

	if not (options and options.suppressPublish) then
		local latestReward = rewardMeta[#rewardMeta]
		self._publishState(player, "UpgradePurchased", {
			upgradeId = upgradeId,
			newLevel = newLevel,
			cost = price,
			currency = upgradeConfig.currency,
			collectionMeta = latestReward and latestReward.collectionMeta or nil,
			rewardMeta = rewardMeta,
			tutorialMeta = tutorialMeta,
		})
	end

	return true, {
		upgradeId = upgradeId,
		newLevel = newLevel,
		rewardMeta = rewardMeta,
		tutorialMeta = tutorialMeta,
	}
end

return UpgradeService
