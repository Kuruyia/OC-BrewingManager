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
local net_card = component.modem
local gpu = component.gpu
net_card.open(4000)

local function drawRectangle(startX, startY, endX, endY)
	gpu.fill(startX, startY, endX - startX + 1, endY - startY + 1, " ")
end

local function drawPixel(x, y)
	drawRectangle(x, y, x, y)
end

local w, h = gpu.getResolution()
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0xFFFFFF)
gpu.fill(1, 1, w, h, " ")

gpu.setBackground(0xA5A5A5)
gpu.fill(1, 1, w, 1, " ")
term.setCursor(1, 1)
term.write("Brewing Manager")

gpu.setBackground(0xFF0000)
gpu.fill(w - 4, 1, w, 1, " ")
term.setCursor(w - 2, 1)
term.write("X")

local function drawNumericUpDown()
	gpu.setBackground(0x00DBFF)
	gpu.setForeground(0xFFFFFF)

	drawRectangle(85, 28, 87, 28)
	term.setCursor(86, 28)
	term.write("-")

	drawRectangle(153, 28, 155, 28)
	term.setCursor(154, 28)
	term.write("+")
end

local function updateNumericUpDown()
	gpu.setBackground(0x0092FF)
	gpu.setForeground(0xFFFFFF)
	drawRectangle(88, 28, 152, 28)

	local baseTextX = (88 + 152) / 2
	local baseTextY = 28
	local textOffset = string.len(nSelectedButton["quantity"]) / 2

	term.setCursor(baseTextX - textOffset, baseTextY)
	term.write(nSelectedButton["quantity"])
end

local function drawFlags(isGlowstoneEnabled, isRedstoneEnabled)
	if isGlowstoneEnabled == nil then
		if nSelectedButton["buttonNumber"] > 0 then
			isGlowstoneEnabled = tPotionsIndex[nSelectedButton["buttonNumber"]]["glowstone"]
		else
			isGlowstoneEnabled = false
		end
	end

	if isRedstoneEnabled == nil then
		if nSelectedButton["buttonNumber"] > 0 then
			isRedstoneEnabled = tPotionsIndex[nSelectedButton["buttonNumber"]]["redstone"]
		else
			isRedstoneEnabled = false
		end
	end

	gpu.setBackground(0xFFFFFF)
	drawRectangle(85, 22, 120, 24)

	if nSelectedButton["splash"] then
		gpu.setBackground(0x009200)
		drawRectangle(121, 22, 125, 22)

		gpu.setBackground(0x00DB00)
		drawPixel(125, 22)
	else
		gpu.setBackground(0x696969)
		drawRectangle(121, 22, 125, 22)

		gpu.setBackground(0xC3C3C3)
		drawPixel(121, 22)
	end

	if nSelectedButton["lingering"] then
		gpu.setBackground(0x009200)
		drawRectangle(121, 24, 125, 24)

		gpu.setBackground(0x00DB00)
		drawPixel(125, 24)
	else
		gpu.setBackground(0x696969)
		drawRectangle(121, 24, 125, 24)

		gpu.setBackground(0xC3C3C3)
		drawPixel(121, 24)
	end

	gpu.setForeground(0x000000)
	gpu.setBackground(0xFFFFFF)
	term.setCursor(127, 22)
	term.write("Splash")
	term.setCursor(127, 24)
	term.write("Lingering")

	if isGlowstoneEnabled then
		if nSelectedButton["glowstone"] then
			gpu.setBackground(0x009200)
			drawRectangle(85, 22, 89, 22)

			gpu.setBackground(0x00DB00)
			drawPixel(89, 22)
		else
			gpu.setBackground(0x696969)
			drawRectangle(85, 22, 89, 22)

			gpu.setBackground(0xC3C3C3)
			drawPixel(85, 22)
		end

		gpu.setForeground(0x000000)
		gpu.setBackground(0xFFFFFF)
		term.setCursor(91, 22)
		term.write("Glowstone")
	end

	if isRedstoneEnabled then
		if nSelectedButton["redstone"] then
			gpu.setBackground(0x009200)
			drawRectangle(85, 24, 89, 24)

			gpu.setBackground(0x00DB00)
			drawPixel(89, 24)
		else
			gpu.setBackground(0x696969)
			drawRectangle(85, 24, 89, 24)

			gpu.setBackground(0xC3C3C3)
			drawPixel(85, 24)
		end

		gpu.setForeground(0x000000)
		gpu.setBackground(0xFFFFFF)
		term.setCursor(91, 24)
		term.write("Redstone")
	end
