-- Ethos Battery Manager
local HapticPatterns = {{". . . . . .", 1}, {". - . - . - .", 2}, {". - - . - - . - - . - - .", 3}}

-- Get Radio Version to determine field size
local radio = system.getVersion()

-- local LIP = assert(loadfile("lib/lip.lua"))()
local jsonFile = assert(loadfile("lib/json_file.lua"))()
local fieldWidth
local fieldHeight

-- This function is called when the widget is first created
local function create()
    local widget = {
        -- Remaining Percentage Sensor
        remainingPercentSensor = nil,

        -- Battery Handling
        batteries = {},
        lastObservedConsumption = 0,
        selectedModelBattery = nil,

        -- Configuration
        config = {
            useCapacity = nil,

            voltageCheckEnabled = false,
            voltageCheckMinChargedCellVoltage = nil,
            voltageCheckHapticEnabled = false,
            voltageCheckHapticPattern = nil,
            remainingCalloutSwitch = nil,
            remainingCalloutInterval = 10,
            remainingCalloutZeroPercentInterval = 5,
            remainingCalloutHapticEnabled = false,
            remainingCalloutHapticPattern = nil,
        },

        modelStorage = {
            pinnedModelId = nil,
        },

        voltageCheckCompleted = false,
        voltageCheckPromptOpen = false, 
        voltageCheckLastCheckTime = nil,
        voltageCheckBatteryConnectTime = nil,

        batteryChoiceFieldFocusOnBuild = false,

        -- Model IDs
        modelIds = {},
        modelIDSensor = nil,
        lastModelID = nil,
        currentModelID = nil,

        -- Widget Internals
        lastReconcileTime = os.clock(),
        telemetryActive = false,
        telemetryActiveTime = nil,

        widgetRebuildRequired = false,
        widgetInitialized = false, -- Tracks whether the widget has been initalized.

        batteryPanel = nil,
        globalSettingsPanel = nil,
        modelSettingsPanel = nil,
        preferencePanelRebuildRequired = false,

        mahSensor = nil,
        cellSensor = nil,
        voltageSensor = nil,

        remainingCalloutSwitch = nil,

        noBatteriesAlert = {
            enabled = false,
            lastPlayTime = nil,
        },

        batteryNeedsSelectionAlert = {
            enabled = false,
            lastPlayTime = nil,
        },

        remainingPercentageAlert = {
            lastPlayedPercentage = nil,
            lastCriticalPlayTime = nil,
        }
    }
    return widget
end

local function readFromFiles(widget)
    if os.stat("config.json") then
        widget.config = jsonFile.load("config.json")
    end
    if os.stat("batteries.json") then
        widget.batteries = jsonFile.load("batteries.json")
    end
end
local function read(widget)
    readFromFiles(widget)
    widget.modelStorage.pinnedModelId = storage.read("m0") or 0
end

local function writeToFiles(widget)
    jsonFile.save("config.json", widget.config)
    jsonFile.save("batteries.json", widget.batteries)
end

local function write(widget)
    writeToFiles(widget)
    storage.write("m0", widget.modelStorage.pinnedModelId)
end

local function requestWidgetRebuild(widget)
    widget.widgetRebuildRequired = true
end

local function resetBatteryVoltageCheck(widget, completed)
    widget.voltageCheckCompleted = completed

    widget.voltageCheckLastCheckTime = nil
    widget.voltageCheckBatteryConnectTime = nil
end

