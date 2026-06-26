local CatalogTypes = {}

export type AvatarItemType = "Asset" | "Bundle"
export type ItemKey = string

export type CatalogItem = {
	key: ItemKey?,
	itemType: AvatarItemType?,
	id: string | number,

	name: string,
	price: number | string,
	image: string,

	assetId: number?,
	assetType: string?,
	propertyName: string?,
	category: string?,
	subcategory: string?,
	tags: { string }?,
	availability: string?,
}

export type CatalogUiState = {
	activeHeaderTab: "ItemCatalog" | "AvatarLoader",
	activeCategory: string,
	activeSubcategory: string,
	searchQuery: string,
	hoveredItemId: string?,
	selectedItemId: string?,
}

function CatalogTypes.makeItemKey(itemType: AvatarItemType, id: number | string): string
	return `{itemType}:{id}`
end

function CatalogTypes.parseItemKey(key: string): { itemType: AvatarItemType, id: number }?
	local parts = string.split(key, ":")
	if #parts == 2 then
		local itemType = parts[1]
		local id = tonumber(parts[2])
		if (itemType == "Asset" or itemType == "Bundle") and id ~= nil then
			return { itemType = itemType :: AvatarItemType, id = id }
		end
	end
	return nil
end

function CatalogTypes.isValidItemKey(key: string): boolean
	return CatalogTypes.parseItemKey(key) ~= nil
end

return CatalogTypes
