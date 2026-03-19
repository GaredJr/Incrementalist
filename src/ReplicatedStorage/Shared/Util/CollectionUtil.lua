local CollectionUtil = {}

local function deepCopy(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}
	for key, value in pairs(source) do
		copy[key] = deepCopy(value)
	end
	return copy
end

function CollectionUtil.createBook()
	return {
		discovered = {},
		completedSets = {},
	}
end

function CollectionUtil.synchronizeBook(book, ownedStickers, collections)
	local updatedBook = deepCopy(book or CollectionUtil.createBook())
	updatedBook.discovered = updatedBook.discovered or {}
	updatedBook.completedSets = updatedBook.completedSets or {}

	local newlyDiscovered = {}
	local newlyCompleted = {}

	for stickerId, amountOwned in pairs(ownedStickers or {}) do
		if (amountOwned or 0) > 0 and not updatedBook.discovered[stickerId] then
			updatedBook.discovered[stickerId] = true
			table.insert(newlyDiscovered, stickerId)
		end
	end

	for collectionId, collectionConfig in pairs(collections or {}) do
		if not updatedBook.completedSets[collectionId] then
			local isComplete = true
			for _, stickerId in ipairs(collectionConfig.stickerIds or {}) do
				if not updatedBook.discovered[stickerId] then
					isComplete = false
					break
				end
			end

			if isComplete then
				updatedBook.completedSets[collectionId] = true
				table.insert(newlyCompleted, collectionId)
			end
		end
	end

	table.sort(newlyDiscovered)
	table.sort(newlyCompleted)

	return updatedBook, newlyDiscovered, newlyCompleted
end

function CollectionUtil.getCompletedCount(book)
	local count = 0
	for _, completed in pairs(book and book.completedSets or {}) do
		if completed then
			count += 1
		end
	end
	return count
end

return CollectionUtil
