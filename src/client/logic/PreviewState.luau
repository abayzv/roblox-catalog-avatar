local PreviewState = {}

export type CatalogItem = {
	id: string,
	name: string,
	price: number | string,
	image: string,
}

local previewItems: { [string]: CatalogItem } = {}
local appliedItems: { [string]: CatalogItem } = {}
local originalAppearance: any = nil

local listeners = {}

local function notifyListeners()
	for _, listener in ipairs(listeners) do
		task.spawn(listener, previewItems, appliedItems)
	end
end

function PreviewState.subscribe(callback: (
	previewItems: { [string]: CatalogItem },
	appliedItems: { [string]: CatalogItem }
) -> ())
	table.insert(listeners, callback)
	-- Return an unsubscribe function
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function PreviewState.addPreviewItem(item: CatalogItem)
	if not previewItems[item.id] then
		local newItems = table.clone(previewItems)
		newItems[item.id] = item
		previewItems = newItems
		notifyListeners()
	end
end

function PreviewState.removePreviewItem(itemId: string)
	if previewItems[itemId] then
		local newItems = table.clone(previewItems)
		newItems[itemId] = nil
		previewItems = newItems
		notifyListeners()
	end
end

function PreviewState.clearPreview()
	previewItems = {}
	notifyListeners()
end

function PreviewState.getPreviewItems()
	return previewItems
end

function PreviewState.hasPreviewItem(itemId: string)
	return previewItems[itemId] ~= nil
end

function PreviewState.setOriginalAppearance(appearance: any)
	originalAppearance = appearance
end

function PreviewState.getOriginalAppearance()
	return originalAppearance
end

return PreviewState
