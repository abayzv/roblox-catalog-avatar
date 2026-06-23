local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local PreviewState = require(script.Parent.Parent.logic.PreviewState)

local function usePreviewState()
	local previewItems, setPreviewItems = React.useState(PreviewState.getPreviewItems())

	React.useEffect(function()
		local unsubscribe = PreviewState.subscribe(function(newPreviewItems)
			setPreviewItems(newPreviewItems)
		end)
		return unsubscribe
	end, {})

	return previewItems
end

return usePreviewState
