export type Node = {
    indicies: { string },
    cache: { [string]: any },
    subnodes: { [string]: Node }
}

const VirtualTree = {}
VirtualTree.__index = VirtualTree

const function createNode()
    const node = {
        indicies = table.freeze({}),
        cache = {},
        subnodes = {}
    }

    return node
end

function VirtualTree.new()
    return setmetatable({
        rootNode = createNode()
    }, VirtualTree)
end

function VirtualTree:createNode(name: string, parentNode: Node?)
    if not parentNode then
        parentNode = self.rootNode
    end
    assert(parentNode) -- for typesafe

    const newNode = createNode()

    const indicies = table.clone(parentNode.indicies)
    table.insert(indicies, name)
    table.freeze(indicies)
    newNode.indicies = indicies

    parentNode.subnodes[name] = newNode

    return table.freeze(newNode)
end

function VirtualTree:getNode(parentNode: Node, name: string)
    return parentNode.subnodes[name]
end

function VirtualTree:removeNode(node: Node)
    const parentIndicies = table.clone(node.indicies)
    const nodeName = table.remove(parentIndicies, #parentIndicies)
    const parentNode = self:walkTo(parentIndicies)
    parentNode.subnodes[nodeName] = nil
end

function VirtualTree:writeCache(node: Node, name: string, value: any)
    node.cache[name] = value
    return value
end

function VirtualTree:readCache(node: Node, name: string)
    return node.cache[name]
end

function VirtualTree:walkTo(indicies: { string }, reconcile: boolean?)
    local dstNode = self.rootNode
    for _, nodeName in indicies do
        local node = self:getNode(dstNode, nodeName)
        if not node then
            if reconcile then
                node = self:createNode(nodeName, dstNode)
            else
                return nil
            end
        end
        dstNode = node
    end

    return dstNode
end

function VirtualTree:querySubnodes(node: Node)
    const subnodes = {} :: { Node }
    const function querySubNodes(targetNode)
        for _, subnode in targetNode.subnodes do
            table.insert(subnodes, subnode)
            querySubNodes(subnode)
        end
    end

    querySubNodes(node)
    return subnodes
end

return VirtualTree