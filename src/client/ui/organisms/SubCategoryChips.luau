local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local SubCategoryChip = require(script.Parent.Parent.molecules.SubCategoryChip)

export type SubCategoryChipsProps = {
	activeMainCategory: string?,
	activeSubCategory: string?,
	onSubCategorySelected: ((subcat: string) -> ())?,
	layoutOrder: number?,
}

local MAIN_TO_SUB = {
	All = {
		"Featured", "Recommended", "Premium"
	},
	Body = {
		"Body Bundles", "Hair", "Head", "Faces"
	},
	["Modern Clothing"] = {
		"T-Shirt", "Shirt", "Pants", "Jacket", "Sweater", "Shorts", "Dress / Skirt", "Shoes Bundle"
	},
	["Classic Clothing"] = {
		"Classic T-Shirt", "Classic Shirt", "Classic Pants"
	},
	Accessory = {
		"Hats", "Face Accessories", "Neck", "Shoulder", "Front", "Back", "Waist"
	},
	Animation = {
		"Emotes", "Animation Bundles"
	}
}

local function SubCategoryChips(props: SubCategoryChipsProps)
	local activeMain = props.activeMainCategory or "All"
	local activeSubCategory = props.activeSubCategory or "Featured"
	local subcategories = MAIN_TO_SUB[activeMain] or {}

	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Theme.Space.SM),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	}

	for i, subcat in ipairs(subcategories) do
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

	return React.createElement("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.X,
		LayoutOrder = props.layoutOrder,
	}, React.createElement(React.Fragment, nil, children))
end

return SubCategoryChips
