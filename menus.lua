-- This menu API based on the HPRPCMenu framework
HPRPCMenu = {}
HPRPCMenu.__index = HPRPCMenu
local menus = {}
local keys = {
	down = 187,
	up = 188,
	left = 189,
	right = 190,
	select = 191,
	back = 194
}
local optionCount = 0
local currentKey = nil
local currentMenu = nil
local toolTipWidth = 0.153
local spriteWidth = 0.027
local spriteHeight = spriteWidth * GetAspectRatio()
local titleHeight = 0.101
local titleYOffset = 0.021
local titleFont = 1
local titleScale = 1.0
local buttonHeight = 0.038
local buttonFont = 0
local buttonScale = 0.365
local buttonTextXOffset = 0.005
local buttonTextYOffset = 0.005
local buttonSpriteXOffset = 0.002
local buttonSpriteYOffset = 0.005
local defaultStyle = {
    x = 0.750,
    y = 0.025,
    width = 0.23,
    maxOptionCountOnScreen = 10,
    titleColor = {0, 0, 0, 255},
    titleBackgroundColor = {0, 102, 255, 255},
    titleBackgroundSprite = nil,
    subTitleColor = {0, 102, 255, 255},
    textColor = {255, 255, 255, 255},
    subTextColor = {0, 102, 255, 255},
    focusTextColor = {0, 0, 0, 255},
    focusColor = {245, 245, 245, 255},
    backgroundColor = {0, 0, 0, 160},
    subTitleBackgroundColor = {0, 0, 0, 255},
    buttonPressedSound = {
        name = 'SELECT',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    }
}

-- Declare a local function for setting menu properties
local function setMenuProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]
	if menu then
		menu[property] = value
	end
end

-- Declare a local function for setting style properties
local function setStyleProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]

	if menu then
		if not menu.overrideStyle then
			menu.overrideStyle = { }
		end

		menu.overrideStyle[property] = value
	end
end

-- Declare a local function for getting style properties
local function getStyleProperty(property, menu)
	menu = menu or currentMenu

	if menu.overrideStyle then
		local value = menu.overrideStyle[property]
		if value then
			return value
		end
	end

	return menu.style and menu.style[property] or defaultStyle[property]
end

-- Declare a local function for copying LUA tables.
local function copyTable(t)
	if type(t) ~= 'table' then
		return t
	end

	local result = { }
	for k, v in pairs(t) do
		result[k] = copyTable(v)
	end

	return result
end

-- Declare a local function for setting the menu visible.
local function setMenuVisible(id, visible, holdCurrentOption)
	if currentMenu then
		if visible then
			if currentMenu.id == id then
				return
			end
		else
			if currentMenu.id ~= id then
				return
			end
		end
	end

	if visible then
		local menu = menus[id]

		if not currentMenu then
			menu.currentOption = 1
		else
			if not holdCurrentOption then
				menus[currentMenu.id].currentOption = 1
			end
		end

		currentMenu = menu
	else
		currentMenu = nil
	end
end

-- Declare a local function for setting text parameters
local function setTextParams(font, color, scale, center, shadow, alignRight, wrapFrom, wrapTo)
	SetTextFont(font)
	SetTextColour(color[1], color[2], color[3], color[4] or 255)
	SetTextScale(scale, scale)

	if shadow then
		SetTextDropShadow()
	end

	if center then
		SetTextCentre(true)
	elseif alignRight then
		SetTextRightJustify(true)
	end

	if not wrapFrom or not wrapTo then
		wrapFrom = wrapFrom or getStyleProperty('x')
		wrapTo = wrapTo or getStyleProperty('x') + getStyleProperty('width') - buttonTextXOffset
	end

	SetTextWrap(wrapFrom, wrapTo)
end

-- Declare a local function for getting line counts
local function getLinesCount(text, x, y)
	BeginTextCommandLineCount('TWOSTRINGS')
	AddTextComponentString(tostring(text))
	return EndTextCommandGetLineCount(x, y)
end

-- Declare a local function for drawing text
local function drawText(text, x, y)
	BeginTextCommandDisplayText('TWOSTRINGS')
	AddTextComponentString(tostring(text))
	EndTextCommandDisplayText(x, y)
end

