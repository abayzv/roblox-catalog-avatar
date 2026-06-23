local PreviewState = require(script.Parent.Parent.logic.PreviewState)

local AvatarPreviewController = {}

-- This function is called when UI clicks "Try On"
function AvatarPreviewController.ToggleItemPreview(item)
	if PreviewState.hasPreviewItem(item.id) then
		PreviewState.removePreviewItem(item.id)
	else
		PreviewState.addPreviewItem(item)
	end
end

-- This function is called to reset the character to original appearance
function AvatarPreviewController.ResetPreview()
	PreviewState.clearPreview()
end

return AvatarPreviewController
