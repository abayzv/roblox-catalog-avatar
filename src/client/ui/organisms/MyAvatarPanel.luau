local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local HeaderTabs = require(script.Parent.HeaderTabs)
local MainCategoryTabs = require(script.Parent.MainCategoryTabs)
local SubCategoryChips = require(script.Parent.SubCategoryChips)
local CatalogGrid = require(script.Parent.CatalogGrid)
local useCatalogState = require(script.Parent.Parent.hooks.useCatalogState)
local useWornItems = require(script.Parent.Parent.Parent.hooks.useWornItems)
local WornItemExtractor = require(ReplicatedStorage.Shared.avatar.WornItemExtractor)
local MyAvatarCategoryConfig = require(ReplicatedStorage.Shared.avatar.MyAvatarCategoryConfig)

export type MyAvatarPanelProps = {
	layoutOrder: number?,
	isMobile: boolean?,
	isTablet: boolean?,
	viewportSize: Vector2?,
	contentScale: number?,
	activeTab: string,
	setActiveTab: (tab: string) -> (),
}

local function MyAvatarPanel(props: MyAvatarPanelProps)
	local state, actions = useCatalogState("my_avatar")
	local wornData = useWornItems()
	
	local contentScale = props.contentScale or 1
	local contentSizeScale = if contentScale > 0 then 1 / contentScale else 1

	local filteredItems = React.useMemo(function()
		return WornItemExtractor.filterItems(wornData.wornItems, state.activeMainCategory, state.activeSubCategory)
	end, { wornData.wornItems, state.activeMainCategory, state.activeSubCategory })

	-- Format worn items for CatalogGrid
	local catalogItems = React.useMemo(function()
		local items = {}
		for _, worn in ipairs(filteredItems) do
			table.insert(items, {
				id = tostring(worn.id),
				key = worn.key,
				name = worn.name,
				price = worn.price,
				creator = worn.creator,
				image = worn.image,
			})
		end
		return items
	end, { filteredItems })
	
	-- Everything is "ready" since it's just raw data right now
	local readyKeys = React.useMemo(function()
		local keys = {}
		for _, item in ipairs(catalogItems) do
			keys[item.key] = true
		end
		return keys
	end, { catalogItems })

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Theme.Color.Panel,
			ClipsDescendants = true,
			LayoutOrder = props.layoutOrder,
			BorderSizePixel = 0,
		},
		React.createElement(React.Fragment, nil, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.Panel),
			}),
			Content = React.createElement("Frame", {
				BackgroundTransparency = 1,
				ClipsDescendants = false,
				Size = UDim2.fromScale(contentSizeScale, contentSizeScale),
			}, {
				UIScale = React.createElement("UIScale", {
					Scale = contentScale,
				}),

				UIPadding = React.createElement("UIPadding", {
					PaddingTop = UDim.new(0, Theme.Space.XL),
					PaddingBottom = UDim.new(0, Theme.Space.XL),
					PaddingLeft = UDim.new(0, Theme.Space.XL),
					PaddingRight = UDim.new(0, Theme.Space.XL),
				}),
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),

				HeaderArea = React.createElement(HeaderTabs, {
					activeTab = props.activeTab,
					onTabSelected = props.setActiveTab,
					layoutOrder = 1,
				}),
				
				Spacer1 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}),

				MainCategoryArea = React.createElement(MainCategoryTabs, {
					activeCategory = state.activeMainCategory,
					onCategorySelected = actions.setActiveMainCategory,
					categories = MyAvatarCategoryConfig.MainCategories,
					layoutOrder = 3,
				}),

				Spacer2 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 4,
				}),

				SubCategoryArea = React.createElement(SubCategoryChips, {
					activeMainCategory = state.activeMainCategory,
					activeSubCategory = state.activeSubCategory,
					onSubCategorySelected = actions.setActiveSubCategory,
					categories = MyAvatarCategoryConfig.MainCategories,
					layoutOrder = 5,
				}),

				Spacer3 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 6,
				}),

				GridArea = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 1, -193), -- 51 + 16 + 60 + 16 + 50 = 193
					BackgroundTransparency = 1,
					LayoutOrder = 7,
				}, {
					Grid = React.createElement(CatalogGrid, {
						items = catalogItems,
						readyKeys = readyKeys,
						isLoading = wornData.isLoading,
						isFetchingNextPage = false,
						hasNextPage = false,
						isLimitReached = true,
						columns = 5,
						viewportScale = contentScale,
						emptyText = if state.activeMainCategory == "all" and state.activeSubCategory == "all"
							then "Belum ada item yang bisa ditampilkan."
							else "Kamu belum memakai item di kategori ini.",
					}),
				}),
			}),
		})
	)
end

return MyAvatarPanel
