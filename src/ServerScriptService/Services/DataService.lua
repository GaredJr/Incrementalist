local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigBundle = require(ReplicatedStorage.Shared.Config.ConfigBundle)
local PlayerData = require(ReplicatedStorage.Shared.Types.PlayerData)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local DataService = {
	_profiles = {},
	_store = nil,
	_schemaContext = ConfigBundle,
}

function DataService:Init()
	local success, store = pcall(function()
		return DataStoreService:GetDataStore(self._schemaContext.Economy.DATASTORE_NAME)
	end)

	if success then
		self._store = store
	else
		warn("[DataService] Failed to initialize DataStore:", store)
	end
end

function DataService:_getKey(player)
	return string.format("player_%d", player.UserId)
end

function DataService:IsLoaded(player)
	return self._profiles[player] ~= nil
end

function DataService:GetData(player)
	local profile = self._profiles[player]
	return profile and profile.data or nil
end

function DataService:GetSnapshot(player)
	local data = self:GetData(player)
	if not data then
		return nil
	end

	return TableUtil.deepCopy(data)
end

function DataService:GetLoadedPlayers()
	local players = {}

	for player, _ in pairs(self._profiles) do
		table.insert(players, player)
	end

	return players
end

function DataService:LoadPlayer(player)
	if self._profiles[player] then
		return true, self._profiles[player].data
	end

	local storedData
	if self._store then
		local success, result = pcall(function()
			return self._store:GetAsync(self:_getKey(player))
		end)

		if success then
			storedData = result
		else
			warn(string.format("[DataService] Failed to load data for %s: %s", player.Name, tostring(result)))
		end
	end

	local migratedData = PlayerData.migrate(storedData, self._schemaContext)
	self._profiles[player] = {
		key = self:_getKey(player),
		data = migratedData,
		dirty = false,
	}

	return true, migratedData
end

function DataService:Update(player, mutator)
	local profile = self._profiles[player]
	if not profile then
		return false, "Profile not loaded."
	end

	local ok, resultA, resultB, resultC = pcall(mutator, profile.data)
	if not ok then
		warn(string.format("[DataService] Mutation failed for %s: %s", player.Name, tostring(resultA)))
		return false, resultA
	end

	if resultA == false then
		return false, resultB or "Mutation rejected."
	end

	profile.dirty = true
	return true, resultA, resultB, resultC
end

function DataService:MarkDirty(player)
	local profile = self._profiles[player]
	if profile then
		profile.dirty = true
	end
end

function DataService:SavePlayer(player)
	local profile = self._profiles[player]
	if not profile then
		return false, "Profile not loaded."
	end

	if not self._store or not profile.dirty then
		return true
	end

	local payload = TableUtil.deepCopy(profile.data)
	local success, err = pcall(function()
		self._store:SetAsync(profile.key, payload)
	end)

	if not success then
		warn(string.format("[DataService] Failed to save data for %s: %s", player.Name, tostring(err)))
		return false, err
	end

	profile.dirty = false
	return true
end

function DataService:ReleasePlayer(player)
	self._profiles[player] = nil
end

function DataService:SaveAllPlayers()
	for _, player in ipairs(self:GetLoadedPlayers()) do
		self:SavePlayer(player)
	end
end

return DataService
