local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

export type IconProps = {
	image: string,
	size: number?,
	color: Color3?,
	transparency: number?,
	layoutOrder: number?,
}

local function Icon(props: IconProps)
	local size = props.size or 20

	return React.createElement("ImageLabel", {
		Image = props.image,
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = props.color or Theme.Color.IconDark,
		ImageTransparency = props.transparency or 0,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = props.layoutOrder,
	})
end

return Icon
