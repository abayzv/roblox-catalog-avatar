local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local CatalogTopbarController = require(script.Parent.controllers.CatalogTopbarController)
local App = require(script.Parent.ui.App)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RobloxItemCatalogGui"
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local root = ReactRoblox.createRoot(screenGui)
root:render(React.createElement(App))

local topbarController = CatalogTopbarController.new(Packages, screenGui)

script.Destroying:Connect(function()
	topbarController:destroy()
	root:unmount()
	screenGui:Destroy()
end)
