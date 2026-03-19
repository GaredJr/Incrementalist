local shared = script.Parent.Parent

return {
	Economy = require(shared.Config.EconomyConfig),
	Stickers = require(shared.Config.StickerConfig),
	Upgrades = require(shared.Config.UpgradeConfig),
	Prestige = require(shared.Config.PrestigeConfig),
	Quests = require(shared.Config.QuestConfig),
	Zones = require(shared.Config.ZoneConfig),
	Collections = require(shared.Config.CollectionConfig),
	Tutorial = require(shared.Config.TutorialConfig),
}
