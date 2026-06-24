local PreviewState = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
export type CatalogItem = CatalogTypes.CatalogItem

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
	local newItems = {}
	for k, v in pairs(items) do
		newItems[k] = v
	end
	return newItems
end

local function cloneItem(item: CatalogItem): CatalogItem
	local newItem = {}
	for k, v in pairs(item) do
		newItem[k] = v
	end
	return newItem
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

local NON_EXCLUSIVE_PROPERTIES = {
	HatAccessory = true,
	HairAccessory = true,
}

local function itemHasProperty(item: CatalogItem, propName: string): boolean
	if item.propertyName == propName then
		return true
	end
	if item.bundleAssets then
		for _, bAsset in ipairs(item.bundleAssets) do
			if bAsset.propertyName == propName then
				return true
			end
		end
	end
	return false
end

local function enforceExclusivity(items: { [string]: CatalogItem }, newItemKey: string, propName: string)
	if not NON_EXCLUSIVE_PROPERTIES[propName] then
		for otherKey, otherItem in pairs(items) do
			if otherKey ~= newItemKey and itemHasProperty(otherItem, propName) then
				items[otherKey] = nil
			end
		end
	end
end

local function ensurePropertyName(item: CatalogItem)
	if item.propertyName or item.bundleAssets then
		return
	end
	local assetId = item.assetId or tonumber(item.id)
	if not assetId then
		return
	end

	if item.itemType == "Bundle" or item.itemType == Enum.AvatarItemType.Bundle then
		task.spawn(function()
			local success, details = pcall(function()
				return game:GetService("AssetService"):GetBundleDetailsAsync(assetId)
			end)
			if success and details and details.Items then
				local bundleAssets = {}
				for _, subItem in ipairs(details.Items) do
					if subItem.Type == "Asset" then
						local s, info = pcall(function()
							return MarketplaceService:GetProductInfo(subItem.Id, Enum.InfoType.Asset)
						end)
						if s and info then
							local propName = CatalogConfig.AssetTypeToProperty[info.AssetTypeId]
							if propName then
								table.insert(bundleAssets, {
									id = subItem.Id,
									name = subItem.Name,
									assetType = tostring(info.AssetTypeId),
									propertyName = propName,
								})
							end
						end
					end
				end

				if #bundleAssets > 0 then
					local key = getItemKey(item)
					local changed = false

					if previewItems[key] then
						local newItems = cloneItems(previewItems)
						newItems[key] = cloneItem(newItems[key])
						newItems[key].bundleAssets = bundleAssets
						for _, bAsset in ipairs(bundleAssets) do
							if bAsset.propertyName then
								enforceExclusivity(newItems, key, bAsset.propertyName)
							end
						end
						previewItems = newItems
						changed = true
					end

					if appliedItems[key] then
						local newApplied = cloneItems(appliedItems)
						newApplied[key].bundleAssets = bundleAssets
						appliedItems = newApplied
					end

					if changed then
						notifyListeners()
					end
				end
			end
		end)
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
					newItems[key] = cloneItem(newItems[key])
					newItems[key].propertyName = propName
					enforceExclusivity(newItems, key, propName)
					previewItems = newItems
					changed = true
				end

				if appliedItems[key] then
					local newApplied = cloneItems(appliedItems)
					newApplied[key] = cloneItem(newApplied[key])
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
		
		-- Special rule: Try On ANY item resets (removes) the current Emote preview
		for otherKey, otherItem in pairs(newItems) do
			if itemHasProperty(otherItem, "EmoteAnimation") then
				newItems[otherKey] = nil
			end
		end
		
		newItems[key] = item
		if item.propertyName then
			enforceExclusivity(newItems, key, item.propertyName)
		end
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
		if (item.itemType == "Bundle" or item.itemType == Enum.AvatarItemType.Bundle) and item.bundleAssets then
			for _, bAsset in ipairs(item.bundleAssets) do
				if bAsset.propertyName == "EmoteAnimation" then
					continue
				end
				if not seen[bAsset.id] then
					seen[bAsset.id] = true
					table.insert(assetIds, bAsset.id)
				end
			end
		else
			if item.propertyName == "EmoteAnimation" then
				continue
			end
			local assetId = item.assetId or tonumber(item.id)
			if assetId and not seen[assetId] then
				seen[assetId] = true
				table.insert(assetIds, assetId)
			end
		end
	end

	table.sort(assetIds)
	return assetIds
end

return PreviewState
