local Players = game:GetService("Players")

local ViewportAnimationController = {}

local currentViewportTrack = nil
local currentLiveTrack = nil
local currentAnimationAssetId = nil
local playbackRevision = 0

local function stopTrack(track)
	if not track then
		return
	end

	pcall(function()
		track:Stop(0)
	end)

	pcall(function()
		track:Destroy()
	end)
end

function ViewportAnimationController.stopViewportAnimation()
	stopTrack(currentViewportTrack)
	currentViewportTrack = nil
end

function ViewportAnimationController.stopLiveAnimation()
	stopTrack(currentLiveTrack)
	currentLiveTrack = nil
end

function ViewportAnimationController.stopAll()
	ViewportAnimationController.stopViewportAnimation()
	ViewportAnimationController.stopLiveAnimation()
	currentAnimationAssetId = nil
	playbackRevision += 1
end

function ViewportAnimationController.playViewportEmote(assetId: number)
	ViewportAnimationController.stopViewportAnimation()

	local AvatarPreviewController = require(script.Parent.AvatarPreviewController)
	local humanoid = AvatarPreviewController.getViewportHumanoid()
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(assetId)

	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if ok then
		currentViewportTrack = trackOrErr
		currentViewportTrack.Looped = true
		currentViewportTrack.Priority = Enum.AnimationPriority.Action
		currentViewportTrack:Play()
	else
		warn("[ViewportAnimationController] Failed to play viewport emote:", trackOrErr)
	end

	pcall(function()
		animation:Destroy()
	end)
end

function ViewportAnimationController.playLiveEmote(assetId: number)
	ViewportAnimationController.stopLiveAnimation()

	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(assetId)

	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if ok then
		currentLiveTrack = trackOrErr
		currentLiveTrack.Looped = true
		currentLiveTrack.Priority = Enum.AnimationPriority.Action
		currentLiveTrack:Play()
	else
		warn("[ViewportAnimationController] Failed to play live emote:", trackOrErr)
	end

	pcall(function()
		animation:Destroy()
	end)
end

function ViewportAnimationController.playEmote(assetId: number)
	currentAnimationAssetId = assetId
	playbackRevision += 1
	ViewportAnimationController.playViewportEmote(assetId)
	ViewportAnimationController.playLiveEmote(assetId)
end

function ViewportAnimationController.onViewportRigRebuilt()
	ViewportAnimationController.stopViewportAnimation()
end

function ViewportAnimationController.onLiveCharacterRemoving()
	ViewportAnimationController.stopLiveAnimation()
end

return ViewportAnimationController
