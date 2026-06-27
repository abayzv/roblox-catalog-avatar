local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

local HeaderTabs = require(script.Parent.HeaderTabs)
local SearchToolbar = require(script.Parent.Parent.molecules.SearchToolbar)
local AvatarTemplateCard = require(script.Parent.Parent.molecules.AvatarTemplateCard)
local AvatarTemplateTypes = require(ReplicatedStorage.Shared.types.AvatarTemplateTypes)

export type AvatarLoaderPanelProps = {
	layoutOrder: number?,
	isMobile: boolean?,
	isTablet: boolean?,
	viewportSize: Vector2?,
	contentScale: number?,
	activeTab: string,
	setActiveTab: (tab: string) -> (),
}

local function AvatarLoaderPanel(props: AvatarLoaderPanelProps)
	local contentScale = props.contentScale or 1
	local contentSizeScale = if contentScale > 0 then 1 / contentScale else 1
	
	local searchInput, setSearchInput = React.useState("")
	local searchQuery, setSearchQuery = React.useState("")
	
	local HEADER_HEIGHT = 51
	local SEARCH_HEIGHT = 60
	local LIST_OFFSET = HEADER_HEIGHT + 16 + SEARCH_HEIGHT + 18 + 24 + 16
	
	-- Dummy data for UI building (Sub-Phase 12.4)
	local dummyTemplates: {AvatarTemplateTypes.AvatarTemplateCardData} = {
		{
			templateId = "dummy-1",
			code = "5X3P2",
			name = "Template 1",
			creatorUsername = "Abay",
			thumbnailUrl = nil,
			thumbnailState = "Placeholder",
		},
		{
			templateId = "dummy-2",
			code = "829KQ",
			name = "Template 2",
			creatorUsername = "Roblox",
			thumbnailUrl = nil,
			thumbnailState = "Placeholder",
		},
		{
			templateId = "dummy-3",
			code = "ZZZ11",
			name = "Template 3",
			creatorUsername = "Builderman",
			thumbnailUrl = nil,
			thumbnailState = "Placeholder",
		}
	}

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
				
				SearchArea = React.createElement(SearchToolbar, {
					searchText = searchInput,
					onSearchInputChanged = setSearchInput,
					onSearchSubmitted = function(query)
						setSearchQuery(query)
					end,
					layoutOrder = 3,
				}),
				
				Spacer2 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					LayoutOrder = 4,
				}),

				TitleArea = React.createElement("TextLabel", {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = "Generated Templates",
					TextColor3 = Theme.Color.TextPrimary,
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.H3,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 5,
				}),
				
				Spacer3 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 6,
				}),

				GridArea = (function()
					local columns = 3
					local scrollBarThickness = 6
					local sidePadding = 16
					-- Approximate container width based on standard design
					local containerWidth = 804 
					local usableWidth = math.max(containerWidth - scrollBarThickness - sidePadding, 1)
					local gapX = 18
					local gapY = 14
					local originalWidth = 248
					local originalHeight = 252
					
					local targetCellWidth = math.max((usableWidth - (gapX * (columns - 1))) / columns, 1)
					local scale = targetCellWidth / originalWidth
					local targetCellHeight = math.floor(originalHeight * scale)
					local itemCount = #dummyTemplates
					local rowCount = math.max(math.ceil(itemCount / columns), 1)
					
					local estimatedContentHeight = 12 + (rowCount * targetCellHeight) + (math.max(rowCount - 1, 0) * gapY) + 96

					return React.createElement("ScrollingFrame", {
						Size = UDim2.new(1, 0, 1, -LIST_OFFSET - 40),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = scrollBarThickness,
						ScrollBarImageColor3 = Theme.Color.Border,
						CanvasSize = UDim2.new(0, 0, 0, estimatedContentHeight),
						LayoutOrder = 7,
					}, {
						Layout = React.createElement("UIGridLayout", {
							CellSize = UDim2.fromOffset(math.floor(targetCellWidth), targetCellHeight),
							CellPadding = UDim2.fromOffset(gapX, gapY),
							FillDirection = Enum.FillDirection.Horizontal,
							FillDirectionMaxCells = columns,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
						}),
						Padding = React.createElement("UIPadding", {
							PaddingTop = UDim.new(0, 12),
							PaddingBottom = UDim.new(0, 96),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
						
						Cards = React.createElement(React.Fragment, nil, 
							(function()
								local cards = {}
								for i, template in ipairs(dummyTemplates) do
									cards["Card_" .. template.templateId] = React.createElement("Frame", {
										BackgroundTransparency = 1,
										Size = UDim2.fromScale(1, 1),
										LayoutOrder = i,
									}, {
										ScalerContainer = React.createElement("Frame", {
											BackgroundTransparency = 1,
											Size = UDim2.fromOffset(originalWidth, originalHeight),
										}, {
											UIScale = React.createElement("UIScale", { Scale = scale }),
											Card = React.createElement(AvatarTemplateCard, {
												templateData = template,
												onLoad = function(id)
													print("Load template:", id)
												end,
											}),
										}),
									})
								end
								return cards
							end)()
						)
					})
				end)()
			}),
		})
	)
end

return AvatarLoaderPanel
