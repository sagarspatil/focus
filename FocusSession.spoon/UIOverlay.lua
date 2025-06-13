-- UIOverlay.lua
-- Floating overlay that displays task name and countdown timer

local obj = {}
obj.__index = obj

function obj:init(config)
    self.config = config
    self.canvas = nil
    self.flashCanvas = nil
    self.isVisible = false
    self.currentStyle = "normal"
    
    return self
end

function obj:show(taskName, remainingSeconds)
    if self.canvas then
        self.canvas:delete()
    end
    
    -- Get primary screen dimensions
    local screen = hs.screen.primaryScreen()
    local screenFrame = screen:frame()
    
    -- Create overlay canvas (top-right corner)
    local width = 300
    local height = 80
    local x = screenFrame.x + screenFrame.w - width - 20
    local y = screenFrame.y + 20
    
    self.canvas = hs.canvas.new({x = x, y = y, w = width, h = height})
    
    -- Background rectangle
    self.canvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = self.config.colors.overlay_bg,
        roundedRectRadii = {xRadius = 8, yRadius = 8}
    }
    
    -- Task name text
    self.canvas[2] = {
        type = "text",
        text = taskName,
        textFont = "Helvetica-Bold",
        textSize = 16,
        textColor = self.config.colors.overlay_text,
        textAlignment = "center",
        frame = {x = 10, y = 10, w = width - 20, h = 25}
    }
    
    -- Countdown text
    local timeText = self:formatTime(remainingSeconds)
    self.canvas[3] = {
        type = "text", 
        text = timeText,
        textFont = "Helvetica",
        textSize = 24,
        textColor = self.config.colors.overlay_text,
        textAlignment = "center",
        frame = {x = 10, y = 35, w = width - 20, h = 35}
    }
    
    -- Make it stay on top and show
    self.canvas:level(hs.canvas.windowLevels.overlay)
    self.canvas:show()
    self.isVisible = true
end

function obj:updateCountdown(remainingSeconds)
    if not self.canvas or not self.isVisible then
        return
    end
    
    local timeText = self:formatTime(remainingSeconds)
    self.canvas[3].text = timeText
end

function obj:updateStyle(phase)
    self.currentStyle = phase
    
    if not self.canvas or not self.isVisible then
        return
    end
    
    local colors = self.config.colors
    if phase == "extension" then
        self.canvas[1].fillColor = {red = 0.8, green = 0.6, blue = 0, alpha = 0.8} -- Orange
    elseif phase == "grace" then
        self.canvas[1].fillColor = {red = 0.8, green = 0.2, blue = 0, alpha = 0.8} -- Red-orange
    else
        self.canvas[1].fillColor = colors.overlay_bg -- Default
    end
end

function obj:pulse()
    if not self.canvas or not self.isVisible then
        return
    end
    
    -- Quick opacity pulse
    local originalOpacity = self.canvas[1].fillColor.alpha
    self.canvas[1].fillColor.alpha = 0.3
    
    hs.timer.doAfter(0.2, function()
        if self.canvas then
            self.canvas[1].fillColor.alpha = originalOpacity
        end
    end)
end

function obj:redFlash()
    -- Create full-screen red flash
    if self.flashCanvas then
        self.flashCanvas:delete()
    end
    
    local screen = hs.screen.primaryScreen()
    local screenFrame = screen:frame()
    
    self.flashCanvas = hs.canvas.new(screenFrame)
    
    self.flashCanvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = self.config.colors.flash_color
    }
    
    self.flashCanvas:level(hs.canvas.windowLevels.overlay + 1)
    self.flashCanvas:show()
    
    -- Hide after 1 second
    hs.timer.doAfter(1, function()
        if self.flashCanvas then
            self.flashCanvas:delete()
            self.flashCanvas = nil
        end
    end)
end

function obj:hide()
    if self.canvas then
        self.canvas:delete()
        self.canvas = nil
    end
    
    if self.flashCanvas then
        self.flashCanvas:delete()
        self.flashCanvas = nil
    end
    
    self.isVisible = false
end

function obj:formatTime(seconds)
    if seconds <= 0 then
        return "00:00"
    end
    
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    
    return string.format("%02d:%02d", minutes, secs)
end

function obj:isShowing()
    return self.isVisible
end

return obj
