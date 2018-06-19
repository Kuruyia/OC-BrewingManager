local bRun = true
local tPotionsName = {["night_vision"] = "Night Vision", ["invisibility"] = "Invisibility", ["fire_resistance"] = "Fire Resistance", ["leaping"] = "Leaping", ["slowness"] = "Slowness", ["swiftness"] = "Swiftness", ["water_breathing"] = "Water Breathing", ["healing"] = "Healing", ["harming"] = "Harming", ["poison"] = "Poison", ["regeneration"] = "Regeneration", ["strength"] = "Strength", ["weakness"] = "Weakness"}
local tPotionsIndex = {{["name"] = "Night Vision", ["id"] = "night_vision", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Invisibility", ["id"] = "invisibility", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Fire Resistance", ["id"] = "fire_resistance", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Leaping", ["id"] = "leaping", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Slowness", ["id"] = "slowness", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Swiftness", ["id"] = "swiftness", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Water Breathing", ["id"] = "water_breathing", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Healing", ["id"] = "healing", ["glowstone"] = true, ["redstone"] = false}, {["name"] = "Harming", ["id"] = "harming", ["glowstone"] = true, ["redstone"] = false}, {["name"] = "Poison", ["id"] = "poison", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Regeneration", ["id"] = "regeneration", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Strength", ["id"] = "strength", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Weakness", ["id"] = "weakness", ["glowstone"] = false, ["redstone"] = true}}
local tIngredientName = {["minecraft:nether_wart"] = "Nether Wart", ["minecraft:gunpowder"] = "Gunpowder", ["minecraft:spider_eye"] = "Spider Eye", ["minecraft:blaze_powder"] = "Blaze Powder", ["minecraft:ghast_tear"] = "Ghast Tear", ["minecraft:redstone"] = "Redstone", ["minecraft:speckled_melon"] = "Glistering Melon", ["minecraft:rabbit_foot"] = "Rabbit's Foot", ["minecraft:sugar"] = "Sugar", ["minecraft:magma_cream"] = "Magma Cream", ["minecraft:glowstone"] = "Glowstone", ["minecraft:fermented_spider_eye"] = "Fermented Spider Eye"}

local tQueue = {}
local nState = 0

local nSelectedButton = {["buttonNumber"] = 0, ["column"] = 0, ["line"] = 0, ["glowstone"] = false, ["redstone"] = false, ["splash"] = false, ["lingering"] = false, ["quantity"] = 1}

local component = require("component")
local event = require("event")
local sides = require("sides")
local table = require("table")
local term = require("term")
local serialization = require("serialization")
local ui = dofile("ui.lua")
local net_card = component.modem
local gpu = component.gpu
net_card.open(4000)

local w, h = gpu.getResolution()

local function modemMessageHandler(_, local_address, remote_address, port, distance, ...)
  local msg = {...}

  if msg[1] == "updateState" then
  	tQueue = serialization.unserialize(msg[2])
  	nState = tonumber(msg[3])

  	tQueue = {}
  	for i = 1, 64 do
  		table.insert(tQueue, {["name"] = "invisibility"})
  	end

  	ui.setList(tQueue)
  elseif msg[1] == "potionFinished" then
  	table.remove(tQueue, 1)
  	ui.setList(tQueue)

  	if #tQueue == 0 then
  		nState = 0
  	end
  elseif msg[1] == "potionRemoved" then
  	table.remove(tQueue, tonumber(msg[2]))
  	ui.setList(tQueue)
  elseif msg[1] == "notifyMissingIngredient" then
  	nState = 2
  	ui.updateListHeader(tQueue, nState)
  elseif msg[1] == "notifyIngredient" then
  	nState = 1
  	table.remove(tQueue[1]["ingredients"], 1)

  	ui.updateListHeader(tQueue, nState)
  end
end

event.listen("modem_message", modemMessageHandler)

net_card.broadcast(4000, "getState")

ui.setupInterface()

ui.setCloseHandler(function()
	bRun = false
	
	event.ignore("modem_message", modemMessageHandler)
	net_card.close(4000)

	ui.close()
end)

ui.setPotionRemoveHandler(function(potionIndex)
	net_card.broadcast(4000, "removePotion", potionIndex)
end)

