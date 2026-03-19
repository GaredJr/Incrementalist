return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local CollectionUtil = require(ReplicatedStorage.Shared.Util.CollectionUtil)
	local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)

	describe("CollectionUtil", function()
		it("discovers stickers and completes sets once every required sticker is seen", function()
			local book = CollectionUtil.createBook()
			local updatedBook, newlyDiscovered, newlyCompleted = CollectionUtil.synchronizeBook(book, {
				basic_smile = 1,
				neon_cat = 1,
				holo_dragon = 1,
				cosmic_ghost = 1,
			}, Configs.Collections)

			expect(updatedBook.discovered.basic_smile).to.equal(true)
			expect(#newlyDiscovered).to.equal(4)
			expect(updatedBook.completedSets.smile_line).to.equal(true)
			expect(newlyCompleted[1]).to.equal("smile_line")
		end)
	end)
end
