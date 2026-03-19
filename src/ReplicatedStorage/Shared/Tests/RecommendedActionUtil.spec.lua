return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)
	local FormulaUtil = require(ReplicatedStorage.Shared.Util.FormulaUtil)
	local PlayerData = require(ReplicatedStorage.Shared.Types.PlayerData)
	local RecommendedActionUtil = require(ReplicatedStorage.Shared.Util.RecommendedActionUtil)
	local TutorialUtil = require(ReplicatedStorage.Shared.Util.TutorialUtil)

	describe("RecommendedActionUtil", function()
		it("prioritizes the tutorial flow before any other action", function()
			local playerData = PlayerData.new(Configs)
			local action = RecommendedActionUtil.getRecommendedAction(playerData, Configs, FormulaUtil)

			expect(action.kind).to.equal("tutorial")
			expect(action.targetType).to.equal("collectButton")
			expect(action.stepId).to.equal("collect_once")
		end)

		it("surfaces a claimable quest once the tutorial is complete", function()
			local playerData = PlayerData.new(Configs)
			playerData.tutorial = TutorialUtil.createCompletedState(Configs)
			playerData.quests.first_collect.progress = Configs.Quests.STARTER.first_collect.target
			playerData.quests.first_collect.completed = true

			local action = RecommendedActionUtil.getRecommendedAction(playerData, Configs, FormulaUtil)

			expect(action.kind).to.equal("quest")
			expect(action.questId).to.equal("first_collect")
		end)
	end)
end
