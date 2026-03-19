local UIController = {}
UIController.__index = UIController

local HEADER_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamMedium

local COLORS = {
	card = Color3.fromRGB(255, 251, 241),
	cardStroke = Color3.fromRGB(236, 196, 144),
	text = Color3.fromRGB(73, 52, 36),
	textMuted = Color3.fromRGB(123, 97, 71),
	collect = Color3.fromRGB(255, 153, 72),
	upgrade = Color3.fromRGB(49, 170, 141),
	prestige = Color3.fromRGB(61, 129, 255),
	quest = Color3.fromRGB(239, 191, 58),
	error = Color3.fromRGB(211, 83, 70),
	success = Color3.fromRGB(56, 168, 102),
	muted = Color3.fromRGB(191, 178, 159),
	tab = Color3.fromRGB(255, 242, 207),
	tabActive = Color3.fromRGB(255, 222, 166),
	highlight = Color3.fromRGB(255, 214, 102),
}

local SETTING_METADATA = {
	autoMerge = {
		name = "Auto Merge",
		description = "Hands-free merges every production tick.",
		lockedText = "Unlock with Auto Merge",
	},
	autoBuy = {
		name = "Auto Buy",
		description = "Purchases standard upgrades in a fixed priority order.",
		lockedText = "Unlock with Board Expander Lv 2",
	},
	reducedMotion = {
		name = "Reduced Motion",
		description = "Keeps the board calmer during long sessions.",
		lockedText = nil,
	},
}

local PAGE_ORDER = {
	"play",
	"progress",
	"systems",
}

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function createPadding(parent, top, right, bottom, left)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.PaddingLeft = UDim.new(0, left)
	padding.Parent = parent
	return padding
end

local function createLabel(parent, height, text, font, textSize, textColor, wrapped)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Text = text
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = textColor
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = wrapped == true
	label.AutomaticSize = wrapped and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
	label.Parent = parent
	return label
end

