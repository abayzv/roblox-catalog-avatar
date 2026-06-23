local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

export type BaseFrameProps = {
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	backgroundColor: Color3?,
	backgroundTransparency: number?,
	cornerRadius: number?,
	strokeColor: Color3?,
	strokeThickness: number?,
	padding: number?,
	layoutOrder: number?,
	children: any?,
}

local function BaseFrame(props: BaseFrameProps)
	local hasStroke = props.strokeColor ~= nil
	local hasPadding = props.padding ~= nil

	local children = props.children or {}
	if type(children) ~= "table" then
		children = { default = children }
	else
		local newChildren = {}
		for k, v in pairs(children) do
			newChildren[k] = v
		end
		children = newChildren
	end

	children.UICorner = React.createElement("UICorner", {
		CornerRadius = UDim.new(0, props.cornerRadius or Theme.Radius.MD),
	})

	if hasStroke then
		children.UIStroke = React.createElement("UIStroke", {
			Color = props.strokeColor,
			Thickness = props.strokeThickness or 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end

	if hasPadding then
		children.UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, props.padding),
			PaddingBottom = UDim.new(0, props.padding),
			PaddingLeft = UDim.new(0, props.padding),
			PaddingRight = UDim.new(0, props.padding),
		})
	end

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.backgroundColor or Theme.Color.Panel,
		BackgroundTransparency = props.backgroundTransparency or 0,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	}, React.createElement(React.Fragment, nil, children))
end

return BaseFrame
