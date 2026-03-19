local AutomationUtil = {}

function AutomationUtil.isSettingUnlocked(settingKey, playerData, configs)
	for upgradeId, upgradeConfig in pairs(configs.Upgrades or {}) do
		local unlocks = upgradeConfig.unlocksSettings
		local unlockLevel = unlocks and unlocks[settingKey] or nil
		if unlockLevel and (playerData.upgrades[upgradeId] or 0) >= unlockLevel then
			return true
		end
	end

	return settingKey == "reducedMotion"
end

function AutomationUtil.getOrderedUpgrades(configs, upgradeType)
	local ordered = {}
	for upgradeId, upgradeConfig in pairs(configs.Upgrades or {}) do
		if not upgradeType or upgradeConfig.type == upgradeType then
			table.insert(ordered, {
				id = upgradeId,
				config = upgradeConfig,
			})
		end
	end

	table.sort(ordered, function(left, right)
		local leftPriority = left.config.autoBuyPriority or left.config.sortOrder or 999
		local rightPriority = right.config.autoBuyPriority or right.config.sortOrder or 999
		if leftPriority == rightPriority then
			return left.id < right.id
		end
		return leftPriority < rightPriority
	end)

	return ordered
end

return AutomationUtil
