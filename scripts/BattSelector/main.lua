-- Lua Battery Selector and Alarm widget
-- BattSelect + ETHOS LUA configuration

-- Known Issues:
-- 1. If you change models to another model with BattSelector, the Remaining Sensor will not function.
-- 2. If you change models to another model with BattSelector, the matchingBatteries list (and therefore widget choiceField) will not update. 

-- Restarting the radio makes 1 and 2 work again, but I'd like to figure out *why* it happens and fix it properly at some point.

-- Set to true to enable debug output for each function as needed
local useDebug = {
    fillFavoritesPanel = false,
    fillImagePanel = false,
    fillBatteryPanel = false,
    fillPrefsPanel = false,
    doBatteryVoltageCheck = false,
    updateRemainingSensor = false,
    getmAh = false,
    create = false,
    build = false,
    paint = false,
    wakeup = false,
    configure = false
}

-- Get Radio Version to determine field size
local radio = system.getVersion()

-- Favorites Panel in Configure
local function fillFavoritesPanel(widget)
    widget.favoritesPanel:clear()
    -- Create list of Unique IDs from on all Batteries' IDs
    widget.uniqueIDs = {}
    local seen = {}
    for i = 1, #widget.Batteries do
        local id = widget.Batteries[i].modelID
        if not seen[id] then
            seen[id] = true
            table.insert(widget.uniqueIDs, id)
        end
    end

    -- List out available unique Model IDs in the Favorites panel
    for i, id in ipairs(widget.uniqueIDs) do
        local line = widget.favoritesPanel:addLine("ID " .. id .. " Favorite")

        -- Create Favorite picker field
        local matchingNames = {}
        for j = 1, widget.numBatts do
            if widget.Batteries[j].modelID == id then
                matchingNames[#matchingNames + 1] = {widget.Batteries[j].name, j}
            end
        end
        local field = form.addChoiceField(line, nil, matchingNames, function()
            for j = 1, #widget.Batteries do
                if widget.Batteries[j].modelID == id and widget.Batteries[j].favorite then
                    return j
                end
            end
            return nil
        end, function(value)
            for j = 1, #widget.Batteries do
                if widget.Batteries[j].modelID == id then
                    widget.Batteries[j].favorite = (j == value)
                end
            end
        end)
    end
end


local function fillImagePanel(widget)
    local debug = useDebug.fillImagePanel

    widget.imagePanel:clear()

    local line = widget.imagePanel:addLine("Default Image")
    local field = form.addFileField(line, nil, "/bitmaps/models", "image+ext", function() return widget.Images.Default or "" end, function(newValue) widget.Images.Default = newValue end)

    if debug then print("Debug(fillImagePanel):" .. "Default Image: " .. widget.Images.Default) end

    -- List out available Model IDs in the Favorites panel
    for i, id in ipairs(widget.uniqueIDs) do
        local line = widget.imagePanel:addLine("ID " .. widget.uniqueIDs[i] .. " Image")
        local id = widget.uniqueIDs[i]

        local field = form.addFileField(line, nil, "/bitmaps/models", "image+ext", function()
            return widget.Images[id] or ""
        end, function(newValue)
            widget.Images[id] = newValue
        end)
        if debug then print("Debug(fillImagePanel): Image for ID " .. id .. ": " .. widget.Images[id]) end
    end
end


local function fillBatteryPanel(widget)
    local debug = useDebug.fillBatteryPanel
    if debug then print("Debug(fillBatteryPanel): Filling Battery Panel") end

    widget.batteryPanel:clear()

    local pos_header_battery
    local pos_header_capacity
    local pos_header_id
    local pos_value_name
    local pos_value_capacity
    local pos_value_id
    local pos_options_button
    local pos_add_button

    if string.find(radio.board, "X20") or radio.board == "X18R" or radio.board == "X18RS" then
        -- Header text positions
        pos_header_battery = {x = 10, y = 8, w = 200, h = 40}
        pos_header_capacity = {x = 530, y = 8, w = 100, h = 40}
        pos_header_id = {x = 655, y = 8, w = 100, h = 40}
        -- Value positions
        pos_value_name = {x = 8, y = 8, w = 400, h = 40}
        pos_value_capacity = {x = 504, y = 8, w = 130, h = 40}
        pos_value_id = {x = 642, y = 8, w = 50, h = 40}
        pos_options_button = {x = 700, y = 8, w = 50, h = 40}
        pos_add_button = {x = 642, y = 8, w = 108, h = 40}
    elseif radio.board == "X18" or radio.board == "X18S" or radio.board == "TWXLITE" or radio.board == "TWXLITES" then
        -- Header text positions
        pos_header_battery = {x = 6, y = 6, w = 200, h = 30}
        pos_header_capacity = {x = 300, y = 6, w = 100, h = 30}
        pos_header_id = {x = 390, y = 6, w = 100, h = 30}
        -- Value positions
        pos_value_name = {x = 6, y = 6, w = 275, h = 30}
        pos_value_capacity = {x = 288, y = 6, w = 85, h = 30}
        pos_value_id = {x = 379, y = 6, w = 35, h = 30}
        pos_options_button = {x = 420, y = 6, w = 35, h = 30}
        pos_add_button = {x = 375, y = 6, w = 80, h = 30}
    else
        -- Currently not tested on other radios (X10,X12,X14)
    end

    -- Create header for the battery panel
    local line = widget.batteryPanel:addLine("")
    local field = form.addStaticText(line, pos_header_battery, "Name")
    local field = form.addStaticText(line, pos_header_capacity, "Capacity")
    local field = form.addStaticText(line, pos_header_id, "ID")

    for i = 1, widget.numBatts do
        local line = widget.batteryPanel:addLine("")
        local field = form.addTextField(line, pos_value_name, function() return widget.Batteries[i].name end, function(newName)
            widget.Batteries[i].name = newName
            widget.rebuildWidget = true
        end)

        local field = form.addNumberField(line, pos_value_capacity, 0, 20000, function() return widget.Batteries[i].capacity end, function(value)
            widget.Batteries[i].capacity = value
            widget.rebuildWidget = true
        end)
        field:suffix("mAh")
        field:step(100)
        field:default(0)
        field:enableInstantChange(false)
        local field = form.addNumberField(line, pos_value_id, 0, 99, function() return widget.Batteries[i].modelID end, function(value)
            widget.Batteries[i].modelID = value
            fillFavoritesPanel(widget)
            fillImagePanel(widget)
            widget.rebuildWidget = true
        end)
        field:default(0)
        field:enableInstantChange(false)
        local field = form.addTextButton(line, pos_options_button, "...", function()
            local buttons = {
                {label = "Cancel", action = function() return true end},
                {label = "Delete", action = function()
                    table.remove(widget.Batteries, i)
                    widget.numBatts = widget.numBatts - 1
                    fillBatteryPanel(widget)
                    fillFavoritesPanel(widget)
                    widget.rebuildWidget = true
                    return true
                end},
                {label = "Clone", action = function()
                    local newBattery = {name = widget.Batteries[i].name, capacity = widget.Batteries[i].capacity, modelID = widget.Batteries[i].modelID, favorite = false}
                    table.insert(widget.Batteries, newBattery)
                    widget.numBatts = widget.numBatts + 1
                    fillFavoritesPanel(widget)
                    fillImagePanel(widget)
                    widget.rebuildWidget = true
                    return true
                end}
            }
            form.openDialog({
                title = (widget.Batteries[i].name ~= "" and widget.Batteries[i].name or "Unnamed Battery"),
                message = "Select Action",
                width = 350,
                buttons = buttons,
                options = TEXT_LEFT,
            })
        end)
    end

    local line = widget.batteryPanel:addLine("")
    local field = form.addTextButton(line, pos_add_button, "Add New", function()
        widget.numBatts = widget.numBatts + 1
        widget.Batteries[widget.numBatts] = {name = "Battery " .. widget.numBatts, capacity = 0, modelID = 0}
        fillBatteryPanel(widget)
        fillFavoritesPanel(widget)
        fillImagePanel(widget)
        widget.rebuildWidget = true
    end)
end

local hapticPatterns = {{". . . . . .", 1}, {". - . - . - .", 2}, {". - - . - - . - - . - - .", 3}}

-- Settings Panel
local function fillPrefsPanel(widget)
    local debug = useDebug.fillPrefsPanel
    if debug then print("Debug(fillPrefsPanel): Filling Preferences Panel") end

    widget.prefsPanel:clear()

    local line = widget.prefsPanel:addLine("Use Capacity")
    local field = form.addNumberField(line, nil, 50, 100, function() return widget.useCapacity or 80 end, function(value) widget.useCapacity = value end)
    field:suffix("%")
    field:default(80)

    -- Create field to enable/disable battery voltage checking on connect
    local line = widget.prefsPanel:addLine("Enable Voltage Check")
    local field = form.addBooleanField(line, nil, function() return widget.checkBatteryVoltageOnConnect end, function(newValue) widget.checkBatteryVoltageOnConnect = newValue widget.rebuildPrefs = true end)
    if widget.checkBatteryVoltageOnConnect then
        local line = widget.prefsPanel:addLine("Min Charged Volt/Cell")
        local field = form.addNumberField(line, nil, 400, 430, function() return widget.minChargedCellVoltage or 415 end, function(value) widget.minChargedCellVoltage = value end)
        field:decimals(2)
        field:suffix("V")
        field:enableInstantChange(false)
        local line = widget.prefsPanel:addLine("Haptic Warning")
        local field = form.addBooleanField(line, nil, function() return widget.doHaptic end, function(newValue) widget.doHaptic = newValue widget.rebuildPrefs = true end)
        if widget.doHaptic then 
            if widget.hapticPattern == nil then widget.hapticPattern = 1 end
            local line = widget.prefsPanel:addLine("Haptic Pattern")
            local field = form.addChoiceField(line, nil, hapticPatterns, function() return widget.hapticPattern end, function(newValue) widget.hapticPattern = newValue end)
        end
    end

    if useDebug.fillPrefsPanel then
        print("fillingPrefsPanel")
    end
end

-- Alerts Panel, commented out for now as not in use
-- local function fillAlertsPanel(alertsPanel, widget)
--     local line = alertsPanel:addLine("Eventually")
-- end

-- Estimate cellcount and check if battery is charged.  If not, popup dialog to alert user
local function doBatteryVoltageCheck(widget)
    local debug = useDebug.doBatteryVoltageCheck
    if debug then print("Debug(doBatteryVoltageCheck): Running Battery Voltage Check") end

    local cellCount
    local currentVoltage
    local isCharged

    if not widget.batteryConnectTime then
        widget.batteryConnectTime = os.clock()
    end

    if widget.batteryConnectTime and (os.clock() - widget.batteryConnectTime) <= 30 then
        -- Check if cell count sensor exists (RF 2.2? only), if not, get it
        if not widget.cellSensor then
            widget.cellSensor = system.getSource({category = CATEGORY_TELEMETRY, name = "Cell Count"})
            if widget.cellSensor then
                if debug then print("Debug(doBatteryVoltageCheck): RF Cell Count sensor found.  Continuing") end
            else
                if debug then print("Debug(doBatteryVoltageCheck): RF Cell Count sensor not found.  Proceeding with estimation from Voltage") end
            end
        end

        -- Check if voltage sensor exists, if not, get it
        if not widget.voltageSensor then
            widget.voltageSensor = system.getSource({category = CATEGORY_TELEMETRY, name = "Voltage"})
            if widget.voltageSensor then 
                if debug then print("Debug(doBatteryVoltageCheck): Voltage Sensor Found.  Continuing") end
            else
                if debug then print ("Debug(doBatteryVoltageCheck): Voltage sensor not found.  Exiting") end
                return
            end
        end
        
        if widget.cellSensor and widget.voltageSensor then
            currentVoltage = widget.voltageSensor:value()
            cellCount = math.floor(widget.cellSensor:value())
            isCharged = currentVoltage >= cellCount * widget.minChargedCellVoltage 
            widget.doneVoltageCheck = true
        elseif widget.voltageSensor then
            currentVoltage = widget.voltageSensor:value()
            -- Estimate cell count based on voltage
            cellCount = math.floor(currentVoltage / widget.minChargedCellVoltage + 0.5)
            -- To prevent accidentally reading a very low battery as a lower cell count than actual, add 1 to cellCount if the voltage is higher than cellCount * 4.35 (HV battery max cell voltage)
            if currentVoltage >= cellCount * 4.35 then
                cellCount = cellCount + 1
            end    
        end

        if cellCount == 0  then
            cellCount = 1
        end

        if cellCount and currentVoltage then 
            isCharged = currentVoltage >= cellCount * widget.minChargedCellVoltage 
            if debug then 
                print("Debug(doBatteryVoltageCheck): Voltage Sensor Found.  Reading: " .. currentVoltage .. "V")
                print("Debug(doBatteryVoltageCheck): Cell Count: " .. cellCount)
                print("Debug(doBatteryVoltageCheck): Battery Charged: " .. tostring(isCharged)) 
            end

            if isCharged == false and widget.voltageDialogDismissed == false then
                if debug then print ("Debug(doBatteryVoltageCheck): Battery not charged!  Popup dialog") end
                local buttons = {
                    {label = "OK", action = function()
                        widget.voltageDialogDismissed = true 
                        if debug then print("Debug(doBatteryVoltageCheck): Voltage Dialog Dismissed") end
                        return true 
                    end}}
                if widget.doHaptic then
                    if debug then print("Debug(doBatteryVoltageCheck): Playing Haptic") end
                    system.playHaptic(hapticPatterns[widget.hapticPattern][1])
                end
                form.openDialog({
                    title = "Low Battery Voltage",
                    message = "Battery may not be charged!",
                    width = 350,
                    buttons = buttons,
                    options = TEXT_LEFT,
                })
            end
            widget.doneVoltageCheck = true 
        end
    end
end

local function updateRemainingSensor(widget)
    if widget.percentSensor == nil then
        widget.percentSensor = system.getSource({category = CATEGORY_TELEMETRY, appId = 0x4402, physId = 0x11, name = "Remaining"})
        if widget.percentSensor == nil then
            widget.percentSensor = model.createSensor()
            widget.percentSensor:name("Remaining")
            widget.percentSensor:unit(UNIT_PERCENT)
            widget.percentSensor:decimals(0)
            widget.percentSensor:appId(0x4402)
            widget.percentSensor:physId(0x11)
        end
    end 
    if widget.percentSensor ~= nil then
        widget.percentSensor:value(widget.newPercent)
    end
end

local function getmAh(widget)
    if widget.mAhSensor == nil then
        for member = 0, 50 do
            local candidate = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, member = member})
            if candidate then
                if candidate:unit() == UNIT_MILLIAMPERE_HOUR then
                    widget.mAhSensor = candidate
                    break -- Exit the loop once a valid mAh sensor is found
                end
            end
        end

        if widget.mAhSensor == nil then
            print("No mAh sensor found!")
            return 0
        end
    end
    
    -- Return the value or 0 if no valid sensor was found
    if widget.mAhSensor and widget.mAhSensor:value() ~= nil then
        if useDebug.getmAh then
            print("Debug(getmAh): mAh Reading: " .. math.floor(widget.mAhSensor:value()) .. "mAh")
        end
        return math.floor(widget.mAhSensor:value())
    else
        return 0
    end
