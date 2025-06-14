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
    self.isPaused = false
    
    return self
end

function obj:show(taskName, remainingSeconds)
    if self.canvas then
        self.canvas:delete()
    end
    
    -- Get primary screen dimensions
    local screen = hs.screen.primaryScreen()
    local screenFrame = screen:frame()
    
    -- Container dimensions - more compact and professional
    local containerHeight = 44
    local containerWidth = 340
    local x = screenFrame.x + (screenFrame.w - containerWidth) / 2
    local y = screenFrame.y + 40  -- Closer to top
    
    self.canvas = hs.canvas.new({x = x, y = y, w = containerWidth, h = containerHeight})
    self.canvasPosition = {x = x, y = y}  -- Store for dragging
    
    -- Main container - semi-transparent gray background (static)
    self.canvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = {red = 0.25, green = 0.25, blue = 0.27, alpha = 0.8},
        roundedRectRadii = {xRadius = containerHeight/2, yRadius = containerHeight/2},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "background"
    }
    
    -- Timer badge - darker background
    local timerBadgeX = 16
    local timerBadgeY = 10
    local timerBadgeHeight = 24
    local timerBadgeWidth = 65
    
    self.canvas[2] = {
        type = "rectangle",
        action = "fill",
        fillColor = {red = 0.18, green = 0.18, blue = 0.2, alpha = 1},
        roundedRectRadii = {xRadius = 6, yRadius = 6},
        frame = {x = timerBadgeX, y = timerBadgeY, w = timerBadgeWidth, h = timerBadgeHeight}
    }
    
    -- Timer text - white
    local timeText = self:formatTime(remainingSeconds)
    self.canvas[3] = {
        type = "text", 
        text = timeText,
        textFont = "SF Pro Text Medium",
        textSize = 15,
        textColor = {red = 0.9, green = 0.9, blue = 0.92, alpha = 1},
        textAlignment = "center",
        frame = {x = timerBadgeX, y = timerBadgeY + 3, w = timerBadgeWidth, h = timerBadgeHeight - 6}
    }
    
    -- Calculate available width for task name
    -- Container width - timer badge - margins - space for buttons
    local taskNameX = timerBadgeX + timerBadgeWidth + 16
    local buttonsSpace = 70  -- Very tight: pause(20) + cancel(20) + reorder(20) + minimal gaps
    local rightMargin = 10
    local availableWidth = containerWidth - taskNameX - buttonsSpace - rightMargin
    
    -- Task title - truncated with ellipsis if too long
    local truncatedTaskName = taskName
    local maxChars = 18  -- Adjusted for tighter layout
    if string.len(taskName) > maxChars then
        truncatedTaskName = string.sub(taskName, 1, maxChars) .. "..."
    end
    
    self.canvas[4] = {
        type = "text",
        text = truncatedTaskName,
        textFont = "SF Pro Text",
        textSize = 17,
        textColor = {red = 0.95, green = 0.95, blue = 0.97, alpha = 1},
        textAlignment = "left",
        frame = {x = taskNameX, y = 11, w = availableWidth, h = 22}
    }
    
    -- Control buttons (icons only)
    self:createControlButtons(containerWidth, containerHeight)
    
    -- Configure canvas behavior
    self.canvas:clickActivating(false)
    self.canvas:canvasMouseEvents(true, true, false, true)
    self.canvas:level(hs.canvas.windowLevels.overlay)
    self.canvas:behaviorAsLabels({"canJoinAllSpaces", "stationary"})
    self.canvas:show()
    self.isVisible = true
    
    -- Enable interactions
    self:enableInteractions()
end

function obj:createControlButtons(width, height)
    local iconSize = 20
    local rightMargin = 12
    local buttonSpacing = 22  -- Very tight spacing between buttons
    
    -- Calculate positions from right (only 3 controls now)
    local reorderX = width - rightMargin - 20
    local abortX = reorderX - buttonSpacing
    local pauseX = abortX - buttonSpacing
    
    local centerY = height / 2
    
    -- Pause button (icon only) - show pause when running, play when paused
    self.canvas[5] = {
        type = "text",
        text = self.isPaused and "►" or "❙❙",  -- Better pause/play symbols
        textFont = "SF Pro Text",
        textSize = 16,
        textColor = {red = 0.7, green = 0.7, blue = 0.72, alpha = 1},
        textAlignment = "center",
        frame = {x = pauseX - iconSize/2, y = centerY - iconSize/2, w = iconSize, h = iconSize},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "pauseBtn"
    }
    
    -- Abort button (X icon)
    self.canvas[6] = {
        type = "text",
        text = "×",  -- Cleaner X symbol
        textFont = "SF Pro Text",
        textSize = 20,
        textColor = {red = 0.7, green = 0.7, blue = 0.72, alpha = 1},
        textAlignment = "center",
        frame = {x = abortX - iconSize/2, y = centerY - iconSize/2, w = iconSize, h = iconSize},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "abortBtn"
    }
    
    -- Reorder handle (6 dots)
    local dotRadius = 1.5
    local dotSpacing = 5
    local gridX = reorderX - 6
    local gridY = centerY - 7.5
    
    for row = 0, 2 do
        for col = 0, 1 do
            local index = 7 + row * 2 + col
            self.canvas[index] = {
                type = "circle",
                action = "fill",
                center = {x = gridX + col * dotSpacing, y = gridY + row * dotSpacing},
                radius = dotRadius,
                fillColor = {red = 0.75, green = 0.75, blue = 0.77, alpha = 1}
            }
        end
    end
    
    -- Invisible drag area for reorder handle
    self.canvas[13] = {
        type = "rectangle",
        action = "fill",
        fillColor = {red = 0, green = 0, blue = 0, alpha = 0.01},
        frame = {x = reorderX - 12, y = centerY - 12, w = 24, h = 24},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "reorderHandle"
    }
