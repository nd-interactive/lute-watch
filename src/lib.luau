local fs = require("@std/fs")
local task = require("@std/task")
local path = require("@std/path")

local function watch(relativePath: path.Path, callback: () -> ()): () -> ()
    local timeCache = {}
    
    local connected = true
    local isInitial = true
    local lastCallId = 0
    task.spawn(function()
        while connected do
            local queryDescendants = fs.walk(relativePath, {recursive = true})
            local callId = lastCallId + 1
            while true do
                local nextPath = queryDescendants()
                if not nextPath then
                    break
                end
                
                local modifiedAt = fs.metadata(nextPath).modified
                local hashedPath = table.concat(nextPath.parts, `/`)
                if not timeCache[hashedPath] and isInitial then
                    timeCache[hashedPath] = modifiedAt
                end
                if timeCache[hashedPath] ~= modifiedAt then
                    timeCache[hashedPath] = modifiedAt
                    if lastCallId ~= callId then
                        task.spawn(callback)
                        lastCallId = callId
                    end
                end
            end
            isInitial = false
            task.wait(0.1)
        end
    end)

    return function()
        connected = false
    end
end

return watch