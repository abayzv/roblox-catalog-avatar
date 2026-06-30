local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

local AvatarAppearanceService = {}

export type AppearanceSnapshot = {
	[string]: any,
}

export type PlayerAppearanceState = {
	originalSnapshot: AppearanceSnapshot?,
	liveSnapshot: AppearanceSnapshot?,
	liveRevision: number,

	isApplying: boolean,
	lastApplySource: string?,
}

local playerStates: { [Player]: PlayerAppearanceState } = {}

local function getOrCreateState(player: Player): PlayerAppearanceState
	if not playerStates[player] then
		playerStates[player] = {
			originalSnapshot = nil,
			liveSnapshot = nil,
			liveRevision = 0,
			isApplying = false,
			lastApplySource = nil,
		}
	end
	return playerStates[player]
end

function AvatarAppearanceService.initializePlayer(player: Player)
	local state = getOrCreateState(player)
	
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		warn("[AvatarAppearanceService] Failed to find Humanoid for", player.Name)
		return
	end

	local desc = humanoid:GetAppliedDescription()
	if not desc then
		warn("[AvatarAppearanceService] No applied description found for", player.Name)
		return
	end

	local snapshot = HumanoidDescriptionSerializer.serialize(desc)
	
	-- Only set originalSnapshot once
	if not state.originalSnapshot then
		state.originalSnapshot = snapshot
	end
	
	state.liveSnapshot = snapshot
	state.liveRevision = 1
	state.lastApplySource = "initial"
	
	print(`[AvatarAppearanceService] Initialized {player.Name} (Revision {state.liveRevision})`)
end

function AvatarAppearanceService.getState(player: Player): PlayerAppearanceState?
	return playerStates[player]
end

function AvatarAppearanceService.getLiveSnapshot(player: Player): AppearanceSnapshot?
	local state = playerStates[player]
	return state and state.liveSnapshot
end

function AvatarAppearanceService.getLiveRevision(player: Player): number
	local state = playerStates[player]
	return state and state.liveRevision or 0
end

function AvatarAppearanceService.applyDescriptionSnapshot(player: Player, snapshot: AppearanceSnapshot, source: string): (boolean, string?)
	local state = getOrCreateState(player)
	
	if state.isApplying then
		return false, "APPLY_IN_PROGRESS"
	end
	
	local valid, err = HumanoidDescriptionSerializer.validateSnapshot(snapshot)
	if not valid then
		return false, "INVALID_SNAPSHOT: " .. tostring(err)
	end
	
	state.isApplying = true
	
	local success, applyErr = pcall(function()
		local character = player.Character
		if not character then error("Character not found") end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then error("Humanoid not found") end
		
		local desc = HumanoidDescriptionSerializer.deserialize(snapshot)
		humanoid:ApplyDescriptionResetAsync(desc, Enum.AssetTypeVerification.Always)
		
		local appliedDesc = humanoid:GetAppliedDescription()
		local appliedSnapshot = HumanoidDescriptionSerializer.serialize(appliedDesc)
		
		state.liveSnapshot = appliedSnapshot
		state.liveRevision += 1
		state.lastApplySource = source
	end)
	
	state.isApplying = false
	
	if success then
		print(`[AvatarAppearanceService] Applied snapshot for {player.Name} (Source: {source}, Revision: {state.liveRevision})`)
		return true, nil
	else
		warn(`[AvatarAppearanceService] Failed to apply snapshot for {player.Name}:`, applyErr)
		return false, tostring(applyErr)
	end
end

function AvatarAppearanceService.applyMorphFromHumanoid(player: Player, sourceHumanoid: Humanoid): (boolean, string?)
	local desc = sourceHumanoid:GetAppliedDescription()
	if not desc then
		return false, "No applied description on source humanoid"
	end
	
	local snapshot = HumanoidDescriptionSerializer.serialize(desc)
	return AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "morph")
end

function AvatarAppearanceService.resetToOriginal(player: Player): (boolean, string?)
	local state = getOrCreateState(player)
	if not state.originalSnapshot then
		return false, "No original snapshot available"
	end
	
	return AvatarAppearanceService.applyDescriptionSnapshot(player, state.originalSnapshot, "reset_original")
end

local function isMorphDetected(originalSnapshot: any, currentSnapshot: any): boolean
	local KEYS = {
		"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
		"Face", "Shirt", "Pants", "GraphicTShirt",
		"HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", 
		"ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory",
		"TShirtAccessory", "ShirtAccessory", "PantsAccessory", "JacketAccessory", 
		"SweaterAccessory", "ShortsAccessory", "DressSkirtAccessory", 
		"LeftShoeAccessory", "RightShoeAccessory",
		"IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", 
		"FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation"
	}
	
	for _, key in ipairs(KEYS) do
		local origVal = tostring(originalSnapshot[key] or "0")
		local currVal = tostring(currentSnapshot[key] or "0")
		
		if origVal == "" then origVal = "0" end
		if currVal == "" then currVal = "0" end
		
		if origVal ~= currVal then
			return true
		end
	end
	
	return false
end

function AvatarAppearanceService.reapplyLiveSnapshot(player: Player)
	local state = getOrCreateState(player)
	if not state.liveSnapshot then
		AvatarAppearanceService.initializePlayer(player)
		return
	end
	
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	
	if state.isApplying then
		warn("[AvatarAppearanceService] Skipping reapply for", player.Name, "- apply already in progress")
		return
	end
	
	-- Auto-detect morph
	local currentDesc = humanoid:GetAppliedDescription()
	if currentDesc and state.originalSnapshot then
		local currentSnapshot = HumanoidDescriptionSerializer.serialize(currentDesc)
		if isMorphDetected(state.originalSnapshot, currentSnapshot) then
			print(`[AvatarAppearanceService] Morph or custom avatar detected on {player.Name}. Aborting catalog reapply.`)
			return
		end
	end
	
	state.isApplying = true
	pcall(function()
		local desc = HumanoidDescriptionSerializer.deserialize(state.liveSnapshot)
		humanoid:ApplyDescriptionResetAsync(desc, Enum.AssetTypeVerification.Always)
	end)
	state.isApplying = false
end

local GetAppearanceStateRemote = require(ReplicatedStorage.Shared.remotes.GetAppearanceStateRemote)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

GetAppearanceStateRemote.OnServerInvoke = function(player: Player)
	local state = playerStates[player]
	if not state then
		-- Initialize if they asked before it was ready
		AvatarAppearanceService.initializePlayer(player)
		state = playerStates[player]
	end
	
	if not state then
		return { success = false, message = "State unavailable" }
	end
	
	return {
		success = true,
		liveSnapshot = state.liveSnapshot,
		liveRevision = state.liveRevision,
		lastApplySource = state.lastApplySource,
	}
end

return AvatarAppearanceService
