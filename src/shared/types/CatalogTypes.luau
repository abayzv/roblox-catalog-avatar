export type CatalogItem = {
	id: string,
	name: string,
	price: number | string,
	image: string,
	assetId: number?,
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

return {}
