local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local AvatarApplyTypes = require(ReplicatedStorage.Shared.types.AvatarApplyTypes)
local PreviewTypes = require(ReplicatedStorage.Shared.types.PreviewTypes)
local AvatarDescriptionDraft = require(script.Parent.AvatarDescriptionDraft)

export type ItemKey = CatalogTypes.ItemKey
export type PreviewPayload = PreviewTypes.PreviewPayload
export type DesiredOutfitEntry = AvatarApplyTypes.DesiredOutfitEntry

local PreviewState = {}

local previewPayloads: { [ItemKey]: PreviewPayload } = {}
local appliedEntries: { [ItemKey]: DesiredOutfitEntry } = {}
local originalEntries: { [ItemKey]: DesiredOutfitEntry } = {}
local activeEmote: PreviewPayload? = nil

local hydrated = false
local listeners = {}

local function notifyListeners()
	-- Sync draft description with current payloads
	AvatarDescriptionDraft.resetDraftToApplied()
	for _, payload in pairs(previewPayloads) do
		AvatarDescriptionDraft.applyPayload(payload)
	end

	for _, listener in ipairs(listeners) do
		task.spawn(listener, previewPayloads, appliedEntries, activeEmote)
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
	appliedEntries: { [ItemKey]: DesiredOutfitEntry },
	activeEmote: PreviewPayload?
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
	if type(entries) ~= "table" then
		warn("[PreviewState] hydrateAppliedEntries called with non-table:", entries)
		return
	end
	for i, entry in ipairs(entries) do
		if type(entry) ~= "table" then
			warn(`[PreviewState] hydrateAppliedEntries entry at index {i} is not a table:`, entry)
			continue
		end
		if entry.key == nil then
			warn(`[PreviewState] hydrateAppliedEntries entry has nil key! index {i}, entry:`, entry)
		end
		appliedEntries[entry.key] = entry
	end
	
	hydrated = true
	notifyListeners()
end

function PreviewState.hasHydrated(): boolean
	return hydrated
end

function PreviewState.setActiveEmote(payload: PreviewPayload?)
	if activeEmote ~= payload then
		activeEmote = payload
		notifyListeners()
	end
end

function PreviewState.getActiveEmote(): PreviewPayload?
	return activeEmote
end

function PreviewState.addPreviewPayload(payload: PreviewPayload)
	local newPayloads = table.clone(previewPayloads)
	
	-- Remove active emote when equipping something else
	if activeEmote then
		activeEmote = nil
	end

	-- Replacement logic for accessories/clothing
	if payload.propertyName then
		for key, existing in pairs(newPayloads) do
			if existing.propertyName == payload.propertyName then
				newPayloads[key] = nil
			end
		end
	end

	-- Replacement logic for body parts (bundles)
	if payload.bodyParts then
		for key, existing in pairs(newPayloads) do
			if existing.bodyParts then
				local overlap = false
				for partName in pairs(payload.bodyParts) do
					if existing.bodyParts[partName] then
						overlap = true
						break
					end
				end
				if overlap then
					newPayloads[key] = nil
				end
			end
		end
	end

	newPayloads[payload.key] = payload
	previewPayloads = newPayloads
	notifyListeners()
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
	activeEmote = nil
	notifyListeners()
end

function PreviewState.resetPreviewToOriginal()
	previewPayloads = {}
	activeEmote = nil
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
