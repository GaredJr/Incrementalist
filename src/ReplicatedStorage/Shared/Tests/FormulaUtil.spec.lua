return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)
	local FormulaUtil = require(ReplicatedStorage.Shared.Util.FormulaUtil)

	describe("FormulaUtil", function()
		it("increases manual reward when tap upgrades and collection bonuses are active", function()
			local playerData = {
				upgrades = {
					tap_power = 2,
					speed_branch = 0,
					curator_branch = 0,
				},
				collectionBook = {
					completedSets = {
						arcade_line = true,
					},
				},
				ownedStickers = {
					basic_smile = 1,
				},
			}

			expect(FormulaUtil.getManualCollectReward(playerData, Configs)).to.equal(4)
		end)

		it("applies the active zone multiplier to matching sticker families", function()
			local playerData = {
				upgrades = {
					sticker_printer = 0,
					speed_branch = 0,
					rarity_branch = 0,
					merge_mastery = 0,
					board_expander = 0,
					curator_branch = 0,
				},
				collectionBook = {
					completedSets = {},
				},
				ownedStickers = {
					soda_slime = 1,
				},
				zoneId = "sticker_street",
			}

			local starterProduction = FormulaUtil.getStickerProductionPerSecond("soda_slime", 1, playerData, Configs)
			playerData.zoneId = "neon_alley"
			local alleyProduction = FormulaUtil.getStickerProductionPerSecond("soda_slime", 1, playerData, Configs)

			expect(alleyProduction).to.be.greaterThan(starterProduction)
		end)

		it("caps offline reward using the configured offline limit", function()
			local playerData = {
				upgrades = {
					tap_power = 0,
					sticker_printer = 0,
					auto_collector = 1,
					speed_branch = 0,
					rarity_branch = 0,
					offline_branch = 0,
					merge_mastery = 0,
					board_expander = 0,
					curator_branch = 0,
				},
				collectionBook = {
					completedSets = {},
				},
				ownedStickers = {
					basic_smile = 1,
				},
				zoneId = "sticker_street",
			}

			local reward, cappedSeconds = FormulaUtil.getOfflineReward(playerData, 999999, Configs)
			expect(cappedSeconds).to.equal(Configs.Economy.OFFLINE_CAP_SECONDS)
			expect(reward).to.be.ok()
		end)

		it("requires at least two stickers before allowing a merge", function()
			local playerData = {
				upgrades = {},
				ownedStickers = {
					basic_smile = 1,
				},
			}

			expect(FormulaUtil.canMergeSticker(playerData, "basic_smile", Configs)).to.equal(false)

			playerData.ownedStickers.basic_smile = 2
			expect(FormulaUtil.canMergeSticker(playerData, "basic_smile", Configs)).to.equal(true)
		end)
	end)
end
