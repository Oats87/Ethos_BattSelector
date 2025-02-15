-- Ethos Battery Manager

local HapticPatterns = { { ". . . . . .", 1 }, { ". - . - . - .", 2 }, { ". - - . - - . - - . - - .", 3 } }

-- Get Radio Version to determine field size
local radio = system.getVersion()

local LIP = assert(loadfile("lib/lip.lua"))()
local fieldWidth
local fieldHeight

-- This function is called when the widget is first created
local function create()
    local widget = {
        -- Remaining Percentage Sensor
        remainingPercentSensor = nil,

        -- Battery Handling
        batteries = {},
        useCapacity = nil,
        lastObservedConsumption = 0,
        selectedModelBattery = nil,

        -- Voltage Check
        voltageCheckConfig = {
            enabled = false,
            minChargedCellVoltage = nil,
            hapticEnabled = false,
            hapticPattern = nil,
        },

        voltageCheckCompleted = false,
        voltageCheckLastCheckTime = nil,
        voltageCheckBatteryConnectTime = nil,

        -- Model IDs
        modelIds = {},
        modelIDSensor = nil,
        lastModelID = nil,
        currentModelID = nil,

        -- Widget Internals
        lastReconcileTime = os.clock(),
        telemetryActive = false,

        widgetRebuildRequired = false,
        widgetInitialized = false, -- Tracks whether the widget has been initalized.

        batteryPanel = nil,
        prefsPanel = nil,
        preferencePanelRebuildRequired = false,

        mahSensor = nil,
        cellSensor = nil,
        voltageSensor = nil,
    }
    return widget
end

local function read(widget)
    if os.stat("config.ini") then
        local config = LIP.load("config.ini")
        widget.voltageCheckConfig = config.voltageCheckConfig
        widget.useCapacity = config.general.useCapacity
    end
    if os.stat("batteries.ini") then
        widget.batteries = LIP.load("batteries.ini")
        print("loaded batteries")
    end
end

local function write(widget)
    LIP.save("config.ini", {
        general = {
            useCapacity = widget.useCapacity
        },
        voltageCheckConfig = {
            widget.voltageCheckConfig
        }
    })
    LIP.save("batteries.ini", widget.batteries)
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
    widget.lastObservedConsumption = 0
    widget.currentModelID = nil

    resetBatteryVoltageCheck(widget, false)
    requestWidgetRebuild(widget)
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
    form.addStaticText(line, pos_header_id, "ID")

    for i, battery in ipairs(widget.batteries) do
        line = widget.batteryPanel:addLine("")

        form.addTextField(line, pos_value_name, function()
            return battery.name
        end, function(newName)
            battery.name = newName
            write(widget)
            requestWidgetRebuild(widget)
        end)

        field = form.addNumberField(line, pos_value_capacity, 0, 20000, function()
            return battery.capacity
        end, function(value)
            battery.capacity = value
            write(widget)
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
            write(widget)
            requestWidgetRebuild(widget)
        end)

        field:default(0)
        field:enableInstantChange(false)

        field = form.addTextButton(line, pos_options_button, "...", function()
            local buttons = { {
                label = "Cancel",
                action = function()
                    return true
                end
            }, {
                label = "Delete",
                action = function()
                    table.remove(widget.batteries, i)
                    write(widget)
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
                    write(widget)
                    requestWidgetRebuild(widget)
                    return true
                end
            } }
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
            modelID = 0,
        })
        write(widget)
        fillBatteryPanel(widget)
        requestWidgetRebuild(widget)
    end)
end

