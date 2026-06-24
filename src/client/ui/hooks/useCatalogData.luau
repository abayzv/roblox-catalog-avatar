local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
export type CatalogItem = CatalogTypes.CatalogItem

local CatalogService = require(script.Parent.Parent.Parent.services.CatalogService)

export type CatalogDataState = {
	items: { CatalogItem },
	isLoading: boolean,
	isFetchingMore: boolean,
	hasError: boolean,
	fetchNextPage: () -> (),
}

local function parseCatalogPages(pages: any, mainCategory: string, subCategory: string): { CatalogItem }
	local parsedItems = {}
	if not pages then
		return parsedItems
	end

	local currentPage = pages:GetCurrentPage()
	for _, itemInfo in ipairs(currentPage) do
		local image = "rbxassetid://18517062196"
		-- The API returns ItemType as a string ("Asset" or "Bundle")
		if itemInfo.ItemType == "Asset" then
			image = `rbxthumb://type=Asset&id={itemInfo.Id}&w=150&h=150`
		elseif itemInfo.ItemType == "Bundle" then
			image = `rbxthumb://type=BundleThumbnail&id={itemInfo.Id}&w=150&h=150`
		end

		local priceText = itemInfo.Price
		if itemInfo.PriceStatus == "Off Sale" or itemInfo.PriceStatus == "No Resellers" then
			priceText = "Off Sale"
		elseif itemInfo.PriceStatus == "Free" or itemInfo.Price == 0 then
			priceText = "Free"
		elseif not itemInfo.Price then
			-- Fallback if Price is nil and PriceStatus isn't explicit
			priceText = "Off Sale"
		end

		table.insert(parsedItems, {
			id = tostring(itemInfo.Id),
			name = itemInfo.Name or "Unknown Item",
			price = priceText,
			image = image,
			assetId = itemInfo.Id,
			category = mainCategory,
			subcategory = subCategory,
			availability = (priceText == "Off Sale") and "OffSale" or "InStock",
			itemType = itemInfo.ItemType,
		})
	end
	return parsedItems
end

local function useCatalogData(searchQuery: string, activeMainCategory: string, activeSubCategory: string): CatalogDataState
	local items, setItems = React.useState({})
	local isLoading, setIsLoading = React.useState(true)
	local isFetchingMore, setIsFetchingMore = React.useState(false)
	local hasError, setHasError = React.useState(false)
	local pagesRef = React.useRef(nil)

	React.useEffect(function()
		local isCancelled = false
		setIsLoading(true)
		setHasError(false)
		setItems({})
		pagesRef.current = nil

		task.spawn(function()
			local pages, err = CatalogService.SearchAsync(searchQuery, activeMainCategory, activeSubCategory)
			if isCancelled then return end

			if err or not pages then
				setHasError(true)
				setIsLoading(false)
				return
			end

			pagesRef.current = pages
			local parsedItems = parseCatalogPages(pages, activeMainCategory, activeSubCategory)
			
			if not isCancelled then
				setItems(parsedItems)
				setIsLoading(false)
			end
		end)

		return function()
			isCancelled = true
		end
	end, { searchQuery, activeMainCategory, activeSubCategory })

	local fetchNextPage = React.useCallback(function()
		if isFetchingMore or isLoading then return end
		if not pagesRef.current or pagesRef.current.IsFinished then return end

		setIsFetchingMore(true)
		task.spawn(function()
			local success = pcall(function()
				pagesRef.current:AdvanceToNextPageAsync()
			end)
			
			if success then
				local newParsedItems = parseCatalogPages(pagesRef.current, activeMainCategory, activeSubCategory)
				setItems(function(prevItems)
					local combined = table.clone(prevItems)
					for _, item in ipairs(newParsedItems) do
						table.insert(combined, item)
					end
					return combined
				end)
			end
			setIsFetchingMore(false)
		end)
	end, { isFetchingMore, isLoading, activeMainCategory, activeSubCategory })

	return {
		items = items,
		isLoading = isLoading,
		isFetchingMore = isFetchingMore,
		hasError = hasError,
		fetchNextPage = fetchNextPage,
	}
end

return useCatalogData
