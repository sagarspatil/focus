-- SessionController.lua
-- Main state machine for focus sessions

local obj = {}
obj.__index = obj

-- Session states
obj.STATES = {
    IDLE = "idle",
    ACTIVE = "active",
    EXTENSION = "extension", 
    GRACE = "grace",
    ESCALATE = "escalate",
    ENDING = "ending"
}

function obj:init(config)
    self.config = config
    self.state = self.STATES.IDLE
    self.currentSession = nil
    self.dependencies = {}
    
    return self
end

function obj:setDependencies(timerEngine, uiOverlay, promptDialog, systemActions, logger)
    self.timerEngine = timerEngine
    self.uiOverlay = uiOverlay
    self.promptDialog = promptDialog
    self.systemActions = systemActions
    self.logger = logger
    
    -- Set up callbacks
    self.timerEngine:setCallbacks({
        onCountdownTick = function(remaining) self:onCountdownTick(remaining) end,
        onPhaseComplete = function() self:onPhaseComplete() end,
        onFlashTrigger = function() self:onFlashTrigger() end
    })
    
    self.promptDialog:setCallback(function(response) self:onPromptResponse(response) end)
end

function obj:start(taskName, plannedMinutes)
    if self.state ~= self.STATES.IDLE then
        hs.notify.new({title="FocusSession", informativeText="Session already active"}):send()
        return
    end
    
    -- Get task name and minutes from user if not provided
    if not taskName or not plannedMinutes then
        local result = self.promptDialog:enhancedTaskInput()
        if not result then
            return -- User cancelled
        end
        taskName = result.task
        plannedMinutes = result.minutes
    end
    
    -- Initialize session
    self.currentSession = {
        task = taskName,
        plannedMinutes = plannedMinutes,
        startTime = os.time(),
        currentPhase = "initial",
        totalMinutes = 0
    }
    
    self.state = self.STATES.ACTIVE
    
    -- Start UI and timers
    self.uiOverlay:show(taskName, plannedMinutes * 60)
    self.timerEngine:startPhase("initial", plannedMinutes * 60)
    
    hs.notify.new({
        title="FocusSession Started", 
        informativeText=string.format("Task: %s (%d min)", taskName, plannedMinutes)
    }):send()
end

function obj:onCountdownTick(remainingSeconds)
    if self.state == self.STATES.IDLE then
        return
    end
    
    self.uiOverlay:updateCountdown(remainingSeconds)
    
    -- Check if we need to pause (screen locked)
    if self.systemActions:isScreenLocked() then
        self.timerEngine:pause()
        self.uiOverlay:hide()
    elseif self.timerEngine:isPaused() then
        self.timerEngine:resume()
        self.uiOverlay:show(self.currentSession.task, remainingSeconds)
    end
end

function obj:onPhaseComplete()
    if self.state == self.STATES.ACTIVE then
        -- Initial 30 minutes complete
        self:promptForCompletion()
    elseif self.state == self.STATES.EXTENSION then  
        -- Extension 15 minutes complete
        self.state = self.STATES.GRACE
        self.timerEngine:startPhase("grace", 10 * 60) -- 10 minute grace
        self.uiOverlay:updateStyle("grace")
    elseif self.state == self.STATES.GRACE then
        -- Grace period complete - start escalation
        self.state = self.STATES.ESCALATE
        self:promptForCompletion(true) -- Final prompt
    end
end

function obj:onFlashTrigger()
    if self.state == self.STATES.ESCALATE then
        self.uiOverlay:redFlash()
    else
        self.uiOverlay:pulse()
    end
end

function obj:promptForCompletion(isFinal)
    local buttons = isFinal and {"Finished", "Not Finished"} or {"Finished", "+15 min"}
    self.promptDialog:show("Focus Session", "Are you finished with your task?", buttons)
end

function obj:onPromptResponse(response)
    if response == "Finished" then
        self:finish("completed")
    elseif response == "+15 min" then
        self:extendSession()
    elseif response == "Not Finished" then
        self:finish("interrupted")
        self.systemActions:lockScreen()
    end
end

function obj:extendSession()
    self.state = self.STATES.EXTENSION
    self.currentSession.currentPhase = "extension"
    self.timerEngine:startPhase("extension", 15 * 60) -- 15 minutes
    self.uiOverlay:updateStyle("extension")
    
    hs.notify.new({title="FocusSession", informativeText="Extended for 15 minutes"}):send()
end

function obj:finish(outcome)
    if self.state == self.STATES.IDLE then
        return
    end
    
    self.state = self.STATES.ENDING
    
    -- Calculate actual time
    local endTime = os.time()
    local actualMinutes = math.floor((endTime - self.currentSession.startTime) / 60)
    
    -- Log session
    self.logger:logSession({
        startTime = self.currentSession.startTime,
        endTime = endTime,
        task = self.currentSession.task,
        plannedMinutes = self.currentSession.plannedMinutes,
        actualMinutes = actualMinutes,
        outcome = outcome
    })
    
    -- Clean up
    self.timerEngine:stop()
    self.uiOverlay:hide()
    
    -- Notify completion
    hs.notify.new({
        title="FocusSession Complete",
        informativeText=string.format("%s after %d minutes", outcome, actualMinutes)
    }):send()
    
    -- Reset state
    self.state = self.STATES.IDLE
    self.currentSession = nil
end

function obj:abort()
    if self.state ~= self.STATES.IDLE then
        self:finish("aborted")
    end
end

function obj:getStatus()
    return {
        state = self.state,
        session = self.currentSession
    }
end

return obj
