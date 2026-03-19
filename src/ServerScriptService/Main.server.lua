local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)
local PayloadTypes = require(ReplicatedStorage.Shared.Types.PayloadTypes)
local SnapshotUtil = require(ReplicatedStorage.Shared.Util.SnapshotUtil)
local FormulaUtil = require(ReplicatedStorage.Shared.Util.FormulaUtil)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local AnalyticsService = require(script.Parent.Services.AnalyticsService)
local CollectionService = require(script.Parent.Services.CollectionService)
local DataService = require(script.Parent.Services.DataService)
local EconomyService = require(script.Parent.Services.EconomyService)
local PrestigeService = require(script.Parent.Services.PrestigeService)
local QuestService = require(script.Parent.Services.QuestService)
local SessionService = require(script.Parent.Services.SessionService)
local SettingsService = require(script.Parent.Services.SettingsService)
local TutorialService = require(script.Parent.Services.TutorialService)
local UpgradeService = require(script.Parent.Services.UpgradeService)
local ZoneService = require(script.Parent.Services.ZoneService)

local ZONE_FALLBACKS = {
	sticker_street = {
		floorPosition = Vector3.new(0, -3, 0),
		spawnPosition = Vector3.new(0, 1, 0),
		focusPosition = Vector3.new(0, 5, 0),
		portalPosition = Vector3.new(20, 2, -20),
		floorColor = Color3.fromRGB(244, 227, 184),
		portalColor = Color3.fromRGB(255, 153, 72),
	},
	neon_alley = {
		floorPosition = Vector3.new(64, -3, 0),
		spawnPosition = Vector3.new(64, 1, 0),
		focusPosition = Vector3.new(64, 5, 0),
		portalPosition = Vector3.new(44, 2, -20),
		floorColor = Color3.fromRGB(32, 37, 68),
		portalColor = Color3.fromRGB(61, 129, 255),
	},
}

local function ensureZoneNode(parent, name)
	local node = parent:FindFirstChild(name)
	if node then
		return node
	end

	node = Instance.new("Folder")
	node.Name = name
	node.Parent = parent
	return node
end

local function ensurePart(parent, name, className)
	local part = parent:FindFirstChild(name)
	if part and part.ClassName == className then
		return part
	end

	if part then
		part:Destroy()
	end

	part = Instance.new(className)
	part.Name = name
	part.Parent = parent
	return part
end

local function ensureWorld()
	local mapFolder = Workspace:FindFirstChild("Map")
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "Map"
		mapFolder.Parent = Workspace
	end

	local zonesFolder = mapFolder:FindFirstChild("Zones")
	if not zonesFolder then
		zonesFolder = Instance.new("Folder")
		zonesFolder.Name = "Zones"
		zonesFolder.Parent = mapFolder
	end

	for zoneId, fallback in pairs(ZONE_FALLBACKS) do
		local zoneFolder = ensureZoneNode(zonesFolder, zoneId)

		local floor = ensurePart(zoneFolder, "Floor", "Part")
		floor.Anchored = true
		floor.Size = Vector3.new(52, 1, 52)
		floor.Position = fallback.floorPosition
		floor.Color = fallback.floorColor
		floor.Material = Enum.Material.SmoothPlastic

		local spawnLocation = ensurePart(zoneFolder, "BoardSpawn", "SpawnLocation")
		spawnLocation.Anchored = true
		spawnLocation.Neutral = true
		spawnLocation.Size = Vector3.new(8, 1, 8)
		spawnLocation.Position = fallback.spawnPosition
		spawnLocation.Color = fallback.portalColor

		local boardFocus = ensurePart(zoneFolder, "BoardFocus", "Part")
		boardFocus.Size = Vector3.new(1, 1, 1)
		boardFocus.Transparency = 1
		boardFocus.Anchored = true
		boardFocus.CanCollide = false
		boardFocus.Position = fallback.focusPosition

		local portal = ensurePart(zoneFolder, "ZonePortal", "Part")
		portal.Size = Vector3.new(6, 8, 1)
		portal.Transparency = 0.3
		portal.Anchored = true
		portal.CanCollide = false
		portal.Position = fallback.portalPosition
		portal.Color = fallback.portalColor
		portal.Material = Enum.Material.Neon
	end
end

