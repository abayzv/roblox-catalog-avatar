local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local PreviewState = require(script.Parent.Parent.logic.PreviewState)

local function usePreviewState()
	local previewPayloads, setPreviewPayloads = React.useState(PreviewState.getPreviewPayloads())
	local activeEmote, setActiveEmote = React.useState(PreviewState.getActiveEmote())

	React.useEffect(function()
		local unsubscribe = PreviewState.subscribe(function(newPreviewPayloads, _, newActiveEmote)
			setPreviewPayloads(newPreviewPayloads)
			setActiveEmote(newActiveEmote)
		end)
		return unsubscribe
	end, {})

	return previewPayloads, activeEmote
end

return usePreviewState
