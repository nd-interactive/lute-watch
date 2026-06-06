const FileSystem = require("@lute/fs")
const task = require("@lute/task")
const StandardFileSystem = require("@std/fs")
const VirtualTree = require("@self/virtual-tree")
const Path = require("@std/path")

export type Behavior = {
    kind: "create"
} | {
    kind: "delete"
} | {
    kind: "rename",
    from: Path.Path?
} | {
    kind: "change"
}

const function watchDescendants(targetPath: Path.Path, callback: (Path.Path, Behavior) -> ())
    assert(
        FileSystem.type(Path.format(targetPath)) == "dir",
        "currently we support observing directories only, observing files will be supported in the future."
    )

    const vtree = VirtualTree.new()

    const function disconnectListener(node: VirtualTree.Node)
        const connection = vtree:readCache(node, "connection")
        if connection then
            connection:close()
            vtree:writeCache(node, "connection", nil)
        end
    end

    const function connectListener(directoryPath: Path.Path)
        local latelyRenamed: { path: Path.Path, size: number }
        const directoryNode = vtree:walkTo(directoryPath.parts, true)
        const stringifyDirectoryPath = Path.format(directoryPath)

        const connection = FileSystem.watch(stringifyDirectoryPath, function(fileName, event)
            const filePath = Path.join(directoryPath, fileName)
            const stringifyPath = Path.format(filePath)
            const isFileExist = FileSystem.exists(stringifyPath)
            local fileNode = vtree:getNode(directoryNode, fileName)

            if not isFileExist then
                const size = vtree:readCache(fileNode, "size")
                for _, subnode in vtree:querySubnodes(fileNode) do
                    disconnectListener(subnode)
                end
                disconnectListener(fileNode)
                vtree:removeNode(fileNode)

                if event.rename then
                    latelyRenamed = { path = filePath, size = size }
                end

                task.spawn(callback, filePath, { kind = "delete" })
                return
            end

            const fileMetadata = FileSystem.stat(stringifyPath)
            
            if event.change then
                vtree:writeCache(fileNode, "size", fileMetadata.size)
                return task.spawn(callback, filePath, { kind = "change" })
            end
            
            if not fileNode then
                if FileSystem.type(stringifyPath) == "dir" then
                    connectListener(filePath)
                end
                
                fileNode = vtree:createNode(fileName, directoryNode)
                vtree:writeCache(fileNode, "size", fileMetadata.size)
                
                if event.rename and latelyRenamed and latelyRenamed.size == fileMetadata.size then
                    const from = latelyRenamed
                    latelyRenamed = nil :: any
                    return task.spawn(callback, filePath, { kind = "rename", from = from.path })
                end
                
                return task.spawn(callback, filePath, { kind = "create" })
            end

            if event.rename then
                return task.spawn(callback, filePath, { kind = "rename" })
            end
            
            return error("unexpected behavior")
        end)

        vtree:writeCache(directoryNode, "connection", connection)
    end
    
    const queryDescendants = StandardFileSystem.walk(targetPath, { recursive = true })
    while true do
        const path = queryDescendants()
        if not path then
            break
        end
        
        const stringifyPath = Path.format(path)
        const node = vtree:walkTo(path.parts, true) -- register things
        vtree:writeCache(node, "size", FileSystem.stat(stringifyPath).size)

        if FileSystem.type(stringifyPath) == "dir" then
            connectListener(path)
        end
    end
end

return watchDescendants