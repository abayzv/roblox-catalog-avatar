local PreviewState = require(script.Parent.Parent.logic.PreviewState)
-- local PreviewItemApplier = require(script.Parent.Parent.logic.PreviewItemApplier) -- To be added in 4.3

local AvatarPreviewController = {}

-- This function is called when UI clicks "Try On"
function AvatarPreviewController.ToggleItemPreview(item)
	if PreviewState.hasPreviewItem(item.id) then
		PreviewState.removePreviewItem(item.id)
		-- PreviewItemApplier.RemoveItem(item.id)
	else
		PreviewState.addPreviewItem(item)
		-- PreviewItemApplier.ApplyItem(item)
	end
end

-- This function is called to reset the character to original appearance
function AvatarPreviewController.ResetPreview()
	PreviewState.clearPreview()
	-- PreviewItemApplier.RestoreOriginalAppearance()
end

return AvatarPreviewController
