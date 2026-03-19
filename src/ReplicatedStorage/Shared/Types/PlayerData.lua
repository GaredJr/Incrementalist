local CollectionUtil = require(script.Parent.Parent.Util.CollectionUtil)
local DailyQuestUtil = require(script.Parent.Parent.Util.DailyQuestUtil)
local TutorialUtil = require(script.Parent.Parent.Util.TutorialUtil)

local PlayerData = {}

PlayerData.SCHEMA_VERSION = 3

local function cloneDictionary(source)
	local clone = {}

	for key, value in pairs(source) do
		if type(value) == "table" then
			clone[key] = cloneDictionary(value)
		else
			clone[key] = value
		end
	end

	return clone
end

local function ensureStarterQuestState(quests)
	local questState = {}

	for questId, _ in pairs(quests) do
		questState[questId] = {
			progress = 0,
			completed = false,
			claimed = false,
		}
	end

	return questState
end

local function ensureUpgradeState(upgrades, prestige)
	local state = {}

	for upgradeId, _ in pairs(upgrades) do
		state[upgradeId] = 0
	end

	for upgradeId, config in pairs(prestige) do
		if type(config) == "table" and config.id then
			state[upgradeId] = 0
		end
	end

	return state
end

local function normalizeUnlockedZones(unlockedZones, starterZoneId, zoneId)
	local normalized = {
		[starterZoneId] = true,
	}

	if type(unlockedZones) == "table" then
		for currentZoneId, isUnlocked in pairs(unlockedZones) do
			normalized[currentZoneId] = isUnlocked == true
		end
	end

	if zoneId then
		normalized[zoneId] = true
	end

	return normalized
end

local function normalizeCollectionBook(existingBook)
	local book = CollectionUtil.createBook()

	if type(existingBook) ~= "table" then
		return book
	end

	if type(existingBook.discovered) == "table" then
		for stickerId, discovered in pairs(existingBook.discovered) do
			book.discovered[stickerId] = discovered == true
		end
	end

	if type(existingBook.completedSets) == "table" then
		for collectionId, completed in pairs(existingBook.completedSets) do
			book.completedSets[collectionId] = completed == true
		end
	end

	return book
end

local function normalizeDailyBoard(existingBoard)
	if type(existingBoard) ~= "table" then
		return {
			dayKey = 0,
			resetAtUnix = 0,
			quests = {},
		}
	end

	local board = {
		dayKey = math.max(0, math.floor(tonumber(existingBoard.dayKey) or 0)),
		resetAtUnix = math.max(0, math.floor(tonumber(existingBoard.resetAtUnix) or 0)),
		quests = {},
	}

	if type(existingBoard.quests) == "table" then
		for _, quest in ipairs(existingBoard.quests) do
			if type(quest) == "table" and type(quest.id) == "string" then
				table.insert(board.quests, {
					id = quest.id,
					templateId = quest.templateId,
					category = "daily",
					name = quest.name or "Daily Objective",
					description = quest.description or "",
					type = quest.type,
					target = math.max(1, math.floor(tonumber(quest.target) or 1)),
					progress = math.max(0, math.floor(tonumber(quest.progress) or 0)),
					completed = quest.completed == true,
					claimed = quest.claimed == true,
					reward = cloneDictionary(quest.reward or {}),
				})
			end
		end
	end

	return board
end

local function normalizeTutorialState(existingTutorial, schemaContext, currentData)
	if type(existingTutorial) == "table" then
		return TutorialUtil.normalizeState(existingTutorial, schemaContext)
	end

	if currentData and TutorialUtil.hasMigrationProgress(currentData, schemaContext) then
		return TutorialUtil.createCompletedState(schemaContext)
	end

	return TutorialUtil.createState(schemaContext)
end

