a simple path watcher for lute

example code

```lua
const path = require("@std/path")
const watchPath = require("@luau_packages/watch")

watchPath(path.basename("./targetFile"), function()
    print("file changed!")
end)
```
