local FormatUtils = {}

function FormatUtils.formatNumber(value: number): string
	local formatted = tostring(value)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

return FormatUtils
