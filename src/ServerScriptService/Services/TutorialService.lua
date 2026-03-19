local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialUtil = require(ReplicatedStorage.Shared.Util.TutorialUtil)

local TutorialService = {
	_dataService = nil,
	_configs = nil,
	_analyticsService = nil,
	_sessionService = nil,
}

function TutorialService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._configs = dependencies.Configs
	self._analyticsService = dependencies.AnalyticsService
	self._sessionService = dependencies.SessionService
end

function TutorialService:Evaluate(player, source)
	local ok, result, completedStepIds, updatedState = self._dataService:Update(player, function(currentData)
		local nextState, newlyCompleted = TutorialUtil.advanceFromState(currentData.tutorial, currentData, self._configs)
		if #newlyCompleted == 0 then
			return false, "No tutorial progress."
		end

		currentData.tutorial = nextState
		currentData.lastOnlineUnix = os.time()
		return true, newlyCompleted, nextState
	end)

	if not ok then
		if result == "No tutorial progress." then
			return nil
		end

		return nil, result
	end

	for _, stepId in ipairs(completedStepIds or {}) do
		self._analyticsService:Track(player, "tutorial_step_completed", {
			stepId = stepId,
			source = source or "unknown",
		})
	end

	if self._sessionService and completedStepIds and #completedStepIds > 0 then
		local lastStepId = completedStepIds[#completedStepIds]
		local lastStepConfig = self._configs.Tutorial.STEPS[lastStepId]
		local nextStepConfig = updatedState.currentStepId and self._configs.Tutorial.STEPS[updatedState.currentStepId] or nil

		self._sessionService:QueueNotification(player, {
			kind = "tutorial",
			title = updatedState.completed and "Tutorial Complete" or "Tutorial Step Complete",
			message = updatedState.completed
					and "The guided intro is done. Push toward your first Reprint now."
				or string.format(
					"%s complete. Next: %s.",
					lastStepConfig and lastStepConfig.name or lastStepId,
					nextStepConfig and nextStepConfig.name or "Free play"
				),
		})
	end

	return {
		completedStepIds = completedStepIds or {},
		currentStepId = updatedState and updatedState.currentStepId or nil,
		completed = updatedState and updatedState.completed or false,
	}
end

return TutorialService