local function createListLayout(parent, padding)
	local layout = parent:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = parent
	end

	layout.Padding = UDim.new(0, padding or 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	return layout
end

local function clearContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function setButtonEnabled(button, enabled, backgroundColor, buttonText)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = enabled and backgroundColor or COLORS.muted
	button.TextTransparency = enabled and 0 or 0.15
	button.Text = buttonText
end

local function toColor3(colorArray, fallback)
	if type(colorArray) == "table" and #colorArray >= 3 then
		return Color3.new(colorArray[1], colorArray[2], colorArray[3])
	end
	return fallback or COLORS.upgrade
end

local function formatReward(reward)
	if not reward then
		return ""
	end

	if reward.currency then
		return string.format("%d %s", reward.amount or 0, reward.currency == "inkShards" and "Ink" or "Hype")
	end

	if reward.stickerId then
		return string.format("%d %s", reward.amount or 0, reward.stickerId)
	end

	return "Reward"
end

local function formatDuration(seconds)
	local totalSeconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	return string.format("%02dh %02dm", hours, minutes)
end

local function countDiscovered(stickerIds, discoveredMap)
	local count = 0
	for _, stickerId in ipairs(stickerIds or {}) do
		if discoveredMap and discoveredMap[stickerId] then
			count += 1
		end
	end
	return count
end

function UIController.new(dependencies)
	local self = setmetatable({}, UIController)
	self._configs = dependencies.Configs
	self._formulaUtil = dependencies.FormulaUtil
	self._actions = dependencies.Actions
	self._refs = {
		upgradeButtons = {},
		stickerButtons = {},
		printButtons = {},
		questButtons = {},
		zoneButtons = {},
		settingButtons = {},
	}
	self._buttonBaseColors = {}
	self._state = nil
	self._currentPageId = "play"
	return self
end

function UIController:_registerButton(button, baseColor)
	self._buttonBaseColors[button] = baseColor
end

function UIController:_clearHighlights()
	for button, baseColor in pairs(self._buttonBaseColors) do
		if button and button.Parent then
			button.BackgroundColor3 = baseColor
		end
	end
end

function UIController:_highlightButton(button)
	if not button then
		return
	end

	local baseColor = self._buttonBaseColors[button]
	if not baseColor then
		return
	end

	button.BackgroundColor3 = COLORS.highlight
end

function UIController:_getOrderedIds(configTable)
	return self._formulaUtil.getOrderedConfigIds(configTable)
end

function UIController:_cloneTemplate(templateName, parent)
	local template = self._refs.templates:FindFirstChild(templateName)
	if not template then
		error("Missing template: " .. templateName)
	end

	local clone = template:Clone()
	clone.Name = templateName .. "Item"
	clone.Visible = true
	clone.Parent = parent
	createCorner(clone, 18)
	createStroke(clone, COLORS.cardStroke, 1)
	return clone
end

function UIController:_createSection(parent, title, description)
	local frame = Instance.new("Frame")
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.BackgroundColor3 = COLORS.card
	frame.BorderSizePixel = 0
	frame.Parent = parent
	createCorner(frame, 24)
	createStroke(frame, COLORS.cardStroke, 1.5)
	createPadding(frame, 16, 16, 16, 16)
	createListLayout(frame, 10)

	createLabel(frame, 24, title, HEADER_FONT, 22, COLORS.text, false)
	if description then
		createLabel(frame, 18, description, BODY_FONT, 14, COLORS.textMuted, true)
	end

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Size = UDim2.new(1, 0, 0, 0)
	list.Parent = frame
	createListLayout(list, 8)

	return frame, list
end

function UIController:_ensurePageLayout(page)
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 8
	page.BorderSizePixel = 0
	page.BackgroundTransparency = 1
	createListLayout(page, 12)
	createPadding(page, 0, 0, 12, 0)
end

function UIController:_resetActionRefs()
	self._refs.upgradeButtons = {}
	self._refs.stickerButtons = {}
	self._refs.printButtons = {}
	self._refs.questButtons = {}
	self._refs.zoneButtons = {}
	self._refs.settingButtons = {}
	self._buttonBaseColors = {}
	self:_registerButton(self._refs.collectButton, COLORS.collect)
end

function UIController:_setTabActive(button, active)
	button.BackgroundColor3 = active and COLORS.tabActive or COLORS.tab
	button.TextColor3 = active and COLORS.text or COLORS.textMuted
end

function UIController:_showPage(pageId)
	self._currentPageId = pageId
	self._refs.playPage.Visible = pageId == "play"
	self._refs.progressPage.Visible = pageId == "progress"
	self._refs.systemsPage.Visible = pageId == "systems"

	self:_setTabActive(self._refs.playTabButton, pageId == "play")
	self:_setTabActive(self._refs.progressTabButton, pageId == "progress")
	self:_setTabActive(self._refs.systemsTabButton, pageId == "systems")
end

function UIController:Mount(playerGui)
	local screenGui = playerGui:WaitForChild("GameUI", 5)
	if not screenGui then
		error("GameUI ScreenGui not found in PlayerGui. Check StarterGui Rojo sync.")
	end

	local root = screenGui:WaitForChild("Root")
	local mainPanel = root:WaitForChild("MainPanel")
	local content = mainPanel:WaitForChild("Content")
	local recommendationCard = mainPanel:WaitForChild("RecommendationCard")
	local tabBar = mainPanel:WaitForChild("TabBar")
	local loadingState = mainPanel:WaitForChild("LoadingState")
	local errorState = mainPanel:WaitForChild("ErrorState")

	self._screenGui = screenGui
	self._refs.mainPanel = mainPanel
	self._refs.titleLabel = mainPanel:WaitForChild("TitleLabel")
	self._refs.subtitleLabel = mainPanel:WaitForChild("SubtitleLabel")
	self._refs.hypeValue = mainPanel:WaitForChild("HypeValue")
	self._refs.inkValue = mainPanel:WaitForChild("InkValue")
	self._refs.rateValue = mainPanel:WaitForChild("RateValue")
	self._refs.collectButton = mainPanel:WaitForChild("CollectButton")
	self._refs.manualRewardLabel = mainPanel:WaitForChild("ManualRewardLabel")
	self._refs.productionLabel = mainPanel:WaitForChild("ProductionLabel")
	self._refs.statusLabel = mainPanel:WaitForChild("StatusLabel")
	self._refs.recommendationCard = recommendationCard
	self._refs.recommendationTagLabel = recommendationCard:WaitForChild("TagLabel")
	self._refs.recommendationTitleLabel = recommendationCard:WaitForChild("TitleLabel")
	self._refs.recommendationDescriptionLabel = recommendationCard:WaitForChild("DescriptionLabel")
	self._refs.recommendationButton = recommendationCard:WaitForChild("ActionButton")
	self._refs.playTabButton = tabBar:WaitForChild("PlayTabButton")
	self._refs.progressTabButton = tabBar:WaitForChild("ProgressTabButton")
	self._refs.systemsTabButton = tabBar:WaitForChild("SystemsTabButton")
	self._refs.playPage = content:WaitForChild("PlayPage")
	self._refs.progressPage = content:WaitForChild("ProgressPage")
	self._refs.systemsPage = content:WaitForChild("SystemsPage")
	self._refs.toastArea = mainPanel:WaitForChild("ToastArea")
	self._refs.loadingState = loadingState
	self._refs.loadingMessageLabel = loadingState:WaitForChild("DescriptionLabel")
	self._refs.errorState = errorState
	self._refs.errorMessageLabel = errorState:WaitForChild("DescriptionLabel")
	self._refs.retryButton = errorState:WaitForChild("RetryButton")
	self._refs.templates = mainPanel:WaitForChild("Templates")

	for _, pageId in ipairs(PAGE_ORDER) do
		self:_ensurePageLayout(self._refs[pageId .. "Page"])
	end

	createListLayout(self._refs.toastArea, 8)
	createPadding(self._refs.toastArea, 0, 0, 0, 0)

	self:_registerButton(self._refs.collectButton, COLORS.collect)
	self:_showPage(self._currentPageId)
	self:ShowLoading("The authored shell is ready. Waiting for the first server snapshot.")

	self._refs.collectButton.MouseButton1Click:Connect(function()
		self._actions.OnCollect()
	end)

	self._refs.playTabButton.MouseButton1Click:Connect(function()
		self:_showPage("play")
	end)
	self._refs.progressTabButton.MouseButton1Click:Connect(function()
		self:_showPage("progress")
	end)
	self._refs.systemsTabButton.MouseButton1Click:Connect(function()
		self:_showPage("systems")
	end)
	self._refs.recommendationButton.MouseButton1Click:Connect(function()
		self:_executeRecommendedAction()
	end)
	self._refs.retryButton.MouseButton1Click:Connect(function()
		if self._actions.OnRetry then
			self._actions.OnRetry()
		end
	end)
end

function UIController:GetRefs()
	return self._refs
end

function UIController:SetRetryHandler(handler)
	self._actions.OnRetry = handler
end

function UIController:ShowLoading(message)
	self._refs.loadingState.Visible = true
	self._refs.errorState.Visible = false
	self._refs.loadingMessageLabel.Text = message or "Loading..."
end

function UIController:ShowError(message)
	self._refs.errorState.Visible = true
	self._refs.loadingState.Visible = false
	self._refs.errorMessageLabel.Text = message or "An unexpected client error occurred."
	self:ShowStatus(message or "An unexpected client error occurred.", true)
end

function UIController:ShowStatus(message, isError)
	self._refs.statusLabel.Text = message
	self._refs.statusLabel.TextColor3 = isError and COLORS.error or COLORS.text
end

function UIController:_renderZones(page)
	local _, list = self:_createSection(page, "Zones", "Travel, unlock boosts, and keep the board moving.")

	for _, zoneId in ipairs(self:_getOrderedIds(self._configs.Zones)) do
		local zoneConfig = self._configs.Zones[zoneId]
		local unlocked = self._state.data.unlockedZones[zoneId] == true
		local isSelected = self._state.data.zoneId == zoneId
		local requiredUnlocked = not zoneConfig.requiredZoneId or self._state.data.unlockedZones[zoneConfig.requiredZoneId] == true
		local accentColor = toColor3(zoneConfig.accentColor, COLORS.prestige)
		local card = self:_cloneTemplate("ZoneCard", list)
		local button = card:WaitForChild("ActionButton")

		card.NameLabel.Text = zoneConfig.name
		card.DescriptionLabel.Text = zoneConfig.description
		card.MetaLabel.Text = string.format("Zone boost: %.2fx", zoneConfig.productionMultiplier or 1)
		self._refs.zoneButtons[zoneId] = button
		self:_registerButton(button, accentColor)

		if unlocked then
			setButtonEnabled(button, not isSelected, accentColor, isSelected and "Currently Active" or "Travel Here")
		elseif not requiredUnlocked then
			setButtonEnabled(button, false, accentColor, "Unlock previous zone first")
		else
			local canAfford = (self._state.data.hype or 0) >= (zoneConfig.unlockCost or 0)
			setButtonEnabled(button, canAfford, accentColor, string.format("Unlock for %d Hype", zoneConfig.unlockCost or 0))
		end

		button.MouseButton1Click:Connect(function()
			if unlocked then
				self._actions.OnSelectZone(zoneId)
			else
				self._actions.OnUnlockZone(zoneId)
			end
		end)
	end
end

function UIController:_renderStickers(page)
	local _, list = self:_createSection(page, "Sticker Board", "Print fresh copies, merge chains, and push each family higher.")

	for _, stickerId in ipairs(self:_getOrderedIds(self._configs.Stickers)) do
		local stickerConfig = self._configs.Stickers[stickerId]
		local amountOwned = self._state.data.ownedStickers[stickerId] or 0
		local production = self._formulaUtil.getStickerProductionPerSecond(stickerId, amountOwned, self._state.data, self._configs)
		local zoneName = self._configs.Zones[stickerConfig.zoneId] and self._configs.Zones[stickerConfig.zoneId].name or stickerConfig.zoneId
		local canPrint = (stickerConfig.tier or 0) == 1 and stickerConfig.printCost ~= nil
		local card = self:_cloneTemplate("StickerCard", list)
		local printButton = card:WaitForChild("PrintButton")
		local mergeButton = card:WaitForChild("MergeButton")

		card.NameLabel.Text = stickerConfig.name
		card.DetailLabel.Text = string.format("%s | Tier %d | Owned: %d", stickerConfig.rarity, stickerConfig.tier or 1, amountOwned)
		card.BodyLabel.Text = string.format("%s\nZone: %s | Production: %.1f Hype/sec", stickerConfig.description, zoneName, production)

		if canPrint then
			local zoneUnlocked = self._state.data.unlockedZones[stickerConfig.zoneId] == true
			local canAffordPrint = zoneUnlocked and (self._state.data.hype or 0) >= (stickerConfig.printCost or 0)
			self._refs.printButtons[stickerId] = printButton
			self:_registerButton(printButton, COLORS.upgrade)
			printButton.Visible = true
			if zoneUnlocked then
				setButtonEnabled(printButton, canAffordPrint, COLORS.upgrade, string.format("Print copy for %d Hype", stickerConfig.printCost))
			else
				setButtonEnabled(printButton, false, COLORS.upgrade, "Unlock zone to print")
			end
			printButton.MouseButton1Click:Connect(function()
				self._actions.OnPrintSticker(stickerId)
			end)
		else
			printButton.Visible = false
		end

		self._refs.stickerButtons[stickerId] = mergeButton
		self:_registerButton(mergeButton, COLORS.collect)

		if stickerConfig.mergeInto and amountOwned >= 2 then
			setButtonEnabled(mergeButton, true, COLORS.collect, "Merge into " .. self._configs.Stickers[stickerConfig.mergeInto].name)
		elseif stickerConfig.mergeInto then
			setButtonEnabled(mergeButton, false, COLORS.collect, "Need 2 copies to merge")
		else
			setButtonEnabled(mergeButton, false, COLORS.collect, "Top rarity reached")
		end

		mergeButton.MouseButton1Click:Connect(function()
			self._actions.OnMergeSticker(stickerId)
		end)
	end
end

function UIController:_renderUpgradeList(page, configTable, title, description, accentColor)
	local _, list = self:_createSection(page, title, description)

	for _, upgradeId in ipairs(self:_getOrderedIds(configTable)) do
		local upgradeConfig = configTable[upgradeId]
		local playerData = self._state.data
		local currentLevel = playerData.upgrades[upgradeId] or 0
		local cost = self._formulaUtil.getUpgradeCost(upgradeConfig, currentLevel)
		local isMaxed = currentLevel >= upgradeConfig.maxLevel
		local affordableAmount = playerData[upgradeConfig.currency] or 0
		local card = self:_cloneTemplate("UpgradeCard", list)
		local button = card:WaitForChild("ActionButton")

		card.NameLabel.Text = upgradeConfig.name
		card.DescriptionLabel.Text = upgradeConfig.description
		card.MetaLabel.Text = string.format("Level %d / %d", currentLevel, upgradeConfig.maxLevel)
		self._refs.upgradeButtons[upgradeId] = button
		self:_registerButton(button, accentColor)

		if isMaxed then
			setButtonEnabled(button, false, accentColor, "Maxed")
		else
			local buttonText = string.format("Buy for %d %s", cost, upgradeConfig.currency == "hype" and "Hype" or "Ink")
			setButtonEnabled(button, affordableAmount >= cost, accentColor, buttonText)
		end

		button.MouseButton1Click:Connect(function()
			self._actions.OnBuyUpgrade(upgradeId)
		end)
	end
end

function UIController:_renderReprint(page)
	local _, list = self:_createSection(page, "Reprint", "When the run is ready, convert it into permanent Ink.")
	local summary = createLabel(list, 18, "", BODY_FONT, 14, COLORS.textMuted, true)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = COLORS.prestige
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = HEADER_FONT
	button.TextSize = 18
	button.Parent = list
	createCorner(button, 16)
	createStroke(button, Color3.new(1, 1, 1), 1.5)
	self._refs.reprintButton = button
	self:_registerButton(button, COLORS.prestige)

	summary.Text = string.format(
		"Reprint reward: %d Ink | Run Hype: %d | Threshold: %d",
		self._state.derived.reprintReward,
		self._state.derived.runLifetimeHype,
		self._state.derived.reprintThreshold
	)

	if self._state.derived.reprintReward > 0 then
		setButtonEnabled(button, true, COLORS.prestige, "Reprint Board")
	else
		setButtonEnabled(
			button,
			false,
			COLORS.prestige,
			string.format("Reach %d run Hype to Reprint", self._state.derived.reprintThreshold)
		)
	end

	button.MouseButton1Click:Connect(function()
		self._actions.OnReprint()
	end)
end

function UIController:_renderTutorial(page)
	local _, list = self:_createSection(page, "Onboarding", "Finish the guided steps, then push toward your first Reprint.")
	local tutorial = self._state.tutorial or { completedSteps = {}, completed = false }
	local completedSteps = 0
	local totalSteps = #(self._configs.Tutorial.ORDER or {})

	for _, stepId in ipairs(self._configs.Tutorial.ORDER or {}) do
		if tutorial.completedSteps and tutorial.completedSteps[stepId] then
			completedSteps += 1
		end
	end

	local progressLabel = createLabel(
		list,
		18,
		string.format("Progress: %d / %d", completedSteps, totalSteps),
		BODY_FONT,
		14,
		COLORS.textMuted,
		false
	)
	progressLabel.LayoutOrder = 1

	local currentStep = tutorial.currentStepId and self._configs.Tutorial.STEPS[tutorial.currentStepId] or nil
	local currentDescription = tutorial.completed and "The guided intro is complete." or (currentStep and currentStep.description or "")
	local descriptionLabel = createLabel(list, 18, currentDescription, BODY_FONT, 14, COLORS.text, true)
	descriptionLabel.LayoutOrder = 2

	for index, stepId in ipairs(self._configs.Tutorial.ORDER or {}) do
		local stepConfig = self._configs.Tutorial.STEPS[stepId]
		local row = self:_cloneTemplate("ChecklistRow", list)
		local statusLabel = row:WaitForChild("StatusLabel")
		row.LayoutOrder = 2 + index
		row.StepLabel.Text = stepConfig.name

		if tutorial.completedSteps and tutorial.completedSteps[stepId] then
			statusLabel.Text = "Done"
			statusLabel.TextColor3 = COLORS.success
		elseif tutorial.currentStepId == stepId then
			statusLabel.Text = "Now"
			statusLabel.TextColor3 = COLORS.collect
		else
			statusLabel.Text = "Later"
			statusLabel.TextColor3 = COLORS.textMuted
		end
	end
end

function UIController:_renderQuestSection(page, title, description, quests, starterConfig)
	local _, list = self:_createSection(page, title, description)

	for _, quest in ipairs(quests) do
		local questConfig = starterConfig and starterConfig[quest.id] or quest
		local card = self:_cloneTemplate("QuestCard", list)
		local button = card:WaitForChild("ActionButton")
		card.NameLabel.Text = questConfig.name
		card.DescriptionLabel.Text = questConfig.description
		card.MetaLabel.Text = string.format("Progress: %d / %d", quest.progress, quest.target)
		self._refs.questButtons[quest.id] = button
		self:_registerButton(button, COLORS.quest)

		if quest.claimed then
			setButtonEnabled(button, false, COLORS.quest, "Reward Claimed")
		elseif quest.completed then
			setButtonEnabled(button, true, COLORS.quest, "Claim " .. formatReward(questConfig.reward))
		else
			setButtonEnabled(button, false, COLORS.quest, "Complete quest to claim")
		end

		button.MouseButton1Click:Connect(function()
			self._actions.OnClaimQuest(quest.id)
		end)
	end
end

function UIController:_renderCollections(page)
	local _, list = self:_createSection(page, "Collection Book", "Complete sticker lines to lock in permanent passive bonuses.")
	local discoveredMap = self._state.collectionBook and self._state.collectionBook.discovered or {}
	local completedSets = self._state.collectionBook and self._state.collectionBook.completedSets or {}

	for _, collectionId in ipairs(self:_getOrderedIds(self._configs.Collections)) do
		local collectionConfig = self._configs.Collections[collectionId]
		local progress = countDiscovered(collectionConfig.stickerIds, discoveredMap)
		local target = #(collectionConfig.stickerIds or {})
		local completed = completedSets[collectionId] == true
		local card = self:_cloneTemplate("CollectionCard", list)

		card.NameLabel.Text = collectionConfig.name
		card.DescriptionLabel.Text = collectionConfig.description
		card.MetaLabel.Text = string.format(
			"Progress: %d / %d | Reward: %s",
			progress,
			target,
			self:_describeCollectionReward(collectionConfig.reward)
		)
		card.MetaLabel.TextColor3 = completed and COLORS.success or COLORS.textMuted
	end
end

function UIController:_describeCollectionReward(reward)
	local parts = {}
	if reward.manualCollectMultiplier then
		table.insert(parts, string.format("+%d%% manual", math.floor(reward.manualCollectMultiplier * 100 + 0.5)))
	end
	if reward.stickerProductionMultiplier then
		table.insert(parts, string.format("+%d%% production", math.floor(reward.stickerProductionMultiplier * 100 + 0.5)))
	end
	if reward.offlineEfficiencyBonus then
		table.insert(parts, string.format("+%d%% offline", math.floor(reward.offlineEfficiencyBonus * 100 + 0.5)))
	end
	return #parts > 0 and table.concat(parts, ", ") or "Passive bonus"
end

function UIController:_renderMilestone(page)
	local _, list = self:_createSection(page, "Next Milestone", "Keep this goal in view while the tutorial hands off to the longer run.")
	local titleLabel = createLabel(list, 20, "", HEADER_FONT, 18, COLORS.text, false)
	local descriptionLabel = createLabel(list, 18, "", BODY_FONT, 14, COLORS.textMuted, true)
	local playerData = self._state.data

	if not self._state.tutorial.completed then
		titleLabel.Text = "Finish The Guided Intro"
		descriptionLabel.Text = "Complete the onboarding steps before the milestone card switches to your first Reprint."
	elseif (playerData.prestigeCount or 0) <= 0 then
		local remaining = math.max(0, self._state.derived.reprintThreshold - self._state.derived.runLifetimeHype)
		titleLabel.Text = "First Reprint"
		if self._state.derived.reprintReward > 0 then
			descriptionLabel.Text = string.format(
				"Your current run is ready. Reprinting now will earn %d Ink Shards.",
				self._state.derived.reprintReward
			)
		else
			descriptionLabel.Text = string.format(
				"Earn %d more run Hype to hit the first Reprint threshold of %d.",
				remaining,
				self._state.derived.reprintThreshold
			)
		end
	else
		titleLabel.Text = "Prestige Online"
		descriptionLabel.Text = "The first Reprint milestone is complete. Spend Ink on permanent upgrades and keep climbing."
	end
end

function UIController:_renderSettings(page)
	local _, list = self:_createSection(page, "Automation", "Toggle long-session helpers and comfort settings.")

	for _, settingKey in ipairs({ "autoMerge", "autoBuy", "reducedMotion" }) do
		local metadata = SETTING_METADATA[settingKey]
		local unlocked = settingKey == "reducedMotion"
			or self._formulaUtil.isSettingUnlocked(settingKey, self._state.data, self._configs)
		local enabled = self._state.data.settings[settingKey] == true
		local card = self:_cloneTemplate("SettingCard", list)
		local button = card:WaitForChild("ActionButton")

		card.NameLabel.Text = metadata.name
		card.DescriptionLabel.Text = metadata.description
		card.MetaLabel.Text = unlocked and (enabled and "Status: On" or "Status: Off") or "Status: Locked"
		self._refs.settingButtons[settingKey] = button
		self:_registerButton(button, COLORS.upgrade)

		if unlocked then
			setButtonEnabled(button, true, COLORS.upgrade, enabled and "Turn Off" or "Turn On")
		else
			setButtonEnabled(button, false, COLORS.upgrade, metadata.lockedText)
		end

		button.MouseButton1Click:Connect(function()
			self._actions.OnUpdateSetting(settingKey, not enabled)
		end)
	end
end

function UIController:_renderNotifications(page)
	local _, list = self:_createSection(page, "Session Feed", "Recent notifications stay here even after the toast area scrolls away.")

	for _, notification in ipairs(self._state.notifications or {}) do
		local card = self:_cloneTemplate("NotificationRow", list)
		card.TitleLabel.Text = notification.title or "Board Update"
		card.MessageLabel.Text = notification.message or ""
	end
end

function UIController:_renderToasts()
	clearContainer(self._refs.toastArea)

	local notifications = self._state.notifications or {}
	local startIndex = math.max(1, #notifications - 2)
	for index = #notifications, startIndex, -1 do
		local notification = notifications[index]
		local toast = self:_cloneTemplate("ToastCard", self._refs.toastArea)
		toast.TitleLabel.Text = notification.title or "Board Update"
		toast.MessageLabel.Text = notification.message or ""
		toast.LayoutOrder = #notifications - index
	end
end

function UIController:_renderRecommendedAction()
	local action = self._state.recommendedAction
	if not action then
		self._refs.recommendationTagLabel.Text = "GOAL"
		self._refs.recommendationTitleLabel.Text = "Keep Building"
		self._refs.recommendationDescriptionLabel.Text = "No urgent action is waiting. Keep growing the board."
		setButtonEnabled(self._refs.recommendationButton, false, COLORS.collect, "No Action")
		return
	end

	self._refs.recommendationTagLabel.Text = string.upper(action.kind or "NEXT")
	self._refs.recommendationTitleLabel.Text = action.title or "Next Action"
	self._refs.recommendationDescriptionLabel.Text = action.description or ""
	setButtonEnabled(self._refs.recommendationButton, true, COLORS.collect, action.actionLabel or "Do It")
end

function UIController:_executeRecommendedAction()
	local action = self._state and self._state.recommendedAction or nil
	if not action then
		return
	end

	if action.pageId then
		self:_showPage(action.pageId)
	end

	if action.actionType == "collect" then
		self._actions.OnCollect()
	elseif action.actionType == "printSticker" then
		self._actions.OnPrintSticker(action.stickerId or action.targetId)
	elseif action.actionType == "mergeSticker" then
		self._actions.OnMergeSticker(action.stickerId or action.targetId)
	elseif action.actionType == "buyUpgrade" then
		self._actions.OnBuyUpgrade(action.upgradeId or action.targetId)
	elseif action.actionType == "claimQuest" then
		local questId = action.questId or action.targetId
		if questId and questId ~= "any" then
			self._actions.OnClaimQuest(questId)
		end
	elseif action.actionType == "unlockZone" then
		self._actions.OnUnlockZone(action.zoneId or action.targetId)
	elseif action.actionType == "reprint" then
		self._actions.OnReprint()
	end
end

function UIController:_applyRecommendedHighlight()
	self:_clearHighlights()
	local action = self._state and self._state.recommendedAction or nil
	if not action then
		return
	end

	if action.targetType == "collectButton" then
		self:_highlightButton(self._refs.collectButton)
	elseif action.targetType == "printButton" then
		self:_highlightButton(self._refs.printButtons[action.targetId])
	elseif action.targetType == "mergeButton" then
		self:_highlightButton(self._refs.stickerButtons[action.targetId])
	elseif action.targetType == "upgradeButton" then
		self:_highlightButton(self._refs.upgradeButtons[action.targetId])
	elseif action.targetType == "questButton" then
		local targetButton = action.targetId ~= "any" and self._refs.questButtons[action.targetId] or nil
		if not targetButton then
			for _, button in pairs(self._refs.questButtons) do
				targetButton = button
				break
			end
		end
		self:_highlightButton(targetButton)
	elseif action.targetType == "zoneButton" then
		self:_highlightButton(self._refs.zoneButtons[action.targetId])
	elseif action.targetType == "reprintButton" then
		self:_highlightButton(self._refs.reprintButton)
	end
end

function UIController:HandleError(message, fallbackState)
	if fallbackState then
		self:Render(fallbackState, nil, "ActionRejected")
	end

	self:ShowStatus(message or "That action was rejected.", true)
end

function UIController:Render(snapshot, meta, reason)
	self._state = snapshot
	self._refs.loadingState.Visible = false
	self._refs.errorState.Visible = false
	self:_resetActionRefs()

	local playerData = snapshot.data
	local derived = snapshot.derived
	local currentZoneConfig = self._configs.Zones[snapshot.zones.currentZoneId]

	self._refs.hypeValue.Text = string.format("Hype: %d", playerData.hype)
	self._refs.inkValue.Text = string.format("Ink: %d", playerData.inkShards)
	self._refs.rateValue.Text = string.format("Rate: %.1f/s", derived.totalProductionPerSecond)

	local completedCollectionCount = 0
	for _, completed in pairs(self._state.collectionBook.completedSets or {}) do
		if completed then
			completedCollectionCount += 1
		end
	end
	self._refs.subtitleLabel.Text = string.format(
		"%s active | %.2fx zone boost | %d sets complete",
		currentZoneConfig and currentZoneConfig.name or "Sticker Street",
		derived.currentZoneMultiplier or 1,
		completedCollectionCount
	)
	self._refs.manualRewardLabel.Text = string.format("Manual collect: +%d Hype", derived.manualCollectReward)
	self._refs.productionLabel.Text = string.format(
		"Passive %.1f + Auto %.1f = %.1f Hype/sec",
		derived.passiveProductionPerSecond,
		derived.autoCollectPerSecond,
		derived.totalProductionPerSecond
	)

	clearContainer(self._refs.playPage)
	clearContainer(self._refs.progressPage)
	clearContainer(self._refs.systemsPage)

	self:_renderZones(self._refs.playPage)
	self:_renderStickers(self._refs.playPage)
	self:_renderUpgradeList(
		self._refs.playPage,
		self._configs.Upgrades,
		"Standard Upgrades",
		"Spend Hype to accelerate manual play, automation, and board depth.",
		COLORS.upgrade
	)
	self:_renderUpgradeList(
		self._refs.playPage,
		self._configs.Prestige,
		"Ink Upgrade Tree",
		"Spend permanent Ink on long-run multipliers and quality-of-life boosts.",
		COLORS.prestige
	)
	self:_renderReprint(self._refs.playPage)

	self:_renderTutorial(self._refs.progressPage)
	local starterQuestStates = {}
	for _, questId in ipairs(self:_getOrderedIds(self._configs.Quests.STARTER)) do
		local questState = playerData.quests[questId]
		if questState then
			table.insert(starterQuestStates, {
				id = questId,
				progress = questState.progress,
				target = self._configs.Quests.STARTER[questId].target,
				completed = questState.completed,
				claimed = questState.claimed,
			})
		end
	end
	self:_renderQuestSection(
		self._refs.progressPage,
		"Starter Quests",
		"These one-time quests smooth out the first public-alpha session.",
		starterQuestStates,
		self._configs.Quests.STARTER
	)
	self:_renderQuestSection(
		self._refs.progressPage,
		"Daily Board",
		"Fresh daily goals keep the board worth revisiting.",
		self._state.dailyBoard and self._state.dailyBoard.quests or {},
		nil
	)
	self:_renderCollections(self._refs.progressPage)
	self:_renderMilestone(self._refs.progressPage)

	self:_renderSettings(self._refs.systemsPage)
	self:_renderNotifications(self._refs.systemsPage)
	self:_renderToasts()
	self:_renderRecommendedAction()
	self:_applyRecommendedHighlight()

	local message = meta and meta.message or nil
	local latestNotification = self._state.notifications and self._state.notifications[#self._state.notifications] or nil
	if message then
		self:ShowStatus(message, false)
	elseif latestNotification and latestNotification.message then
		self:ShowStatus(latestNotification.message, false)
	elseif reason == "Collected" then
		self:ShowStatus("Fresh Hype added to the board.", false)
	elseif reason == "StickerPrinted" then
		self:ShowStatus("Printed a fresh sticker copy for the board.", false)
	elseif reason == "MergeCompleted" then
		self:ShowStatus("Merged a sticker into a rarer version.", false)
	elseif reason == "UpgradePurchased" then
		self:ShowStatus("Upgrade purchased successfully.", false)
	elseif reason == "ZoneUnlocked" then
		self:ShowStatus("New zone unlocked and ready to showcase.", false)
	elseif reason == "ZoneSelected" then
		self:ShowStatus("Board camera moved to the selected zone.", false)
	elseif reason == "SettingUpdated" then
		self:ShowStatus("Automation settings updated.", false)
	elseif reason == "ReprintCompleted" then
		self:ShowStatus("Board reprinted. Permanent Ink secured.", false)
	elseif reason == "QuestClaimed" then
		self:ShowStatus("Quest reward claimed.", false)
	elseif reason == "TutorialAdvanced" then
		self:ShowStatus("Tutorial progress updated.", false)
	elseif not self._refs.statusLabel.Text or self._refs.statusLabel.Text == "" then
		self:ShowStatus("Space also collects Hype.", false)
	end
end

return UIController
