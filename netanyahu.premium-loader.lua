local endpoint = "https://netanyahu-licenses.vladosikthebestkid.workers.dev"
local uiUrl = "https://raw.githubusercontent.com/indernitelua/bloxstrikescript/main/netanyahu.arvn.lua"
local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local folder = "NetanyahuCC/" .. tostring(player.UserId)
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local previous = getgenv().NetanyahuLicenseWindow
if type(previous) == "table" and type(previous.Close) == "function" then previous.Close() end
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
local busy = false
local closed = false
local savedKey = read(folder .. "/license.key"):gsub("%s", "")
local fontFamily = "rbxasset://fonts/families/BuilderSans.json"
local font = Font.new(fontFamily, Enum.FontWeight.Medium)
local screen = Instance.new("ScreenGui")
screen.Name = "NetanyahuLicense"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 10000
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = gethui() or player:WaitForChild("PlayerGui")
local connections = {}
local mouseBehavior = UserInputService.MouseBehavior
local mouseIcon = UserInputService.MouseIconEnabled
local mouseStep = "NetanyahuLicenseMouse"
local owner = {}
getgenv().NetanyahuLicenseWindow = owner
local function close()
    if closed then return end
    closed = true
    RunService:UnbindFromRenderStep(mouseStep)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    UserInputService.MouseBehavior = mouseBehavior
    UserInputService.MouseIconEnabled = mouseIcon
    screen:Destroy()
    if getgenv().NetanyahuLicenseWindow == owner then getgenv().NetanyahuLicenseWindow = nil end
end
owner.Close = close
local function create(className, properties, parent)
    local item = Instance.new(className)
    for name, value in pairs(properties) do item[name] = value end
    item.Parent = parent
    return item
end
local panel = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 284), BackgroundColor3 = Color3.fromHex("110E17"), BorderSizePixel = 0, ClipsDescendants = true}, screen)
create("UICorner", {CornerRadius = UDim.new(0, 24)}, panel)
create("UIStroke", {Color = Color3.fromHex("352D42"), Thickness = 1, Transparency = 0.1}, panel)
local scale = create("UIScale", {Scale = 1}, panel)
local function resize()
    local camera = workspace.CurrentCamera
    if camera then scale.Scale = math.min(1, math.max(0.25, math.min((camera.ViewportSize.X - 24) / 440, (camera.ViewportSize.Y - 24) / 284))) end
end
local function label(text, position, size, color, fontSize)
    return create("TextLabel", {Text = text, Position = position, Size = size, BackgroundTransparency = 1, TextColor3 = color, FontFace = font, TextSize = fontSize, TextXAlignment = Enum.TextXAlignment.Left}, panel)
end
local title = label("netanyahu.cc", UDim2.fromOffset(24, 20), UDim2.fromOffset(340, 26), Color3.fromHex("F0ECF6"), 20)
title.FontFace = Font.new(fontFamily, Enum.FontWeight.SemiBold)
label("license access", UDim2.fromOffset(24, 51), UDim2.fromOffset(350, 20), Color3.fromHex("958CA5"), 13)
create("Frame", {Position = UDim2.fromOffset(24, 82), Size = UDim2.fromOffset(392, 1), BackgroundColor3 = Color3.fromHex("352D42"), BorderSizePixel = 0}, panel)
local dismiss = create("TextButton", {Text = "×", Position = UDim2.fromOffset(384, 20), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromHex("211B2B"), BorderSizePixel = 0, TextColor3 = Color3.fromHex("958CA5"), FontFace = font, TextSize = 22}, panel)
create("UICorner", {CornerRadius = UDim.new(1, 0)}, dismiss)
label("license key", UDim2.fromOffset(24, 98), UDim2.fromOffset(350, 18), Color3.fromHex("D6CFE2"), 13)
local field = create("Frame", {Position = UDim2.fromOffset(24, 123), Size = UDim2.fromOffset(392, 44), BackgroundColor3 = Color3.fromHex("292235"), BorderSizePixel = 0, ClipsDescendants = true}, panel)
create("UICorner", {CornerRadius = UDim.new(0, 12)}, field)
local input = create("TextBox", {Text = savedKey, PlaceholderText = "paste your key", ClearTextOnFocus = false, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, TextColor3 = Color3.fromHex("D6CFE2"), PlaceholderColor3 = Color3.fromHex("6D657D"), FontFace = font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true}, field)
local activate = create("TextButton", {Text = "activate", Modal = true, Position = UDim2.fromOffset(24, 179), Size = UDim2.fromOffset(392, 42), BackgroundColor3 = Color3.fromHex("9A6BFF"), BorderSizePixel = 0, TextColor3 = Color3.fromHex("F0ECF6"), FontFace = Font.new(fontFamily, Enum.FontWeight.SemiBold), TextSize = 14}, panel)
create("UICorner", {CornerRadius = UDim.new(0, 12)}, activate)
local status = label("enter your key to continue", UDim2.fromOffset(24, 232), UDim2.fromOffset(392, 36), Color3.fromHex("958CA5"), 12)
status.TextWrapped = true
status.TextYAlignment = Enum.TextYAlignment.Top
connections[#connections + 1] = dismiss.Activated:Connect(close)
RunService:BindToRenderStep(mouseStep, Enum.RenderPriority.Last.Value + 1, function()
    if not closed then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        resize()
    end
end)
resize()
local state = getgenv().STATE
if type(state) == "table" and type(state.onCleanup) == "function" then state.onCleanup(close) end
local function call(route, method, value, token)
    local response = request({Url = endpoint .. route, Method = method, Headers = { ["Content-Type"] = "application/json", Authorization = token and "Bearer " .. token or "" }, Body = value and HttpService:JSONEncode(value) or nil})
    if type(response) ~= "table" then error("network unavailable") end
    return response.StatusCode, response.Body
end
local function submit()
    if busy or closed then return end
    busy = true
    status.Text = "checking license..."
    activate.Text = "checking..."
    local ok, message = pcall(function()
        local key = input.Text:gsub("%s", "")
        local code, body = call("/activate", "POST", {key = key, device = device, userId = player.UserId})
        local data = HttpService:JSONDecode(body)
        if code ~= 200 then error(data.error or "activation failed") end
        local coreCode, source = call("/core", "GET", nil, data.token)
        if coreCode ~= 200 then error("core unavailable; contact the seller") end
        local chunk, compileError = loadstring(source)
        assert(chunk, tostring(compileError))
        local start = chunk()
        assert(type(start) == "function", "invalid core module")
        local uiChunk, uiError = loadstring(game:HttpGet(uiUrl))
        assert(uiChunk, tostring(uiError))
        if closed then return end
        assert(store(folder .. "/license.key", key), "key could not be saved")
        close()
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
        if not closed then status.Text = tostring(message):gsub("^.-:%d+: ", ""); activate.Text = "activate" else warn("netanyahu.cc: " .. tostring(message)) end
    end
end
connections[#connections + 1] = activate.Activated:Connect(submit)
connections[#connections + 1] = input.FocusLost:Connect(function(enterPressed) if enterPressed then submit() end end)
if savedKey ~= "" then task.defer(submit) end
