local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local Theme = require(script.Parent.theme.Theme)
local Icons = require(script.Parent.theme.Icons)

local BaseFrame = require(script.Parent.atoms.BaseFrame)
local Text = require(script.Parent.atoms.Text)
local Spacer = require(script.Parent.atoms.Spacer)
local GradientButton = require(script.Parent.atoms.GradientButton)
local IconButton = require(script.Parent.atoms.IconButton)

local function Story()
	return React.createElement(
		"ScrollingFrame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.fromOffset(0, 1000),
			ScrollBarThickness = 6,
		},
		React.createElement(React.Fragment, nil, {
			Layout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 16),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 20),
			}),

			-- 1. BaseFrame & Text
			BaseFrameContainer = React.createElement(
				BaseFrame,
				{
					size = UDim2.fromOffset(260, 100),
					layoutOrder = 1,
					padding = 12,
					strokeColor = Theme.Color.BorderStrong,
					backgroundColor = Theme.Color.Panel,
				},
				React.createElement(React.Fragment, nil, {
					Layout = React.createElement("UIListLayout", {
						Padding = UDim.new(0, 8),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					Title = React.createElement(Text, {
						text = "BaseFrame & Text",
						font = Theme.Font.Bold,
						textSize = Theme.Text.ScreenTitle,
					}),
					Body = React.createElement(Text, {
						text = "Ini adalah deskripsi kecil menggunakan warna TextSecondary.",
						color = Theme.Color.TextSecondary,
						textSize = Theme.Text.Body,
					}),
				})
			),

			-- 2. Spacer Example
			SpacerContainer = React.createElement(
				BaseFrame,
				{
					size = UDim2.fromOffset(260, 60),
					layoutOrder = 2,
					backgroundColor = Theme.Color.PanelSoft,
					strokeColor = Theme.Color.Border,
					padding = 10,
				},
				React.createElement(React.Fragment, nil, {
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					Box1 = React.createElement("Frame", {
						Size = UDim2.fromOffset(30, 30),
						BackgroundColor3 = Theme.Color.Success,
					}),
					Spacer = React.createElement(Spacer, { size = 30 }),
					Box2 = React.createElement("Frame", {
						Size = UDim2.fromOffset(30, 30),
						BackgroundColor3 = Theme.Color.Danger,
					}),
					Spacer2 = React.createElement(Spacer, { size = 30 }),
					Text = React.createElement(Text, { text = "Ada Spacer di kiri" }),
				})
			),

			-- 3. GradientButton
			TryOnButton = React.createElement(GradientButton, {
				text = "Try On",
				size = UDim2.fromOffset(240, 36),
				layoutOrder = 3,
				onActivated = function()
					print("Try On diklik!")
				end,
			}),

			-- 4. GradientButton Disabled
			TryOnDisabled = React.createElement(GradientButton, {
				text = "Buy (Disabled)",
				size = UDim2.fromOffset(240, 36),
				disabled = true,
				layoutOrder = 4,
			}),

			-- 5. IconButton
			FilterBtn = React.createElement(IconButton, {
				icon = Icons.Filter or "rbxassetid://0",
				layoutOrder = 5,
				onActivated = function()
					print("Filter diklik!")
				end,
			}),
		})
	)
end

local story = {
	react = React,
	reactRoblox = ReactRoblox,
	story = Story,
}

return story
