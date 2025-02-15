local function create()
    local widget = {
        consumptionSensor = nil,
        consumptionActive = false,
        currentConsumption = nil,
        lastConsumptionUpdate = nil,
        config = {
            startConsumption = 0,
            maxConsumption = 6000,
            consumptionRate = 5, -- 5 mAh per ...
            consumptionRateTime = 1 -- every N seconds (not guaranteed)
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
            if not widget.currentConsumption then
                widget.currentConsumption = widget.config.startConsumption
            end
            widget.consumptionActive = true
            print("starting consumption")
        end
    })
    line = form.addLine("b", nil, false)
    form.addButton(line, nil, {
        text = "Stop",
        press = function()
            widget.lastConsumptionUpdate = nil
            widget.consumptionActive = false
            print("stopping consumption")
        end
    })
    line = form.addLine("c", nil, false)
    form.addButton(line, nil, {
        text = "Reset",
        press = function()
            widget.currentConsumption = widget.config.startConsumption
            widget.consumptionSensor:value(widget.currentConsumption)
            widget.lastConsumptionUpdate = nil
            print("resetting consumption")
        end
    })
end

local function wakeup(widget)
    local now = os.clock()
    if not widget.consumptionSensor then
        for member = 0, 50 do
            local candidate = system.getSource({
                category = CATEGORY_TELEMETRY_SENSOR,
                member = member
            })
            if candidate then
                if candidate:unit() == UNIT_MILLIAMPERE_HOUR then
                    widget.consumptionSensor = candidate
                    print("found consumption sensor: " .. candidate:name())
                    break -- Exit the loop once a valid mAh sensor is found
                end
            end
        end
        if not widget.consumptionSensor then
            print("no consumption sensor found, creating one")
            widget.consumptionSensor = model.createSensor()
            widget.consumptionSensor:name("Fake Consumption")
            widget.consumptionSensor:unit(UNIT_MILLIAMPERE_HOUR)
            widget.consumptionSensor:decimals(0)
        end
    end

    if widget.consumptionActive then
        -- print("consumption active, checking to see if update is required")
        local needsUpdate = false
        if widget.lastConsumptionUpdate then
            -- print("checking to see if " .. (now - widget.lastConsumptionUpdate) .. " >= " .. widget.config.consumptionRateTime)
            if (now - widget.lastConsumptionUpdate) >= widget.config.consumptionRateTime then
                needsUpdate = true
            end
        else
            print("consumption update time not found, setting to now: " .. now)
            widget.lastConsumptionUpdate = now
        end
        if needsUpdate then
            widget.lastConsumptionUpdate = now
            local newConsumption = widget.currentConsumption + widget.config.consumptionRate
            if newConsumption > widget.config.maxConsumption then
                newConsumption = widget.config.maxConsumption
            end
            print("updating consumption to: " .. newConsumption)
            widget.currentConsumption = newConsumption
            widget.consumptionSensor:value(newConsumption)
            
        end
    end
end

-- This function is called when the user first selects the widget from the widget list, or when they select "configure widget"
local function configure(widget)
end

local function paint(widget)
end

local function init()

    system.registerWidget({
        key = "fkconsm",
        name = "Fake Consumption",
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
