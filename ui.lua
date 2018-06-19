local ui = {}

local component = require("component")
local term = require("term")
local event = require("event")
local gpu = component.gpu

local w, h = gpu.getResolution()
local tPotionsName = {["night_vision"] = "Night Vision", ["invisibility"] = "Invisibility", ["fire_resistance"] = "Fire Resistance", ["leaping"] = "Leaping", ["slowness"] = "Slowness", ["swiftness"] = "Swiftness", ["water_breathing"] = "Water Breathing", ["healing"] = "Healing", ["harming"] = "Harming", ["poison"] = "Poison", ["regeneration"] = "Regeneration", ["strength"] = "Strength", ["weakness"] = "Weakness"}
local tPotionsIndex = {{["name"] = "Night Vision", ["id"] = "night_vision", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Invisibility", ["id"] = "invisibility", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Fire Resistance", ["id"] = "fire_resistance", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Leaping", ["id"] = "leaping", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Slowness", ["id"] = "slowness", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Swiftness", ["id"] = "swiftness", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Water Breathing", ["id"] = "water_breathing", ["glowstone"] = false, ["redstone"] = true}, {["name"] = "Healing", ["id"] = "healing", ["glowstone"] = true, ["redstone"] = false}, {["name"] = "Harming", ["id"] = "harming", ["glowstone"] = true, ["redstone"] = false}, {["name"] = "Poison", ["id"] = "poison", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Regeneration", ["id"] = "regeneration", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Strength", ["id"] = "strength", ["glowstone"] = true, ["redstone"] = true}, {["name"] = "Weakness", ["id"] = "weakness", ["glowstone"] = false, ["redstone"] = true}}
local listOffset = 0

local closeHandler, potionRemoveHandler, potionSelectedHandler, flagHandler, quantityHandler, confirmHandler, listScrollHandler

local function drawRectangle(startX, startY, endX, endY)
	gpu.fill(startX, startY, endX - startX + 1, endY - startY + 1, " ")
end

local function drawPixel(x, y)
	drawRectangle(x, y, x, y)
end

local function drawWindow()
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
end

