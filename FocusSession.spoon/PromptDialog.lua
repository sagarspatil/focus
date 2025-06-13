-- PromptDialog.lua
-- Modal dialogs for user input and confirmation

local obj = {}
obj.__index = obj

function obj:init(config)
    self.config = config
    self.callback = nil
    
    return self
end

function obj:setCallback(callback)
    self.callback = callback
end

function obj:show(title, message, buttons)
    if not buttons then
        buttons = {"OK", "Cancel"}
    end
    
    hs.dialog.choiceCallback = function(response)
        if self.callback then
            self.callback(response)
        end
    end
    
    hs.dialog.choice(message, buttons, title)
end

function obj:getTaskInput()
    -- First get task name
    local taskResult = hs.dialog.textPrompt("Start Focus Session", "What task are you working on?", "", "Start", "Cancel")
    
    if not taskResult or taskResult == "" then
        return nil
    end
    
    -- Then get duration
    local minutesResult = hs.dialog.choiceFromList(
        "How long do you plan to work?",
        {"25", "30", "45", "60", "90"},
        "Select duration (minutes)",
        "30"
    )
    
    if not minutesResult then
        return nil
    end
    
    return {
        task = taskResult,
        minutes = tonumber(minutesResult[1])
    }
end

function obj:confirm(title, message, callback)
    local function onResponse(response)
        if callback then
            callback(response == "Yes")
        end
    end
    
    hs.dialog.choiceCallback = onResponse
    hs.dialog.choice(message, {"Yes", "No"}, title)
end

function obj:alert(title, message)
    hs.dialog.alert(title, message, "OK")
end

function obj:notification(title, message, duration)
    local notification = hs.notify.new({
        title = title,
        informativeText = message,
        autoWithdraw = true,
        withdrawAfter = duration or 5
    })
    
    notification:send()
    return notification
end

-- Custom choice dialog that works better with our callback system
function obj:customChoice(title, message, buttons, defaultButton)
    local result = nil
    local finished = false
    
    local alert = hs.dialog.webviewAlert(function(response)
        result = response
        finished = true
    end, message, title, buttons[1], buttons[2])
    
    -- Wait for response (with timeout)
    local timeout = 0
    while not finished and timeout < 300 do -- 30 second timeout
        hs.timer.usleep(100000) -- Sleep 0.1 seconds
        timeout = timeout + 1
    end
    
    return result
end

-- Fallback method using AppleScript for better reliability
function obj:appleScriptChoice(title, message, buttons)
    local buttonList = table.concat(buttons, '", "')
    local script = string.format([[
        display dialog "%s" with title "%s" buttons {"%s"} default button 1
        return button returned of result
    ]], message:gsub('"', '\\"'), title:gsub('"', '\\"'), buttonList)
    
    local success, result = hs.osascript.applescript(script)
    
    if success then
        return result
    else
        return nil
    end
end

-- Enhanced task input using AppleScript for better UX
function obj:enhancedTaskInput()
    -- Get task name
    local taskScript = [[
        display dialog "What task are you working on?" default answer "" with title "Start Focus Session" buttons {"Cancel", "Continue"} default button 2
        return text returned of result
    ]]
    
    local taskSuccess, taskName = hs.osascript.applescript(taskScript)
    if not taskSuccess or taskName == "" then
        return nil
    end
    
    -- Get duration
    local durationScript = [[
        choose from list {"25", "30", "45", "60", "90"} with title "Focus Session Duration" with prompt "How many minutes do you plan to work?" default items {"30"}
        return result as string
    ]]
    
    local durationSuccess, duration = hs.osascript.applescript(durationScript)
    if not durationSuccess or duration == "false" then
        return nil
    end
    
    return {
        task = taskName,
        minutes = tonumber(duration)
    }
end

return obj
