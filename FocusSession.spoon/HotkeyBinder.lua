-- HotkeyBinder.lua
-- Global hotkey management for focus sessions

local obj = {}
obj.__index = obj

function obj:init(config)
    self.config = config
    self.sessionController = nil
    self.hotkeys = {}
    
    return self
end

function obj:setSessionController(sessionController)
    self.sessionController = sessionController
end

function obj:bindHotkeys()
    self:unbindHotkeys() -- Clear any existing bindings
    
    -- Start session hotkey (⌥⌘T by default)
    local startKey = self.config.hotkeys.start
    self.hotkeys.start = hs.hotkey.bind(startKey[1], startKey[2], function()
        self:onStartHotkey()
    end)
    
    -- Abort session hotkey (⌥⌘⌃Q by default)
    local abortKey = self.config.hotkeys.abort
    self.hotkeys.abort = hs.hotkey.bind(abortKey[1], abortKey[2], function()
        self:onAbortHotkey()
    end)
    
    -- Quick session presets
    self.hotkeys.quick25 = hs.hotkey.bind({"option", "cmd"}, "1", function()
        self:quickSession(25)
    end)
    
    self.hotkeys.quick30 = hs.hotkey.bind({"option", "cmd"}, "2", function()
        self:quickSession(30)
    end)
    
    self.hotkeys.quick45 = hs.hotkey.bind({"option", "cmd"}, "3", function()
        self:quickSession(45)
    end)
    
    -- Status hotkey
    self.hotkeys.status = hs.hotkey.bind({"option", "cmd"}, "s", function()
        self:showStatus()
    end)
    
    hs.printf("FocusSession hotkeys bound:")
    hs.printf("  Start session: ⌥⌘T")
    hs.printf("  Abort session: ⌥⌘⌃Q")
    hs.printf("  Quick 25min: ⌥⌘1")
    hs.printf("  Quick 30min: ⌥⌘2") 
    hs.printf("  Quick 45min: ⌥⌘3")
    hs.printf("  Show status: ⌥⌘S")
end

function obj:unbindHotkeys()
    for name, hotkey in pairs(self.hotkeys) do
        if hotkey then
            hotkey:delete()
        end
    end
    self.hotkeys = {}
end

function obj:onStartHotkey()
    if not self.sessionController then
        hs.notify.new({title="Error", informativeText="SessionController not available"}):send()
        return
    end
    
    local status = self.sessionController:getStatus()
    
    if status.state ~= "idle" then
        hs.notify.new({
            title="Session Active", 
            informativeText=string.format("Current: %s (%s)", status.session.task, status.state)
        }):send()
        return
    end
    
    -- Start a session with user input
    self.sessionController:start()
end

function obj:onAbortHotkey()
    if not self.sessionController then
        return
    end
    
    local status = self.sessionController:getStatus()
    
    if status.state == "idle" then
        hs.notify.new({title="No Session", informativeText="No active session to abort"}):send()
        return
    end
    
    -- Confirm abort
    local script = [[
        display dialog "Are you sure you want to abort the current focus session?" with title "Confirm Abort" buttons {"Cancel", "Abort Session"} default button 1
        return button returned of result
    ]]
    
    local success, result = hs.osascript.applescript(script)
    
    if success and result == "Abort Session" then
        self.sessionController:abort()
        hs.notify.new({title="Session Aborted", informativeText="Focus session was aborted"}):send()
    end
end

function obj:quickSession(minutes)
    if not self.sessionController then
        return
    end
    
    local status = self.sessionController:getStatus()
    
    if status.state ~= "idle" then
        hs.notify.new({
            title="Session Active",
            informativeText="Cannot start - session already running"
        }):send()
        return
    end
    
    -- Quick task name input
    local script = string.format([[
        display dialog "Quick %d-minute session - what are you working on?" default answer "" with title "Quick Focus Session" buttons {"Cancel", "Start"} default button 2
        return text returned of result
    ]], minutes)
    
    local success, taskName = hs.osascript.applescript(script)
    
    if success and taskName ~= "" then
        self.sessionController:start(taskName, minutes)
    end
end

function obj:showStatus()
    if not self.sessionController then
        hs.notify.new({title="Error", informativeText="SessionController not available"}):send()
        return
    end
    
    local status = self.sessionController:getStatus()
    
    if status.state == "idle" then
        hs.notify.new({
            title="Focus Session Status",
            informativeText="No active session. Press ⌥⌘T to start."
        }):send()
    else
        local session = status.session
        local elapsed = math.floor((os.time() - session.startTime) / 60)
        
        hs.notify.new({
            title="Focus Session Status",
            informativeText=string.format("Task: %s\nState: %s\nElapsed: %d min", 
                session.task, status.state, elapsed)
        }):send()
    end
end

function obj:pauseSession()
    -- Emergency pause functionality
    if self.sessionController then
        local timerEngine = self.sessionController.timerEngine
        if timerEngine then
            timerEngine:pause()
            hs.notify.new({title="Session Paused", informativeText="Timer paused - resume by unlocking screen"}):send()
        end
    end
end

function obj:resumeSession()
    -- Resume functionality
    if self.sessionController then
        local timerEngine = self.sessionController.timerEngine
        if timerEngine and timerEngine:isPaused() then
            timerEngine:resume()
            hs.notify.new({title="Session Resumed", informativeText="Timer resumed"}):send()
        end
    end
end

-- Additional utility hotkeys (optional, can be enabled via config)
function obj:bindUtilityHotkeys()
    -- These are more advanced hotkeys that can be optionally enabled
    
    -- Force complete session
    self.hotkeys.forceComplete = hs.hotkey.bind({"option", "cmd", "shift"}, "f", function()
        if self.sessionController then
            self.sessionController:finish("forced_complete")
        end
    end)
    
    -- Emergency system unlock (if screen lock fails)
    self.hotkeys.emergencyUnlock = hs.hotkey.bind({"option", "cmd", "shift"}, "u", function()
        local systemActions = require("SystemActions"):init(self.config)
        systemActions:emergencyAbort()
    end)
    
    -- Show session statistics
    self.hotkeys.showStats = hs.hotkey.bind({"option", "cmd"}, "i", function()
        self:showSessionStats()
    end)
end

function obj:showSessionStats()
    local logger = require("Logger"):init(self.config)
    local stats = logger:getSessionStats(7) -- Last 7 days
    
    local message = string.format([[Sessions (last 7 days):
Total: %d
Completed: %d (%.1f%%)
Avg. time: %.1f min
Total time: %.1f hours]],
        stats.totalSessions,
        stats.completedSessions,
        stats.completionRate,
        stats.averageActualMinutes,
        stats.totalActualMinutes / 60
    )
    
    hs.notify.new({
        title="Session Statistics",
        informativeText=message,
        autoWithdraw = false
    }):send()
end

function obj:getHotkeyList()
    -- Return list of all bound hotkeys for help/reference
    return {
        {"⌥⌘T", "Start new focus session"},
        {"⌥⌘⌃Q", "Abort current session"},
        {"⌥⌘1", "Quick 25-minute session"},
        {"⌥⌘2", "Quick 30-minute session"},
        {"⌥⌘3", "Quick 45-minute session"},
        {"⌥⌘S", "Show session status"},
        {"⌥⌘I", "Show session statistics (if enabled)"}
    }
end

return obj
