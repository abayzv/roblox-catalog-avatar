local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local Icon = require(script.Parent.Parent.atoms.Icon)
local GradientButton = require(script.Parent.Parent.atoms.GradientButton)
local AvatarTemplateTypes = require(ReplicatedStorage.Shared.types.AvatarTemplateTypes)

export type AvatarTemplateCardProps = {
	templateData: AvatarTemplateTypes.AvatarTemplateCardData,
	isLoading: boolean?,
	onLoad: (templateId: string) -> (),
	layoutOrder: number?,
}

local function AvatarTemplateCard(props: AvatarTemplateCardProps)
	local isHovered, setIsHovered = React.useState(false)
	local data = props.templateData
	local isApplying, setIsApplying = React.useState(false)
	
	-- In MVP we use a placeholder icon for thumbnail
	local thumbImage = Icons.Avatar or "rbxassetid://0"

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromOffset(248, 252), -- Exactly matches guideline
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
			ImageContainer = React.createElement(
				"Frame",
				{
					Size = UDim2.new(1, 0, 0, 128),
					BackgroundColor3 = Theme.Color.PanelHover,
					LayoutOrder = 1,
				},
				{
					UICorner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, Theme.Radius.MD),
					}),
					Thumbnail = React.createElement("ImageLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = data.thumbnailUrl or thumbImage,
						ScaleType = Enum.ScaleType.Fit,
					}),
				}
			),

			-- 2. Title Area
			TitleRow = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
			}, {
				NameLabel = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = data.name,
					TextColor3 = Theme.Color.TextPrimary,
					Font = Theme.Font.SemiBold,
					TextSize = Theme.Text.Body,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
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
					Padding = UDim.new(0, 8),
				}),
				CodeLabel = React.createElement("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					BackgroundTransparency = 1,
					Text = data.code or (data.sourceType == "roblox_outfit" and "OUTFIT") or "",
					TextColor3 = Theme.Color.Primary,
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.Caption,
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

			-- 4. Load Button
			ActionRow = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 4,
			}, {
				LoadButton = React.createElement(GradientButton, {
					text = if isApplying then "Applying..." elseif props.isLoading then "Loading..." else "Load",
					size = UDim2.fromScale(1, 1),
					disabled = props.isLoading or isApplying,
					onActivated = function()
						if not props.isLoading and not isApplying then
							setIsApplying(true)
							local id = if data.sourceType == "roblox_outfit" then data.userOutfitId else data.templateId
							props.onLoad(id)
							
							-- In MVP, reset state after a short delay since onLoad doesn't return a Promise 
							-- (It uses task.spawn internally in the parent, but we can just delay reset)
							task.delay(1, function()
								setIsApplying(false)
							end)
						end
					end,
				}),
			}),
		})
	)
end

return AvatarTemplateCard
