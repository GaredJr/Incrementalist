local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = require(ReplicatedStorage.Shared.Config.ConfigBundle)
local FormulaUtil = require(ReplicatedStorage.Shared.Util.FormulaUtil)
local PayloadTypes = require(ReplicatedStorage.Shared.Types.PayloadTypes)

local UIController = require(script.Parent.Controllers.UIController)
local InputController = require(script.Parent.Controllers.InputController)
local FXController = require(script.Parent.Controllers.FXController)

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local remotes = {
	RequestCollect = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestCollect),
	RequestPrintSticker = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestPrintSticker),
	RequestBuyUpgrade = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestBuyUpgrade),
	RequestMergeSticker = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestMergeSticker),
	RequestReprint = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestReprint),
	RequestClaimQuest = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestClaimQuest),
	RequestUnlockZone = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestUnlockZone),
	RequestSelectZone = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestSelectZone),
	RequestUpdateSetting = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.RequestUpdateSetting),
	TrackClientEvent = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.TrackClientEvent),
	GetInitialState = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.GetInitialState),
	StateUpdated = remotesFolder:WaitForChild(PayloadTypes.RemoteNames.StateUpdated),
}

local function trackClientEvent(eventName, context, message)
	remotes.TrackClientEvent:FireServer({
		eventName = eventName,
		context = context,
		message = message,
	})
end

local function createEmergencyShell(playerGui, message)
	local existing = playerGui:FindFirstChild("EmergencyGameUI")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EmergencyGameUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundColor3 = Color3.fromRGB(255, 251, 241)
	root.BorderSizePixel = 0
	root.Parent = screenGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.8, 0, 0, 100)
	label.Position = UDim2.new(0.1, 0, 0.4, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(73, 52, 36)
	label.Parent = root
end

local uiController = UIController.new({
	Configs = Configs,
	FormulaUtil = FormulaUtil,
	Actions = {
		OnCollect = function()
			remotes.RequestCollect:FireServer()
		end,
		OnBuyUpgrade = function(upgradeId)
			remotes.RequestBuyUpgrade:FireServer({
				upgradeId = upgradeId,
			})
		end,
		OnPrintSticker = function(stickerId)
			remotes.RequestPrintSticker:FireServer({
				stickerId = stickerId,
			})
		end,
		OnMergeSticker = function(stickerId)
			remotes.RequestMergeSticker:FireServer({
				stickerId = stickerId,
			})
		end,
		OnReprint = function()
			remotes.RequestReprint:FireServer()
		end,
		OnClaimQuest = function(questId)
			remotes.RequestClaimQuest:FireServer({
				questId = questId,
			})
		end,
		OnUnlockZone = function(zoneId)
			remotes.RequestUnlockZone:FireServer({
				zoneId = zoneId,
			})
		end,
		OnSelectZone = function(zoneId)
			remotes.RequestSelectZone:FireServer({
				zoneId = zoneId,
			})
		end,
		OnUpdateSetting = function(settingKey, enabled)
			remotes.RequestUpdateSetting:FireServer({
				settingKey = settingKey,
				enabled = enabled,
			})
		end,
		OnRetry = function()
			-- Replaced below after the loader function is defined.
		end,
	},
})

local playerGui = player:WaitForChild("PlayerGui")
local mountOk, mountErr = pcall(function()
	uiController:Mount(playerGui)
end)

if not mountOk then
	local errorMessage = "UI mount failed. Check StarterGui/Rojo sync.\n" .. tostring(mountErr)
	warn("[Main.client] Failed to mount UI:", mountErr)
	createEmergencyShell(playerGui, errorMessage)
	trackClientEvent("client_error_shown", "mount_failed", tostring(mountErr))
	return
end

trackClientEvent("ui_shell_visible", "mount_complete")

local fxController = FXController.new()
fxController:Bind(uiController:GetRefs())

local inputController = InputController.new()
inputController:Init({
	OnCollect = function()
		remotes.RequestCollect:FireServer()
	end,
	StartingZoneId = Configs.Economy.STARTER_ZONE_ID,
})

local hasTrackedInitialState = false

local function applyState(payload)
	local ok, err = pcall(function()
		if payload.ok then
			uiController:Render(payload.state, payload.meta, payload.reason)
			if payload.state.zones and payload.state.zones.currentZoneId then
				inputController:SetZone(payload.state.zones.currentZoneId)
			end
			fxController:SetReducedMotion(payload.state.data.settings.reducedMotion == true)
			fxController:Play(payload.reason, payload.meta)
		else
			uiController:HandleError(payload.message, payload.state)
		end
	end)

	if not ok then
		warn("[Main.client] Failed to apply state:", err)
		uiController:ShowError("Client error: " .. tostring(err))
		trackClientEvent("client_error_shown", "apply_state_failed", tostring(err))
	end
end

local function requestInitialState()
	uiController:ShowLoading("The authored shell is ready. Requesting game state...")

	local ok, initialState = pcall(function()
		return remotes.GetInitialState:InvokeServer()
	end)

	if not ok then
		local message = "Initial state request failed. Try again."
		warn("[Main.client] Failed to request initial state:", initialState)
		uiController:ShowError(message)
		trackClientEvent("client_error_shown", "initial_state_request", tostring(initialState))
		return
	end

	if not initialState then
		uiController:ShowError("Initial state was empty. Try again.")
		trackClientEvent("client_error_shown", "initial_state_empty", "nil payload")
		return
	end

	applyState(initialState)

	if initialState.ok and not hasTrackedInitialState then
		hasTrackedInitialState = true
		trackClientEvent("initial_state_loaded", "initial_load")
	elseif not initialState.ok then
		uiController:ShowError(initialState.message or "State failed to load.")
		trackClientEvent("client_error_shown", "initial_state_rejected", initialState.message or "unknown")
	end
end

uiController:SetRetryHandler(requestInitialState)
requestInitialState()

remotes.StateUpdated.OnClientEvent:Connect(function(payload)
	applyState(payload)
end)