-- Settings Panel
local function fillPrefsPanel(widget)
    if not widget.prefsPanel then
        return
    else
        widget.prefsPanel:clear()
    end

    local line = widget.prefsPanel:addLine("Use Capacity")
    local field = form.addNumberField(line, nil, 50, 100, function()
        return widget.useCapacity
    end, function(value)
        widget.useCapacity = value
    end)
    field:suffix("%")

    -- Create field to enable/disable battery voltage checking on connect
    line = widget.prefsPanel:addLine("Enable Voltage Check")
    field = form.addBooleanField(line, nil, function()
        return widget.voltageCheckConfig.hapticEnabled
    end, function(newValue)
        widget.voltageCheckConfig.hapticEnabled = newValue
        widget.preferencePanelRebuildRequired = true
    end)

    if widget.voltageCheckConfig.hapticEnabled then
        line = widget.prefsPanel:addLine("Min Charged Volt/Cell")
        field = form.addNumberField(line, nil, 400, 430, function()
            return widget.voltageCheckConfig.minChargedCellVoltage
        end, function(value)
            widget.voltageCheckConfig.minChargedCellVoltage = value
        end)
        field:decimals(2)
        field:suffix("V")
        field:enableInstantChange(false)

        line = widget.prefsPanel:addLine("Haptic Warning")
        form.addBooleanField(line, nil, function()
            return widget.voltageCheckConfig.hapticEnabled
        end, function(newValue)
            widget.voltageCheckConfig.hapticEnabled = newValue
            widget.preferencePanelRebuildRequired = true
        end)

        if widget.voltageCheckConfig.hapticEnabled then
            line = widget.prefsPanel:addLine("Haptic Pattern")
            form.addChoiceField(line, nil, HapticPatterns, function()
                return widget.voltageCheckConfig.hapticPattern
            end, function(newValue)
                widget.voltageCheckConfig.hapticPattern = newValue
            end)
        end
    end
end

-- Alerts Panel, commented out for now as not in use
-- local function fillAlertsPanel(alertsPanel, widget)
--     local line = alertsPanel:addLine("Eventually")
-- end

-- Estimate cellcount and check if battery is charged.  If not, popup dialog to alert user
local function doBatteryVoltageCheck(widget)
    if not widget.telemetryActive then -- reset the voltage check if telemetry is not active or the voltage check is not enabled
        resetBatteryVoltageCheck(widget, false)
        return
    end

    if widget.voltageCheckComplete or not widget.voltageCheckConfig.enabled then
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

    if (now - widget.batteryConnectTime) > 30 then
        resetBatteryVoltageCheck(widget, true)
        return
    end

    -- Check if voltage sensor exists, if not, get it
    if not widget.voltageSensor then
        widget.voltageSensor = system.getSource({
            category = CATEGORY_TELEMETRY,
            name = "Voltage"
        })
        if not widget.voltageSensor then
            return
        end
    end

    local currentVoltage = widget.voltageSensor:value()

    if not currentVoltage then
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
        cellCount = math.floor(widget.cellSensor:value())
        isCharged = currentVoltage >= cellCount * widget.voltageCheckConfig.minChargedCellVoltage
    else
        -- Estimate cell count based on voltage
        cellCount = math.floor(currentVoltage / widget.voltageCheckConfig.minChargedCellVoltage + 0.5)
        -- To prevent accidentally reading a very low battery as a lower cell count than actual, add 1 to cellCount if the voltage is higher than cellCount * 4.35 (HV battery max cell voltage)
        if currentVoltage >= cellCount * 4.35 then
            cellCount = cellCount + 1
        end

        if cellCount == 0 then
            cellCount = 1
        end

        isCharged = currentVoltage >= cellCount * widget.voltageCheckConfig.minChargedCellVoltage
    end

    if not isCharged then
        local buttons = { {
            label = "Acknowledge",
            action = function() return true end
        } }
        if widget.voltageCheckConfig.hapticEnabled then
            system.playHaptic(HapticPatterns[widget.voltageCheckConfig.hapticPattern][1])
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
            print("No mAh sensor found!")
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
        if not widget.useCapacity then widget.useCapacity = 70 end
        if not widget.voltageCheckConfig.enabled then widget.voltageCheckConfig.enabled = false end
        if not widget.voltageCheckConfig.minChargedCellVoltage then widget.voltageCheckConfig.minChargedCellVoltage = 415 end
        if not widget.voltageCheckConfig.hapticEnabled then widget.voltageCheckConfig.hapticEnabled = false end
        if not widget.voltageCheckConfig.hapticPattern then widget.voltageCheckConfig.hapticPattern = 1 end
        form.create()
        widget.widgetInitialized = true
    end

    if widget.telemetryActive then
        if widget.currentModelID then
            for i, battery in ipairs(widget.batteries) do
                if battery.modelID == widget.currentModelID then
                    widget.selectedModelBattery = i
                end
            end
        end
    end

    if not widget.selectedModelBattery then
        widget.selectedModelBattery = 1
    end

    if fieldHeight and fieldWidth then
        form.clear()

        local batteryChoices = {}
        if not widget.telemetryActive then
            table.insert(batteryChoices, { "No Connection", 1 })
        else
            for i, battery in ipairs(widget.batteries) do
                table.insert(batteryChoices, { battery.name, i })
            end
        end

        local w, h = lcd.getWindowSize()
        -- Create form and add choice field for selecting battery
        form.addChoiceField(nil, {
            x = (w / 2 - fieldWidth / 2),
            y = (h / 2 - fieldHeight / 2),
            w = fieldWidth,
            h = fieldHeight
        }, batteryChoices, function()
            return widget.selectedModelBattery
        end, function(value)
            widget.selectedModelBattery = value
        end)
    end
