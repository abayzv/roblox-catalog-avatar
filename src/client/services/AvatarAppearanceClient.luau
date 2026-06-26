local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetAppearanceStateRemote = require(ReplicatedStorage.Shared.remotes.GetAppearanceStateRemote)
local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local PreviewState = require(script.Parent.Parent.logic.PreviewState)

export type AppearanceSnapshot = {
	[string]: any,
}

export type ClientAppearanceState = {
	liveSnapshot: AppearanceSnapshot?,
	liveRevision: number,
	lastApplySource: string?,
}

local AvatarAppearanceClient = {}
local state: ClientAppearanceState = {
	liveSnapshot = nil,
	liveRevision = 0,
	lastApplySource = nil,
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
	
	-- Layered clothing
	local accs = desc:GetAccessories(true)
	for _, acc in ipairs(accs) do
		addAsset(acc.AssetId)
	end
	
	-- Bundles/Body parts usually aren't direct assetIds in description (they are bundle IDs, but description holds asset IDs for the parts).
	-- For UI matching, if the UI matches by itemKey (which for bundles is Bundle:ID), it's hard to map from part AssetId -> Bundle ID locally.
	-- We'll just leave them out for now or only match Assets. The plan says simple currently wearing is fine.

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

function AvatarAppearanceClient.fetchStateAsync(): ClientAppearanceState
	local ok, result = pcall(function()
		return GetAppearanceStateRemote:InvokeServer()
	end)
	
	if ok and result and result.success then
		state = {
			liveSnapshot = result.liveSnapshot,
			liveRevision = result.liveRevision,
			lastApplySource = result.lastApplySource,
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
	}
	notifyListeners()
end

return AvatarAppearanceClient
