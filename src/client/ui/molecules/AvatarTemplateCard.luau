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
	local data = props.templateData
	
	-- In MVP we use a placeholder icon for thumbnail
	local thumbImage = Icons.Avatar or "rbxassetid://0"
	
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundColor3 = Theme.Color.Surface,
		LayoutOrder = props.layoutOrder,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, Theme.Radius.MD),
		}),
		UIStroke = React.createElement("UIStroke", {
			Color = Theme.Color.Border,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, Theme.Space.MD),
			PaddingBottom = UDim.new(0, Theme.Space.MD),
			PaddingLeft = UDim.new(0, Theme.Space.MD),
			PaddingRight = UDim.new(0, Theme.Space.MD),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Theme.Space.MD),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		
		-- Thumbnail Placeholder
		ThumbnailArea = React.createElement("Frame", {
			Size = UDim2.new(0, 68, 0, 68),
			BackgroundColor3 = Theme.Color.Background,
			LayoutOrder = 1,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.SM),
			}),
			Icon = React.createElement(Icon, {
				image = thumbImage,
				size = 32,
				color = Theme.Color.TextMuted,
			}),
		}),
		
		-- Info Area
		InfoArea = React.createElement("Frame", {
			Size = UDim2.new(1, -68 - Theme.Space.MD - 100 - Theme.Space.MD, 1, 0), -- 100 is button width
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			NameLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = data.name,
				TextColor3 = Theme.Color.TextPrimary,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.BodyStrong,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
			CreatorLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "by @" .. data.creatorUsername,
				TextColor3 = Theme.Color.TextMuted,
				Font = Theme.Font.Regular,
				TextSize = Theme.Text.Caption,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),
			CodeLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = data.code,
				TextColor3 = Theme.Color.Purple,
				Font = Theme.Font.Medium,
				TextSize = Theme.Text.Caption,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 3,
			}),
		}),
		
		-- Action Area
		ActionArea = React.createElement("Frame", {
			Size = UDim2.new(0, 100, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			}),
			LoadButton = React.createElement(GradientButton, {
				text = if props.isLoading then "Loading..." else "Load",
				size = UDim2.new(1, 0, 0, 36),
				disabled = props.isLoading,
				onActivated = function()
					if not props.isLoading then
						props.onLoad(data.templateId)
					end
				end,
			}),
		}),
	})
end

return AvatarTemplateCard
