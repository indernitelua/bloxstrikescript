local _0x7E6B ="https://netanyahu-licenses.vladosikthebestkid.workers.dev"local _0xDDDB ="https://raw.githubusercontent.com/indernitelua/bloxstrikescript/11872f43778797cab371ce861592057765fe83c5/voidsense.arvn.lua"local _0x04BF = game:GetService("HttpService")
local _0x2C73 = game:GetService("Players").LocalPlayer
local _0x98EC ="NetanyahuCC/".. tostring(_0x2C73.UserId)
local _0x00EA = game:GetService("UserInputService")
local _0x507F = game:GetService("RunService")
local _0xD954 = getgenv().NetanyahuLicenseWindow
if type(_0xD954) =="table"and type(_0xD954.Close) =="function"then _0xD954.Close() end
local function _0xBD94(path)
local _0xDE36, _0xDEC7 = pcall(readfile, path)
return _0xDE36 and _0xDEC7 or""end
local function _0xCDB3(path, _0xDEC7)
local _0xDE36 = pcall(writefile, path, _0xDEC7)
return _0xDE36
end
local _0xBF5A = _0xBD94(_0x98EC .."/license-device.key")
if not _0xBF5A:match("^%x+$") or #_0xBF5A ~= 64 then
_0xBF5A = (_0x04BF:GenerateGUID(false) .. _0x04BF:GenerateGUID(false)):gsub("%-",""):lower()
assert(_0xCDB3(_0x98EC .."/license-device.key", _0xBF5A),"voidsense.cc: local storage unavailable")
end
local _0x8453 = false
local _0x673E = false
local _0x3910 = _0xBD94(_0x98EC .."/license.key"):gsub("%s","")
local _0xF6AD ="rbxasset://fonts/families/BuilderSans.json"local _0xA8EF = Font.new(_0xF6AD, Enum.FontWeight.Medium)
local _0x85A8 = Instance.new("ScreenGui")
_0x85A8.Name ="NetanyahuLicense"_0x85A8.IgnoreGuiInset = true
_0x85A8.ResetOnSpawn = false
_0x85A8.DisplayOrder = 10000
_0x85A8.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
_0x85A8.Parent = gethui() or _0x2C73:WaitForChild("PlayerGui")
local _0xE394 = {}
local _0xC3A8 = _0x00EA.MouseBehavior
local _0xC229 = _0x00EA.MouseIconEnabled
local _0x7871 ="NetanyahuLicenseMouse"local _0x7244 = {}
getgenv().NetanyahuLicenseWindow = _0x7244
local function _0xC2E0()
if _0x673E then return end
_0x673E = true
_0x507F:UnbindFromRenderStep(_0x7871)
for _, connection in ipairs(_0xE394) do connection:Disconnect() end
_0x00EA.MouseBehavior = _0xC3A8
_0x00EA.MouseIconEnabled = _0xC229
_0x85A8:Destroy()
if getgenv().NetanyahuLicenseWindow == _0x7244 then getgenv().NetanyahuLicenseWindow = nil end
end
_0x7244.Close = _0xC2E0
local function _0x9B15(className, properties, parent)
local _0x7739 = Instance.new(className)
for name, _0xDEC7 in pairs(properties) do _0x7739[name] = _0xDEC7 end
_0x7739.Parent = parent
return _0x7739
end
local _0x4008 = _0x9B15("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 284), BackgroundColor3 = Color3.fromHex("110E17"), BorderSizePixel = 0, ClipsDescendants = true}, _0x85A8)
_0x9B15("UICorner", {CornerRadius = UDim.new(0, 24)}, _0x4008)
_0x9B15("UIStroke", {Color = Color3.fromHex("352D42"), Thickness = 1, Transparency = 0.1}, _0x4008)
local _0xBE91 = _0x9B15("UIScale", {Scale = 1}, _0x4008)
local function _0xC93C()
local _0x3B34 = workspace.CurrentCamera
if _0x3B34 then _0xBE91.Scale = math.min(1, math.max(0.25, math.min((_0x3B34.ViewportSize.X - 24) / 440, (_0x3B34.ViewportSize.Y - 24) / 284))) end
end
local function _0xDB2E(text, position, size, color, fontSize)
return _0x9B15("TextLabel", {Text = text, Position = position, Size = size, BackgroundTransparency = 1, TextColor3 = color, FontFace = _0xA8EF, TextSize = fontSize, TextXAlignment = Enum.TextXAlignment.Left}, _0x4008)
end
local _0x7793 = _0xDB2E("voidsense.cc", UDim2.fromOffset(24, 20), UDim2.fromOffset(340, 26), Color3.fromHex("F0ECF6"), 20)
_0x7793.FontFace = Font.new(_0xF6AD, Enum.FontWeight.SemiBold)
_0xDB2E("license access", UDim2.fromOffset(24, 51), UDim2.fromOffset(350, 20), Color3.fromHex("958CA5"), 13)
_0x9B15("Frame", {Position = UDim2.fromOffset(24, 82), Size = UDim2.fromOffset(392, 1), BackgroundColor3 = Color3.fromHex("352D42"), BorderSizePixel = 0}, _0x4008)
local _0x31DF = _0x9B15("TextButton", {Text ="×", Position = UDim2.fromOffset(384, 20), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromHex("211B2B"), BorderSizePixel = 0, TextColor3 = Color3.fromHex("958CA5"), FontFace = _0xA8EF, TextSize = 22}, _0x4008)
_0x9B15("UICorner", {CornerRadius = UDim.new(1, 0)}, _0x31DF)
_0xDB2E("license key", UDim2.fromOffset(24, 98), UDim2.fromOffset(350, 18), Color3.fromHex("D6CFE2"), 13)
local _0x6BFB = _0x9B15("Frame", {Position = UDim2.fromOffset(24, 123), Size = UDim2.fromOffset(392, 44), BackgroundColor3 = Color3.fromHex("292235"), BorderSizePixel = 0, ClipsDescendants = true}, _0x4008)
_0x9B15("UICorner", {CornerRadius = UDim.new(0, 12)}, _0x6BFB)
local _0xF3F2 = _0x9B15("TextBox", {Text = _0x3910, PlaceholderText ="paste your key", ClearTextOnFocus = false, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, TextColor3 = Color3.fromHex("D6CFE2"), PlaceholderColor3 = Color3.fromHex("6D657D"), FontFace = _0xA8EF, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true}, _0x6BFB)
local _0x883A = _0x9B15("TextButton", {Text ="activate", Modal = true, Position = UDim2.fromOffset(24, 179), Size = UDim2.fromOffset(392, 42), BackgroundColor3 = Color3.fromHex("9A6BFF"), BorderSizePixel = 0, TextColor3 = Color3.fromHex("F0ECF6"), FontFace = Font.new(_0xF6AD, Enum.FontWeight.SemiBold), TextSize = 14}, _0x4008)
_0x9B15("UICorner", {CornerRadius = UDim.new(0, 12)}, _0x883A)
local _0xAFE3 = _0xDB2E("enter your key to continue", UDim2.fromOffset(24, 232), UDim2.fromOffset(392, 36), Color3.fromHex("958CA5"), 12)
_0xAFE3.TextWrapped = true
_0xAFE3.TextYAlignment = Enum.TextYAlignment.Top
_0xE394[#_0xE394 + 1] = _0x31DF.Activated:Connect(_0xC2E0)
_0x507F:BindToRenderStep(_0x7871, Enum.RenderPriority.Last.Value + 1, function()
if not _0x673E then
_0x00EA.MouseBehavior = Enum.MouseBehavior.Default
_0x00EA.MouseIconEnabled = true
_0xC93C()
end
end)
_0xC93C()
local _0xAF2D = getgenv().STATE
if type(_0xAF2D) =="table"and type(_0xAF2D.onCleanup) =="function"then _0xAF2D.onCleanup(_0xC2E0) end
local function _0xD7EA(route, method, _0xDEC7, token)
local _0xEDCB = request({Url = _0x7E6B .. route, Method = method, Headers = { ["Content-Type"] ="application/json", Authorization = token and"Bearer ".. token or""}, Body = _0xDEC7 and _0x04BF:JSONEncode(_0xDEC7) or nil})
if type(_0xEDCB) ~="table"then error("network unavailable") end
return _0xEDCB.StatusCode, _0xEDCB.Body
end
local function _0x9401()
if _0x8453 or _0x673E then return end
_0x8453 = true
_0xAFE3.Text ="checking license..."_0x883A.Text ="checking..."local _0xDE36, _0x5330 = pcall(function()
local _0xBEFE = _0xF3F2.Text:gsub("%s","")
local _0x17F5, _0xA2B2 = _0xD7EA("/activate","POST", {key = _0xBEFE, device = _0xBF5A, userId = _0x2C73.UserId})
local _0xA39D = _0x04BF:JSONDecode(_0xA2B2)
if _0x17F5 ~= 200 then error(_0xA39D.error or"activation failed") end
local _0xB8A5, _0xB150 = _0xD7EA("/core","GET", nil, _0xA39D.token)
if _0xB8A5 ~= 200 then error("core unavailable; contact the seller") end
local _0x34F0, _0x1167 = loadstring(_0xB150)
assert(_0x34F0, tostring(_0x1167))
local _0x6422 = _0x34F0()
assert(type(_0x6422) =="function","invalid core module")
local _0xBF87, _0x9E4D = loadstring(game:HttpGet(_0xDDDB))
assert(_0xBF87, tostring(_0x9E4D))
if _0x673E then return end
assert(_0xCDB3(_0x98EC .."/license.key", _0xBEFE),"key could not be saved")
_0xC2E0()
local _0x6E66, _0xA49B = pcall(_0x6422, function() return _0xBF87() end)
if not _0x6E66 then error(tostring(_0xA49B)) end
local _0xE8F4 = getgenv().NetanyahuCC or getgenv().BloxStrikeArvn
assert(type(_0xE8F4) =="table"and type(_0xE8F4.Eject) =="function","core did not start")
task.spawn(function()
local _0x9E84 = 0
while (getgenv().NetanyahuCC or getgenv().BloxStrikeArvn) == _0xE8F4 do
task.wait(60)
if (getgenv().NetanyahuCC or getgenv().BloxStrikeArvn) ~= _0xE8F4 then break end
local _0x9D0F, _0x1AD6 = pcall(_0xD7EA,"/validate","POST", nil, _0xA39D.token)
if _0x9D0F and _0x1AD6 == 200 then _0x9E84 = 0 else _0x9E84 += 1 end
if (_0x9D0F and (_0x1AD6 == 401 or _0x1AD6 == 403)) or _0x9E84 >= 3 then
pcall(_0xE8F4.Eject)
warn("voidsense.cc: license expired, revoked or validation unavailable; execute the loader again")
break
end
end
end)
end)
_0x8453 = false
if not _0xDE36 then
if not _0x673E then _0xAFE3.Text = tostring(_0x5330):gsub("^.-:%d+: ",""); _0x883A.Text ="activate"else warn("voidsense.cc: ".. tostring(_0x5330)) end
end
end
_0xE394[#_0xE394 + 1] = _0x883A.Activated:Connect(_0x9401)
_0xE394[#_0xE394 + 1] = _0xF3F2.FocusLost:Connect(function(enterPressed) if enterPressed then _0x9401() end end)
if _0x3910 ~=""then task.defer(_0x9401) end