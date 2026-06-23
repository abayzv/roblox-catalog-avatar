export type CatalogItem = {
	id: string,
	name: string,
	price: number,
	image: string,
	assetId: number?,
	category: string,
	subcategory: string,
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
