local CollectionConfig = {
	smile_line = {
		id = "smile_line",
		sortOrder = 1,
		name = "Smile Syndicate",
		description = "Discover every sticker in the classic city starter line.",
		stickerIds = { "basic_smile", "neon_cat", "holo_dragon", "cosmic_ghost" },
		reward = {
			stickerProductionMultiplier = 0.08,
		},
	},
	arcade_line = {
		id = "arcade_line",
		sortOrder = 2,
		name = "Arcade Crew",
		description = "Finish the pixel-heavy board-expander line.",
		stickerIds = { "arcade_bunny", "pixel_koala", "glitch_pigeon", "laser_pegasus" },
		reward = {
			manualCollectMultiplier = 0.12,
		},
	},
	neon_line = {
		id = "neon_line",
		sortOrder = 3,
		name = "Alley Lights",
		description = "Collect the full Neon Alley family.",
		stickerIds = { "soda_slime", "turbo_tiger", "disco_phoenix", "billboard_titan" },
		reward = {
			stickerProductionMultiplier = 0.12,
			offlineEfficiencyBonus = 0.05,
		},
	},
	city_legends = {
		id = "city_legends",
		sortOrder = 4,
		name = "City Legends",
		description = "Find every epic sticker across all three families.",
		stickerIds = { "cosmic_ghost", "laser_pegasus", "billboard_titan" },
		reward = {
			manualCollectMultiplier = 0.08,
			stickerProductionMultiplier = 0.06,
		},
	},
}

return CollectionConfig
