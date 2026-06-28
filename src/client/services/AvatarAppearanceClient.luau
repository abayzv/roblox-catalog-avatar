local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetAppearanceStateRemote = require(ReplicatedStorage.Shared.remotes.GetAppearanceStateRemote)
local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local PreviewState = require(script.Parent.Parent.logic.PreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)

export type AppearanceSnapshot = {
	[string]: any,
}

export type OptimisticState = {
	isOptimistic: boolean,
	requestId: number,
	previousSnapshot: AppearanceSnapshot?,
	predictedSnapshot: AppearanceSnapshot?,
	actionType: string?,
}

export type ClientAppearanceState = {
	liveSnapshot: AppearanceSnapshot?,
	liveRevision: number,
	lastApplySource: string?,
	optimisticState: OptimisticState?,
}

local AvatarAppearanceClient = {}
local state: ClientAppearanceState = {
	liveSnapshot = nil,
	liveRevision = 0,
	lastApplySource = nil,
	optimisticState = nil,
}

local listeners = {}

local function extractEquippedKeys(snapshot: AppearanceSnapshot)
	local desc = HumanoidDescriptionSerializer.deserialize(snapshot)
	local keys = {}
	
	-- Helper to add asset id
	local function addAsset(assetId)
		if type(assetId) == "number" and assetId > 0 then
			keys[CatalogTypes.makeItemKey("Asset", assetId)] = true
		elseif type(assetId) == "string" and assetId ~= "" then
			for token in string.gmatch(assetId, "[^,]+") do
				local trimmed = string.gsub(token, "^%s*(.-)%s*$", "%1")
				local num = tonumber(trimmed)
				if num and num > 0 then
					keys[CatalogTypes.makeItemKey("Asset", num)] = true
				end
			end
		end
	end
	
	-- Rigid accessories
	for _, prop in ipairs({"HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory"}) do
		pcall(function() addAsset(desc[prop]) end)
	end
	
	-- Clothing
	for _, prop in ipairs({"Shirt", "Pants", "GraphicTShirt"}) do
		pcall(function() addAsset(desc[prop]) end)
	end
	
	-- Body Parts
	for _, prop in ipairs({"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}) do
		pcall(function() addAsset(desc[prop]) end)
	end

	-- Animations
	for _, prop in ipairs({"IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation"}) do
		pcall(function() addAsset(desc[prop]) end)
	end
	
	-- Layered clothing
	local accs = desc:GetAccessories(true)
	for _, acc in ipairs(accs) do
		addAsset(acc.AssetId)
	end
	
	-- Bundles/Body parts second pass
	-- Since HumanoidDescription only stores part AssetIDs (not Bundle IDs),
	-- we must infer if a Bundle is equipped by checking if its parts are equipped.
	for cachedKey, payload in pairs(PreviewPayloadCache.getAll()) do
		if string.find(cachedKey, "^Bundle:") then
			local isEquipped = true
			local hasRequirements = false
			
			if payload.assetIds and #payload.assetIds > 0 then
				hasRequirements = true
				for _, assetId in ipairs(payload.assetIds) do
					if not keys[CatalogTypes.makeItemKey("Asset", assetId)] then
						isEquipped = false
						break
					end
				end
			end
			
			if payload.bodyParts then
				hasRequirements = true
				for partName, partAssetId in pairs(payload.bodyParts) do
					if partAssetId > 0 then
						local currentVal = nil
						pcall(function() currentVal = desc[partName] end)
						if currentVal ~= partAssetId then
							isEquipped = false
							break
						end
					end
				end
			end
			
			if payload.animations then
				hasRequirements = true
				for animName, animAssetId in pairs(payload.animations) do
					if animAssetId > 0 then
						local currentVal = nil
						pcall(function() currentVal = desc[animName] end)
						if currentVal ~= animAssetId then
							isEquipped = false
							break
						end
					end
				end
			end
			
			if hasRequirements and isEquipped then
				keys[cachedKey] = true
			end
		end
	end

	local count = 0
	for k in pairs(keys) do count += 1 end
	print("[AvatarAppearanceClient] Extracted equipped keys count:", count)
	
	PreviewState.setEquippedKeys(keys)
end

local function notifyListeners()
	if state.liveSnapshot then
		extractEquippedKeys(state.liveSnapshot)
	end
	for _, listener in ipairs(listeners) do
		task.spawn(listener, state)
	end
end

function AvatarAppearanceClient.subscribe(callback: (state: ClientAppearanceState) -> ())
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

function AvatarAppearanceClient.getState(): ClientAppearanceState
	return state
end

local nextRequestId = 0

function AvatarAppearanceClient.setOptimisticState(snapshot: AppearanceSnapshot, actionType: string?): number
	nextRequestId += 1
	local requestId = nextRequestId
	
	state = {
		liveSnapshot = state.liveSnapshot,
		liveRevision = state.liveRevision,
		lastApplySource = state.lastApplySource,
		optimisticState = {
			isOptimistic = true,
			requestId = requestId,
			previousSnapshot = state.liveSnapshot,
			predictedSnapshot = snapshot,
			actionType = actionType,
		},
	}
	notifyListeners()
	
	return requestId
end

function AvatarAppearanceClient.resolveOptimisticState(requestId: number, liveSnapshot: AppearanceSnapshot, liveRevision: number, source: string?)
	if state.optimisticState and state.optimisticState.requestId == requestId then
		state = {
			liveSnapshot = liveSnapshot,
			liveRevision = liveRevision,
			lastApplySource = source,
			optimisticState = {
				isOptimistic = false,
				requestId = 0,
				previousSnapshot = nil,
				predictedSnapshot = nil,
				actionType = nil,
			},
		}
	else
		-- If the request ID doesn't match, it means a newer optimistic update took precedence.
		-- We just update the live state quietly without clearing the current optimistic state.
		state = {
			liveSnapshot = liveSnapshot,
			liveRevision = liveRevision,
			lastApplySource = source,
			optimisticState = state.optimisticState,
		}
	end
	notifyListeners()
end

function AvatarAppearanceClient.rollbackOptimisticState(requestId: number)
	if state.optimisticState and state.optimisticState.requestId == requestId then
		state = {
			liveSnapshot = state.liveSnapshot,
			liveRevision = state.liveRevision,
			lastApplySource = state.lastApplySource,
			optimisticState = {
				isOptimistic = false,
				requestId = 0,
				previousSnapshot = nil,
				predictedSnapshot = nil,
				actionType = nil,
			},
		}
		notifyListeners()
	end
end

function AvatarAppearanceClient.fetchStateAsync(): ClientAppearanceState
	local ok, result = pcall(function()
		return GetAppearanceStateRemote:InvokeServer()
	end)
	
	if ok and result and result.success then
		state = {
			liveSnapshot = result.liveSnapshot,
			liveRevision = result.liveRevision,
			lastApplySource = result.lastApplySource,
			optimisticState = state.optimisticState, -- preserve optimistic state
		}
		notifyListeners()
	else
		warn("[AvatarAppearanceClient] Failed to fetch state from server:", result and result.message or "unknown error")
	end
	
	return state
end

function AvatarAppearanceClient.updateState(liveSnapshot: AppearanceSnapshot, liveRevision: number, source: string?)
	state = {
		liveSnapshot = liveSnapshot,
		liveRevision = liveRevision,
		lastApplySource = source,
		optimisticState = state.optimisticState, -- preserve optimistic state
	}
	notifyListeners()
end

return AvatarAppearanceClient
