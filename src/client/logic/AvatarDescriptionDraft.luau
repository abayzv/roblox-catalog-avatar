local AvatarDescriptionDraft = {}

local HumanoidDescriptionSerializer = require(game:GetService("ReplicatedStorage").Shared.avatar.HumanoidDescriptionSerializer)

function AvatarDescriptionDraft.applyPayloadToSnapshot(snapshot: any, payload: any): any
	local desc = HumanoidDescriptionSerializer.deserialize(snapshot)
	
	if payload.propertyName and payload.assetIds then
		local ok, err = pcall(function()
			local currentValue = (desc :: any)[payload.propertyName]
			if type(currentValue) == "string" then
				if payload.action == "remove" then
					(desc :: any)[payload.propertyName] = ""
				else
					local values = {}
					for _, id in ipairs(payload.assetIds) do
						table.insert(values, tostring(id))
					end
					(desc :: any)[payload.propertyName] = table.concat(values, ",")
				end
			else
				if payload.action == "remove" then
					(desc :: any)[payload.propertyName] = 0
				else
					(desc :: any)[payload.propertyName] = payload.assetIds[#payload.assetIds] or 0
				end
			end
		end)
		
		if not ok then
			-- It might be a layered clothing pseudo-property (like "JacketAccessory")
			local accessoryName = payload.propertyName:gsub("Accessory", "")
			if accessoryName == "Shoulders" then accessoryName = "Shoulder" end
			local enumSuccess, enumItem = pcall(function() return Enum.AccessoryType[accessoryName] end)
			
			if enumSuccess and enumItem then
				local accs = desc:GetAccessories(true)
				for i = #accs, 1, -1 do
					if accs[i].AccessoryType == enumItem then
						table.remove(accs, i)
					end
				end
				if payload.action ~= "remove" then
					for i, assetId in ipairs(payload.assetIds) do
						table.insert(accs, {
							AccessoryType = enumItem,
							AssetId = assetId,
							IsLayered = true,
							Order = i
						})
					end
				end
				desc:SetAccessories(accs, true)
			else
				warn("Failed to set property", payload.propertyName, "err:", err)
			end
		end
	end
	
	if payload.bodyParts then
		for partName, assetId in pairs(payload.bodyParts) do
			local ok, err = pcall(function()
				(desc :: any)[partName] = if payload.action == "remove" then 0 else assetId
			end)
			if not ok then warn("Failed to set body part", partName, "err:", err) end
		end
	end
	
	if payload.animations then
		for animName, assetId in pairs(payload.animations) do
			local ok, err = pcall(function()
				(desc :: any)[animName] = if payload.action == "remove" then 0 else assetId
			end)
			if not ok then warn("Failed to set animation", animName, "err:", err) end
		end
	end
	
	local nextSnapshot = HumanoidDescriptionSerializer.serialize(desc)
	return nextSnapshot
end

return AvatarDescriptionDraft
