local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local PreviewTypes = require(ReplicatedStorage.Shared.types.PreviewTypes)

local PreviewPayloadCache = {}

local cache: { [CatalogTypes.ItemKey]: PreviewTypes.PreviewPayload } = {}
local listeners: { [CatalogTypes.ItemKey]: { (payload: PreviewTypes.PreviewPayload) -> () } } = {}

function PreviewPayloadCache.get(key: CatalogTypes.ItemKey): PreviewTypes.PreviewPayload?
	return cache[key]
end

function PreviewPayloadCache.set(key: CatalogTypes.ItemKey, payload: PreviewTypes.PreviewPayload)
	cache[key] = payload
	
	-- Notify listeners
	local callbacks = listeners[key]
	if callbacks then
		for _, callback in ipairs(callbacks) do
			task.spawn(callback, payload)
		end
		-- Clear listeners after firing since payload is now cached and won't change
		listeners[key] = nil
	end
end

function PreviewPayloadCache.patch(key: CatalogTypes.ItemKey, partial: any)
	local payload = cache[key]
	if payload then
		for k, v in pairs(partial) do
			payload[k] = v
		end
		
		-- Notify listeners even for patches, in case UI depends on state changes
		local callbacks = listeners[key]
		if callbacks then
			for _, callback in ipairs(callbacks) do
				task.spawn(callback, payload)
			end
		end
	end
end

function PreviewPayloadCache.has(key: CatalogTypes.ItemKey): boolean
	return cache[key] ~= nil
end

function PreviewPayloadCache.getAll(): { [CatalogTypes.ItemKey]: PreviewTypes.PreviewPayload }
	return cache
end

function PreviewPayloadCache.listen(key: CatalogTypes.ItemKey, callback: (payload: PreviewTypes.PreviewPayload) -> ()): () -> ()
	if cache[key] then
		-- Already cached, fire immediately
		task.spawn(callback, cache[key])
		return function() end
	end
	
	if not listeners[key] then
		listeners[key] = {}
	end
	table.insert(listeners[key], callback)
	
	return function()
		local callbacks = listeners[key]
		if callbacks then
			local index = table.find(callbacks, callback)
			if index then
				table.remove(callbacks, index)
			end
		end
	end
end

return PreviewPayloadCache
