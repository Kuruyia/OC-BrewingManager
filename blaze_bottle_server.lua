local bRun = true
local tQueue = {}
local bIsReady = false
local bWantsVerification = false
local bNeedsBottle = false
local bNeedsBlaze = false

local component = require("component")
local event = require("event")
local sides = require("sides")
local table = require("table")
local net_card = component.modem
local inv_controller = component.inventory_controller
local robot = component.robot
net_card.open(4000)

local function turnAround()
	robot.turn(true)
	robot.turn(true)
end

local function drop(slot, side)
	robot.select(slot)
	local containerSize = inv_controller.getInventorySize(side)
	local itemToDrop = inv_controller.getStackInInternalSlot(slot)
	local tEmptySlots = {}

	for i = 1, containerSize do
		local currentSlot = inv_controller.getStackInSlot(side, i)

		if currentSlot and currentSlot.name == itemToDrop.name then
			if currentSlot.size < currentSlot.maxSize then
				inv_controller.dropIntoSlot(side, i)

				itemToDrop = inv_controller.getStackInInternalSlot(slot)
				if not itemToDrop then
					break
				end
			end
		elseif not currentSlot then
			table.insert(tEmptySlots, i)
		end
	end

	itemToDrop = inv_controller.getStackInInternalSlot(slot)
	if itemToDrop then
		if #tEmptySlots > 0 then
			inv_controller.dropIntoSlot(side, tEmptySlots[1])
		else
			return false
		end
	end

	robot.select(1)
	return true
end

local function findPosition()
	local _, blockTypeFront = robot.detect(sides.front)
	robot.turn(true)
	local _, blockTypeRight = robot.detect(sides.front)
	turnAround()
	local _, blockTypeLeft = robot.detect(sides.front)
	robot.turn(true)

	if blockTypeFront == "liquid" and blockTypeRight == "solid" and blockTypeLeft == "liquid" then
		robot.turn(true)
	elseif blockTypeFront == "solid" and blockTypeRight == "liquid" and blockTypeLeft == "solid" then
		robot.turn(false)
	elseif blockTypeFront == "liquid" and blockTypeRight == "liquid" and blockTypeLeft == "solid" then
		turnAround()
	end
end

local function clearInventory()
	local tPotions = {}
	local tBlazePowder = {}
	local tGlassBottle = {}
	local tJunk = {}

	for i = 1, robot.inventorySize() do
		local item = inv_controller.getStackInInternalSlot(i)
		if item then
			if item.name == "minecraft:potion" then
				table.insert(tPotions, i)
			elseif item.name == "minecraft:glass_bottle" then
				table.insert(tGlassBottle, i)
			elseif item.name == "minecraft:blaze_powder" then
				table.insert(tBlazePowder, i)
			else
				table.insert(tJunk, i)
			end
		end
	end

	if #tPotions > 0 then
		robot.turn(true)
		for i = 1, #tPotions do
			drop(tPotions[i], sides.front)
		end
		robot.turn(false)
	end

	if #tBlazePowder > 0 then
		for i = 1, #tBlazePowder do
			drop(tBlazePowder[i], sides.top)
		end
	end

	if #tGlassBottle > 0 then
		for i = 1, #tGlassBottle do
			drop(tGlassBottle[i], sides.bottom)
		end
	end

	if #tJunk > 0 then
		turnAround()
		for i = 1, #tJunk do
			drop(tJunk[i], sides.front)
		end
		turnAround()
	end
end

local function fillGlassBottle()
	local chestSize = inv_controller.getInventorySize(sides.bottom)
	local gotPotions = 0
	robot.select(1)

	for i = 1, chestSize do
		local currentSlot = inv_controller.getStackInSlot(sides.bottom, i)
		if currentSlot and currentSlot.name == "minecraft:glass_bottle" then
			gotPotions = gotPotions + currentSlot.size
			for j = 1, currentSlot.size do
				local selectedSlot = inv_controller.getStackInInternalSlot()

				if not selectedSlot then
					inv_controller.suckFromSlot(sides.bottom, i, 1)
				end

				robot.select(robot.select() + 1)

				if j == 3 then
					break
				end
			end
		end

		if gotPotions >= 3 then
			break
		end
	end

	robot.turn(false)
	for i = 1, 3 do
		robot.select(i)
		inv_controller.equip()
		robot.use(3)
		inv_controller.equip()
	end
	robot.turn(true)

	for i = 1, 3 do
		robot.select(i)

		if not inv_controller.getStackInSlot(sides.front, i) then
			inv_controller.dropIntoSlot(sides.front, i)
		end
	end

	robot.select(1)
end

local function gatherPotions()
	local nGatheredPotions = 0

	for i = 1, 3 do
		if inv_controller.getStackInSlot(sides.front, i) then
			inv_controller.suckFromSlot(sides.front, i)
			nGatheredPotions = nGatheredPotions + 1

			robot.select(robot.select() + 1)
		end
	end

	robot.turn(true)

	local tEmptySlots = {}
	local chestSize = inv_controller.getInventorySize(sides.front)
	for i = 1, chestSize do
		if not inv_controller.getStackInSlot(sides.front, i) then
			table.insert(tEmptySlots, i)

			if #tEmptySlots >= nGatheredPotions then
				break
			end
		end
	end

	for i = 1, nGatheredPotions do
		robot.select(i)
		inv_controller.dropIntoSlot(sides.front, tEmptySlots[i])
	end

	robot.turn(false)
	robot.select(1)
end

local function isPotionExisting(potion)
	for i = 1, #tPotions do
		if tPotions[i] == potion then
			return true
		end
	end

	return false
