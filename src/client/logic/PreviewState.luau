local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local AvatarApplyTypes = require(ReplicatedStorage.Shared.types.AvatarApplyTypes)
local PreviewTypes = require(ReplicatedStorage.Shared.types.PreviewTypes)

export type ItemKey = CatalogTypes.ItemKey
export type PreviewPayload = PreviewTypes.PreviewPayload
export type DesiredOutfitEntry = AvatarApplyTypes.DesiredOutfitEntry

local PreviewState = {}

local previewPayloads: { [ItemKey]: PreviewPayload } = {}
local appliedEntries: { [ItemKey]: DesiredOutfitEntry } = {}
local originalEntries: { [ItemKey]: DesiredOutfitEntry } = {}

local hydrated = false
local listeners = {}

local function notifyListeners()
	for _, listener in ipairs(listeners) do
		task.spawn(listener, previewPayloads, appliedEntries)
	end
end

local function sameEntries(left: { [ItemKey]: DesiredOutfitEntry }, right: { [ItemKey]: DesiredOutfitEntry }): boolean
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

function PreviewState.subscribe(callback: (
	previewPayloads: { [ItemKey]: PreviewPayload },
	appliedEntries: { [ItemKey]: DesiredOutfitEntry }
) -> ())
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function PreviewState.hydrateOriginalEntries(entries: { DesiredOutfitEntry })
	originalEntries = {}
	for _, entry in ipairs(entries) do
		originalEntries[entry.key] = entry
	end
end

function PreviewState.hydrateAppliedEntries(entries: { DesiredOutfitEntry })
	appliedEntries = {}
	for _, entry in ipairs(entries) do
		appliedEntries[entry.key] = entry
	end
	
	hydrated = true
	notifyListeners()
end

function PreviewState.hasHydrated(): boolean
	return hydrated
end

function PreviewState.addPreviewPayload(payload: PreviewPayload)
	if not previewPayloads[payload.key] then
		local newPayloads = table.clone(previewPayloads)
		newPayloads[payload.key] = payload
		previewPayloads = newPayloads
		notifyListeners()
	end
end

function PreviewState.removePreviewPayload(key: ItemKey)
	if previewPayloads[key] then
		local newPayloads = table.clone(previewPayloads)
		newPayloads[key] = nil
		previewPayloads = newPayloads
		notifyListeners()
	end
end

function PreviewState.clearPreview()
	previewPayloads = {}
	notifyListeners()
end

function PreviewState.resetPreviewToOriginal()
	previewPayloads = {}
	notifyListeners()
end

function PreviewState.getPreviewPayloads()
	return previewPayloads
end

function PreviewState.getAppliedEntries()
	return appliedEntries
end

function PreviewState.hasPreviewPayload(key: ItemKey): boolean
	return previewPayloads[key] ~= nil
end

function PreviewState.isDirty(): boolean
	for _ in pairs(previewPayloads) do
		return true
	end
	return false
end

function PreviewState.getDesiredEntries(): { DesiredOutfitEntry }
	local entries = {}
	local seen = {}

	for key, entry in pairs(appliedEntries) do
		if not seen[key] then
			seen[key] = true
			table.insert(entries, entry)
		end
	end

	for key, payload in pairs(previewPayloads) do
		if not seen[key] then
			seen[key] = true
			table.insert(entries, {
				key = payload.key,
				itemType = payload.itemType,
				id = payload.id
			})
		end
	end

	return entries
end

return PreviewState
