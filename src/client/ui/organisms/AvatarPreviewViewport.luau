local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local GlassButton = require(script.Parent.Parent.atoms.GlassButton)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)
local PreviewState = require(script.Parent.Parent.Parent.logic.PreviewState)
local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)

local LOCAL_PLAYER = Players.LocalPlayer
local INITIAL_RIG_YAW = math.rad(180)
local DRAG_ROTATION_SPEED = 0.011
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

local function addAssetToBucket(buckets, propertyName: string, assetId: number)
	local bucket = buckets[propertyName]
	if not bucket then
		bucket = {}
		buckets[propertyName] = bucket
	end

	table.insert(bucket, assetId)
end

local function getItemBuckets(items)
	local buckets = {}

	for _, item in pairs(items) do
		if item.bundleAssets then
			for _, bAsset in ipairs(item.bundleAssets) do
				if bAsset.propertyName then
					addAssetToBucket(buckets, bAsset.propertyName, bAsset.id)
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

	for propertyName, bucket in pairs(buckets) do
		table.sort(bucket)
	end

	return buckets
end

local function sameAssetIds(left: { number }?, right: { number }?): boolean
	left = left or {}
	right = right or {}

	if #left ~= #right then
		return false
	end

	for index, assetId in ipairs(left) do
		if right[index] ~= assetId then
			return false
		end
	end

	return true
end

local function getTouchedProperties(previewItems, appliedItems)
	local previewBuckets = getItemBuckets(previewItems)
	local appliedBuckets = getItemBuckets(appliedItems)
	local touchedProperties = {}

	for propertyName, previewAssetIds in pairs(previewBuckets) do
		if not sameAssetIds(previewAssetIds, appliedBuckets[propertyName]) then
			touchedProperties[propertyName] = true
		end
	end

	for propertyName, appliedAssetIds in pairs(appliedBuckets) do
		if not sameAssetIds(appliedAssetIds, previewBuckets[propertyName]) then
			touchedProperties[propertyName] = true
		end
	end

	return touchedProperties, previewBuckets, appliedBuckets
end




