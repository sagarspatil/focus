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
    
    -- Create overlay canvas (centered horizontally)
    local width = 400
    local height = 60
    local x = screenFrame.x + (screenFrame.w - width) / 2
    local y = screenFrame.y + 100  -- Below menu bar
    
    self.canvas = hs.canvas.new({x = x, y = y, w = width, h = height})
    self.canvasPosition = {x = x, y = y}  -- Store for dragging
    
    -- Background pill shape - semi-transparent with border
    self.canvas[1] = {
        type = "rectangle",
        action = "fillAndStroke",
        fillColor = {red = 0.15, green = 0.15, blue = 0.18, alpha = 0.7},
        strokeColor = {red = 0.35, green = 0.35, blue = 0.4, alpha = 0.8},
        strokeWidth = 1.5,
        roundedRectRadii = {xRadius = height/2, yRadius = height/2},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "background"
    }
    
    -- Time display (left side in rounded box)
    local timeText = self:formatTime(remainingSeconds)
    self.canvas[2] = {
        type = "rectangle",
        action = "fill",
        fillColor = {red = 0.25, green = 0.25, blue = 0.3, alpha = 0.8},
        roundedRectRadii = {xRadius = 15, yRadius = 15},
        frame = {x = 15, y = 12, w = 90, h = 36}
    }
    
    self.canvas[3] = {
        type = "text", 
        text = timeText,
        textFont = "SF Pro Display Medium",
        textSize = 22,
        textColor = {red = 0.6, green = 0.6, blue = 0.65, alpha = 1},
        textAlignment = "center",
        frame = {x = 15, y = 18, w = 90, h = 30}
    }
    
    -- Task name text (center)
    self.canvas[4] = {
        type = "text",
        text = taskName,
        textFont = "SF Pro Display",
        textSize = 20,
        textColor = {red = 0.95, green = 0.95, blue = 0.97, alpha = 1},
        textAlignment = "center",
        frame = {x = 120, y = 18, w = width - 240, h = 30}
    }
    
    -- Control buttons and move handle
    self:createControlButtons(width)
    
    -- Configure canvas behavior
    self.canvas:clickActivating(false)
    self.canvas:canvasMouseEvents(true, true, false, true)
    self.canvas:level(hs.canvas.windowLevels.overlay)
    self.canvas:behaviorAsLabels({"canJoinAllSpaces", "stationary"})
    self.canvas:show()
    self.isVisible = true
    
    -- Enable dragging
    self:enableDragging()
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
    
    local alpha = self.isPaused and 0.5 or 0.7
    if phase == "extension" then
        self.canvas[1].strokeColor = {red = 0.8, green = 0.6, blue = 0, alpha = 0.9} -- Orange border
        self.canvas[2].fillColor = {red = 0.4, green = 0.3, blue = 0.1, alpha = 0.8} -- Orange tinted time bg
    elseif phase == "grace" then
        self.canvas[1].strokeColor = {red = 0.8, green = 0.2, blue = 0, alpha = 0.9} -- Red-orange border
        self.canvas[2].fillColor = {red = 0.4, green = 0.15, blue = 0.1, alpha = 0.8} -- Red tinted time bg
    else
        self.canvas[1].strokeColor = {red = 0.35, green = 0.35, blue = 0.4, alpha = 0.8} -- Default border
        self.canvas[2].fillColor = {red = 0.25, green = 0.25, blue = 0.3, alpha = 0.8} -- Default time bg
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

