return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)

	describe("StickerConfig", function()
		it("lets each base family print new copies for merge progression", function()
			expect(Configs.Stickers.basic_smile.printCost).to.be.ok()
			expect(Configs.Stickers.arcade_bunny.printCost).to.be.ok()
			expect(Configs.Stickers.soda_slime.printCost).to.be.ok()
		end)
	end)
end
