local PreviewState = {}

local activeEmote = nil
local equippedKeys: { [string]: boolean } = {}
local listeners = {}

function PreviewState.subscribe(
	callback: (equippedKeys: { [string]: boolean }, activeEmote: any) -> ()
)
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

local function notifyListeners()
	for _, listener in ipairs(listeners) do
		task.spawn(listener, equippedKeys, activeEmote)
	end
end

function PreviewState.getActiveEmote()
	return activeEmote
end

function PreviewState.setActiveEmote(payload: any)
	if activeEmote ~= payload then
		activeEmote = payload
		notifyListeners()
	end
end

function PreviewState.setEquippedKeys(keys: { [string]: boolean })
	equippedKeys = keys
	notifyListeners()
end

function PreviewState.getEquippedKeys(): { [string]: boolean }
	return equippedKeys
end

return PreviewState
