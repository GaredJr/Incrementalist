local TweenService = game:GetService("TweenService")

local FXController = {}
FXController.__index = FXController

local function ensureScale(instance)
	local scale = instance:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = instance
	end
	return scale
end

function FXController.new()
	return setmetatable({
		_reducedMotion = false,
	}, FXController)
end

function FXController:Bind(references)
	self._refs = references
end

function FXController:SetReducedMotion(enabled)
	self._reducedMotion = enabled == true
end

function FXController:_pulse(instance)
	if not instance or self._reducedMotion then
		return
	end

	local scale = ensureScale(instance)
	scale.Scale = 1.05
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

function FXController:_flashLabel(label, targetColor)
	if not label then
		return
	end

	local originalColor = label.TextColor3
	label.TextColor3 = targetColor
	if self._reducedMotion then
		task.delay(0.1, function()
			if label and label.Parent then
				label.TextColor3 = originalColor
			end
		end)
		return
	end

	TweenService:Create(label, TweenInfo.new(0.25), {
		TextColor3 = originalColor,
	}):Play()
end

function FXController:Play(reason, meta)
	if not self._refs then
		return
	end

	if reason == "Collected" then
		self:_pulse(self._refs.collectButton)
		self:_flashLabel(self._refs.hypeValue, Color3.fromRGB(255, 255, 255))
	elseif reason == "StickerPrinted" and meta and meta.stickerId then
		self:_pulse(self._refs.printButtons[meta.stickerId])
		self:_flashLabel(self._refs.hypeValue, Color3.fromRGB(255, 255, 255))
	elseif reason == "UpgradePurchased" and meta and meta.upgradeId then
		self:_pulse(self._refs.upgradeButtons[meta.upgradeId])
		self:_flashLabel(self._refs.rateValue, Color3.fromRGB(255, 255, 255))
	elseif reason == "MergeCompleted" and meta and meta.fromStickerId then
		self:_pulse(self._refs.stickerButtons[meta.fromStickerId])
	elseif reason == "QuestClaimed" and meta and meta.questId then
		self:_pulse(self._refs.questButtons[meta.questId])
	elseif (reason == "ZoneUnlocked" or reason == "ZoneSelected") and meta and meta.zoneId then
		self:_pulse(self._refs.zoneButtons[meta.zoneId])
	elseif reason == "SettingUpdated" and meta and meta.settingKey then
		self:_pulse(self._refs.settingButtons[meta.settingKey])
	elseif reason == "ReprintCompleted" then
		self:_pulse(self._refs.reprintButton)
		self:_flashLabel(self._refs.inkValue, Color3.fromRGB(255, 255, 255))
	end
end

return FXController
