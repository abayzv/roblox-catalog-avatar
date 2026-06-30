local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
export type CatalogItem = CatalogTypes.CatalogItem

local CatalogService = {}

export type FetchParams = {
	category: string,
	subCategory: string,
	searchQuery: string,
	cursor: string?,
}

export type FetchResult = {
	items: { CatalogItem },
	nextCursor: string?,
}

-- Fallback mock for testing in Studio if API access is off
local function createMockItem(id: number, name: string): CatalogItem
	local itemType: CatalogTypes.AvatarItemType = "Asset"
	local key = CatalogTypes.makeItemKey(itemType, id)
	return {
		key = key,
		id = id,
		itemType = itemType,
		name = name,
		price = 100,
		image = `rbxthumb://type=Asset&id={id}&w=420&h=420`,
		assetId = id,
	}
end

local MOCK_FALLBACK = {
	createMockItem(128159229, "Fedora Macan Tutul Salju"),
	createMockItem(376524487, "Blonde Spiked Hair"),
}

local currentCatalogPages: CatalogPages? = nil
local currentSearchSignature: string = ""

local function getSearchSignature(params: FetchParams): string
	return `{params.category}_{params.subCategory}_{params.searchQuery}`
end

local function applyFilters(searchParams: CatalogSearchParams, subCategory: string)
	-- Default to None, override for specific subcategories
	searchParams.CategoryFilter = Enum.CatalogCategoryFilter.None

	if subCategory == "Featured" then
		searchParams.CategoryFilter = Enum.CatalogCategoryFilter.Featured
	elseif subCategory == "Recommended" then
		searchParams.CategoryFilter = Enum.CatalogCategoryFilter.Recommended
	elseif subCategory == "Premium" then
		searchParams.CategoryFilter = Enum.CatalogCategoryFilter.Premium
		
	elseif subCategory == "Body Bundles" then
		searchParams.BundleTypes = { Enum.BundleType.BodyParts }
	elseif subCategory == "Hair" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.HairAccessory }
	elseif subCategory == "Head" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.Head, Enum.AvatarAssetType.DynamicHead }
		searchParams.BundleTypes = { Enum.BundleType.DynamicHead }
	elseif subCategory == "Faces" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.Face }
		
	elseif subCategory == "T-Shirt" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.TShirtAccessory }
	elseif subCategory == "Shirt" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.ShirtAccessory }
	elseif subCategory == "Pants" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.PantsAccessory }
	elseif subCategory == "Jacket" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.JacketAccessory }
	elseif subCategory == "Sweater" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.SweaterAccessory }
	elseif subCategory == "Shorts" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.ShortsAccessory }
	elseif subCategory == "Dress / Skirt" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.DressSkirtAccessory }
	elseif subCategory == "Shoes Bundle" then
		searchParams.BundleTypes = { Enum.BundleType.Shoes }
		
	elseif subCategory == "Classic T-Shirt" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.TShirt }
	elseif subCategory == "Classic Shirt" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.Shirt }
	elseif subCategory == "Classic Pants" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.Pants }
		
	elseif subCategory == "Hats" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.Hat }
	elseif subCategory == "Face Accessories" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.FaceAccessory }
	elseif subCategory == "Neck" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.NeckAccessory }
	elseif subCategory == "Shoulder" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.ShoulderAccessory }
	elseif subCategory == "Front" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.FrontAccessory }
	elseif subCategory == "Back" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.BackAccessory }
	elseif subCategory == "Waist" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.WaistAccessory }
		
	elseif subCategory == "Emotes" then
		searchParams.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
	elseif subCategory == "Animation Bundles" then
		searchParams.BundleTypes = { Enum.BundleType.Animations }
	end
end

export type FetchResult = {
	items: { CatalogItem },
	nextCursor: string?,
	isThrottled: boolean?,
}

function CatalogService.fetchPage(params: FetchParams): FetchResult
	local signature = getSearchSignature(params)
	local isThrottled = false
	
	if currentCatalogPages and currentSearchSignature == signature and params.cursor ~= nil then
		-- Fetch next page
		local success, err = pcall(function()
			currentCatalogPages:AdvanceToNextPageAsync()
		end)
		if not success then
			local errStr = tostring(err)
			if string.find(errStr, "429") or string.find(errStr, "TooManyRequests") then
				isThrottled = true
			else
				warn(`[CatalogService] Failed to advance page: {errStr}`)
			end
			return { items = {}, nextCursor = nil, isThrottled = isThrottled }
		end
	else
		-- New search
		local searchParams = CatalogSearchParams.new()
		searchParams.SearchKeyword = params.searchQuery or ""
		applyFilters(searchParams, params.subCategory)
		
		-- Setup specific filters if needed
		searchParams.IncludeOffSale = false
		searchParams.SortType = Enum.CatalogSortType.Relevance
		
		local success, pages = pcall(function()
			return AvatarEditorService:SearchCatalog(searchParams)
		end)
		
		if success and pages then
			currentCatalogPages = pages
			currentSearchSignature = signature
		else
			local errStr = tostring(pages)
			if string.find(errStr, "429") or string.find(errStr, "TooManyRequests") then
				isThrottled = true
			else
				warn(`[CatalogService] Failed to search catalog: {errStr}. Using mock fallback.`)
				-- Return mock fallback if API fails
				return {
					items = MOCK_FALLBACK,
					nextCursor = nil,
					isThrottled = false,
				}
			end
			
			return { items = {}, nextCursor = nil, isThrottled = isThrottled }
		end
	end

	local items: { CatalogItem } = {}
	local isFinished = true
	
	if currentCatalogPages then
		local page = currentCatalogPages:GetCurrentPage()
		for _, rawItem in ipairs(page) do
			local itemType: CatalogTypes.AvatarItemType = if rawItem.ItemType == "Bundle" or rawItem.ItemType == Enum.AvatarItemType.Bundle then "Bundle" else "Asset"
			local key = CatalogTypes.makeItemKey(itemType, rawItem.Id)
			
			local item: CatalogItem = {
				key = key,
				id = rawItem.Id,
				itemType = itemType,
				name = rawItem.Name or "Unknown Item",
				price = rawItem.Price or 0,
				image = if itemType == "Bundle" 
					then `rbxthumb://type=BundleThumbnail&id={rawItem.Id}&w=420&h=420` 
					else `rbxthumb://type=Asset&id={rawItem.Id}&w=420&h=420`,
				assetId = if itemType == "Asset" then rawItem.Id else nil,
				assetType = if itemType == "Asset" and rawItem.AssetType then rawItem.AssetType.Name else nil,
				category = params.category,
				subcategory = params.subCategory,
			}
			table.insert(items, item)
		end
		isFinished = currentCatalogPages.IsFinished
	end

	return {
		items = items,
		nextCursor = if isFinished then nil else "next_page",
		isThrottled = false,
	}
end

return CatalogService
