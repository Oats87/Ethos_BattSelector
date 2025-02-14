-- Lua Battery Selector and Alarm widget
-- BattSelect + ETHOS LUA configuration
-- Set to true to enable debug output for each function as needed
local useDebug = {
    fillFavoritesPanel = true,
    fillImagePanel = true,
    fillBatteryPanel = true,
    fillPrefsPanel = true,
    doBatteryVoltageCheck = true,
    updateRemainingSensor = false,
    getmAh = true,
    create = true,
    build = true,
    paint = true,
    wakeup = true,
    configure = true
}

local hapticPatterns = {{". . . . . .", 1}, {". - . - . - .", 2}, {". - - . - - . - - . - - .", 3}}

-- Get Radio Version to determine field size
local radio = system.getVersion()

-- This function is called when the widget is first created
local function create()
    local widget = {
        useCapacity = nil,
        selectedModelBattery = nil,
        doHaptic = nil,
        hapticPattern = nil,

        numBatts = 0,
        Batteries = {},
        Images = {},

        lastmAh = 0,

        modelIds = {},
        lastModelID = nil,
        currentModelID = nil,

        lastTime = os.clock(),

        tlmActive = false,

        voltageCheckEnabled = false,
        voltageCheckCompleted = false,
        voltageCheckMinChargedCellVoltage = nil,
        voltageCheckLastCheckTime = nil,
        voltageCheckBatteryConnectTime = nil,

        widgetRebuildRequired = false,

        rebuildPrefs = false,

        widgetInitialized = false, -- Tracks whether the widget has been initalized.
        fieldHeight = nil,
        fieldWidth = nil,

        favoritesPanel = nil,
        imagePanel = nil,
        batteryPanel = nil,
        prefsPanel = nil,

        percentSensor = nil,
        mahSensor = nil,
        modelIDSensor = nil,
        cellSensor = nil,
        voltageSensor = nil
    }
    return widget
end

local function populateModelIds(widget)
    widget.modelIds = {}
    local seen = {}
    for i, battery in ipairs(widget.Batteries) do
        if not seen[battery.modelID] then
            seen[battery.modelID] = true
            table.insert(widget.modelIds, battery.modelID)
        end
    end
end