local function ensureRemote(parent, name, className)
	local remote = parent:FindFirstChild(name)
	if remote and remote.ClassName == className then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	return {
		RequestCollect = ensureRemote(folder, PayloadTypes.RemoteNames.RequestCollect, "RemoteEvent"),
		RequestPrintSticker = ensureRemote(folder, PayloadTypes.RemoteNames.RequestPrintSticker, "RemoteEvent"),
		RequestBuyUpgrade = ensureRemote(folder, PayloadTypes.RemoteNames.RequestBuyUpgrade, "RemoteEvent"),
		RequestMergeSticker = ensureRemote(folder, PayloadTypes.RemoteNames.RequestMergeSticker, "RemoteEvent"),
		RequestReprint = ensureRemote(folder, PayloadTypes.RemoteNames.RequestReprint, "RemoteEvent"),
		RequestClaimQuest = ensureRemote(folder, PayloadTypes.RemoteNames.RequestClaimQuest, "RemoteEvent"),
		RequestUnlockZone = ensureRemote(folder, PayloadTypes.RemoteNames.RequestUnlockZone, "RemoteEvent"),
		RequestSelectZone = ensureRemote(folder, PayloadTypes.RemoteNames.RequestSelectZone, "RemoteEvent"),
		RequestUpdateSetting = ensureRemote(folder, PayloadTypes.RemoteNames.RequestUpdateSetting, "RemoteEvent"),
		TrackClientEvent = ensureRemote(folder, PayloadTypes.RemoteNames.TrackClientEvent, "RemoteEvent"),
		GetInitialState = ensureRemote(folder, PayloadTypes.RemoteNames.GetInitialState, "RemoteFunction"),
		StateUpdated = ensureRemote(folder, PayloadTypes.RemoteNames.StateUpdated, "RemoteEvent"),
	}
end

ensureWorld()
local remotes = ensureRemotes()

local function buildSnapshot(player)
	local data = DataService:GetSnapshot(player)
	if not data then
		return nil
	end

	return SnapshotUtil.buildPlayerSnapshot(data, Configs, FormulaUtil, SessionService:GetRuntimeState(player))
end

local function publishState(player, reason, meta)
	local snapshot = buildSnapshot(player)
	if not snapshot then
		return
	end

	remotes.StateUpdated:FireClient(player, {
		ok = true,
		reason = reason,
		state = snapshot,
		meta = meta or {},
	})
end

local function rejectAction(player, message, meta)
	AnalyticsService:Track(player, "action_rejected", TableUtil.mergeDefaults(meta, {
		message = message,
	}))

	remotes.StateUpdated:FireClient(player, {
		ok = false,
		reason = PayloadTypes.UpdateReasons.ActionRejected,
		message = message,
		state = buildSnapshot(player),
		meta = meta or {},
	})
end

DataService:Init()
AnalyticsService:Init({})
SessionService:Init({
	DataService = DataService,
	EconomyService = EconomyService,
	QuestService = QuestService,
	CollectionService = CollectionService,
	PublishState = publishState,
	Configs = Configs,
	AnalyticsService = AnalyticsService,
})
QuestService:Init({
	DataService = DataService,
	Configs = Configs,
	AnalyticsService = AnalyticsService,
	SessionService = SessionService,
	TutorialService = TutorialService,
})
CollectionService:Init({
	DataService = DataService,
	Configs = Configs,
	AnalyticsService = AnalyticsService,
	SessionService = SessionService,
})
TutorialService:Init({
	DataService = DataService,
	Configs = Configs,
	AnalyticsService = AnalyticsService,
	SessionService = SessionService,
})
EconomyService:Init({
	DataService = DataService,
	QuestService = QuestService,
	CollectionService = CollectionService,
	TutorialService = TutorialService,
	Configs = Configs,
	FormulaUtil = FormulaUtil,
	PublishState = publishState,
})
QuestService:SetRewardCallback(function(player, reward, source)
	return EconomyService:GrantReward(player, reward, source)
end)
UpgradeService:Init({
	DataService = DataService,
	EconomyService = EconomyService,
	QuestService = QuestService,
	Configs = Configs,
	FormulaUtil = FormulaUtil,
	PublishState = publishState,
	AnalyticsService = AnalyticsService,
	TutorialService = TutorialService,
})
EconomyService:SetUpgradeService(UpgradeService)
PrestigeService:Init({
	DataService = DataService,
	EconomyService = EconomyService,
	QuestService = QuestService,
	Configs = Configs,
	FormulaUtil = FormulaUtil,
	PublishState = publishState,
	AnalyticsService = AnalyticsService,
	SessionService = SessionService,
})
ZoneService:Init({
	DataService = DataService,
	EconomyService = EconomyService,
	CollectionService = CollectionService,
	QuestService = QuestService,
	Configs = Configs,
	PublishState = publishState,
	AnalyticsService = AnalyticsService,
	SessionService = SessionService,
	TutorialService = TutorialService,
})
SettingsService:Init({
	DataService = DataService,
	Configs = Configs,
	FormulaUtil = FormulaUtil,
	PublishState = publishState,
	AnalyticsService = AnalyticsService,
})
EconomyService:Start()
SessionService:Start()

local function withRateLimit(player, requestKey, cooldownSeconds)
	local ok, err = SessionService:CanProcess(player, requestKey, cooldownSeconds)
	if not ok then
		rejectAction(player, err)
	end
	return ok
end

remotes.GetInitialState.OnServerInvoke = function(player)
	SessionService:LoadPlayer(player)
	TutorialService:Evaluate(player, "load")
	local snapshot = buildSnapshot(player)
	if not snapshot then
		return {
			ok = false,
			message = "State is not ready yet.",
		}
	end

	return {
		ok = true,
		reason = PayloadTypes.UpdateReasons.InitialState,
		state = snapshot,
		meta = {},
	}
end