end

local function drawButton(column, line, text, highlighted)
	local baseX = w / 2 + 5
	local baseY = 4
	local buttonWidth = 16
	local buttonHeight = 2

	local startX = baseX + ((buttonWidth + 2) * (column - 1))
	local startY = baseY + ((buttonHeight + 2) * (line - 1))

	if highlighted then
		gpu.setBackground(0x00DB00)
	else
		gpu.setBackground(0x00DBFF)
	end
	drawRectangle(startX, startY, startX + buttonWidth, startY + buttonHeight)

	local textBaseX = startX + (buttonWidth / 2)
	local textBaseY = startY + 1
	local textOffset = math.ceil(string.len(text) / 2)

	gpu.setForeground(0xFFFFFF)
	term.setCursor(textBaseX - textOffset + 1, textBaseY)
	term.write(text)
end

local function drawButtonMatrix()
	for i = 1, 4 do
		for j = 1, 3 do
			local buttonNumber = i + (j - 1) * 4
			drawButton(i, j, tPotionsIndex[buttonNumber]["name"], false)
		end
	end

	drawButton(1, 4, tPotionsIndex[13]["name"], false)
end

local function updateListHeader()
	term.setCursor(2, 3)
  	gpu.setForeground(0x000000)
  	gpu.setBackground(0xFFFFFF)
  	term.clearLine()
  	term.setCursor(2, 3)
  
  	term.write("Queue: "..#tQueue)

  	if nState == 2 then
  		local currentIngredient = tQueue[1]["ingredients"][1]
  		local ingredientStr = ""

  		if type(currentIngredient) == "string" then
  			ingredientStr = tIngredientName[currentIngredient]
  		elseif type(currentIngredient) == "table" then
  			ingredientStr = tIngredientName[currentIngredient[1]]
  			for i = 2, #currentIngredient do
  				ingredientStr = ingredientStr.." or "..tIngredientName[currentIngredient[i]]
  			end
  		end

  		gpu.setForeground(0xFF0000)
  		term.write(" - Missing ingredient: "..ingredientStr)
  	end
end

local function updateList()
	updateListHeader()

  	gpu.setBackground(0x0092FF)
	drawRectangle(2, 4, w / 2 - 1, h - 1)

  	gpu.setForeground(0xFFFFFF)
  	for i = 1, #tQueue do
  		term.setCursor(2, 4 + i - 1)
  		term.write(tPotionsName[tQueue[i]["name"]])

  		if i > 1 then
  			gpu.setBackground(0xFF0000)
  			term.setCursor(w / 2 - 1, 4 + i - 1)
  			term.write("X")
  			gpu.setBackground(0x0092FF)
  		end
  	end
end

local function modemMessageHandler(_, local_address, remote_address, port, distance, ...)
  local msg = {...}

  if msg[1] == "updateState" then
  	tQueue = serialization.unserialize(msg[2])
  	nState = tonumber(msg[3])
  	updateList()
  elseif msg[1] == "potionFinished" then
  	table.remove(tQueue, 1)
  	updateList()

  	if #tQueue == 0 then
  		nState = 0
  	end
  elseif msg[1] == "potionRemoved" then
  	table.remove(tQueue, tonumber(msg[2]))
  	updateList()
  elseif msg[1] == "notifyMissingIngredient" then
  	nState = 2
  	updateListHeader()
  elseif msg[1] == "notifyIngredient" then
  	nState = 1
  	table.remove(tQueue[1]["ingredients"], 1)

  	updateListHeader()
  end
end

local function touchHandler(_, screen_address, x, y, button, player_name)
	if x >= w - 4 and x <= w and y == 1 then
		bRun = false
	
		event.ignore("modem_message", modemMessageHandler)
		event.ignore("touch", touchHandler)
		net_card.close(4000)

		gpu.setBackground(0x000000)
		gpu.setForeground(0xFFFFFF)
		gpu.fill(1, 1, w, h, " ")
		term.setCursor(1, 1)
	elseif x == w / 2 - 1 and y >= 5 and y <= h - 1 then
		local nElement = y - 3
		net_card.broadcast(4000, "removePotion", nElement)
	elseif x >= w / 2 + 5 and x <= (w / 2 + 5) + 70 and y >= 4 and y <= 18 then
		if x % 18 ~= 12 and y % 4 ~= 3 then
			local column = math.floor((x - (w / 2 + 5) + 1) / 18) + 1
			local line = math.floor((y - 3) / 4) + 1
			local buttonNumber = column + (line - 1) * 4

			if nSelectedButton["buttonNumber"] > 0 then
				drawButton(nSelectedButton["column"], nSelectedButton["line"], tPotionsIndex[nSelectedButton["buttonNumber"]]["name"], false)
			end

			nSelectedButton["buttonNumber"] = buttonNumber
			nSelectedButton["column"] = column
			nSelectedButton["line"] = line
			drawButton(column, line, tPotionsIndex[buttonNumber]["name"], true)
			drawFlags(tPotionsIndex[buttonNumber]["glowstone"], tPotionsIndex[buttonNumber]["redstone"])

			if not tPotionsIndex[buttonNumber]["glowstone"] then
				nSelectedButton["glowstone"] = false
			end
			if not tPotionsIndex[buttonNumber]["redstone"] then
				nSelectedButton["redstone"] = false
			end
		end
	elseif x >= 85 and x <= 110 and y == 22 then
		if nSelectedButton["buttonNumber"] > 0 and tPotionsIndex[nSelectedButton["buttonNumber"]]["glowstone"] then
			nSelectedButton["glowstone"] = not nSelectedButton["glowstone"]
			if nSelectedButton["glowstone"] then
				nSelectedButton["redstone"] = false
			end

			drawFlags()
		end
	elseif x >= 85 and x <= 110 and y == 24 then
		if nSelectedButton["buttonNumber"] > 0 and tPotionsIndex[nSelectedButton["buttonNumber"]]["redstone"] then
			nSelectedButton["redstone"] = not nSelectedButton["redstone"]
			if nSelectedButton["redstone"] then
				nSelectedButton["glowstone"] = false
			end

			drawFlags()
		end
	elseif x >= 121 and x <= 146 and y == 22 then
		nSelectedButton["splash"] = not nSelectedButton["splash"]
		if nSelectedButton["splash"] then
			nSelectedButton["lingering"] = false
		end

		drawFlags()
	elseif x >= 121 and x <= 146 and y == 24 then
		nSelectedButton["lingering"] = not nSelectedButton["lingering"]
		if nSelectedButton["lingering"] then
			nSelectedButton["splash"] = false
		end

		drawFlags()
	elseif x >= 85 and x <= 87 and y == 28 then
		if nSelectedButton["quantity"] > 1 then
			nSelectedButton["quantity"] = nSelectedButton["quantity"] - 1
		end

		updateNumericUpDown()
	elseif x >= 153 and x <= 155 and y == 28 then
		if nSelectedButton["quantity"] < 64 then
			nSelectedButton["quantity"] = nSelectedButton["quantity"] + 1
		end

		updateNumericUpDown()
	elseif x >= 147 and x <= 155 and y >= 32 and y <= 36 then
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
	end
end

event.listen("modem_message", modemMessageHandler)
event.listen("touch", touchHandler)

net_card.broadcast(4000, "getState")

drawButtonMatrix()
drawFlags(false, false)
drawNumericUpDown()
updateNumericUpDown()

gpu.setBackground(0x00DB00)
drawRectangle(147, 32, 155, 36)
term.setCursor(151, 34)
term.write(">")

while bRun do
	os.sleep(1)
end