-- TimerEngine.lua
-- Manages all timers for countdown and flash notifications

local obj = {}
obj.__index = obj

function obj:init(config)
    self.config = config
    self.countdownTimer = nil
    self.flashTimer = nil
    self.callbacks = {}
    self.isPausedState = false
    self.remainingSeconds = 0
    self.currentPhase = nil
    self.flashInterval = 0
    
    return self
end

function obj:setCallbacks(callbacks)
    self.callbacks = callbacks
end

function obj:startPhase(phase, durationSeconds)
    self:stop() -- Clean up any existing timers
    
    self.currentPhase = phase
    self.remainingSeconds = durationSeconds
    self.isPausedState = false
    
    -- Set flash interval based on phase
    if phase == "initial" then
        self.flashInterval = self.config.flash_intervals.initial
    elseif phase == "extension" then
        self.flashInterval = self.config.flash_intervals.extension
    elseif phase == "grace" then
        self.flashInterval = self.config.flash_intervals.grace
    end
    
    -- Start countdown timer (every second)
    self.countdownTimer = hs.timer.doEvery(1, function()
        self:onCountdownTick()
    end)
    
    -- Start flash timer if we have an interval
    if self.flashInterval > 0 then
        self.flashTimer = hs.timer.doEvery(self.flashInterval, function()
            self:onFlashTick()
        end)
    end
    
    -- Initial callback
    if self.callbacks.onCountdownTick then
        self.callbacks.onCountdownTick(self.remainingSeconds)
    end
end

function obj:onCountdownTick()
    if self.isPausedState then
        return
    end
    
    self.remainingSeconds = self.remainingSeconds - 1
    
    -- Notify callback
    if self.callbacks.onCountdownTick then
        self.callbacks.onCountdownTick(self.remainingSeconds)
    end
    
    -- Check if time is up
    if self.remainingSeconds <= 0 then
        self:stop()
        if self.callbacks.onPhaseComplete then
            self.callbacks.onPhaseComplete()
        end
    end
end

function obj:onFlashTick()
    if self.isPausedState then
        return
    end
    
    if self.callbacks.onFlashTrigger then
        self.callbacks.onFlashTrigger()
    end
end

function obj:pause()
    if self.isPausedState then
        return
    end
    
    self.isPausedState = true
    
    if self.countdownTimer then
        self.countdownTimer:stop()
    end
    
    if self.flashTimer then
        self.flashTimer:stop()
    end
end

function obj:resume()
    if not self.isPausedState then
        return
    end
    
    self.isPausedState = false
    
    -- Restart timers
    if self.remainingSeconds > 0 then
        self.countdownTimer = hs.timer.doEvery(1, function()
            self:onCountdownTick()
        end)
        
        if self.flashInterval > 0 then
            self.flashTimer = hs.timer.doEvery(self.flashInterval, function()
                self:onFlashTick()
            end)
        end
    end
end

function obj:stop()
    if self.countdownTimer then
        self.countdownTimer:stop()
        self.countdownTimer = nil
    end
    
    if self.flashTimer then
        self.flashTimer:stop()
        self.flashTimer = nil
    end
    
    self.isPausedState = false
    self.remainingSeconds = 0
    self.currentPhase = nil
end

function obj:isPaused()
    return self.isPausedState
end

function obj:getRemainingSeconds()
    return self.remainingSeconds
end

function obj:getCurrentPhase()
    return self.currentPhase
end

function obj:addTime(seconds)
    self.remainingSeconds = self.remainingSeconds + seconds
    
    if self.callbacks.onCountdownTick then
        self.callbacks.onCountdownTick(self.remainingSeconds)
    end
end

function obj:getStatus()
    return {
        phase = self.currentPhase,
        remaining = self.remainingSeconds,
        paused = self.isPausedState,
        flashInterval = self.flashInterval
    }
end

return obj
