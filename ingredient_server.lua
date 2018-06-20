local bRun = true
local tQueue = {}
local tPotions = {["night_vision"] = "minecraft:golden_carrot", ["invisibility"] = {"minecraft:golden_carrot", "minecraft:fermented_spider_eye"}, ["fire_resistance"] = "minecraft:magma_cream", ["leaping"] = "minecraft:rabbit_foot", ["slowness"] = {{"minecraft:rabbit_foot", "minecraft:fermented_spider_eye"}, {"minecraft:sugar", "minecraft:fermented_spider_eye"}}, ["swiftness"] = "minecraft:sugar", ["water_breathing"] = "minecraft:fish", ["healing"] = "minecraft:speckled_melon", ["harming"] = {{"minecraft:speckled_melon", "minecraft:fermented_spider_eye"}, {"minecraft:spider_eye", "minecraft:fermented_spider_eye"}}, ["poison"] = "minecraft:spider_eye", ["regeneration"] = "minecraft:ghast_tear", ["strength"] = "minecraft:blaze_powder", ["weakness"] = "minecraft:fermented_spider_eye"}
local nState = 0
local tMissingComponents = {}

--[[
  States:
  0 = idle
  1 = brewing
  2 = missing ingredient
  3 = querying brewing stand status
  4 = missing brewing stand component
  5 = potion has finished
]]

local component = require("component")
local event = require("event")
local sides = require("sides")
local table = require("table")
local serialization = require("serialization")
local net_card = component.modem
local inv_controller = component.inventory_controller
local robot = component.robot
net_card.open(4000)

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
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
  for i = 1, 4 do
    local _, blockType = robot.detect(sides.front)
    if blockType == "liquid" then
      robot.turn(false)
      break
    end

    robot.turn(true)
  end
end

local function clearInventory()
  local tIngredients = {}
  local tJunk = {}

  for i = 1, robot.inventorySize() do
    local item = inv_controller.getStackInInternalSlot(i)
    if item then
      if item.name == "minecraft:nether_wart" or item.name == "minecraft:gunpowder" or item.name == "minecraft:spider_eye" or item.name == "minecraft:blaze_powder" or item.name == "minecraft:ghast_tear" or item.name == "minecraft:redstone" or item.name == "minecraft:speckled_melon" or item.name == "minecraft:rabbit_foot" or item.name == "minecraft:sugar" or item.name == "minecraft:magma_cream" or item.name == "minecraft:glowstone" or item.name == "minecraft:fermented_spider_eye" then
        table.insert(tIngredients, i)
      else
        table.insert(tJunk, i)
      end
    end
  end

  if #tIngredients > 0 then
    for i = 1, #tIngredients do
      drop(tIngredients[i], sides.front)
    end
  end

  if #tJunk > 0 then
    robot.turn(true)
    for i = 1, #tJunk do
      drop(tJunk[i], sides.front)
    end
    robot.turn(true)
  end
end

local function clearSlot()
	if inv_controller.getStackInSlot(sides.bottom, 1) then
		inv_controller.suckFromSlot(sides.bottom, 1)
		local selectedItem = inv_controller.getStackInInternalSlot()
		local chestSize = inv_controller.getInventorySize(sides.front)
		print(chestSize)

		local tEmptySlots = {}
		local hasEmptiedSlot = false
		for i = 1, chestSize do
			local currentSlot = component.inventory_controller.getStackInSlot(sides.front, i)

			if not currentSlot then
				tEmptySlots.insert(i)
			elseif currentSlot.name == selectedItem.name then
				if currentSlot.size < currentSlot.maxSize then
					inv_controller.dropIntoSlot(sides.front, i, selectedItem.size)
					hasEmptiedSlot = true
					break
				end
			end
		end

		if not hasEmptiedSlot then
			inv_controller.dropIntoSlot(sides.front, tEmptySlots[1], selectedItem.size)
		end
	end
end

local function isIngredientPresent(ingredient)
  local chestSize = inv_controller.getInventorySize(sides.front)
  for i = 1, chestSize do
    local currentSlot = inv_controller.getStackInSlot(sides.front, i)

      if currentSlot and currentSlot.name == ingredient then
        return true, i
      end
  end

  return false
end

local function putIngredient(ingredient)
  local success, slot = isIngredientPresent(ingredient)
  if success then
    inv_controller.suckFromSlot(sides.front, slot, 1)
    inv_controller.dropIntoSlot(sides.bottom, 1, 1)
  end

  return success
end

