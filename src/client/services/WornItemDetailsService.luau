local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")

export type WornDisplayItem = {
	id: number,
	name: string,
	price: number,
	creator: string,
	image: string,
	assetType: string,
}

local WornItemDetailsService = {}
local cache = {}

function WornItemDetailsService.resolveDetails(ids: { number }): { [number]: WornDisplayItem }
	local results = {}
	local toFetch = {}

	for _, id in ipairs(ids) do
		if cache[id] then
			results[id] = cache[id]
		else
			table.insert(toFetch, id)
		end
	end

	if #toFetch > 0 then
		local success, batchDetails = pcall(function()
			return AvatarEditorService:GetBatchItemDetails(toFetch, Enum.AvatarItemType.Asset)
		end)

		if success and batchDetails then
			for _, detail in ipairs(batchDetails) do
				local id = detail.Id
				local displayItem = {
					id = id,
					name = detail.Name or "Unknown Item",
					price = detail.PriceInRobux or 0,
					creator = detail.CreatorName or "Roblox",
					image = "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150",
					assetType = detail.ItemType or "Asset",
				}
				cache[id] = displayItem
				results[id] = displayItem
			end
		end

		-- For any that failed or weren't in AvatarEditorService, try MarketplaceService fallback or just use basic data
		for _, id in ipairs(toFetch) do
			if not results[id] then
				results[id] = {
					id = id,
					name = "Item " .. id,
					price = 0,
					creator = "Unknown",
					image = "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150",
					assetType = "Asset",
				}
			end
		end
	end

	return results
end

return WornItemDetailsService
