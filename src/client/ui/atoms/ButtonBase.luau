local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

export type ButtonBaseProps = {
	text: string?,
	icon: string?,
	size: UDim2?,
	minHeight: number?,
	variant: string?,
	selected: boolean?,
	disabled: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
	children: any?,
	render: ((isHovered: boolean, isPressed: boolean) -> any)?,
	automaticSize: Enum.AutomaticSize?,
}

local function ButtonBase(props: ButtonBaseProps)
	local isHovered, setHovered = React.useState(false)
	local isPressed, setPressed = React.useState(false)
	local disabled = props.disabled

	local onMouseEnter = React.useCallback(function()
		if not disabled then
			setHovered(true)
		end
	end, { disabled })

	local onMouseLeave = React.useCallback(function()
		setHovered(false)
		setPressed(false)
	end, { disabled })

	local onInputBegan = React.useCallback(function(_, input)
		if disabled then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setPressed(true)
		end
	end, { disabled })

	local onInputEnded = React.useCallback(function(_, input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setPressed(false)
		end
	end, {})

	local content
	if props.render then
		content = props.render(isHovered, isPressed)
	else
		content = props.children
	end

	return React.createElement("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = props.size or UDim2.fromScale(1, 1),
		AutomaticSize = props.automaticSize,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		Active = not disabled,

		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.InputBegan] = onInputBegan,
		[React.Event.InputEnded] = onInputEnded,
		[React.Event.Activated] = function()
			if not disabled and props.onActivated then
				props.onActivated()
			end
		end,
	}, content)
end

return ButtonBase
