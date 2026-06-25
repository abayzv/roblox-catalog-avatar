local PreviewState = require(script.Parent.Parent.logic.PreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)

local AvatarPreviewController = {}

-- This function is called when UI clicks "Try On"
function AvatarPreviewController.ToggleItemPreview(item)
	print("[CatalogPreview] ToggleItemPreview called for:", item.key, "hasHydrated:", PreviewState.hasHydrated())
	if not PreviewState.hasHydrated() then
		warn("[CatalogPreview] Ignore try-on until equipped snapshot is loaded.")
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

		if PreviewState.hasPreviewPayload(key) then
			print("[CatalogPreview] Removing payload")
			PreviewState.removePreviewPayload(key)
		else
			print("[CatalogPreview] Adding payload")
			if payload.emoteAnimationId then
				PreviewState.setActiveEmote(payload)
			else
				PreviewState.addPreviewPayload(payload)
			end
		end
	else
		warn(`[CatalogPreview] Cannot preview item {key}; payload is not yet cached.`)
	end
end

-- This function is called to reset the character to original appearance
function AvatarPreviewController.ResetPreview()
	PreviewState.resetPreviewToOriginal()
end

return AvatarPreviewController
