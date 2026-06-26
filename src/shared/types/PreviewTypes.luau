local CatalogTypes = require(script.Parent.CatalogTypes)

export type PreviewPayload = {
	key: CatalogTypes.ItemKey,
	id: number,
	itemType: CatalogTypes.AvatarItemType,
	kind: string,

	propertyName: string?,
	assetIds: { number }?,
	animations: { [string]: number }?,
	bodyParts: { [string]: number }?,
	emoteAnimationId: number?,
	emoteAssetId: number?,
	resolveState: string?,
	resolveError: string?,
}

return {}
