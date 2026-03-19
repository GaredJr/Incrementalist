local ZoneConfig = {
	sticker_street = {
		id = "sticker_street",
		sortOrder = 1,
		name = "Sticker Street",
		description = "The warm-up strip where every board gets loud for the first time.",
		unlockCost = 0,
		productionMultiplier = 1,
		accentColor = { 1, 0.6000000238, 0.2823529541 },
		mapFolderName = "sticker_street",
		rewardStickerId = nil,
	},
	neon_alley = {
		id = "neon_alley",
		sortOrder = 2,
		name = "Neon Alley",
		description = "A bright late-night lane that boosts its own family of foil monsters.",
		unlockCost = 1500,
		productionMultiplier = 1.3500000238,
		accentColor = { 0.2392156869, 0.5058823824, 1 },
		mapFolderName = "neon_alley",
		requiredZoneId = "sticker_street",
		rewardStickerId = "soda_slime",
		rewardAmount = 1,
	},
}

return ZoneConfig
