local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local CategoryButton = require(script.Parent.Parent.molecules.CategoryButton)

export type MainCategoryTabsProps = {
	activeCategory: string?,
	onCategorySelected: ((category: string) -> ())?,
	layoutOrder: number?,
}

local CATEGORIES = {
	{ id = "Clothing", icon = Icons.Clothing },
	{ id = "Accessories", icon = Icons.Accessories },
	{ id = "Body", icon = Icons.Body },
	{ id = "Faces", icon = Icons.Faces },
	{ id = "Animation", icon = Icons.Animation },
	{ id = "Bundles", icon = Icons.Bundles },
}

local function MainCategoryTabs(props: MainCategoryTabsProps)
	local activeCategory = props.activeCategory or "Clothing"

	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Theme.Space.MD),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for i, cat in ipairs(CATEGORIES) do
		children[cat.id] = React.createElement(CategoryButton, {
			text = cat.id,
			icon = cat.icon or "rbxassetid://0",
			active = activeCategory == cat.id,
			layoutOrder = i,
			onActivated = function()
				if props.onCategorySelected then
					props.onCategorySelected(cat.id)
				end
			end,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, React.createElement(React.Fragment, nil, children))
end

return MainCategoryTabs
