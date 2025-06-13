-- Logger.lua
-- CSV logging for focus session data

local obj = {}
obj.__index = obj

function obj:init(config)
    self.config = config
    self.csvPath = config.csv_path
    
    -- Ensure CSV file exists with headers
    self:ensureCSVExists()
    
    return self
end

function obj:ensureCSVExists()
    local file = io.open(self.csvPath, "r")
    
    if not file then
        -- Create new CSV with headers
        file = io.open(self.csvPath, "w")
        if file then
            file:write("timestamp_start,timestamp_end,task,planned_min,actual_min,outcome\n")
            file:close()
        else
            hs.printf("Error: Could not create CSV file at %s", self.csvPath)
        end
    else
        file:close()
    end
end

function obj:logSession(sessionData)
    local file = io.open(self.csvPath, "a")
    
    if not file then
        hs.printf("Error: Could not open CSV file for writing: %s", self.csvPath)
        return false
    end
    
    -- Format timestamps
    local startTime = self:formatTimestamp(sessionData.startTime)
    local endTime = self:formatTimestamp(sessionData.endTime)
    
    -- Escape task name (handle commas and quotes)
    local task = self:escapeCSVField(sessionData.task)
    
    -- Write CSV row
    local csvRow = string.format("%s,%s,%s,%d,%d,%s\n",
        startTime,
        endTime,
        task,
        sessionData.plannedMinutes,
        sessionData.actualMinutes,
        sessionData.outcome
    )
    
    file:write(csvRow)
    file:close()
    
    -- Log to console as well
    hs.printf("Session logged: %s - %s (%d/%d min) - %s",
        task,
        sessionData.outcome,
        sessionData.actualMinutes,
        sessionData.plannedMinutes,
        startTime
    )
    
    return true
end

function obj:formatTimestamp(unixTime)
    -- Format as ISO 8601: 2025-06-13T09:02:00
    return os.date("%Y-%m-%dT%H:%M:%S", unixTime)
end

function obj:escapeCSVField(field)
    -- Handle CSV escaping for fields containing commas or quotes
    if string.find(field, '[",\n\r]') then
        -- Escape quotes by doubling them
        field = string.gsub(field, '"', '""')
        -- Wrap in quotes
        field = '"' .. field .. '"'
    end
    
    return field
end

function obj:getRecentSessions(days)
    days = days or 7
    local cutoffTime = os.time() - (days * 24 * 60 * 60)
    
    local sessions = {}
    local file = io.open(self.csvPath, "r")
    
    if not file then
        return sessions
    end
    
    -- Skip header line
    file:read("*line")
    
    for line in file:lines() do
        local session = self:parseCSVLine(line)
        if session and session.startTime >= cutoffTime then
            table.insert(sessions, session)
        end
    end
    
    file:close()
    
    -- Sort by start time (newest first)
    table.sort(sessions, function(a, b)
        return a.startTime > b.startTime
    end)
    
    return sessions
end

function obj:parseCSVLine(line)
    -- Simple CSV parser (handles basic cases)
    local fields = {}
    local inQuotes = false
    local currentField = ""
    
    for char in line:gmatch(".") do
        if char == '"' then
            inQuotes = not inQuotes
        elseif char == "," and not inQuotes then
            table.insert(fields, currentField)
            currentField = ""
        else
            currentField = currentField .. char
        end
    end
    
    -- Add the last field
    table.insert(fields, currentField)
    
    if #fields >= 6 then
        return {
            startTime = self:parseTimestamp(fields[1]),
            endTime = self:parseTimestamp(fields[2]),
            task = fields[3]:gsub('""', '"'), -- Unescape quotes
            plannedMin = tonumber(fields[4]),
            actualMin = tonumber(fields[5]),
            outcome = fields[6]
        }
    end
    
    return nil
end

function obj:parseTimestamp(timestamp)
    -- Parse ISO 8601 timestamp back to unix time
    local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec = timestamp:match(pattern)
    
    if year then
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec)
        })
    end
    
    return 0
end

function obj:getSessionStats(days)
    local sessions = self:getRecentSessions(days)
    
    local stats = {
        totalSessions = #sessions,
        completedSessions = 0,
        totalPlannedMinutes = 0,
        totalActualMinutes = 0,
        averageActualMinutes = 0,
        completionRate = 0,
        outcomes = {}
    }
    
    for _, session in ipairs(sessions) do
        stats.totalPlannedMinutes = stats.totalPlannedMinutes + session.plannedMin
        stats.totalActualMinutes = stats.totalActualMinutes + session.actualMin
        
        if session.outcome == "completed" then
            stats.completedSessions = stats.completedSessions + 1
        end
        
        -- Count outcomes
        stats.outcomes[session.outcome] = (stats.outcomes[session.outcome] or 0) + 1
    end
    
    if stats.totalSessions > 0 then
        stats.averageActualMinutes = stats.totalActualMinutes / stats.totalSessions
        stats.completionRate = stats.completedSessions / stats.totalSessions * 100
    end
    
    return stats
end

function obj:exportData(format, outputPath)
    format = format or "csv"
    outputPath = outputPath or (os.getenv("HOME") .. "/FocusSessionsExport." .. format)
    
    if format == "csv" then
        -- Just copy the existing CSV
        local success = self:copyFile(self.csvPath, outputPath)
        return success, outputPath
    elseif format == "json" then
        return self:exportToJSON(outputPath)
    else
        return false, "Unsupported format: " .. format
    end
end

function obj:exportToJSON(outputPath)
    local sessions = self:getRecentSessions(365) -- Get all sessions from last year
    
    -- Convert to JSON-friendly format
    local jsonData = {
        exportDate = os.date("%Y-%m-%dT%H:%M:%S"),
        sessions = {}
    }
    
    for _, session in ipairs(sessions) do
        table.insert(jsonData.sessions, {
            startTime = self:formatTimestamp(session.startTime),
            endTime = self:formatTimestamp(session.endTime),
            task = session.task,
            plannedMinutes = session.plannedMin,
            actualMinutes = session.actualMin,
            outcome = session.outcome
        })
    end
    
    -- Simple JSON serialization (basic implementation)
    local jsonString = self:toJSON(jsonData)
    
    local file = io.open(outputPath, "w")
    if file then
        file:write(jsonString)
        file:close()
        return true, outputPath
    else
        return false, "Could not write to " .. outputPath
    end
end

function obj:copyFile(src, dest)
    local srcFile = io.open(src, "r")
    if not srcFile then
        return false
    end
    
    local content = srcFile:read("*all")
    srcFile:close()
    
    local destFile = io.open(dest, "w")
    if not destFile then
        return false
    end
    
    destFile:write(content)
    destFile:close()
    
    return true
end

function obj:toJSON(data)
    -- Very basic JSON serialization
    -- For production use, would want a proper JSON library
    if type(data) == "table" then
        local parts = {}
        local isArray = true
        local count = 0
        
        -- Check if it's an array
        for k, v in pairs(data) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                isArray = false
                break
            end
        end
        
        if isArray then
            for i, v in ipairs(data) do
                table.insert(parts, self:toJSON(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(data) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. self:toJSON(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    elseif type(data) == "string" then
        return '"' .. data:gsub('"', '\\"') .. '"'
    elseif type(data) == "number" or type(data) == "boolean" then
        return tostring(data)
    else
        return "null"
    end
end

return obj
