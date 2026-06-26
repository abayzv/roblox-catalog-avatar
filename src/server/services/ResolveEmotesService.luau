local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local ResolveEmotesRemote = require(ReplicatedStorage.Shared.remotes.ResolveEmotesRemote)

local ResolveEmotesService = {}
local resolvedCache = {}

function ResolveEmotesService.init()
	ResolveEmotesRemote.OnServerInvoke = function(player, assetIds)
		if type(assetIds) ~= "table" then
			return {}
		end
		
		local MAX_EMOTES_PER_REQUEST = 3
		if #assetIds > MAX_EMOTES_PER_REQUEST then
			warn("[ResolveEmotesService] Truncating request to", MAX_EMOTES_PER_REQUEST, "emotes for player", player.UserId)
			local truncated = {}
			for i = 1, MAX_EMOTES_PER_REQUEST do
				table.insert(truncated, assetIds[i])
			end
			assetIds = truncated
		end

		local results = {}
		for _, assetId in ipairs(assetIds) do
			if type(assetId) ~= "number" then
				continue
			end

			-- Check memory cache
			if resolvedCache[assetId] then
				results[tostring(assetId)] = resolvedCache[assetId]
				continue
			end

			local success, model = pcall(function()
				return InsertService:LoadAsset(assetId)
			end)

			if success and model then
				local animationId = nil
				for _, desc in ipairs(model:GetDescendants()) do
					if desc:IsA("Animation") then
						local idStr = string.match(desc.AnimationId, "%d+")
						if idStr then
							animationId = tonumber(idStr)
						end
						break
					end
				end

				if animationId then
					resolvedCache[assetId] = animationId
					results[tostring(assetId)] = animationId
				end

				model:Destroy()
			else
				warn("[ResolveEmotesService] Failed to load asset", assetId, ":", model)
			end
		end

		return results
	end
end

return ResolveEmotesService
