local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local Icon = require(script.Parent.Parent.atoms.Icon)
local GradientButton = require(script.Parent.Parent.atoms.GradientButton)
local AvatarTemplateTypes = require(ReplicatedStorage.Shared.types.AvatarTemplateTypes)

local TemplateThumbnailGenerator =
	require(script.Parent.Parent.Parent.services.TemplateThumbnailGenerator)

export type AvatarTemplateCardProps = {
	templateData: AvatarTemplateTypes.AvatarTemplateCardData,
	isLoading: boolean?,
	onLoad: (templateId: string) -> (),
	layoutOrder: number?,
	pageToken: string?,
}

local function AvatarTemplateCard(props: AvatarTemplateCardProps)
	local isHovered, setIsHovered = React.useState(false)
	local data = props.templateData
	local isApplying, setIsApplying = React.useState(false)
	local thumbnailState, setThumbnailState = React.useState("loading")
	local skeletonOffsetBinding, setSkeletonOffsetBinding = React.useBinding(0)
	local viewportRef = React.useRef(nil)

	React.useEffect(function()
		if thumbnailState ~= "loading" then
			return nil
		end

		local connection = RunService.RenderStepped:Connect(function()
			local newOffset = (tick() * 1.5) % 2 - 1
			setSkeletonOffsetBinding(newOffset)
		end)

		return function()
			connection:Disconnect()
		end
	end, { thumbnailState })

	React.useEffect(function()
		local active = true
		setThumbnailState("loading")

		if viewportRef.current and data.descriptionSnapshot then
			TemplateThumbnailGenerator.renderTemplateCard(
				data.templateId or data.userOutfitId or tostring(data.name),
				data.descriptionSnapshot,
				viewportRef.current,
				{
					pageToken = props.pageToken,
					onRendered = function()
						if active then
							setThumbnailState("ready")
						end
					end,
					onFailed = function()
						if active then
							setThumbnailState("failed")
						end
					end,
				}
			)
		else
			setThumbnailState("failed")
		end

		return function()
			active = false
		end
	end, { data.templateId, data.userOutfitId, data.descriptionSnapshot, props.pageToken })

	local function ThumbnailPlaceholder()
		local isFailed = thumbnailState == "failed"

		return React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(235, 238, 245),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 3,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.MD),
			}),
			UIGradient = if isFailed
				then nil
				else React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 238, 245)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(245, 247, 250)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 238, 245)),
					}),
					Rotation = 45,
					Offset = skeletonOffsetBinding:map(function(offset)
						return Vector2.new(offset, 0)
					end),
				}),
			Icon = if isFailed
				then React.createElement(Icon, {
					image = Icons.Avatar or "rbxassetid://0",
					size = 42,
					color = Theme.Color.TextMuted,
				})
				else nil,
			Layout = if isFailed
				then React.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				})
				else nil,
		})
	end

	local codeText = if data.code
		then "#" .. data.code
		elseif data.sourceType == "roblox_outfit" then "OUTFIT"
		else ""

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromOffset(248, 342), -- Taller for portrait thumbnail
			BackgroundColor3 = Theme.Color.Panel,
			LayoutOrder = props.layoutOrder,
			Active = true,
			[React.Event.MouseEnter] = function()
				setIsHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setIsHovered(false)
			end,
		},
		React.createElement(React.Fragment, nil, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.LG),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = isHovered and Theme.Color.Purple or Theme.Color.Border,
				Thickness = isHovered and 2 or 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),

			-- 1. Image Area
			ImageContainer = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 218), -- Portrait height (218 + 8 + 22 + 8 + 14 + 8 + 40 + 24 = 342)
				BackgroundTransparency = 1, -- No background as requested
				LayoutOrder = 1,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, Theme.Radius.MD),
				}),
				Viewport = React.createElement("ViewportFrame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 2,
					LightColor = Color3.fromRGB(255, 255, 255),
					Ambient = Color3.fromRGB(200, 200, 200),
					LightDirection = Vector3.new(-1, -1, -1),
					ref = viewportRef,
				}),
				ThumbnailPlaceholder = if thumbnailState ~= "ready"
					then ThumbnailPlaceholder()
					else nil,
			}),

			-- 2. Item Name
			ItemName = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = data.name,
				TextColor3 = Theme.Color.TextPrimary,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.CardTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 2,
			}),

			-- 3. Code & Creator Area
			MetaRow = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 5),
				}),
				CodeLabel = React.createElement("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					BackgroundTransparency = 1,
					Text = codeText,
					TextColor3 = Theme.Color.Success,
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.CardTitle,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
				}),
				CreatorLabel = React.createElement("TextLabel", {
					Size = UDim2.new(1, -40, 1, 0),
					BackgroundTransparency = 1,
					Text = "by " .. (data.creatorUsername or data.ownerUsername or "Unknown"),
					TextColor3 = Theme.Color.TextSecondary,
					Font = Theme.Font.Regular,
					TextSize = Theme.Text.Caption,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 2,
				}),
			}),

			-- 4. Action Buttons
			ActionRow = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 4,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				LoadButton = React.createElement(GradientButton, {
					text = if isApplying
						then "Applying..."
						elseif props.isLoading then "Loading..."
						else "Load",
					size = UDim2.new(1, -4, 1, 0),
					disabled = props.isLoading or isApplying,
					layoutOrder = 1,
					onActivated = function()
						if not props.isLoading and not isApplying then
							setIsApplying(true)
							local id = if data.sourceType == "roblox_outfit"
								then data.userOutfitId
								else data.templateId
							props.onLoad(id)

							task.delay(1, function()
								setIsApplying(false)
							end)
						end
					end,
				}),
				-- ShareButton = React.createElement(GradientButton, {
				-- 	text = "Share",
				-- 	size = UDim2.new(0.5, -4, 1, 0),
				-- 	disabled = false,
				-- 	layoutOrder = 2,
				-- 	onActivated = function()
				-- 		print("[AvatarLoader] Share Template Code:", data.code)
				-- 	end,
				-- }),
			}),
		})
	)
end

return AvatarTemplateCard
