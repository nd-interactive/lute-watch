const FileSystem = require("@lute/fs")
const task = require("@lute/task")
const StandardFileSystem = require("@std/fs")
const VirtualTree = require("./virtual-tree")
const Path = require("@std/path")

export type Events = {
    kind: "create"
} | {
    kind: "delete"
} | {
    kind: "rename"
} | {
    kind: "change"
}

const function observePath(targetPath: Path.Path, callback: (Path.Path, Events) -> ())
    assert(
        FileSystem.type(Path.format(targetPath)) == "dir",
        "currently we supports directories only, files will be supported in the future."
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
        const node = vtree:walkTo(directoryPath.parts, true)
        const stringifyDirectoryPath = Path.format(directoryPath)

        const connection = FileSystem.watch(stringifyDirectoryPath, function(fileName, event)
            const filePath = Path.join(directoryPath, fileName)
            const stringifyPath = Path.format(filePath)
            const isFileExist = FileSystem.exists(stringifyPath)

            if not isFileExist then
                for _, subnode in vtree:querySubnodes(node) do
                    disconnectListener(subnode)
                end
                disconnectListener(node)
                vtree:removeNode(node)
                task.spawn(callback, filePath, { kind = "delete" })
                return
            end

            if event.change then
                return task.spawn(callback, filePath, { kind = "change" })
            end

            if not vtree:getNode(node, fileName) then
                if FileSystem.type(stringifyPath) == "dir" then
                    connectListener(filePath)
                end
                vtree:createNode(fileName, node)
                return task.spawn(callback, filePath, { kind = "create" })
            end

            if event.rename then
                return task.spawn(callback, filePath, { kind = "rename" })
            end

            return error("unexpected behavior")
        end)
        vtree:writeCache(node, "connection", connection)
    end
    
    const queryDescendants = StandardFileSystem.walk(targetPath, { recursive = true })
    while true do
        const path = queryDescendants()
        if not path then
            break
        end
        
        const stringifyPath = Path.format(path)
        vtree:walkTo(path.parts, true) -- register things

        if FileSystem.type(stringifyPath) == "dir" then
            connectListener(path)
        end
    end
end

return observePath