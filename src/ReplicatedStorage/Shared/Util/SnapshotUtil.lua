local SnapshotUtil = {}
local RecommendedActionUtil = require(script.Parent.RecommendedActionUtil)

function SnapshotUtil.buildPlayerSnapshot(playerData, configs, formulaUtil, runtimeState)
	local nextZone = formulaUtil.getNextLockedZone(playerData, configs)

	return {
		data = playerData,
		zones = {
			currentZoneId = playerData.zoneId,
			unlocked = playerData.unlockedZones,
			nextZoneId = nextZone and nextZone.id or nil,
			nextZoneUnlockCost = nextZone and nextZone.unlockCost or nil,
		},
		dailyBoard = playerData.dailyBoard,
		collectionBook = playerData.collectionBook,
		tutorial = playerData.tutorial,
		recommendedAction = RecommendedActionUtil.getRecommendedAction(playerData, configs, formulaUtil),
		notifications = runtimeState and runtimeState.notifications or {},
		derived = {
			manualCollectReward = formulaUtil.getManualCollectReward(playerData, configs),
			passiveProductionPerSecond = formulaUtil.getPassiveProductionPerSecond(playerData, configs),
			autoCollectPerSecond = formulaUtil.getAutoCollectPerSecond(playerData, configs),
			totalProductionPerSecond = formulaUtil.getTotalProductionPerSecond(playerData, configs),
			reprintReward = formulaUtil.getPrestigeReward(
				formulaUtil.getRunLifetimeHype(playerData),
				configs
			),
			offlineCapSeconds = formulaUtil.getOfflineCapSeconds(playerData, configs),
			currentZoneMultiplier = formulaUtil.getCurrentZoneMultiplier(playerData, configs),
			nextZoneUnlockCost = nextZone and nextZone.unlockCost or nil,
			collectionBonuses = formulaUtil.getCollectionBonuses(playerData, configs),
			runLifetimeHype = formulaUtil.getRunLifetimeHype(playerData),
			reprintThreshold = formulaUtil.getReprintThreshold(configs),
		},
	}
end

return SnapshotUtil