function PlayerData.new(schemaContext)
	local template = {
		schemaVersion = PlayerData.SCHEMA_VERSION,
		hype = 0,
		lifetimeHype = 0,
		reprintCheckpointHype = 0,
		inkShards = 0,
		ownedStickers = {
			[schemaContext.Economy.STARTER_STICKER_ID] = schemaContext.Economy.STARTER_STICKER_COUNT,
		},
		upgrades = ensureUpgradeState(schemaContext.Upgrades, schemaContext.Prestige),
		prestigeCount = 0,
		settings = cloneDictionary(schemaContext.Economy.DEFAULT_SETTINGS),
		lastOnlineUnix = os.time(),
		zoneId = schemaContext.Economy.STARTER_ZONE_ID,
		unlockedZones = {
			[schemaContext.Economy.STARTER_ZONE_ID] = true,
		},
		quests = ensureStarterQuestState(schemaContext.Quests.STARTER),
		dailyBoard = {
			dayKey = 0,
			resetAtUnix = 0,
			quests = {},
		},
		collectionBook = CollectionUtil.createBook(),
		tutorial = TutorialUtil.createState(schemaContext),
	}

	template.dailyBoard = DailyQuestUtil.generateDailyBoard(template, schemaContext.Quests, schemaContext, os.time())
	return template
end

function PlayerData.migrate(existingData, schemaContext)
	local migrated = PlayerData.new(schemaContext)
	local hadDailyBoard = type(existingData) == "table" and existingData.dailyBoard ~= nil
	local hadTutorial = type(existingData) == "table" and existingData.tutorial ~= nil

	if type(existingData) ~= "table" then
		return migrated
	end

	for key, value in pairs(existingData) do
		if key == "settings" and type(value) == "table" then
			for settingKey, settingValue in pairs(value) do
				migrated.settings[settingKey] = settingValue
			end
		elseif key == "ownedStickers" and type(value) == "table" then
			for stickerId, count in pairs(value) do
				if type(count) == "number" and count >= 0 then
					migrated.ownedStickers[stickerId] = math.floor(count)
				end
			end
		elseif key == "upgrades" and type(value) == "table" then
			for upgradeId, level in pairs(value) do
				if type(level) == "number" and level >= 0 then
					migrated.upgrades[upgradeId] = math.floor(level)
				end
			end
		elseif key == "quests" and type(value) == "table" then
			for questId, questState in pairs(value) do
				if migrated.quests[questId] and type(questState) == "table" then
					migrated.quests[questId].progress = math.max(0, math.floor(questState.progress or 0))
					migrated.quests[questId].completed = questState.completed == true
					migrated.quests[questId].claimed = questState.claimed == true
				end
			end
		elseif key == "collectionBook" then
			migrated.collectionBook = normalizeCollectionBook(value)
		elseif key == "dailyBoard" then
			migrated.dailyBoard = normalizeDailyBoard(value)
		elseif key == "unlockedZones" then
			migrated.unlockedZones = normalizeUnlockedZones(value, schemaContext.Economy.STARTER_ZONE_ID, existingData.zoneId)
		elseif key == "tutorial" then
			migrated.tutorial = normalizeTutorialState(value, schemaContext, existingData)
		elseif migrated[key] ~= nil then
			migrated[key] = value
		end
	end

	migrated.schemaVersion = PlayerData.SCHEMA_VERSION
	migrated.lastOnlineUnix = tonumber(migrated.lastOnlineUnix) or os.time()
	migrated.hype = math.max(0, tonumber(migrated.hype) or 0)
	migrated.lifetimeHype = math.max(0, tonumber(migrated.lifetimeHype) or 0)
	migrated.reprintCheckpointHype = math.max(0, tonumber(migrated.reprintCheckpointHype) or 0)
	migrated.inkShards = math.max(0, tonumber(migrated.inkShards) or 0)
	migrated.prestigeCount = math.max(0, math.floor(tonumber(migrated.prestigeCount) or 0))
	migrated.unlockedZones = normalizeUnlockedZones(migrated.unlockedZones, schemaContext.Economy.STARTER_ZONE_ID, migrated.zoneId)
	migrated.collectionBook = normalizeCollectionBook(migrated.collectionBook)
	migrated.dailyBoard = normalizeDailyBoard(migrated.dailyBoard)
	if hadTutorial then
		migrated.tutorial = normalizeTutorialState(migrated.tutorial, schemaContext, migrated)
	else
		migrated.tutorial = normalizeTutorialState(nil, schemaContext, migrated)
	end

	if not hadDailyBoard then
		migrated.dailyBoard = {
			dayKey = 0,
			resetAtUnix = 0,
			quests = {},
		}
	end

	if not migrated.unlockedZones[migrated.zoneId] then
		migrated.zoneId = schemaContext.Economy.STARTER_ZONE_ID
	end

	return migrated
end

return PlayerData
