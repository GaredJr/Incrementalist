local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionUtil = require(ReplicatedStorage.Shared.Util.CollectionUtil)

local CollectionService = {
	_dataService = nil,
	_configs = nil,
	_analyticsService = nil,
	_sessionService = nil,
}

function CollectionService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._configs = dependencies.Configs
	self._analyticsService = dependencies.AnalyticsService
	self._sessionService = dependencies.SessionService
end

function CollectionService:SyncBook(player, source)
	local playerData = self._dataService:GetData(player)
	if not playerData then
		return false, "Profile not loaded."
	end

	local updatedBook, newlyDiscovered, newlyCompleted =
		CollectionUtil.synchronizeBook(playerData.collectionBook, playerData.ownedStickers, self._configs.Collections)

	if #newlyDiscovered == 0 and #newlyCompleted == 0 then
		return true, {
			newlyDiscovered = {},
			newlyCompleted = {},
		}
	end

	local ok, result = self._dataService:Update(player, function(currentData)
		currentData.collectionBook = updatedBook
		currentData.lastOnlineUnix = os.time()
		return true
	end)

	if not ok or result ~= true then
		return false, result
	end

	for _, collectionId in ipairs(newlyCompleted) do
		self._analyticsService:Track(player, "collection_completed", {
			collectionId = collectionId,
			source = source or "unknown",
		})

		if self._sessionService and self._configs.Collections[collectionId] then
			self._sessionService:QueueNotification(player, {
				kind = "collection",
				title = "Collection Complete",
				message = string.format("%s bonus is now active.", self._configs.Collections[collectionId].name),
			})
		end
	end

	return true, {
		newlyDiscovered = newlyDiscovered,
		newlyCompleted = newlyCompleted,
	}
end

return CollectionService