ui.setPotionSelectedHandler(function(newColumn, newLine, newButtonNumber, newName)
	local oldColumn = nSelectedButton["column"]
	local oldLine = nSelectedButton["line"]
	local oldNumber = nSelectedButton["buttonNumber"]

	local oldName
	if oldNumber > 0 then
		oldName = tPotionsIndex[oldNumber]["name"]
	end

	nSelectedButton["buttonNumber"] = newButtonNumber
	nSelectedButton["column"] = newColumn
	nSelectedButton["line"] = newLine

	ui.selectButton(newColumn, newLine, newName, oldColumn, oldLine, oldName)

	if not tPotionsIndex[newButtonNumber]["glowstone"] then
		nSelectedButton["glowstone"] = false
	end
	if not tPotionsIndex[newButtonNumber]["redstone"] then
		nSelectedButton["redstone"] = false
	end

	ui.setFlags(nSelectedButton["glowstone"], nSelectedButton["redstone"], tPotionsIndex[newButtonNumber]["glowstone"], tPotionsIndex[newButtonNumber]["redstone"])
end)

ui.setFlagHandler(function(flagType)
	if flagType == "glowstone" then
		if nSelectedButton["buttonNumber"] > 0 and tPotionsIndex[nSelectedButton["buttonNumber"]]["glowstone"] then
			nSelectedButton["glowstone"] = not nSelectedButton["glowstone"]
			if nSelectedButton["glowstone"] then
				nSelectedButton["redstone"] = false
			end

			ui.setFlags(nSelectedButton["glowstone"], nSelectedButton["redstone"], tPotionsIndex[nSelectedButton["buttonNumber"]]["glowstone"], tPotionsIndex[nSelectedButton["buttonNumber"]]["redstone"])
		end
	elseif flagType == "redstone" then
		if nSelectedButton["buttonNumber"] > 0 and tPotionsIndex[nSelectedButton["buttonNumber"]]["redstone"] then
			nSelectedButton["redstone"] = not nSelectedButton["redstone"]
			if nSelectedButton["redstone"] then
				nSelectedButton["glowstone"] = false
			end

			ui.setFlags(nSelectedButton["glowstone"], nSelectedButton["redstone"], tPotionsIndex[nSelectedButton["buttonNumber"]]["glowstone"], tPotionsIndex[nSelectedButton["buttonNumber"]]["redstone"])
		end
	elseif flagType == "splash" then
		nSelectedButton["splash"] = not nSelectedButton["splash"]
		if nSelectedButton["splash"] then
			nSelectedButton["lingering"] = false
		end

		ui.setSecondFlags(nSelectedButton["splash"], nSelectedButton["lingering"])
	elseif flagType == "lingering" then
		nSelectedButton["lingering"] = not nSelectedButton["lingering"]
		if nSelectedButton["lingering"] then
			nSelectedButton["splash"] = false
		end

		ui.setSecondFlags(nSelectedButton["splash"], nSelectedButton["lingering"])
	end
end)

ui.setQuantityHandler(function(direction)
	if (nSelectedButton["quantity"] > 1 and direction == -1) or (nSelectedButton["quantity"] < 64 and direction == 1) then
		nSelectedButton["quantity"] = nSelectedButton["quantity"] + direction
		ui.updateNumericUpDownText(nSelectedButton["quantity"])
	end
end)

ui.setConfirmHandler(function()
	if nSelectedButton["buttonNumber"] > 0 then
		local flags = 0
		if nSelectedButton["glowstone"] then
			flags = bit32.bor(flags, 1)
		end
		if nSelectedButton["redstone"] and not nSelectedButton["glowstone"] then
			flags = bit32.bor(flags, 2)
		end
		if nSelectedButton["splash"] and not nSelectedButton["lingering"] then
			flags = bit32.bor(flags, 4)
		end
		if nSelectedButton["lingering"] then
			flags = bit32.bor(flags, 8)
		end

		net_card.broadcast(4000, "addPotion", tPotionsIndex[nSelectedButton["buttonNumber"]]["id"], flags, nSelectedButton["quantity"])
		net_card.broadcast(4000, "getState")
	end
end)

ui.setListScrollHandler(function(direction)
	if direction == -1 then
		if ui.getListOffset() > 0 then
			ui.scrollListUp(tQueue)
		end
	elseif direction == 1 then
		if ui.getListOffset() < #tQueue - h - 5 then
			ui.scrollListDown(tQueue)
		end
	end
end)

while bRun do
	os.sleep(1)
end