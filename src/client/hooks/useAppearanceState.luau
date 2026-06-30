local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local AvatarAppearanceClient = require(script.Parent.Parent.services.AvatarAppearanceClient)

local function useAppearanceState()
	local state, setState = React.useState(AvatarAppearanceClient.getState())

	React.useEffect(function()
		-- Fetch on mount if not initialized
		if state.liveRevision == 0 then
			task.spawn(function()
				AvatarAppearanceClient.fetchStateAsync()
			end)
		end

		local disconnect = AvatarAppearanceClient.subscribe(function(newState)
			setState(newState)
		end)

		return function()
			disconnect()
		end
	end, {})

	return state
end

return useAppearanceState