function ui.drawListHeader(list, state)
	term.setCursor(2, 3)
  	gpu.setForeground(0x000000)
  	gpu.setBackground(0xFFFFFF)
  	term.clearLine()
  	term.setCursor(2, 3)
  
  	term.write("Queue: "..#list)

  	if state == 2 then
  		local currentIngredient = list[1]["ingredients"][1]
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

local function drawList(list, state, from)
	if from > #list - h - 4 then
		from = #list - h - 4
	end
	if from < 1 then
		from = 1
	end
	listOffset = from - 1

	if state then
		ui.drawListHeader(list, state)
	end

	gpu.setBackground(0x0092FF)
	drawRectangle(2, 4, w / 2 - 1, h - 1)

	gpu.setBackground(0xA5A5A5)
	drawRectangle(w / 2 - 1, 4, w / 2 - 1, h - 1)

	gpu.setBackground(0x00DBFF)
	gpu.setForeground(0xFFFFFF)
	term.setCursor(w / 2 - 1, 4)
	term.write("-")
	term.setCursor(w / 2 - 1, h - 1)
	term.write("+")

  	gpu.setBackground(0x0092FF)
  	for i = 1, #list do
  		term.setCursor(2, 4 + i - 1)
  		term.write(tPotionsName[list[i + listOffset]["name"]])

  		if i + listOffset > 1 then
  			gpu.setBackground(0xFF0000)
  			term.setCursor(w / 2 - 2, 4 + i - 1)
  			term.write("X")
  			gpu.setBackground(0x0092FF)
  		end

  		if i == h - 4 then
  			break
  		end
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

local function setupButtonMatrix()
	for i = 1, 4 do
		for j = 1, 3 do
			local buttonNumber = i + (j - 1) * 4
			drawButton(i, j, tPotionsIndex[buttonNumber]["name"], false)
		end
	end

	drawButton(1, 4, tPotionsIndex[13]["name"], false)
end

local function drawFlag(posX, posY, name, isEnabled, isVisible)
	if isVisible then
		if not isEnabled then
			gpu.setBackground(0x696969)
			drawRectangle(posX, posY, posX + 4, posY)

			gpu.setBackground(0xC3C3C3)
			drawPixel(posX, posY)
		else
			gpu.setBackground(0x009200)
			drawRectangle(posX, posY, posX + 4, posY)

			gpu.setBackground(0x00DB00)
			drawPixel(posX + 4, posY)
		end

		gpu.setBackground(0xFFFFFF)
		gpu.setForeground(0x000000)
		term.setCursor(posX + 6, posY)
		term.write(name)
	else
		gpu.setBackground(0xFFFFFF)
		drawRectangle(posX, posY, posX + 5 + string.len(name), posY)
	end
end

local function setupFlags()
	drawFlag(85, 22, "Glowstone", false, true)
	drawFlag(85, 24, "Redstone", false, true)
	drawFlag(121, 22, "Splash", false, true)
	drawFlag(121, 24, "Lingering", false, true)
end

local function drawConfirmButton()
	gpu.setBackground(0x00DB00)
	gpu.setForeground(0xFFFFFF)

	drawRectangle(147, 32, 155, 36)
	term.setCursor(151, 34)
	term.write(">")
end

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

local function touchHandler(_, screen_address, x, y, button, player_name)
	if x >= w - 4 and x <= w and y == 1 then
		closeHandler()
	elseif x == w / 2 - 2 and y >= 5 and y <= h - 1 then
		potionRemoveHandler(y - 3 + listOffset)
	elseif x >= w / 2 + 5 and x <= (w / 2 + 5) + 70 and y >= 4 and y <= 18 then
		if x % 18 ~= 12 and y % 4 ~= 3 then
			local column = math.floor((x - (w / 2 + 5) + 1) / 18) + 1
			local line = math.floor((y - 3) / 4) + 1
			local buttonNumber = column + (line - 1) * 4
			local newName = tPotionsIndex[buttonNumber]["name"]

			potionSelectedHandler(column, line, buttonNumber, newName)
		end
	elseif x >= 85 and x <= 110 and y == 22 then
		flagHandler("glowstone")
	elseif x >= 85 and x <= 110 and y == 24 then
		flagHandler("redstone")
	elseif x >= 121 and x <= 146 and y == 22 then
		flagHandler("splash")
	elseif x >= 121 and x <= 146 and y == 24 then
		flagHandler("lingering")
	elseif x >= 85 and x <= 87 and y == 28 then
		quantityHandler(-1)
	elseif x >= 153 and x <= 155 and y == 28 then
		quantityHandler(1)
	elseif x >= 147 and x <= 155 and y >= 32 and y <= 36 then
		confirmHandler()
	elseif x == w / 2 - 1 and y == 4 then
		listScrollHandler(-1)
	elseif x == w / 2 - 1 and y == h - 1 then
		listScrollHandler(1)
	end
end

function ui.updateNumericUpDownText(qty)
	gpu.setBackground(0x0092FF)
	gpu.setForeground(0xFFFFFF)
	drawRectangle(88, 28, 152, 28)

	local baseTextX = (88 + 152) / 2
	local baseTextY = 28
	local textOffset = string.len(qty) / 2

	term.setCursor(baseTextX - textOffset, baseTextY)
	term.write(qty)
end

function ui.setupInterface()
	drawWindow()
	drawList({}, 0, 1)
	setupButtonMatrix()
	setupFlags()
	drawConfirmButton()
	drawNumericUpDown()
	ui.updateNumericUpDownText(1)

	event.listen("touch", touchHandler)
end

function ui.close()
	event.ignore("touch", touchHandler)

	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
	gpu.fill(1, 1, w, h, " ")
	term.setCursor(1, 1)
end

function ui.selectButton(newColumn, newLine, newText, oldColumn, oldLine, oldText)
	if oldColumn > 0 and oldLine > 0 then
		drawButton(oldColumn, oldLine, oldText, false)
	end

	drawButton(newColumn, newLine, newText, true)
end

function ui.setFlags(isGlowstoneEnabled, isRedstoneEnabled, isGlowstoneVisible, isRedstoneVisible)
	drawFlag(85, 22, "Glowstone", isGlowstoneEnabled, isGlowstoneVisible or isGlowstoneVisible == nil)
	drawFlag(85, 24, "Redstone", isRedstoneEnabled, isRedstoneVisible or isRedstoneVisible == nil)
end

function ui.setSecondFlags(isSplashEnabled, isLingeringEnabled)
	drawFlag(121, 22, "Splash", isSplashEnabled, true)
	drawFlag(121, 24, "Lingering", isLingeringEnabled, true)
end

function ui.getListOffset()
	return listOffset
end

function ui.scrollListDown(list)
	drawList(list, nil, listOffset + 2)
end

function ui.scrollListUp(list)
	drawList(list, nil, listOffset)
end

function ui.setList(list)
	drawList(list, nil, listOffset + 1)
end

function ui.setCloseHandler(func)
	closeHandler = func
end

function ui.setPotionRemoveHandler(func)
	potionRemoveHandler = func
end

function ui.setPotionSelectedHandler(func)
	potionSelectedHandler = func
end

function ui.setFlagHandler(func)
	flagHandler = func
end

function ui.setQuantityHandler(func)
	quantityHandler = func
end

function ui.setConfirmHandler(func)
	confirmHandler = func
end

function ui.setListScrollHandler(func)
	listScrollHandler = func
end

return ui