function obj:createControlButtons(width)
    -- Move handle (grip icon) - always visible
    self.canvas[5] = {
        type = "rectangle",
        action = "fill",
        fillColor = {red = 0.3, green = 0.3, blue = 0.35, alpha = 0.3},
        roundedRectRadii = {xRadius = 8, yRadius = 8},
        frame = {x = width - 115, y = 20, w = 20, h = 20},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "moveHandle"
    }
    
    -- Grip dots pattern
    local dotSize = 2
    local dotSpacing = 5
    for row = 0, 2 do
        for col = 0, 2 do
            self.canvas[6 + row * 3 + col] = {
                type = "circle",
                action = "fill",
                center = {x = width - 110 + col * dotSpacing, y = 25 + row * dotSpacing},
                radius = dotSize/2,
                fillColor = {red = 0.5, green = 0.5, blue = 0.55, alpha = 0.8}
            }
        end
    end
    
    -- Pause/Resume button
    self.canvas[15] = {
        type = "text", 
        text = self.isPaused and "▶" or "⏸", 
        textSize = 20, 
        textColor = {red = 0.7, green = 0.7, blue = 0.75, alpha = 1},
        textAlignment = "center", 
        frame = {x = width - 85, y = 17, w = 25, h = 25}, 
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "pauseBtn"
    }
    
    -- Complete button  
    self.canvas[16] = {
        type = "text", 
        text = "✓", 
        textSize = 20, 
        textColor = {red = 0.7, green = 0.7, blue = 0.75, alpha = 1},
        textAlignment = "center", 
        frame = {x = width - 55, y = 17, w = 25, h = 25},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "completeBtn"
    }
    
    -- Cancel button
    self.canvas[17] = {
        type = "text", 
        text = "✕", 
        textSize = 20, 
        textColor = {red = 0.7, green = 0.7, blue = 0.75, alpha = 1},
        textAlignment = "center", 
        frame = {x = width - 25, y = 17, w = 25, h = 25},
        trackMouseDown = true,
        trackMouseEnterExit = true,
        id = "cancelBtn"
    }
end

function obj:enableDragging()
    local isDragging = false
    local dragOffset = {x = 0, y = 0}
    local dragEventTap = nil
    local mouseUpEventTap = nil
    
    self.canvas:mouseCallback(function(canvas, event, id, x, y)
        if event == "mouseEnter" then
            -- Hover effects
            if id == "moveHandle" or id == 5 then
                self.canvas[5].fillColor.alpha = 0.5
            elseif id == "pauseBtn" or id == 15 then
                self.canvas[15].textColor = {red = 0.9, green = 0.9, blue = 0.95, alpha = 1}
            elseif id == "completeBtn" or id == 16 then
                self.canvas[16].textColor = {red = 0.9, green = 0.9, blue = 0.95, alpha = 1}
            elseif id == "cancelBtn" or id == 17 then
                self.canvas[17].textColor = {red = 0.9, green = 0.9, blue = 0.95, alpha = 1}
            end
        elseif event == "mouseExit" then
            -- Reset hover effects
            if id == "moveHandle" or id == 5 then
                self.canvas[5].fillColor.alpha = 0.3
            elseif id == "pauseBtn" or id == 15 then
                self.canvas[15].textColor = {red = 0.7, green = 0.7, blue = 0.75, alpha = 1}
            elseif id == "completeBtn" or id == 16 then
                self.canvas[16].textColor = {red = 0.7, green = 0.7, blue = 0.75, alpha = 1}
            elseif id == "cancelBtn" or id == 17 then
                self.canvas[17].textColor = {red = 0.7, green = 0.7, blue = 0.75, alpha = 1}
            end
        elseif event == "mouseDown" then
            if id == "pauseBtn" or id == 15 then
                if self.onPauseClick then 
                    self:togglePauseIcon()
                    self.onPauseClick() 
                end
            elseif id == "completeBtn" or id == 16 then
                if self.onCompleteClick then self.onCompleteClick() end
            elseif id == "cancelBtn" or id == 17 then
                if self.onCancelClick then self.onCancelClick() end
            elseif id == "moveHandle" or id == 5 then
                -- Start dragging when clicking move handle
                isDragging = true
                local mousePos = hs.mouse.absolutePosition()
                dragOffset.x = mousePos.x - self.canvasPosition.x
                dragOffset.y = mousePos.y - self.canvasPosition.y
                
                -- Change cursor to indicate dragging
                self.canvas[5].fillColor.alpha = 0.7
                
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
                    self.canvas[5].fillColor.alpha = 0.3
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

function obj:setCallbacks(callbacks)
    self.onPauseClick = callbacks.onPauseClick
    self.onCompleteClick = callbacks.onCompleteClick
    self.onCancelClick = callbacks.onCancelClick
end

function obj:togglePauseIcon()
    self.isPaused = not self.isPaused
    if self.canvas and self.canvas[15] then
        self.canvas[15].text = self.isPaused and "▶" or "⏸"
        -- Make UI slightly transparent when paused
        self.canvas[1].fillColor.alpha = self.isPaused and 0.5 or 0.7
    end
end

function obj:setPaused(paused)
    self.isPaused = paused
    if self.canvas and self.canvas[15] then
        self.canvas[15].text = self.isPaused and "▶" or "⏸"
        self.canvas[1].fillColor.alpha = self.isPaused and 0.5 or 0.7
    end
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
