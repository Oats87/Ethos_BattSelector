local function create()
    local widget = {
        voltageSensor = nil,
        voltageSensorActive = false,
        currentVoltage = nil,
        lastVoltageUpdate = nil,
        cellCountSensorActive = false,
        config = {
            startVoltage = 1244,
            voltageRate = 0, -- 0.05 per ...
            voltageRateTime = 1, -- every N seconds (not guaranteed)
            cellCount = 3
        }
    }
    return widget
end

local function build(widget)
    form.create()
    local line = form.addLine("a", nil, false)
    form.addButton(line, nil, {
        text = "Start",
        press = function()
            if not widget.currentVoltage then 
                widget.currentVoltage = widget.config.startVoltage
            end
            widget.voltageActive = true
            print("starting voltage")
        end
    })
    line = form.addLine("b", nil, false)
    form.addButton(line, nil, {
        text = "Stop",
        press = function()
            widget.lastVoltageUpdate = nil
            widget.voltageActive = false
            print("stopping voltage")
        end
    })
    line = form.addLine("c", nil, false)
    form.addButton(line, nil, {
            text = "CellCount",
            press = function()
                widget.cellCountSensorActive = not widget.cellCountSensorActive
                print("toggling cellcount sensor")
            end
        })
    -- form.addButton(line, nil, {
    --     text = "Reset",
    --     press = function()
    --         widget.currentVoltage = widget.config.startVoltage
    --         widget.voltageSensor:value(widget.currentVoltage)
    --         widget.lastVoltageUpdate = nil
    --         print("resetting voltage")
    --     end
    -- })
end

local function setCellCount(widget)
    local cellSensor = system.getSource({
        category = CATEGORY_TELEMETRY,
        name = "Cell Count"
    })
    if cellSensor then
        cellSensor:value(widget.config.cellCount)
    else 
        cellSensor = model.createSensor()
        cellSensor:name("Cell Count")
        cellSensor:value(widget.config.cellCount)
    end
end

local function wakeup(widget)
    local now = os.clock()
    if not widget.currentVoltage then
        widget.currentVoltage = widget.config.startVoltage
    end
    if not widget.voltageSensor then
            local candidate = system.getSource({
                category = CATEGORY_TELEMETRY_SENSOR,
                name = "Voltage"
            })
            if candidate then
                    widget.voltageSensor = candidate
                    print("found voltage sensor: " .. candidate:name())
            end
        if not widget.voltageSensor then
            print("no voltage sensor found, creating one")
            widget.voltageSensor = model.createSensor()
            widget.voltageSensor:name("Voltage")
            widget.voltageSensor:unit(UNIT_VOLT)
            widget.voltageSensor:decimals(2)
            widget.voltageSensor:protocolUnit(UNIT_VOLT)
            widget.voltageSensor:protocolDecimals(2)
        end
    end

    if widget.voltageActive then
        -- print("voltage active, checking to see if update is required")
        local needsUpdate = false
        if widget.lastVoltageUpdate then
            -- print("checking to see if " .. (now - widget.lastVoltageUpdate) .. " >= " .. widget.config.voltageRateTime)
            if (now - widget.lastVoltageUpdate) >= widget.config.voltageRateTime then
                needsUpdate = true
            end
        else
            print("voltage update time not found, setting to now: " .. now)
            widget.lastVoltageUpdate = now
        end
        if needsUpdate then
            widget.lastVoltageUpdate = now
            local newVoltage = widget.currentVoltage - widget.config.voltageRate
            if newVoltage < 0 then
                newVoltage = 0
            end
            print("updating voltage to: " .. newVoltage)
            widget.currentVoltage = newVoltage
            widget.voltageSensor:value(newVoltage)
        end
    end

    if widget.cellCountSensorActive then
        setCellCount(widget)
    end
end

-- This function is called when the user first selects the widget from the widget list, or when they select "configure widget"
local function configure(widget)
end

local function paint(widget)
end

local function init()

    system.registerWidget({
        key = "fkvolt",
        name = "Fake Voltage",
        create = create,
        build = build,
        wakeup = wakeup,
        paint = paint,
        configure = configure
    })
end

return {
    init = init
}
