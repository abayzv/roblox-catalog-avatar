local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ButtonBase = require(script.Parent.Parent.atoms.ButtonBase)

export type PaginationControlsProps = {
	currentPage: number,
	totalPages: number,
	hasNextPage: boolean?,
	onPrevious: (() -> ())?,
	onNext: (() -> ())?,
	layoutOrder: number?,
}

local function PageButton(props: {
	text: string,
	disabled: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
})
	return React.createElement(ButtonBase, {
		disabled = props.disabled,
		onActivated = props.onActivated,
		size = UDim2.fromOffset(118, 36),
		layoutOrder = props.layoutOrder,
		render = function(isHovered, isPressed)
			local scale = isPressed and 0.98 or 1
			local bgColor = Theme.Color.Panel
			local strokeColor = Theme.Color.Border
			local textColor = Theme.Color.TextPrimary

			if props.disabled then
				bgColor = Theme.Color.PanelSoft
				strokeColor = Theme.Color.Border
				textColor = Theme.Color.TextMuted
			elseif isHovered then
				bgColor = Theme.Color.ActiveSoft
				strokeColor = Theme.Color.Purple
				textColor = Theme.Color.Purple
			end

			return React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = bgColor,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}, {
				UIScale = React.createElement("UIScale", {
					Scale = scale,
				}),
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, Theme.Radius.SM),
				}),
				UIStroke = React.createElement("UIStroke", {
					Color = strokeColor,
					Thickness = if props.disabled then 1 else 1.5,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Text = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = props.text,
					TextColor3 = textColor,
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.Body,
				}),
			})
		end,
	})
end

local function PaginationControls(props: PaginationControlsProps)
	local currentPage = props.currentPage
	local totalPages = math.max(props.totalPages, 1)
	local canPrevious = currentPage > 1
	local canNext = if props.hasNextPage ~= nil
		then props.hasNextPage == true
		else currentPage < totalPages

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.Space.MD),
		}),
		PreviousButton = PageButton({
			text = "< Previous",
			disabled = not canPrevious,
			onActivated = props.onPrevious,
			layoutOrder = 1,
		}),
		PagePill = React.createElement("Frame", {
			Size = UDim2.fromOffset(116, 34),
			BackgroundColor3 = Theme.Color.PanelSoft,
			LayoutOrder = 2,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.SM),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = Theme.Color.Border,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Text = React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "Page " .. tostring(currentPage),
				TextColor3 = Theme.Color.TextSecondary,
				Font = Theme.Font.Medium,
				TextSize = Theme.Text.Small,
			}),
		}),
		NextButton = PageButton({
			text = "Next >",
			disabled = not canNext,
			onActivated = props.onNext,
			layoutOrder = 3,
		}),
	})
end

return PaginationControls