end

-- This function is called when the widget is first created
local function create()
    local widget = {
        batteries = nil,
        useCapacity = nil,
        percentSensor = nil,
        mahSensor = nil,
        modelIDSensor = nil,
        cellSensor = nil,
        voltageSensor = nil,
        newPercent = 100,
        lastmAh = 0,
        lastModelID = nil,
        currentModelID = nil,
        lastTime = os.clock(),
        lastBattCheckTime = os.clock(),
        selectedBattery = nil,
        matchingBatteries = nil,
        tlmActive = false,
        resetDone = false,
        voltageDialogDismissed = false,
        doneVoltageCheck = false,
        batteryConnectTime = nil,


        widgetInit = true, -- Tracks whether the widget needs to be initalized.
        fieldHeight = nil,
        fieldWidth = nil,
        
        numBatts = 0,
        Batteries = nil,
        uniqueIDs = {},
        Images = {},
        
        favoritesPanel = nil,
        imagePanel = nil,
        batteryPanel = nil,
        prefsPanel = nil,
        
        rebuildWidget = false,
        rebuildPrefs = false,

        checkBatteryVoltageOnConnect = nil,
        minChargedCellVoltage = nil,
        doHaptic = nil,
        hapticPattern = nil,
    }
    return widget
end

local function build(widget)
    local debug = useDebug.build

    local w, h = lcd.getWindowSize()

    -- Refresh the matchingBatteries list based on currentModelID
    widget.matchingBatteries = {}
    if #widget.Batteries > 0 then
        if widget.currentModelID then
            if debug then print ("Debug(build): Current Model ID: " .. widget.currentModelID) end
            for i = 1, #widget.Batteries do
                if widget.Batteries[i].modelID == widget.currentModelID then
                    widget.matchingBatteries[#widget.matchingBatteries + 1] = {widget.Batteries[i].name, i}
                end
            end
            for i = 1, #widget.Batteries do
                if widget.Batteries[i].modelID == widget.currentModelID and widget.Batteries[i].favorite then
                    widget.selectedBattery = i
                    break
                end
            end
        else
            for i = 1, #widget.Batteries do
                widget.matchingBatteries[#widget.matchingBatteries + 1] = {widget.Batteries[i].name, i}
            end
            if #widget.matchingBatteries > 0 then
                widget.selectedBattery = widget.matchingBatteries[1][2]
            end
        end
    end

    if not widget.selectedBattery then
        widget.selectedBattery = 1
    end

    if debug then
        local batteryNames = {}
        for i, battery in ipairs(widget.matchingBatteries) do
            table.insert(batteryNames, battery[1])
        end
        if batteryNames then print("Debug(build): Matching Batteries: " .. table.concat(batteryNames, ", ")) end
        if widget.Batteries[widget.selectedBattery] then 
            local batteryInfo = "Debug(build): Selected Battery: " .. widget.Batteries[widget.selectedBattery].name
            if widget.Batteries[widget.selectedBattery].favorite then
            batteryInfo = batteryInfo .. " (Favorite)"
            end
            print(batteryInfo)
        end
    end

    -- Initialize widget based on radio type
    if widget.widgetInit then
        if debug then print("Debug(build): Widget Init") end
        -- Set form size based on radio type
        if string.find(radio.board, "X20") or radio.board == "X18R" or radio.board == "X18RS" then
            widget.fieldHeight = 40
            widget.fieldWidth = 145
        elseif radio.board == "X18" or radio.board == "X18S" or radio.board == "TWXLITE" or radio.board == "TWXLITES" then
            widget.fieldHeight = 30
            widget.fieldWidth = 100
        else
            -- Currently not tested on other radios (X10,X12,X14)
        end
        if debug then print("Debug(build): Creating form") end
        form.create()
        widget.widgetInit = false
    end
    
    if widget.fieldHeight and widget.fieldWidth and widget.matchingBatteries then
        form.clear()
        if debug then print("Debug(build): Updating Choice Field") end
        local pos_x = (w / 2 - widget.fieldWidth / 2)
        local pos_y = (h / 2 - widget.fieldHeight / 2)

        -- Create form and add choice field for selecting battery
        local choiceField = form.addChoiceField(line, {x = pos_x, y = pos_y, w = widget.fieldWidth, h = widget.fieldHeight}, widget.matchingBatteries, function() return widget.selectedBattery end, function(value) 
            widget.selectedBattery = value 
        end)
    end
end

local function wakeup(widget)
    local debug = useDebug.wakeup

    -- Get the current uptime
    local currentTime = os.clock()

    if widget.checkBatteryVoltageOnConnect and widget.tlmActive then
        -- Only run the battery voltage check 3 seconds after telemetry becomes active to prevent reading voltage before Voltage telemetry is established and valid (nonzero)
        if currentTime - widget.lastBattCheckTime >= 3 then
            widget.lastBattCheckTime = currentTime
            -- If telemetry is active and voltage check is enabled, run check if it hasn't been done and dismissed yet
            if not widget.doneVoltageCheck and not widget.voltageDialogDismissed then
                if debug then print ("Debug(wakeup): Running Battery Voltage Check") end
                doBatteryVoltageCheck(widget)
            end
        end
    else
        widget.voltageDialogDismissed = false -- Reset the dialog dismissed flag when telemetry becomes inactive
        widget.lastBattCheckTime = currentTime -- Reset the timer when telemetry becomes inactive
    end

    if currentTime - widget.lastTime >= 1 then
        widget.tlmActive = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE, options = nil}):state()
        -- Reset all doBatteryVoltageCheck parameters when telemetry becomes inactive so that it can run again on next battery connect
        if not widget.tlmActive and not widget.resetDone then
            widget.voltageDialogDismissed = false
            widget.doneVoltageCheck = false
            widget.batteryConnectTime = nil
            widget.resetDone = true
        elseif widget.tlmActive then
            widget.resetDone = false
        end

        -- if Batteries exist, telemetry is active, a battery is selected, and the mAh reading is not nil, do the maths
        local newmAh = getmAh(widget)
        if #widget.Batteries > 0 and widget.tlmActive and widget.selectedBattery and newmAh ~= nil and widget.useCapacity ~= nil then
            if newmAh ~= widget.lastmAh then
                local usablemAh = widget.Batteries[widget.selectedBattery].capacity * (widget.useCapacity / 100)
                widget.newPercent = 100 - (newmAh / usablemAh) * 100
                if widget.newPercent < 0 then widget.newPercent = 0 end
                widget.lastmAh = newmAh
            end
        end

        if debug then print ("Debug(wakeup): Updating Remaining Sensor") end
        updateRemainingSensor(widget) -- Update the remaining sensor
        
        -- Check for modelID sensor presence and its value
        if widget.modelIDSensor == nil then 
            widget.modelIDSensor = system.getSource({category = CATEGORY_TELEMETRY, name = "Model ID"})
            if widget.modelIDSensor ~= nil and widget.modelIDSensor:value() ~= nil then
                widget.currentModelID = math.floor(widget.modelIDSensor:value())
            end
        else
            if widget.modelIDSensor:value() ~= nil then
                widget.currentModelID = math.floor(widget.modelIDSensor:value())
            end
        end
            
        local currentBitmapName = model.bitmap():match("([^/]+)$")

        -- Set the model image based on the currentModelID.  If not present or invalid, set it to the default image
        if widget.tlmActive and widget.currentModelID and widget.Images[widget.currentModelID] then
            if currentBitmapName ~= widget.Images[widget.currentModelID] then
                model.bitmap(widget.Images[widget.currentModelID])
                if debug then print("Debug(wakeup: Setting model image to " .. (widget.Images[widget.currentModelID])) end
            end
        elseif widget.Images.Default ~= "" then
            if currentBitmapName ~= widget.Images.Default  then
                model.bitmap(widget.Images.Default)
                if debug then print("Debug(wakeup): Setting model image to Default: " .. widget.Images.Default) end
            end
        end
        widget.lastTime = currentTime
    end

    -- Check if the modelID has changed since last wakeup, and if so, set the rebuildMatching flag to true
    if widget.currentModelID ~= widget.lastModelID then
        if debug then print("Debug(wakeup): Model ID has changed") end
        widget.lastModelID = widget.currentModelID 
        widget.rebuildWidget = true
    end

    if widget.rebuildWidget then
        if debug then print ("Debug(wakeup): Rebuilding widget") end
        build(widget)
        widget.rebuildWidget = false
    end

    if widget.rebuildPrefs then
        if debug then print ("Debug(wakeup): Rebuilding Preferences Panel") end
        fillPrefsPanel(widget.prefsPanel, widget)
        widget.rebuildPrefs = false
    end
