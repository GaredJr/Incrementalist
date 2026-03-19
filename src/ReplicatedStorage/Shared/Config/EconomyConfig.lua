local EconomyConfig = {
	AUTOSAVE_INTERVAL_SECONDS = 90,
	AUTO_PRODUCTION_TICK_SECONDS = 1,
	OFFLINE_CAP_SECONDS = 8 * 60 * 60,
	OFFLINE_EFFICIENCY = 0.7,
	STARTER_ZONE_ID = "sticker_street",
	STARTER_STICKER_ID = "basic_smile",
	STARTER_STICKER_COUNT = 1,
	BASE_MANUAL_COLLECT = 3,
	COLLECT_RATE_LIMIT_SECONDS = 0.15,
	REQUEST_RATE_LIMIT_SECONDS = 0.1,
	MAX_NUMERIC_INPUT = 1000000000,
	DATASTORE_NAME = "StickerStreetTycoon_PlayerData_v1",
	AUTO_MERGE_MAX_ACTIONS_PER_TICK = 24,
	AUTO_BUY_MAX_PURCHASES_PER_TICK = 6,
	DEFAULT_SETTINGS = {
		autoMerge = false,
		autoBuy = false,
		reducedMotion = false,
	},
	RARITY_ORDER = {
		Common = 1,
		Uncommon = 2,
		Rare = 3,
		Epic = 4,
	},
}

return EconomyConfig