remotes.RequestCollect.OnServerEvent:Connect(function(player)
	if not withRateLimit(player, "collect", Configs.Economy.COLLECT_RATE_LIMIT_SECONDS) then
		return
	end

	local ok, err = EconomyService:HandleCollect(player)
	if not ok then
		rejectAction(player, err)
	end
end)

remotes.RequestPrintSticker.OnServerEvent:Connect(function(player, payload)
	if not withRateLimit(player, "print_sticker", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local stickerId = type(payload) == "table" and payload.stickerId or nil
	local ok, err = EconomyService:HandlePrintSticker(player, stickerId)
	if not ok then
		rejectAction(player, err, {
			stickerId = stickerId,
		})
		return
	end

	SessionService:TrackMilestone(player, "first_print", {
		stickerId = stickerId,
	})
end)

remotes.RequestBuyUpgrade.OnServerEvent:Connect(function(player, payload)
	if not withRateLimit(player, "buy_upgrade", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local upgradeId = type(payload) == "table" and payload.upgradeId or nil
	local ok, result = UpgradeService:PurchaseUpgrade(player, upgradeId)
	if not ok then
		rejectAction(player, result, {
			upgradeId = upgradeId,
		})
		return
	end

	SessionService:TrackMilestone(player, "first_upgrade", {
		upgradeId = upgradeId,
	})

	if upgradeId == "auto_collector" then
		SessionService:TrackMilestone(player, "first_automation", {
			upgradeId = upgradeId,
		})
	end
end)

remotes.RequestMergeSticker.OnServerEvent:Connect(function(player, payload)
	if not withRateLimit(player, "merge_sticker", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local stickerId = type(payload) == "table" and payload.stickerId or nil
	local ok, err = EconomyService:HandleMerge(player, stickerId)
	if not ok then
		rejectAction(player, err, {
			stickerId = stickerId,
		})
		return
	end

	SessionService:TrackMilestone(player, "first_merge", {
		stickerId = stickerId,
	})
end)

remotes.RequestReprint.OnServerEvent:Connect(function(player)
	if not withRateLimit(player, "reprint", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local ok, result = PrestigeService:RequestReprint(player)
	if not ok then
		rejectAction(player, result)
		return
	end

	SessionService:TrackMilestone(player, "first_reprint", {
		inkShardsEarned = result,
	})
end)

remotes.RequestClaimQuest.OnServerEvent:Connect(function(player, payload)
	if not withRateLimit(player, "claim_quest", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local questId = type(payload) == "table" and payload.questId or nil
	local ok, result, meta = QuestService:ClaimQuest(player, questId)
	if not ok then
		rejectAction(player, result, {
			questId = questId,
		})
		return
	end

	publishState(player, "QuestClaimed", TableUtil.mergeDefaults(meta, {
		message = result,
	}))
end)

remotes.RequestUnlockZone.OnServerEvent:Connect(function(player, payload)
	if not withRateLimit(player, "unlock_zone", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local zoneId = type(payload) == "table" and payload.zoneId or nil
	local ok, result = ZoneService:UnlockZone(player, zoneId)
	if not ok then
		rejectAction(player, result, {
			zoneId = zoneId,
		})
		return
	end

	SessionService:TrackMilestone(player, "first_zone_unlock", {
		zoneId = result,
	})
end)

remotes.RequestSelectZone.OnServerEvent:Connect(function(player, payload)
	if not withRateLimit(player, "select_zone", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local zoneId = type(payload) == "table" and payload.zoneId or nil
	local ok, result = ZoneService:SelectZone(player, zoneId)
	if not ok then
		rejectAction(player, result, {
			zoneId = zoneId,
		})
	end
end)

remotes.RequestUpdateSetting.OnServerEvent:Connect(function(player, payload)
	if not withRateLimit(player, "update_setting", Configs.Economy.REQUEST_RATE_LIMIT_SECONDS) then
		return
	end

	local settingKey = type(payload) == "table" and payload.settingKey or nil
	local enabled = type(payload) == "table" and payload.enabled or nil
	local ok, result = SettingsService:UpdateSetting(player, settingKey, enabled)
	if not ok then
		rejectAction(player, result, {
			settingKey = settingKey,
		})
	end
end)

local CLIENT_ANALYTICS_EVENTS = {
	ui_shell_visible = true,
	initial_state_loaded = true,
	client_error_shown = true,
}

remotes.TrackClientEvent.OnServerEvent:Connect(function(player, payload)
	local eventName = type(payload) == "table" and payload.eventName or nil
	if type(eventName) ~= "string" or not CLIENT_ANALYTICS_EVENTS[eventName] then
		return
	end

	AnalyticsService:Track(player, eventName, {
		context = type(payload) == "table" and payload.context or nil,
		message = type(payload) == "table" and payload.message or nil,
	})
end)

game:BindToClose(function()
	SessionService:Shutdown()
end)

for _, player in ipairs(Players:GetPlayers()) do
	if DataService:IsLoaded(player) then
		publishState(player, PayloadTypes.UpdateReasons.PlayerLoaded)
	end
end