end


-- This function is called when the user first selects the widget from the widget list, or when they select "configure widget"
local function configure(widget)
    local debug = useDebug.configure
    -- Fill Batteries panel
    if debug then print("Debug(configure): Filling Battery Panel") end
    widget.batteryPanel = form.addExpansionPanel("Batteries")
    widget.batteryPanel:open(false)
    fillBatteryPanel(widget)

    -- Fill Favorites panel
    if debug then print("Debug(configure): Filling Favorites Panel") end
    widget.favoritesPanel = form.addExpansionPanel("Favorites")
    widget.favoritesPanel:open(false)
    fillFavoritesPanel(widget)

    -- Fill Images panel
    if debug then print("Debug(configure): Filling Images Panel") end
    widget.imagePanel = form.addExpansionPanel("Images")
    widget.imagePanel:open(false)
    fillImagePanel(widget)

    -- Preferences Panel
    if debug then print("Debug(configure): Filling Preferences Panel") end
    widget.prefsPanel = form.addExpansionPanel("Preferences")
    widget.prefsPanel:open(false)
    fillPrefsPanel(widget)

    -- Alerts Panel.  Commented out for now as not in use
    -- local alertsPanel
    -- alertsPanel = form.addExpansionPanel("Alerts")
    -- alertsPanel:open(false)
    -- fillAlertsPanel(alertsPanel, widget)
