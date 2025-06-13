-- SystemActions.lua
-- System-level actions like screen lock, focus mode, etc.

local obj = {}
obj.__index = obj

function obj:init(config)
    self.config = config
    
    return self
end

function obj:lockScreen()
    -- Primary method: pmset displaysleepnow
    local success = self:runCommand("pmset displaysleepnow")
    
    if not success then
        -- Fallback: open screensaver
        self:runCommand("open /System/Library/CoreServices/ScreenSaverEngine.app")
    end
end

function obj:isScreenLocked()
    -- Check if screen is locked by trying to get current app info
    -- This is a heuristic - if we can't get the current app, screen might be locked
    local currentApp = hs.application.frontmostApplication()
    
    if not currentApp then
        return true
    end
    
    -- Additional check: see if loginwindow is frontmost (indicates lock screen)
    local appName = currentApp:name()
    return appName == "loginwindow" or appName == "ScreenSaverEngine"
end

function obj:enableFocusMode()
    -- Enable Do Not Disturb mode
    -- Note: This requires macOS 12+ and proper permissions
    local script = [[
        tell application "System Events"
            tell process "Control Center"
                -- This is complex and may not work reliably
                -- Better to use shortcuts or manual setup
            end tell
        end tell
    ]]
    
    -- For now, just show a notification suggesting manual setup
    hs.notify.new({
        title = "Focus Mode",
        informativeText = "Consider enabling Do Not Disturb manually for better focus",
        autoWithdraw = false
    }):send()
end

function obj:disableFocusMode()
    -- Disable Do Not Disturb mode
    hs.notify.new({
        title = "Focus Mode",
        informativeText = "You can now disable Do Not Disturb manually",
        autoWithdraw = false
    }):send()
end

function obj:playSound(soundName)
    -- Play system sound
    local sounds = {
        alert = "Ping",
        complete = "Glass",
        warning = "Sosumi"
    }
    
    local systemSound = sounds[soundName] or soundName or "Ping"
    hs.sound.getByName(systemSound):play()
end

function obj:showAlert(title, message, level)
    -- Show system alert with different urgency levels
    local alertLevels = {
        info = "informational",
        warning = "warning", 
        critical = "critical"
    }
    
    local alertLevel = alertLevels[level] or "informational"
    
    local notification = hs.notify.new({
        title = title,
        informativeText = message,
        hasActionButton = false,
        autoWithdraw = level ~= "critical"
    })
    
    if level == "critical" then
        notification:scheduleNotification()
        self:playSound("alert")
    else
        notification:send()
    end
    
    return notification
end

function obj:runCommand(command)
    local output, status, _, rc = hs.execute(command)
    
    if rc == 0 then
        return true, output
    else
        hs.printf("Command failed: %s (exit code: %d)", command, rc)
        return false, output
    end
end

function obj:checkAccessibilityPermissions()
    -- Check if Hammerspoon has accessibility permissions
    return hs.accessibilityState()
end

function obj:promptForAccessibilityPermissions()
    if not self:checkAccessibilityPermissions() then
        local script = [[
            display alert "Accessibility Permission Required" message "FocusSession needs Accessibility permission to work properly. Click OK to open System Preferences." buttons {"Cancel", "OK"} default button 2
            return button returned of result
        ]]
        
        local success, result = hs.osascript.applescript(script)
        
        if success and result == "OK" then
            hs.urlevent.openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        end
        
        return false
    end
    
    return true
end

function obj:getBatteryLevel()
    -- Get current battery level (useful for power management warnings)
    local battery = hs.battery.percentage()
    return battery
end

function obj:isOnPower()
    -- Check if Mac is plugged into power
    return hs.battery.isCharged() or hs.battery.isCharging()
end

function obj:preventSleep()
    -- Prevent system sleep during focus sessions
    hs.caffeinate.set("displayIdle", true)
    hs.caffeinate.set("systemIdle", true)
end

function obj:allowSleep()
    -- Re-enable system sleep
    hs.caffeinate.set("displayIdle", false)
    hs.caffeinate.set("systemIdle", false)
end

function obj:getSystemInfo()
    -- Return useful system information
    return {
        batteryLevel = self:getBatteryLevel(),
        onPower = self:isOnPower(),
        accessibilityEnabled = self:checkAccessibilityPermissions(),
        screenLocked = self:isScreenLocked()
    }
end

-- Emergency abort function
function obj:emergencyAbort()
    -- Stop all focus session activities immediately
    self:allowSleep()
    self:disableFocusMode()
    
    hs.notify.new({
        title = "FocusSession Emergency Stop",
        informativeText = "All focus session activities have been stopped",
        autoWithdraw = false
    }):send()
end

return obj
