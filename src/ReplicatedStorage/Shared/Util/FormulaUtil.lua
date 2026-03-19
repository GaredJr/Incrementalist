local AutomationUtil = require(script.Parent.AutomationUtil)

local FormulaUtil = {}

local function rounded(number)
	return math.max(0, math.floor(number + 0.5))
end

local function getCollectionRewardScalar(playerData, configs)
	local curatorLevel = playerData.upgrades.curator_branch or 0
	return 1 + (0.2 * curatorLevel)
end

function FormulaUtil.getOrderedConfigIds(configTable)
	local ordered = {}
	for configId, config in pairs(configTable or {}) do
		if type(config) == "table" and config.id then
			table.insert(ordered, configId)
		end
	end

	table.sort(ordered, function(left, right)
		local leftOrder = configTable[left].sortOrder or 999
		local rightOrder = configTable[right].sortOrder or 999
		if leftOrder == rightOrder then
			return left < right
		end
		return leftOrder < rightOrder
	end)

	return ordered
end

function FormulaUtil.getUpgradeCost(config, currentLevel)
	local growth = config.costGrowth or 1
	local baseCost = config.baseCost or 0
	return rounded(baseCost * (growth ^ math.max(0, currentLevel)))
end

function FormulaUtil.getCollectionBonuses(playerData, configs)
	local bonuses = {
		manualCollectMultiplier = 0,
		stickerProductionMultiplier = 0,
		offlineEfficiencyBonus = 0,
	}

	local scalar = getCollectionRewardScalar(playerData, configs)
	for collectionId, completed in pairs(playerData.collectionBook and playerData.collectionBook.completedSets or {}) do
		local collectionConfig = configs.Collections[collectionId]
		if completed and collectionConfig and collectionConfig.reward then
			for rewardKey, rewardValue in pairs(collectionConfig.reward) do
				bonuses[rewardKey] = (bonuses[rewardKey] or 0) + (rewardValue * scalar)
			end
		end
	end

	return bonuses
end

function FormulaUtil.getManualCollectReward(playerData, configs)
	local tapLevel = playerData.upgrades.tap_power or 0
	local speedLevel = playerData.upgrades.speed_branch or 0
	local collectionBonuses = FormulaUtil.getCollectionBonuses(playerData, configs)
	local baseReward = configs.Economy.BASE_MANUAL_COLLECT + tapLevel
	local multiplier = 1 + (0.15 * speedLevel) + (collectionBonuses.manualCollectMultiplier or 0)
	return rounded(baseReward * multiplier)
end

function FormulaUtil.getCurrentZoneConfig(playerData, configs)
	return configs.Zones[playerData.zoneId] or configs.Zones[configs.Economy.STARTER_ZONE_ID]
end

function FormulaUtil.getCurrentZoneMultiplier(playerData, configs)
	local zoneConfig = FormulaUtil.getCurrentZoneConfig(playerData, configs)
	return zoneConfig and (zoneConfig.productionMultiplier or 1) or 1
end

function FormulaUtil.getStickerProductionPerSecond(stickerId, amountOwned, playerData, configs)
	local sticker = configs.Stickers[stickerId]
	if not sticker then
		return 0
	end

	local printerLevel = playerData.upgrades.sticker_printer or 0
	local speedLevel = playerData.upgrades.speed_branch or 0
	local rarityLevel = playerData.upgrades.rarity_branch or 0
	local mergeMasteryLevel = playerData.upgrades.merge_mastery or 0
	local boardExpanderLevel = playerData.upgrades.board_expander or 0
	local collectionBonuses = FormulaUtil.getCollectionBonuses(playerData, configs)

	local globalMultiplier = 1 + (0.22 * printerLevel) + (0.15 * speedLevel) + (0.08 * boardExpanderLevel)
	local rarityMultiplier = 1
	local mergedTierMultiplier = 1
	local zoneMultiplier = 1
	local rarityOrder = configs.Economy.RARITY_ORDER[sticker.rarity] or 1

	if rarityOrder >= 2 then
		rarityMultiplier = rarityMultiplier + (0.2 * rarityLevel)
	end

	if (sticker.tier or 1) >= 2 then
		mergedTierMultiplier = mergedTierMultiplier + (0.12 * mergeMasteryLevel)
	end

	if sticker.zoneId == playerData.zoneId then
		zoneMultiplier = FormulaUtil.getCurrentZoneMultiplier(playerData, configs)
	end

	return sticker.baseProduction
		* amountOwned
		* globalMultiplier
		* rarityMultiplier
		* mergedTierMultiplier
		* zoneMultiplier
		* (1 + (collectionBonuses.stickerProductionMultiplier or 0))
