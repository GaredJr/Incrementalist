return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)
	local DailyQuestUtil = require(ReplicatedStorage.Shared.Util.DailyQuestUtil)

	describe("DailyQuestUtil", function()
		it("generates a three-slot board for the current UTC day", function()
			local playerData = {
				unlockedZones = {
					sticker_street = true,
				},
				lifetimeHype = 0,
				prestigeCount = 0,
			}

			local board = DailyQuestUtil.generateDailyBoard(playerData, Configs.Quests, Configs, 86400)
			expect(board.dayKey).to.equal(1)
			expect(board.resetAtUnix).to.equal(172800)
			expect(#board.quests).to.equal(Configs.Quests.DAILY_BOARD_SIZE)
		end)

		it("keeps advanced templates locked until the player reaches the right zone", function()
			local template = Configs.Quests.DAILY_TEMPLATES.merge_chain
			local playerData = {
				unlockedZones = {
					sticker_street = true,
				},
				lifetimeHype = 1000,
				prestigeCount = 0,
			}

			expect(DailyQuestUtil.isTemplateAvailable(template, playerData, Configs)).to.equal(false)
			playerData.unlockedZones.neon_alley = true
			expect(DailyQuestUtil.isTemplateAvailable(template, playerData, Configs)).to.equal(true)
		end)
	end)
end
