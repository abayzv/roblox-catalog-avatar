local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")

export type DisplayItemDetails = {
	id: number,
	name: string,
	price: number,
	creator: string,
	image: string,
	assetType: string,
	isFree: boolean,
	isOffSale: boolean,
}

local ItemDetailsService = {}
local cache = {}

-- items is an array of { id: number, itemType: string }
function ItemDetailsService.resolveDetails(
	items: { { id: number, itemType: string } }
): { [string]: DisplayItemDetails }
	local results = {}

	local assetsToFetch = {}
	local bundlesToFetch = {}

	for _, item in ipairs(items) do
		local cacheKey = item.itemType .. ":" .. item.id
		if cache[cacheKey] then
			results[cacheKey] = cache[cacheKey]
		else
			if item.itemType == "Bundle" then
				table.insert(bundlesToFetch, item.id)
			else
				table.insert(assetsToFetch, item.id)
			end
		end
	end

	local function processBatch(ids, itemTypeEnum, typeString)
		if #ids == 0 then
			return
		end

		local success, batchDetails = pcall(function()
			return AvatarEditorService:GetBatchItemDetails(ids, itemTypeEnum)
		end)

		if success and batchDetails then
			for _, detail in ipairs(batchDetails) do
				local id = detail.Id
				local price = detail.Price or 0
				local isFree = detail.PriceStatus == "Free"
					or (price == 0 and detail.PriceStatus ~= "OffSale")
				local isOffSale = detail.IsOffSale == true or detail.PriceStatus == "OffSale"

				local image = "rbxthumb://type="
					.. (typeString == "Bundle" and "BundleThumbnail" or "Asset")
					.. "&id="
					.. id
					.. "&w=150&h=150"

				local displayItem = {
					id = id,
					name = detail.Name or "Unknown Item",
					price = price,
					creator = detail.CreatorName or "Roblox",
					image = image,
					assetType = detail.ItemType or typeString,
					isFree = isFree,
					isOffSale = isOffSale,
				}

				local cacheKey = typeString .. ":" .. id
				cache[cacheKey] = displayItem
				results[cacheKey] = displayItem
			end
		end

		-- Fallback for any that failed
		for _, id in ipairs(ids) do
			local cacheKey = typeString .. ":" .. id
			if not results[cacheKey] then
				results[cacheKey] = {
					id = id,
					name = "Item " .. id,
					price = 0,
					creator = "Unknown",
					image = "rbxthumb://type="
						.. (typeString == "Bundle" and "BundleThumbnail" or "Asset")
						.. "&id="
						.. id
						.. "&w=150&h=150",
					assetType = typeString,
					isFree = false,
					isOffSale = true,
				}
			end
		end
	end

	processBatch(assetsToFetch, Enum.AvatarItemType.Asset, "Asset")
	processBatch(bundlesToFetch, Enum.AvatarItemType.Bundle, "Bundle")

	return results
end

return ItemDetailsService
