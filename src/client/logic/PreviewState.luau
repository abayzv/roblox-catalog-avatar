local PreviewState = {}

export type CatalogItem = {
	id: string,
	name: string,
	price: number | string,
	image: string,
	assetId: number?,
	propertyName: string?,
}

type EquippedItemPayload = {
	assetId: number,
	propertyName: string?,
	name: string?,
}

local previewItems: { [string]: CatalogItem } = {}
local appliedItems: { [string]: CatalogItem } = {}
local originalItems: { [string]: CatalogItem } = {}
local hydrated = false

local listeners = {}

local function getItemKey(item: CatalogItem): string
	return tostring(item.assetId or item.id)
end

local function makeCatalogItemFromAssetId(assetId: number): CatalogItem
	return {
		id = tostring(assetId),
		name = `Equipped Item {assetId}`,
		price = "-",
		image = `rbxthumb://type=Asset&id={assetId}&w=420&h=420`,
		assetId = assetId,
	}
end

local function makeCatalogItemFromEquippedItem(equippedItem: EquippedItemPayload): CatalogItem?
	local assetId = tonumber(equippedItem.assetId)
	if not assetId then
		return nil
	end

	return {
		id = tostring(assetId),
		name = equippedItem.name or `Equipped Item {assetId}`,
		price = "-",
		image = `rbxthumb://type=Asset&id={assetId}&w=420&h=420`,
		assetId = assetId,
		propertyName = equippedItem.propertyName,
	}
end

local function cloneItems(items: { [string]: CatalogItem }): { [string]: CatalogItem }
	local clone = {}
	for key, item in pairs(items) do
		clone[key] = item
	end
	return clone
end

local function makeItemsFromAssetIds(assetIds: { number }): { [string]: CatalogItem }
	local items = {}

	for _, assetId in ipairs(assetIds) do
		local item = makeCatalogItemFromAssetId(assetId)
		items[getItemKey(item)] = item
	end

	return items
end

local function makeItemsFromEquippedItems(
	equippedItems: { EquippedItemPayload }
): { [string]: CatalogItem }
	local items = {}

	for _, equippedItem in ipairs(equippedItems) do
		local item = makeCatalogItemFromEquippedItem(equippedItem)
		if item then
			items[getItemKey(item)] = item
		end
	end

	return items
end

local function sameItems(left: { [string]: CatalogItem }, right: { [string]: CatalogItem }): boolean
	for key in pairs(left) do
		if right[key] == nil then
			return false
		end
	end

	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end

	return true
end

local function notifyListeners()
	for _, listener in ipairs(listeners) do
		task.spawn(listener, previewItems, appliedItems)
	end
end

local function describeItems(items: { [string]: CatalogItem }): string
	local values = {}

	for key, item in pairs(items) do
		table.insert(values, `{key}:{item.propertyName or "unknown"}`)
	end

	table.sort(values)
	return table.concat(values, ",")
end

local MarketplaceService = game:GetService("MarketplaceService")
local CatalogConfig = require(game:GetService("ReplicatedStorage").Shared.config.CatalogConfig)

local function ensurePropertyName(item: CatalogItem)
	if item.propertyName then
		return
	end
	local assetId = item.assetId or tonumber(item.id)
	if not assetId then
		return
	end

	task.spawn(function()
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
		end)
		if success and info then
			local propName = CatalogConfig.AssetTypeToProperty[info.AssetTypeId]
			if propName then
				local key = getItemKey(item)
				local changed = false

				if previewItems[key] then
					local newItems = cloneItems(previewItems)
					newItems[key].propertyName = propName
					previewItems = newItems
					changed = true
				end

				if appliedItems[key] then
					local newApplied = cloneItems(appliedItems)
					newApplied[key].propertyName = propName
					appliedItems = newApplied
				end

				if changed then
					notifyListeners()
				end
			end
		end
	end)
end

function PreviewState.subscribe(callback: (
	previewItems: { [string]: CatalogItem },
	appliedItems: { [string]: CatalogItem }
) -> ())
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function PreviewState.hydrateOriginalItems(equippedItems: { EquippedItemPayload })
	originalItems = makeItemsFromEquippedItems(equippedItems)
	print(`[PreviewState] Hydrated original items: {describeItems(originalItems)}`)
	notifyListeners()

	for _, item in pairs(originalItems) do
		ensurePropertyName(item)
	end
end

function PreviewState.hydrateAppliedAssetIds(assetIds: { number })
	appliedItems = makeItemsFromAssetIds(assetIds)
	previewItems = cloneItems(appliedItems)
	hydrated = true
	notifyListeners()

	for _, item in pairs(appliedItems) do
		ensurePropertyName(item)
	end
end

function PreviewState.hydrateAppliedItems(equippedItems: { EquippedItemPayload })
	appliedItems = makeItemsFromEquippedItems(equippedItems)
	previewItems = cloneItems(appliedItems)
	hydrated = true
	print(`[PreviewState] Hydrated applied items: {describeItems(appliedItems)}`)
	notifyListeners()

	for _, item in pairs(appliedItems) do
		ensurePropertyName(item)
	end
end

function PreviewState.hasHydrated(): boolean
	return hydrated
end

function PreviewState.addPreviewItem(item: CatalogItem)
	local key = getItemKey(item)
	if not previewItems[key] then
		local newItems = cloneItems(previewItems)
		newItems[key] = item
		previewItems = newItems
		notifyListeners()
		ensurePropertyName(item)
	end
end

function PreviewState.removePreviewItem(itemOrId: CatalogItem | string)
	local key = if type(itemOrId) == "table" then getItemKey(itemOrId) else tostring(itemOrId)

	if previewItems[key] then
		local newItems = cloneItems(previewItems)
		newItems[key] = nil
		previewItems = newItems
		notifyListeners()
	end
end

function PreviewState.clearPreview()
	previewItems = {}
	notifyListeners()
end

function PreviewState.resetPreviewToOriginal()
	previewItems = cloneItems(originalItems)
	notifyListeners()
end

function PreviewState.getPreviewItems()
	return previewItems
end

function PreviewState.getAppliedItems()
	return appliedItems
end

function PreviewState.hasPreviewItem(itemOrId: CatalogItem | string)
	local key = if type(itemOrId) == "table" then getItemKey(itemOrId) else tostring(itemOrId)
	return previewItems[key] ~= nil
end

function PreviewState.isDirty(): boolean
	return not sameItems(previewItems, appliedItems)
end

function PreviewState.getDesiredAssetIds(): { number }
	local assetIds = {}
	local seen = {}

	for _, item in pairs(previewItems) do
		local assetId = item.assetId or tonumber(item.id)
		if assetId and not seen[assetId] then
			seen[assetId] = true
			table.insert(assetIds, assetId)
		end
	end

	table.sort(assetIds)
	return assetIds
end

return PreviewState
