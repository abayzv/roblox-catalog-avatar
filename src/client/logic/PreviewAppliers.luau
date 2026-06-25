local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)

local PreviewAppliers = {}

local ACCESSORY_TYPE_TO_PROPERTY = {
	[Enum.AccessoryType.Back] = "BackAccessory",
	[Enum.AccessoryType.Face] = "FaceAccessory",
	[Enum.AccessoryType.Front] = "FrontAccessory",
	[Enum.AccessoryType.Hair] = "HairAccessory",
	[Enum.AccessoryType.Hat] = "HatAccessory",
	[Enum.AccessoryType.Neck] = "NeckAccessory",
	[Enum.AccessoryType.Shoulder] = "ShouldersAccessory",
	[Enum.AccessoryType.Waist] = "WaistAccessory",
	[Enum.AccessoryType.TShirt] = "TShirtAccessory",
	[Enum.AccessoryType.Shirt] = "ShirtAccessory",
	[Enum.AccessoryType.Pants] = "PantsAccessory",
	[Enum.AccessoryType.Jacket] = "JacketAccessory",
	[Enum.AccessoryType.Sweater] = "SweaterAccessory",
	[Enum.AccessoryType.Shorts] = "ShortsAccessory",
	[Enum.AccessoryType.LeftShoe] = "LeftShoeAccessory",
	[Enum.AccessoryType.RightShoe] = "RightShoeAccessory",
	[Enum.AccessoryType.DressSkirt] = "DressSkirtAccessory",
	[Enum.AccessoryType.Eyebrow] = "EyebrowAccessory",
	[Enum.AccessoryType.Eyelash] = "EyelashAccessory",
}

local PROPERTY_TO_ACCESSORY_TYPE = {}
for accType, propName in pairs(ACCESSORY_TYPE_TO_PROPERTY) do
	PROPERTY_TO_ACCESSORY_TYPE[propName] = accType
end

local IDLE_ANIMATION_BY_RIG_TYPE = {
	[Enum.HumanoidRigType.R6] = "rbxassetid://180435571",
	[Enum.HumanoidRigType.R15] = "rbxassetid://507766666",
}

local CLOTHING_PROPERTIES = { Shirt = true, Pants = true, GraphicTShirt = true }

-- Client-side cache for resolved asset IDs (Template IDs / Animation IDs)
local resolvedAssetCache = {}

-- Utility: Resolve catalog ID to actual template/animation ID using server
local function resolveAssetId(catalogAssetId: number)
	if resolvedAssetCache[catalogAssetId] then
		return resolvedAssetCache[catalogAssetId]
	end

	local callSuccess, response = pcall(function()
		return ApplyAvatarRemote:InvokeServer({
			action = "ResolvePreviewAsset",
			assetId = catalogAssetId
		})
	end)

	if callSuccess and type(response) == "table" and response.success then
		local result = response.result
		resolvedAssetCache[catalogAssetId] = result
		return result
	end

	warn("[PreviewAppliers] Failed to resolve asset ID:", catalogAssetId)
	return nil
end

local function addAssetToBucket(buckets, propertyName: string, assetId: number)
	local bucket = buckets[propertyName]
	if not bucket then
		bucket = {}
		buckets[propertyName] = bucket
	end
	table.insert(bucket, assetId)
end

function PreviewAppliers.getItemBuckets(items)
	local buckets = {}
	for _, item in pairs(items) do
		if item.bundleAssets then
			for _, bAsset in ipairs(item.bundleAssets) do
				if bAsset.propertyName then
					addAssetToBucket(buckets, bAsset.propertyName, bAsset.id or tonumber(bAsset.id))
				end
			end
		else
			local assetId = item.assetId or tonumber(item.id)
			local propertyName = item.propertyName
			if assetId and propertyName then
				addAssetToBucket(buckets, propertyName, assetId)
			end
		end
	end
	for _, bucket in pairs(buckets) do
		table.sort(bucket)
	end
	return buckets
end

