local PreviewState = require(script.Parent.Parent.logic.PreviewState)

local AvatarPreviewController = {}

-- This function is called when UI clicks "Try On"
function AvatarPreviewController.ToggleItemPreview(item)
	if not PreviewState.hasHydrated() then
		warn("[CatalogPreview] Ignore try-on until equipped snapshot is loaded.")
		return
	end

	if PreviewState.hasPreviewItem(item) then
		PreviewState.removePreviewItem(item)
	else
		PreviewState.addPreviewItem(item)
	end
end

-- This function is called to reset the character to original appearance
function AvatarPreviewController.ResetPreview()
	PreviewState.resetPreviewToOriginal()
end

return AvatarPreviewController
