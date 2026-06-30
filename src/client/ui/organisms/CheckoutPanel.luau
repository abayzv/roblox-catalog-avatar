local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local HeaderTabs = require(script.Parent.HeaderTabs)
local CheckoutItemRow = require(script.Parent.Parent.molecules.CheckoutItemRow)
local CheckoutItemRowSkeleton = require(script.Parent.Parent.molecules.CheckoutItemRowSkeleton)
local ButtonBase = require(script.Parent.Parent.atoms.ButtonBase)
local Icon = require(script.Parent.Parent.atoms.Icon)
local useCheckoutItems = require(script.Parent.Parent.Parent.hooks.useCheckoutItems)
local CheckoutController = require(script.Parent.Parent.Parent.controllers.CheckoutController)

export type CheckoutPanelProps = {
	layoutOrder: number?,
	isMobile: boolean?,
	isTablet: boolean?,
	viewportSize: Vector2?,
	contentScale: number?,
	activeTab: string,
	setActiveTab: (tab: string) -> (),
}

local function CheckoutPanel(props: CheckoutPanelProps)
	local contentScale = props.contentScale or 1
	local contentSizeScale = if contentScale > 0 then 1 / contentScale else 1

	local checkoutData = useCheckoutItems()

	local onBuyAll = React.useCallback(function()
		CheckoutController.buyAllItems(checkoutData.items)
	end, { checkoutData.items })

	local HEADER_HEIGHT = 51
	local BOTTOM_AREA_HEIGHT = 150

	-- Calculate total height of top elements to set scrolling frame offset
	local GRID_OFFSET = HEADER_HEIGHT + Theme.Space.XL * 2 + 80 -- roughly

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Theme.Color.Panel,
		ClipsDescendants = true,
		LayoutOrder = props.layoutOrder,
		BorderSizePixel = 0,
	}, {
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
				Size = UDim2.new(1, 0, 0, Theme.Space.XL),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
			}),

			TitleArea = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Title = React.createElement("TextLabel", {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = "Checkout Items",
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.ScreenTitle,
					TextColor3 = Theme.Color.TextPrimary,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
				}),
				Subtitle = React.createElement("TextLabel", {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					Text = "Review your items and complete your purchase.",
					Font = Theme.Font.Medium,
					TextSize = Theme.Text.Body,
					TextColor3 = Theme.Color.TextSecondary,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
				}),
			}),

			Spacer2 = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, Theme.Space.XL),
				BackgroundTransparency = 1,
				LayoutOrder = 4,
			}),

			ListArea = React.createElement("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -(GRID_OFFSET + BOTTOM_AREA_HEIGHT)),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ClipsDescendants = true,
				LayoutOrder = 5,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, Theme.Space.MD),
					PaddingRight = UDim.new(0, Theme.Space.SM),
				}),
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Space.SM),
				}),

				Items = React.createElement(
					React.Fragment,
					nil,
					(function()
						local elements = {}
						if checkoutData.isLoading then
							for i = 1, 4 do
								elements["Skeleton_" .. i] = React.createElement(CheckoutItemRowSkeleton, {
									layoutOrder = i,
								})
							end
						elseif #checkoutData.items == 0 then
							elements["EmptyState"] = React.createElement("Frame", {
								Size = UDim2.new(1, 0, 0, 200),
								BackgroundTransparency = 1,
								LayoutOrder = 1,
							}, {
								Layout = React.createElement("UIListLayout", {
									FillDirection = Enum.FillDirection.Vertical,
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									Padding = UDim.new(0, Theme.Space.MD),
								}),
								Icon = React.createElement(Icon, {
									image = Icons.Cart or "rbxassetid://0",
									size = 48,
									color = Theme.Color.TextSecondary,
									layoutOrder = 1,
								}),
								Text = React.createElement("TextLabel", {
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									Text = "Your cart is empty",
									Font = Theme.Font.Medium,
									TextSize = Theme.Text.Body,
									TextColor3 = Theme.Color.TextSecondary,
									LayoutOrder = 2,
								})
							})
						else
							for i, item in ipairs(checkoutData.items) do
								elements["Item_" .. i] = React.createElement(CheckoutItemRow, {
									item = item,
									layoutOrder = i,
								})
							end
						end
						return elements
					end)()
				),
			}),

			BottomArea = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, BOTTOM_AREA_HEIGHT),
				BackgroundTransparency = 1,
				LayoutOrder = 6,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Space.MD),
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
				}),

				-- Summary Box
				SummaryBox = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 72),
					BackgroundColor3 = Color3.fromRGB(250, 245, 255), -- light purple tint
					LayoutOrder = 1,
				}, {
					UICorner = React.createElement(
						"UICorner",
						{ CornerRadius = UDim.new(0, Theme.Radius.MD) }
					),
					UIStroke = React.createElement(
						"UIStroke",
						{ Color = Color3.fromRGB(230, 220, 240), Thickness = 1 }
					),
					UIPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, Theme.Space.MD),
						PaddingRight = UDim.new(0, Theme.Space.MD),
					}),

					LeftContainer = React.createElement("Frame", {
						Size = UDim2.new(0.5, 0, 1, 0),
						BackgroundTransparency = 1,
					}, {
						Layout = React.createElement("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, Theme.Space.MD),
						}),
						IconBox = React.createElement("Frame", {
							Size = UDim2.fromOffset(48, 48),
							BackgroundColor3 = Color3.fromRGB(230, 210, 255),
							LayoutOrder = 1,
						}, {
							UICorner = React.createElement(
								"UICorner",
								{ CornerRadius = UDim.new(0, Theme.Radius.MD) }
							),
							Icon = React.createElement(Icon, {
								image = Icons.Robux or "rbxassetid://0",
								size = 24,
								color = Color3.fromRGB(150, 50, 200),
								anchorPoint = Vector2.new(0.5, 0.5),
								position = UDim2.fromScale(0.5, 0.5),
							}),
						}),
						TextContainer = React.createElement("Frame", {
							Size = UDim2.new(1, -64, 1, 0),
							BackgroundTransparency = 1,
							LayoutOrder = 2,
						}, {
							Layout = React.createElement("UIListLayout", {
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							Title = React.createElement("TextLabel", {
								Size = UDim2.new(1, 0, 0, 24),
								BackgroundTransparency = 1,
								Text = "Total Robux",
								Font = Theme.Font.Bold,
								TextSize = Theme.Text.Body,
								TextColor3 = Theme.Color.TextPrimary,
								TextXAlignment = Enum.TextXAlignment.Left,
								LayoutOrder = 1,
							}),
							Subtitle = React.createElement("TextLabel", {
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								Text = checkoutData.buyableCount .. " items",
								Font = Theme.Font.Medium,
								TextSize = Theme.Text.Small,
								TextColor3 = Theme.Color.TextSecondary,
								TextXAlignment = Enum.TextXAlignment.Left,
								LayoutOrder = 2,
							}),
						}),
					}),

					RightContainer = React.createElement("Frame", {
						Size = UDim2.new(0.5, 0, 1, 0),
						Position = UDim2.fromScale(0.5, 0),
						BackgroundTransparency = 1,
					}, {
						Layout = React.createElement("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							Padding = UDim.new(0, 8),
						}),
						RobuxIcon = React.createElement(Icon, {
							image = Icons.Robux or "rbxassetid://0",
							size = 24,
							color = Theme.Color.TextPrimary,
							layoutOrder = 1,
						}),
						Price = React.createElement("TextLabel", {
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							Text = tostring(checkoutData.totalRobux),
							Font = Theme.Font.Bold,
							TextSize = 28,
							TextColor3 = Theme.Color.TextPrimary,
							LayoutOrder = 2,
						}),
					}),
				}),

				-- Buy All Button
				BuyAllButton = React.createElement(ButtonBase, {
					size = UDim2.new(1, 0, 0, 50),
					layoutOrder = 2,
					onActivated = (checkoutData.buyableCount > 0) and onBuyAll or nil,
					render = function(isHovered, isPressed)
						local alpha = checkoutData.buyableCount > 0 and 0 or 0.5
						if isPressed then
							alpha = 0.2
						elseif isHovered and checkoutData.buyableCount > 0 then
							alpha = 0.1
						end

						return React.createElement("Frame", {
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = Color3.new(1, 1, 1),
						}, {
							UICorner = React.createElement(
								"UICorner",
								{ CornerRadius = UDim.new(0, Theme.Radius.MD) }
							),
							UIGradient = React.createElement(
								"UIGradient",
								{ Color = Theme.Gradient.Primary }
							),
							Overlay = React.createElement("Frame", {
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = Color3.new(0, 0, 0),
								BackgroundTransparency = 1 - alpha,
								ZIndex = 2,
							}, {
								UICorner = React.createElement(
									"UICorner",
									{ CornerRadius = UDim.new(0, Theme.Radius.MD) }
								),
							}),
							Content = React.createElement("Frame", {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								ZIndex = 3,
							}, {
								Layout = React.createElement("UIListLayout", {
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									Padding = UDim.new(0, Theme.Space.SM),
								}),
								Icon = React.createElement(Icon, {
									image = Icons.Cart or "rbxassetid://0",
									size = 20,
									color = Color3.new(1, 1, 1),
									layoutOrder = 1,
								}),
								Text = React.createElement("TextLabel", {
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									Text = "Buy All Items (" .. checkoutData.buyableCount .. ")",
									Font = Theme.Font.Bold,
									TextSize = Theme.Text.Body,
									TextColor3 = Color3.new(1, 1, 1),
									LayoutOrder = 2,
								}),
							}),
						})
					end,
				}),

				-- Secure text
				SecureTextContainer = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					LayoutOrder = 3,
				}, {
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 4),
					}),
					LockIcon = React.createElement(Icon, {
						image = Icons.Lock or "rbxassetid://0",
						size = 14,
						color = Theme.Color.TextSecondary,
						layoutOrder = 1,
					}),
					Text = React.createElement("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = "Secure transaction · Your items will be added to your inventory immediately.",
						Font = Theme.Font.Medium,
						TextSize = Theme.Text.Small,
						TextColor3 = Theme.Color.TextSecondary,
						LayoutOrder = 2,
					}),
				}),
			}),
		}),
	})
end

return CheckoutPanel