local function prepareRig(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			if descendant.Name == "Animate" then
				descendant.Disabled = true
			else
				descendant:Destroy()
			end
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function pivotRig(model: Model, yaw: number?)
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		model.PrimaryPart = humanoidRootPart
	end

	model:PivotTo(CFrame.Angles(0, yaw or INITIAL_RIG_YAW, 0))
end

local function frameCamera(camera: Camera, model: Model)
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	local center = boundingCFrame.Position
	local height = math.max(boundingSize.Y, 5)
	local width = math.max(boundingSize.X, boundingSize.Z, 3)
	local distance = math.max(height * 2.65, width * 3.1, 13)
	local target = center + Vector3.new(0, height * 0.04, 0)
	local cameraPosition = target + Vector3.new(0, height * 0.04, distance)

	camera.CFrame = CFrame.new(cameraPosition, target)
end

local function playIdleAnimation(model: Model, previewItems)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

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

	local previewEmoteAssetId = nil
	if previewItems then
		local buckets = getItemBuckets(previewItems)
		if buckets["EmoteAnimation"] and #buckets["EmoteAnimation"] > 0 then
			previewEmoteAssetId = buckets["EmoteAnimation"][#buckets["EmoteAnimation"]]
		end
	end

	if previewEmoteAssetId then
		local animation = Instance.new("Animation")
		animation.Name = "CatalogPreviewEmote"
		animation.AnimationId = "rbxassetid://" .. tostring(previewEmoteAssetId)

		local ok, trackOrError = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if ok then
			local track = trackOrError
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.2, 1, 1)
		else
			warn("[CatalogPreview] Failed to play emote animation:", trackOrError)
		end

		animation:Destroy()
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = "CatalogPreviewIdle"
	
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

local function cloneLocalCharacter(): Model?
	local character = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
	if not character then
		return nil
	end

	if not character:FindFirstChildOfClass("Humanoid") then
		character:WaitForChild("Humanoid", 5)
	end

	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", 5)
	end

	local previousArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = previousArchivable

	if clone then
		clone.Name = "CatalogPreviewRig"
		prepareRig(clone)
		pivotRig(clone)
	end

	return clone
end

local function applyPreviewDescription(rig: Model, previewItems, appliedItems, camera: Camera)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local description = humanoid:GetAppliedDescription()
	local touchedProperties, previewBuckets, appliedBuckets = getTouchedProperties(previewItems, appliedItems)

	if next(touchedProperties) == nil then
		print(
			"[CatalogPreview] Viewport has no touched appearance properties; keeping clone intact."
		)
		return
	end

	local touchedNames = {}
	for propertyName in pairs(touchedProperties) do
		table.insert(touchedNames, propertyName)
	end
	table.sort(touchedNames)
	print("[CatalogPreview] Viewport applying touched properties:", table.concat(touchedNames, ","))

	local accessories = description:GetAccessories(true)
	local accessoriesModified = false

	for propertyName in pairs(touchedProperties) do
		local currentValue
		local success = pcall(function() currentValue = description[propertyName] end)
		
		if success and type(currentValue) == "number" then
			-- 2D Clothing (Shirt, Pants, GraphicTShirt) & Body Parts (Head, Torso, LeftArm, etc)
			local assetIds = previewBuckets[propertyName]
			if not assetIds or #assetIds == 0 then
				assetIds = appliedBuckets[propertyName] or {}
			end
			description[propertyName] = assetIds[#assetIds] or 0
		else
			local accType = PROPERTY_TO_ACCESSORY_TYPE[propertyName]
			if accType then
				accessoriesModified = true
				-- Remove old
				for i = #accessories, 1, -1 do
					if accessories[i].AccessoryType == accType then
						table.remove(accessories, i)
					end
				end
				-- Add new (or restore applied)
				local newIds = previewBuckets[propertyName]
				if not newIds or #newIds == 0 then
					newIds = appliedBuckets[propertyName] or {}
				end
				
				for _, assetId in ipairs(newIds) do
					table.insert(accessories, {
						AccessoryType = accType,
						AssetId = assetId,
						Order = 1,
					})
				end
			end
		end
	end

	if accessoriesModified then
		description:SetAccessories(accessories, true)
	end

	local ok, err = pcall(function()
		humanoid:ApplyDescription(description)
	end)

	if not ok then
		warn("[CatalogPreview] Failed to apply viewport description:", err)
	end

	task.defer(function()
		if rig.Parent then
			prepareRig(rig)
			pivotRig(rig)
			frameCamera(camera, rig)
			playIdleAnimation(rig, previewItems)
		end
	end)
end

local function setupViewport(
	viewport: ViewportFrame,
	previewItems,
	appliedItems,
	shouldApplyPreview: boolean
)
	viewport:ClearAllChildren()

	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = 31
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "PreviewWorld"
	worldModel.Parent = viewport

	local rig = cloneLocalCharacter()
	if not rig then
		return nil
	end

	rig.Parent = worldModel
	frameCamera(camera, rig)
	if shouldApplyPreview then
		applyPreviewDescription(rig, previewItems, appliedItems, camera)
	end
	playIdleAnimation(rig, previewItems)

	return rig
end

local function isPrimaryDragInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isDragMoveInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function AvatarPreviewViewport()
	local viewportRef = React.useRef(nil)
	local rigRef = React.useRef(nil)
	local draggingRef = React.useRef(false)
	local lastDragXRef = React.useRef(0)
	local yawRef = React.useRef(INITIAL_RIG_YAW)
	local previewItems = usePreviewState()
	local appliedItems = PreviewState.getAppliedItems()
	local isHydrated = PreviewState.hasHydrated()
	local isDirty = PreviewState.isDirty()
	local previewKeyParts = {}

	for itemId, item in pairs(previewItems) do
		if item.bundleAssets then
			local bKeys = {}
			for _, b in ipairs(item.bundleAssets) do
				table.insert(bKeys, b.id)
			end
			table.insert(previewKeyParts, `{itemId}:bundle:{table.concat(bKeys, ",")}`)
		else
			table.insert(previewKeyParts, `{itemId}:{item.propertyName or "nil"}`)
		end
	end
	table.sort(previewKeyParts)

	local previewKey = table.concat(previewKeyParts, "|")

	React.useEffect(function()
		if PreviewState.hasHydrated() then
			return nil
		end

		task.spawn(function()
			local callSuccess, response = pcall(function()
				return ApplyAvatarRemote:InvokeServer({
					action = "GetEquipped",
				})
			end)

			if callSuccess and type(response) == "table" and response.success then
				if response.equippedItems then
					PreviewState.hydrateAppliedItems(response.equippedItems)
					if response.originalItems then
						PreviewState.hydrateOriginalItems(response.originalItems)
					end
				else
					PreviewState.hydrateAppliedAssetIds(response.equippedItemIds or {})
				end
			elseif callSuccess and type(response) == "table" then
				warn("[CatalogPreview] Failed to load equipped snapshot:", response.message)
			else
				warn("[CatalogPreview] Failed to request equipped snapshot:", response)
			end
		end)

		return nil
	end, {})

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return nil
		end

		yawRef.current = INITIAL_RIG_YAW
		rigRef.current = setupViewport(viewport, previewItems, appliedItems, isHydrated)

		return function()
			rigRef.current = nil
			if viewport then
				viewport:ClearAllChildren()
			end
		end
	end, { previewKey, isHydrated })

	local beginDrag = React.useCallback(function(_, input)
		if not isPrimaryDragInput(input) then
			return
		end

		draggingRef.current = true
		lastDragXRef.current = input.Position.X
	end, {})

	local updateDrag = React.useCallback(function(_, input)
		if not draggingRef.current or not isDragMoveInput(input) then
			return
		end

		local nextX = input.Position.X
		local deltaX = nextX - lastDragXRef.current
		lastDragXRef.current = nextX
		yawRef.current += deltaX * DRAG_ROTATION_SPEED

		local rig = rigRef.current
		if rig then
			pivotRig(rig, yawRef.current)
		end
	end, {})

	local endDrag = React.useCallback(function(_, input)
		if isPrimaryDragInput(input) then
			draggingRef.current = false
		end
	end, {})

	return React.createElement("Frame", {
		BackgroundColor3 = Theme.Color.Panel,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, Theme.Radius.Panel),
		}),

		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, Theme.Space.MD),
			PaddingBottom = UDim.new(0, Theme.Space.MD),
			PaddingLeft = UDim.new(0, Theme.Space.MD),
			PaddingRight = UDim.new(0, Theme.Space.MD),
		}),

		Stage = React.createElement("Frame", {
			BackgroundColor3 = Theme.Color.PanelSoft,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 11,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.LG),
			}),

			Gradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Theme.Color.Background),
				}),
				Rotation = 90,
			}),

			Viewport = React.createElement("ViewportFrame", {
				Active = true,
				Ambient = Color3.fromRGB(210, 210, 220),
				BackgroundTransparency = 1,
				LightColor = Color3.fromRGB(255, 255, 255),
				LightDirection = Vector3.new(-0.5, -0.9, -0.4),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 12,
				ref = viewportRef,

				[React.Event.InputBegan] = beginDrag,
				[React.Event.InputChanged] = updateDrag,
				[React.Event.InputEnded] = endDrag,
			}),

			ResetArea = next(previewItems) ~= nil and React.createElement("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -Theme.Space.MD, 0, Theme.Space.MD),
				Size = UDim2.fromOffset(48, 48),
				BackgroundTransparency = 1,
				ZIndex = 13,
			}, {
				ResetButton = React.createElement(GlassButton, {
					icon = Icons.Reset,
					color = Theme.Color.TextSecondary,
					size = UDim2.fromScale(1, 1),
					onActivated = function()
						PreviewState.resetPreviewToOriginal()
					end,
				}),
			}),

			ActionArea = isDirty and React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -Theme.Space.XL),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -(Theme.Space.XL * 2), 0, 48),
				ZIndex = 13,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, Theme.Space.MD),
				}),

				ApplyButton = React.createElement(GlassButton, {
					text = "Apply",
					icon = Icons.Apply,
					color = Theme.Color.TextPrimary,
					size = UDim2.fromScale(1, 1),
					onActivated = function()
						if not PreviewState.hasHydrated() then
							warn("[CatalogPreview] Ignore apply until equipped snapshot is loaded.")
							return
						end

						local assetIds = PreviewState.getDesiredAssetIds()
						print(
							"[CatalogPreview] Sending apply request to server for desired items..."
						)

						task.spawn(function()
							local callSuccess, response = pcall(function()
								return ApplyAvatarRemote:InvokeServer({
									itemIds = assetIds,
								})
							end)

							if callSuccess and type(response) == "table" then
								if response.success then
									if response.equippedItems then
										PreviewState.hydrateAppliedItems(response.equippedItems)
									else
										PreviewState.hydrateAppliedAssetIds(
											response.equippedItemIds or assetIds
										)
									end
									print(
										"[CatalogPreview] Server accepted apply:",
										response.message
									)
								else
									warn(
										"[CatalogPreview] Server rejected apply:",
										response.message
									)
								end
							else
								warn(
									"[CatalogPreview] Failed to communicate with server:",
									response
								)
							end
						end)
					end,
				}),
			}),
		}),
	})
end

return AvatarPreviewViewport
