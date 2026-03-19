return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local AutomationUtil = require(ReplicatedStorage.Shared.Util.AutomationUtil)
	local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)

	describe("AutomationUtil", function()
		it("locks automation settings behind their configured upgrades", function()
			local playerData = {
				upgrades = {
					auto_merge_unlock = 0,
					board_expander = 0,
				},
			}

			expect(AutomationUtil.isSettingUnlocked("autoMerge", playerData, Configs)).to.equal(false)
			expect(AutomationUtil.isSettingUnlocked("autoBuy", playerData, Configs)).to.equal(false)

			playerData.upgrades.auto_merge_unlock = 1
			playerData.upgrades.board_expander = 2
			expect(AutomationUtil.isSettingUnlocked("autoMerge", playerData, Configs)).to.equal(true)
			expect(AutomationUtil.isSettingUnlocked("autoBuy", playerData, Configs)).to.equal(true)
		end)

		it("orders standard upgrades by configured auto-buy priority", function()
			local orderedUpgrades = AutomationUtil.getOrderedUpgrades(Configs, "standard")
			expect(orderedUpgrades[1].id).to.equal("tap_power")
			expect(orderedUpgrades[#orderedUpgrades].id).to.equal("auto_merge_unlock")
		end)
	end)
end