end

local function doesChestHaveGlassBottle()
	for i = 1, inv_controller.getInventorySize(sides.bottom) do
		local tCurrentItem = inv_controller.getStackInSlot(sides.bottom, i)

		if tCurrentItem and tCurrentItem.name == "minecraft:glass_bottle" then
			return true
		end
	end

	return false
end

local function doesChestHaveBlazePowder()
	for i = 1, inv_controller.getInventorySize(sides.top) do
		local tCurrentItem = inv_controller.getStackInSlot(sides.top, i)

		if tCurrentItem and tCurrentItem.name == "minecraft:blaze_powder" then
			return true
		end
	end

	return false
end

local function fillBlazePowder()
	local tBlazeSlots = {}
	local nTotalQuantity = 0

	for i = 1, inv_controller.getInventorySize(sides.top) do
		local tCurrentItem = inv_controller.getStackInSlot(sides.top, i)

		if tCurrentItem and tCurrentItem.name == "minecraft:blaze_powder" then
			local nQuantity = tCurrentItem.size

			if nQuantity + nTotalQuantity > 64 then
				nQuantity = 64 - nTotalQuantity
			end
			nTotalQuantity = nTotalQuantity + nQuantity

			table.insert(tBlazeSlots, {["slot"] = i, ["quantity"] = nQuantity})
		end
	end

	if #tBlazeSlots == 0 then
		return false
	end

	for i = 1, #tBlazeSlots do
		inv_controller.suckFromSlot(sides.top, tBlazeSlots[i]["slot"], tBlazeSlots[i]["quantity"])
	end

	inv_controller.dropIntoSlot(sides.front, 4)

	return true
end

local function hasEnoughGlassBottles()
	if inv_controller.getStackInSlot(sides.front, 1) or inv_controller.getStackInSlot(sides.front, 2) or inv_controller.getStackInSlot(sides.front, 3) then
		return true
	else
		bNeedsBottle = true
		return false
	end
end

local function hasEnoughBlazePowder()
	if inv_controller.getStackInSlot(sides.front, 4) then
		return true
	else
		if not fillBlazePowder() then
			bNeedsBlaze = true
			return false
		else
			return true
		end
	end
end

local function ready()
	print("Ready")
	bIsReady = true

	if bWantsVerification then
		net_card.broadcast(4000, "verification", hasEnoughGlassBottles(), hasEnoughBlazePowder())
	end
end

local function countBlazePowderLevel()
	local nItemCount = 0
	local nInvSize = inv_controller.getInventorySize(sides.top)
	local nTotalCount = nInvSize * 64

	for i = 1, nInvSize do
		local tCurrentItem = inv_controller.getStackInSlot(sides.top, i)

		if tCurrentItem and tCurrentItem.name == "minecraft:blaze_powder" then
			nItemCount = nItemCount + tCurrentItem.size
		end
	end

	return nItemCount, nTotalCount
end

local function countGlassBottleLevel()
	local nItemCount = 0
	local nInvSize = inv_controller.getInventorySize(sides.bottom)
	local nTotalCount = nInvSize * 64

	for i = 1, nInvSize do
		local tCurrentItem = inv_controller.getStackInSlot(sides.bottom, i)

		if tCurrentItem and tCurrentItem.name == "minecraft:glass_bottle" then
			nItemCount = nItemCount + tCurrentItem.size
		end
	end

	return nItemCount, nTotalCount
end

local function sendItemLevels()
	local nGlassLevel, nMaxGlass = countGlassBottleLevel()
  	local nBlazeLevel, nMaxBlaze = countBlazePowderLevel()

  	net_card.broadcast(4000, "updateLevelsState", nGlassLevel, nMaxGlass, nBlazeLevel, nMaxBlaze)
end

local function modemMessageHandler(_, local_address, remote_address, port, distance, ...)
  local msg = {...}

  if msg[1] == "potionFinished" or msg[1] == "notifyQuantityDecreased" then
  	print("Potion finished")
  	bIsReady = false

  	gatherPotions()
  	if doesChestHaveGlassBottle() then
  		fillGlassBottle()
  	else
  		bNeedsBottle = true
  	end

  	ready()
  	sendItemLevels()
  elseif msg[1] == "wantsVerification" then
  	if bIsReady then
  		net_card.broadcast(4000, "verification", hasEnoughGlassBottles(), hasEnoughBlazePowder())
  	else
  		bWantsVerification = true
  	end
  elseif msg[1] == "getState" then
  	sendItemLevels()
  else
  	print(msg[1])
  end
end

local function keyDownHandler(_, keyboard_address, char, code, playerName)
	if char == 99 then
		event.ignore("modem_message", modemMessageHandler)
		event.ignore("key_down", keyDownHandler)
		net_card.close(4000)

		print("Exiting the program")
		bRun = false
	end
end

event.listen("modem_message", modemMessageHandler)
event.listen("key_down", keyDownHandler)

findPosition()
clearInventory()

ready()

while bRun do
	os.sleep(1)

	if bNeedsBottle or bNeedsBlaze then
		local bHasChanged = false

		if bNeedsBottle then
			print("Check for bottles...")
			if doesChestHaveGlassBottle() then
				bNeedsBottle = false
				bHasChanged = true

				fillGlassBottle()
			end
		end

		if bNeedsBlaze then
			print("Check for blaze...")
			if doesChestHaveBlazePowder() then
				bNeedsBlaze = false
				bHasChanged = true

				fillBlazePowder()
			end
		end

		if bHasChanged then
			net_card.broadcast(4000, "verification", not bNeedsBottle, not bNeedsBlaze)
		end
	end
end
