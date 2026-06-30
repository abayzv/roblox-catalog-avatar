local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HumanoidDescriptionSerializer =
	require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

local RobloxOutfitConverter = {}

function RobloxOutfitConverter.getSnapshotFromOutfitId(userOutfitId: number): table?
	local success, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromOutfitId(userOutfitId)
	end)

	if success and desc then
		local snapshot = HumanoidDescriptionSerializer.serialize(desc)
		desc:Destroy()
		return snapshot
	end

	warn("[RobloxOutfitConverter] Failed to get HumanoidDescription for outfit", userOutfitId)
	return nil
end

return RobloxOutfitConverter
