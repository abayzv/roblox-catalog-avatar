local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local PreviewState = require(script.Parent.Parent.logic.PreviewState)

local function usePreviewState()
	local previewPayloads, setPreviewPayloads = React.useState(PreviewState.getPreviewPayloads())

	React.useEffect(function()
		local unsubscribe = PreviewState.subscribe(function(newPreviewPayloads)
			setPreviewPayloads(newPreviewPayloads)
		end)
		return unsubscribe
	end, {})

	return previewPayloads
end

return usePreviewState
