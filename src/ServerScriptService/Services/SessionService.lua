local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local SessionService = {
	_dataService = nil,
	_economyService = nil,
	_questService = nil,
	_collectionService = nil,
	_publishState = nil,
	_configs = nil,
	_analyticsService = nil,
	_sessions = {},
	_connections = {},
}

function SessionService:Init(dependencies)
	self._dataService = dependencies.DataService
	self._economyService = dependencies.EconomyService
	self._questService = dependencies.QuestService
	self._collectionService = dependencies.CollectionService
	self._publishState = dependencies.PublishState
	self._configs = dependencies.Configs
	self._analyticsService = dependencies.AnalyticsService
end

function SessionService:_ensureSession(player)
	if not self._sessions[player] then
		self._sessions[player] = {
			joinedAt = os.time(),
			requestTimestamps = {},
			notifications = {},
			notificationCounter = 0,
			milestones = {},
		}
	end

	return self._sessions[player]
end

function SessionService:TrackMilestone(player, milestoneName, payload)
	local session = self:_ensureSession(player)
	if session.milestones[milestoneName] then
		return
	end

	local elapsedSeconds = os.time() - session.joinedAt
	session.milestones[milestoneName] = elapsedSeconds

	local analyticsPayload = payload or {}
	analyticsPayload.elapsedSeconds = elapsedSeconds
	self._analyticsService:Track(player, milestoneName, analyticsPayload)
end

function SessionService:QueueNotification(player, notification)
	local session = self:_ensureSession(player)
	session.notificationCounter += 1

	local entry = {
		id = string.format("%d_%d", player.UserId, session.notificationCounter),
		kind = type(notification) == "table" and notification.kind or "info",
		title = type(notification) == "table" and notification.title or "Board Update",
		message = type(notification) == "table" and notification.message or tostring(notification),
		createdAt = os.time(),
	}

	table.insert(session.notifications, entry)

	while #session.notifications > 8 do
		table.remove(session.notifications, 1)
	end

	return entry
end

function SessionService:GetRuntimeState(player)
	local session = self:_ensureSession(player)

	return {
		notifications = TableUtil.deepCopy(session.notifications),
	}
end

function SessionService:CanProcess(player, requestKey, cooldownSeconds)
	if not self._dataService:IsLoaded(player) then
		return false, "Player data is still loading."
	end

	local session = self:_ensureSession(player)
	local now = os.clock()
	local lastRequestAt = session.requestTimestamps[requestKey] or 0

	if now - lastRequestAt < cooldownSeconds then
		return false, "Action is cooling down."
	end

	session.requestTimestamps[requestKey] = now
	return true
end

function SessionService:LoadPlayer(player)
	if self._dataService:IsLoaded(player) then
		return true
	end

	self._dataService:LoadPlayer(player)
	local session = self:_ensureSession(player)
	session.joinedAt = os.time()

	local dailyRefreshed = self._questService:RefreshDailyBoard(player)
	if dailyRefreshed then
		self:QueueNotification(player, {
			kind = "daily",
			title = "Fresh Dailies",
			message = "Three fresh daily objectives are ready.",
		})
	end

	self._collectionService:SyncBook(player, "load")

	local offlineReward, cappedSeconds = self._economyService:ApplyOfflineProgress(player)
	if offlineReward > 0 then
		self:QueueNotification(player, {
			kind = "offline",
			title = "Offline Earnings",
			message = string.format("You earned %d Hype while away (%d minutes).", offlineReward, math.floor(cappedSeconds / 60)),
		})
	end

	self._analyticsService:Track(player, "session_started", {
		day = os.time(),
	})

	return true
end

function SessionService:HandlePlayerRemoving(player)
	if self._dataService:IsLoaded(player) then
		self._dataService:Update(player, function(playerData)
			playerData.lastOnlineUnix = os.time()
			return true
		end)
		self._dataService:SavePlayer(player)
		self._dataService:ReleasePlayer(player)
	end

	local session = self._sessions[player]
	if session then
		self._analyticsService:Track(player, "session_ended", {
			elapsedSeconds = os.time() - session.joinedAt,
		})
	end

	self._sessions[player] = nil
end

function SessionService:_startAutosaveLoop()
	task.spawn(function()
		while true do
			task.wait(self._configs.Economy.AUTOSAVE_INTERVAL_SECONDS)
			self._dataService:SaveAllPlayers()
		end
	end)
end

function SessionService:Start()
	self:_startAutosaveLoop()

	self._connections.playerAdded = Players.PlayerAdded:Connect(function(player)
		self:LoadPlayer(player)
	end)

	self._connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
		self:HandlePlayerRemoving(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:LoadPlayer(player)
	end
end

function SessionService:Shutdown()
	for _, player in ipairs(Players:GetPlayers()) do
		self:HandlePlayerRemoving(player)
	end
end

return SessionService
