local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local CheckoutController = {}

-- Store the active purchase queue
local purchaseQueue = {}
local isPurchasing = false

function CheckoutController.promptPurchase(item)
	local player = Players.LocalPlayer
	if not player then
		return
	end

	if item.itemType == "Bundle" then
		MarketplaceService:PromptBundlePurchase(player, item.id)
	else
		MarketplaceService:PromptPurchase(player, item.id)
	end
end

-- Buy all items sequentially
function CheckoutController.buyAllItems(items)
	-- Clear any existing queue and start fresh
	table.clear(purchaseQueue)

	for _, item in ipairs(items) do
		-- Only enqueue items that can be bought
		if not item.isOwned and not item.isOffSale and not item.isFree then
			table.insert(purchaseQueue, item)
		end
	end

	if not isPurchasing and #purchaseQueue > 0 then
		CheckoutController._processNextInQueue()
	end
end

function CheckoutController._processNextInQueue()
	if #purchaseQueue == 0 then
		isPurchasing = false
		return
	end

	isPurchasing = true
	local nextItem = table.remove(purchaseQueue, 1)
	CheckoutController.promptPurchase(nextItem)
end

-- Continue queue when a purchase finishes
MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
	if player == Players.LocalPlayer and isPurchasing then
		-- Add a small delay so the UI can breathe between prompts
		task.delay(0.5, function()
			CheckoutController._processNextInQueue()
		end)
	end
end)

MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
	if player == Players.LocalPlayer and isPurchasing then
		task.delay(0.5, function()
			CheckoutController._processNextInQueue()
		end)
	end
end)

return CheckoutController
