return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)
	local PlayerData = require(ReplicatedStorage.Shared.Types.PlayerData)

	describe("PlayerData", function()
		it("creates a new profile with alpha starter state", function()
			local profile = PlayerData.new(Configs)

			expect(profile.schemaVersion).to.equal(PlayerData.SCHEMA_VERSION)
			expect(profile.zoneId).to.equal(Configs.Economy.STARTER_ZONE_ID)
			expect(profile.unlockedZones[Configs.Economy.STARTER_ZONE_ID]).to.equal(true)
			expect(profile.ownedStickers[Configs.Economy.STARTER_STICKER_ID]).to.equal(Configs.Economy.STARTER_STICKER_COUNT)
			expect(profile.quests.first_collect.claimed).to.equal(false)
			expect(profile.upgrades.tap_power).to.equal(0)
			expect(profile.upgrades.board_expander).to.equal(0)
			expect(profile.upgrades.curator_branch).to.equal(0)
			expect(#profile.dailyBoard.quests).to.equal(Configs.Quests.DAILY_BOARD_SIZE)
			expect(profile.collectionBook.completedSets.smile_line).to.equal(nil)
			expect(profile.tutorial.currentStepId).to.equal("collect_once")
			expect(profile.tutorial.completed).to.equal(false)
		end)

		it("migrates partial v1 saves and backfills new alpha fields", function()
			local profile = PlayerData.migrate({
				hype = 120,
				lifetimeHype = 400,
				zoneId = "neon_alley",
				unlockedZones = {
					neon_alley = true,
				},
				ownedStickers = {
					neon_cat = 3,
				},
				settings = {
					reducedMotion = true,
				},
				collectionBook = {
					discovered = {
						basic_smile = true,
					},
				},
			}, Configs)

			expect(profile.hype).to.equal(120)
			expect(profile.lifetimeHype).to.equal(400)
			expect(profile.zoneId).to.equal("neon_alley")
			expect(profile.unlockedZones.sticker_street).to.equal(true)
			expect(profile.unlockedZones.neon_alley).to.equal(true)
			expect(profile.ownedStickers.neon_cat).to.equal(3)
			expect(profile.ownedStickers[Configs.Economy.STARTER_STICKER_ID]).to.equal(Configs.Economy.STARTER_STICKER_COUNT)
			expect(profile.settings.reducedMotion).to.equal(true)
			expect(profile.quests.first_upgrade.progress).to.equal(0)
			expect(profile.upgrades.offline_branch).to.equal(0)
			expect(profile.upgrades.board_expander).to.equal(0)
			expect(profile.collectionBook.discovered.basic_smile).to.equal(true)
			expect(profile.dailyBoard.resetAtUnix).to.equal(0)
			expect(profile.tutorial.completed).to.equal(true)
			expect(profile.tutorial.currentStepId).to.equal(nil)
		end)
	end)
end