-- Declare a local function for drawing rectangles
local function drawRect(x, y, width, height, color)
	DrawRect(x, y, width, height, color[1], color[2], color[3], color[4] or 255)
end

-- Declare a local function for getting the current index
local function getCurrentIndex()
	if currentMenu.currentOption <= getStyleProperty('maxOptionCountOnScreen') and optionCount <= getStyleProperty('maxOptionCountOnScreen') then
		return optionCount
	elseif optionCount > currentMenu.currentOption - getStyleProperty('maxOptionCountOnScreen') and optionCount <= currentMenu.currentOption then
		return optionCount - (currentMenu.currentOption - getStyleProperty('maxOptionCountOnScreen'))
	end

	return nil
end

-- Declare a local function for drawing titles
local function drawTitle()
	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight / 2

	if getStyleProperty('titleBackgroundSprite') then
		DrawSprite(getStyleProperty('titleBackgroundSprite').dict, getStyleProperty('titleBackgroundSprite').name, x, y, getStyleProperty('width'), titleHeight, 0., 255, 255, 255, 255)
	else
		drawRect(x, y, getStyleProperty('width'), titleHeight, getStyleProperty('titleBackgroundColor'))
	end

	if currentMenu.title then
		setTextParams(titleFont, getStyleProperty('titleColor'), titleScale, true)
		drawText(currentMenu.title, x, y - titleHeight / 2 + titleYOffset)
	end
end

-- Declare a local function for drawing subtitles
local function drawSubTitle()
	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight + buttonHeight / 2

	drawRect(x, y, getStyleProperty('width'), buttonHeight, getStyleProperty('subTitleBackgroundColor'))

	setTextParams(buttonFont, getStyleProperty('subTitleColor'), buttonScale, false)
	drawText(currentMenu.subTitle, getStyleProperty('x') + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)

	if optionCount > getStyleProperty('maxOptionCountOnScreen') then
		setTextParams(buttonFont, getStyleProperty('subTitleColor'), buttonScale, false, false, true)
		drawText(tostring(currentMenu.currentOption)..' / '..tostring(optionCount), getStyleProperty('x') + getStyleProperty('width'), y - buttonHeight / 2 + buttonTextYOffset)
	end
end

-- Declare a local function for drawing buttons
local function drawButton(text, subText)
	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	local backgroundColor = nil
	local textColor = nil
	local subTextColor = nil
	local shadow = false

	if currentMenu.currentOption == optionCount then
		backgroundColor = getStyleProperty('focusColor')
		textColor = getStyleProperty('focusTextColor')
		subTextColor = getStyleProperty('focusTextColor')
	else
		backgroundColor = getStyleProperty('backgroundColor')
		textColor = getStyleProperty('textColor')
		subTextColor = getStyleProperty('subTextColor')
		shadow = true
	end

	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight + buttonHeight + (buttonHeight * currentIndex) - buttonHeight / 2

	drawRect(x, y, getStyleProperty('width'), buttonHeight, backgroundColor)

	setTextParams(buttonFont, textColor, buttonScale, false, shadow)
	drawText(text, getStyleProperty('x') + buttonTextXOffset, y - (buttonHeight / 2) + buttonTextYOffset)

	if subText then
		setTextParams(buttonFont, subTextColor, buttonScale, false, shadow, true)
		drawText(subText, getStyleProperty('x') + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)
	end
end

-- Declare a global function for creating the menu objects
function HPRPCMenu.CreateMenu(id, title, subTitle, style)
	-- Default settings
	local menu = { }

	-- Members
	menu.id = id
	menu.previousMenu = nil
	menu.currentOption = 1
	menu.title = title
	menu.subTitle = subTitle and string.upper(subTitle) or 'INTERACTION MENU'

	-- Style
	if style then
		menu.style = style
	end

    print(json.encode(menu))

	menus[id] = menu

    print(json.encode(menus))
end

-- Declare a global function for creating sub menu objects
function HPRPCMenu.CreateSubMenu(id, parent, subTitle, style)
	local parentMenu = menus[parent]
	if not parentMenu then
		return
	end

	HPRPCMenu.CreateMenu(id, parentMenu.title, subTitle and string.upper(subTitle) or parentMenu.subTitle)

	local menu = menus[id]

	menu.previousMenu = parent

	if parentMenu.overrideStyle then
		menu.overrideStyle = copyTable(parentMenu.overrideStyle)
	end

	if style then
		menu.style = style
	elseif parentMenu.style then
		menu.style = copyTable(parentMenu.style)
	end