local function modemMessageHandler(_, local_address, remote_address, port, distance, ...)
  local msg = {...}

  if msg[1] == "addPotion" then
  	local potion = msg[2]
    local modifier = msg[3]
    local qty = msg[4]
    modifier = tonumber(modifier)
    qty = tonumber(qty)
  	print("Received addPotion")

    if not modifier then
      modifier = 0
    end
    if not qty then
      qty = 1
    end

  	if tPotions[potion] then
  		local ingredients = tPotions[potion]
      local tPotion = {}

      if (potion) ~= "weakness" then
        table.insert(tPotion, "minecraft:nether_wart")
      end

  		if type(ingredients) == "string" then
  			-- Only one ingredient
  			print("only one ingredient")
  			table.insert(tPotion, ingredients)
  		elseif type(ingredients) == "table" then
  			-- 2+ ingredients
  			if type(ingredients[1]) == "string" and type(ingredients[2]) == "string" then
          table.insert(tPotion, ingredients[1])
          table.insert(tPotion, ingredients[2])
  			elseif type(ingredients[1]) == "table" and type(ingredients[2]) == "table" then
          local firstSet = ingredients[1]
          local secondSet = ingredients[2]

          if isIngredientPresent(firstSet[1]) then
            table.insert(tPotion, firstSet[1])
          elseif isIngredientPresent(secondSet[1]) then
            table.insert(tPotion, secondSet[1])
          else
            table.insert(tPotion, {firstSet[1], secondSet[1]})
          end
          table.insert(tPotion, firstSet[2])
  			end
  		end

      local hasGlowstone = bit32.band(modifier, 1) ~= 0
      local hasRedstone = bit32.band(modifier, 2) ~= 0
      local hasSplash = bit32.band(modifier, 4) ~= 0
      local hasLingering = bit32.band(modifier, 8) ~= 0

      local flagStr = "Flags: "
      if hasGlowstone then
        flagStr = flagStr.."G"
        table.insert(tPotion, "minecraft:glowstone")
      end
      if hasRedstone and not hasGlowstone then
        flagStr = flagStr.."R"
        table.insert(tPotion, "minecraft:redstone")
      end
      if hasSplash and not hasLingering then
        flagStr = flagStr.."S"
        table.insert(tPotion, "minecraft:gunpowder")
      end
      if hasLingering then
        flagStr = flagStr.."L"
        table.insert(tPotion, "minecraft:gunpowder")
        table.insert(tPotion, "minecraft:dragon_breath")
      end
      print(flagStr)

      table.insert(tQueue, {["ingredients"] = tPotion, ["ingredientsLeft"] = deepcopy(tPotion), ["name"] = potion, ["isReady"] = false, ["quantity"] = qty})
  	end
  elseif msg[1] == "getState" then
    local tData = {}

    if nState == 4 then
      tData = tMissingComponents
    end

    net_card.broadcast(4000, "updateState", serialization.serialize(tQueue), nState, serialization.serialize(tData))
  elseif msg[1] == "removePotion" then
    local potionToRemove = tonumber(msg[2])
    if potionToRemove and tQueue[potionToRemove] then
      table.remove(tQueue, potionToRemove)
      net_card.broadcast(4000, "potionRemoved", potionToRemove)
    end
  elseif msg[1] == "verification" then
    print("Verification received")
    if nState == 3 or nState == 4 then
      local tPotionToDo = tQueue[1]

      if tPotionToDo and not tPotionToDo["ready"] then
        if msg[2] and msg[3] then
          tPotionToDo["ready"] = true
          nState = 1
        else
          nState = 4
          tMissingComponents = {msg[2], msg[3]}
        end
      end
    end
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
  if #tQueue > 0 then
    if not inv_controller.getStackInSlot(sides.bottom, 1) then
      while true do
        local tPotionToDo = tQueue[1]
        print("Current state: "..nState)

        if not tPotionToDo then
          nState = 0
          break
        end

        if nState == 3 or nState == 4 then
          break
        end

        if #tPotionToDo["ingredientsLeft"] == 0 and tPotionToDo["quantity"] == 1 then
          table.remove(tQueue, 1)
          net_card.broadcast(4000, "potionFinished")

          nState = 5
          print("Finished!")
        else
          if #tPotionToDo["ingredientsLeft"] == 0 and tPotionToDo["quantity"] > 1 then
            tPotionToDo["quantity"] = tPotionToDo["quantity"] - 1
            tPotionToDo["ingredientsLeft"] = deepcopy(tPotionToDo["ingredients"])
            tPotionToDo["ready"] = false

            net_card.broadcast(4000, "notifyQuantityDecreased")

            nState = 5
          end

          if not tPotionToDo["isReady"] and (nState == 5 or nState == 0) then
            net_card.broadcast(4000, "wantsVerification")
            nState = 3

            break
          end

          local currentIngredient = tPotionToDo["ingredientsLeft"][1]

          if type(currentIngredient) == "string" then
            if (putIngredient(currentIngredient)) then
              net_card.broadcast(4000, "notifyIngredient")

              nState = 1
              table.remove(tQueue[1]["ingredientsLeft"], 1)
            else
              if nState ~= 2 then
                nState = 2

                print("Missing ingredient: "..currentIngredient)
                net_card.broadcast(4000, "notifyMissingIngredient")
              end
            end
          elseif type(currentIngredient) == "table" then
            local ingredientToUse
            local ingredientsStr = currentIngredient[1]
            for i = 1, #currentIngredient do
              if i > 1 then
                ingredientsStr = ingredientsStr.." or "..currentIngredient[i]
              end

              if isIngredientPresent(currentIngredient[i]) then
                ingredientToUse = currentIngredient[i]
              end
            end

            if ingredientToUse and string.len(ingredientToUse) > 0 then
              putIngredient(ingredientToUse)
              net_card.broadcast(4000, "notifyIngredient")

              nState = 1
              table.remove(tQueue[1]["ingredientsLeft"], 1)
            else
              if nState ~= 2 then
                nState = 2

                print("Missing ingredients: "..ingredientsStr)
                net_card.broadcast(4000, "notifyMissingIngredient")
              end
            end
          end

          break
        end
      end
    end
  end

  os.sleep(1)
end
