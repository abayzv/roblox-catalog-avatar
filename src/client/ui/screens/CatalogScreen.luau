local React = require(game:GetService("ReplicatedStorage").Packages.React)

local Theme = require(script.Parent.Parent.theme.Theme)

local function CatalogScreen()
	return React.createElement("Frame", {
		Name = "CatalogScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		CatalogPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.Color.Panel,
			Position = UDim2.new(0, 72, 0.5, 0),
			Size = UDim2.new(0, 858, 1, -8),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.Panel),
			}),

			Stroke = React.createElement("UIStroke", {
				Color = Theme.Color.Border,
				Thickness = 1,
			}),

			Padding = React.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, Theme.Space.XL),
				PaddingLeft = UDim.new(0, Theme.Space.XL),
				PaddingRight = UDim.new(0, Theme.Space.XL),
				PaddingTop = UDim.new(0, Theme.Space.XL),
			}),

			Title = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme.Font.Bold,
				Size = UDim2.new(1, 0, 0, 32),
				Text = "Item Catalog",
				TextColor3 = Theme.Color.TextPrimary,
				TextSize = Theme.Text.ScreenTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	})
end

return CatalogScreen
