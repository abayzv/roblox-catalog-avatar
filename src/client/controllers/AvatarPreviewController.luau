local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PreviewState = require(script.Parent.Parent.logic.PreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)
local AvatarAppearanceClient = require(script.Parent.Parent.services.AvatarAppearanceClient)
local AvatarDescriptionDraft = require(script.Parent.Parent.logic.AvatarDescriptionDraft)
local TryOnDescriptionRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote) -- using ApplyAvatarRemote with TryOn action

local AvatarPreviewController = {}

function AvatarPreviewController.getViewportHumanoid()
	local localPlayer = game:GetService("Players").LocalPlayer
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local previewWorld = playerGui:FindFirstChild("PreviewWorld", true)
	if not previewWorld then
		return nil
	end

	local rig = previewWorld:FindFirstChild("CatalogPreviewRig")
	if not rig then
		return nil
	end

	return rig:FindFirstChildOfClass("Humanoid")
end

-- This function is called when UI clicks "Try On"
function AvatarPreviewController.ToggleItemPreview(item)
	local state = AvatarAppearanceClient.getState()
	if not state.liveSnapshot then
		warn("[CatalogPreview] Ignore try-on until live snapshot is loaded.")
		return
	end

	local key = item.key
	local payload = PreviewPayloadCache.get(key)

	if payload then
		print("[CatalogPreview] Payload found for:", key)

		if payload.kind == "Emote" then
			local activeEmote = PreviewState.getActiveEmote()
			local ViewportAnimationController = require(script.Parent.ViewportAnimationController)

			if activeEmote and activeEmote.key == payload.key then
				ViewportAnimationController.stopAll()
				PreviewState.setActiveEmote(nil)
			else
				if payload.emoteAnimationId then
					ViewportAnimationController.playEmote(payload.emoteAnimationId)
					PreviewState.setActiveEmote(payload)
				else
					if payload.resolveState == "resolving" then
						return
					end
					PreviewPayloadCache.patch(key, { resolveState = "resolving" })

					task.spawn(function()
						local EmoteAnimationResolver =
							require(script.Parent.Parent.services.EmoteAnimationResolver)
						local success, animationId, err =
							EmoteAnimationResolver.resolveOne(payload.emoteAssetId)
						if success and animationId then
							PreviewPayloadCache.patch(key, {
								resolveState = "ready",
								emoteAnimationId = animationId,
							})
							ViewportAnimationController.playEmote(animationId)
							PreviewState.setActiveEmote(PreviewPayloadCache.get(key))
						else
							PreviewPayloadCache.patch(key, {
								resolveState = "failed",
								resolveError = err,
							})
							warn("[CatalogPreview] Failed to resolve emote animation:", err)
						end
					end)
				end
			end
			return
		end

		-- Stop all animations and clear active emote before appearance mutations
		local ViewportAnimationController = require(script.Parent.ViewportAnimationController)
		ViewportAnimationController.stopAll()
		PreviewState.setActiveEmote(nil)

		local equippedKeys = PreviewState.getEquippedKeys()
		local isEquipped = equippedKeys[key] == true

		local nextPayload = table.clone(payload)
		if isEquipped then
			print("[CatalogPreview] Adding removal payload for equipped item")
			nextPayload.action = "remove"
		else
			print("[CatalogPreview] Adding equip payload")
		end

		-- Build next snapshot
		local nextSnapshot =
			AvatarDescriptionDraft.applyPayloadToSnapshot(state.liveSnapshot, nextPayload)

		-- Set Optimistic State
		local requestId = AvatarAppearanceClient.setOptimisticState(nextSnapshot, "catalog_try_on")

		-- Send live apply request
		task.spawn(function()
			local ok, result = pcall(function()
				return TryOnDescriptionRemote:InvokeServer({
					action = "TryOnDescription",
					description = nextSnapshot,
					revision = state.liveRevision,
				})
			end)

			if ok and result and result.success then
				AvatarAppearanceClient.resolveOptimisticState(
					requestId,
					result.liveSnapshot,
					result.liveRevision,
					result.source
				)
			else
				warn("[CatalogPreview] TryOn failed:", result and result.message or "unknown error")
				AvatarAppearanceClient.rollbackOptimisticState(requestId)
			end
		end)
	else
		warn(`[CatalogPreview] Cannot preview item {key}; payload is not yet cached.`)
	end
end

-- This function is called to reset the character to original appearance
function AvatarPreviewController.ResetPreview()
	-- Handled by resetting original, wait, we don't have a reset remote yet.
	-- We can use TryOnDescriptionRemote with the original snapshot, but the client doesn't know the original snapshot.
	-- We need a ResetRemote, or we can just add a reset remote later.
	warn("Reset to original not yet implemented in Phase 7 UI")
end

function AvatarPreviewController.RemoveWornItem(item)
	local state = AvatarAppearanceClient.getState()
	if not state.liveSnapshot then
		warn("[CatalogPreview] Cannot remove item: live snapshot is not loaded.")
		return
	end

	print("[CatalogPreview] Removing worn item:", item.property, item.id)

	local nextSnapshot = nil
	local BODY_RESTORE_FIELDS = {
		Head = true,
		Torso = true,
		LeftArm = true,
		RightArm = true,
		LeftLeg = true,
		RightLeg = true,
		Face = true,
	}

	if BODY_RESTORE_FIELDS[item.property] and state.originalSnapshot then
		nextSnapshot = table.clone(state.liveSnapshot)
		nextSnapshot[item.property] = state.originalSnapshot[item.property]

		local scales = {
			"BodyTypeScale",
			"DepthScale",
			"HeadScale",
			"HeightScale",
			"ProportionScale",
			"WidthScale",
		}
		for _, scale in ipairs(scales) do
			if state.originalSnapshot[scale] ~= nil then
				nextSnapshot[scale] = state.originalSnapshot[scale]
			end
		end
	else
		local removePayload = {
			action = "remove",
			id = item.id,
			itemType = "Asset",
			propertyName = item.property,
			assetIds = { item.id },
		}
		nextSnapshot =
			AvatarDescriptionDraft.applyPayloadToSnapshot(state.liveSnapshot, removePayload)
	end

	local requestId = AvatarAppearanceClient.setOptimisticState(nextSnapshot, "catalog_remove_worn")

	task.spawn(function()
		local ok, result = pcall(function()
			return TryOnDescriptionRemote:InvokeServer({
				action = "TryOnDescription",
				description = nextSnapshot,
				revision = state.liveRevision,
			})
		end)

		if ok and result and result.success then
			AvatarAppearanceClient.resolveOptimisticState(
				requestId,
				result.liveSnapshot,
				result.liveRevision,
				result.source
			)
		else
			warn("[CatalogPreview] Remove failed:", result and result.message or "unknown error")
			AvatarAppearanceClient.rollbackOptimisticState(requestId)
		end
	end)
end

return AvatarPreviewController
