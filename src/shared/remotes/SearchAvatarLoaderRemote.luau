local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.types.AvatarTemplateTypes)

-- Remote function for searching Avatar Loader (templates by code, or roblox users by username)
local SearchAvatarLoaderRemote = Instance.new("RemoteFunction")
SearchAvatarLoaderRemote.Name = "SearchAvatarLoaderRemote"

return SearchAvatarLoaderRemote
