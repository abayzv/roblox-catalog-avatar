local CatalogTypes = require(script.Parent.CatalogTypes)

export type DesiredOutfitEntry = {
	key: CatalogTypes.ItemKey,
	itemType: CatalogTypes.AvatarItemType,
	id: number,
}

return {}
