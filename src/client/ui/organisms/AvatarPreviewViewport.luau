local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local GlassButton = require(script.Parent.Parent.atoms.GlassButton)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)
local PreviewState = require(script.Parent.Parent.Parent.logic.PreviewState)
local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local PreviewAppliers = require(script.Parent.Parent.Parent.logic.PreviewAppliers)

local LOCAL_PLAYER = Players.LocalPlayer
local INITIAL_RIG_YAW = math.rad(180)
local DRAG_ROTATION_SPEED = 0.011




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

	return clone
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
	local cameraRef = React.useRef(nil)
	local updateVersionRef = React.useRef(0)
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

	-- Mount/Unmount effect to create persistent Viewport instances
	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then return end

		viewport:ClearAllChildren()

		local camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = 31
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		cameraRef.current = camera

		local worldModel = Instance.new("WorldModel")
		worldModel.Name = "PreviewWorld"
		worldModel.Parent = viewport

		return function()
			if rigRef.current then
				rigRef.current:Destroy()
			end
			rigRef.current = nil
			cameraRef.current = nil
			viewport:ClearAllChildren()
		end
	end, {})

	-- Update effect to apply descriptions when state changes
	React.useEffect(function()
		if not isHydrated then return end

		local viewport = viewportRef.current
		local camera = cameraRef.current
		
		if viewport and camera then
			yawRef.current = INITIAL_RIG_YAW
			
			local currentVersion = updateVersionRef.current + 1
			updateVersionRef.current = currentVersion
			
			task.spawn(function()
				-- 1. Clone fresh rig
				local newRig = cloneLocalCharacter()
				if not newRig then return end
				
				-- 2. Parent to Workspace first (hidden) for physics/welding of layered clothing
				newRig:PivotTo(CFrame.new(0, 10000, 0))
				newRig.Parent = workspace
				
				-- 3. Build & apply description
				local humanoid = newRig:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					newRig:Destroy()
					return
				end
				
				local description = humanoid:GetAppliedDescription()
				
				local previewBuckets = PreviewAppliers.getItemBuckets(previewItems)
				local appliedBuckets = PreviewAppliers.getItemBuckets(appliedItems)
				
				PreviewAppliers.applyBodyParts(description, previewBuckets, appliedBuckets)
				PreviewAppliers.applyAccessories(description, previewBuckets, appliedBuckets)
				
				local ok, err = pcall(function()
					humanoid:ApplyDescription(description)
				end)
				if not ok then
					warn("[CatalogPreview] Failed to apply description:", err)
				end
				
				-- If another update started while we were yielding, discard this rig
				if updateVersionRef.current ~= currentVersion then
					newRig:Destroy()
					return
				end
				
				-- 4. Apply classic clothing manual (after ApplyDescription)
				PreviewAppliers.applyClassicClothing(newRig, previewBuckets, appliedBuckets)
				
				-- 5. Prepare and move to ViewportFrame
				prepareRig(newRig)
				pivotRig(newRig, yawRef.current)
				
				local worldModel = viewport:FindFirstChild("PreviewWorld")
				if worldModel then
					if rigRef.current and rigRef.current.Parent then
						rigRef.current:Destroy()
					end
					
					newRig.Parent = worldModel
					rigRef.current = newRig
					
					frameCamera(camera, newRig)
					
					-- 6. Play animation
					task.spawn(function()
						PreviewAppliers.playAnimation(newRig, previewItems, appliedItems)
					end)
				else
					newRig:Destroy()
				end
			end)
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