function PreviewAppliers.applyBodyParts(description: HumanoidDescription, previewBuckets, appliedBuckets)
	-- Body Parts (Head, Torso, LeftArm, etc) & scales
	for propertyName, _ in pairs(previewBuckets) do
		if not PROPERTY_TO_ACCESSORY_TYPE[propertyName] and not CLOTHING_PROPERTIES[propertyName] then
			local success, isNum = pcall(function() return type(description[propertyName]) == "number" end)
			if success and isNum then
				local assetIds = previewBuckets[propertyName]
				if not assetIds or #assetIds == 0 then
					assetIds = appliedBuckets[propertyName] or {}
				end
				description[propertyName] = assetIds[#assetIds] or 0
			end
		end
	end

	-- Also process appliedBuckets to handle removals
	for propertyName, _ in pairs(appliedBuckets) do
		if not previewBuckets[propertyName] and not PROPERTY_TO_ACCESSORY_TYPE[propertyName] and not CLOTHING_PROPERTIES[propertyName] then
			local success, isNum = pcall(function() return type(description[propertyName]) == "number" end)
			if success and isNum then
				description[propertyName] = 0
			end
		end
	end
end

function PreviewAppliers.applyAccessories(description: HumanoidDescription, previewBuckets, appliedBuckets)
	local accessories = description:GetAccessories(true)

	-- We collect all unique property names for accessories involved
	local touchedProps = {}
	for prop, _ in pairs(previewBuckets) do
		if PROPERTY_TO_ACCESSORY_TYPE[prop] then touchedProps[prop] = true end
	end
	for prop, _ in pairs(appliedBuckets) do
		if PROPERTY_TO_ACCESSORY_TYPE[prop] then touchedProps[prop] = true end
	end

	for propertyName in pairs(touchedProps) do
		local accType = PROPERTY_TO_ACCESSORY_TYPE[propertyName]
		
		-- 1. Remove all old accessories of this type
		for i = #accessories, 1, -1 do
			if accessories[i].AccessoryType == accType then
				table.remove(accessories, i)
			end
		end
		
		-- 2. Add new (or restore applied)
		local newIds = previewBuckets[propertyName]
		if not newIds or #newIds == 0 then
			newIds = appliedBuckets[propertyName] or {}
		end
		
		for order, assetId in ipairs(newIds) do
			table.insert(accessories, {
				AccessoryType = accType,
				AssetId = assetId,
				IsLayered = true,
				Order = order,
			})
		end
	end

	description:SetAccessories(accessories, true)
end

function PreviewAppliers.applyClassicClothing(rig: Model, previewBuckets, appliedBuckets)
	for propertyName in pairs(CLOTHING_PROPERTIES) do
		local assetIds = previewBuckets[propertyName]
		if not assetIds or #assetIds == 0 then
			assetIds = appliedBuckets[propertyName] or {}
		end
		local catalogAssetId = assetIds[#assetIds] or 0

		if catalogAssetId == 0 then
			-- Remove clothing
			if propertyName == "Shirt" then
				local existing = rig:FindFirstChildOfClass("Shirt")
				if existing then existing:Destroy() end
			elseif propertyName == "Pants" then
				local existing = rig:FindFirstChildOfClass("Pants")
				if existing then existing:Destroy() end
			elseif propertyName == "GraphicTShirt" then
				local existing = rig:FindFirstChildOfClass("ShirtGraphic")
				if existing then existing:Destroy() end
			end
		else
			-- Resolve catalog ID to template ID via server
			local templateId = resolveAssetId(catalogAssetId)
			if templateId then
				if propertyName == "Shirt" then
					local existing = rig:FindFirstChildOfClass("Shirt")
					if not existing then
						existing = Instance.new("Shirt")
						existing.Parent = rig
					end
					existing.ShirtTemplate = "rbxassetid://" .. templateId
				elseif propertyName == "Pants" then
					local existing = rig:FindFirstChildOfClass("Pants")
					if not existing then
						existing = Instance.new("Pants")
						existing.Parent = rig
					end
					existing.PantsTemplate = "rbxassetid://" .. templateId
				elseif propertyName == "GraphicTShirt" then
					local existing = rig:FindFirstChildOfClass("ShirtGraphic")
					if not existing then
						existing = Instance.new("ShirtGraphic")
						existing.Parent = rig
					end
					existing.Graphic = "rbxassetid://" .. templateId
				end
			end
		end
	end
end

function PreviewAppliers.playAnimation(model: Model, previewItems: table?, appliedItems: table?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == "CatalogPreviewIdle" or track.Name == "CatalogPreviewEmote" then
			track:Stop(0.1)
		end
	end

	local animation = Instance.new("Animation")
	animation.Name = "CatalogPreviewIdle"
	
	local emoteAssetId = nil
	if previewItems then
		for key, item in pairs(previewItems) do
			if item.propertyName == "EmoteAnimation" then
				if not (appliedItems and appliedItems[key]) then
					emoteAssetId = item.assetId or tonumber(item.id)
					break
				end
			elseif item.bundleAssets then
				for _, bAsset in ipairs(item.bundleAssets) do
					if bAsset.propertyName == "EmoteAnimation" then
						if not (appliedItems and appliedItems[key]) then
							emoteAssetId = bAsset.id or tonumber(bAsset.id)
							break
						end
					end
				end
				if emoteAssetId then break end
			end
		end
	end

	if emoteAssetId then
		local resolvedAnimId = resolveAssetId(emoteAssetId)
		if resolvedAnimId then
			animation.AnimationId = type(resolvedAnimId) == "string" and resolvedAnimId or ("rbxassetid://" .. resolvedAnimId)
		else
			animation:Destroy()
			return
		end
	else
		local desc = humanoid:GetAppliedDescription()
		if desc and desc.IdleAnimation and desc.IdleAnimation > 0 then
			local animate = model:FindFirstChild("Animate")
			if animate then
				local idleFolder = animate:FindFirstChild("idle")
				if idleFolder then
					local anim1 = idleFolder:FindFirstChild("Animation1")
					if anim1 and anim1:IsA("Animation") and anim1.AnimationId ~= "" then
						animation.AnimationId = anim1.AnimationId
					end
				end
			end
			
			if animation.AnimationId == "" then
				animation.AnimationId = IDLE_ANIMATION_BY_RIG_TYPE[humanoid.RigType]
					or IDLE_ANIMATION_BY_RIG_TYPE[Enum.HumanoidRigType.R15]
			end
		else
			animation.AnimationId = IDLE_ANIMATION_BY_RIG_TYPE[humanoid.RigType]
				or IDLE_ANIMATION_BY_RIG_TYPE[Enum.HumanoidRigType.R15]
		end
	end

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if ok then
		local track = trackOrError
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play(0.2, 1, 1)
	else
		warn("[CatalogPreview] Failed to play viewport idle animation:", trackOrError)
	end

	animation:Destroy()
end

return PreviewAppliers