end

local function reconcileCurrentModelId(widget)
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

    -- Check if the modelID has changed since last wakeup, and if so, set the rebuildMatching flag to true
    if widget.currentModelID ~= widget.lastModelID then
        widget.lastModelID = widget.currentModelID
        requestWidgetRebuild(widget)
    end
end

local function reconcileConsumption(widget)
    -- if batteries exist, telemetry is active, a battery is selected, and the mAh reading is not nil, do the maths
    local currentConsumption = getCurrentConsumption(widget)
    local remainingPercentage = 100

    if #widget.batteries > 0 and widget.selectedModelBattery and currentConsumption and widget.useCapacity then
        if currentConsumption ~= widget.lastObservedConsumption then
            local usablemAh = widget.batteries[widget.selectedModelBattery].capacity * (widget.useCapacity / 100)
            remainingPercentage = 100 - (currentConsumption / usablemAh) * 100
            if remainingPercentage < 0 then
                remainingPercentage = 0
            end
            widget.lastObservedConsumption = currentConsumption
        end
    end
    updateRemainingPercentSensor(widget, remainingPercentage) -- Update the remaining sensor
end

local function wakeup(widget)
    local now = os.clock()
    local timeSinceLastReconcile = now - widget.lastReconcileTime

    if timeSinceLastReconcile >= 1 then
        widget.telemetryActive = system.getSource({
            category = CATEGORY_SYSTEM_EVENT,
            member = TELEMETRY_ACTIVE,
            options = nil
        }):state()

        if widget.telemetryActive then
            doBatteryVoltageCheck(widget)
            reconcileConsumption(widget)
            reconcileCurrentModelId(widget)

            widget.lastReconcileTime = now
        elseif timeSinceLastReconcile >= 5 then
            resetWidget(widget)
        end
    end

    if widget.widgetRebuildRequired then
        build(widget)
        widget.widgetRebuildRequired = false
    end

    if widget.preferencePanelRebuildRequired then
        fillPrefsPanel(widget)
        widget.preferencePanelRebuildRequired = false
    end
end

-- This function is called when the user first selects the widget from the widget list, or when they select "configure widget"
local function configure(widget)
    read(widget)
    widget.batteryPanel = form.addExpansionPanel("Batteries")
    widget.batteryPanel:open(false)
    fillBatteryPanel(widget)

    widget.prefsPanel = form.addExpansionPanel("Preferences")
    widget.prefsPanel:open(false)
    fillPrefsPanel(widget)
end


local function paint(widget) end

local function init()
    -- Set form size based on radio type
    if string.find(radio.board, "X20") or radio.board == "X18R" or radio.board == "X18RS" then
        fieldHeight = 40
        fieldWidth = 145
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
