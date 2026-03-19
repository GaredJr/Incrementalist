local SettingsService = {
	_dataService = nil,
	_configs = nil,
	_formulaUtil = nil,
	_publishState = nil,
	_analyticsService = nil,
}

function SettingsService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._configs = dependencies.Configs
	self._formulaUtil = dependencies.FormulaUtil
	self._publishState = dependencies.PublishState
	self._analyticsService = dependencies.AnalyticsService
end

function SettingsService:UpdateSetting(player, settingKey, enabled)
	if type(settingKey) ~= "string" then
		return false, "Setting key must be a string."
	end

	if type(enabled) ~= "boolean" then
		return false, "Enabled must be true or false."
	end

	if self._configs.Economy.DEFAULT_SETTINGS[settingKey] == nil then
		return false, "Unknown setting."
	end

	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	if settingKey ~= "reducedMotion" and not self._formulaUtil.isSettingUnlocked(settingKey, playerData, self._configs) then
		return false, "That setting is still locked."
	end

	local ok, result = self._dataService:Update(player, function(currentData)
		currentData.settings[settingKey] = enabled
		currentData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or result ~= true then
		return false, result
	end

	self._analyticsService:Track(player, "setting_updated", {
		settingKey = settingKey,
		enabled = enabled,
	})

	if self._publishState then
		self._publishState(player, "SettingUpdated", {
			settingKey = settingKey,
			enabled = enabled,
			message = string.format("%s %s.", settingKey, enabled and "enabled" or "disabled"),
		})
	end

	return true, enabled
end

return SettingsService