end

-- Declare a global function for returning the current menu
function HPRPCMenu.CurrentMenu()
	return currentMenu and currentMenu.id or nil
end

-- Declare a global function for opening menu objects
function HPRPCMenu.OpenMenu(id)
    print(id, menus[id])
    print(json.encode(menus))
	if id and menus[id] then
		PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		setMenuVisible(id, true)
	end
end

-- Declare a global function for checking if a specific menu is opened
function HPRPCMenu.IsMenuOpened(id)
	return currentMenu and currentMenu.id == id
end

-- Declare a alternative object name for IsMenuOpened
HPRPCMenu.Begin = HPRPCMenu.IsMenuOpened

-- Declare a global function for checking if any menu is opened
function HPRPCMenu.IsAnyMenuOpened()
	return currentMenu ~= nil
end

-- Declare a global function for checking if a menu is about to be closed this frame
function HPRPCMenu.IsMenuAboutToBeClosed()
	return false
end

-- Declare a global function for closing a current menu
function HPRPCMenu.CloseMenu()
	if currentMenu then
		setMenuVisible(currentMenu.id, false)
		optionCount = 0
		currentKey = nil
		PlaySoundFrontend(-1, 'QUIT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
	end
end

-- Declare a global function to create a ToolTip icon which appears to the side of a menu item
function HPRPCMenu.ToolTip(text, width, flipHorizontal)
	if not currentMenu then
		return
	end

	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	width = width or toolTipWidth

	local x = nil
	if not flipHorizontal then
		x = getStyleProperty('x') + getStyleProperty('width') + width / 2 + buttonTextXOffset
	else
		x = getStyleProperty('x') - width / 2 - buttonTextXOffset
	end

	local textX = x - (width / 2) + buttonTextXOffset
	setTextParams(buttonFont, getStyleProperty('textColor'), buttonScale, false, true, false, textX, textX + width - (buttonTextYOffset * 2))
	local linesCount = getLinesCount(text, textX, getStyleProperty('y'))

	local height = GetTextScaleHeight(buttonScale, buttonFont) * (linesCount + 1) + buttonTextYOffset
	local y = getStyleProperty('y') + titleHeight + (buttonHeight * currentIndex) + height / 2

	drawRect(x, y, width, height, getStyleProperty('backgroundColor'))

	y = y - (height / 2) + buttonTextYOffset
	drawText(text, textX, y)
end

-- Declare a global function to create menu button items
function HPRPCMenu.Button(text, subText)
	if not currentMenu then
		return
	end

	optionCount = optionCount + 1

	drawButton(text, subText)

	local pressed = false

	if currentMenu.currentOption == optionCount then
		if currentKey == keys.select then
			pressed = true
			PlaySoundFrontend(-1, getStyleProperty('buttonPressedSound').name, getStyleProperty('buttonPressedSound').set, true)
		elseif currentKey == keys.left or currentKey == keys.right then
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		end
	end

	return pressed
end

-- Declare a global function to create sprite buttons
function HPRPCMenu.SpriteButton(text, dict, name, r, g, b, a)
	if not currentMenu then
		return
	end

	local pressed = HPRPCMenu.Button(text)

	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	if not HasStreamedTextureDictLoaded(dict) then
		RequestStreamedTextureDict(dict)
	end
	DrawSprite(dict, name, getStyleProperty('x') + getStyleProperty('width') - spriteWidth / 2 - buttonSpriteXOffset, getStyleProperty('y') + titleHeight + buttonHeight + (buttonHeight * currentIndex) - spriteHeight / 2 + buttonSpriteYOffset, spriteWidth, spriteHeight, 0., r or 255, g or 255, b or 255, a or 255)

	return pressed
end

-- Declare a global function to create input buttons allowing for text input inside the menu
function HPRPCMenu.InputButton(text, windowTitleEntry, defaultText, maxLength, subText)
	if not currentMenu then
		return
	end

	local pressed = HPRPCMenu.Button(text, subText)
	local inputText = nil

	if pressed then
		DisplayOnscreenKeyboard(1, windowTitleEntry or 'FMMC_MPM_NA', '', defaultText or '', '', '', '', maxLength or 255)

		while true do
			DisableAllControlActions(0)

			local status = UpdateOnscreenKeyboard()
			if status == 2 then
				break
			elseif status == 1 then
				inputText = GetOnscreenKeyboardResult()
				break
			end

			Citizen.Wait(0)
		end
	end

	return pressed, inputText
end

-- Declare a global function to create menu buttons
function HPRPCMenu.MenuButton(text, id, subText)
	if not currentMenu then
		return
	end

	local pressed = HPRPCMenu.Button(text, subText)

	if pressed then
		currentMenu.currentOption = optionCount
		setMenuVisible(currentMenu.id, false)
		setMenuVisible(id, true, true)
	end

	return pressed
end

-- Declare a global function to create sprite menu buttons
function HPRPCMenu.CheckBox(text, checked, callback)
	if not currentMenu then
		return
	end

	local name = nil
	if currentMenu.currentOption == optionCount + 1 then
		name = checked and 'shop_box_tickb' or 'shop_box_blankb'
	else
		name = checked and 'shop_box_tick' or 'shop_box_blank'
	end

	local pressed = HPRPCMenu.SpriteButton(text, 'commonmenu', name)

	if pressed then
		checked = not checked
		if callback then callback(checked) end
	end

	return pressed
end

-- Declare a global function to create a combination box allowing for multiple options to be shown
function HPRPCMenu.ComboBox(text, items, currentIndex, selectedIndex, callback)
	if not currentMenu then
		return
	end

	local itemsCount = #items
	local selectedItem = items[currentIndex]
	local isCurrent = currentMenu.currentOption == optionCount + 1
	selectedIndex = selectedIndex or currentIndex

	if itemsCount > 1 and isCurrent then
		selectedItem = '← '..tostring(selectedItem)..' →'
	end

	local pressed = HPRPCMenu.Button(text, selectedItem)

	if pressed then
		selectedIndex = currentIndex
	elseif isCurrent then
		if currentKey == keys.left then
			if currentIndex > 1 then currentIndex = currentIndex - 1 else currentIndex = itemsCount end
		elseif currentKey == keys.right then
			if currentIndex < itemsCount then currentIndex = currentIndex + 1 else currentIndex = 1 end
		end
	end

	if callback then callback(currentIndex, selectedIndex) end
	return pressed, currentIndex
end

-- Declare a global function to display the existing menu, this should be called after all menu tasks have concluded.
function HPRPCMenu.Display()
	if currentMenu then
		DisableControlAction(0, keys.left, true)
		DisableControlAction(0, keys.up, true)
		DisableControlAction(0, keys.down, true)
		DisableControlAction(0, keys.right, true)
		DisableControlAction(0, keys.back, true)

		ClearAllHelpMessages()

		drawTitle()
		drawSubTitle()

		currentKey = nil

		if IsDisabledControlJustReleased(0, keys.down) then
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

			if currentMenu.currentOption < optionCount then
				currentMenu.currentOption = currentMenu.currentOption + 1
			else
				currentMenu.currentOption = 1
			end
		elseif IsDisabledControlJustReleased(0, keys.up) then
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

			if currentMenu.currentOption > 1 then
				currentMenu.currentOption = currentMenu.currentOption - 1
			else
				currentMenu.currentOption = optionCount
			end
		elseif IsDisabledControlJustReleased(0, keys.left) then
			currentKey = keys.left
		elseif IsDisabledControlJustReleased(0, keys.right) then
			currentKey = keys.right
		elseif IsControlJustReleased(0, keys.select) then
			currentKey = keys.select
		elseif IsDisabledControlJustReleased(0, keys.back) then
			if menus[currentMenu.previousMenu] then
				setMenuVisible(currentMenu.previousMenu, true)
				PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			else
				HPRPCMenu.CloseMenu()
			end
		end

		optionCount = 0
	end
end
-- Declare a alternative object name for Display
HPRPCMenu.End = HPRPCMenu.Display

-- Declare a global function to return the current selected option
function HPRPCMenu.CurrentOption()
	if currentMenu and optionCount ~= 0 then
		return currentMenu.currentOption
	end

	return nil
end

-- Declare a global function to check if a menu item is hovered
function HPRPCMenu.IsItemHovered()
	if not currentMenu or optionCount == 0 then
		return false
	end

	return currentMenu.currentOption == optionCount
end

-- Declare a global function to check if a menu item has been selected
function HPRPCMenu.IsItemSelected()
	return currentKey == keys.select and HPRPCMenu.IsItemHovered()
end

-- Declare a global function to set a menu title
function HPRPCMenu.SetTitle(id, title)
	setMenuProperty(id, 'title', title)
end

-- Declare an alternative object name for SetTitle
HPRPCMenu.SetMenuTitle = HPRPCMenu.SetTitle

-- Declare a global function to set a menu subtitle
function HPRPCMenu.SetSubTitle(id, text)
	setMenuProperty(id, 'subTitle', string.upper(text))
end

-- Declare an alternative object name for SetSubTitle
HPRPCMenu.SetMenuSubTitle = HPRPCMenu.SetSubTitle

-- Declare a global function to set the menu style
function HPRPCMenu.SetMenuStyle(id, style)
	setMenuProperty(id, 'style', style)
end

-- Declare a global function to set the menus position on the X axis
function HPRPCMenu.SetMenuX(id, x)
	setStyleProperty(id, 'x', x)
end

-- Declare a global function to set the menus position on the Y axis
function HPRPCMenu.SetMenuY(id, y)
	setStyleProperty(id, 'y', y)
end

-- Declare a global function to set the menus positional width
function HPRPCMenu.SetMenuWidth(id, width)
	setStyleProperty(id, 'width', width)
end

-- Declare a global function to set the menus pre-defined max item count
function HPRPCMenu.SetMenuMaxOptionCountOnScreen(id, count)
	setStyleProperty(id, 'maxOptionCountOnScreen', count)
end

-- Declare a global function to set the menu title colour
function HPRPCMenu.SetTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'titleColor', { r, g, b, a })
end

