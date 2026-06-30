local CatalogConfig = {
	-- A whitelist of allowed AssetTypeIds that represent wearable catalog items
	-- This prevents exploiters from applying unsupported assets like Audio, Scripts, or Models.
	-- A mapping of allowed AssetTypeIds to their corresponding HumanoidDescription property.
	-- If it's an accessory, it maps to the CSV string property.
	-- If it's 2D clothing, it maps to the integer ID property.
	AssetTypeToProperty = {
		[2] = "GraphicTShirt", -- T-Shirt (Classic)
		[8] = "HatAccessory", -- Hat
		[11] = "Shirt", -- Shirt (Classic)
		[12] = "Pants", -- Pants (Classic)

		-- Body Parts
		[17] = "Head",
		[18] = "Face",
		[27] = "Torso",
		[28] = "RightArm",
		[29] = "LeftArm",
		[30] = "LeftLeg",
		[31] = "RightLeg",

		-- Accessories
		[41] = "HairAccessory",
		[42] = "FaceAccessory",
		[43] = "NeckAccessory",
		[44] = "ShouldersAccessory",
		[45] = "FrontAccessory",
		[46] = "BackAccessory",
		[47] = "WaistAccessory",

		-- Animations
		[48] = "ClimbAnimation",
		[50] = "FallAnimation",
		[51] = "IdleAnimation",
		[52] = "JumpAnimation",
		[53] = "RunAnimation",
		[54] = "SwimAnimation",
		[55] = "WalkAnimation",
		[61] = "EmoteAnimation",

		-- Layered Clothing
		[64] = "TShirtAccessory",
		[65] = "ShirtAccessory",
		[66] = "PantsAccessory",
		[67] = "JacketAccessory",
		[68] = "SweaterAccessory",
		[69] = "ShortsAccessory",
		[70] = "LeftShoeAccessory",
		[71] = "RightShoeAccessory",
		[72] = "DressSkirtAccessory",
		[78] = "MoodAnimation",
		[79] = "Head",
	},

	-- Toggle this to true if the game requires players to actually own the items to apply them to their live character
	RequireOwnership = false,
}

return CatalogConfig