-- Favorites Panel in Configure
local function fillFavoritesPanel(widget)
    if not widget.favoritesPanel then
        return
    else 
        widget.favoritesPanel:clear()
    end

    populateModelIds(widget)
    -- List out available Model IDs in the Favorites panel
    for _, modelId in ipairs(widget.modelIds) do
        local line = widget.favoritesPanel:addLine("ID " .. modelId .. " Favorite")

        -- Create Favorite picker field
        local matchingNames = {}
        for i, battery in ipairs(widget.Batteries) do
            if battery.modelID == modelId then
                matchingNames[#matchingNames + 1] = {battery.name, i}
            end
        end
        local field = form.addChoiceField(line, nil, matchingNames, function()
            for j, battery in ipairs(widget.Batteries) do
                if battery.modelID == modelId and battery.favorite then
                    return j
                end
            end
            return nil
        end, function(value)
            for j, battery in ipairs(widget.Batteries) do
                if battery.modelID == modelId then
                    battery.favorite = (j == value)
                end
            end
        end)
    end
end

local function fillImagePanel(widget)
    local debug = useDebug.fillImagePanel

    if not widget.imagePanel then
        return
    else
        widget.imagePanel:clear()
    end

    local line = widget.imagePanel:addLine("Default Image")
    local field = form.addFileField(line, nil, "/bitmaps/models", "image+ext", function()
        return widget.Images.Default or ""
    end, function(newValue)
        widget.Images.Default = newValue
    end)

    if debug and widget.Images.Default then
        print("Debug(fillImagePanel):" .. "Default Image: " .. widget.Images.Default)
    end

    print("hello")
    -- List out available Model IDs in the Favorites panel
    for i, modelId in ipairs(widget.modelIds) do
        print("hello 2")
        local line = widget.imagePanel:addLine("ID " .. modelId .. " Image")

        local field = form.addFileField(line, nil, "/bitmaps/models", "image+ext", function()
            return widget.Images[modelId] or ""
        end, function(newValue)
            widget.Images[modelId] = newValue
        end)
        if debug and modelId and widget.Images[modelId] then
            print("Debug(fillImagePanel): Image for Model ID " .. modelId .. ": " .. widget.Images[modelId])
        end
    end
    print("Finished filling image")
end

local function requestWidgetRebuild(widget)
    widget.widgetRebuildRequired = true
end

local function resetBatteryVoltageCheck(widget, completed)
    widget.voltageCheckCompleted = completed

    widget.voltageCheckLastCheckTime = nil
    widget.voltageCheckBatteryConnectTime = nil
end

local function resetWidget(widget)
    widget.selectedModelBattery = nil
    widget.lastmAh = 0
    widget.lastModelID = nil
    widget.currentModelID = nil

    resetBatteryVoltageCheck(widget, false)
    requestWidgetRebuild(widget)
end

local function fillBatteryPanel(widget)
    local debug = useDebug.fillBatteryPanel
    if debug then
        print("Debug(fillBatteryPanel): Begin filling battery panel")
    end

    if not widget.batteryPanel then
       return
    else
        widget.batteryPanel:clear() 
    end

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
        pos_header_battery = {
            x = 10,
            y = 8,
            w = 200,
            h = 40
        }
        pos_header_capacity = {
            x = 530,
            y = 8,
            w = 100,
            h = 40
        }
        pos_header_id = {
            x = 655,
            y = 8,
            w = 100,
            h = 40
        }
        -- Value positions
        pos_value_name = {
            x = 8,
            y = 8,
            w = 400,
            h = 40
        }
        pos_value_capacity = {
            x = 504,
            y = 8,
            w = 130,
            h = 40
        }
        pos_value_id = {
            x = 642,
            y = 8,
            w = 50,
            h = 40
        }
        pos_options_button = {
            x = 700,
            y = 8,
            w = 50,
            h = 40
        }
        pos_add_button = {
            x = 642,
            y = 8,
            w = 108,
            h = 40
        }
    elseif radio.board == "X18" or radio.board == "X18S" or radio.board == "TWXLITE" or radio.board == "TWXLITES" then
        -- Header text positions
        pos_header_battery = {
            x = 6,
            y = 6,
            w = 200,
            h = 30
        }
        pos_header_capacity = {
            x = 300,
            y = 6,
            w = 100,
            h = 30
        }
        pos_header_id = {
            x = 390,
            y = 6,
            w = 100,
            h = 30
        }
        -- Value positions
        pos_value_name = {
            x = 6,
            y = 6,
            w = 275,
            h = 30
        }
        pos_value_capacity = {
            x = 288,
            y = 6,
            w = 85,
            h = 30
        }
        pos_value_id = {
            x = 379,
            y = 6,
            w = 35,
            h = 30
        }
        pos_options_button = {
            x = 420,
            y = 6,
            w = 35,
            h = 30
        }
        pos_add_button = {
            x = 375,
            y = 6,
            w = 80,
            h = 30
        }
    else
        -- Currently not tested on other radios (X10,X12,X14)
    end

    -- Create header for the battery panel
    local line = widget.batteryPanel:addLine("")
    local field = form.addStaticText(line, pos_header_battery, "Name")
    local field = form.addStaticText(line, pos_header_capacity, "Capacity")
    local field = form.addStaticText(line, pos_header_id, "ID")

    -- for i = 1, widget.numBatts do
    for i, battery in ipairs(widget.Batteries) do
        local line = widget.batteryPanel:addLine("")

        local field = form.addTextField(line, pos_value_name, function()
            return battery.name
        end, function(newName)
            battery.name = newName
            requestWidgetRebuild(widget)
        end)

        local field = form.addNumberField(line, pos_value_capacity, 0, 20000, function()
            return battery.capacity
        end, function(value)
            battery.capacity = value
            requestWidgetRebuild(widget)
        end)
        field:suffix("mAh")
        field:step(100)
        field:default(0)
        field:enableInstantChange(false)

        local field = form.addNumberField(line, pos_value_id, 0, 99, function()
            return battery.modelID
        end, function(value)
            battery.modelID = value
            fillFavoritesPanel(widget)
            fillImagePanel(widget)
            requestWidgetRebuild(widget)
        end)

        field:default(0)
        field:enableInstantChange(false)

        local field = form.addTextButton(line, pos_options_button, "...", function()
            local buttons = {{
                label = "Cancel",
                action = function()
                    return true
                end
            }, {
                label = "Delete",
                action = function()
                    table.remove(widget.Batteries, i)
                    --widget.numBatts = widget.numBatts - 1
                    fillBatteryPanel(widget)
                    fillFavoritesPanel(widget)
                    requestWidgetRebuild(widget)
                    return true
                end
            }, {
                label = "Clone",
                action = function()
                    local newBattery = {
                        name = battery.name,
                        capacity = battery.capacity,
                        modelID = battery.modelID,
                        favorite = false
                    }
                    table.insert(widget.Batteries, newBattery)
                    --widget.numBatts = widget.numBatts + 1
                    fillFavoritesPanel(widget)
                    fillImagePanel(widget)
                    requestWidgetRebuild(widget)
                    return true
                end
            }}
            form.openDialog({
                title = (battery.name ~= "" and battery.name or "Unnamed Battery"),
                message = "Select Action",
                width = 350,
                buttons = buttons,
                options = TEXT_LEFT
            })
        end)
    end

    local line = widget.batteryPanel:addLine("")
    local field = form.addTextButton(line, pos_add_button, "Add New", function()
        table.insert(widget.Batteries, {
            name = "Battery " .. #widget.Batteries+1,
            capacity = 0,
            modelID = 0,
            favorite = false,
        })
        fillBatteryPanel(widget)
        fillFavoritesPanel(widget)
        fillImagePanel(widget)
        requestWidgetRebuild(widget)
    end)
end

-- Settings Panel
local function fillPrefsPanel(widget)
    local debug = useDebug.fillPrefsPanel
    if debug then
        print("Debug(fillPrefsPanel): Filling Preferences Panel")
    end

    if not widget.prefsPanel then
        return
    else 
        widget.prefsPanel:clear()
    end

    local line = widget.prefsPanel:addLine("Use Capacity")
    local field = form.addNumberField(line, nil, 50, 100, function()
        return widget.useCapacity or 80
    end, function(value)
        widget.useCapacity = value
    end)
    field:suffix("%")
    field:default(80)

    -- Create field to enable/disable battery voltage checking on connect
    local line = widget.prefsPanel:addLine("Enable Voltage Check")
    local field = form.addBooleanField(line, nil, function()
        return widget.checkBatteryVoltageOnConnect
    end, function(newValue)
        widget.checkBatteryVoltageOnConnect = newValue
        widget.rebuildPrefs = true
    end)
    if widget.checkBatteryVoltageOnConnect then
        local line = widget.prefsPanel:addLine("Min Charged Volt/Cell")
        local field = form.addNumberField(line, nil, 400, 430, function()
            return widget.minChargedCellVoltage or 415
        end, function(value)
            widget.minChargedCellVoltage = value
        end)
        field:decimals(2)
        field:suffix("V")
        field:enableInstantChange(false)
        local line = widget.prefsPanel:addLine("Haptic Warning")
        local field = form.addBooleanField(line, nil, function()
            return widget.doHaptic
        end, function(newValue)
            widget.doHaptic = newValue
            widget.rebuildPrefs = true
        end)
        if widget.doHaptic then
            if widget.hapticPattern == nil then
                widget.hapticPattern = 1
            end
            local line = widget.prefsPanel:addLine("Haptic Pattern")
            local field = form.addChoiceField(line, nil, hapticPatterns, function()
                return widget.hapticPattern
            end, function(newValue)
                widget.hapticPattern = newValue
            end)
        end
    end

    if useDebug.fillPrefsPanel then
        print("Debug(fillPrefsPanel): Filled Preferences Panel")
    end
end

-- Alerts Panel, commented out for now as not in use
-- local function fillAlertsPanel(alertsPanel, widget)
--     local line = alertsPanel:addLine("Eventually")
-- end

-- Estimate cellcount and check if battery is charged.  If not, popup dialog to alert user
local function doBatteryVoltageCheck(widget)
    local debug = useDebug.doBatteryVoltageCheck
    if debug then
        print("Debug(doBatteryVoltageCheck): Running Battery Voltage Check")
    end

    if not widget.tlmActive then -- reset the voltage check if telemetry is not active or the voltage check is not enabled
        resetBatteryVoltageCheck(widget, false)
        return
    end

    if widget.voltageCheckComplete or not widget.voltageCheckEnable then
        resetBatteryVoltageCheck(widget, true)
        return
    end

    local now = os.clock()
    widget.voltageCheckLastCheckTime = now

    if not widget.voltageCheckBatteryConnectTime then
        widget.voltageCheckBatteryConnectTime = now
        return -- not ready to check the battery voltage as we want to wait 3 seconds after connecting the battery
    end

    if (now - widget.voltageCheckBatteryConnectTime) < 3 then
        resetBatteryVoltageCheck(widget, true)
        return
    end

    local cellCount
    local currentVoltage
    local isCharged

    if (now - widget.batteryConnectTime) > 30 then
        resetBatteryVoltageCheck(widget, true)
        return
    end

    -- Check if cell count sensor exists (RF 2.2? only), if not, get it
    if not widget.cellSensor then
        widget.cellSensor = system.getSource({
            category = CATEGORY_TELEMETRY,
            name = "Cell Count"
        })
        if widget.cellSensor then
            if debug then
                print("Debug(doBatteryVoltageCheck): RF Cell Count sensor found. Continuing")
            end
        else
            if debug then
                print(
                    "Debug(doBatteryVoltageCheck): RF Cell Count sensor not found. Proceeding with estimation from Voltage")
            end
        end
    end

    -- Check if voltage sensor exists, if not, get it
    if not widget.voltageSensor then
        widget.voltageSensor = system.getSource({
            category = CATEGORY_TELEMETRY,
            name = "Voltage"
        })
        if widget.voltageSensor then
            if debug then
                print("Debug(doBatteryVoltageCheck): Voltage Sensor Found.  Continuing")
            end
        else
            if debug then
                print("Debug(doBatteryVoltageCheck): Voltage sensor not found.  Exiting")
            end
            return
        end
    end

    currentVoltage = widget.voltageSensor:value()

    if not currentVoltage then
        return -- not ready for voltage check, the voltage sensor value was nil
    end

    if widget.cellSensor then
        cellCount = math.floor(widget.cellSensor:value())
        isCharged = currentVoltage >= cellCount * widget.minChargedCellVoltage
    else
        -- Estimate cell count based on voltage
        cellCount = math.floor(currentVoltage / widget.minChargedCellVoltage + 0.5)
        -- To prevent accidentally reading a very low battery as a lower cell count than actual, add 1 to cellCount if the voltage is higher than cellCount * 4.35 (HV battery max cell voltage)
        if currentVoltage >= cellCount * 4.35 then
            cellCount = cellCount + 1
        end

        if cellCount == 0 then
            cellCount = 1
        end

        isCharged = currentVoltage >= cellCount * widget.minChargedCellVoltage
        if debug then
            print("Debug(doBatteryVoltageCheck): Voltage Sensor Found.  Reading: " .. currentVoltage .. "V")
            print("Debug(doBatteryVoltageCheck): Cell Count: " .. cellCount)
            print("Debug(doBatteryVoltageCheck): Battery Charged: " .. tostring(isCharged))
        end
    end

    if not isCharged then
        if debug then
            print("Debug(doBatteryVoltageCheck): Battery not charged!  Popup dialog")
        end
        local buttons = {{
            label = "OK",
            action = function()
                if debug then
                    print("Debug(doBatteryVoltageCheck): Voltage Dialog Dismissed")
                end
                return true
            end
        }}
        if widget.doHaptic then
            if debug then
                print("Debug(doBatteryVoltageCheck): Playing Haptic")
            end
            system.playHaptic(hapticPatterns[widget.hapticPattern][1])
        end
        form.openDialog({
            title = "Low Battery Voltage",
            message = "Battery may not be charged!",
            width = 350,
            buttons = buttons,
            options = TEXT_LEFT
        })
    end

    resetBatteryVoltageCheck(widget, true)
end

local function updateRemainingSensor(widget, newPercent)
    if useDebug.remainingSensorUpdate then
        print("Debug(updateRemainingSensor): Updating Remaining Sensor with new value: " .. newPercent)
    end

    if not widget.percentSensor then
        widget.percentSensor = system.getSource({
            category = CATEGORY_TELEMETRY,
            appId = 0x4402,
            physId = 0x11,
            name = "Remaining"
        })
        if not widget.percentSensor then
            widget.percentSensor = model.createSensor()
            widget.percentSensor:name("Remaining")
            widget.percentSensor:unit(UNIT_PERCENT)
            widget.percentSensor:decimals(0)
            widget.percentSensor:appId(0x4402)
            widget.percentSensor:physId(0x11)
        end
    end

    widget.percentSensor:value(newPercent)
end

local function getmAh(widget)
    if widget.mAhSensor == nil then
        for member = 0, 50 do
            local candidate = system.getSource({
                category = CATEGORY_TELEMETRY_SENSOR,
                member = member
            })
            if candidate then
                if candidate:unit() == UNIT_MILLIAMPERE_HOUR then
                    widget.mAhSensor = candidate
                    break -- Exit the loop once a valid mAh sensor is found
                end
            end
        end

        if not widget.mAhSensor then
            print("No mAh sensor found!")
            return 0
        end
    end

    -- Return the value or 0 if no valid sensor was found
    if widget.mAhSensor and widget.mAhSensor:value() then
        if useDebug.getmAh then
            print("Debug(getmAh): mAh Reading: " .. math.floor(widget.mAhSensor:value()) .. "mAh")
        end
        return math.floor(widget.mAhSensor:value())
    else
        return 0
    end
end

local function build(widget)
    print("Performing Build")
    local debug = useDebug.build

    -- Initialize widget based on radio type
    if not widget.widgetInitialized then
        if debug then
            print("Debug(build): Widget Initialization")
        end
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
        if debug then
            print("Debug(build): Creating form")
        end
        form.create()
        widget.widgetInitialized = true
    end

    local w, h = lcd.getWindowSize()

    if widget.tlmActive then
        if widget.currentModelID then
            if debug then
                print("Debug(build): Current Model ID: " .. widget.currentModelID)
            end
            for i, battery in ipairs(widget.Batteries) do
                if battery.modelID == widget.currentModelID then
                    widget.selectedModelBattery = i
                    -- if battery.favorite then
                    --     widget.selectedModelBattery = i
                    -- end
                end
            end
        end
    end

    if not widget.selectedModelBattery then
        widget.selectedModelBattery = 1
    end

    if widget.fieldHeight and widget.fieldWidth then
        form.clear()
        if debug then
            print("Debug(build): Updating Choice Field")
        end
        local pos_x = (w / 2 - widget.fieldWidth / 2)
        local pos_y = (h / 2 - widget.fieldHeight / 2)

        local batteryChoices = {}
        if not widget.tlmActive then
            table.insert(batteryChoices, {"No Connection", 1})
        else
            for i, battery in ipairs(widget.Batteries) do
                table.insert(batteryChoices, {battery.name, battery.id})
            end
        end

        -- Create form and add choice field for selecting battery
        local choiceField = form.addChoiceField(nil, {
            x = pos_x,
            y = pos_y,
            w = widget.fieldWidth,
            h = widget.fieldHeight
        }, batteryChoices, function()
            return widget.selectedModelBattery
        end, function(value)
            widget.selectedModelBattery = value
        end)
    end
end

local function wakeup(widget)
    local debug = useDebug.wakeup

    -- Get the current uptime
    local now = os.clock()

    if now - widget.lastTime >= 1 then
        widget.tlmActive = system.getSource({
            category = CATEGORY_SYSTEM_EVENT,
            member = TELEMETRY_ACTIVE,
            options = nil
        }):state()

        if widget.tlmActive then
            doBatteryVoltageCheck(widget)

            -- if Batteries exist, telemetry is active, a battery is selected, and the mAh reading is not nil, do the maths
            local newmAh = getmAh(widget)
            local remainingPercentage = 100

            if #widget.Batteries > 0 and widget.tlmActive and widget.selectedModelBattery and newmAh and widget.useCapacity then
                if newmAh ~= widget.lastmAh then
                    local usablemAh = widget.Batteries[widget.selectedModelBattery].capacity * (widget.useCapacity / 100)
                    remainingPercentage = 100 - (newmAh / usablemAh) * 100
                    if remainingPercentage < 0 then
                        remainingPercentage = 0
                    end
                    widget.lastmAh = newmAh
                end
            end

            updateRemainingSensor(widget, remainingPercentage) -- Update the remaining sensor

            -- Check for modelID sensor presence and its value
            if widget.modelIDSensor == nil then
                widget.modelIDSensor = system.getSource({
                    category = CATEGORY_TELEMETRY,
                    name = "Model ID"
                })
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
            local modelImage = nil
            if widget.currentModelID and widget.Images[widget.currentModelID] then
                if currentBitmapName ~= widget.Images[widget.currentModelID] then
                    modelImage = widget.Images[widget.currentModelID]
                end
            elseif widget.Images.Default ~= "" then
                if currentBitmapName ~= widget.Images.Default then
                    modelImage = widget.Images.Default
                    if debug then
                        print("Debug(wakeup): Setting model image to Default")
                    end
                end
            end

            if modelImage then
                model.bitmap(widget.Images[widget.currentModelID])
                if debug then
                    print("Debug(wakeup): Setting Model Image to: " .. modelImage)
                end
            end
        elseif now - widget.lastTime >= 5 then
            resetWidget(widget)
        end

        widget.lastTime = now
    end

    -- Check if the modelID has changed since last wakeup, and if so, set the rebuildMatching flag to true
    if widget.currentModelID ~= widget.lastModelID then
        if debug then
            print("Debug(wakeup): Model ID has changed")
        end
        widget.lastModelID = widget.currentModelID
        requestWidgetRebuild(widget)
    end

    if widget.widgetRebuildRequired then
        if debug then
            print("Debug(wakeup): Rebuilding widget")
        end
        build(widget)
        widget.widgetRebuildRequired = false
    end

    if widget.rebuildPrefs then
        if debug then
            print("Debug(wakeup): Rebuilding Preferences Panel")
        end
        fillPrefsPanel(widget.prefsPanel, widget)
        widget.rebuildPrefs = false
    end
end

-- This function is called when the user first selects the widget from the widget list, or when they select "configure widget"
local function configure(widget)
    local debug = useDebug.configure
    -- Fill Batteries panel
    if debug then
        print("Debug(configure): Filling Battery Panel")
    end
    widget.batteryPanel = form.addExpansionPanel("Batteries")
    widget.batteryPanel:open(false)
    fillBatteryPanel(widget)

    -- Fill Favorites panel
    if debug then
        print("Debug(configure): Filling Favorites Panel")
    end
    widget.favoritesPanel = form.addExpansionPanel("Favorites")
    widget.favoritesPanel:open(false)
    fillFavoritesPanel(widget)

    -- Fill Images panel
    if debug then
        print("Debug(configure): Filling Images Panel")
    end
    widget.imagePanel = form.addExpansionPanel("Images")
    widget.imagePanel:open(false)
    fillImagePanel(widget)

    -- Preferences Panel
    if debug then
        print("Debug(configure): Filling Preferences Panel")
    end
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
    print("Performing Read")

    local numBatts = storage.read("numBatts") or 0
    print("Number of batteries during read: " .. numBatts)
    widget.Batteries = {}
    if numBatts > 0 then
        for i = 1, numBatts do
            widget.Batteries[i] = {
                name = storage.read("Battery" .. i .. "_name") or "Battery " .. i,
                capacity = storage.read("Battery" .. i .. "_capacity") or 0,
                modelID = storage.read("Battery" .. i .. "_modelID") or 0,
                favorite = storage.read("Battery" .. i .. "_favorite") or false
            }
        end
    end

    populateModelIds(widget)

    widget.useCapacity = storage.read("useCapacity") or 80

    widget.voltageCheckEnabled = storage.read("checkBatteryVoltageOnConnect") or false
    widget.voltageCheckMinChargedCellVoltage = storage.read("minChargedCellVoltage") or 415

    widget.doHaptic = storage.read("doHaptic") or false
    widget.hapticPattern = storage.read("hapticPattern") or 1

    widget.Images = {
        Default = storage.read("ImagesDefault") or ""
    }

    for _, modelId in ipairs(widget.modelIds) do
        widget.Images[modelId] = storage.read("Images" .. modelId) or ""
    end
end

local function write(widget) -- Write configuration to storage
    print("Writing "..#widget.Batteries.." as number of batteries")
    storage.write("numBatts", #widget.Batteries)
    for i, battery in ipairs(widget.Batteries) do
        print("Writing battery ".. i .. " to storage for battery name".. battery.name)
        storage.write("Battery" .. i .. "_name", battery.name)
        storage.write("Battery" .. i .. "_capacity", battery.capacity)
        storage.write("Battery" .. i .. "_modelID", battery.modelID)
        storage.write("Battery" .. i .. "_favorite", battery.favorite)
    end

    storage.write("useCapacity", widget.useCapacity)

    storage.write("checkBatteryVoltageOnConnect", widget.voltageCheckEnabled)
    storage.write("minChargedCellVoltage", widget.voltageCheckMinChargedCellVoltage)

    storage.write("doHaptic", widget.doHaptic)
    storage.write("hapticPattern", widget.hapticPattern)
    storage.write("ImagesDefault", widget.Images.Default)

    for id, image in pairs(widget.Images) do
        if id ~= "Default" then
            storage.write("Images" .. id, image)
        end
    end
end

local function paint(widget)
end

local function init()
    system.registerWidget({
        key = "battsel",
        name = "Battery Select",
        create = create,
        build = build,
        wakeup = wakeup,
        paint = paint,
        configure = configure,
        read = read,
        write = write
    })
end

return {
    init = init
}
