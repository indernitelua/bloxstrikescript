local endpoint = "https://netanyahu-licenses.vladosikthebestkid.workers.dev"
local uiUrl = "https://raw.githubusercontent.com/indernitelua/bloxstrikescript/main/netanyahu.arvn.lua"
local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local folder = "NetanyahuCC/" .. tostring(player.UserId)
local function read(path)
    local ok, value = pcall(readfile, path)
    return ok and value or ""
end
local function store(path, value)
    local ok = pcall(writefile, path, value)
    return ok
end
local device = read(folder .. "/license-device.key")
if not device:match("^%x+$") or #device ~= 64 then
    device = (HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)):gsub("%-", ""):lower()
    assert(store(folder .. "/license-device.key", device), "netanyahu.cc: local storage unavailable")
end
local uiSource = game:HttpGet(uiUrl)
local uiChunk, uiError = loadstring(uiSource)
assert(uiChunk, tostring(uiError))
local library = uiChunk()
local window = library:CreateWindow({Title = "netanyahu.cc", Author = "vlad", Version = "access", Folder = folder .. "/access", Theme = "Purple", Accent = Color3.fromRGB(154, 107, 255), MenuKey = "RightShift", Watermark = false})
local section = window:Group("account"):Tab({Name = "license", Icon = "key"}):Section({Name = "activate access", Side = "Left"})
section:Input({Name = "license key", Flag = "license_key", Default = read(folder .. "/license.key"), Save = false})
local status = section:Label("enter your key to continue")
local busy = false
local closed = false
library:OnEject(function() closed = true end)
local function call(route, method, value, token)
    local response = request({Url = endpoint .. route, Method = method, Headers = { ["Content-Type"] = "application/json", Authorization = token and "Bearer " .. token or "" }, Body = value and HttpService:JSONEncode(value) or nil})
    if type(response) ~= "table" then error("network unavailable") end
    return response.StatusCode, response.Body
end
section:Button({Name = "activate", Callback = function()
    if busy or closed then return end
    busy = true
    status:SetName("checking license...")
    local ok, message = pcall(function()
        local key = tostring(library.Flags.license_key or ""):gsub("%s", "")
        local code, body = call("/activate", "POST", {key = key, device = device, userId = player.UserId})
        local data = HttpService:JSONDecode(body)
        if code ~= 200 then error(data.error or "activation failed") end
        local coreCode, source = call("/core", "GET", nil, data.token)
        if coreCode ~= 200 then error("core unavailable; contact the seller") end
        local chunk, compileError = loadstring(source)
        assert(chunk, tostring(compileError))
        local start = chunk()
        assert(type(start) == "function", "invalid core module")
        if closed then return end
        assert(store(folder .. "/license.key", key), "key could not be saved")
        library:Eject()
        local launched, launchError = pcall(start, function() return uiChunk() end)
        if not launched then error(tostring(launchError)) end
        local owned = getgenv().NetanyahuCC or getgenv().BloxStrikeArvn
        assert(type(owned) == "table" and type(owned.Eject) == "function", "core did not start")
        task.spawn(function()
            local failures = 0
            while (getgenv().NetanyahuCC or getgenv().BloxStrikeArvn) == owned do
                task.wait(60)
                if (getgenv().NetanyahuCC or getgenv().BloxStrikeArvn) ~= owned then break end
                local success, replyCode = pcall(call, "/validate", "POST", nil, data.token)
                if success and replyCode == 200 then failures = 0 else failures += 1 end
                if (success and (replyCode == 401 or replyCode == 403)) or failures >= 3 then
                    pcall(owned.Eject)
                    warn("netanyahu.cc: license expired, revoked or validation unavailable; execute the loader again")
                    break
                end
            end
        end)
    end)
    busy = false
    if not ok then
        if not closed then status:SetName(tostring(message):gsub("^.-:%d+: ", "")) else warn("netanyahu.cc: " .. tostring(message)) end
    end
end})
