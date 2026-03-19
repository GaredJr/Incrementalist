local AutomationUtil = require(script.Parent.AutomationUtil)
local TutorialUtil = require(script.Parent.TutorialUtil)

local RecommendedActionUtil = {}

local TARGET_TYPE_TO_ACTION = {
	collectButton = "collect",
	printButton = "printSticker",
	mergeButton = "mergeSticker",
	upgradeButton = "buyUpgrade",
	questButton = "claimQuest",
	zoneButton = "unlockZone",
	reprintButton = "reprint",
}

local function buildAction(kind, title, description, actionLabel, pageId, actionType, targetType, targetId, extra)
	local payload = {
		kind = kind,
		title = title,
		description = description,
		actionLabel = actionLabel,
		pageId = pageId,
		actionType = actionType,
		targetType = targetType,
		targetId = targetId,
	}

	if type(extra) == "table" then
		for key, value in pairs(extra) do
			payload[key] = value
		end
	end

	return payload
end

local function getClaimableQuest(playerData, configs, formulaUtil)
	for _, questId in ipairs(formulaUtil.getOrderedConfigIds(configs.Quests.STARTER)) do
		local questState = playerData.quests[questId]
		local questConfig = configs.Quests.STARTER[questId]
		if questState and questConfig and questState.completed and not questState.claimed then
			return buildAction(
				"quest",
				"Claim A Quest Reward",
				string.format("%s is ready to claim.", questConfig.name),
				"Claim Reward",
				"progress",
				"claimQuest",
				"questButton",
				questId,
				{
					questId = questId,
				}
			)
		end
	end

	for _, quest in ipairs(playerData.dailyBoard and playerData.dailyBoard.quests or {}) do
		if quest.completed and not quest.claimed then
			return buildAction(
				"quest",
				"Claim A Daily Reward",
				string.format("%s is ready to claim.", quest.name),
				"Claim Reward",
				"progress",
				"claimQuest",
				"questButton",
				quest.id,
				{
					questId = quest.id,
				}
			)
		end
	end

	return nil
end

local function getAffordableZoneUnlock(playerData, configs, formulaUtil)
	for _, zoneId in ipairs(formulaUtil.getOrderedConfigIds(configs.Zones)) do
		local zoneConfig = configs.Zones[zoneId]
		local isUnlocked = playerData.unlockedZones[zoneId] == true
		local requirementMet = not zoneConfig.requiredZoneId or playerData.unlockedZones[zoneConfig.requiredZoneId] == true
		if not isUnlocked and requirementMet and (playerData.hype or 0) >= (zoneConfig.unlockCost or 0) then
			return buildAction(
				"zone",
				string.format("Unlock %s", zoneConfig.name),
				"Open the next zone to boost its sticker family and widen the run.",
				"Unlock Zone",
				"play",
				"unlockZone",
				"zoneButton",
				zoneId,
				{
					zoneId = zoneId,
				}
			)
		end
	end

	return nil
end

local function getAffordablePrint(playerData, configs, formulaUtil)
	for _, stickerId in ipairs(formulaUtil.getOrderedConfigIds(configs.Stickers)) do
		local stickerConfig = configs.Stickers[stickerId]
		if (stickerConfig.tier or 0) == 1
			and stickerConfig.printCost
			and playerData.unlockedZones[stickerConfig.zoneId] == true
			and (playerData.hype or 0) >= stickerConfig.printCost then
			return buildAction(
				"print",
				string.format("Print %s", stickerConfig.name),
				"Fresh copies are the fastest way to unlock the next merge tier.",
				"Print Sticker",
				"play",
				"printSticker",
				"printButton",
				stickerId,
				{
					stickerId = stickerId,
				}
			)
		end
	end

	return nil
end

local function getAffordableUpgrade(playerData, configs, formulaUtil)
	local standardUpgrades = AutomationUtil.getOrderedUpgrades(configs, "standard")

	for _, entry in ipairs(standardUpgrades) do
		local currentLevel = playerData.upgrades[entry.id] or 0
		if currentLevel < entry.config.maxLevel then
			local cost = formulaUtil.getUpgradeCost(entry.config, currentLevel)
			if (playerData[entry.config.currency] or 0) >= cost then
				return buildAction(
					"upgrade",
					string.format("Buy %s", entry.config.name),
					"Upgrades are the most reliable way to accelerate the whole run.",
					"Buy Upgrade",
					"play",
					"buyUpgrade",
					"upgradeButton",
					entry.id,
					{
						upgradeId = entry.id,
					}
				)
			end
		end
	end

	for _, prestigeId in ipairs(formulaUtil.getOrderedConfigIds(configs.Prestige)) do
		local prestigeConfig = configs.Prestige[prestigeId]
		if prestigeConfig.id then
			local currentLevel = playerData.upgrades[prestigeId] or 0
			if currentLevel < prestigeConfig.maxLevel then
				local cost = formulaUtil.getUpgradeCost(prestigeConfig, currentLevel)
				if (playerData[prestigeConfig.currency] or 0) >= cost then
					return buildAction(
						"upgrade",
						string.format("Buy %s", prestigeConfig.name),
						"Spend Ink on a permanent branch to speed up every future run.",
						"Buy Prestige Upgrade",
						"play",
						"buyUpgrade",
						"upgradeButton",
						prestigeId,
						{
							upgradeId = prestigeId,
						}
					)
				end
			end
		end
	end

	return nil
end

function RecommendedActionUtil.getRecommendedAction(playerData, configs, formulaUtil)
	local tutorialState = TutorialUtil.normalizeState(playerData.tutorial, configs)
	if not tutorialState.completed and tutorialState.currentStepId then
		local stepConfig = configs.Tutorial.STEPS[tutorialState.currentStepId]
		if stepConfig then
			local questAction = tutorialState.currentStepId == "claim_any_quest" and getClaimableQuest(playerData, configs, formulaUtil)
				or nil
			return buildAction(
				"tutorial",
				stepConfig.name,
				stepConfig.description,
				stepConfig.actionLabel,
				stepConfig.pageId,
				questAction and questAction.actionType or stepConfig.actionType or TARGET_TYPE_TO_ACTION[stepConfig.targetType],
				stepConfig.targetType,
				questAction and questAction.targetId or stepConfig.targetId,
				{
					stepId = tutorialState.currentStepId,
					questId = questAction and questAction.questId or nil,
				}
			)
		end
	end

	local claimableQuest = getClaimableQuest(playerData, configs, formulaUtil)
	if claimableQuest then
		return claimableQuest
	end

	local affordableZone = getAffordableZoneUnlock(playerData, configs, formulaUtil)
	if affordableZone then
		return affordableZone
	end

	local affordablePrint = getAffordablePrint(playerData, configs, formulaUtil)
	if affordablePrint then
		return affordablePrint
	end

	local affordableUpgrade = getAffordableUpgrade(playerData, configs, formulaUtil)
	if affordableUpgrade then
		return affordableUpgrade
	end

	if formulaUtil.getPrestigeReward(formulaUtil.getRunLifetimeHype(playerData), configs) > 0 then
		return buildAction(
			"reprint",
			"Reprint For Permanent Ink",
			"The current run is worth permanent Ink Shards now.",
			"Reprint Board",
			"play",
			"reprint",
			"reprintButton",
			nil,
			nil
		)
	end

	return nil
end

return RecommendedActionUtil