-- Declare an alternative object name for SetTitleColor
HPRPCMenu.SetMenuTitleColor = HPRPCMenu.SetTitleColor

-- Declare a global function to set the menu subtitle colour
function HPRPCMenu.SetMenuSubTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'subTitleColor', { r, g, b, a })
end

-- Declare a global function to set the title background colour
function HPRPCMenu.SetTitleBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'titleBackgroundColor', { r, g, b, a })
end

-- Declare an alternative object name for SetTitleBackgroundColor
HPRPCMenu.SetMenuTitleBackgroundColor = HPRPCMenu.SetTitleBackgroundColor

-- Declare a global function to set the title background sprite (background image)
function HPRPCMenu.SetTitleBackgroundSprite(id, dict, name)
	RequestStreamedTextureDict(dict)
	setStyleProperty(id, 'titleBackgroundSprite', { dict = dict, name = name })
end

-- Declare an alternative object name for SetTitleBackgroundSprite
HPRPCMenu.SetMenuTitleBackgroundSprite = HPRPCMenu.SetTitleBackgroundSprite

-- Declare a global function to set the menu background colour
function HPRPCMenu.SetMenuBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'backgroundColor', { r, g, b, a })
end

-- Declare a global function to set the menu text colour
function HPRPCMenu.SetMenuTextColor(id, r, g, b, a)
	setStyleProperty(id, 'textColor', { r, g, b, a })
end

-- Declare a global function to set the menu subtext colour
function HPRPCMenu.SetMenuSubTextColor(id, r, g, b, a)
	setStyleProperty(id, 'subTextColor', { r, g, b, a })
end

-- Declare a global function to set the menu focus colour
function HPRPCMenu.SetMenuFocusColor(id, r, g, b, a)
	setStyleProperty(id, 'focusColor', { r, g, b, a })
end

-- Declare a global function to set the menu focus text colour
function HPRPCMenu.SetMenuFocusTextColor(id, r, g, b, a)
	setStyleProperty(id, 'focusTextColor', { r, g, b, a })
end

-- Declare a global function to set the menu pressed button (uses native soundsets)
function HPRPCMenu.SetMenuButtonPressedSound(id, name, set)
	setStyleProperty(id, 'buttonPressedSound', { name = name, set = set })
end