end

local function read(widget) -- Read configuration from storage
    widget.numBatts = storage.read("numBatts") or 0
    widget.useCapacity = storage.read("useCapacity") or 80
    widget.Batteries = {}
    if widget.numBatts > 0 then
        for i = 1, widget.numBatts do
            local name = storage.read("Battery" .. i .. "_name") or "Battery " .. i
            local capacity = storage.read("Battery" .. i .. "_capacity") or 0
            local modelID = storage.read("Battery" .. i .. "_modelID") or 0
            local favorite = storage.read("Battery" .. i .. "_favorite") or false
            widget.Batteries[i] = {
                name = name,
                capacity = capacity,
                modelID = modelID,
                favorite = favorite
            }
        end
    end
    local uniqueIDs = {}
    local seen = {}
    for i = 1, widget.numBatts do
        local id = widget.Batteries[i].modelID
        if not seen[id] then
            seen[id] = true
            table.insert(uniqueIDs, id)
        end
    end

    widget.checkBatteryVoltageOnConnect = storage.read("checkBatteryVoltageOnConnect") or false
    if widget.checkBatteryVoltageOnConnect then
        widget.minChargedCellVoltage = storage.read("minChargedCellVoltage") or 415
        widget.doHaptic = storage.read("doHaptic") or false
        widget.hapticPattern = storage.read("hapticPattern") or 1
    end
    
    widget.Images = { Default = storage.read("ImagesDefault") or "" }
    for i = 1, #uniqueIDs do
        local id = uniqueIDs[i]
        Images[id] = storage.read("Images" .. id)
    end