local function fillBatteryPanel(widget)
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

    local field
    -- Create header for the battery panel
    local line = widget.batteryPanel:addLine("")

    form.addStaticText(line, pos_header_battery, "Name")
    form.addStaticText(line, pos_header_capacity, "Capacity")
    form.addStaticText(line, pos_header_id, "mID")

    for i, battery in ipairs(widget.batteries) do
        line = widget.batteryPanel:addLine("")

        form.addTextField(line, pos_value_name, function()
            return battery.name
        end, function(newName)
            battery.name = newName
            writeToFiles(widget)
            requestWidgetRebuild(widget)
        end)

        field = form.addNumberField(line, pos_value_capacity, 0, 20000, function()
            return battery.capacity
        end, function(value)
            battery.capacity = value
            writeToFiles(widget)
            requestWidgetRebuild(widget)
        end)
        field:suffix("mAh")
        field:step(100)
        field:default(0)
        field:enableInstantChange(false)

        field = form.addNumberField(line, pos_value_id, 0, 99, function()
            return battery.modelID
        end, function(value)
            battery.modelID = value
            writeToFiles(widget)
            requestWidgetRebuild(widget)
        end)

        field:default(0)
        field:enableInstantChange(false)

        field = form.addTextButton(line, pos_options_button, "...", function()
            local buttons = {{
                label = "Cancel",
                action = function()
                    return true
                end
            }, {
                label = "Delete",
                action = function()
                    table.remove(widget.batteries, i)
                    writeToFiles(widget)
                    fillBatteryPanel(widget)
                    requestWidgetRebuild(widget)
                    return true
                end
            }, {
                label = "Clone",
                action = function()
                    local newBattery = {
                        name = battery.name,
                        capacity = battery.capacity,
                        modelID = battery.modelID
                    }
                    table.insert(widget.batteries, newBattery)
                    writeToFiles(widget)
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

    line = widget.batteryPanel:addLine("")
    form.addTextButton(line, pos_add_button, "Add New", function()
        table.insert(widget.batteries, {
            name = "Battery " .. #widget.batteries + 1,
            capacity = 0,
            modelID = 0
        })
        writeToFiles(widget)
        fillBatteryPanel(widget)
        requestWidgetRebuild(widget)
    end)
end

-- Settings Panel
local function fillModelSettingsPanel(widget)
    if not widget.modelSettingsPanel then
        return
    else
        widget.modelSettingsPanel:clear()
    end

        local line = widget.modelSettingsPanel:addLine("Override Model ID")
        local field = form.addNumberField(line, nil, 0, 99, function()
            return widget.modelStorage.pinnedModelId
        end, function(value)
            widget.modelStorage.pinnedModelId = value
        end)
        field:enableInstantChange(false)
end

-- Settings Panel
local function fillGlobalSettingsPanel(widget)
    if not widget.globalSettingsPanel then
        return
    else
        widget.globalSettingsPanel:clear()
    end

    local line = widget.globalSettingsPanel:addLine("Use Capacity")
    local field = form.addNumberField(line, nil, 50, 100, function()
        return widget.config.useCapacity
    end, function(value)
        widget.config.useCapacity = value
    end)
    field:suffix("%")

    line = widget.globalSettingsPanel:addLine("Remaining Capacity Callout Enable")
    field = form.addSwitchField(line, nil, 
        function() 
            return widget.remainingCalloutSwitch 
        end, 
        function(newValue) 
            widget.remainingCalloutSwitch = newValue
            if widget.remainingCalloutSwitch then 
                widget.config.remainingCalloutSwitch  = 
            {
                name = newValue:name(),
                member = newValue:member(),
                category = newValue:category(),
                physId = newValue:physId(),
                appId = newValue:appId(),
            }
            else
                widget.config.remainingCalloutSwitch = nil
            end
        end)

    -- Create field to enable/disable battery voltage checking on connect
    line = widget.globalSettingsPanel:addLine("Enable Voltage Check")
    field = form.addBooleanField(line, nil, function()
        return widget.config.voltageCheckEnabled
    end, function(newValue)
        widget.config.voltageCheckEnabled = newValue
        widget.preferencePanelRebuildRequired = true
    end)

    if widget.config.voltageCheckEnabled then
        line = widget.globalSettingsPanel:addLine("Min Charged Volt/Cell")
        field = form.addNumberField(line, nil, 400, 430, function()
            return widget.config.voltageCheckMinChargedCellVoltage
        end, function(value)
            widget.config.voltageCheckMinChargedCellVoltage = value
        end)
        field:decimals(2)
        field:suffix("V")
        field:enableInstantChange(false)

        line = widget.globalSettingsPanel:addLine("Haptic Warning")
        form.addBooleanField(line, nil, function()
            return widget.config.voltageCheckHapticEnabled
        end, function(newValue)
            widget.config.voltageCheckHapticEnabled = newValue
            widget.preferencePanelRebuildRequired = true
        end)

        if widget.config.voltageCheckHapticEnabled then
            line = widget.globalSettingsPanel:addLine("Haptic Pattern")
            form.addChoiceField(line, nil, HapticPatterns, function()
                return widget.config.voltageCheckHapticPattern
            end, function(newValue)
                widget.config.voltageCheckHapticPattern = newValue
            end)
        end
    end
end

local function openBatteryVoltagePrompt(widget, title, message) 

    widget.voltageCheckPromptOpen = true
        local buttons = {{
            label = "Acknowledge",
            action = function()
                widget.voltageCheckPromptOpen = false
                return true
            end
        }}
        system.playFile("sound/alert.wav")
        if widget.config.voltageCheckHapticEnabled then
            system.playHaptic(HapticPatterns[widget.config.voltageCheckHapticPattern][1])
        end
        form.openDialog({
            title = title,
            message = message,
            width = 500,
            buttons = buttons,
            options = TEXT_LEFT
        })
    end


-- Estimate cellcount and check if battery is charged.  If not, popup dialog to alert user
local function doBatteryVoltageCheck(widget)
    if not widget.telemetryActive or not widget.selectedModelBattery then -- reset the voltage check if telemetry is not active or the voltage check is not enabled
        resetBatteryVoltageCheck(widget, false)
        return
    end

    if widget.voltageCheckCompleted or not widget.config.voltageCheckEnabled then
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
        return
    end

    -- Check if voltage sensor exists, if not, get it
    if not widget.voltageSensor then
        widget.voltageSensor = system.getSource({
            category = CATEGORY_TELEMETRY,
            name = "Voltage"
        })
        if not widget.voltageSensor then
            widget.voltageSensor = system.getSource({
                category = CATEGORY_TELEMETRY,
                name = "Battery Voltage"
            })
            if not widget.voltageSensor then
                openBatteryVoltagePrompt(widget, "Voltage Sensor Not Found", "Ensure there is a valid voltage sensor.")
                resetBatteryVoltageCheck(widget, true)
                return
            end
        end
    end

    local currentVoltage = widget.voltageSensor:value()

    if not currentVoltage then
        if now - widget.voltageCheckBatteryConnectTime > 5 then
            openBatteryVoltagePrompt(widget, "Voltage Sensor Value Invalid", "Ensure there is a valid voltage sensor.")
            resetBatteryVoltageCheck(widget, true)
        end
        return -- not ready for voltage check, the voltage sensor value was nil
    end

    -- Check if cell count sensor exists (RF 2.2? only), if not, get it
    if not widget.cellSensor then
        widget.cellSensor = system.getSource({
            category = CATEGORY_TELEMETRY,
            name = "Cell Count"
        })
    end

    local cellCount
    local isCharged = false

    if widget.cellSensor then
        if not widget.cellSensor:value() then
            if now - widget.voltageCheckBatteryConnectTime > 5 then
                openBatteryVoltagePrompt(widget, "Cell Count Sensor Value Invalid", "Ensure there is a valid cell count sensor.")
                resetBatteryVoltageCheck(widget, true)
            end
            return
        end
        cellCount = math.floor(widget.cellSensor:value())
        isCharged = currentVoltage >= cellCount * widget.config.voltageCheckMinChargedCellVoltage
    else
        -- Estimate cell count based on voltage
        cellCount = math.floor(currentVoltage / (widget.config.voltageCheckMinChargedCellVoltage/100) + 0.5)
        -- To prevent accidentally reading a very low battery as a lower cell count than actual, add 1 to cellCount if the voltage is higher than cellCount * 4.35 (HV battery max cell voltage)
        if currentVoltage >= cellCount * 4.35 then
            cellCount = cellCount + 1
        end

        if cellCount == 0 then
            cellCount = 1
        end

        isCharged = currentVoltage >= cellCount * widget.config.voltageCheckMinChargedCellVoltage
    end

    if not isCharged then
        widget.voltageCheckPromptOpen = true
        local buttons = {{
            label = "Acknowledge",
            action = function()
                widget.voltageCheckPromptOpen = false
                return true
            end
        }}
        system.playFile("sound/alert.wav")
        if widget.config.voltageCheckHapticEnabled then
            system.playHaptic(HapticPatterns[widget.config.voltageCheckHapticPattern][1])
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

local function updateRemainingPercentSensor(widget, newPercent)
    if not widget.remainingPercentSensor then
        widget.remainingPercentSensor = system.getSource({
            category = CATEGORY_TELEMETRY,
            appId = 0x4402,
            physId = 0x11,
            name = "Remaining"
        })
        if not widget.remainingPercentSensor then
            widget.remainingPercentSensor = model.createSensor()
            widget.remainingPercentSensor:name("Remaining")
            widget.remainingPercentSensor:unit(UNIT_PERCENT)
            widget.remainingPercentSensor:decimals(0)
            widget.remainingPercentSensor:appId(0x4402)
            widget.remainingPercentSensor:physId(0x11)
        end
    end

    widget.remainingPercentSensor:value(newPercent)
end

local function resetWidget(widget)
    widget.selectedModelBattery = nil
    widget.lastObservedConsumption = 0
    widget.lastReconcileTime = os.clock()
    widget.currentModelID = nil
    if widget.telemetryActiveTime then
        system.playFile("sound/telemetry_lost.wav")
    end
    widget.telemetryActiveTime = nil

    widget.remainingPercentageAlert.lastCriticalPlayTime = nil
    widget.remainingPercentageAlert.lastPlayedPercentage = nil

    widget.voltageCheckPromptOpen = false

    resetBatteryVoltageCheck(widget, false)
    requestWidgetRebuild(widget)
end

local function getCurrentConsumption(widget)
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
            return 0
        end
    end

    -- Return the value or 0 if no valid sensor was found
    if widget.mAhSensor and widget.mAhSensor:value() then
        return math.floor(widget.mAhSensor:value())
    else
        return 0
    end
end

local function build(widget)
    -- Initialize widget based on radio type
    if not widget.widgetInitialized then
        if widget.config.remainingCalloutSwitch then
                widget.remainingCalloutSwitch = system.getSource(widget.config.remainingCalloutSwitch)
        end
        if not widget.config.useCapacity then
            widget.config.useCapacity = 70
        end
        if not widget.config.voltageCheckEnabled then
            widget.config.voltageCheckEnabled = false
        end
        if not widget.config.voltageCheckMinChargedCellVoltage then
            widget.config.voltageCheckMinChargedCellVoltage = 415
        end
        if not widget.config.voltageCheckHapticEnabled then
            widget.config.voltageCheckHapticEnabled = false
        end
        if not widget.config.voltageCheckHapticPattern then
            widget.config.voltageCheckHapticPattern = 1
        end
        if not widget.config.remainingCalloutInterval then
            widget.config.remainingCalloutInterval = 10
        end
        if not widget.config.remainingCalloutZeroPercentInterval then
            widget.config.remainingCalloutZeroPercentInterval = 5
        end
        form.create()
        if #widget.batteries == 0 then
            form.clear()
            local buttons = {{
                label = "Acknowledge",
                action = function()
                    widget.noBatteriesAlert.lastPlayTime = nil
                    widget.noBatteriesAlert.enabled = false
                    return true
                end
            }}
            -- local noBatteriesAlertSoundTime = os.clock()
            if not widget.noBatteriesAlert.lastPlayTime then
                system.playFile("sound/alert.wav")
                widget.noBatteriesAlert.enabled = true
                widget.noBatteriesAlert.lastPlayTime = os.clock()
            end
            local dialog = form.openDialog({
                title = "No Batteries Found!",
                message = "No batteries were found for the widget. Please add at least one battery!",
                width = 500,
                buttons = buttons,
                options = TEXT_LEFT,
                wakeup = function()
                    local now = os.clock()
                    if widget.noBatteriesAlert.enabled and (now - widget.noBatteriesAlert.lastPlayTime) > 5 then
                        system.playFile("sound/alert.wav")
                        widget.noBatteriesAlert.lastPlayTime = now
                    end
                end
            })
        end
        widget.widgetInitialized = true
    end

    if fieldHeight and fieldWidth then
        form.clear()

        local w, h = lcd.getWindowSize()
        if widget.telemetryActive then
            if widget.currentModelID then
                for i, battery in ipairs(widget.batteries) do
                    if battery.modelID == widget.currentModelID then
                        widget.selectedModelBattery = i
                        system.playFile("sound/batt_auto_selected.wav")
                    end
                end
            end
            local batteryChoices = {}
            for i, battery in ipairs(widget.batteries) do
                table.insert(batteryChoices, {battery.name, i})
            end
            -- Create form and add choice field for selecting battery
             local batteryChoiceField = form.addChoiceField(nil, {
                x = (w / 2 - fieldWidth / 2),
                y = (h / 2 - fieldHeight / 2),
                w = fieldWidth,
                h = fieldHeight
            }, batteryChoices, function()
                return widget.selectedModelBattery
            end, function(value)
                widget.selectedModelBattery = value
                widget.batteryNeedsSelectionAlert.enabled = false
                widget.batteryNeedsSelectionAlert.lastPlayTime = nil
                widget.batteryChoiceFieldFocusOnBuild = false
            end)

            if not widget.selectedModelBattery and widget.batteryChoiceFieldFocusOnBuild then
                batteryChoiceField:focus()
                widget.batteryNeedsSelectionAlert.enabled = true
            end
        else
            local msg = "Waiting for Telemetry"
            local textW, textH = lcd.getTextSize(msg)

            form.addStaticText(nil, {
                x = (w / 2 - textW / 2),
                y = (h / 2 - textH / 2),
                w = textW,
                h = textW
            }, msg)
        end
    end
end

local function reconcileCurrentModelId(widget)
    if widget.modelStorage.pinnedModelId and widget.modelStorage.pinnedModelId ~= 0 then
        widget.currentModelID = widget.modelStorage.pinnedModelId
    else 

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
end 
    -- Check if the modelID has changed since last wakeup, and if so, set the rebuildMatching flag to true
    if widget.currentModelID ~= widget.lastModelID then
        widget.lastModelID = widget.currentModelID
        requestWidgetRebuild(widget)
    end
end

local function reconcileConsumption(widget)
    -- if batteries exist, telemetry is active, a battery is selected, and the mAh reading is not nil, do the maths
    local currentConsumption = getCurrentConsumption(widget)
    if #widget.batteries > 0 and widget.selectedModelBattery and currentConsumption and widget.config.useCapacity then
        if currentConsumption >= widget.lastObservedConsumption then
            local usablemAh = widget.batteries[widget.selectedModelBattery].capacity * (widget.config.useCapacity / 100)
            local remainingPercentage = 100 - (currentConsumption / usablemAh) * 100
            if remainingPercentage < 0 then
                remainingPercentage = 0
            end
            updateRemainingPercentSensor(widget, remainingPercentage) -- Update the remaining sensor
            widget.lastObservedConsumption = currentConsumption

            if widget.remainingCalloutSwitch and widget.remainingCalloutSwitch:state() then
                if remainingPercentage == 0 or 
                remainingPercentage % 10 == 0 or 
                (widget.remainingPercentageAlert.lastPlayedPercentage and 
                (widget.remainingPercentageAlert.lastPlayedPercentage - remainingPercentage 
                > widget.config.remainingCalloutInterval)) then
                    local roundedPercent = math.ceil(remainingPercentage / 10) * 10

                    local playRequired = remainingPercentage ~= 0 and widget.remainingPercentageAlert.lastPlayedPercentage ~= roundedPercent
                    if remainingPercentage == 0 then
                        if widget.remainingPercentageAlert.lastCriticalPlayTime then
                        end
                        local now = os.clock()
                        if (widget.remainingPercentageAlert.lastCriticalPlayTime and now - widget.remainingPercentageAlert.lastCriticalPlayTime > widget.config.remainingCalloutZeroPercentInterval) or not widget.remainingPercentageAlert.lastCriticalPlayTime then
                            playRequired = true
                            widget.remainingPercentageAlert.lastCriticalPlayTime = now
                        end
                    end
                    
                    if playRequired then
                        widget.remainingPercentageAlert.lastPlayedPercentage = roundedPercent
                        system.playFile("sound/battery.wav")
                        system.playNumber(roundedPercent, UNIT_PERCENT, 0)

                        if remainingPercentage == 0 and widget.config.remainingCalloutHapticEnabled and widget.config.remainingCalloutHapticPattern then
                            system.playHaptic(HapticPatterns[widget.config.remainingCalloutHapticPattern][1])
                        end
                    end
                end
             else 
                 widget.remainingPercentageAlert.lastPlayedPercentage = nil
             end

        end
     
    end
end

local function wakeup(widget)
    local now = os.clock()
    if widget.batteryNeedsSelectionAlert.enabled and not widget.selectedModelBattery then
        if (widget.batteryNeedsSelectionAlert.lastPlayTime and now - widget.batteryNeedsSelectionAlert.lastPlayTime > 5) or not widget.batteryNeedsSelectionAlert.lastPlayTime then
        system.playFile("sound/batt_needs_selection.wav")
        widget.batteryNeedsSelectionAlert.lastPlayTime = now
        end
    end

    local timeSinceLastReconcile = now - widget.lastReconcileTime

    if timeSinceLastReconcile >= 1 then
        widget.telemetryActive = system.getSource({
            category = CATEGORY_SYSTEM_EVENT,
            member = TELEMETRY_ACTIVE,
            options = nil
        }):state()

        if widget.telemetryActive then
            if not widget.telemetryActiveTime then
                widget.telemetryActiveTime = now
                widget.batteryChoiceFieldFocusOnBuild = true
                
                requestWidgetRebuild(widget)
                system.playFile("sound/telemetry_active.wav")
            end
            if widget.selectedModelBattery then
                doBatteryVoltageCheck(widget)
                if widget.config.voltageCheckEnabled and not widget.voltageCheckPromptOpen and widget.voltageCheckCompleted or not widget.config.voltageCheckEnabled then
                    reconcileConsumption(widget)
                end
            end
            reconcileCurrentModelId(widget)
            widget.lastReconcileTime = now
        elseif not widget.telemetryActive and timeSinceLastReconcile >= 5 then
            resetWidget(widget)
        end
    end

    if widget.widgetRebuildRequired then
        build(widget)
        widget.widgetRebuildRequired = false
    end

    if widget.preferencePanelRebuildRequired then
        fillGlobalSettingsPanel(widget)
        widget.preferencePanelRebuildRequired = false
    end
end

-- This function is called when the user first selects the widget from the widget list, or when they select "configure widget"
local function configure(widget)
    widget.batteryPanel = form.addExpansionPanel("Batteries")
    fillBatteryPanel(widget)

    widget.modelSettingsPanel = form.addExpansionPanel("Model Settings")
    fillModelSettingsPanel(widget)

    widget.globalSettingsPanel = form.addExpansionPanel("Global Settings")
    fillGlobalSettingsPanel(widget)
end

local function paint(widget)
end

local function init()
    -- Set form size based on radio type
    if string.find(radio.board, "X20") or radio.board == "X18R" or radio.board == "X18RS" then
        fieldHeight = 40
        fieldWidth = 155
    elseif radio.board == "X18" or radio.board == "X18S" or radio.board == "TWXLITE" or radio.board == "TWXLITES" then
        fieldHeight = 30
        fieldWidth = 100
    else
        return
        -- Currently not tested on other radios (X10,X12,X14)
    end
    system.registerWidget({
        key = "battmgr",
        name = "Battery Manager",
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
