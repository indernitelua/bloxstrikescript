local coreUrl = "https://raw.githubusercontent.com/indernitelua/bloxstrikescript/main/netanyahu.core.obfuscated.lua"
local uiUrl = "https://raw.githubusercontent.com/indernitelua/bloxstrikescript/main/netanyahu.arvn.lua"
local function compile(url)
    local source = game:HttpGet(url)
    local chunk, err = loadstring(source)
    assert(chunk, tostring(err))
    return chunk
end
local coreChunk = compile(coreUrl)
local uiChunk = compile(uiUrl)
local start = coreChunk()
assert(type(start) == "function", "invalid script module")
start(function()
    local library = uiChunk()
    assert(type(library) == "table", "invalid UI module")
    return library
end)