end


local function write(widget) -- Write configuration to storage
    storage.write("numBatts", widget.numBatts)
    storage.write("useCapacity", widget.useCapacity)
    if widget.numBatts > 0 then
        for i = 1, widget.numBatts do
            storage.write("Battery" .. i .. "_name", widget.Batteries[i].name)
            storage.write("Battery" .. i .. "_capacity", widget.Batteries[i].capacity)
            storage.write("Battery" .. i .. "_modelID", widget.Batteries[i].modelID)
            storage.write("Battery" .. i .. "_favorite", widget.Batteries[i].favorite)
        end
    end
    storage.write("checkBatteryVoltageOnConnect", widget.checkBatteryVoltageOnConnect)
    if widget.checkBatteryVoltageOnConnect then
        storage.write("minChargedCellVoltage", widget.minChargedCellVoltage)
        storage.write("doHaptic", widget.doHaptic)
        if widget.doHaptic then storage.write("hapticPattern", widget.hapticPattern) end
    end
    
    storage.write("ImagesDefault", widget.Images.Default)
    for id, image in pairs(widget.Images) do
        if id ~= "Default" then
            storage.write("Images" .. id, image)
        end
    end
end


local function paint(widget) end

local function event(widget, category, value, x, y) end

local function init()
    system.registerWidget({
        key = "battsel",
        name = "Battery Select",
        create = create,
        build = build,
        paint = paint,
        event = event,
        wakeup = wakeup,
        configure = configure,
        read = read,
        write = write,
    })
end


return {init = init}
