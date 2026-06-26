local AvatarDescriptionDraft = {}

local originalDescription: HumanoidDescription? = nil
local appliedDescription: HumanoidDescription? = nil
local draftDescription: HumanoidDescription? = nil
local HumanoidDescriptionSerializer = require(game.ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

function AvatarDescriptionDraft.initializeFromCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local desc = humanoid:GetAppliedDescription()
	if not desc then return end
	
	originalDescription = desc:Clone()
	appliedDescription = desc:Clone()
	draftDescription = desc:Clone()
end

function AvatarDescriptionDraft.getDraftDescription(): HumanoidDescription?
	return draftDescription
end

function AvatarDescriptionDraft.setDraftDescription(description: HumanoidDescription)
	draftDescription = description
end

function AvatarDescriptionDraft.resetDraftToApplied()
	if appliedDescription then
		draftDescription = appliedDescription:Clone()
	end
end

function AvatarDescriptionDraft.markApplied(description: HumanoidDescription)
	appliedDescription = description:Clone()
	draftDescription = description:Clone()
end

function AvatarDescriptionDraft.isDirty(): boolean
	-- Basic dirty check: will be enhanced later, but for now we'll just check if draft was mutated.
	-- Since phase 6 plan says: dirty = true after any Try-On mutation, false after successful server apply/hydration.
	-- For simplicity, we just keep a boolean flag.
	return AvatarDescriptionDraft._dirtyFlag or false
end

function AvatarDescriptionDraft.setDirty(dirty: boolean)
	AvatarDescriptionDraft._dirtyFlag = dirty
end

function AvatarDescriptionDraft.applyPayload(payload: any)
	if not draftDescription then return end
	
	if payload.propertyName and payload.assetIds then
		local ok, err = pcall(function()
			local currentValue = (draftDescription :: any)[payload.propertyName]
			if type(currentValue) == "string" then
				local values = {}
				for _, id in ipairs(payload.assetIds) do
					table.insert(values, tostring(id))
				end
				(draftDescription :: any)[payload.propertyName] = table.concat(values, ",")
			else
				(draftDescription :: any)[payload.propertyName] = payload.assetIds[#payload.assetIds] or 0
			end
		end)
		
		if not ok then
			-- It might be a layered clothing pseudo-property (like "JacketAccessory")
			local accessoryName = payload.propertyName:gsub("Accessory", "")
			if accessoryName == "Shoulders" then accessoryName = "Shoulder" end
			local enumSuccess, enumItem = pcall(function() return Enum.AccessoryType[accessoryName] end)
			
			if enumSuccess and enumItem then
				local accs = draftDescription:GetAccessories(true)
				for i = #accs, 1, -1 do
					if accs[i].AccessoryType == enumItem then
						table.remove(accs, i)
					end
				end
				for i, assetId in ipairs(payload.assetIds) do
					table.insert(accs, {
						AccessoryType = enumItem,
						AssetId = assetId,
						IsLayered = true,
						Order = i
					})
				end
				draftDescription:SetAccessories(accs, true)
			else
				warn("Failed to set property", payload.propertyName, "err:", err)
			end
		end
	end
	
	if payload.bodyParts then
		for partName, assetId in pairs(payload.bodyParts) do
			local ok, err = pcall(function()
				(draftDescription :: any)[partName] = assetId
			end)
			if not ok then warn("Failed to set body part", partName, "err:", err) end
		end
	end
	
	if payload.animations then
		for animName, assetId in pairs(payload.animations) do
			local ok, err = pcall(function()
				(draftDescription :: any)[animName] = assetId
			end)
			if not ok then warn("Failed to set animation", animName, "err:", err) end
		end
	end
	
	AvatarDescriptionDraft.setDirty(true)
end

function AvatarDescriptionDraft.serializeDraft(): table?
	if draftDescription then
		return HumanoidDescriptionSerializer.serialize(draftDescription)
	end
	return nil
end

return AvatarDescriptionDraft