end

function obj:enableInteractions()
    local isDragging = false
    local dragOffset = {x = 0, y = 0}
    local dragEventTap = nil
    local mouseUpEventTap = nil
    
    self.canvas:mouseCallback(function(canvas, event, id, x, y)
        if event == "mouseEnter" then
            -- Subtle hover effects
            if id == "pauseBtn" or id == 5 then
                self.canvas[5].textColor = {red = 0.95, green = 0.95, blue = 0.97, alpha = 1}
            elseif id == "abortBtn" or id == 6 then
                self.canvas[6].textColor = {red = 0.95, green = 0.95, blue = 0.97, alpha = 1}
            elseif id == "reorderHandle" or id == 13 then
                -- Make dots brighter on hover
                for i = 7, 12 do
                    if self.canvas[i] then
                        self.canvas[i].fillColor = {red = 0.9, green = 0.9, blue = 0.92, alpha = 1}
                    end
                end
            end
        elseif event == "mouseExit" then
            -- Reset hover effects
            if id == "pauseBtn" or id == 5 then
                self.canvas[5].textColor = {red = 0.7, green = 0.7, blue = 0.72, alpha = 1}
            elseif id == "abortBtn" or id == 6 then
                self.canvas[6].textColor = {red = 0.7, green = 0.7, blue = 0.72, alpha = 1}
            elseif id == "reorderHandle" or id == 13 then
                -- Reset dots
                for i = 7, 12 do
                    if self.canvas[i] then
                        self.canvas[i].fillColor = {red = 0.75, green = 0.75, blue = 0.77, alpha = 1}
                    end
                end
            end
        elseif event == "mouseDown" then
            if id == "pauseBtn" or id == 5 then
                if self.onPauseClick then 
                    self:togglePauseState()
                    self.onPauseClick() 
                end
            elseif id == "abortBtn" or id == 6 then
                if self.onCancelClick then self.onCancelClick() end
            elseif id == "reorderHandle" or id == 13 then
                -- Start dragging
                isDragging = true
                local mousePos = hs.mouse.absolutePosition()
                dragOffset.x = mousePos.x - self.canvasPosition.x
                dragOffset.y = mousePos.y - self.canvasPosition.y
                
                -- Create event tap for drag
                if dragEventTap then dragEventTap:stop() end
                dragEventTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDragged}, function(e)
                    if isDragging then
                        local newMousePos = hs.mouse.absolutePosition()
                        self.canvasPosition.x = newMousePos.x - dragOffset.x
                        self.canvasPosition.y = newMousePos.y - dragOffset.y
                        self.canvas:topLeft({x = self.canvasPosition.x, y = self.canvasPosition.y})
                    end
                    return false
                end):start()
                
                -- Create event tap for mouse up
                if mouseUpEventTap then mouseUpEventTap:stop() end
                mouseUpEventTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function(e)
                    isDragging = false
                    if dragEventTap then
                        dragEventTap:stop()
                        dragEventTap = nil
                    end
                    if mouseUpEventTap then
                        mouseUpEventTap:stop()
                        mouseUpEventTap = nil
                    end
                    return false
                end):start()
            end
        end
    end)
end

function obj:togglePauseState()
    self.isPaused = not self.isPaused
    if self.canvas then
        -- Update pause icon
        if self.canvas[5] then
            self.canvas[5].text = self.isPaused and "►" or "❙❙"
        end
        -- Keep background static - no transparency change
    end
end

function obj:updateCountdown(remainingSeconds)
    if not self.canvas or not self.isVisible then
        return
    end
    
    local timeText = self:formatTime(remainingSeconds)
    if self.canvas[3] then
        self.canvas[3].text = timeText
    end
end

function obj:updateStyle(phase)
    self.currentStyle = phase
    
    if not self.canvas or not self.isVisible then
        return
    end
    
    -- Subtle color changes for different phases
    if phase == "extension" then
        self.canvas[2].fillColor = {red = 0.5, green = 0.3, blue = 0.1, alpha = 1} -- Dark orange
        self.canvas[3].textColor = {red = 1, green = 0.8, blue = 0.6, alpha = 1}
    elseif phase == "grace" then
        self.canvas[2].fillColor = {red = 0.5, green = 0.15, blue = 0.15, alpha = 1} -- Dark red
        self.canvas[3].textColor = {red = 1, green = 0.7, blue = 0.7, alpha = 1}
    else
        self.canvas[2].fillColor = {red = 0.3, green = 0.3, blue = 0.32, alpha = 1} -- Default dark gray
        self.canvas[3].textColor = {red = 0.9, green = 0.9, blue = 0.92, alpha = 1}
    end
end

function obj:pulse()
    if not self.canvas or not self.isVisible then
        return
    end
    
    -- Very subtle pulse - just flash the timer badge slightly
    local originalColor = self.canvas[2].fillColor
    self.canvas[2].fillColor = {red = 0.25, green = 0.25, blue = 0.27, alpha = 1}
    
    hs.timer.doAfter(0.2, function()
        if self.canvas and self.canvas[2] then
            self.canvas[2].fillColor = originalColor
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

function obj:setCallbacks(callbacks)
    self.onPauseClick = callbacks.onPauseClick
    self.onCompleteClick = callbacks.onCompleteClick
    self.onCancelClick = callbacks.onCancelClick
end

function obj:setPaused(paused)
    self.isPaused = paused
    self:togglePauseState()
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