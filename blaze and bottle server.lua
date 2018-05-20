local bRun = true
local tQueue = {}

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
				break;
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

local function modemMessageHandler(_, local_address, remote_address, port, distance, ...)
  local msg = {...}

  if msg[1] == "potionFinished" then
  	print("Potion finished")
  	gatherPotions()
  	fillGlassBottle()
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
print("Ready!")

while bRun do
	os.sleep(1)
end