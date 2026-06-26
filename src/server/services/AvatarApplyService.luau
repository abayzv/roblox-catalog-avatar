local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local AvatarAppearanceService = require(script.Parent.AvatarAppearanceService)

local AvatarApplyService = {}

function AvatarApplyService.init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			-- Wait a short time for humanoid to be fully ready
			task.delay(0.5, function()
				if character.Parent then
					AvatarAppearanceService.reapplyLiveSnapshot(player)
				end
			end)
		end)
	end)

	ApplyAvatarRemote.OnServerInvoke = function(player: Player, payload: any)
		if type(payload) == "table" and (payload.action == "ApplyDescription" or payload.action == "TryOnDescription") then
			local ok, err = AvatarAppearanceService.applyDescriptionSnapshot(player, payload.description, "catalog_try_on")
			if not ok then
				return {
					success = false,
					code = err == "APPLY_IN_PROGRESS" and "APPLY_IN_PROGRESS" or "APPLY_ERROR",
					message = err,
				}
			end
			
			return {
				success = true,
				liveSnapshot = AvatarAppearanceService.getLiveSnapshot(player),
				liveRevision = AvatarAppearanceService.getLiveRevision(player),
				source = "catalog_try_on",
			}
		end

		return { success = false, message = "Unknown action" }
	end
end

return AvatarApplyService
