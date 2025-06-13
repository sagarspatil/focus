-- FocusSession.spoon
-- A Hammerspoon Spoon for focused work sessions with escalating nudges

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "FocusSession"
obj.version = "1.0"
obj.author = "Sagar"
obj.homepage = "https://github.com/sagar/focus-session"
obj.license = "MIT"

-- Configuration
obj.config = {
    hotkeys = {
        start = {{"option", "cmd"}, "t"},
        abort = {{"option", "cmd", "ctrl"}, "q"}
    },
    colors = {
        overlay_bg = {red = 0, green = 0, blue = 0, alpha = 0.8},
        overlay_text = {red = 1, green = 1, blue = 1, alpha = 1},
        flash_color = {red = 1, green = 0, blue = 0, alpha = 0.5}
    },
    csv_path = os.getenv("HOME") .. "/FocusSessions.csv",
    flash_intervals = {
        initial = 300,  -- 5 minutes
        extension = 180, -- 3 minutes
        grace = 60      -- 1 minute
    }
}

-- State
obj.sessionController = nil
obj.uiOverlay = nil
obj.timerEngine = nil
obj.promptDialog = nil
obj.systemActions = nil
obj.logger = nil
obj.hotkeyBinder = nil

function obj:init()
    -- Get the spoon path for proper module loading
    local spoonPath = hs.spoons.scriptPath()
    package.path = package.path .. ";" .. spoonPath .. "/?.lua"
    
    -- Initialize all modules
    self.sessionController = dofile(spoonPath .. "/SessionController.lua")
    self.uiOverlay = dofile(spoonPath .. "/UIOverlay.lua")
    self.timerEngine = dofile(spoonPath .. "/TimerEngine.lua")
    self.promptDialog = dofile(spoonPath .. "/PromptDialog.lua")
    self.systemActions = dofile(spoonPath .. "/SystemActions.lua")
    self.logger = dofile(spoonPath .. "/Logger.lua")
    self.hotkeyBinder = dofile(spoonPath .. "/HotkeyBinder.lua")
    
    -- Initialize modules with config
    self.sessionController:init(self.config)
    self.uiOverlay:init(self.config)
    self.timerEngine:init(self.config)
    self.promptDialog:init(self.config)
    self.systemActions:init(self.config)
    self.logger:init(self.config)
    self.hotkeyBinder:init(self.config)
    
    -- Wire up dependencies
    self.sessionController:setDependencies(
        self.timerEngine,
        self.uiOverlay,
        self.promptDialog,
        self.systemActions,
        self.logger
    )
    
    self.hotkeyBinder:setSessionController(self.sessionController)
    
    return self
end

function obj:start()
    self.hotkeyBinder:bindHotkeys()
    hs.notify.new({title="FocusSession", informativeText="Ready! Press ⌥⌘T to start a session"}):send()
    return self
end

function obj:stop()
    if self.hotkeyBinder then
        self.hotkeyBinder:unbindHotkeys()
    end
    if self.sessionController then
        self.sessionController:abort()
    end
    return self
end

return obj
