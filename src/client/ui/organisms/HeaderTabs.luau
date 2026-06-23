local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local HeaderTabButton = require(script.Parent.Parent.molecules.HeaderTabButton)

export type HeaderTabsProps = {
	activeTab: string?,
	onTabSelected: ((tab: string) -> ())?,
	layoutOrder: number?,
}

local function HeaderTabs(props: HeaderTabsProps)
	local activeTab = props.activeTab or "Item Catalog"

	return React.createElement(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = props.layoutOrder,
		},
		React.createElement(React.Fragment, nil, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Space.XL), -- 24px gap between tabs and divider
			}),
			TabsContainer = React.createElement(
				"Frame",
				{
					Size = UDim2.new(1, 0, 0, 51),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				},
				React.createElement(React.Fragment, nil, {
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Space.MD), -- 16px gap between the two buttons
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
					}),
					ItemCatalog = React.createElement(HeaderTabButton, {
						text = "Item Catalog",
						icon = Icons.Catalog or "rbxassetid://0",
						active = activeTab == "Item Catalog",
						layoutOrder = 1,
						onActivated = function()
							if props.onTabSelected then
								props.onTabSelected("Item Catalog")
							end
						end,
					}),
					AvatarLoader = React.createElement(HeaderTabButton, {
						text = "Avatar Loader",
						icon = Icons.Avatar or "rbxassetid://0",
						active = activeTab == "Avatar Loader",
						layoutOrder = 2,
						onActivated = function()
							if props.onTabSelected then
								props.onTabSelected("Avatar Loader")
							end
						end,
					}),
				})
			),
			DividerContainer = React.createElement(
				"Frame",
				{
					Size = UDim2.new(1, 0, 0, 3),
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				},
				React.createElement(React.Fragment, nil, {
					-- Full width thin grey line
					GreyLine = React.createElement("Frame", {
						Size = UDim2.new(1, 0, 0, 1),
						Position = UDim2.new(0, 0, 1, -1),
						BackgroundColor3 = Theme.Color.Border,
						BorderSizePixel = 0,
					}),
					-- Active gradient underline
					ActiveUnderline = React.createElement(
						"Frame",
						{
							Size = UDim2.fromOffset(274, 3),
							BackgroundColor3 = Color3.new(1, 1, 1),
							BorderSizePixel = 0,
							Position = UDim2.fromOffset(
								activeTab == "Item Catalog" and 0 or (274 + Theme.Space.MD),
								0
							),
						},
						React.createElement(React.Fragment, nil, {
							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
							UIGradient = React.createElement("UIGradient", {
								Color = Theme.Gradient.Primary,
							}),
						})
					),
				})
			),
		})
	)
end

return HeaderTabs
