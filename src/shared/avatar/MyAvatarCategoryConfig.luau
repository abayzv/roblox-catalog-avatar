export type MyAvatarCategory = {
	id: string,
	label: string,
	subcategories: { MyAvatarSubcategory },
}

export type MyAvatarSubcategory = {
	id: string,
	label: string,
	groupId: string?,
	properties: { string }?,
}

local MyAvatarCategoryConfig = {}

MyAvatarCategoryConfig.MainCategories = {
	{
		id = "all",
		label = "All",
		subcategories = {
			{ id = "all", label = "All" },
			{ id = "body", label = "Body", groupId = "body" },
			{ id = "3d_clothing", label = "3D Clothing", groupId = "3d_clothing" },
			{ id = "classic_clothing", label = "Classic Clothing", groupId = "classic_clothing" },
			{ id = "accessories", label = "Accessories", groupId = "accessories" },
			{ id = "animation", label = "Animation", groupId = "animation" },
		},
	},

	{
		id = "body",
		label = "Body",
		subcategories = {
			{ id = "all", label = "All", groupId = "body" },
			{ id = "hair", label = "Hair", properties = { "HairAccessory" } },
			{ id = "head", label = "Head", properties = { "Head" } },
			{ id = "face", label = "Face", properties = { "Face" } },
			{ id = "body_parts", label = "Body Parts", properties = {
				"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
			}},
		},
	},

	{
		id = "3d_clothing",
		label = "3D Clothing",
		subcategories = {
			{ id = "all", label = "All", groupId = "3d_clothing" },
			{ id = "tshirt", label = "T-Shirt", properties = { "TShirtAccessory" } },
			{ id = "shirt", label = "Shirt", properties = { "ShirtAccessory" } },
			{ id = "pants", label = "Pants", properties = { "PantsAccessory" } },
			{ id = "jacket", label = "Jacket", properties = { "JacketAccessory" } },
			{ id = "sweater", label = "Sweater", properties = { "SweaterAccessory" } },
			{ id = "shorts", label = "Shorts", properties = { "ShortsAccessory" } },
			{ id = "dress_skirt", label = "Dress / Skirt", properties = { "DressSkirtAccessory" } },
			{ id = "left_shoe", label = "Left Shoe", properties = { "LeftShoeAccessory" } },
			{ id = "right_shoe", label = "Right Shoe", properties = { "RightShoeAccessory" } },
		},
	},

	{
		id = "classic_clothing",
		label = "Classic Clothing",
		subcategories = {
			{ id = "all", label = "All", groupId = "classic_clothing" },
			{ id = "classic_tshirt", label = "Classic T-Shirt", properties = { "GraphicTShirt" } },
			{ id = "classic_shirt", label = "Classic Shirt", properties = { "Shirt" } },
			{ id = "classic_pants", label = "Classic Pants", properties = { "Pants" } },
		},
	},

	{
		id = "accessories",
		label = "Accessories",
		subcategories = {
			{ id = "all", label = "All", groupId = "accessories" },
			{ id = "hats", label = "Hats", properties = { "HatAccessory" } },
			{ id = "face", label = "Face", properties = { "FaceAccessory" } },
			{ id = "neck", label = "Neck", properties = { "NeckAccessory" } },
			{ id = "shoulder", label = "Shoulder", properties = { "ShoulderAccessory", "ShouldersAccessory" } },
			{ id = "front", label = "Front", properties = { "FrontAccessory" } },
			{ id = "back", label = "Back", properties = { "BackAccessory" } },
			{ id = "waist", label = "Waist", properties = { "WaistAccessory" } },
		},
	},

	{
		id = "animation",
		label = "Animation",
		subcategories = {
			{ id = "all", label = "All", groupId = "animation" },
			{ id = "idle", label = "Idle", properties = { "IdleAnimation" } },
			{ id = "walk", label = "Walk", properties = { "WalkAnimation" } },
			{ id = "run", label = "Run", properties = { "RunAnimation" } },
			{ id = "jump", label = "Jump", properties = { "JumpAnimation" } },
			{ id = "fall", label = "Fall", properties = { "FallAnimation" } },
			{ id = "climb", label = "Climb", properties = { "ClimbAnimation" } },
			{ id = "swim", label = "Swim", properties = { "SwimAnimation" } },
		},
	},
}

return MyAvatarCategoryConfig
