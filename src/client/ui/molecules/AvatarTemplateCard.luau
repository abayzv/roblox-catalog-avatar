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
					Size = UDim2.new(1, 0, 0, 124),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				},
				React.createElement(React.Fragment, nil, {
					UIPadding = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),
					ItemImage = React.createElement(Icon, {
						image = thumbImage,
						size = 80,
						color = Theme.Color.TextMuted,
						anchorPoint = Vector2.new(0.5, 0.5),
						position = UDim2.fromScale(0.5, 0.5),
					}),
				})
			),

			-- 2. Template Name
			TemplateName = React.createElement("TextLabel", {
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

			-- 3. Code & Creator Row
			CodeRow = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				CodeTag = React.createElement("TextLabel", {
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = data.code,
					TextColor3 = Theme.Color.Purple,
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.Caption,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
				}),
				CreatorTag = React.createElement("TextLabel", {
					Size = UDim2.new(1, -50, 1, 0),
					BackgroundTransparency = 1,
					Text = "by @" .. data.creatorUsername,
					TextColor3 = Theme.Color.TextMuted,
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
					text = if props.isLoading then "Loading..." else "Load",
					size = UDim2.fromScale(1, 1),
					disabled = props.isLoading,
					onActivated = function()
						if not props.isLoading then
							props.onLoad(data.templateId)
						end
					end,
				}),
			}),
		})
	)
end

return AvatarTemplateCard
