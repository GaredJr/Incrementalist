local TableUtil = {}

function TableUtil.deepCopy(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}

	for key, value in pairs(source) do
		copy[key] = TableUtil.deepCopy(value)
	end

	return copy
end

function TableUtil.mergeDefaults(target, defaults)
	local merged = TableUtil.deepCopy(target or {})

	for key, value in pairs(defaults or {}) do
		if type(value) == "table" then
			merged[key] = TableUtil.mergeDefaults(merged[key], value)
		elseif merged[key] == nil then
			merged[key] = value
		end
	end

	return merged
end

return TableUtil
