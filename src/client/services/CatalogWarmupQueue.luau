local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local PreviewPayloadResolver = require(script.Parent.PreviewPayloadResolver)
local PreviewPayloadCache = require(script.Parent.PreviewPayloadCache)
local ContentPrewarmQueue = require(script.Parent.ContentPrewarmQueue)

local CatalogWarmupQueue = {}

type QueueEntry = {
	item: CatalogTypes.CatalogItem,
	token: number,
	tokenRef: { current: number },
}

local queue: { QueueEntry } = {}
local isProcessing = false

local function processQueue()
	if isProcessing or #queue == 0 then
		return
	end
	
	isProcessing = true
	
	task.spawn(function()
		while #queue > 0 do
			-- Take up to 30 items for batch processing
			local batchEntries = {}
			local itemsToResolve = {}
			
			while #queue > 0 and #batchEntries < 30 do
				local entry = table.remove(queue, 1)
				
				-- Skip stale entries
				if entry.token == entry.tokenRef.current then
					local key = entry.item.key
					if key and not PreviewPayloadCache.has(key) then
						table.insert(batchEntries, entry)
						table.insert(itemsToResolve, entry.item)
					end
				end
			end
			
			if #itemsToResolve > 0 then
				local payloadsMap = PreviewPayloadResolver.resolveBatch(itemsToResolve)
				
				-- Extract a list of payloads for prewarming
				local prewarmList = {}
				for _, item in ipairs(itemsToResolve) do
					if payloadsMap[item.key] then
						table.insert(prewarmList, payloadsMap[item.key])
					end
				end
				
				-- Prewarm the first 15 items to cache physical assets
				ContentPrewarmQueue.queueItems(prewarmList, 15)
				
				-- Apply payloads to cache, checking tokens again
				for _, entry in ipairs(batchEntries) do
					if entry.token == entry.tokenRef.current then
						local key = entry.item.key
						local payload = payloadsMap[key]
						
						if payload then
							PreviewPayloadCache.set(key, payload)
						else
							PreviewPayloadCache.set(key, {
								key = key,
								id = tonumber(entry.item.id) or 0,
								itemType = entry.item.itemType or "Asset",
								kind = "Failed",
							})
						end
					end
				end
			end
		end
		
		isProcessing = false
	end)
end

function CatalogWarmupQueue.warmup(items: { CatalogTypes.CatalogItem }, token: number, tokenRef: { current: number })
	for _, item in ipairs(items) do
		if item.key and not PreviewPayloadCache.has(item.key) then
			table.insert(queue, {
				item = item,
				token = token,
				tokenRef = tokenRef,
			})
		end
	end
	
	processQueue()
end

return CatalogWarmupQueue
