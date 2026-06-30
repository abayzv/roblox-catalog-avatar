local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ResolveEmotesRemote = require(ReplicatedStorage.Shared.remotes.ResolveEmotesRemote)
local PreviewPayloadCache = require(script.Parent.PreviewPayloadCache)

local EmoteAnimationResolver = {}

-- Maintain an in-memory cache to prevent multiple calls for the same emote in a session
local resolutionCache: { [number]: number } = {}
local pendingResolutions: { [number]: boolean } = {}
local resolutionYields: { [number]: { thread: thread } } = {}

function EmoteAnimationResolver.resolveOne(emoteAssetId: number): (boolean, number?, string?)
	if not emoteAssetId then
		return false, nil, "NO_ASSET_ID"
	end

	-- 1. Check local memory cache first
	if resolutionCache[emoteAssetId] then
		return true, resolutionCache[emoteAssetId], nil
	end

	-- 2. Prevent duplicate concurrent calls
	if pendingResolutions[emoteAssetId] then
		table.insert(resolutionYields[emoteAssetId], { thread = coroutine.running() })
		coroutine.yield()

		if resolutionCache[emoteAssetId] then
			return true, resolutionCache[emoteAssetId], nil
		else
			return false, nil, "RESOLUTION_FAILED_DURING_YIELD"
		end
	end

	pendingResolutions[emoteAssetId] = true
	resolutionYields[emoteAssetId] = {}

	-- 3. Fetch from remote
	local success, resolvedMap = pcall(function()
		return ResolveEmotesRemote:InvokeServer({ emoteAssetId })
	end)

	local animationId = nil
	if success and type(resolvedMap) == "table" then
		local resolvedId = resolvedMap[tostring(emoteAssetId)]
		if resolvedId then
			animationId = tonumber(resolvedId)
			resolutionCache[emoteAssetId] = animationId
		end
	end

	pendingResolutions[emoteAssetId] = nil

	-- Resume yielding threads
	for _, yieldData in ipairs(resolutionYields[emoteAssetId]) do
		task.spawn(yieldData.thread)
	end
	resolutionYields[emoteAssetId] = nil

	if animationId then
		return true, animationId, nil
	else
		return false, nil, "FAILED_TO_RESOLVE"
	end
end

return EmoteAnimationResolver
