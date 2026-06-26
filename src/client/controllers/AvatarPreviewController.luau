local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PreviewState = require(script.Parent.Parent.logic.PreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)
local AvatarAppearanceClient = require(script.Parent.Parent.services.AvatarAppearanceClient)
local AvatarDescriptionDraft = require(script.Parent.Parent.logic.AvatarDescriptionDraft)
local TryOnDescriptionRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote) -- using ApplyAvatarRemote with TryOn action

local AvatarPreviewController = {}

-- This function is called when UI clicks "Try On"
function AvatarPreviewController.ToggleItemPreview(item)
	local state = AvatarAppearanceClient.getState()
	if not state.liveSnapshot then
		warn("[CatalogPreview] Ignore try-on until live snapshot is loaded.")
		return
	end

	local key = item.key
	local payload = PreviewPayloadCache.get(key)
	
	if payload then
		print("[CatalogPreview] Payload found for:", key)
		local activeEmote = PreviewState.getActiveEmote()
		if activeEmote and activeEmote.key == key then
			print("[CatalogPreview] Toggling off emote")
			PreviewState.setActiveEmote(nil)
			return
		end

		if payload.emoteAnimationId then
			PreviewState.setActiveEmote(payload)
			return
		end
		
		local equippedKeys = PreviewState.getEquippedKeys()
		local isEquipped = equippedKeys[key] == true
		
		local nextPayload = table.clone(payload)
		if isEquipped then
			print("[CatalogPreview] Adding removal payload for equipped item")
			nextPayload.action = "remove"
		else
			print("[CatalogPreview] Adding equip payload")
		end
		
		-- Build next snapshot
		local nextSnapshot = AvatarDescriptionDraft.applyPayloadToSnapshot(state.liveSnapshot, nextPayload)
		
		-- Send live apply request
		task.spawn(function()
			local ok, result = pcall(function()
				return TryOnDescriptionRemote:InvokeServer({
					action = "TryOnDescription",
					description = nextSnapshot,
					revision = state.liveRevision
				})
			end)
			
			if ok and result and result.success then
				AvatarAppearanceClient.updateState(result.liveSnapshot, result.liveRevision, result.source)
			else
				warn("[CatalogPreview] TryOn failed:", result and result.message or "unknown error")
			end
		end)
	else
		warn(`[CatalogPreview] Cannot preview item {key}; payload is not yet cached.`)
	end
end

-- This function is called to reset the character to original appearance
function AvatarPreviewController.ResetPreview()
	-- Handled by resetting original, wait, we don't have a reset remote yet. 
	-- We can use TryOnDescriptionRemote with the original snapshot, but the client doesn't know the original snapshot.
	-- We need a ResetRemote, or we can just add a reset remote later.
	warn("Reset to original not yet implemented in Phase 7 UI")
end

function AvatarPreviewController.RemoveWornItem(item)
	local state = AvatarAppearanceClient.getState()
	if not state.liveSnapshot then
		warn("[CatalogPreview] Cannot remove item: live snapshot is not loaded.")
		return
	end

	print("[CatalogPreview] Removing worn item:", item.property, item.id)

	-- We construct a custom payload to remove the item
	-- We need to pass the assetIds as a table with the single ID so the draft logic can filter it out of CSV properties
	local removePayload = {
		action = "remove",
		id = item.id,
		itemType = "Asset",
		propertyName = item.property,
		assetIds = { item.id }
	}
	
	-- We don't really need humanoidDescriptionProperties for simple removal if applyPayloadToSnapshot knows how to handle "remove" with just id.
	-- Let's check how applyPayloadToSnapshot handles remove: it iterates over humanoidDescriptionProperties and removes the id.
	
	-- So we need to fetch the property.
	-- Fortunately, applyPayloadToSnapshot removes `id` from any CSV property or clears the property if it matches exactly.
	-- But to be safe, we give it the property hint.
	
	local nextSnapshot = AvatarDescriptionDraft.applyPayloadToSnapshot(state.liveSnapshot, removePayload)
	
	task.spawn(function()
		local ok, result = pcall(function()
			return TryOnDescriptionRemote:InvokeServer({
				action = "TryOnDescription",
				description = nextSnapshot,
				revision = state.liveRevision
			})
		end)
		
		if ok and result and result.success then
			AvatarAppearanceClient.updateState(result.liveSnapshot, result.liveRevision, result.source)
		else
			warn("[CatalogPreview] Remove failed:", result and result.message or "unknown error")
		end
	end)
end

return AvatarPreviewController
