local AnalyticsService = {
	_enabled = true,
}

local function encodePayload(payload)
	if type(payload) ~= "table" then
		return ""
	end

	local parts = {}
	for key, value in pairs(payload) do
		table.insert(parts, string.format("%s=%s", tostring(key), tostring(value)))
	end

	table.sort(parts)
	return table.concat(parts, " ")
end

function AnalyticsService:Init(dependencies)
	self._enabled = dependencies and dependencies.Enabled ~= false
end

function AnalyticsService:Track(player, eventName, payload)
	if not self._enabled then
		return
	end

	local playerName = player and player.Name or "server"
	local encodedPayload = encodePayload(payload)
	if encodedPayload ~= "" then
		print(string.format("[Analytics] player=%s event=%s %s", playerName, eventName, encodedPayload))
	else
		print(string.format("[Analytics] player=%s event=%s", playerName, eventName))
	end
end

return AnalyticsService
