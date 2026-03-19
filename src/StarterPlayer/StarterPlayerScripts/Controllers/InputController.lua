local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local InputController = {}
InputController.__index = InputController

local function getZoneFolder(zoneId)
	local map = Workspace:FindFirstChild("Map")
	local zones = map and map:FindFirstChild("Zones")
	return zones and zones:FindFirstChild(zoneId) or nil
end

function InputController.new()
	return setmetatable({
		_currentZoneId = "sticker_street",
	}, InputController)
end

function InputController:_applyBoardCamera()
	local focus = getZoneFolder(self._currentZoneId) and getZoneFolder(self._currentZoneId):FindFirstChild("BoardFocus")
	local camera = Workspace.CurrentCamera
	if not focus or not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(focus.Position + Vector3.new(0, 18, 20), focus.Position)
end

function InputController:_teleportCharacterToZone(character)
	local zoneFolder = getZoneFolder(self._currentZoneId)
	local spawnLocation = zoneFolder and zoneFolder:FindFirstChild("BoardSpawn")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if spawnLocation and rootPart then
		rootPart.CFrame = CFrame.new(spawnLocation.Position + Vector3.new(0, 3, 0))
	end
end

function InputController:_configureCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false

	self:_teleportCharacterToZone(character)
	self:_applyBoardCamera()
	task.delay(0.25, function()
		self:_teleportCharacterToZone(character)
		self:_applyBoardCamera()
	end)
end

function InputController:SetZone(zoneId)
	if type(zoneId) ~= "string" or zoneId == "" then
		return
	end

	self._currentZoneId = zoneId
	local player = Players.LocalPlayer
	if player.Character then
		self:_teleportCharacterToZone(player.Character)
	end
	self:_applyBoardCamera()
	task.delay(0.1, function()
		self:_applyBoardCamera()
	end)
end

function InputController:Init(dependencies)
	self._onCollect = dependencies.OnCollect
	self._currentZoneId = dependencies.StartingZoneId or self._currentZoneId

	ContextActionService:BindAction(
		"StickerStreetCollect",
		function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				self._onCollect()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2
	)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		self:_configureCharacter(character)
	end)

	if player.Character then
		self:_configureCharacter(player.Character)
	end

	self:_applyBoardCamera()
	task.delay(1, function()
		self:_applyBoardCamera()
	end)
end

return InputController