end

function FormulaUtil.getPassiveProductionPerSecond(playerData, configs)
	local total = 0

	for stickerId, amountOwned in pairs(playerData.ownedStickers) do
		total = total + FormulaUtil.getStickerProductionPerSecond(stickerId, amountOwned, playerData, configs)
	end

	return total
end

function FormulaUtil.getAutoCollectPerSecond(playerData, configs)
	local autoCollectorLevel = playerData.upgrades.auto_collector or 0
	if autoCollectorLevel <= 0 then
		return 0
	end

	return FormulaUtil.getManualCollectReward(playerData, configs) * autoCollectorLevel
end

function FormulaUtil.getTotalProductionPerSecond(playerData, configs)
	return FormulaUtil.getPassiveProductionPerSecond(playerData, configs)
		+ FormulaUtil.getAutoCollectPerSecond(playerData, configs)
end

function FormulaUtil.getOfflineCapSeconds(playerData, configs)
	local offlineLevel = playerData.upgrades.offline_branch or 0
	return configs.Economy.OFFLINE_CAP_SECONDS + (offlineLevel * 60 * 60)
end

function FormulaUtil.getOfflineReward(playerData, secondsOffline, configs)
	local cappedSeconds = math.min(secondsOffline, FormulaUtil.getOfflineCapSeconds(playerData, configs))
	local productionPerSecond = FormulaUtil.getTotalProductionPerSecond(playerData, configs)
	local bonuses = FormulaUtil.getCollectionBonuses(playerData, configs)
	local efficiency = configs.Economy.OFFLINE_EFFICIENCY + (bonuses.offlineEfficiencyBonus or 0)
	local reward = productionPerSecond * cappedSeconds * efficiency
	return rounded(reward), cappedSeconds
end

function FormulaUtil.getRunLifetimeHype(playerData)
	return math.max(0, (playerData.lifetimeHype or 0) - (playerData.reprintCheckpointHype or 0))
end

function FormulaUtil.getReprintThreshold(configs)
	return configs.Prestige.REPRINT_FORMULA.divisor
end

function FormulaUtil.getPrestigeReward(lifetimeHype, configs)
	local formula = configs.Prestige.REPRINT_FORMULA
	if lifetimeHype <= 0 then
		return 0
	end

	return math.floor((lifetimeHype / formula.divisor) ^ formula.exponent)
end

function FormulaUtil.canMergeSticker(playerData, stickerId, configs)
	local sticker = configs.Stickers[stickerId]
	if not sticker or not sticker.mergeInto then
		return false
	end

	return (playerData.ownedStickers[stickerId] or 0) >= 2
end

function FormulaUtil.getNextStickerId(stickerId, configs)
	local sticker = configs.Stickers[stickerId]
	return sticker and sticker.mergeInto or nil
end

function FormulaUtil.getNextLockedZone(playerData, configs)
	local orderedZoneIds = FormulaUtil.getOrderedConfigIds(configs.Zones)
	for _, zoneId in ipairs(orderedZoneIds) do
		if not playerData.unlockedZones[zoneId] then
			return configs.Zones[zoneId]
		end
	end
	return nil
end

function FormulaUtil.getNextZoneUnlockCost(playerData, configs)
	local nextZone = FormulaUtil.getNextLockedZone(playerData, configs)
	return nextZone and (nextZone.unlockCost or 0) or nil
end

function FormulaUtil.isSettingUnlocked(settingKey, playerData, configs)
	return AutomationUtil.isSettingUnlocked(settingKey, playerData, configs)
end

return FormulaUtil
