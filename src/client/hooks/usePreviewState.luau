local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local PreviewState = require(script.Parent.Parent.logic.PreviewState)

local function usePreviewState()
	local equippedKeys, setEquippedKeys = React.useState(PreviewState.getEquippedKeys())
	local activeEmote, setActiveEmote = React.useState(PreviewState.getActiveEmote())

	React.useEffect(function()
		local unsubscribe = PreviewState.subscribe(function(newEquippedKeys, newActiveEmote)
			setEquippedKeys(newEquippedKeys)
			setActiveEmote(newActiveEmote)
		end)
		return unsubscribe
	end, {})

	return equippedKeys, activeEmote
end

return usePreviewState
