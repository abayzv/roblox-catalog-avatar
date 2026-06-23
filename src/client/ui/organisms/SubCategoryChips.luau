local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local SubCategoryChip = require(script.Parent.Parent.molecules.SubCategoryChip)

export type SubCategoryChipsProps = {
	activeSubCategory: string?,
	onSubCategorySelected: ((subcat: string) -> ())?,
	layoutOrder: number?,
}

local SUBCATEGORIES = {
	"Jackets",
	"Pants",
	"Classic Shirts",
	"Classic Pants",
	"Shoes",
	"Hats",
}

local function SubCategoryChips(props: SubCategoryChipsProps)
	local activeSubCategory = props.activeSubCategory or "Jackets"

	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Theme.Space.SM),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for i, subcat in ipairs(SUBCATEGORIES) do
		children[subcat] = React.createElement(SubCategoryChip, {
			text = subcat,
			active = activeSubCategory == subcat,
			layoutOrder = i,
			onActivated = function()
				if props.onSubCategorySelected then
					props.onSubCategorySelected(subcat)
				end
			end,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, React.createElement(React.Fragment, nil, children))
end

return SubCategoryChips
