local PreviewState = require(script.Parent.Parent.logic.PreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)

local AvatarPreviewController = {}

-- This function is called when UI clicks "Try On"
function AvatarPreviewController.ToggleItemPreview(item)
	if not PreviewState.hasHydrated() then
		warn("[CatalogPreview] Ignore try-on until equipped snapshot is loaded.")
		return
	end

	local key = item.key or tostring(item.id)
	
	if PreviewState.hasPreviewPayload(key) then
		PreviewState.removePreviewPayload(key)
	else
		local payload = PreviewPayloadCache.get(key)
		if payload then
			PreviewState.addPreviewPayload(payload)
		else
			warn(`[CatalogPreview] Cannot preview item {key}; payload is not yet cached.`)
		end
	end
end

-- This function is called to reset the character to original appearance
function AvatarPreviewController.ResetPreview()
	PreviewState.resetPreviewToOriginal()
end

return AvatarPreviewController
