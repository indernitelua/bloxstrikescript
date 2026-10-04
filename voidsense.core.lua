return function(createArvn)
local newInstance = Instance.new
local State = getgenv().STATE
if type(State) ~= "table" then State = {} end
if type(State.onCleanup) ~= "function" then State.onCleanup = function() end end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local Characters = workspace:WaitForChild("Characters", 10)
if not Characters then error("voidsense.cc: characters are unavailable") end
local CharacterModels = Characters:GetChildren()
local function module(root, names)
    local node = root
    for _, name in ipairs(names) do
        node = node:FindFirstChild(name) or node:WaitForChild(name, 5)
        if not node then error("voidsense.cc: missing game module " .. table.concat(names, ".")) end
    end
    local ok, value = pcall(require, node :: ModuleScript)
    if not ok then error("voidsense.cc: module failed " .. table.concat(names, ".") .. ": " .. tostring(value)) end
    return value
end
local CameraController = module(ReplicatedStorage, {"Controllers", "CameraController"})
local CharacterController = module(ReplicatedStorage, {"Controllers", "CharacterController"})
local CharacterClass = module(ReplicatedStorage, {"Classes", "Character"})
local MovementButtons = module(ReplicatedStorage, {"MovementV2", "Buttons"})
local MovementSettings = module(ReplicatedStorage, {"MovementV2", "Simulation", "RuntimeSettings"})
local Bullet = module(ReplicatedStorage, {"Components", "Weapon", "Classes", "Bullet"})
local WeaponRaycast = module(ReplicatedStorage, {"Shared", "Raycast"})
local InventoryController = module(ReplicatedStorage, {"Controllers", "InventoryController"})
local CharacterPose = module(ReplicatedStorage, {"Components", "Common", "CharacterPose"})
local CharacterSkins = module(ReplicatedStorage, {"Database", "Components", "Libraries", "Skins"})
local WeaponAttachments = module(ReplicatedStorage, {"Database", "Custom", "GameStats", "Character", "Attachments"})
local Controls = module(LocalPlayer.PlayerScripts, {"PlayerModule"}):GetControls()
local required = {{Bullet, "_performRaycast"}, {WeaponRaycast, "cast"}, {WeaponRaycast, "castThrough"}, {InventoryController, "peekCurrentEquippedForMovement"}, {CharacterClass, "SampleInput"}, {Controls, "moveFunction"}, {Controls, "GetMoveVector"}}
for _, dependency in ipairs(required) do
    if type(dependency[1]) ~= "table" or type(dependency[1][dependency[2]]) ~= "function" then error("voidsense.cc: incompatible game API " .. dependency[2]) end
end
local Previous = getgenv().BloxStrikeArvn
if Previous and type(Previous.Eject) == "function" then pcall(Previous.Eject) end
local Arvn = createArvn()
local Runtime = (function()
local Runtime = {Tasks = {}, Errors = {}, Alive = true}
function Runtime:Every(name, interval, callback)
    self.Tasks[name] = {Interval = interval, NextAt = 0, Callback = callback, Count = 0, Total = 0, Maximum = 0, Failures = 0, ErrorCount = 0, ErrorWindow = 0}
end
function Runtime:Tick(now)
    if not self.Alive then return end
    for name, taskState in pairs(self.Tasks) do
        if now >= taskState.NextAt and taskState.Failures < 3 then
            taskState.NextAt = now + taskState.Interval
            local started = os.clock()
            local ok, err = xpcall(taskState.Callback, debug.traceback)
            local elapsed = os.clock() - started
            taskState.Count += 1
            taskState.Total += elapsed
            taskState.Maximum = math.max(taskState.Maximum, elapsed)
            if ok then taskState.Failures = 0 else
                if now - taskState.ErrorWindow > 60 then taskState.ErrorWindow = now; taskState.ErrorCount = 0 end
                taskState.ErrorCount += 1
                taskState.Failures += 1
                if taskState.ErrorCount >= 3 then taskState.Failures = 3 end
                self.Errors[name] = tostring(err)
                if taskState.Failures == 1 or taskState.Failures == 3 then warn("voidsense.cc " .. name .. ": " .. tostring(err)) end
            end
        end
    end
end
function Runtime:Snapshot()
    local result = {}
    for name, taskState in pairs(self.Tasks) do
        result[name] = {Calls = taskState.Count, AverageMs = taskState.Count > 0 and taskState.Total / taskState.Count * 1000 or 0, MaximumMs = taskState.Maximum * 1000, Disabled = taskState.Failures >= 3, Error = self.Errors[name]}
    end
    return result
end
function Runtime:Stop()
    self.Alive = false
    table.clear(self.Tasks)
end
return Runtime

end)()
local Window = Arvn:CreateWindow({Title = "voidsense.cc", Author = "vlad", Version = "3.0", Folder = "NetanyahuCC/" .. tostring(LocalPlayer.UserId), MenuKey = "RightShift", Theme = "Purple", Accent = Color3.fromRGB(154, 107, 255), Watermark = false, ShowErrors = true})
local Flags = Arvn.Flags
local function palette(flag, fallback)
    local value = Flags[flag]
    if typeof(value) == "Color3" then return value end
    if type(value) == "string" then
        local hex = value:match("#?(%x%x%x%x%x%x)")
        if hex then return Color3.fromHex(hex) end
    end
    return fallback
end

local Drawings = {}
local PlayerDrawings = {}
local ObjectDrawings = {}
local Highlights = {}
local HookRestores = {}
local Running = true
local Public = {Flags = Flags, Window = Window, Library = Arvn, SkinStudio = nil}
getgenv().BloxStrikeArvn = Public
getgenv().NetanyahuCC = Public
getgenv().VoidsenseCC = Public
Public.Runtime = Runtime
Public.Compatibility = {Missing = {}, PlaceVersion = game.PlaceVersion}
Public.GetPerformance = function() return Runtime:Snapshot() end
Arvn:Connect(Characters.ChildAdded, function(model) if not table.find(CharacterModels, model) then CharacterModels[#CharacterModels + 1] = model end end)
Arvn:Connect(Characters.ChildRemoved, function(model) local index = table.find(CharacterModels, model); if index then table.remove(CharacterModels, index) end end)
Public.CursorState = {Open = false, Applying = false, Behavior = UserInputService.MouseBehavior, Icon = UserInputService.MouseIconEnabled}
function Public.UpdateCursor()
    local state = Public.CursorState
    if state.Applying then return end
    local open = Running and Arvn:IsOpen()
    state.Applying = true
    if open then
        if not state.Open then
            state.Behavior = UserInputService.MouseBehavior
            state.Icon = UserInputService.MouseIconEnabled
            state.Open = true
        end
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    elseif state.Open then
        state.Open = false
        UserInputService.MouseBehavior = state.Behavior
        UserInputService.MouseIconEnabled = state.Icon
    end
    state.Applying = false
end
Public.CursorState.Connection = UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
    if Running and Arvn:IsOpen() then Public.UpdateCursor() end
end)
RunService:BindToRenderStep("BloxStrikeArvnCursor", Enum.RenderPriority.Last.Value + 100, Public.UpdateCursor)
Public.LegitState = {Model = nil, Since = 0, ReadyAt = 0}
Public.BodyEffects = {Root = nil, Objects = {}}
function Public.ResetBodyEffects()
    for _, object in ipairs(Public.BodyEffects.Objects) do object:Destroy() end
    Public.BodyEffects = {Root = nil, Objects = {}}
end
local function resetBodyEffectState(state)
    for _, object in ipairs(state.Objects) do object:Destroy() end
    table.clear(state)
    state.Objects = {}
end
local function updateBodyEffectsFor(model, state, Flags)
    local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
    local enabled = Flags.body_sparkles or Flags.body_glow or Flags.body_aura or Flags.body_trail
    if not root or not enabled then
        if state.Root then resetBodyEffectState(state) end
        return
    end
    if state.Root ~= root then
        resetBodyEffectState(state)
        state.Root = root
        local function create(class, parent)
            local object = newInstance(class)
            object.Name = "BloxStrikeBodyEffect"
            object.Parent = parent
            state.Objects[#state.Objects + 1] = object
            return object
        end
        state.Anchor = create("Attachment", root)
        state.Sparkles = create("ParticleEmitter", state.Anchor)
        state.Sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        state.Sparkles.Lifetime = NumberRange.new(0.4, 0.9)
        state.Sparkles.Speed = NumberRange.new(0.5, 2)
        state.Sparkles.SpreadAngle = Vector2.new(180, 180)
        state.Sparkles.LightEmission = 1
        state.Sparkles.Transparency = NumberSequence.new(0, 1)
        state.Aura = create("ParticleEmitter", state.Anchor)
        state.Aura.Texture = "rbxasset://textures/particles/smoke_main.dds"
        state.Aura.Lifetime = NumberRange.new(0.7, 1.3)
        state.Aura.Speed = NumberRange.new(1, 2)
        state.Aura.SpreadAngle = Vector2.new(180, 180)
        state.Aura.LightEmission = 0.8
        state.Aura.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.75), NumberSequenceKeypoint.new(1, 1)})
        state.Light = create("PointLight", root)
        state.Light.Shadows = false
        state.Top = create("Attachment", root)
        state.Top.Position = Vector3.new(0, 1, 0)
        state.Bottom = create("Attachment", root)
        state.Bottom.Position = Vector3.new(0, -1, 0)
        state.Trail = create("Trail", root)
        state.Trail.Attachment0 = state.Top
        state.Trail.Attachment1 = state.Bottom
        state.Trail.FaceCamera = true
        state.Trail.LightEmission = 1
        state.Trail.Transparency = NumberSequence.new(0.2, 1)
        state.Trail.WidthScale = NumberSequence.new(1, 0)
    end
    local color = Flags.body_rainbow and Color3.fromHSV((os.clock() * (Flags.body_rainbow_speed or 15) / 100) % 1, 0.85, 1) or Flags.body_effect_color or Color3.fromRGB(166, 112, 255)
    state.Sparkles.Enabled = Flags.body_sparkles == true
    state.Sparkles.Color = ColorSequence.new(color)
    state.Sparkles.Rate = Flags.body_effect_density or 25
    state.Sparkles.Size = NumberSequence.new(Flags.body_sparkle_size or 0.2)
    state.Aura.Enabled = Flags.body_aura == true
    state.Aura.Color = ColorSequence.new(color)
    state.Aura.Rate = (Flags.body_effect_density or 25) * 0.5
    state.Aura.Size = NumberSequence.new(1, 3)
    state.Light.Enabled = Flags.body_glow == true
    state.Light.Color = color
    state.Light.Brightness = Flags.body_glow_brightness or 1
    state.Light.Range = 10
    if state.Trail.Enabled and not Flags.body_trail then state.Trail:Clear() end
    state.Trail.Enabled = Flags.body_trail == true
    state.Trail.Color = ColorSequence.new(color)
    state.Trail.Lifetime = Flags.body_trail_lifetime or 0.5
end
function Public.UpdateBodyEffects()
    local options = table.clone(Flags)
    options.body_effect_color = palette("body_effect_color", Color3.fromRGB(166, 112, 255))
    updateBodyEffectsFor(Characters:FindFirstChild(LocalPlayer.Name), Public.BodyEffects, options)
end
Public.SurfaceVisuals = {Body = {}, Map = {}, Root = nil, ScanAt = 0, Signature = nil, Highlight = nil}
Public.Ragdolls = {}
Public.RagdollsConfirmed = false
function Public.UpdateRagdolls()
    if not Flags.ragdoll_style then
        Public.SurfaceVisuals.Restore(Public.Ragdolls)
        return
    end
    local debris = workspace:FindFirstChild("Debris")
    if not debris then return end
    for item in pairs(Public.Ragdolls) do
        if not item:IsDescendantOf(debris) then
            pcall(function() for key, value in pairs(Public.Ragdolls[item]) do item[key] = value end end)
            Public.Ragdolls[item] = nil
        end
    end
    for _, model in ipairs(debris:GetChildren()) do
        if model:IsA("Model") and model:GetAttribute("ClientRagdoll") and not model:GetAttribute("RagdollStaged") then
            for _, item in ipairs(model:GetDescendants()) do
                if item:IsA("BasePart") then
                    Public.SurfaceVisuals.Save(Public.Ragdolls, item, "Color")
                    Public.SurfaceVisuals.Save(Public.Ragdolls, item, "Material")
                    Public.SurfaceVisuals.Save(Public.Ragdolls, item, "LocalTransparencyModifier")
                    local material = Flags.ragdoll_material or "Original"
                    item.Color = palette("ragdoll_color", Color3.fromRGB(154, 107, 255))
                    item.Material = material == "Original" and Public.Ragdolls[item].Material or Enum.Material[material]
                    item.LocalTransparencyModifier = Flags.ragdoll_hide and 1 or Public.Ragdolls[item].LocalTransparencyModifier
                end
            end
        end
    end
end
function Public.SurfaceVisuals.Restore(saved)
    for item, properties in pairs(saved) do
        pcall(function() for key, value in pairs(properties) do item[key] = value end end)
        saved[item] = nil
    end
end
function Public.SurfaceVisuals.Save(saved, item, property)
    if not saved[item] then saved[item] = {} end
    if saved[item][property] == nil then saved[item][property] = item[property] end
end
function Public.SurfaceVisuals.Reset()
    Public.ResetBodyEffects()
    Public.SurfaceVisuals.Restore(Public.Ragdolls)
    local state = Public.SurfaceVisuals
    state.Restore(state.Body)
    state.Restore(state.Map)
    if state.Highlight then state.Highlight:Destroy(); state.Highlight = nil end
    state.Root = nil
    state.Signature = nil
    state.ScanAt = 0
end
function Public.SurfaceVisuals.Update()
    local state = Public.SurfaceVisuals
    local model = Characters:FindFirstChild(LocalPlayer.Name)
    if (Flags.body_style or Flags.body_rainbow) and model then
        for item in pairs(state.Body) do
            if not item:IsDescendantOf(model) then
                pcall(function() for key, value in pairs(state.Body[item]) do item[key] = value end end)
                state.Body[item] = nil
            end
        end
        local color = Flags.body_rainbow and Color3.fromHSV((os.clock() * (Flags.body_rainbow_speed or 15) / 100) % 1, 0.85, 1) or palette("body_color", Color3.fromRGB(166, 112, 255))
        local material = Flags.body_material or "Original"
        for _, item in ipairs(model:GetChildren()) do
            if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
                state.Save(state.Body, item, "Color")
                state.Save(state.Body, item, "Material")
                state.Save(state.Body, item, "Reflectance")
                item.Color = color
                item.Material = Flags.body_style and material ~= "Original" and Enum.Material[material] or state.Body[item].Material
                item.Reflectance = Flags.body_style and (Flags.body_reflectance or 0) / 100 or state.Body[item].Reflectance
            end
        end
    else state.Restore(state.Body) end
    if Flags.body_outline and model then
        if not state.Highlight then
            state.Highlight = newInstance("Highlight")
            state.Highlight.Name = "BloxStrikeBodyOutline"
            state.Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
            state.Highlight.Parent = workspace
        end
        state.Highlight.Adornee = model
        state.Highlight.Enabled = true
        state.Highlight.FillTransparency = 1
        state.Highlight.OutlineTransparency = (Flags.body_outline_transparency or 0) / 100
        state.Highlight.OutlineColor = palette("body_outline_color", Color3.fromRGB(235, 219, 255))
    elseif state.Highlight then state.Highlight:Destroy(); state.Highlight = nil end
    local root = workspace:FindFirstChild("Map")
    if not Flags.map_style or not root then
        if state.Root or next(state.Map) then state.Restore(state.Map) end
        state.Root = nil
        state.Signature = nil
        return
    end
    local color = palette("map_surface_color", Color3.fromRGB(126, 98, 166))
    local material = Flags.map_material or "Original"
    local signature = color:ToHex() .. material .. tostring(Flags.map_recolor) .. tostring(Flags.map_hide_textures)
    if root ~= state.Root or signature ~= state.Signature then
        state.Restore(state.Map)
        state.Root = root
        state.Signature = signature
        state.ScanAt = 0
    end
    if os.clock() < state.ScanAt then return end
    state.ScanAt = os.clock() + 1
    for item in pairs(state.Map) do if not item:IsDescendantOf(root) then
        pcall(function() for key, value in pairs(state.Map[item]) do item[key] = value end end)
        state.Map[item] = nil
    end end
    for _, item in ipairs(root:GetDescendants()) do
        if item:IsA("BasePart") and item.Transparency < 1 then
            if Flags.map_recolor then state.Save(state.Map, item, "Color"); item.Color = color end
            if material ~= "Original" then state.Save(state.Map, item, "Material"); item.Material = Enum.Material[material] end
            if Flags.map_hide_textures and item:IsA("MeshPart") then
                state.Save(state.Map, item, "TextureID")
                pcall(function() item.TextureID = "" end)
            end
        elseif Flags.map_hide_textures and (item:IsA("Decal") or item:IsA("Texture")) then
            state.Save(state.Map, item, "Transparency")
            item.Transparency = 1
        end
    end
end
local LastTrigger = 0
local RageTargetModel = nil
local RageTargetSince = 0
local MotionSamples = setmetatable({}, {__mode = "k"})
local AimDiagnostics = {Hitbox = "none", LeadMs = 0, Speed = 0}
Public.GetAimState = function() return table.clone(AimDiagnostics) end
local ShotTracers = {}
Public.TracerFolder = newInstance("Folder")
Public.TracerFolder.Name = "VoidsenseBulletTracers"
Public.TracerFolder.Parent = workspace
function Public.DestroyShotTracer(trace)
    if trace.Part then trace.Part:Destroy() end
    if trace.Glow then trace.Glow:Destroy() end
end
function Public.ClearShotTracers()
    for _, trace in ipairs(ShotTracers) do Public.DestroyShotTracer(trace) end
    table.clear(ShotTracers)
end
function Public.CreateTracerPart(origin, endpoint, width, material, color, transparency)
    local delta = endpoint - origin
    local part = newInstance("Part")
    part.Name = "Tracer"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Size = Vector3.new(width, width, delta.Magnitude)
    part.CFrame = CFrame.lookAt(origin + delta * 0.5, endpoint)
    part.Material = material
    part.Color = color
    part.Transparency = transparency
    part.Parent = Public.TracerFolder
    return part
end
local PendingHits = {}
local HitmarkerUntil = 0
Public.CombatAudio = {Sounds = {}, Index = 0}
function Public.PlayCombatSound(kind)
    if not Running or not Flags[kind .. "_sound"] then return nil end
    local preset = Flags[kind .. "_sound_preset"] or (kind == "hit" and "Tick" or kind == "shot" and "Mech" or "Chime")
    if preset == "None" then return nil end
    local state = Public.CombatAudio
    state.Index = state.Index % 6 + 1
    local sound = state.Sounds[state.Index]
    if not sound then
        sound = newInstance("Sound")
        sound.Name = "VoidsenseCombatSound"
        sound.Parent = game:GetService("SoundService")
        state.Sounds[state.Index] = sound
    end
    sound:Stop()
    local asset = preset == "Custom" and tostring(Flags[kind .. "_sound_id"] or ""):match("^%s*(%d+)%s*$") or nil
    local libraryAsset = type(Arvn.GetSoundAsset) == "function" and Arvn:GetSoundAsset(preset) or nil
    sound.SoundId = asset and "rbxassetid://" .. asset or libraryAsset or "rbxasset://sounds/electronicpingshort.wav"
    sound.Volume = math.clamp((Flags[kind .. "_sound_volume"] or 50) / 100, 0, 1)
    sound.PlaybackSpeed = preset == "Custom" and (kind == "hit" and 1.35 or 0.75) or 1
    sound:Play()
    return sound
end
do
    local kills = LocalPlayer:GetAttribute("Kills") or 0
    Arvn:Connect(LocalPlayer:GetAttributeChangedSignal("Kills"), function()
        local current = LocalPlayer:GetAttribute("Kills") or 0
        if current > kills then Public.PlayCombatSound("kill") end
        kills = current
    end)
end
local CurrentTarget = nil
local LastDodge = 0
local DodgeSide = 1
local LastStrafeYaw = nil
local StrafeSide = 1
local AutoPeekOrigin = nil
local AutoPeekModel = nil
local AutoPeekReturning = false
local OriginalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local OriginalLighting = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd}
local Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local OriginalDensity = Atmosphere and Atmosphere.Density or nil
local EnvironmentOriginal = {GlobalShadows = Lighting.GlobalShadows, ColorShift_Top = Lighting.ColorShift_Top, ColorShift_Bottom = Lighting.ColorShift_Bottom}
local SavedSkies = {}
local EnvironmentSky = nil
local EnvironmentColor = nil
local EnvironmentBloom = nil
local EnvironmentActive = false
local function restoreEnvironment()
    if EnvironmentSky then EnvironmentSky:Destroy(); EnvironmentSky = nil end
    if EnvironmentColor then EnvironmentColor:Destroy(); EnvironmentColor = nil end
    if EnvironmentBloom then EnvironmentBloom:Destroy(); EnvironmentBloom = nil end
    for sky, parent in pairs(SavedSkies) do sky.Parent = parent end
    table.clear(SavedSkies)
    if EnvironmentActive then
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
        Lighting.GlobalShadows = EnvironmentOriginal.GlobalShadows
        Lighting.ColorShift_Top = EnvironmentOriginal.ColorShift_Top
        Lighting.ColorShift_Bottom = EnvironmentOriginal.ColorShift_Bottom
    end
    EnvironmentActive = false
end

local function applyEnvironment()
    if not Flags.environment then
        if EnvironmentActive then restoreEnvironment() end
        return
    end
    EnvironmentActive = true
    local preset = Flags.sky_preset or "Original"
    if preset ~= "Original" then
        for _, sky in ipairs(Lighting:GetChildren()) do
            if sky:IsA("Sky") and sky ~= EnvironmentSky then SavedSkies[sky] = Lighting; sky.Parent = nil end
        end
        if not EnvironmentSky then
            EnvironmentSky = newInstance("Sky")
            EnvironmentSky.Name = "BloxStrikeArvnSky"
            for property, face in pairs({SkyboxBk = "bk", SkyboxDn = "dn", SkyboxFt = "ft", SkyboxLf = "lf", SkyboxRt = "rt", SkyboxUp = "up"}) do
                EnvironmentSky[property] = "rbxasset://textures/sky/sky512_" .. face .. ".tex"
            end
            EnvironmentSky.Parent = Lighting
        end
        EnvironmentSky.StarCount = preset == "Night" and 3000 or 0
        Lighting.ClockTime = preset == "Night" and 0 or preset == "Sunset" and 18 or 14
    else
        if EnvironmentSky then EnvironmentSky:Destroy(); EnvironmentSky = nil end
        for sky, parent in pairs(SavedSkies) do sky.Parent = parent end
        table.clear(SavedSkies)
        Lighting.ClockTime = Flags.environment_time or OriginalLighting.ClockTime
    end
    Lighting.Brightness = Flags.environment_brightness or 2
    Lighting.Ambient = palette("ambient_color", Color3.fromRGB(100, 70, 140))
    Lighting.OutdoorAmbient = palette("outdoor_color", Color3.fromRGB(80, 60, 115))
    Lighting.GlobalShadows = not Flags.environment_no_shadows
    if not EnvironmentColor then EnvironmentColor = newInstance("ColorCorrectionEffect"); EnvironmentColor.Name = "BloxStrikeArvnColor"; EnvironmentColor.Parent = Lighting end
    EnvironmentColor.Enabled = not Flags.remove_post
    EnvironmentColor.TintColor = palette("world_color", Color3.fromRGB(235, 219, 255))
    EnvironmentColor.Contrast = (Flags.world_contrast or 0) / 100
    EnvironmentColor.Saturation = (Flags.world_saturation or 0) / 100
    if not EnvironmentBloom then EnvironmentBloom = newInstance("BloomEffect"); EnvironmentBloom.Name = "BloxStrikeArvnBloom"; EnvironmentBloom.Parent = Lighting end
    EnvironmentBloom.Enabled = Flags.environment_bloom == true and not Flags.remove_post
    EnvironmentBloom.Intensity = (Flags.bloom_intensity or 20) / 100
    EnvironmentBloom.Size = 24
    EnvironmentBloom.Threshold = 1
end
local PostEffects = {}
local ViewPartOriginals = {}
local FinishColors = {Crimson = Color3.fromRGB(204, 54, 69), Cyan = Color3.fromRGB(58, 197, 233), Gold = Color3.fromRGB(238, 189, 64), Violet = Color3.fromRGB(157, 92, 227), Green = Color3.fromRGB(80, 205, 120)}
local SkinOptions = {"Stock"}
local SkinOriginals = {}
local LastSkinWeapon = nil
local AppliedSkinKey = nil
local AppliedSkinModel = nil
local SkinInfo = nil
local GloveTypes = {"Default"}
local GloveSkins = {"Stock"}
local LastGloveType = nil
local AppliedGloveKey = nil
local AppliedGloveModel = nil
local GloveOriginals = {}
local GloveInfo = nil
local ThirdPersonOriginal = CameraController.setPerspective
local ThirdPersonApplied = false
Public.ThirdPersonState = {}
Public.CameraZoomOriginal = {Min = LocalPlayer.CameraMinZoomDistance, Max = LocalPlayer.CameraMaxZoomDistance}
local ThirdPersonMouseMode = false
local HiddenViewmodelParts = {}
local VisibleCharacterParts = {}
local ThirdPersonPose = nil
local ThirdPersonPoseModel = nil
local ThirdPersonWeapon = nil
local ThirdPersonWeaponKey = nil
local ThirdPersonWeaponOwner = nil
local ThirdPersonWeaponMotors = {}
local LastAutoAttempt = 0
local LastAutoWeapon = nil
local AutoFireStats = {Attempts = 0, Shots = 0, Status = "idle"}
Public.GetAutoFireState = function() return table.clone(AutoFireStats) end
Public.WeaponProfiles = {
    Groups = {"Pistol", "Rifle", "Sniper"},
    Logs = {},
    LastScope = 0,
    Current = "Global",
}
function Public.WeaponProfiles.Group()
    local weapon = InventoryController.peekCurrentEquippedForMovement()
    if not weapon then return "Global" end
    if weapon.Name == "AWP" or weapon.Name == "SSG 08" or weapon.Name == "G3SG1" or weapon.Name == "SCAR-20" then return "Sniper" end
    if weapon.Slot == 2 then return "Pistol" end
    if weapon.Slot == 1 then return "Rifle" end
    return "Global"
end
function Public.WeaponProfiles.Get(key, fallback)
    local group = Public.WeaponProfiles.Group()
    Public.WeaponProfiles.Current = group
    if Flags.weapon_profiles and group ~= "Global" then
        local value = Flags["profile_" .. group .. "_" .. key]
        if value ~= nil then return value end
    end
    local value = Flags[key]
    if value ~= nil then return value end
    return fallback
end

local function clearThirdPersonWeapon()
    for _, motor in ipairs(ThirdPersonWeaponMotors) do motor:Destroy() end
    table.clear(ThirdPersonWeaponMotors)
    if ThirdPersonWeapon then ThirdPersonWeapon:Destroy() end
    ThirdPersonWeapon = nil
    ThirdPersonWeaponKey = nil
    ThirdPersonWeaponOwner = nil
end

local function restoreThirdPersonPose()
    if ThirdPersonPose then
        for _, name in ipairs({"RightShoulder", "LeftShoulder", "Waist", "Neck"}) do
            local joint = ThirdPersonPose[name]
            local base = ThirdPersonPose["Base" .. name .. "C0"]
            if joint and joint.Parent and base then joint.C0 = base end
        end
    end
    ThirdPersonPose = nil
    ThirdPersonPoseModel = nil
end

local function updateThirdPersonPresentation()
    local model = Characters:FindFirstChild(LocalPlayer.Name)
    local cam = workspace.CurrentCamera
    if not Flags.force_thirdperson or not model or not cam then return end
    if ThirdPersonPoseModel ~= model then
        restoreThirdPersonPose()
        ThirdPersonPose = CharacterPose.getJoints(model)
        ThirdPersonPoseModel = model
    end
    if ThirdPersonPose then
        local pitch = math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)) / (math.pi * 0.5)
        if Flags.anti_aim then
            if Flags.anti_aim_pitch == "Up" then pitch = 1 elseif Flags.anti_aim_pitch == "Down" then pitch = -1 end
        end
        CharacterPose.applyVerticalLook(ThirdPersonPose, pitch)
    end
    local raw = LocalPlayer:GetAttribute("CurrentEquipped")
    if type(raw) ~= "string" then clearThirdPersonWeapon(); return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok or type(data) ~= "table" or type(data.Name) ~= "string" then return end
    if Flags.skin_changer and Public.SkinStudio then
        local selected = Flags.skin_knife_model
        local knife = data.Name == "Karambit" or data.Name == "M9 Bayonet" or string.find(data.Name, "Knife", 1, true)
        if knife and type(selected) == "string" and selected ~= "" then data.Name = selected end
        local choice = Public.SkinStudio.Loadout.Weapons[data.Name]
        if choice then
            data.Skin = choice.Skin
            data.Float = ({["Factory New"] = 0.03, ["Minimal Wear"] = 0.1, ["Field-Tested"] = 0.25, ["Well-Worn"] = 0.4, ["Battle-Scarred"] = 0.7})[choice.Wear] or 0.03
        end
    end
    local key = table.concat({data.Name, tostring(data.Identifier), tostring(data.Skin), tostring(data.Float), tostring(data.IsSuppressed)}, "|")
    if ThirdPersonWeaponOwner == model and ThirdPersonWeaponKey == key and ThirdPersonWeapon and ThirdPersonWeapon.Parent then return end
    clearThirdPersonWeapon()
    local created, weapon = pcall(CharacterSkins.GetCharacterModel, data.Name, data.Skin, data.Float, data.StatTrack, data.NameTag, false, data.Stickers)
    if not created or not weapon or not weapon:IsA("Model") then return end
    local jointPart = model:FindFirstChild(WeaponAttachments.WEAPON_JOINT_PARTS[data.Name] or WeaponAttachments.DEFAULT_JOINT_PART)
    local primary = weapon.PrimaryPart or weapon:FindFirstChild("Insert", true)
    if not jointPart or not primary then weapon:Destroy(); return end
    local hidden = {MuzzlePartL = true, MuzzlePartR = true, MuzzlePart = true, RootPart = true, Hitbox = true, Insert = true, move = true}
    for _, part in ipairs(weapon:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Anchored = false
            part.Massless = true
            part.LocalTransparencyModifier = 0
            if hidden[part.Name] then part.Transparency = 1 end
        end
    end
    local properties = weapon:FindFirstChild("Properties")
    local function attach(hand, handle, suffix)
        local motor = newInstance("Motor6D")
        motor.Name = "BloxStrikeArvnWeapon"
        motor.Part0 = hand
        motor.Part1 = handle
        local c0 = properties and properties:FindFirstChild("C0" .. suffix)
        local c1 = properties and properties:FindFirstChild("C1" .. suffix)
        if c0 and c0:IsA("CFrameValue") then motor.C0 = c0.Value end
        if c1 and c1:IsA("CFrameValue") then motor.C1 = c1.Value end
        handle.CFrame = hand.CFrame * motor.C0 * motor.C1:Inverse()
        motor.Parent = hand
        ThirdPersonWeaponMotors[#ThirdPersonWeaponMotors + 1] = motor
    end
    local left = weapon:FindFirstChild("HandleL", true)
    local right = weapon:FindFirstChild("HandleR", true)
    if left and right and model:FindFirstChild("LeftHand") and model:FindFirstChild("RightHand") then
        attach(model.LeftHand, left, "LEFT")
        attach(model.RightHand, right, "RIGHT")
    else
        attach(jointPart, primary, "")
    end
    weapon.Name = "BloxStrikeArvnThirdPersonWeapon"
    weapon.Parent = model
    ThirdPersonWeapon = weapon
    ThirdPersonWeaponKey = key
    ThirdPersonWeaponOwner = model
end

local function skinsRoot()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Skins") or nil
end

local function weaponsRoot()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Weapons") or nil
end

local function getCameraWeapon(cam)
    local skins = skinsRoot()
    if not cam or not skins then return nil, skins end
    for _, child in ipairs(cam:GetChildren()) do
        if child:IsA("Model") and skins:FindFirstChild(child.Name) then return child, skins end
    end
    return nil, skins
end

local function setViewmodelHidden(hidden)
    if hidden then
        local model = getCameraWeapon(workspace.CurrentCamera)
        if not model then return end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                if HiddenViewmodelParts[part] == nil then HiddenViewmodelParts[part] = part.LocalTransparencyModifier end
                part.LocalTransparencyModifier = 1
            end
        end
        return
    end
    for part, transparency in pairs(HiddenViewmodelParts) do
        if part.Parent then part.LocalTransparencyModifier = transparency end
        HiddenViewmodelParts[part] = nil
    end
end

local function thirdPersonAvailable()
    local model = Characters:FindFirstChild(LocalPlayer.Name)
    local alive = model and not model:GetAttribute("Dead") and (model:GetAttribute("Health") or 0) > 0
    local mainGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MainGui")
    local bottom = mainGui and mainGui:FindFirstChild("Gameplay") and mainGui.Gameplay:FindFirstChild("Bottom")
    return alive and not LocalPlayer:GetAttribute("IsSpectating") and bottom and bottom.Visible
end

local function restoreThirdPerson()
    setViewmodelHidden(false)
    clearThirdPersonWeapon()
    restoreThirdPersonPose()
    for part, value in pairs(VisibleCharacterParts) do
        if part.Parent then part.LocalTransparencyModifier = value end
        VisibleCharacterParts[part] = nil
    end
    if not ThirdPersonApplied then return end
    ThirdPersonApplied = false
    table.clear(Public.ThirdPersonState)
    LocalPlayer.CameraMaxZoomDistance = Public.CameraZoomOriginal.Max
    LocalPlayer.CameraMinZoomDistance = Public.CameraZoomOriginal.Min
    if type(ThirdPersonOriginal) == "function" and thirdPersonAvailable() and not ThirdPersonMouseMode then
        pcall(ThirdPersonOriginal, true, Arvn:IsOpen())
    end
end

local function applyThirdPerson()
    if not Flags.force_thirdperson or not thirdPersonAvailable() or type(ThirdPersonOriginal) ~= "function" then
        restoreThirdPerson()
        return
    end
    local state = Public.ThirdPersonState
    local owner = Characters:FindFirstChild(LocalPlayer.Name)
    local cam = workspace.CurrentCamera
    local distance = Flags.thirdperson_distance or 8
    local menu = Arvn:IsOpen()
    local changed = not ThirdPersonApplied or state.Owner ~= owner or state.Camera ~= cam or state.Distance ~= distance or state.Menu ~= menu
    local ok = true
    if changed then
        ok = pcall(ThirdPersonOriginal, false, menu, distance)
        if ok then state.Owner = owner; state.Camera = cam; state.Distance = distance; state.Menu = menu end
    end
    if ok then
        ThirdPersonApplied = true
        LocalPlayer.CameraMaxZoomDistance = Flags.thirdperson_distance or 8
        LocalPlayer.CameraMinZoomDistance = Flags.thirdperson_distance or 8
        setViewmodelHidden(true)
        local model = Characters:FindFirstChild(LocalPlayer.Name)
        if model then
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency < 1 then
                    if VisibleCharacterParts[part] == nil then VisibleCharacterParts[part] = part.LocalTransparencyModifier end
                    part.LocalTransparencyModifier = 0
                end
            end
        end
    end
end


function Public.CreateSharedWeapon(model, data, state)
    local created, weapon = pcall(CharacterSkins.GetCharacterModel, data.Name, data.Skin, data.Float, data.StatTrack, data.NameTag, false, data.Stickers)
    if not created or not weapon or not weapon:IsA("Model") then return end
    local jointPart = model:FindFirstChild(WeaponAttachments.WEAPON_JOINT_PARTS[data.Name] or WeaponAttachments.DEFAULT_JOINT_PART)
    local primary = weapon.PrimaryPart or weapon:FindFirstChild("Insert", true)
    if not jointPart or not primary then weapon:Destroy(); return end
    local hidden = {MuzzlePartL = true, MuzzlePartR = true, MuzzlePart = true, RootPart = true, Hitbox = true, Insert = true, move = true}
    for _, part in ipairs(weapon:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Anchored = false
            part.Massless = true
            part.LocalTransparencyModifier = 0
            if hidden[part.Name] then part.Transparency = 1 end
        end
    end
    local properties = weapon:FindFirstChild("Properties")
    local function attach(hand, handle, suffix)
        local motor = newInstance("Motor6D")
        motor.Name = "BloxStrikeArvnWeapon"
        motor.Part0 = hand
        motor.Part1 = handle
        local c0 = properties and properties:FindFirstChild("C0" .. suffix)
        local c1 = properties and properties:FindFirstChild("C1" .. suffix)
        if c0 and c0:IsA("CFrameValue") then motor.C0 = c0.Value end
        if c1 and c1:IsA("CFrameValue") then motor.C1 = c1.Value end
        handle.CFrame = hand.CFrame * motor.C0 * motor.C1:Inverse()
        motor.Parent = hand
        state.Motors[#state.Motors + 1] = motor
    end
    local left = weapon:FindFirstChild("HandleL", true)
    local right = weapon:FindFirstChild("HandleR", true)
    if left and right and model:FindFirstChild("LeftHand") and model:FindFirstChild("RightHand") then
        attach(model.LeftHand, left, "LEFT")
        attach(model.RightHand, right, "RIGHT")
    else
        attach(jointPart, primary, "")
    end
    weapon.Name = "BloxStrikeArvnThirdPersonWeapon"
    weapon.Parent = model
    state.Weapon = weapon
end

local function drawing(kind, properties)
    local item = Drawing.new(kind)
    for key, value in pairs(properties) do item[key] = value end
    Drawings[#Drawings + 1] = item
    return item
end

local function removeDrawing(item)
    pcall(function() item:Remove() end)
    for i = #Drawings, 1, -1 do
        if Drawings[i] == item then table.remove(Drawings, i); break end
    end
end

local function removeNested(items)
    for _, item in pairs(items) do
        if typeof(item) == "table" then removeNested(item) elseif item then removeDrawing(item) end
    end
end

local function hide(items)
    for _, item in pairs(items) do
        if typeof(item) == "table" then hide(item) elseif item and item.Visible then item.Visible = false end
    end
end

local function camera()
    return workspace.CurrentCamera
end

local function localModel()
    return Characters:FindFirstChild(LocalPlayer.Name)
end

local function resetAutoPeek()
    AutoPeekOrigin = nil
    AutoPeekModel = nil
    AutoPeekReturning = false
end

local function captureAutoPeek()
    if not Flags.auto_peek then
        resetAutoPeek()
        return
    end
    local model = localModel()
    local root = model and model.PrimaryPart
    if not root then
        resetAutoPeek()
        return
    end
    if AutoPeekModel ~= model or not AutoPeekOrigin then
        AutoPeekOrigin = root.Position
        AutoPeekModel = model
        AutoPeekReturning = false
    end
end

local function playerOf(model)
    return Players:FindFirstChild(model.Name)
end

local function characterOf(instance)
    local current = instance
    while current and current.Parent ~= Characters do current = current.Parent end
    return current and current:IsA("Model") and current or nil
end

local function isEnemy(model)
    if model.Name == LocalPlayer.Name or model:GetAttribute("Dead") or (model:GetAttribute("Health") or 0) <= 0 then return false end
    local player = playerOf(model)
    if not player then return false end
    if Flags.team_check then
        local own = LocalPlayer:GetAttribute("Team")
        local other = player:GetAttribute("Team")
        if own and other and own == other then return false end
    end
    return true
end

local function isAlive(model)
    return model.Name ~= LocalPlayer.Name and not model:GetAttribute("Dead") and (model:GetAttribute("Health") or 0) > 0
end

local function isTeammate(model)
    local player = playerOf(model)
    local own = LocalPlayer:GetAttribute("Team")
    return player and own ~= nil and player:GetAttribute("Team") == own
end

local function recordShot(packet)
    if type(packet) ~= "table" or typeof(packet.Origin) ~= "Vector3" or typeof(packet.Direction) ~= "Vector3" or type(packet.Distance) ~= "number" then return end
    if Flags.bullet_tracers then
        if #ShotTracers >= 48 then
            local oldest = table.remove(ShotTracers, 1)
            if oldest then Public.DestroyShotTracer(oldest) end
        end
        local endpoint = packet.Origin + packet.Direction * math.clamp(packet.Distance, 0, 1200)
        for _, hit in ipairs(packet.Hits or {}) do
            if typeof(hit.Position) == "Vector3" then endpoint = hit.Position end
        end
        if (endpoint - packet.Origin).Magnitude > 0.01 then
            local color = palette("bullet_color", Color3.fromRGB(185, 137, 255))
            local material = ({Neon = Enum.Material.Neon, ForceField = Enum.Material.ForceField, Glass = Enum.Material.Glass, Metal = Enum.Material.Metal, SmoothPlastic = Enum.Material.SmoothPlastic})[Flags.bullet_material or "Neon"] or Enum.Material.Neon
            local width = math.clamp(Flags.bullet_width or 0.08, 0.02, 0.3)
            local lifetime = math.clamp(Flags.bullet_lifetime or 1.2, 0.2, 4)
            local transparency = material == Enum.Material.Glass and 0.2 or 0.05
            local trace = {Part = Public.CreateTracerPart(packet.Origin, endpoint, width, material, color, transparency), Width = width, Transparency = transparency, Created = os.clock(), Lifetime = lifetime, Expires = os.clock() + lifetime}
            if Flags.bullet_glow ~= false then trace.Glow = Public.CreateTracerPart(packet.Origin, endpoint, width * 2.5, Enum.Material.Neon, color, 0.8) end
            Debris:AddItem(trace.Part, lifetime)
            if trace.Glow then Debris:AddItem(trace.Glow, lifetime) end
            ShotTracers[#ShotTracers + 1] = trace
        end
    end
    if Flags.hitmarker or Flags.hit_sound then
        for _, hit in ipairs(packet.Hits or {}) do
            local model = hit and hit.Instance and characterOf(hit.Instance)
            local health = model and model:GetAttribute("Health")
            if model and model.Name ~= LocalPlayer.Name and type(health) == "number" and health > 0 then
                PendingHits[model] = {Health = health, Expires = os.clock() + 0.65}
                break
            end
        end
    end
end

local function partOf(model)
    local choice = Flags.target_part or "Head"
    if Public.WeaponProfiles.Get("head_only", false) or choice == "Head" then return model:FindFirstChild("Head") end
    if choice == "Chest" then return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart end
    if choice == "Stomach" then return model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart end
    return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
end

local function targetParts(model)
    if Public.WeaponProfiles.Get("head_only", false) then return {model:FindFirstChild("Head")} end
    if not Flags.multipoint and (Flags.target_part or "Head") ~= "All" then return {partOf(model)} end
    return {model:FindFirstChild("Head"), model:FindFirstChild("UpperTorso"), model:FindFirstChild("Torso"), model:FindFirstChild("LowerTorso"), model:FindFirstChild("HumanoidRootPart"), model.PrimaryPart}
end

local function updateMotion(dt)
    local now = os.clock()
    for _, model in ipairs(CharacterModels) do
        local root = model:IsA("Model") and model.PrimaryPart
        if root then
            local old = MotionSamples[model]
            local velocity = Vector3.zero
            if old and now - old.Time > 0.001 and now - old.Time < 0.25 then
                local delta = root.Position - old.Position
                local measured = delta / (now - old.Time)
                if delta.Magnitude < 10 and measured.Magnitude < 120 then
                    velocity = old.Velocity:Lerp(measured, 1 - math.exp(-45 * dt))
                end
            else
                local physical = root.AssemblyLinearVelocity
                if physical.Magnitude < 120 then velocity = physical end
            end
            MotionSamples[model] = {Position = root.Position, Time = now, Velocity = velocity}
        end
    end
end

local function aimPoint(part)
    local mode = Public.WeaponProfiles.Get("prediction_mode", "Off")
    local lead = mode == "Manual" and Public.WeaponProfiles.Get("prediction_time", 0) / 1000 or mode == "Adaptive" and math.clamp(LocalPlayer:GetNetworkPing() * 0.5, 0, 0.08) or 0
    local model = characterOf(part)
    local sample = model and MotionSamples[model]
    if sample and os.clock() - sample.Time > 0.25 then sample = nil end
    if mode == "Adaptive" and sample then lead = math.min(lead + math.max(0, os.clock() - sample.Time), 0.08) end
    local velocity = sample and sample.Velocity or part.AssemblyLinearVelocity
    if velocity.Magnitude > 120 then velocity = Vector3.zero end
    local offset = velocity * lead
    local limit = Flags.prediction_limit or 1.5
    if offset.Magnitude > limit then offset = offset.Unit * limit end
    if part.Name == "Head" then
        local localOffset = part.CFrame:VectorToObjectSpace(offset)
        local half = part.Size * 0.3
        offset = part.CFrame:VectorToWorldSpace(Vector3.new(math.clamp(localOffset.X, -half.X, half.X), math.clamp(localOffset.Y, -half.Y, half.Y), math.clamp(localOffset.Z, -half.Z, half.Z)))
    end
    return part.Position + offset, lead, velocity.Magnitude
end

local function visible(model, position)
    local cam = camera()
    if not cam then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local own = localModel()
    params.FilterDescendantsInstances = own and {own, cam} or {cam}
    params.CollisionGroup = "Bullet"
    local delta = position - cam.CFrame.Position
    local result = workspace:Raycast(cam.CFrame.Position, delta, params)
    if Flags.rage_aim and Flags.silent_aim and Public.WeaponProfiles.Get("head_only", false) then
        return result ~= nil and result.Instance == model:FindFirstChild("Head")
    end
    return result == nil or result.Instance:IsDescendantOf(model)
end

local function directPenetrationMode()
    return Flags.rage_penetration_mode == "Direct (experimental)" or Flags.rage_penetration_mode == "Extended (experimental)"
end

local function penetrationPacket(origin, direction, properties, selected)
    local cam = camera()
    local own = localModel()
    local ignore = own and {own, cam} or {cam}
    local distance = properties.Range or 500
    if selected and directPenetrationMode() and selected.Parent and isEnemy(selected.Parent) then
        local point = aimPoint(selected)
        local localPoint = selected.CFrame:PointToObjectSpace(point)
        local half = selected.Size * 0.3
        point = selected.CFrame:PointToWorldSpace(Vector3.new(math.clamp(localPoint.X, -half.X, half.X), math.clamp(localPoint.Y, -half.Y, half.Y), math.clamp(localPoint.Z, -half.Z, half.Z)))
        local delta = point - origin
        if delta.Magnitude > 0.001 and delta.Magnitude <= distance then
            return {Origin = origin, Direction = delta.Unit, Distance = delta.Magnitude, Hits = {{Position = point, Instance = selected, Material = selected.Material.Name, Normal = -delta.Unit, Exit = false}}}
        end
    end
    local first = WeaponRaycast.cast(origin, direction * distance, nil, ignore)
    local packet = {Origin = origin, Direction = direction, Distance = distance, Hits = {}}
    if not first.instance then return packet end
    packet.Distance = (first.position - origin).Magnitude
    local depth = properties.Penetration or 0
    local intersections = WeaponRaycast.castThrough(first.position - direction * 0.001, direction * (depth + 0.001), depth, ignore)
    for i, hit in ipairs(intersections) do
        if hit.instance and hit.material and (hit.position - origin).Magnitude <= distance then
            packet.Hits[#packet.Hits + 1] = {Position = hit.position, Instance = hit.instance, Material = hit.material.Name, Normal = hit.normal or Vector3.zero, Exit = i % 2 == 0}
        end
    end
    return packet
end

local PenetrationCache = setmetatable({}, {__mode = "k"})
local function reachableTarget(model, part)
    local point = aimPoint(part)
    if visible(model, point) then return true end
    if not Flags.rage_aim or not Flags.rage_penetration then return false end
    local weapon = InventoryController.peekCurrentEquippedForMovement()
    local cam = camera()
    if not cam or not weapon or not weapon.Properties then return false end
    local center = cam.ViewportSize * 0.5
    local origin = cam:ViewportPointToRay(center.X, center.Y).Origin
    local delta = point - origin
    if delta.Magnitude < 0.001 or delta.Magnitude > (weapon.Properties.Range or 500) then return false end
    if directPenetrationMode() and Flags.silent_aim then
        return not Public.WeaponProfiles.Get("head_only", false) or part == model:FindFirstChild("Head")
    end
    local cached = PenetrationCache[part]
    local now = os.clock()
    local mode = Flags.rage_penetration_mode
    local headOnly = Public.WeaponProfiles.Get("head_only", false)
    if cached and cached.Weapon == weapon and cached.Mode == mode and cached.HeadOnly == headOnly and now < cached.Expires and (cached.Origin - origin).Magnitude < 2 and (cached.Point - point).Magnitude < 0.5 then return cached.Result end
    local packet = penetrationPacket(origin, delta.Unit, weapon.Properties)
    local reachable = false
    for _, hit in ipairs(packet.Hits) do
        if not hit.Exit and hit.Instance:IsDescendantOf(model) then
            reachable = not headOnly or hit.Instance == model:FindFirstChild("Head")
            break
        end
    end
    PenetrationCache[part] = {Weapon = weapon, Mode = mode, HeadOnly = headOnly, Expires = now + 0.1, Origin = origin, Point = point, Result = reachable}
    return reachable
end

local function target(onlyFov, fovOverride, omnidirectional)
    local cam = camera()
    if not cam then return nil end
    local center = cam.ViewportSize * 0.5
    local best, bestPart, bestScore = nil, nil, math.huge
    for _, model in ipairs(CharacterModels) do
        if model:IsA("Model") and isEnemy(model) then
            local parts = targetParts(model)
            for _, part in pairs(parts) do
                if part and (part.Position - cam.CFrame.Position).Magnitude <= (Flags.aim_distance or 1000) then
                    local point, onScreen = cam:WorldToViewportPoint(part.Position)
                    if omnidirectional or onScreen and point.Z > 0 then
                        local pixels = (Vector2.new(point.X, point.Y) - center).Magnitude
                        local priority = Flags.aim_priority or "Crosshair"
                        local distance = (part.Position - cam.CFrame.Position).Magnitude
                        local angle = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot((part.Position - cam.CFrame.Position).Unit), -1, 1)))
                        local score = priority == "Distance" and distance or priority == "Health" and (model:GetAttribute("Health") or 100) or priority == "Damage" and (part.Name == "Head" and -10000 or 0) + distance or omnidirectional and angle or pixels
                        if Flags.target_lock and model == RageTargetModel then score -= 100000 end
                        if score < bestScore and (omnidirectional or not onlyFov or angle <= (fovOverride or Flags.rage_fov or 180) * 0.5) and (not Flags.visible_check or reachableTarget(model, part)) then
                            best, bestPart, bestScore = model, part, score
                        end
                    end
                end
            end
        end
    end
    return best, bestPart
end

local function rageTarget()
    local model, part = target(true, nil, Flags.silent_aim and Flags.silent_360 ~= false)
    if model ~= RageTargetModel then
        RageTargetModel = model
        RageTargetSince = os.clock()
    end
    if not part or os.clock() - RageTargetSince < Public.WeaponProfiles.Get("rage_reaction", 0) / 1000 then return model, nil end
    local _, lead, speed = aimPoint(part)
    AimDiagnostics.Hitbox = part.Name
    AimDiagnostics.LeadMs = math.floor(lead * 1000 + 0.5)
    AimDiagnostics.Speed = speed
    return model, part
end


local function makePlayerDrawings()
    local lines = {}
    for i = 1, 12 do lines[i] = drawing("Line", {Visible = false, Thickness = 1.5, Color = Color3.fromRGB(166, 112, 255), Transparency = 1}) end
    return {
        box = drawing("Square", {Visible = false, Filled = false, Thickness = 1.5, Color = Color3.fromRGB(166, 112, 255), Transparency = 1}),
        name = drawing("Text", {Visible = false, Size = 14, Center = true, Outline = true, Color = Color3.fromRGB(235, 219, 255), Transparency = 1}),
        health = drawing("Line", {Visible = false, Thickness = 3, Color = Color3.fromRGB(199, 158, 255), Transparency = 1}),
        distance = drawing("Text", {Visible = false, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(235, 219, 255), Transparency = 1}),
        weapon = drawing("Text", {Visible = false, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(235, 219, 255), Transparency = 1}),
        status = drawing("Text", {Visible = false, Size = 13, Center = false, Outline = true, Color = Color3.fromRGB(235, 219, 255), Transparency = 1}),
        tracer = drawing("Line", {Visible = false, Thickness = 1, Color = Color3.fromRGB(166, 112, 255), Transparency = 1}),
        direction = drawing("Line", {Visible = false, Thickness = 1.5, Color = Color3.fromRGB(235, 219, 255), Transparency = 1}),
        arrow = drawing("Triangle", {Visible = false, Filled = true, Color = Color3.fromRGB(166, 112, 255), Transparency = 1}),
        radar = drawing("Circle", {Visible = false, Filled = true, Radius = 3, Color = Color3.fromRGB(166, 112, 255), Transparency = 1}),
        bones = lines,
    }
end

local SkeletonPairs = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
}

local GroundParams = RaycastParams.new()
GroundParams.FilterType = Enum.RaycastFilterType.Exclude
GroundParams.FilterDescendantsInstances = {Characters}

local function movementStatus(root)
    local velocity = root.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    local airborne = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), GroundParams) == nil
    return speed, airborne
end

local function updatePlayers(cam)
    for model, d in pairs(PlayerDrawings) do
        hide(d)
        if model.Parent ~= Characters or not isAlive(model) then
            removeNested(d)
            PlayerDrawings[model] = nil
        end
    end
    for model, h in pairs(Highlights) do
        h.Enabled = false
        if model.Parent ~= Characters or not isAlive(model) then
            h:Destroy()
            Highlights[model] = nil
        end
    end
    if not Flags.esp_enabled or not (Flags.esp_box or Flags.esp_skeleton or Flags.esp_name or Flags.esp_health or Flags.esp_distance or Flags.esp_weapon or Flags.esp_armor or Flags.esp_defuser or Flags.esp_money or Flags.esp_movement or Flags.esp_tracer or Flags.esp_direction or Flags.esp_chams or Flags.esp_arrow or Flags.radar) then
        for _, d in pairs(PlayerDrawings) do hide(d) end
        for _, h in pairs(Highlights) do h.Enabled = false end
        return
    end
    local center = cam.ViewportSize * 0.5
    for _, model in ipairs(CharacterModels) do
        if model:IsA("Model") and isAlive(model) then
            local d = PlayerDrawings[model]
            if not d then d = makePlayerDrawings(); PlayerDrawings[model] = d end
            local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
            if root and isAlive(model) and (Flags.esp_teammates or not isTeammate(model)) then
                if Flags.radar then
                    local own = localModel()
                    local ownRoot = own and own.PrimaryPart
                    if ownRoot then
                        local delta = ownRoot.CFrame:VectorToObjectSpace(root.Position - ownRoot.Position)
                        local dot = Vector2.new(delta.X, delta.Z) * 0.35
                        if dot.Magnitude > 54 then dot = dot.Unit * 54 end
                        d.radar.Position = Vector2.new(cam.ViewportSize.X - 85, 90) + dot
                        d.radar.Visible = true
                    end
                end
                local top, topOn = cam:WorldToViewportPoint((model:FindFirstChild("Head") or root).Position + Vector3.new(0, 0.7, 0))
                local bottom, bottomOn = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                local centerPoint, centerOn = cam:WorldToViewportPoint(root.Position)
                local distance = (root.Position - cam.CFrame.Position).Magnitude
                local teammate = isTeammate(model)
                local color = teammate and palette("team_color", Color3.fromRGB(207, 170, 255)) or visible(model, root.Position) and palette("enemy_color", Color3.fromRGB(166, 112, 255)) or palette("hidden_color", Color3.fromRGB(119, 78, 186))
                d.radar.Color = color
                for _, item in ipairs({d.name, d.distance, d.weapon, d.status}) do item.Color = palette("esp_text_color", Color3.fromRGB(235, 219, 255)) end
                if topOn and bottomOn and top.Z > 0 and bottom.Z > 0 then
                    local height = math.max(12, bottom.Y - top.Y)
                    local width = height * 0.48
                    local left = top.X - width * 0.5
                    if Flags.esp_box then d.box.Position = Vector2.new(left, top.Y); d.box.Size = Vector2.new(width, height); d.box.Color = color; d.box.Visible = true end
                    if Flags.esp_name then d.name.Text = model.Name; d.name.Position = Vector2.new(top.X, top.Y - 17); d.name.Visible = true end
                    if Flags.esp_health then
                        local ratio = math.clamp((model:GetAttribute("Health") or 0) / math.max(1, model:GetAttribute("MaxHealth") or 100), 0, 1)
                        d.health.From = Vector2.new(left - 5, bottom.Y)
                        d.health.To = Vector2.new(left - 5, bottom.Y - height * ratio)
                        d.health.Color = palette("health_low_color", Color3.fromRGB(119, 78, 186)):Lerp(palette("health_high_color", Color3.fromRGB(207, 170, 255)), ratio)
                        d.health.Visible = true
                    end
                    if Flags.esp_distance then d.distance.Text = string.format("%d studs", distance); d.distance.Position = Vector2.new(top.X, bottom.Y + 2); d.distance.Visible = true end
                    if Flags.esp_weapon then
                        local player = playerOf(model)
                        local raw = player and player:GetAttribute("CurrentEquipped")
                        local ok, data = pcall(function() return HttpService:JSONDecode(raw or "{}") end)
                        d.weapon.Text = ok and tostring(data.Name or "") or ""
                        d.weapon.Position = Vector2.new(top.X, bottom.Y + (Flags.esp_distance and 16 or 2))
                        d.weapon.Visible = d.weapon.Text ~= ""
                    end
                    if Flags.esp_armor or Flags.esp_defuser or Flags.esp_money or Flags.esp_movement then
                        local player = playerOf(model)
                        local labels = {}
                        if player then
                            if Flags.esp_armor then
                                local ok, armor = pcall(function() return HttpService:JSONDecode(player:GetAttribute("Armor") or "{}") end)
                                if ok and (armor.Health or 0) > 0 then labels[#labels + 1] = "ARM " .. tostring(armor.Health) end
                            end
                            if Flags.esp_defuser and player:GetAttribute("HasDefuseKit") then labels[#labels + 1] = "KIT" end
                            if Flags.esp_money then labels[#labels + 1] = "$" .. tostring(player:GetAttribute("Money") or 0) end
                        end
                        if Flags.esp_movement then
                            local speed, airborne = movementStatus(root)
                            if airborne then labels[#labels + 1] = "AIR" end
                            if speed >= (Flags.esp_move_speed or 5) then labels[#labels + 1] = string.format("MOV %d", math.floor(speed + 0.5)) end
                        end
                        d.status.Text = table.concat(labels, "\n")
                        d.status.Position = Vector2.new(left + width + 5, top.Y)
                        d.status.Visible = #labels > 0
                    end
                    if Flags.esp_tracer then d.tracer.From = Vector2.new(center.X, cam.ViewportSize.Y - 2); d.tracer.To = Vector2.new(centerPoint.X, centerPoint.Y); d.tracer.Color = color; d.tracer.Visible = true end
                    if Flags.esp_direction then
                        local ahead, aheadOn = cam:WorldToViewportPoint(root.Position + root.CFrame.LookVector * 8)
                        if aheadOn and ahead.Z > 0 then
                            d.direction.From = Vector2.new(centerPoint.X, centerPoint.Y)
                            d.direction.To = Vector2.new(ahead.X, ahead.Y)
                            d.direction.Color = palette("direction_color", Color3.fromRGB(235, 219, 255))
                            d.direction.Visible = true
                        end
                    end
                    if Flags.esp_skeleton then
                        for i, pair in ipairs(SkeletonPairs) do
                            local a, b = model:FindFirstChild(pair[1]), model:FindFirstChild(pair[2])
                            if a and b then
                                local pa, ona = cam:WorldToViewportPoint(a.Position)
                                local pb, onb = cam:WorldToViewportPoint(b.Position)
                                if ona and onb then d.bones[i].From = Vector2.new(pa.X, pa.Y); d.bones[i].To = Vector2.new(pb.X, pb.Y); d.bones[i].Color = color; d.bones[i].Visible = true end
                            end
                        end
                    end
                elseif Flags.esp_arrow then
                    local direction = Vector2.new(centerPoint.X - center.X, centerPoint.Y - center.Y)
                    if centerPoint.Z < 0 then direction = -direction end
                    if direction.Magnitude > 1 then
                        direction = direction.Unit
                        local perpendicular = Vector2.new(-direction.Y, direction.X)
                        local tip = center + direction * math.min(center.X, center.Y) * 0.8
                        d.arrow.PointA = tip + direction * 10
                        d.arrow.PointB = tip - direction * 9 + perpendicular * 7
                        d.arrow.PointC = tip - direction * 9 - perpendicular * 7
                        d.arrow.Color = color
                        d.arrow.Visible = true
                    end
                end
                if Flags.esp_chams then
                    local h = Highlights[model]
                    if not h then
                        h = newInstance("Highlight")
                        h.Adornee = model
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.FillTransparency = 0.78
                        h.OutlineTransparency = 0.1
                        h.Parent = model
                        Highlights[model] = h
                    end
                    local style = Flags.chams_style or "Shaded"
                    h.FillTransparency = style == "Outline" and 1 or style == "Glow" and 0.45 or 0.78
                    h.OutlineTransparency = style == "Shaded" and 0.1 or 0
                    h.FillColor = color
                    h.OutlineColor = color
                    h.Enabled = true
                elseif Highlights[model] then Highlights[model].Enabled = false end
            elseif Highlights[model] then Highlights[model].Enabled = false end
        end
    end
    for model, d in pairs(PlayerDrawings) do if model.Parent ~= Characters or not isAlive(model) then removeNested(d); PlayerDrawings[model] = nil end end
    for model, h in pairs(Highlights) do if model.Parent ~= Characters or not isAlive(model) then h:Destroy(); Highlights[model] = nil end end
end

local function objectPosition(object)
    if object:IsA("BasePart") then return object.Position end
    if object:IsA("Model") then
        local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end
    return nil
end

local function updateObjects(cam)
    local active = {}
    local function add(object, title, color)
        local position = objectPosition(object)
        if not position then return end
        local point, onScreen = cam:WorldToViewportPoint(position)
        if not onScreen or point.Z <= 0 then return end
        active[object] = true
        local label = ObjectDrawings[object]
        if not label then label = drawing("Text", {Visible = false, Size = 14, Center = true, Outline = true, Transparency = 1}); ObjectDrawings[object] = label end
        label.Text = string.format("%s [%d studs]", title, (position - cam.CFrame.Position).Magnitude)
        label.Position = Vector2.new(point.X, point.Y)
        label.Color = color
        label.Visible = true
    end
    if Flags.esp_bomb then for _, object in ipairs(CollectionService:GetTagged("Bomb")) do add(object, "Bomb", palette("object_color", Color3.fromRGB(180, 115, 255))) end end
    if Flags.esp_grenades then for _, object in ipairs(CollectionService:GetTagged("Grenade")) do add(object, tostring(object:GetAttribute("GrenadeName") or "Grenade"), palette("object_color", Color3.fromRGB(180, 115, 255))) end end
    if Flags.esp_weapons then for _, object in ipairs(CollectionService:GetTagged("WeaponDropped")) do add(object, tostring(object:GetAttribute("Weapon") or object.Name), palette("object_color", Color3.fromRGB(180, 115, 255))) end end
    if Flags.esp_hostages then
        local folder = Characters:FindFirstChild("Hostages")
        if folder then for _, object in ipairs(folder:GetChildren()) do add(object, "Hostage", palette("object_color", Color3.fromRGB(180, 115, 255))) end end
    end
    for object, label in pairs(ObjectDrawings) do if not active[object] then label.Visible = false; if not object.Parent then removeDrawing(label); ObjectDrawings[object] = nil end end end
end

local FovCircle = drawing("Circle", {Visible = false, Radius = 150, Thickness = 1, Filled = false, Color = Color3.fromRGB(235, 219, 255), Transparency = 1})
local Crosshair = {}
for i = 1, 4 do Crosshair[i] = drawing("Line", {Visible = false, Thickness = 2, Color = Color3.fromRGB(235, 219, 255), Transparency = 1}) end
local HitmarkerLines = {}
for i = 1, 4 do HitmarkerLines[i] = drawing("Line", {Visible = false, Thickness = 2, Color = Color3.fromRGB(235, 219, 255), Transparency = 1}) end
local WeaponHud = drawing("Text", {Visible = false, Size = 15, Center = false, Outline = true, Color = Color3.fromRGB(235, 219, 255), Transparency = 1})
local AmmoBackground = drawing("Square", {Visible = false, Filled = true, Transparency = 0.55, Color = Color3.fromRGB(22, 16, 32)})
local AmmoFill = drawing("Square", {Visible = false, Filled = true, Transparency = 1, Color = Color3.fromRGB(199, 158, 255)})
local LowAmmoHud = drawing("Text", {Visible = false, Size = 14, Center = false, Outline = true, Color = Color3.fromRGB(130, 76, 204), Transparency = 1})
Public.SpectatorWidget = Arvn:Widget({Name = "Spectators", Flag = "bloxstrike_spectators", Icon = "eye", Width = 220, Position = Vector2.new(16, 120), Visible = false, Rows = {{"Watching you", 0}}})
Public.SpectatorCount = 0
local RadarBackground = drawing("Square", {Visible = false, Filled = true, Transparency = 0.45, Color = Color3.fromRGB(22, 16, 32)})
local RadarOutline = drawing("Square", {Visible = false, Filled = false, Thickness = 1, Transparency = 1, Color = Color3.fromRGB(138, 110, 174)})
local RadarCenter = drawing("Circle", {Visible = false, Filled = true, Radius = 3, Transparency = 1, Color = Color3.fromRGB(207, 170, 255)})
Arvn:SetWatermark({Text = "voidsense.cc"})
local GrenadeWarningHud = drawing("Text", {Visible = false, Size = 18, Center = true, Outline = true, Color = Color3.fromRGB(202, 158, 255), Transparency = 1})
local TargetHud = drawing("Text", {Visible = false, Size = 14, Center = false, Outline = true, Color = Color3.fromRGB(180, 115, 255), Transparency = 1})
local KeybindHud = drawing("Text", {Visible = false, Size = 14, Center = false, Outline = true, Color = Color3.fromRGB(235, 219, 255), Transparency = 1})
Public.WeaponProfiles.Hud = Arvn:Widget({Name = "Shots", Flag = "bloxstrike_shots", Icon = "crosshair", Width = 260, Position = Vector2.new(16, 260), Visible = false, Empty = "No recent shots"})
Public.ShotRows = {}
Public.ShotAnimation = {Target = false, Value = 0.02, From = 0.02, Started = 0}
function Public.UpdateShotAnimation()
    local state = Public.ShotAnimation
    local hud = Public.WeaponProfiles.Hud
    local card = hud.w.inst
    if not card or not card.Parent then return end
    if state.Card ~= card then
        state.Card = card
        state.Scale = newInstance("UIScale")
        state.Scale.Scale = state.Value
        state.Scale.Parent = card
    end
    local t = math.clamp((os.clock() - state.Started) / 0.24, 0, 1)
    local ease = 1 - (1 - t) ^ 3
    local goal = state.Target and 0.85 or 0.02
    state.Value = state.From + (goal - state.From) * ease
    state.Scale.Scale = state.Value
    local visible = state.Target or t < 1
    if hud.w.visible ~= visible then hud:SetVisible(visible) end
    for key, entry in pairs(Public.ShotRows) do
        local row = hud.w.rowsInst[key]
        if row then
            local remaining = (entry.ExpireAt or entry.Time + 8) - os.clock()
            local progress = math.clamp(remaining / 0.45, 0, 1)
            local amount = progress * progress * (3 - 2 * progress)
            row.f.ClipsDescendants = true
            row.f.Size = UDim2.new(1, 0, 0, 30 * amount)
            row.k.Text = entry.Text:gsub(" | fired$", "") .. " · fired"
            row.k.Size = UDim2.fromScale(1, 1)
            row.k.TextWrapped = true
            row.k.TextTruncate = Enum.TextTruncate.None
            row.k.TextTransparency = 1 - amount
            row.v.Visible = false
        end
    end
end
Public.GetVisualState = function() return {Drawings = #Drawings, Radar = RadarBackground.Visible, Watermark = Flags.ov_wm == true, Spectators = Public.SpectatorWidget.w.visible, Ammo = AmmoBackground.Visible, Tracers = #ShotTracers, Performance = Runtime:Snapshot()} end
local FpsAverage = 60

local function updateHud(cam)
    local hudColor = palette("hud_color", Color3.fromRGB(207, 170, 255))
    for _, item in ipairs({WeaponHud, LowAmmoHud, RadarOutline, RadarCenter, GrenadeWarningHud, TargetHud, KeybindHud}) do item.Color = hudColor end
    local logs = Public.WeaponProfiles.Logs
    for i = #logs, 1, -1 do if os.clock() > (logs[i].ExpireAt or logs[i].Time + 8) then table.remove(logs, i) end end
    local hud = Public.WeaponProfiles.Hud
    local shown = Flags.shot_logs == true and #logs > 0
    if Public.ShotAnimation.Target ~= shown then
        Public.ShotAnimation.Target = shown
        Public.ShotAnimation.From = Public.ShotAnimation.Value
        Public.ShotAnimation.Started = os.clock()
        if shown then hud:SetVisible(true) end
    end
    local title = "Shots | " .. Public.WeaponProfiles.Current
    if hud.w.title ~= title then hud:SetTitle(title) end
    if shown then
    local active = {}
    for _, entry in ipairs(logs) do active[tostring(entry.Time)] = entry end
    for i = #hud.w.order, 1, -1 do
        local key = hud.w.order[i]
        if not active[key] then hud:RemoveRow(key); Public.ShotRows[key] = nil end
    end
    for _, entry in ipairs(logs) do
        local key = tostring(entry.Time)
        local label = entry.Text:gsub(" | fired$", "")
        Public.ShotRows[key] = entry
        if hud.w.values[key] ~= label then hud:SetRow(key, label) end
    end
    end
    local center = cam.ViewportSize * 0.5
    FovCircle.Position = center
    FovCircle.Color = palette("crosshair_color", Color3.fromRGB(235, 219, 255))
    FovCircle.Radius = math.min(cam.ViewportSize.Magnitude, math.tan(math.rad(math.min(Flags.rage_fov or 180, 179) * 0.5)) / math.tan(math.rad(cam.FieldOfView * 0.5)) * cam.ViewportSize.Y * 0.5)
    FovCircle.Visible = Flags.aim_circle == true
    local crosshairVisible = Flags.crosshair == true
    if crosshairVisible then
        local raw = LocalPlayer:GetAttribute("CurrentEquipped")
        local ok, data = pcall(function() return HttpService:JSONDecode(raw or "{}") end)
        local name = ok and string.lower(tostring(data.Name or "")) or ""
        local rule = Flags.crosshair_rule or "Always"
        if rule == "Hide with knife" and string.find(name, "knife", 1, true) then crosshairVisible = false end
        if rule == "Hide with grenade" and string.find(name, "grenade", 1, true) then crosshairVisible = false end
    end
    for _, line in ipairs(Crosshair) do line.Visible = crosshairVisible; line.Color = palette("crosshair_color", Color3.fromRGB(235, 219, 255)) end
    if crosshairVisible then
        local gap, size = 5, 10
        Crosshair[1].From = center + Vector2.new(-gap - size, 0); Crosshair[1].To = center + Vector2.new(-gap, 0)
        Crosshair[2].From = center + Vector2.new(gap, 0); Crosshair[2].To = center + Vector2.new(gap + size, 0)
        Crosshair[3].From = center + Vector2.new(0, -gap - size); Crosshair[3].To = center + Vector2.new(0, -gap)
        Crosshair[4].From = center + Vector2.new(0, gap); Crosshair[4].To = center + Vector2.new(0, gap + size)
    end
    WeaponHud.Visible = Flags.weapon_hud == true
    if Flags.weapon_hud then
        local raw = LocalPlayer:GetAttribute("CurrentEquipped")
        local ok, data = pcall(function() return HttpService:JSONDecode(raw or "{}") end)
        WeaponHud.Text = ok and string.format("%s  %s/%s", tostring(data.Name or "Weapon"), tostring(data.Rounds or "–"), tostring(data.Capacity or "–")) or "Weapon: —"
        WeaponHud.Position = Vector2.new(20, cam.ViewportSize.Y - 85)
    end
    AmmoBackground.Visible = false
    AmmoFill.Visible = false
    LowAmmoHud.Visible = false
    if Flags.ammo_indicator then
        local raw = LocalPlayer:GetAttribute("CurrentEquipped")
        local ok, data = pcall(function() return HttpService:JSONDecode(raw or "{}") end)
        local rounds = ok and type(data) == "table" and tonumber(data.Rounds)
        local capacity = ok and type(data) == "table" and tonumber(data.Capacity)
        if rounds and capacity and capacity > 0 then
            local ratio = math.clamp(rounds / capacity, 0, 1)
            local position = Vector2.new(20, cam.ViewportSize.Y - 60)
            local low = ratio <= (Flags.low_ammo_threshold or 25) / 100
            AmmoBackground.Position = position
            AmmoBackground.Size = Vector2.new(150, 6)
            AmmoBackground.Visible = true
            AmmoFill.Position = position
            AmmoFill.Size = Vector2.new(150 * ratio, 6)
            AmmoFill.Color = hudColor
            AmmoFill.Visible = true
            if low then
                LowAmmoHud.Text = "LOW AMMO"
                LowAmmoHud.Position = position + Vector2.new(0, -19)
                LowAmmoHud.Visible = true
            end
        end
    end
    local spectatorVisible = Flags.spectators == true
    if Public.SpectatorWidget.w.visible ~= spectatorVisible then Public.SpectatorWidget:SetVisible(spectatorVisible) end
    local spectatorCount = LocalPlayer:GetAttribute("Spectators") or 0
    if Public.SpectatorCount ~= spectatorCount then
        Public.SpectatorCount = spectatorCount
        Public.SpectatorWidget:SetRow("Watching you", spectatorCount)
    end
    RadarBackground.Visible = Flags.radar == true
    RadarOutline.Visible = Flags.radar == true
    RadarCenter.Visible = Flags.radar == true
    if Flags.radar then
        local pos = Vector2.new(cam.ViewportSize.X - 145, 30)
        RadarBackground.Position = pos; RadarBackground.Size = Vector2.new(120, 120)
        RadarOutline.Position = pos; RadarOutline.Size = Vector2.new(120, 120)
        RadarCenter.Position = pos + Vector2.new(60, 60)
    end
    TargetHud.Visible = Flags.target_panel == true and CurrentTarget ~= nil
    if TargetHud.Visible then
        local health = CurrentTarget:GetAttribute("Health") or 0
        TargetHud.Text = string.format("TARGET\n%s  |  %d HP", CurrentTarget.Name, health)
        TargetHud.Position = Vector2.new(20, 120)
    end
    KeybindHud.Visible = Flags.keybind_list == true
    if KeybindHud.Visible then
        local active = {}
        if Flags.rage_aim then active[#active + 1] = "Rage aimbot" end
        if Flags.aimbot then active[#active + 1] = "Legit aimbot" end
        if Flags.slow_walk then active[#active + 1] = "Slow walk" end
        if Flags.auto_peek then active[#active + 1] = "Auto peek [V]" end
        if Flags.force_thirdperson then active[#active + 1] = "Thirdperson" end
        KeybindHud.Text = "KEYBINDS\n" .. (#active > 0 and table.concat(active, "\n") or "No active binds")
        KeybindHud.Position = Vector2.new(cam.ViewportSize.X - 190, 170)
    end
    GrenadeWarningHud.Visible = false
    if Flags.grenade_warning then
        local own = localModel()
        local root = own and own.PrimaryPart
        if root then
            local nearest = math.huge
            for _, object in ipairs(CollectionService:GetTagged("Grenade")) do
                local position = objectPosition(object)
                if position then nearest = math.min(nearest, (position - root.Position).Magnitude) end
            end
            if nearest < 40 then
                GrenadeWarningHud.Text = string.format("GRENADE NEARBY  %d studs", nearest)
                GrenadeWarningHud.Position = Vector2.new(center.X, 65)
                GrenadeWarningHud.Visible = true
            end
        end
    end
end

local function updateShotVisuals(cam)
    local now = os.clock()
    if not Flags.bullet_tracers then
        for i = #ShotTracers, 1, -1 do
            Public.DestroyShotTracer(ShotTracers[i])
            table.remove(ShotTracers, i)
        end
    else
        for i = #ShotTracers, 1, -1 do
            local trace = ShotTracers[i]
            if now >= trace.Expires or not trace.Part or not trace.Part.Parent then
                Public.DestroyShotTracer(trace)
                table.remove(ShotTracers, i)
            else
                local progress = math.clamp((now - trace.Created - trace.Lifetime * 0.55) / (trace.Lifetime * 0.45), 0, 1)
                local fade = progress * progress * (3 - 2 * progress)
                trace.Part.Transparency = trace.Transparency + (1 - trace.Transparency) * fade
                trace.Part.Size = Vector3.new(trace.Width * (1 - fade * 0.7), trace.Width * (1 - fade * 0.7), trace.Part.Size.Z)
                if trace.Glow then trace.Glow.Transparency = 0.8 + fade * 0.2 end
            end
        end
    end
    if not Flags.hitmarker and not Flags.hit_sound then
        table.clear(PendingHits)
        HitmarkerUntil = 0
    else
        for model, pending in pairs(PendingHits) do
            local health = model.Parent and model:GetAttribute("Health")
            if not health or now >= pending.Expires then
                PendingHits[model] = nil
            elseif health < pending.Health then
                PendingHits[model] = nil
                HitmarkerUntil = now + 0.35
                Public.PlayCombatSound("hit")
            end
        end
    end
    local visible = Flags.hitmarker and now < HitmarkerUntil
    for _, line in ipairs(HitmarkerLines) do line.Visible = visible; line.Color = palette("hitmarker_color", Color3.fromRGB(235, 219, 255)) end
    if visible then
        local center = cam.ViewportSize * 0.5
        HitmarkerLines[1].From = center + Vector2.new(-10, -10); HitmarkerLines[1].To = center + Vector2.new(-4, -4)
        HitmarkerLines[2].From = center + Vector2.new(10, -10); HitmarkerLines[2].To = center + Vector2.new(4, -4)
        HitmarkerLines[3].From = center + Vector2.new(-10, 10); HitmarkerLines[3].To = center + Vector2.new(-4, 4)
        HitmarkerLines[4].From = center + Vector2.new(10, 10); HitmarkerLines[4].To = center + Vector2.new(4, 4)
    end
end

local function applyWorld()
    if Flags.nightmode then
        Lighting.Brightness = 1
        Lighting.ClockTime = 0
        Lighting.Ambient = palette("ambient_color", Color3.fromRGB(100, 70, 140))
        Lighting.OutdoorAmbient = palette("outdoor_color", Color3.fromRGB(80, 60, 115))
    elseif Flags.fullbright then
        Lighting.Brightness = 4
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(205, 205, 205)
        Lighting.OutdoorAmbient = Color3.fromRGB(205, 205, 205)
    end
    if Flags.no_fog then
        Lighting.FogStart = 0
        Lighting.FogEnd = 100000
        if Atmosphere and Atmosphere.Parent then Atmosphere.Density = 0 end
    end
    if Flags.remove_post then
        for _, effect in ipairs(Lighting:GetDescendants()) do
            if effect:IsA("PostEffect") then
                if PostEffects[effect] == nil then PostEffects[effect] = effect.Enabled end
                effect.Enabled = false
            end
        end
    end
end

local function restorePost()
    for effect, enabled in pairs(PostEffects) do
        if effect.Parent then effect.Enabled = enabled end
        PostEffects[effect] = nil
    end
end


local function applyInventory()
    for _, item in ipairs(camera():GetChildren()) do
        if item:IsA("Model") then
            for _, part in ipairs(item:GetDescendants()) do
                if part:IsA("BasePart") then
                    local glove = part.Name == "Glove"
                    local arm = part.Name == "Left Arm" or part.Name == "Right Arm"
                    local weaponPart = not glove and not arm and part.Name ~= "HumanoidRootPart" and part.Name ~= "Hitbox" and part.Name ~= "ViewmodelLight" and part.Name ~= "Sleeve"
                    local wanted = glove and Flags.glove_tint or weaponPart and Flags.weapon_tint
                    local original = ViewPartOriginals[part]
                    if wanted then
                        if not original then original = {Color = part.Color, Material = part.Material}; ViewPartOriginals[part] = original end
                        part.Color = FinishColors[glove and (Flags.glove_color or "Cyan") or (Flags.weapon_color or "Crimson")] or original.Color
                        part.Material = not glove and Flags.weapon_finish == "Neon" and Enum.Material.Neon or not glove and Flags.weapon_finish == "Metal" and Enum.Material.Metal or original.Material
                    elseif original then
                        part.Color = original.Color
                        part.Material = original.Material
                        ViewPartOriginals[part] = nil
                    end
                end
            end
        end
    end
    for part in pairs(ViewPartOriginals) do if not part.Parent then ViewPartOriginals[part] = nil end end
end

local function restoreInventory()
    for part, original in pairs(ViewPartOriginals) do
        if part.Parent then part.Color = original.Color; part.Material = original.Material end
        ViewPartOriginals[part] = nil
    end
end

local function restoreSkins()
    for part, record in pairs(SkinOriginals) do
        local original = record.Original
        if part.Parent then
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("SurfaceAppearance") and child ~= original then child:Destroy() end
            end
            if original and not original.Parent then original.Parent = part end
        end
        SkinOriginals[part] = nil
    end
    AppliedSkinKey = nil
    AppliedSkinModel = nil
end

local function refreshSkinOptions(model, skins)
    if Public.SkinStudio and Public.SkinStudio.Ready then
        local name = model and model.Name or "No weapon"
        if LastSkinWeapon ~= name then LastSkinWeapon = name; if SkinInfo then SkinInfo:Set(name) end end
        return
    end
    local name = model and model.Name or ""
    if LastSkinWeapon == name then return end
    LastSkinWeapon = name
    table.clear(SkinOptions)
    SkinOptions[1] = "Stock"
    local folder = skins and skins:FindFirstChild(name)
    if folder then
        for _, skin in ipairs(folder:GetChildren()) do
            if skin.Name ~= "Stock" then SkinOptions[#SkinOptions + 1] = skin.Name end
        end
    end
    table.sort(SkinOptions)
    if SkinInfo then SkinInfo:Set(name ~= "" and name or "No weapon") end
    if Flags.skin_name and not table.find(SkinOptions, Flags.skin_name) then Arvn:SetFlag("skin_name", "Stock") end
end

local function applySkin()
    if LocalPlayer:GetAttribute("IsSpectating") then restoreSkins(); return end
    local cam = camera()
    local model, skins = getCameraWeapon(cam)
    refreshSkinOptions(model, skins)
    local selection = Public.SkinStudio and Public.SkinStudio.Loadout.Weapons[model and model.Name or ""]
    local skinName = selection and selection.Skin or Flags.skin_name or "Stock"
    if Public.SkinStudio and Public.SkinStudio.Ready and not selection then skinName = "Stock" end
    if not Flags.skin_changer or not model or skinName == "Stock" then
        if AppliedSkinKey then restoreSkins() end
        return
    end
    local folder = skins and skins:FindFirstChild(model.Name)
    local skin = folder and folder:FindFirstChild(skinName)
    local cameraSkins = skin and skin:FindFirstChild("Camera")
    local wear = cameraSkins and cameraSkins:FindFirstChild(selection and selection.Wear or Flags.skin_wear or "Factory New")
    if not wear then
        if AppliedSkinKey then restoreSkins() end
        return
    end
    local key = tostring(model) .. "/" .. skinName .. "/" .. wear.Name
    if key == AppliedSkinKey and model == AppliedSkinModel then return end
    restoreSkins()
    local applied = false
    for _, source in ipairs(wear:GetDescendants()) do
        if source:IsA("SurfaceAppearance") then
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("MeshPart") and part.Name == source.Name then
                    local original = part:FindFirstChildWhichIsA("SurfaceAppearance")
                    if original then original.Parent = nil end
                    SkinOriginals[part] = {Original = original}
                    source:Clone().Parent = part
                    applied = true
                end
            end
        end
    end
    if applied then
        AppliedSkinKey = key
        AppliedSkinModel = model
    end
end

local function restoreGloves()
    for clone, record in pairs(GloveOriginals) do
        if clone.Parent then clone:Destroy() end
        if record.Original and not record.Original.Parent and record.Arm.Parent then record.Original.Parent = record.Arm end
        GloveOriginals[clone] = nil
    end
    AppliedGloveKey = nil
    AppliedGloveModel = nil
end

local function hasAppearance(folder)
    if not folder then return false end
    for _, item in ipairs(folder:GetDescendants()) do
        if item:IsA("SurfaceAppearance") then return true end
    end
    return false
end

local function refreshGloveTypes(skins, weapons)
    if #GloveTypes > 1 then return end
    table.clear(GloveTypes)
    GloveTypes[1] = "Default"
    if skins and weapons then
        for _, folder in ipairs(skins:GetChildren()) do
            local bases = weapons:FindFirstChild(folder.Name)
            if bases and bases:FindFirstChild("Left Arm") and bases:FindFirstChild("Right Arm") then
                for _, skin in ipairs(folder:GetChildren()) do
                    local cameraSkins = skin:FindFirstChild("Camera")
                    if hasAppearance(cameraSkins) then
                        GloveTypes[#GloveTypes + 1] = folder.Name
                        break
                    end
                end
            end
        end
    end
    table.sort(GloveTypes)
    if Flags.glove_type and not table.find(GloveTypes, Flags.glove_type) then Arvn:SetFlag("glove_type", "Default") end
end

local function refreshGloveSkins(typeName, skins)
    if LastGloveType == typeName then return end
    LastGloveType = typeName
    table.clear(GloveSkins)
    GloveSkins[1] = "Stock"
    local folder = skins and skins:FindFirstChild(typeName)
    if folder then
        for _, skin in ipairs(folder:GetChildren()) do
            if skin.Name ~= "Stock" and hasAppearance(skin:FindFirstChild("Camera")) then GloveSkins[#GloveSkins + 1] = skin.Name end
        end
    end
    table.sort(GloveSkins)
    if GloveInfo then GloveInfo:Set(typeName) end
    if Flags.glove_skin and not table.find(GloveSkins, Flags.glove_skin) then Arvn:SetFlag("glove_skin", "Stock") end
end

local function cameraValue(part, folder, fallback)
    local group = part:FindFirstChild(folder)
    local value = group and group:FindFirstChild("Camera")
    return value and value.Value or fallback
end

local function applyGloves(model)
    if LocalPlayer:GetAttribute("IsSpectating") then restoreGloves(); return end
    local skins = skinsRoot()
    local weapons = weaponsRoot()
    refreshGloveTypes(skins, weapons)
    local typeName = Flags.glove_type or "Default"
    refreshGloveSkins(typeName, skins)
    local skinName = Flags.glove_skin or "Stock"
    if not Flags.glove_changer or not model or typeName == "Default" or skinName == "Stock" then
        if AppliedGloveKey then restoreGloves() end
        return
    end
    if not model:FindFirstChild("Left Arm") or not model:FindFirstChild("Right Arm") then return end
    local bases = weapons and weapons:FindFirstChild(typeName)
    local skin = skins and skins:FindFirstChild(typeName) and skins[typeName]:FindFirstChild(skinName)
    local wear = skin and skin:FindFirstChild("Camera") and skin.Camera:FindFirstChild(Flags.glove_wear or "Factory New")
    if not bases or not wear then
        if AppliedGloveKey then restoreGloves() end
        return
    end
    local key = tostring(model) .. "/" .. typeName .. "/" .. skinName .. "/" .. wear.Name
    if key == AppliedGloveKey and model == AppliedGloveModel then return end
    restoreGloves()
    local applied = 0
    for _, base in ipairs(bases:GetChildren()) do
        if base:IsA("BasePart") and (base.Name == "Left Arm" or base.Name == "Right Arm") then
            local arm = model:FindFirstChild(base.Name)
            local source = wear:FindFirstChild(base.Name)
            if arm and arm:IsA("BasePart") and source and source:IsA("SurfaceAppearance") then
                local original = arm:FindFirstChild("Glove")
                if original then original.Parent = nil end
                local clone = base:Clone()
                local scale = cameraValue(clone, "Scales", Vector3.one)
                local offset = cameraValue(clone, "Offsets", Vector3.zero)
                local rotation = cameraValue(clone, "Rotations", Vector3.zero)
                local weaponBase = weapons:FindFirstChild(model.Name)
                local cameraBase = weaponBase and weaponBase:FindFirstChild("Camera")
                local referenceArm = cameraBase and cameraBase:FindFirstChild(base.Name)
                local referenceSize = referenceArm and referenceArm.Size or Vector3.new(0.8, 0.8, 4)
                local ratio = Vector3.new(arm.Size.X / referenceSize.X, arm.Size.Y / referenceSize.Y, arm.Size.Z / referenceSize.Z)
                offset = Vector3.new(offset.X * ratio.X, offset.Y * ratio.Y, offset.Z * ratio.Z)
                local pivot = clone.PivotOffset
                clone.PivotOffset = CFrame.new(pivot.Position.X * ratio.X, pivot.Position.Y * ratio.Y, pivot.Position.Z * ratio.Z) * pivot.Rotation
                for _, child in ipairs(clone:GetChildren()) do
                    if child:IsA("SurfaceAppearance") or child.Name == "Scales" or child.Name == "Offsets" or child.Name == "Rotations" then child:Destroy() end
                end
                clone.Name = "Glove"
                clone.Size = Vector3.new(arm.Size.X * scale.X, arm.Size.Y * scale.Y, arm.Size.Z * scale.Z)
                local correction = arm.Size.Z * 0.5 - clone.Size.Z * 0.5
                clone.CFrame = arm.CFrame * CFrame.new(offset) * CFrame.new(0, 0, -correction * 1.035) * clone.PivotOffset * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
                clone.CastShadow = false
                clone.CanCollide = false
                clone.CanTouch = false
                clone.CanQuery = false
                clone.Anchored = false
                source:Clone().Parent = clone
                clone.Parent = arm
                local weld = newInstance("WeldConstraint")
                weld.Part0 = arm
                weld.Part1 = clone
                weld.Parent = clone
                GloveOriginals[clone] = {Arm = arm, Original = original}
                applied += 1
            end
        end
    end
    if applied == 2 then
        AppliedGloveKey = key
        AppliedGloveModel = model
    else
        restoreGloves()
    end
end


do
local Studio: any = {Ready = false, Loadout = {Weapons = {}}, Presets = {}, Names = {}, Weapons = {}, Updating = false, Preview = nil}
Public.SkinStudio = Studio
local wearOrder = {"Factory New", "Minimal Wear", "Field-Tested", "Well-Worn", "Battle-Scarred"}
local folder = "NetanyahuCC/" .. tostring(LocalPlayer.UserId)
local path = folder .. "/skin_sets_v1.json"
local function status(message)
    if Studio.Status then Studio.Status:Set(message) end
end
local function copy(value)
    return HttpService:JSONDecode(HttpService:JSONEncode(value))
end
local function valid(value)
    if type(value) ~= "table" or type(value.Weapons) ~= "table" then return false end
    local root = skinsRoot()
    local count = 0
    for weapon, choice in pairs(value.Weapons) do
        count += 1
        if count > 100 or type(weapon) ~= "string" or type(choice) ~= "table" or type(choice.Skin) ~= "string" or type(choice.Wear) ~= "string" then return false end
        local base = root and root:FindFirstChild(weapon)
        local skin = base and base:FindFirstChild(choice.Skin)
        local cameraFolder = skin and skin:FindFirstChild("Camera")
        if not cameraFolder or not cameraFolder:FindFirstChild(choice.Wear) then return false end
    end
    return value.Gloves == nil or type(value.Gloves) == "table"
end
function Studio.Commit()
    Arvn:SetFlag("skin_loadout", HttpService:JSONEncode(Studio.Loadout))
    restoreSkins()
end
function Studio.Options()
    local weapon = Flags.skin_edit_weapon or ""
    local root = skinsRoot()
    local base = root and root:FindFirstChild(weapon)
    local names = {}
    if base then for _, skin in ipairs(base:GetChildren()) do if skin:FindFirstChild("Camera") then names[#names + 1] = skin.Name end end end
    table.sort(names)
    if #names == 0 then names = {"Stock"} end
    if Studio.SkinControl then Studio.SkinControl:SetValues(names) end
    if not table.find(names, Flags.skin_name) then Arvn:SetFlag("skin_name", names[1]) end
    local skin = base and base:FindFirstChild(Flags.skin_name or "Stock")
    local cameraFolder = skin and skin:FindFirstChild("Camera")
    local wears = {}
    for _, name in ipairs(wearOrder) do if cameraFolder and cameraFolder:FindFirstChild(name) then wears[#wears + 1] = name end end
    if #wears == 0 then wears = {"Factory New"} end
    if Studio.WearControl then Studio.WearControl:SetValues(wears) end
    if not table.find(wears, Flags.skin_wear) then Arvn:SetFlag("skin_wear", wears[1]) end
    Studio.PreviewKey = nil
end
function Studio.SelectWeapon()
    if Studio.Updating then return end
    Studio.Updating = true
    local choice = Studio.Loadout.Weapons[Flags.skin_edit_weapon or ""]
    Arvn:SetFlag("skin_name", choice and choice.Skin or "Stock")
    Arvn:SetFlag("skin_wear", choice and choice.Wear or "Factory New")
    Studio.Options()
    Studio.Updating = false
end
function Studio.Assign()
    local weapon = Flags.skin_edit_weapon
    if not table.find(Studio.Weapons, weapon) then return status("select a weapon") end
    Studio.Loadout.Weapons[weapon] = {Skin = Flags.skin_name, Wear = Flags.skin_wear}
    if weapon == "Karambit" or weapon == "M9 Bayonet" or string.find(weapon, "Knife", 1, true) then Arvn:SetFlag("skin_knife_model", weapon) end
    Studio.Commit()
    Arvn:SetFlag("skin_changer", true)
    status("applied to " .. weapon)
    return nil
end
local function names()
    table.clear(Studio.Names)
    for name in pairs(Studio.Presets) do Studio.Names[#Studio.Names + 1] = name end
    table.sort(Studio.Names)
    if Studio.SetControl then Studio.SetControl:SetValues(Studio.Names) end
end
local function save()
    if not writefile then return false, "local storage unavailable" end
    local ok, err = pcall(function()
        if makefolder then makefolder(folder) end
        writefile(path, HttpService:JSONEncode({Version = 1, Sets = Studio.Presets}))
    end)
    return ok, ok and "saved" or tostring(err)
end
local function setName()
    local name = tostring(Flags.skin_set_name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 48 or name:find("[%c]") then return nil end
    return name
end
function Studio.SaveSet(create)
    local name = setName()
    if not name then return status("enter a name, up to 48 characters") end
    if create and Studio.Presets[name] then return status("name already exists") end
    local previous = Studio.Presets[name]
    local current = copy(Studio.Loadout)
    current.Gloves = {}
    for _, flag in ipairs({"glove_changer", "glove_type", "glove_skin", "glove_wear", "glove_tint", "glove_color", "weapon_tint", "weapon_color", "weapon_finish", "skin_changer"}) do current.Gloves[flag] = Flags[flag] end
    Studio.Presets[name] = current
    local ok, message = save()
    if not ok then Studio.Presets[name] = previous; return status(message) end
    names()
    Arvn:SetFlag("skin_set_choice", name)
    status("saved " .. name)
    return nil
end
function Studio.ApplySet()
    local name = Flags.skin_set_choice
    local value = Studio.Presets[name]
    if not valid(value) then return status("set unavailable or incompatible") end
    Studio.Loadout = copy(value)
    Studio.Commit()
    for flag, valueFlag in pairs(Studio.Loadout.Gloves or {}) do
        if table.find({"glove_changer", "glove_type", "glove_skin", "glove_wear", "glove_tint", "glove_color", "weapon_tint", "weapon_color", "weapon_finish", "skin_changer"}, flag) then Arvn:SetFlag(flag, valueFlag) end
    end
    Arvn:SetFlag("skin_set_name", name)
    Studio.SelectWeapon()
    status("applied " .. name)
    return nil
end
function Studio.RenameSet()
    local old = Flags.skin_set_choice
    local name = setName()
    if not name or not Studio.Presets[old] then return status("select a set and enter its new name") end
    if name ~= old and Studio.Presets[name] then return status("name already exists") end
    local value = Studio.Presets[old]
    Studio.Presets[old] = nil
    Studio.Presets[name] = value
    local ok, message = save()
    if not ok then Studio.Presets[name] = nil; Studio.Presets[old] = value; return status(message) end
    names()
    Arvn:SetFlag("skin_set_choice", name)
    status("renamed " .. name)
    return nil
end
function Studio.DeleteSet()
    local name = Flags.skin_set_choice
    local previous = Studio.Presets[name]
    if not previous then return status("select a set") end
    Studio.Presets[name] = nil
    local ok, message = save()
    if not ok then Studio.Presets[name] = previous; return status(message) end
    names()
    Arvn:SetFlag("skin_set_choice", Studio.Names[1] or "")
    status("deleted " .. name)
    return nil
end
function Studio.RefreshPreview()
    local preview = Studio.Preview
    if not preview or not preview.View.Parent then return end
    local key = tostring(Flags.skin_edit_weapon) .. "/" .. tostring(Flags.skin_name) .. "/" .. tostring(Flags.skin_wear)
    if key == Studio.PreviewKey then return end
    Studio.PreviewKey = key
    preview.World:ClearAllChildren()
    local root = weaponsRoot()
    local base = root and root:FindFirstChild(Flags.skin_edit_weapon or "")
    local cameraModel = base and base:FindFirstChild("Camera")
    local weapon = cameraModel and cameraModel:FindFirstChild("Weapon")
    if not weapon or not weapon:IsA("Model") then return end
    local clone = weapon:Clone()
    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("BasePart") then item.Anchored = true; item.CanCollide = false; item.LocalTransparencyModifier = 0 end
        if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then item:Destroy() end
    end
    local skins = skinsRoot()
    local skinBase = skins and skins:FindFirstChild(Flags.skin_edit_weapon)
    local skin = skinBase and skinBase:FindFirstChild(Flags.skin_name or "Stock")
    local group = skin and skin:FindFirstChild("Camera")
    local wear = group and group:FindFirstChild(Flags.skin_wear or "Factory New")
    if wear then
        for _, appearance in ipairs(wear:GetDescendants()) do
            if appearance:IsA("SurfaceAppearance") then
                for _, part in ipairs(clone:GetDescendants()) do
                    if part:IsA("MeshPart") and part.Name == appearance.Name then
                        for _, child in ipairs(part:GetChildren()) do if child:IsA("SurfaceAppearance") then child:Destroy() end end
                        appearance:Clone().Parent = part
                    end
                end
            end
        end
    end
    clone.Parent = preview.World
    local bounds, size = clone:GetBoundingBox()
    clone:PivotTo(CFrame.new(-bounds.Position) * clone:GetPivot())
    preview.Model = clone
    preview.BasePivot = clone:GetPivot()
    preview.Distance = math.max(size.Magnitude, 1) / (2 * math.tan(math.rad(17.5))) * 1.15
    preview.Camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.1, preview.Distance), Vector3.zero)
end
function Studio.BuildPreview(holder, ui)
    local view = newInstance("ViewportFrame")
    view.Name = "SkinStudioPreview"
    view.Size = UDim2.fromScale(1, 1)
    view.BackgroundColor3 = ui.Theme.field
    view.BorderSizePixel = 0
    view.Ambient = Color3.fromRGB(210, 210, 225)
    view.LightColor = Color3.fromRGB(245, 230, 255)
    view.LightDirection = Vector3.new(-1, -1, -1)
    view.Parent = holder
    ui.Corner(view, 24)
    local world = newInstance("WorldModel")
    world.Parent = view
    local cam = newInstance("Camera")
    cam.FieldOfView = 35
    cam.Parent = view
    view.CurrentCamera = cam
    local preview: any = {View = view, World = world, Camera = cam, Angle = 0}
    Studio.Preview = preview
    Studio.PreviewKey = nil
    ui.Cleanup(function() if Studio.Preview == preview then Studio.Preview = nil end end)
    ui.Connect(RunService.RenderStepped, function(dt)
        if not Running or not view:IsDescendantOf(game) then return end
        local visible = view.AbsoluteSize.X > 0
        local parent = view.Parent
        while parent and visible do if parent:IsA("GuiObject") and not parent.Visible then visible = false end; parent = parent.Parent end
        if not visible then return end
        Studio.RefreshPreview()
        preview.Angle += dt * 0.35
        if preview.Model and preview.Model.Parent then preview.Model:PivotTo(CFrame.Angles(0, preview.Angle, 0) * preview.BasePivot) end
    end)
end
local function isKnife(name)
    return name == "Karambit" or name == "M9 Bayonet" or string.find(name, "Knife", 1, true) ~= nil
end
local function sideKnife()
    local ok, slot = pcall(function() return HttpService:JSONDecode(LocalPlayer:GetAttribute("Slot3") or "") end)
    if ok and type(slot) == "table" and (slot.Weapon == "T Knife" or slot.Weapon == "CT Knife") then return slot.Weapon end
    local team = LocalPlayer.Team
    local name = team and string.lower(team.Name) or ""
    return (name == "t" or name == "terrorists" or name == "terrorist") and "T Knife" or "CT Knife"
end
local function restoreHudSlot(slot)
    local hud = Studio.HudSlots and Studio.HudSlots[slot]
    if not hud then return end
    if hud.View then hud.View:Destroy() end
    if hud.Icon.Parent then hud.Icon.ImageTransparency = hud.Transparency; if hud.Icon.Image == hud.Image then hud.Icon.Image = hud.OriginalImage end end
    if hud.Label and hud.Label.Parent and hud.Label.Text == hud.Text then hud.Label.Text = hud.OriginalText end
    Studio.HudSlots[slot] = nil
end
function Studio.RestoreHud()
    for _, slot in ipairs({"Primary", "Secondary", "Melee"}) do restoreHudSlot(slot) end
end
local function updateHudSlot(inventory, slot, name)
    local container = inventory and inventory:FindFirstChild(slot)
    local weapon = container and container:FindFirstChild("Weapon")
    local icon = weapon and weapon:FindFirstChild(slot == "Melee" and "Melee" or "Weapon")
    if not name or name == "" or not icon or not icon:IsA("ImageLabel") then restoreHudSlot(slot); return end
    local choice = Studio.Loadout.Weapons[name]
    local key = name .. "/" .. (choice and choice.Skin .. "/" .. choice.Wear or "Stock")
    local hud = Studio.HudSlots[slot]
    if hud and hud.Icon == icon and hud.Key == key then
        icon.Image = hud.Image
        if hud.Label then hud.Label.Text = hud.Text end
        return
    end
    restoreHudSlot(slot)
    local ok, properties = pcall(function() return require(ReplicatedStorage.Components.Common.GetWeaponProperties)(name) end)
    if not ok or not properties or type(properties.Icon) ~= "string" then return end
    local label = weapon:FindFirstChild("WeaponName")
    local text = name .. (choice and choice.Skin ~= "Stock" and " · " .. choice.Skin or "")
    Studio.HudSlots[slot] = {Icon = icon, Image = properties.Icon, OriginalImage = icon.Image, Key = key, Transparency = icon.ImageTransparency, Label = label, OriginalText = label and label.Text, Text = text}
    icon.Image = properties.Icon
    if label then label.Text = text end
end
function Studio.UpdateHud()
    if LocalPlayer:GetAttribute("IsSpectating") then Studio.RestoreHud(); return end
    if not Flags.skin_changer then Studio.RestoreHud(); return end
    Studio.HudSlots = Studio.HudSlots or {}
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("MainGui")
    local gameplay = main and main:FindFirstChild("Gameplay")
    local bottom = gameplay and gameplay:FindFirstChild("Bottom")
    local inventory = bottom and bottom:FindFirstChild("Inventory")
    for index, slot in ipairs({"Primary", "Secondary", "Melee"}) do
        local ok, data = pcall(function() return HttpService:JSONDecode(LocalPlayer:GetAttribute("Slot" .. index) or "") end)
        local name = ok and type(data) == "table" and type(data.Weapon) == "string" and data.Weapon or nil
        if slot == "Melee" and name and isKnife(name) and Flags.skin_knife_model and isKnife(Flags.skin_knife_model) then name = Flags.skin_knife_model end
        updateHudSlot(inventory, slot, name)
    end
end
function Studio.RestoreKnife()
    local state = Studio.KnifeView
    if not state then return end
    for _, track in pairs(state.Tracks or {}) do track:Stop(0); track:Destroy() end
    if state.Model then state.Model:Destroy() end
    for part, transparency in pairs(state.Hidden) do if part.Parent then part.LocalTransparencyModifier = transparency end end
    Studio.KnifeView = nil
end
function Studio.UpdateKnife()
    if LocalPlayer:GetAttribute("IsSpectating") then Studio.RestoreKnife(); return end
    local cam = camera()
    local model = cam and getCameraWeapon(cam)
    local name = Flags.skin_knife_model
    if not Flags.skin_changer or not model or not isKnife(model.Name) or not name or not isKnife(name) or name == model.Name then Studio.RestoreKnife(); return end
    local arm = model:FindFirstChild("Right Arm")
    local original = model:FindFirstChild("Weapon")
    if not arm or not arm:IsA("BasePart") or not original then Studio.RestoreKnife(); return end
    local choice = Studio.Loadout.Weapons[name]
    local key = name .. "/" .. (choice and choice.Skin .. "/" .. choice.Wear or "Stock") .. "/" .. tostring(Flags.glove_type) .. "/" .. tostring(Flags.glove_skin) .. "/" .. tostring(Flags.glove_wear) .. "/" .. tostring(arm:FindFirstChild("Glove") ~= nil)
    local state = Studio.KnifeView
    local handsChanged = false
    if state and state.Source == model then
        for _, armName in ipairs({"Left Arm", "Right Arm"}) do
            local liveArm = model:FindFirstChild(armName)
            local recorded = state.HandSources and state.HandSources[armName]
            if liveArm and (not recorded or recorded.Glove ~= liveArm:FindFirstChild("Glove") or recorded.Sleeve ~= liveArm:FindFirstChild("Sleeve")) then handsChanged = true end
        end
    end
    if not state or state.Source ~= model or state.Key ~= key or not state.Model.Parent or handsChanged then
        Studio.RestoreKnife()
        local root = weaponsRoot()
        local base = root and root:FindFirstChild(name)
        local baseCamera = base and base:FindFirstChild("Camera")
        local source = baseCamera and baseCamera:FindFirstChild("Weapon")
        local sourceArm = baseCamera and baseCamera:FindFirstChild("Right Arm")
        if not source or not source.PrimaryPart or not sourceArm then return end
        local clone = baseCamera:Clone()
        clone.Name = "VoidsenseCosmeticKnife"
        local scale = arm.Size.Z / math.max(sourceArm.Size.Z, 0.001)
        clone:ScaleTo(baseCamera:GetScale() * scale)
        for _, item in ipairs(clone:GetDescendants()) do
            if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then item:Destroy()
            elseif item:IsA("BasePart") then item.Anchored = item == clone.PrimaryPart; item.CanCollide = false; item.CanTouch = false; item.CanQuery = false; item.CastShadow = false; item.LocalTransparencyModifier = 0 end
        end
        for _, armName in ipairs({"Left Arm", "Right Arm"}) do
            local liveArm = model:FindFirstChild(armName)
            local newArm = clone:FindFirstChild(armName)
            if liveArm and newArm then
                newArm.Color = liveArm.Color
                newArm.Material = liveArm.Material
                newArm.Transparency = liveArm.Transparency
                for _, child in ipairs(newArm:GetChildren()) do if child:IsA("SurfaceAppearance") or child.Name == "Glove" or child.Name == "Sleeve" then child:Destroy() end end
                for _, child in ipairs(liveArm:GetChildren()) do
                    if child:IsA("SurfaceAppearance") then child:Clone().Parent = newArm
                    elseif child:IsA("BasePart") and (child.Name == "Glove" or child.Name == "Sleeve") then
                        local part = child:Clone()
                        for _, joint in ipairs(part:GetDescendants()) do if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then joint:Destroy() end end
                        part.Anchored = false
                        part.CanCollide = false
                        part.CanTouch = false
                        part.CanQuery = false
                        part.CFrame = newArm.CFrame * liveArm.CFrame:ToObjectSpace(child.CFrame)
                        part.LocalTransparencyModifier = 0
                        part.Parent = newArm
                        local weld = newInstance("WeldConstraint")
                        weld.Part0 = newArm; weld.Part1 = part; weld.Parent = part
                    end
                end
            end
        end
        local skins = skinsRoot()
        local skinBase = skins and skins:FindFirstChild(name)
        local skin = choice and skinBase and skinBase:FindFirstChild(choice.Skin)
        local group = skin and skin:FindFirstChild("Camera")
        local wear = group and group:FindFirstChild(choice.Wear)
        if wear then
            for _, appearance in ipairs(wear:GetDescendants()) do
                if appearance:IsA("SurfaceAppearance") then
                    for _, part in ipairs(clone.Weapon:GetDescendants()) do
                        if part:IsA("MeshPart") and part.Name == appearance.Name then
                            for _, child in ipairs(part:GetChildren()) do if child:IsA("SurfaceAppearance") then child:Destroy() end end
                            appearance:Clone().Parent = part
                        end
                    end
                end
            end
        end
        state = {Source = model, Model = clone, Key = key, Hidden = {}, Tracks = {}, Active = {}, AnimationNames = {}, HandSources = {}}
        for _, armName in ipairs({"Left Arm", "Right Arm"}) do
            local liveArm = model:FindFirstChild(armName)
            if liveArm then state.HandSources[armName] = {Glove = liveArm:FindFirstChild("Glove"), Sleeve = liveArm:FindFirstChild("Sleeve")} end
        end
        for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then state.Hidden[part] = part.LocalTransparencyModifier end end
        clone.Parent = model
        local animations = ReplicatedStorage.Assets:FindFirstChild("WeaponAnimations")
        local selected = animations and animations:FindFirstChild(name)
        local selectedCamera = selected and selected:FindFirstChild("CameraAnimations")
        local previous = animations and animations:FindFirstChild(model.Name)
        local previousCamera = previous and previous:FindFirstChild("CameraAnimations")
        local controller = clone:FindFirstChildWhichIsA("AnimationController")
        if controller and selectedCamera then
            local animator = controller:FindFirstChildWhichIsA("Animator") or newInstance("Animator")
            animator.Parent = controller
            for _, animation in ipairs(selectedCamera:GetChildren()) do
                if animation:IsA("Animation") then
                    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
                    if ok then state.Tracks[animation.Name] = track end
                end
            end
        end
        if previousCamera then for _, animation in ipairs(previousCamera:GetChildren()) do if animation:IsA("Animation") then state.AnimationNames[animation.AnimationId] = animation.Name end end end
        if state.Tracks.Idle then state.Tracks.Idle.Looped = true; state.Tracks.Idle.Priority = Enum.AnimationPriority.Idle; state.Tracks.Idle:Play(0.08) end
        if state.Tracks.Equip then state.Tracks.Equip.Priority = Enum.AnimationPriority.Action; state.Tracks.Equip:Play(0.06) end
        Studio.KnifeView = state
    end
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and not part:IsDescendantOf(state.Model) then
            if state.Hidden[part] == nil then state.Hidden[part] = part.LocalTransparencyModifier end
            part.LocalTransparencyModifier = 1
        end
    end
    state.Model:PivotTo(model:GetPivot())
    local visible = state.Hidden[arm] or 0
    for _, part in ipairs(state.Model:GetDescendants()) do if part:IsA("BasePart") then part.LocalTransparencyModifier = visible end end
    local controller = model:FindFirstChildWhichIsA("AnimationController")
    if controller then
        local playing = controller:GetPlayingAnimationTracks()
        local seen = {}
        for _, originalTrack in ipairs(playing) do
            local animation = originalTrack.Animation
            local animationName = animation and state.AnimationNames[animation.AnimationId] or originalTrack.Name
            local replacement = state.Tracks[animationName]
            if replacement and animationName ~= "Idle" then
                seen[originalTrack] = true
                local active = state.Active[originalTrack]
                local time = originalTrack.TimePosition
                local ratio = originalTrack.Length > 0 and replacement.Length > 0 and replacement.Length / originalTrack.Length or 1
                local speed = originalTrack.Speed * ratio
                if not active or time + 0.04 < active.Time or not replacement.IsPlaying then
                    replacement.Looped = originalTrack.Looped
                    replacement.Priority = originalTrack.Priority
                    replacement:Play(0.035, math.max(originalTrack.WeightCurrent, 0.01), speed)
                    if replacement.Length > 0 then replacement.TimePosition = math.min(time * ratio, math.max(0, replacement.Length - 0.001)) end
                    state.Active[originalTrack] = {Track = replacement, Time = time}
                else
                    replacement:AdjustSpeed(speed)
                    replacement:AdjustWeight(originalTrack.WeightCurrent, 0.035)
                    active.Time = time
                end
            end
        end
        for originalTrack, active in pairs(state.Active) do if not seen[originalTrack] then active.Track:Stop(0.035); state.Active[originalTrack] = nil end end
    end
end
function Studio.RestoreCharacterGloves()
    local state = Studio.CharacterGloves
    if not state then return end
    for _, part in ipairs(state.Parts) do part:Destroy() end
    for part, transparency in pairs(state.Hidden) do if part.Parent then part.LocalTransparencyModifier = transparency end end
    Studio.CharacterGloves = nil
end
function Studio.UpdateCharacterGloves()
    local model = Characters:FindFirstChild(LocalPlayer.Name)
    local typeName = Flags.glove_type or "Default"
    local skinName = Flags.glove_skin or "Stock"
    if not Flags.force_thirdperson or not Flags.glove_changer or not model or typeName == "Default" or skinName == "Stock" then Studio.RestoreCharacterGloves(); return end
    local key = typeName .. "/" .. skinName .. "/" .. tostring(Flags.glove_wear)
    local state = Studio.CharacterGloves
    if state and state.Model == model and state.Key == key then
        for part in pairs(state.Hidden) do if part.Parent then part.LocalTransparencyModifier = 1 end end
        return
    end
    Studio.RestoreCharacterGloves()
    local weapons = weaponsRoot()
    local skins = skinsRoot()
    local bases = weapons and weapons:FindFirstChild(typeName)
    local folder = skins and skins:FindFirstChild(typeName)
    local skin = folder and folder:FindFirstChild(skinName)
    local group = skin and (skin:FindFirstChild("Character") or skin:FindFirstChild("Camera"))
    local wear = group and group:FindFirstChild(Flags.glove_wear or "Factory New")
    if not bases or not wear then return end
    state = {Model = model, Key = key, Parts = {}, Hidden = {}}
    for _, side in ipairs({"Left", "Right"}) do
        local hand = model:FindFirstChild(side .. "Hand")
        local base = bases:FindFirstChild(side .. " Arm")
        local appearance = wear:FindFirstChild(side .. " Arm")
        if hand and base and appearance and appearance:IsA("SurfaceAppearance") then
            local clone = base:Clone()
            local function value(name, fallback)
                local f = base:FindFirstChild(name)
                local v = f and f:FindFirstChild("Character")
                return v and v.Value or fallback
            end
            local scale = value("Scales", Vector3.one)
            local offset = value("Offsets", Vector3.zero)
            local rotation = value("Rotations", Vector3.zero)
            for _, child in ipairs(clone:GetChildren()) do if child:IsA("SurfaceAppearance") or child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("Folder") then child:Destroy() end end
            clone.Name = "VoidsenseCharacterGlove"
            clone.Size = scale
            clone.Anchored = false; clone.CanCollide = false; clone.CanTouch = false; clone.CanQuery = false; clone.Massless = true
            local c0 = CFrame.new(offset)
            local c1 = clone.PivotOffset * CFrame.Angles(-math.pi * 0.5, 0, 0) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
            clone.CFrame = hand.CFrame * c0 * c1:Inverse()
            appearance:Clone().Parent = clone
            for _, child in ipairs(model:GetDescendants()) do
                if child:IsA("BasePart") and (child.Name == side .. "Glove" or child.Parent == hand and child.Name == "Glove") then state.Hidden[child] = child.LocalTransparencyModifier; child.LocalTransparencyModifier = 1 end
            end
            clone.Parent = hand
            state.Hidden[hand] = hand.LocalTransparencyModifier
            hand.LocalTransparencyModifier = 1
            local weld = newInstance("Motor6D"); weld.Name = "VoidsenseGloveAttachment"; weld.Part0 = hand; weld.Part1 = clone; weld.C0 = c0; weld.C1 = c1; weld.Parent = clone
            state.Parts[#state.Parts + 1] = clone
        end
    end
    Studio.CharacterGloves = state
end
function Studio.BuildGallery(holder, ui)
    local cards = {}
    local search = newInstance("TextBox")
    search.Size = UDim2.new(1, 0, 0, 40)
    search.BackgroundColor3 = ui.Theme.field
    search.TextColor3 = ui.Theme.text
    search.PlaceholderColor3 = ui.Theme.sub
    search.PlaceholderText = "search weapons"
    search.Text = ""
    search.FontFace = ui.Font("med")
    search.TextSize = 14
    search.ClearTextOnFocus = false
    search.BorderSizePixel = 0
    search.Parent = holder
    ui.Corner(search, 24)
    local grid = ui.Frame({Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = holder})
    local layout = newInstance("UIGridLayout")
    layout.CellPadding = UDim2.fromOffset(12, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid
    local function resize()
        local width = holder.AbsoluteSize.X
        local columns = math.clamp(math.floor((width + 12) / 150), 2, 4)
        layout.CellSize = UDim2.fromOffset(math.max(100, math.floor((width - (columns - 1) * 12) / columns)), 160)
    end
    ui.Connect(holder:GetPropertyChangedSignal("AbsoluteSize"), resize)
    resize()
    local function populate(card)
        if card.Knife then
            local selected = Flags.skin_edit_weapon
            local name = selected and isKnife(selected) and selected or sideKnife()
            if card.Name ~= name then card.Name = name; card.Key = nil end
        end
        local choice = Studio.Loadout.Weapons[card.Name]
        local key = choice and choice.Skin .. "/" .. choice.Wear or "Stock"
        if card.Key == key then return end
        card.Key = key
        card.Label.Text = string.lower(choice and choice.Skin or "stock")
        card.World:ClearAllChildren()
        local root = weaponsRoot()
        local base = root and root:FindFirstChild(card.Name)
        local cameraFolder = base and base:FindFirstChild("Camera")
        local source = cameraFolder and cameraFolder:FindFirstChild("Weapon")
        if not source then card.Label.Text = "preview unavailable"; return end
        local model = source:Clone()
        for _, item in ipairs(model:GetDescendants()) do
            if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then item:Destroy()
            elseif item:IsA("BasePart") then item.Anchored = true; item.CanCollide = false; item.LocalTransparencyModifier = 0 end
        end
        local skins = skinsRoot()
        local skinBase = skins and skins:FindFirstChild(card.Name)
        local skin = choice and skinBase and skinBase:FindFirstChild(choice.Skin)
        local group = skin and skin:FindFirstChild("Camera")
        local wear = group and group:FindFirstChild(choice.Wear)
        if wear then
            for _, appearance in ipairs(wear:GetDescendants()) do
                if appearance:IsA("SurfaceAppearance") then
                    for _, part in ipairs(model:GetDescendants()) do
                        if part:IsA("MeshPart") and part.Name == appearance.Name then
                            for _, child in ipairs(part:GetChildren()) do if child:IsA("SurfaceAppearance") then child:Destroy() end end
                            appearance:Clone().Parent = part
                        end
                    end
                end
            end
        end
        model.Parent = card.World
        local bounds, size = model:GetBoundingBox()
        model:PivotTo(CFrame.Angles(0, math.rad(65), 0) * CFrame.new(-bounds.Position) * model:GetPivot())
        local distance = math.max(size.Magnitude, 1) / (2 * math.tan(math.rad(17.5))) * 1.12
        card.Camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.12, distance), Vector3.zero)
    end
    local catalog = {}
    local knives = {}
    for _, name in ipairs(Studio.Weapons) do
        if isKnife(name) then knives[#knives + 1] = name else catalog[#catalog + 1] = name end
    end
    if #knives > 0 then table.insert(catalog, 1, "knife") end
    for index, entry in ipairs(catalog) do
        local knife = entry == "knife"
        local name = knife and sideKnife() or entry
        local button = ui.Button({Name = name, Text = "", Size = UDim2.fromOffset(150, 160), BackgroundTransparency = 0, BackgroundColor3 = ui.Theme.field, BorderSizePixel = 0, LayoutOrder = index, Parent = grid})
        ui.Corner(button, 24)
        local outline = newInstance("UIStroke")
        outline.Thickness = 1
        outline.Color = ui.Accent()
        outline.Transparency = 1
        outline.Parent = button
        local view = newInstance("ViewportFrame")
        view.Size = UDim2.new(1, -16, 0, 102)
        view.Position = UDim2.fromOffset(8, 4)
        view.BackgroundTransparency = 1
        view.Ambient = Color3.fromRGB(210, 210, 225)
        view.LightColor = Color3.fromRGB(245, 230, 255)
        view.Parent = button
        local world = newInstance("WorldModel"); world.Parent = view
        local cam = newInstance("Camera"); cam.FieldOfView = 35; cam.Parent = view; view.CurrentCamera = cam
        ui.Text({Text = knife and "knife" or string.lower(name), FontFace = ui.Font("semi"), TextSize = 13, TextColor3 = ui.Theme.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 108), Size = UDim2.new(1, -24, 0, 20), Parent = button})
        local label = ui.Text({Text = "stock", FontFace = ui.Font("med"), TextSize = 12, TextColor3 = ui.Theme.sub, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 129), Size = UDim2.new(1, -24, 0, 18), Parent = button})
        local card = {Name = name, Knife = knife, Button = button, World = world, Camera = cam, Label = label, Outline = outline}
        cards[#cards + 1] = card
        populate(card)
        ui.Connect(button.MouseEnter, function() button.BackgroundColor3 = ui.Theme.hover end)
        ui.Connect(button.MouseLeave, function() button.BackgroundColor3 = ui.Theme.field end)
        ui.Connect(button.MouseButton1Click, function()
            ui.Play()
            if Studio.WeaponControl then Studio.WeaponControl:SetValues(knife and knives or Studio.Weapons) end
            Arvn:SetFlag("skin_edit_weapon", knife and sideKnife() or name)
            Studio.SelectWeapon()
            Public.Navigation.SkinEditor:Select()
        end)
    end
    ui.Connect(search:GetPropertyChangedSignal("Text"), function()
        local query = string.lower(search.Text)
        for _, card in ipairs(cards) do card.Button.Visible = string.find(card.Knife and "knife нож" or string.lower(card.Name), query, 1, true) ~= nil end
    end)
    local elapsed = 0
    ui.Connect(RunService.Heartbeat, function(dt)
        elapsed += dt
        if elapsed < 0.3 then return end
        elapsed = 0
        local parent = holder
        while parent do if parent:IsA("GuiObject") and not parent.Visible then return end; parent = parent.Parent end
        for _, card in ipairs(cards) do populate(card); card.Outline.Transparency = Flags.skin_edit_weapon == card.Name and 0 or 1; card.Outline.Color = ui.Accent() end
    end)
end
function Studio.Init()
    local weapons = weaponsRoot()
    local skins = skinsRoot()
    if weapons and skins then
        for _, base in ipairs(weapons:GetChildren()) do
            local cam = base:FindFirstChild("Camera")
            if cam and cam:FindFirstChild("Weapon") and skins:FindFirstChild(base.Name) then Studio.Weapons[#Studio.Weapons + 1] = base.Name end
        end
    end
    table.sort(Studio.Weapons)
    local loadoutOk, loadout = pcall(function() return HttpService:JSONDecode(Flags.skin_loadout or "") end)
    if loadoutOk and valid(loadout) then
        Studio.Loadout = loadout
    elseif Flags.skin_changer and Flags.skin_name and Flags.skin_name ~= "Stock" then
        local equipped = getCameraWeapon(camera())
        if equipped then
            local legacy = {Weapons = {[equipped.Name] = {Skin = Flags.skin_name, Wear = Flags.skin_wear or "Factory New"}}}
            if valid(legacy) then Studio.Loadout = legacy end
        end
    end
    if readfile then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if ok and type(data) == "table" and data.Version == 1 and type(data.Sets) == "table" then for name, value in pairs(data.Sets) do if type(name) == "string" and valid(value) then Studio.Presets[name] = value end end end
    end
    names()
    Studio.Ready = true
    Arvn:OnFlag("skin_loadout", function(value)
        if type(value) ~= "string" or #value > 100000 then return end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(value) end)
        if ok and valid(decoded) then Studio.Loadout = decoded; restoreSkins() end
    end)
end
Studio.Init()
end

Public.Navigation = {}
do
local aim = Window:Group("Aimbot")
Public.Navigation.Rage = aim:Tab({Name = "Rage", Icon = "target"})
Public.Navigation.Legit = aim:Tab({Name = "Legit", Icon = "crosshair"})
local common = Window:Group("Common")
Public.Navigation.Visuals = common:Tab({Name = "Visuals", Icon = "eye"})
Public.Navigation.Effects = common:Tab({Name = "Effects", Icon = "sparkles"})
Public.Navigation.HUD = common:Tab({Name = "HUD", Icon = "layout-dashboard"})
Public.Navigation.Skins = common:Tab({Name = "Skinchanger", Icon = "palette"})
Public.Navigation.SkinEditor = common:Tab({Name = "Skin editor", Icon = "sliders-horizontal"})
Public.Navigation.Misc = common:Tab({Name = "Miscellaneous", Icon = "list"})
local presets = Window:Group("Presets")
local configs = presets:Tab({Name = "Configs", Icon = "settings"})
Public.Navigation.Configs = configs
local localSection = configs:Section({Name = "personal configs", Side = "Right", Order = 1})
Public.ConfigStatus = localSection:Label("local storage ready")
localSection:Toggle({Name = "autosave", Flag = "cfg_autosave", Default = true})
local section = localSection:Page("saved configs")
Public.ConfigChoice = section:Dropdown({Name = "saved configs", Flag = "config_selected", Values = Arvn.Config:List(), Save = false})
function Public.RefreshConfigs()
    Public.ConfigChoice:SetValues(Arvn.Config:List(), true)
end
section:Input({Name = "name", Flag = "config_name", Default = "default"})
section:Input({Name = "Format", Flag = "config_format", Default = "1", Visible = false})
section:Button({Name = "save current", Callback = function()
    local ok = Arvn.Config:Save(Flags.config_name or "default")
    Public.RefreshConfigs()
    Public.ConfigStatus:SetName(ok and "config saved" or "save failed")
end})
section:Button({Name = "load selected", Callback = function()
    local ok = type(Flags.config_selected) == "string" and Window:LoadConfig(Flags.config_selected)
    Public.ConfigStatus:SetName(ok and "config loaded" or "select a saved config")
end})
section:Button({Name = "refresh list", Callback = Public.RefreshConfigs})
local share = localSection:Page("import / export")
share:Button({Name = "copy current config", Callback = function()
    local ok = pcall(setclipboard, Arvn.Config:Export())
    Public.ConfigStatus:SetName(ok and "share code copied" or "clipboard unavailable")
end})
share:Input({Name = "paste share code", Flag = "config_share_code", Default = "", Save = false})
share:Button({Name = "import and save", Callback = function()
    local raw = Flags.config_share_code or ""
    local name = Flags.config_name or "imported"
    if #raw > 250000 then Public.ConfigStatus:SetName("share code too large"); return end
    local ok, result = pcall(function() return Arvn.Config:Import(raw) end)
    Arvn:SetFlag("config_share_code", "")
    if not ok or not result then Public.ConfigStatus:SetName("invalid share code"); return end
    (Public :: any).MigrateConfig()
    local saved = Arvn.Config:Save(name)
    Public.RefreshConfigs()
    Public.ConfigStatus:SetName(saved and "config imported and saved" or "imported; save failed")
end})
do
local community = configs:Section({Name = "community configs", Side = "Left", Order = -10})
local selectedSection = configs:Section({Name = "selected config", Side = "Right", Order = -10})
local publishSection = configs:Section({Name = "publish config", Side = "Right", Order = 2})
local publish = publishSection:Page("prepare upload")
publishSection:Label("share your current settings")
local status = selectedSection:Label("refresh to browse configs")
community:Input({Name = "search name or author", Flag = "community_search", Default = "", Save = false})
local sortChoice = community:Dropdown({Name = "sort by", Flag = "community_sort", Values = {"Newest", "Most used", "Most liked", "Most disliked"}, Default = "Newest", Save = false})
local catalog = {}
local backendVersion = 1
local redrawCatalog = function() end
community:Custom({Name = "public configs", Flag = "community_selected", Default = "", Save = false, Height = 350, Build = function(holder, ui)
    local theme = ui.Theme
    local scroll = newInstance("ScrollingFrame")
    scroll.Name = "CommunityConfigList"
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.BackgroundColor3 = theme.field
    scroll.BackgroundTransparency = 0.25
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = ui.Accent()
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = holder
    ui.Corner(scroll, 24)
    local layout = newInstance("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    local padding = newInstance("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = scroll
    local function render()
        if not scroll.Parent then return end
        for _, child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
        local labels = {}
        for label in pairs(catalog) do labels[#labels + 1] = label end
        table.sort(labels, function(a, b)
            local metric = backendVersion >= 2 and ({["Most used"] = "downloads", ["Most liked"] = "likes", ["Most disliked"] = "dislikes"})[Flags.community_sort] or "created_at"
            local left = tonumber(catalog[a][metric]) or 0
            local right = tonumber(catalog[b][metric]) or 0
            if left ~= right then return left > right end
            local leftTime = tonumber(catalog[a].created_at) or 0
            local rightTime = tonumber(catalog[b].created_at) or 0
            return leftTime == rightTime and catalog[a].id > catalog[b].id or leftTime > rightTime
        end)
        if #labels == 0 then
            ui.Text({Text = "no configs yet — refresh or publish yours", TextWrapped = true, TextColor3 = theme.sub, FontFace = ui.Font("med"), TextSize = 12, Size = UDim2.new(1, -8, 0, 70), BackgroundTransparency = 1, Parent = scroll})
        end
        for index, label in ipairs(labels) do
            local item = catalog[label]
            local row = newInstance("TextButton")
            row.Name = "ConfigRow"
            row.Size = UDim2.new(1, -8, 0, 64)
            row.LayoutOrder = index
            row.Text = ""
            row.BackgroundColor3 = Flags.community_selected == label and ui.Accent() or theme.card
            row.BackgroundTransparency = Flags.community_selected == label and 0.75 or 0.1
            row.BorderSizePixel = 0
            row.Parent = scroll
            ui.Corner(row, 24)
            ui.Text({Text = item.name, TextColor3 = theme.text, FontFace = ui.Font("semi"), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -106, 0, 22), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1, Parent = row})
            ui.Text({Text = "by " .. item.author, TextColor3 = theme.sub, FontFace = ui.Font("med"), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -106, 0, 18), Position = UDim2.fromOffset(12, 33), BackgroundTransparency = 1, Parent = row})
            ui.Text({Text = item.likes ~= nil and ("↑ " .. tostring(item.likes) .. "  ↓ " .. tostring(item.dislikes)) or "", TextColor3 = theme.sub, FontFace = ui.Font("med"), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromOffset(88, 22), Position = UDim2.new(1, -100, 0, 8), BackgroundTransparency = 1, Parent = row})
            ui.Text({Text = item.downloads ~= nil and ("uses " .. tostring(item.downloads)) or "", TextColor3 = theme.sub, FontFace = ui.Font("med"), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromOffset(88, 18), Position = UDim2.new(1, -100, 0, 33), BackgroundTransparency = 1, Parent = row})
            ui.Tip(row, item.description ~= "" and item.description or "no description")
            ui.Connect(row.Activated, function() ui.Set(label); ui.Play("click"); render() end)
        end
    end
    redrawCatalog = render
    render()
end})
local title = selectedSection:Label("no config selected")
local details = selectedSection:Label("select a row in the list")
local rating = selectedSection:Label("ratings require server v2")
local function updateSelection()
    local item = catalog[Flags.community_selected]
    title:SetName(item and (item.name .. " · " .. item.author) or "no config selected")
    details:SetName(item and (item.description ~= "" and item.description or "no description") or "select a row in the list")
    rating:SetName(backendVersion < 2 and "update cloudflare worker to v2" or item and ("likes " .. tostring(item.likes or 0) .. " · dislikes " .. tostring(item.dislikes or 0) .. " · uses " .. tostring(item.downloads or 0) .. " · your vote: " .. ((item.my_vote == 1 and "like") or (item.my_vote == -1 and "dislike") or "none")) or "select a config to vote")
end
Arvn:OnFlag("community_selected", updateSelection)
local nextPage = nil
local busy = false
local endpoint = "https://netanyahu-configs.vladosikthebestkid.workers.dev"
local tokenPath = "NetanyahuCC/" .. tostring(LocalPlayer.UserId) .. "/community-owner.key"
local function ownerToken()
    if isfile(tokenPath) then
        local saved = readfile(tokenPath)
        if #saved == 64 and not saved:find("[^a-f0-9]") then return saved end
        error("invalid local ownership key")
    end
    local key = (HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)):gsub("%-", ""):lower()
    writefile(tokenPath, key)
    return key
end
local function api(method, path, body)
    local headers = { ["Content-Type"] = "application/json" }
    headers.Authorization = "Bearer " .. ownerToken()
    local response = request({Url = endpoint .. path, Method = method, Headers = headers, Body = body and HttpService:JSONEncode(body) or nil})
    if type(response) ~= "table" then error("network request failed") end
    local data = HttpService:JSONDecode(response.Body)
    if response.StatusCode < 200 or response.StatusCode >= 300 then error(data.error or "server request failed") end
    return data
end
Public.CommunityRequest = api
local function run(action)
    if busy then return end
    busy = true
    status:SetName("loading...")
    task.spawn(function()
        local ok, message = pcall(action)
        busy = false
        if getgenv().BloxStrikeArvn ~= Public then return end
        status:SetName(ok and (message or "ready") or tostring(message):gsub("^.-:%d+: ", ""))
    end)
end
local function refresh(append)
    local requestedSort = Flags.community_sort
    local sort = ({["Most used"] = "usage", ["Most liked"] = "likes", ["Most disliked"] = "dislikes"})[Flags.community_sort] or "newest"
    local path = "/configs?limit=20&sort=" .. sort .. "&q=" .. HttpService:UrlEncode(Flags.community_search or "")
    if append and nextPage then path ..= "&before=" .. HttpService:UrlEncode(nextPage) end
    local result = api("GET", path)
    if getgenv().BloxStrikeArvn ~= Public then return "closed" end
    if Flags.community_sort ~= requestedSort then return refresh(false) end
    backendVersion = tonumber(result.version) or 1
    if not append then catalog = {} end
    for _, item in ipairs(result.items) do catalog[item.name .. " | " .. item.author .. " | " .. item.id] = item end
    nextPage = result.next
    local labels = {}
    for label in pairs(catalog) do table.insert(labels, label) end
    table.sort(labels)
    if not catalog[Flags.community_selected] then Arvn:SetFlag("community_selected", "") end
    redrawCatalog()
    updateSelection()
    return backendVersion < 2 and "catalog ready; ratings need server v2" or tostring(#labels) .. " configs listed"
end
sortChoice:OnChanged(function() run(function() return refresh(false) end) end)
local function vote(value)
    run(function()
        if backendVersion < 2 then return "update cloudflare worker to v2, then refresh" end
        local item = catalog[Flags.community_selected]
        if not item then return "select a config to vote" end
        api("POST", "/configs/" .. item.id .. "/vote", {value = value})
        refresh(false)
        return value == 0 and "vote removed" or "vote saved"
    end)
end
selectedSection:Buttons({
    {Name = "like", Callback = function() vote(1) end},
    {Name = "dislike", Callback = function() vote(-1) end},
    {Name = "clear vote", Callback = function() vote(0) end},
})
community:Buttons({
    {Name = "refresh", Callback = function() run(function() return refresh(false) end) end},
    {Name = "load more", Callback = function() run(function() if not nextPage then return "no more pages" end; return refresh(true) end) end},
})
selectedSection:Button({Name = "download and apply", Callback = function() run(function()
    local item = catalog[Flags.community_selected]
    if not item then return "select a public config" end
    local result = backendVersion >= 2 and api("POST", "/configs/" .. item.id .. "/download") or api("GET", "/configs/" .. item.id)
    if getgenv().BloxStrikeArvn ~= Public then return "closed" end
    if type(result.code) ~= "string" or #result.code > 250000 or not Arvn.Config:Import(result.code) then error("invalid config") end
    (Public :: any).MigrateConfig()
    local saved = Arvn.Config:Save("community-" .. item.id:sub(1, 8))
    Public.RefreshConfigs()
    if backendVersion >= 2 then refresh(false) end
    return saved and "downloaded, applied and saved locally" or "applied; local save failed"
end) end})
selectedSection:Page("manage my upload"):Button({Name = "delete selected upload", Callback = function() run(function()
    local item = catalog[Flags.community_selected]
    if not item then return "select your uploaded config" end
    api("DELETE", "/configs/" .. item.id)
    refresh(false)
    return "upload deleted"
end) end})
publish:Input({Name = "public name", Flag = "community_name", Default = "my config", Save = false})
publish:Input({Name = "author nickname", Flag = "community_author", Default = LocalPlayer.Name, Save = false})
publish:Input({Name = "description", Flag = "community_description", Default = "", Save = false})
publish:Label("publishes current settings to everyone")
publish:Label("up to 5 uploads per 24 hours")
publish:Button({Name = "publish current config", Callback = function() run(function()
    local name = Flags.community_name or ""
    local author = Flags.community_author or ""
    local description = Flags.community_description or ""
    if #name == 0 or #name > 48 or #author == 0 or #author > 48 or #description > 240 then return "check name, author and description lengths" end
    api("POST", "/configs", {name = name, author = author, description = description, code = Arvn.Config:Export()})
    refresh(false)
    return "config published"
end) end})
Public.Community = {Refresh = function() return refresh(false) end}
end
end
do
do
local RageTab = Public.Navigation.Rage
local RageSection = RageTab:Section({Name = "Main", Side = "Left"})
RageSection:Toggle({Name = "Enabled", Flag = "rage_aim", Default = false})
RageSection:Toggle({Name = "Silent Aim", Flag = "silent_aim", Default = false})
RageSection:Toggle({Name = "Automatic Fire", Flag = "rage_autofire", Default = false})
RageSection:Toggle({Name = "Penetrate walls", Flag = "rage_penetration", Default = false})
RageSection:Dropdown({Name = "Penetration mode", Flag = "rage_penetration_mode", Values = {"Weapon", "Direct (experimental)"}, Default = "Weapon"})
RageSection:Toggle({Name = "Silent Aim 360°", Flag = "silent_360", Default = true})
RageSection:Slider({Name = "Field of View", Flag = "rage_fov", Min = 1, Max = 180, Default = 180, Suffix = "°"})
do
local selection = RageTab:Section({Name = "Selection", Side = "Left"})
selection:Dropdown({Name = "Target", Flag = "aim_priority", Values = {"Crosshair", "Distance", "Health", "Damage"}, Default = "Crosshair"})
selection:Dropdown({Name = "Hitboxes", Flag = "target_part", Values = {"Head", "Chest", "Stomach", "All"}, Default = "Head"})
selection:Toggle({Name = "Multipoint", Flag = "multipoint", Default = false})
selection:Toggle({Name = "Auto Stop", Flag = "rage_autostop", Default = false})
selection:Toggle({Name = "Auto Scope", Flag = "auto_scope", Default = false})
local targetSettings = selection:Page("Settings")
targetSettings:Toggle({Name = "Head only", Flag = "head_only", Default = true})
targetSettings:Toggle({Name = "Target lock", Flag = "target_lock", Default = true})
targetSettings:Toggle({Name = "Team check", Flag = "team_check", Default = true})
targetSettings:Toggle({Name = "Visibility check", Flag = "visible_check", Default = true})
local other = RageTab:Section({Name = "Other", Side = "Right"})
other:Slider({Name = "Delay Shot", Flag = "rage_reaction", Min = 0, Max = 500, Default = 0, Suffix = " ms"})
local shotSettings = other:Page("Settings")
shotSettings:Dropdown({Name = "Prediction", Flag = "prediction_mode", Values = {"Off", "Adaptive", "Manual"}, Default = "Adaptive"})
shotSettings:Slider({Name = "Prediction time", Flag = "prediction_time", Min = 0, Max = 150, Default = 30, Suffix = " ms"})
shotSettings:Slider({Name = "Maximum lead", Flag = "prediction_limit", Min = 0, Max = 5, Default = 0.35, Step = 0.05})
shotSettings:Toggle({Name = "No spread", Flag = "no_spread", Default = false})
end

local AntiAimTab = RageTab
local AntiAimSection = AntiAimTab:Section({Name = "Anti-Aim", Side = "Right"})
AntiAimSection:Toggle({Name = "Enabled", Flag = "anti_aim", Default = false, Risky = true})
AntiAimSection:Dropdown({Name = "Pitch", Flag = "anti_aim_pitch", Values = {"Neutral", "Up", "Down"}, Default = "Neutral"})
AntiAimSection:Dropdown({Name = "Yaw", Flag = "anti_aim_mode", Values = {"Backwards", "Forward", "Left", "Right", "Jitter", "Spin"}, Default = "Backwards"})
AntiAimSection:Dropdown({Name = "Yaw Jitter", Flag = "anti_aim_jitter", Values = {"Off", "Offset", "Center"}, Default = "Off"})
AntiAimSection:Toggle({Name = "Slow Walk", Flag = "slow_walk", Default = false})
local antiSettings = AntiAimSection:Page("Settings")
antiSettings:Slider({Name = "Spin speed", Flag = "spin_speed", Min = 0, Max = 14400, Default = 14400, Suffix = " deg/s"})
antiSettings:Slider({Name = "Slow walk speed", Flag = "slow_walk_speed", Min = 10, Max = 80, Default = 35, Suffix = "%"})

end
do

local LegitTab = Public.Navigation.Legit
LegitTab:Section({Name = "Main", Side = "Left"}):Toggle({Name = "Enabled", Flag = "aimbot", Default = false})
local LegitSection = LegitTab:Section({Name = "Aiming", Side = "Left"})
LegitSection:Slider({Name = "Field of View", Flag = "legit_fov", Min = 1, Max = 180, Default = 30, Suffix = "°"})
LegitSection:Slider({Name = "Smooth", Flag = "aim_smooth", Min = 1, Max = 30, Default = 8})
LegitSection:Slider({Name = "Mouse Override", Flag = "mouse_override", Min = 0, Max = 10, Default = 1})
LegitSection:Slider({Name = "Reaction Time", Flag = "legit_reaction", Min = 0, Max = 1000, Default = 0, Suffix = " ms"})
LegitSection:Slider({Name = "Reaction Time Reset", Flag = "legit_reset", Min = 0, Max = 1000, Default = 0, Suffix = " ms"})
local legitSettings = LegitSection:Page("Settings")
legitSettings:Dropdown({Name = "Activation", Flag = "legit_activation", Values = {"Hold RMB", "On attack", "Always"}, Default = "Hold RMB"})
local TriggerSection = LegitSection:Page("Auto fire")
TriggerSection:Toggle({Name = "Triggerbot", Flag = "triggerbot", Default = false, Risky = true})
TriggerSection:Slider({Name = "Shot delay", Flag = "trigger_delay", Min = 0, Max = 500, Default = 160, Suffix = " ms"})
LegitTab.entry.page = {LegitTab.entry.page[1]}

end
do

local PlayersTab = Public.Navigation.Visuals
Public.PlayerMain = PlayersTab:Section({Name = "Players", Side = "Left"})
Public.PlayerMain:Toggle({Name = "Enabled", Flag = "esp_enabled", Default = false})
local PlayerSection = Public.PlayerMain:Page("Elements")
PlayerSection:Toggle({Name = "Boxes", Flag = "esp_box", Default = false})
PlayerSection:Toggle({Name = "Skeleton", Flag = "esp_skeleton", Default = false})
PlayerSection:Toggle({Name = "Names", Flag = "esp_name", Default = false})
PlayerSection:Toggle({Name = "Health", Flag = "esp_health", Default = false})
PlayerSection:Toggle({Name = "Distance", Flag = "esp_distance", Default = false})
PlayerSection:Toggle({Name = "Weapon", Flag = "esp_weapon", Default = false})
PlayerSection:Toggle({Name = "Armor", Flag = "esp_armor", Default = false})
PlayerSection:Toggle({Name = "Defuse kit", Flag = "esp_defuser", Default = false})
PlayerSection:Toggle({Name = "Money", Flag = "esp_money", Default = false})
PlayerSection:Toggle({Name = "Movement flags", Flag = "esp_movement", Default = false})
PlayerSection:Slider({Name = "Move threshold", Flag = "esp_move_speed", Min = 1, Max = 40, Default = 5, Suffix = " studs/s"})
PlayerSection:Toggle({Name = "Tracers", Flag = "esp_tracer", Default = false})
PlayerSection:Toggle({Name = "View direction", Flag = "esp_direction", Default = false})
PlayerSection:Toggle({Name = "Chams", Flag = "esp_chams", Default = false})
PlayerSection:Dropdown({Name = "Chams style", Flag = "chams_style", Values = {"Shaded", "Glow", "Outline"}, Default = "Shaded"})
Public.PlayerMain:Toggle({Name = "Teammates", Flag = "esp_teammates", Default = false})
Public.PlayerMain:Toggle({Name = "Bullet Tracers", Flag = "bullet_tracers", Default = false})
local TracerSettings = Public.PlayerMain:Page("Bullet tracers")
TracerSettings:Dropdown({Name = "Material", Flag = "bullet_material", Values = {"Neon", "ForceField", "Glass", "Metal", "SmoothPlastic"}, Default = "Neon"})
TracerSettings:Slider({Name = "Lifetime", Flag = "bullet_lifetime", Min = 0.2, Max = 4, Default = 1.2, Step = 0.1, Suffix = "s"})
TracerSettings:Slider({Name = "Width", Flag = "bullet_width", Min = 0.02, Max = 0.3, Default = 0.08, Step = 0.01})
TracerSettings:Toggle({Name = "Soft glow", Flag = "bullet_glow", Default = true})
Public.PlayerMain:Toggle({Name = "Offscreen ESP", Flag = "esp_arrow", Default = false})
Public.PlayerMain:Toggle({Name = "Radar", Flag = "radar", Default = false})
local ObjectsTab = Public.Navigation.Visuals
local ObjectSection = ObjectsTab:Section({Name = "World", Side = "Right"})
ObjectSection:Toggle({Name = "Bomb", Flag = "esp_bomb", Default = false})
ObjectSection:Toggle({Name = "Weapons", Flag = "esp_weapons", Default = false})
ObjectSection:Toggle({Name = "Grenades", Flag = "esp_grenades", Default = false})
ObjectSection:Toggle({Name = "Grenade Proximity Warning", Flag = "grenade_warning", Default = false})
ObjectSection:Page("Additional"):Toggle({Name = "Hostages", Flag = "esp_hostages", Default = false})
Public.VisualCommon = ObjectsTab:Section({Name = "Common", Side = "Right"})
local WorldSection = Public.VisualCommon:Page("Ambience")
WorldSection:Toggle({Name = "Fullbright", Flag = "fullbright", Default = false, Callback = function(on)
    if not on then
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    end
end})
WorldSection:Toggle({Name = "Nightmode", Flag = "nightmode", Default = false, Callback = function(on)
    if not on then
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    end
end})
WorldSection:Toggle({Name = "Remove fog", Flag = "no_fog", Default = false, Callback = function(on)
    if not on then Lighting.FogStart = OriginalLighting.FogStart; Lighting.FogEnd = OriginalLighting.FogEnd; if Atmosphere and OriginalDensity then Atmosphere.Density = OriginalDensity end end
end})
WorldSection:Toggle({Name = "Remove post processing", Flag = "remove_post", Default = false, Callback = function(on) if not on then restorePost() end end})
do
local BodyTab = Public.Navigation.Visuals
Public.ModelMain = BodyTab:Section({Name = "Models", Side = "Left"})
local BodySection = Public.ModelMain:Page("Local player")
BodySection:Toggle({Name = "Body material and color", Flag = "body_style", Default = false})
BodySection:Dropdown({Name = "Material", Flag = "body_material", Values = {"Original", "SmoothPlastic", "Neon", "ForceField", "Glass", "Metal"}, Default = "Neon"})
BodySection:ColorPicker({Name = "Body color", Flag = "body_color", Default = Color3.fromRGB(166, 112, 255)})
BodySection:Slider({Name = "Reflectance", Flag = "body_reflectance", Min = 0, Max = 100, Default = 0, Suffix = "%"})
BodySection:Toggle({Name = "Rainbow body", Flag = "body_rainbow", Default = false})
BodySection:Slider({Name = "Rainbow speed", Flag = "body_rainbow_speed", Min = 1, Max = 100, Default = 15})
local OutlineSection = Public.ModelMain:Page("Outline")
do
if Public.RagdollsConfirmed then
local ragdolls = Public.ModelMain:Page("Ragdolls")
ragdolls:Toggle({Name = "Enabled", Flag = "ragdoll_style", Default = false, Callback = function() Public.UpdateRagdolls() end})
ragdolls:ColorPicker({Name = "Color", Flag = "ragdoll_color", Default = Color3.fromRGB(154, 107, 255)})
ragdolls:Dropdown({Name = "Material", Flag = "ragdoll_material", Values = {"Original", "SmoothPlastic", "Neon", "ForceField", "Metal"}, Default = "Original"})
ragdolls:Toggle({Name = "Hide ragdolls", Flag = "ragdoll_hide", Default = false})
end
end
BodySection:Toggle({Name = "Sparkles", Flag = "body_sparkles", Default = false})
BodySection:Toggle({Name = "Soft glow", Flag = "body_glow", Default = false})
BodySection:Toggle({Name = "Particle aura", Flag = "body_aura", Default = false})
BodySection:Toggle({Name = "Movement trail", Flag = "body_trail", Default = false})
BodySection:ColorPicker({Name = "Effects color", Flag = "body_effect_color", Default = Color3.fromRGB(166, 112, 255)})
BodySection:Slider({Name = "Particle density", Flag = "body_effect_density", Min = 1, Max = 80, Default = 25})
BodySection:Slider({Name = "Sparkle size", Flag = "body_sparkle_size", Min = 0.05, Max = 0.8, Default = 0.2, Step = 0.05})
BodySection:Slider({Name = "Glow brightness", Flag = "body_glow_brightness", Min = 0.1, Max = 3, Default = 1, Step = 0.1})
BodySection:Slider({Name = "Trail lifetime", Flag = "body_trail_lifetime", Min = 0.1, Max = 2, Default = 0.5, Step = 0.1, Suffix = "s"})
OutlineSection:Toggle({Name = "Local body outline", Flag = "body_outline", Default = false})
OutlineSection:ColorPicker({Name = "Outline color", Flag = "body_outline_color", Default = Color3.fromRGB(235, 219, 255)})
OutlineSection:Slider({Name = "Outline transparency", Flag = "body_outline_transparency", Min = 0, Max = 100, Default = 0, Suffix = "%"})
local MapTab = Public.Navigation.Visuals
local MapSection = Public.VisualCommon:Page("Map style")
MapSection:Toggle({Name = "Enable map style", Flag = "map_style", Default = false})
MapSection:Toggle({Name = "Recolor surfaces", Flag = "map_recolor", Default = false})
MapSection:ColorPicker({Name = "Surface color", Flag = "map_surface_color", Default = Color3.fromRGB(126, 98, 166)})
MapSection:Dropdown({Name = "Surface material", Flag = "map_material", Values = {"Original", "SmoothPlastic", "Neon", "Metal", "Slate", "Concrete"}, Default = "Original"})
MapSection:Toggle({Name = "Hide textures", Flag = "map_hide_textures", Default = false})
MapSection:Button({Name = "Reset body and map", Callback = function()
    for _, flag in ipairs({"body_style", "body_outline", "body_rainbow", "body_sparkles", "body_glow", "body_aura", "body_trail", "map_style"}) do Arvn:SetFlag(flag, false) end
    Public.SurfaceVisuals.Reset()
end})
end
local ViewTab = Public.Navigation.Visuals
local EnvironmentTab = Public.Navigation.Visuals
local EnvironmentSection = Public.VisualCommon:Page("Environment")
EnvironmentSection:Toggle({Name = "Enable environment", Flag = "environment", Default = false, Callback = function(on) if not on then restoreEnvironment() end end})
EnvironmentSection:Dropdown({Name = "Sky preset", Flag = "sky_preset", Values = {"Original", "Daylight", "Sunset", "Night"}, Default = "Original"})
EnvironmentSection:Slider({Name = "Time of day", Flag = "environment_time", Min = 0, Max = 24, Default = OriginalLighting.ClockTime})
EnvironmentSection:Slider({Name = "Brightness", Flag = "environment_brightness", Min = 0, Max = 10, Default = 2})
EnvironmentSection:ColorPicker({Name = "Ambient", Flag = "ambient_color", Default = Color3.fromRGB(100, 70, 140)})
EnvironmentSection:ColorPicker({Name = "Outdoor ambient", Flag = "outdoor_color", Default = Color3.fromRGB(80, 60, 115)})
EnvironmentSection:Toggle({Name = "Remove shadows", Flag = "environment_no_shadows", Default = false})
local GradingSection = Public.VisualCommon:Page("Color grading")
GradingSection:ColorPicker({Name = "World tint", Flag = "world_color", Default = Color3.fromRGB(235, 219, 255)})
GradingSection:Slider({Name = "Contrast", Flag = "world_contrast", Min = -100, Max = 100, Default = 0})
GradingSection:Slider({Name = "Saturation", Flag = "world_saturation", Min = -100, Max = 100, Default = 0})
GradingSection:Toggle({Name = "Bloom", Flag = "environment_bloom", Default = false})
GradingSection:Slider({Name = "Bloom intensity", Flag = "bloom_intensity", Min = 0, Max = 200, Default = 20})
GradingSection:Button({Name = "Reset environment", Callback = function()
    Arvn:SetFlag("environment", false)
    Arvn:SetFlag("sky_preset", "Original")
    Arvn:SetFlag("environment_bloom", false)
    Arvn:SetFlag("environment_no_shadows", false)
    restoreEnvironment()
end})
local PaletteTab = Public.Navigation.Visuals
local PaletteSection = Public.PlayerMain:Page("Colors")
PaletteSection:ColorPicker({Name = "Enemies visible", Flag = "enemy_color", Default = Color3.fromRGB(166, 112, 255)})
PaletteSection:ColorPicker({Name = "Enemies behind walls", Flag = "hidden_color", Default = Color3.fromRGB(119, 78, 186)})
PaletteSection:ColorPicker({Name = "Teammates", Flag = "team_color", Default = Color3.fromRGB(207, 170, 255)})
PaletteSection:ColorPicker({Name = "ESP text", Flag = "esp_text_color", Default = Color3.fromRGB(235, 219, 255)})
PaletteSection:ColorPicker({Name = "Health low", Flag = "health_low_color", Default = Color3.fromRGB(119, 78, 186)})
PaletteSection:ColorPicker({Name = "Health high", Flag = "health_high_color", Default = Color3.fromRGB(207, 170, 255)})
PaletteSection:ColorPicker({Name = "View direction", Flag = "direction_color", Default = Color3.fromRGB(235, 219, 255)})
PaletteSection:ColorPicker({Name = "World objects", Flag = "object_color", Default = Color3.fromRGB(180, 115, 255)})
local EffectPaletteSection = Public.VisualCommon:Page("Effects palette")
EffectPaletteSection:ColorPicker({Name = "Crosshair and FOV", Flag = "crosshair_color", Default = Color3.fromRGB(235, 219, 255)})
EffectPaletteSection:ColorPicker({Name = "Bullet tracers", Flag = "bullet_color", Default = Color3.fromRGB(185, 137, 255)})
EffectPaletteSection:ColorPicker({Name = "Hitmarker", Flag = "hitmarker_color", Default = Color3.fromRGB(235, 219, 255)})
EffectPaletteSection:ColorPicker({Name = "HUD accent", Flag = "hud_color", Default = Color3.fromRGB(207, 170, 255)})
local ViewSection = Public.VisualCommon:Page("View")
Public.VisualCommon:Toggle({Name = "Force Thirdperson", Flag = "force_thirdperson", Default = false, Risky = true, Callback = function(on) if on then applyThirdPerson() else restoreThirdPerson() end end})
Public.VisualCommon:Toggle({Name = "Visual Recoil", Flag = "no_recoil", Default = false})
ViewSection:Toggle({Name = "Remove weapon kick", Flag = "no_kick", Default = false})
ViewSection:Slider({Name = "Thirdperson distance", Flag = "thirdperson_distance", Min = 4, Max = 20, Default = 8, Suffix = " studs", Callback = function() if Flags.force_thirdperson then applyThirdPerson() end end})
Public.VisualCommon:Toggle({Name = "Crosshair", Flag = "crosshair", Default = false})
ViewSection:Dropdown({Name = "Crosshair rule", Flag = "crosshair_rule", Values = {"Always", "Hide with knife", "Hide with grenade"}, Default = "Always"})
ViewSection:Toggle({Name = "Weapon panel", Flag = "weapon_hud", Default = false})
ViewSection:Toggle({Name = "Ammo indicator", Flag = "ammo_indicator", Default = false})
ViewSection:Slider({Name = "Low ammo threshold", Flag = "low_ammo_threshold", Min = 1, Max = 100, Default = 25, Suffix = "%"})
local EffectsSection = Public.VisualCommon:Page("Combat effects")
EffectsSection:Toggle({Name = "Replace weapon fire sound", Flag = "shot_sound", Default = false})
EffectsSection:Dropdown({Name = "Weapon fire preset", Flag = "shot_sound_preset", Values = {"None", "Soft", "Tick", "Click", "Pop", "Bubble", "Glass", "Mech", "Switch", "Chime", "Ping", "Bell", "Swoosh", "Drop", "Custom"}, Default = "Mech"})
EffectsSection:Slider({Name = "Weapon fire volume", Flag = "shot_sound_volume", Min = 0, Max = 100, Default = 50, Suffix = "%"})
EffectsSection:Input({Name = "Weapon fire sound ID", Flag = "shot_sound_id", Default = ""})
EffectsSection:Button({Name = "Test weapon fire sound", Callback = function() Public.PlayCombatSound("shot") end})
EffectsSection:Toggle({Name = "Hit sound", Flag = "hit_sound", Default = false})
EffectsSection:Dropdown({Name = "Hit preset", Flag = "hit_sound_preset", Values = {"None", "Soft", "Tick", "Click", "Pop", "Bubble", "Glass", "Mech", "Switch", "Chime", "Ping", "Bell", "Swoosh", "Drop", "Custom"}, Default = "Tick"})
EffectsSection:Slider({Name = "Hit volume", Flag = "hit_sound_volume", Min = 0, Max = 100, Default = 50, Suffix = "%"})
EffectsSection:Input({Name = "Hit sound ID", Flag = "hit_sound_id", Default = ""})
EffectsSection:Button({Name = "Test hit sound", Callback = function() Public.PlayCombatSound("hit") end})
EffectsSection:Toggle({Name = "Kill sound", Flag = "kill_sound", Default = false})
EffectsSection:Dropdown({Name = "Kill preset", Flag = "kill_sound_preset", Values = {"None", "Soft", "Tick", "Click", "Pop", "Bubble", "Glass", "Mech", "Switch", "Chime", "Ping", "Bell", "Swoosh", "Drop", "golda", "fidi midi", "lopata challenge", "Custom"}, Default = "Chime"})
EffectsSection:Slider({Name = "Kill volume", Flag = "kill_sound_volume", Min = 0, Max = 100, Default = 60, Suffix = "%"})
EffectsSection:Input({Name = "Kill sound ID", Flag = "kill_sound_id", Default = ""})
EffectsSection:Button({Name = "Test kill sound", Callback = function() Public.PlayCombatSound("kill") end})
Public.VisualCommon:Toggle({Name = "Hit Marker", Flag = "hitmarker", Default = false})
local InterfaceTab = Public.Navigation.Visuals
local InterfaceSection = Public.VisualCommon:Page("Overlays")
InterfaceSection:Toggle({Name = "Spectators", Flag = "spectators", Default = false})
InterfaceSection:Toggle({Name = "Watermark", Flag = "ov_wm", Default = false})
InterfaceSection:Toggle({Name = "Target panel", Flag = "target_panel", Default = false})
InterfaceSection:Toggle({Name = "Keybind list", Flag = "keybind_list", Default = false})

end
do

Public.Navigation.Skins:CustomPage(Public.SkinStudio.BuildGallery)
local InventoryWeaponTab = Public.Navigation.SkinEditor
local InventoryWeaponSection = InventoryWeaponTab:Section({Name = "Weapons", Side = "Left"})
local InitialCamera = camera()
local InitialWeapon, InitialSkins = getCameraWeapon(InitialCamera)
refreshSkinOptions(InitialWeapon, InitialSkins)
InventoryWeaponSection:Toggle({Name = "Skin changer", Flag = "skin_changer", Default = false, Callback = function(on) if not on then restoreSkins() end end})
InventoryWeaponSection:Input({Name = "Loadout data", Flag = "skin_loadout", Default = HttpService:JSONEncode(Public.SkinStudio.Loadout), Visible = false})
InventoryWeaponSection:Input({Name = "Knife model data", Flag = "skin_knife_model", Default = "", Visible = false})
Public.SkinStudio.WeaponControl = InventoryWeaponSection:Dropdown({Name = "Model", Flag = "skin_edit_weapon", Values = Public.SkinStudio.Weapons, Default = InitialWeapon and InitialWeapon.Name or Public.SkinStudio.Weapons[1], Callback = function() Public.SkinStudio.SelectWeapon() end})
Public.SkinStudio.SkinControl = InventoryWeaponSection:Dropdown({Name = "Skin", Flag = "skin_name", Values = SkinOptions, Default = "Stock", Callback = function() local studio = Public.SkinStudio; if not studio.Updating then studio.Updating = true; studio.Options(); studio.Updating = false; if studio.EditorReady then studio.Assign() end end end})
Public.SkinStudio.WearControl = InventoryWeaponSection:Dropdown({Name = "Wear", Flag = "skin_wear", Values = {"Factory New", "Minimal Wear", "Field-Tested", "Well-Worn", "Battle-Scarred"}, Default = "Factory New", Callback = function() local studio = Public.SkinStudio; studio.PreviewKey = nil; if studio.EditorReady and not studio.Updating then studio.Assign() end end})
InventoryWeaponSection:Button({Name = "Apply to weapon", Callback = Public.SkinStudio.Assign})
InventoryWeaponSection:Button({Name = "Remove weapon skin", Callback = function() Public.SkinStudio.Loadout.Weapons[Flags.skin_edit_weapon or ""] = nil; Public.SkinStudio.Commit(); Public.SkinStudio.SelectWeapon() end})
InventoryWeaponSection:Custom({Name = "Preview", Height = 230, Build = Public.SkinStudio.BuildPreview})
SkinInfo = InventoryWeaponSection:Info({Name = "Equipped weapon", Value = LastSkinWeapon or "No weapon"})
InventoryWeaponSection:Toggle({Name = "Weapon tint", Flag = "weapon_tint", Default = false, Callback = function(on) if not on then restoreInventory() end end})
InventoryWeaponSection:Dropdown({Name = "Color", Flag = "weapon_color", Values = {"Crimson", "Cyan", "Gold", "Violet", "Green"}, Default = "Violet"})
InventoryWeaponSection:Dropdown({Name = "Material", Flag = "weapon_finish", Values = {"Original", "Metal", "Neon"}, Default = "Original"})
local InventoryGloveTab = Public.Navigation.SkinEditor
local InventoryGloveSection = InventoryGloveTab:Section({Name = "Gloves", Side = "Right"})
refreshGloveTypes(skinsRoot(), weaponsRoot())
InventoryGloveSection:Toggle({Name = "Glove changer", Flag = "glove_changer", Default = false, Callback = function(on) if not on then restoreGloves() end end})
InventoryGloveSection:Dropdown({Name = "Glove type", Flag = "glove_type", Values = GloveTypes, Default = "Default"})
InventoryGloveSection:Dropdown({Name = "Skin", Flag = "glove_skin", Values = GloveSkins, Default = "Stock"})
InventoryGloveSection:Dropdown({Name = "Wear", Flag = "glove_wear", Values = {"Factory New", "Minimal Wear", "Field-Tested", "Well-Worn", "Battle-Scarred"}, Default = "Factory New"})
GloveInfo = InventoryGloveSection:Info({Name = "Glove type", Value = "Default"})
InventoryGloveSection:Toggle({Name = "Glove tint", Flag = "glove_tint", Default = false, Callback = function(on) if not on then restoreInventory() end end})
InventoryGloveSection:Dropdown({Name = "Color", Flag = "glove_color", Values = {"Crimson", "Cyan", "Gold", "Violet", "Green"}, Default = "Violet"})
local Sets = InventoryWeaponTab:Section({Name = "Skin sets", Side = "Right"})
Public.SkinStudio.SetControl = Sets:Dropdown({Name = "Saved sets", Flag = "skin_set_choice", Values = Public.SkinStudio.Names, Default = "", Callback = function(name) if Public.SkinStudio.Presets[name] then Arvn:SetFlag("skin_set_name", name) end end})
Sets:Input({Name = "Set name", Flag = "skin_set_name", Default = "", Placeholder = "my purple set"})
Sets:Button({Name = "Create set", Callback = function() Public.SkinStudio.SaveSet(true) end})
Sets:Button({Name = "Save set", Callback = function() Public.SkinStudio.SaveSet(false) end})
Sets:Button({Name = "Apply set", Callback = Public.SkinStudio.ApplySet})
Sets:Button({Name = "Rename set", Callback = Public.SkinStudio.RenameSet})
Sets:Button({Name = "Delete set", Callback = Public.SkinStudio.DeleteSet})
Public.SkinStudio.Status = Sets:Info({Name = "Status", Value = "choose a weapon, then apply its skin"})
Public.SkinStudio.SelectWeapon()
Public.SkinStudio.EditorReady = true
InventoryWeaponSection:Button({Name = "Back to catalog", Callback = function() Public.Navigation.Skins:Select() end})

end
do

local MovementTab = Public.Navigation.Misc
local MovementSection = MovementTab:Section({Name = "Movement", Side = "Left"})
MovementSection:Toggle({Name = "Bunny hop (hold Space)", Flag = "bunny_hop", Default = false})
MovementSection:Toggle({Name = "Air strafe", Flag = "air_strafe", Default = false})
MovementSection:Toggle({Name = "Quick stop", Flag = "quick_stop", Default = false})
local moveSettings = MovementSection:Page("Additional")
moveSettings:Toggle({Name = "Predictive dodge", Flag = "dodge", Default = false, Risky = true})
moveSettings:Toggle({Name = "Auto peek", Flag = "auto_peek", Default = false, Keybind = {Key = "V", Mode = "Hold"}, Callback = function(on) if not on then resetAutoPeek() end end})

end

end

do
local misc = Public.Navigation.Misc
local features = misc:Section({Name = "Features", Side = "Right"})
features:Toggle({Name = "Field of View", Flag = "custom_fov", Default = false})
features:Slider({Name = "Camera FOV", Flag = "camera_fov", Min = 40, Max = 120, Default = 80, Suffix = "°"})
features:Slider({Name = "Override Zoom", Flag = "zoom_reduction", Min = 0, Max = 75, Default = 0, Suffix = "%"})
local other = misc:Section({Name = "Other", Side = "Left"})
other:Toggle({Name = "Display Log Events", Flag = "shot_logs", Default = false})
end
function Public.MigrateConfig()
    if tostring(Flags.config_format) == "2" then return end
    local cam = workspace.CurrentCamera
    if cam and tonumber(Flags.aim_radius) then
        Flags.rage_fov = math.clamp(math.deg(2 * math.atan((tonumber(Flags.aim_radius) or 150) * math.tan(math.rad(cam.FieldOfView / 2)) / math.max(cam.ViewportSize.Y / 2, 1))), 1, 180)
    end
    Flags.weapon_profiles = false
    Flags.config_format = "2"
end
Public.MigrateConfig()
task.defer(function()
if getgenv().BloxStrikeArvn ~= Public then return end
local marker = "NetanyahuCC/" .. tostring(LocalPlayer.UserId) .. "/purple-defaults-v2"
if not isfile(marker) then
    local colors = {
        body_color = {Color3.fromRGB(70, 190, 255), Color3.fromRGB(166, 112, 255)},
        body_effect_color = {Color3.fromRGB(70, 190, 255), Color3.fromRGB(166, 112, 255)},
        body_outline_color = {Color3.new(1, 1, 1), Color3.fromRGB(235, 219, 255)},
        map_surface_color = {Color3.fromRGB(145, 160, 180), Color3.fromRGB(126, 98, 166)},
        world_color = {Color3.new(1, 1, 1), Color3.fromRGB(235, 219, 255)},
        enemy_color = {Color3.fromRGB(255, 94, 94), Color3.fromRGB(166, 112, 255)},
        hidden_color = {Color3.fromRGB(255, 184, 77), Color3.fromRGB(119, 78, 186)},
        team_color = {Color3.fromRGB(90, 190, 255), Color3.fromRGB(207, 170, 255)},
        esp_text_color = {Color3.new(1, 1, 1), Color3.fromRGB(235, 219, 255)},
        crosshair_color = {Color3.new(1, 1, 1), Color3.fromRGB(235, 219, 255)},
        bullet_color = {Color3.fromRGB(91, 194, 255), Color3.fromRGB(185, 137, 255)},
        ragdoll_color = {Color3.fromRGB(130, 90, 255), Color3.fromRGB(154, 107, 255)},
        ambient_color = {OriginalLighting.Ambient, Color3.fromRGB(100, 70, 140)},
        outdoor_color = {OriginalLighting.OutdoorAmbient, Color3.fromRGB(80, 60, 115)},
    }
    for flag, pair in pairs(colors) do
        if palette(flag, pair[2]):ToHex() == pair[1]:ToHex() then Arvn:SetFlag(flag, pair[2]) end
    end
    if Flags.ui_theme == "Dark" or Flags.ui_theme == "Blue" then Arvn:SetTheme("Purple") end
    if palette("ui_accent", Color3.fromRGB(154, 107, 255)):ToHex() == Color3.fromRGB(40, 163, 232):ToHex() then Window:SetAccent(Color3.fromRGB(154, 107, 255)) end
    if Flags.weapon_color == "Crimson" then Arvn:SetFlag("weapon_color", "Violet") end
    if Flags.glove_color == "Cyan" then Arvn:SetFlag("glove_color", "Violet") end
    writefile(marker, "1")
end
end)
do
local loadConfig = Window.LoadConfig
Window.LoadConfig = function(self, name)
    local result = loadConfig(self, name)
    Public.MigrateConfig()
    return result
end
end

do
    local navigation = Public.Navigation
    local rows, sources, used = {}, {}, {}
    local counts = {Before = 0, After = 0}
    for _, key in ipairs({"Rage", "Legit", "Visuals", "Misc"}) do
        local tab = navigation[key]
        sources[key] = {}
        for _, column in ipairs(tab.entry.page or {}) do
            for _, section in ipairs(column) do
                for _, row in ipairs(section.rows) do
                    if not rows[row.id] then
                        rows[row.id] = row
                        sources[key][#sources[key] + 1] = row
                        counts.Before += 1
                    end
                end
            end
        end
        tab.entry.page = {{}, {}}
    end
    local function place(container, keys)
        for key in keys:gmatch("%S+") do
            local row = rows[key]
            if row and not used[key] then
                used[key] = true
                counts.After += 1
                container.rows[#container.rows + 1] = row
                if container.also then container.also[#container.also + 1] = row end
                local element = Arvn.Elements[key]
                if element then element.Page = container.page; element.List = container.rows; element.Also = container.also end
            end
        end
    end
    local function section(tab, name, side, main, pages)
        local result = navigation[tab]:Section({Name = name, Side = side})
        place(result, main or "")
        for _, page in ipairs(pages or {}) do place(result:Page(page[1]), page[2]) end
        return result
    end
    section("Rage", "Main", "Left", "rage_aim silent_aim rage_autofire", {
        {"Target radius", "silent_360 rage_fov"},
        {"Wall penetration", "rage_penetration rage_penetration_mode"},
        {"Firing", "rage_autostop auto_scope rage_reaction no_spread"}
    })
    section("Rage", "Targets", "Right", "aim_priority target_part", {
        {"Checks", "head_only target_lock team_check visible_check multipoint"},
        {"Prediction", "prediction_mode prediction_time prediction_limit"}
    })
    section("Rage", "Anti-aim", "Right", "anti_aim slow_walk", {
        {"Direction", "anti_aim_pitch anti_aim_mode anti_aim_jitter"},
        {"Speed", "spin_speed slow_walk_speed"}
    })
    section("Legit", "Aim assistance", "Left", "aimbot legit_activation legit_fov aim_smooth", {
        {"Response", "mouse_override legit_reaction legit_reset"}
    })
    section("Legit", "Triggerbot", "Right", "triggerbot", {{"Timing", "trigger_delay"}})
    section("Visuals", "Players", "Left", "esp_enabled esp_teammates", {
        {"Display", "esp_box esp_skeleton esp_name esp_health esp_distance"},
        {"Equipment", "esp_weapon esp_armor esp_defuser esp_money"},
        {"Tracking", "esp_tracer esp_direction esp_arrow radar esp_movement esp_move_speed"},
        {"Highlight", "esp_chams chams_style"},
        {"Colors", "enemy_color hidden_color team_color esp_text_color health_low_color health_high_color direction_color"}
    })
    section("Visuals", "Body", "Left", "body_style body_rainbow", {
        {"Material", "body_material body_color body_reflectance body_rainbow_speed"},
        {"Particles", "body_sparkles body_glow body_aura body_trail"},
        {"Particle settings", "body_effect_color body_effect_density body_sparkle_size body_glow_brightness body_trail_lifetime"},
        {"Outline", "body_outline body_outline_color body_outline_transparency"},
        {"Ragdolls", "ragdoll_style ragdoll_color ragdoll_material ragdoll_hide"}
    })
    section("Visuals", "World objects", "Right", "esp_bomb esp_weapons esp_grenades", {
        {"Options", "grenade_warning esp_hostages object_color"}
    })
    local map = section("Visuals", "Map and lighting", "Right", "environment map_style", {
        {"Lighting", "fullbright nightmode environment_time environment_brightness ambient_color outdoor_color"},
        {"Sky and removals", "sky_preset no_fog remove_post environment_no_shadows"},
        {"Surfaces", "map_recolor map_surface_color map_material map_hide_textures"},
        {"Color grading", "world_color world_contrast world_saturation environment_bloom bloom_intensity"}
    })
    local resets = map:Page("Reset")
    for key, row in pairs(rows) do
        if row.label and (row.label:lower() == "reset body and map" or row.label:lower() == "reset environment") then place(resets, key) end
    end
    section("Visuals", "Camera", "Right", "force_thirdperson no_recoil no_kick", {
        {"Third person", "thirdperson_distance"},
        {"Crosshair", "crosshair crosshair_rule aim_circle crosshair_color"}
    })
    section("Effects", "Bullet tracers", "Left", "bullet_tracers", {
        {"Appearance", "bullet_material bullet_width bullet_glow bullet_color"},
        {"Timing", "bullet_lifetime"}
    })
    section("Effects", "Hitmarker", "Left", "hitmarker", {{"Color", "hitmarker_color"}})
    local audio = section("Effects", "Sounds", "Right", "shot_sound hit_sound kill_sound")
    for _, kind in ipairs({"shot", "hit", "kill"}) do
        local page = audio:Page(kind == "shot" and "Weapon fire" or kind == "hit" and "Hit" or "Kill")
        place(page, kind .. "_sound_preset " .. kind .. "_sound_volume " .. kind .. "_sound_id")
        for key, row in pairs(rows) do
            if row.label and row.label:lower() == "test " .. (kind == "shot" and "weapon fire" or kind) .. " sound" then place(page, key) end
        end
    end
    section("HUD", "Widgets", "Left", "ov_wm spectators shot_logs", {{"Extra panels", "target_panel keybind_list"}})
    section("HUD", "Weapon information", "Right", "weapon_hud ammo_indicator", {{"Appearance", "low_ammo_threshold hud_color"}})
    section("Misc", "Movement", "Left", "bunny_hop air_strafe quick_stop", {{"Assists", "auto_peek dodge"}})
    section("Misc", "Camera FOV", "Right", "custom_fov", {{"Settings", "camera_fov zoom_reduction"}})
    for _, key in ipairs({"Rage", "Legit", "Visuals", "Misc"}) do
        local extra
        for _, row in ipairs(sources[key]) do
            if not used[row.id] then
                if not extra then extra = navigation[key]:Section({Name = "Additional", Side = "Left"}):Page("Options") end
                place(extra, row.id)
            end
        end
    end
    assert(counts.Before == counts.After, "menu layout lost controls")
    Public.MenuLayout = counts
end

Public.SharedEffects = {Peers = {}, States = {}, Busy = false, Published = false, Generation = 0, LastReceived = 0, Error = nil}
local function clearSharedWeapon(state)
    for _, motor in ipairs(state.Motors or {}) do motor:Destroy() end
    if state.Weapon then state.Weapon:Destroy() end
    for part, value in pairs(state.Hidden or {}) do if part.Parent then part.LocalTransparencyModifier = value end end
    state.Weapon = nil; state.Motors = {}; state.Hidden = {}; state.WeaponKey = nil
end
local function clearSharedEffects()
    local shared = Public.SharedEffects
    for _, state in pairs(shared.States) do resetBodyEffectState(state); clearSharedWeapon(state) end
    table.clear(shared.States)
    table.clear(shared.Peers)
end
local function exchangeEffects(enabled)
    local color = palette("body_effect_color", Color3.fromRGB(166, 112, 255))
    local effects = {color = {color.R, color.G, color.B}}
    for _, flag in ipairs({"body_sparkles", "body_glow", "body_aura", "body_trail", "body_rainbow", "body_effect_density", "body_sparkle_size", "body_glow_brightness", "body_trail_lifetime", "body_rainbow_speed"}) do effects[flag] = Flags[flag] end
    if enabled and Flags.skin_changer and Public.SkinStudio then
        local raw = LocalPlayer:GetAttribute("CurrentEquipped")
        local ok, data = pcall(HttpService.JSONDecode, HttpService, raw or "")
        if ok and type(data) == "table" and type(data.Name) == "string" then
            if data.Name == "Karambit" or data.Name == "M9 Bayonet" or string.find(data.Name, "Knife", 1, true) then data.Name = Flags.skin_knife_model or data.Name end
            local choice = Public.SkinStudio.Loadout.Weapons[data.Name]
            effects.weapon = {name = data.Name, skin = choice and choice.Skin or data.Skin or "Stock", wear = choice and choice.Wear or "Factory New"}
        end
    end
    return Public.CommunityRequest("POST", "/effects", {room = tostring(game.PlaceId) .. ":" .. game.JobId, userId = LocalPlayer.UserId, enabled = enabled, effects = effects})
end
local function stopSharing()
    local shared = Public.SharedEffects
    shared.Generation += 1
    clearSharedEffects()
    if shared.Published then
        shared.Published = false
        task.spawn(function() pcall(exchangeEffects, false) end)
    end
end
Arvn:OnEject(stopSharing)
Runtime:Every("shared effects exchange", 10, function()
    local shared = Public.SharedEffects
    if not Running or shared.Busy or game.JobId == "" then return end
    shared.Busy = true
    shared.Published = true
    local generation = shared.Generation
    task.spawn(function()
        local ok, result = pcall(exchangeEffects, true)
        shared.Busy = false
        if not Running or generation ~= shared.Generation then
            pcall(exchangeEffects, false)
            return
        end
        if not ok then shared.Error = tostring(result); return end
        shared.Error = nil
        shared.LastReceived = os.clock()
        local peers = {}
        for _, peer in ipairs(result.players or {}) do
            if type(peer.userId) == "number" and type(peer.effects) == "table" and peer.userId ~= LocalPlayer.UserId then peers[peer.userId] = peer.effects end
        end
        shared.Peers = peers
    end)
end)
Runtime:Every("shared effects visuals", 1 / 30, function()
    local shared = Public.SharedEffects
    if not Running or os.clock() - shared.LastReceived > 30 then clearSharedEffects(); return end
    local active = {}
    for userId, effects in pairs(shared.Peers) do
        local player = Players:GetPlayerByUserId(userId)
        local model = player and Characters:FindFirstChild(player.Name)
        if model and model.Parent == Characters and isAlive(model) and type(effects.color) == "table" and #effects.color == 3 then
            active[userId] = true
            local state = shared.States[userId]
            if not state then state = {Objects = {}}; shared.States[userId] = state end
            local options = table.clone(effects)
            options.body_effect_color = Color3.new(effects.color[1], effects.color[2], effects.color[3])
            updateBodyEffectsFor(model, state, options)
            local choice = effects.weapon
            local key = type(choice) == "table" and HttpService:JSONEncode(choice) or nil
            if state.Owner ~= model or state.WeaponKey ~= key then
                clearSharedWeapon(state)
                state.Owner = model
                if key and type(choice.name) == "string" and type(choice.skin) == "string" then
                    local value = ({["Factory New"] = 0.03, ["Minimal Wear"] = 0.1, ["Field-Tested"] = 0.25, ["Well-Worn"] = 0.4, ["Battle-Scarred"] = 0.7})[choice.wear] or 0.03
                    Public.CreateSharedWeapon(model, {Name = choice.name, Skin = choice.skin, Float = value}, state)
                    if state.Weapon then
                        state.WeaponKey = key
                        for _, child in ipairs(model:GetChildren()) do
                            if child:IsA("Model") and child ~= state.Weapon and (child:FindFirstChild("Insert", true) or child:FindFirstChild("Handle", true)) then
                                for _, part in ipairs(child:GetDescendants()) do if part:IsA("BasePart") then state.Hidden[part] = part.LocalTransparencyModifier; part.LocalTransparencyModifier = 1 end end
                            end
                        end
                    end
                end
            end
        end
    end
    for userId, state in pairs(shared.States) do
        if not active[userId] then resetBodyEffectState(state); clearSharedWeapon(state); shared.States[userId] = nil end
    end
end)

local function shutdown(eject)
    if not Running then return end
    Running = false
    Runtime:Stop()
    Public.ClearShotTracers()
    Public.TracerFolder:Destroy()
    for _, sound in pairs(Public.CombatAudio.Sounds) do sound:Destroy() end
    table.clear(Public.CombatAudio.Sounds)
    RunService:UnbindFromRenderStep("BloxStrikeArvn")
    RunService:UnbindFromRenderStep("BloxStrikeArvnCursor")
    Public.CursorState.Connection:Disconnect()
    Public.UpdateCursor()
    for _, restore in ipairs(HookRestores) do pcall(restore) end
    for _, item in ipairs(Drawings) do pcall(function() item:Remove() end) end
    for _, highlight in pairs(Highlights) do pcall(function() highlight:Destroy() end) end
    if Public.SpectatorWidget then Public.SpectatorWidget:Destroy() end
    if Public.WeaponProfiles.Hud then Public.WeaponProfiles.Hud:Destroy() end
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.ClockTime = OriginalLighting.ClockTime
    Lighting.Ambient = OriginalLighting.Ambient
    Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    Lighting.FogStart = OriginalLighting.FogStart
    Lighting.FogEnd = OriginalLighting.FogEnd
    if Atmosphere and Atmosphere.Parent and OriginalDensity then Atmosphere.Density = OriginalDensity end
    restorePost()
    restoreEnvironment()
    restoreInventory()
    Public.SurfaceVisuals.Reset()
    restoreSkins()
    if Public.SkinStudio then Public.SkinStudio.RestoreHud() end
    if Public.SkinStudio then Public.SkinStudio.RestoreKnife() end
    if Public.SkinStudio then Public.SkinStudio.RestoreCharacterGloves() end
    restoreGloves()
    restoreThirdPerson()
    resetAutoPeek()
    if camera() then camera().FieldOfView = OriginalFov end
    pcall(mouse1release)
    if getgenv().BloxStrikeArvn == Public then getgenv().BloxStrikeArvn = nil end
    if getgenv().VoidsenseCC == Public then getgenv().VoidsenseCC = nil end
    if getgenv().NetanyahuCC == Public then getgenv().NetanyahuCC = nil end
    if eject then pcall(function() Arvn:Eject() end) end
end

Public.Eject = function() Arvn:Eject() end


Arvn:OnEject(function() shutdown(false) end)
State.onCleanup(function() shutdown(true) end)
Arvn:OnFlag("auto_peek", function(on)
    if on then captureAutoPeek() else resetAutoPeek() end
end)
Arvn:OnFlag("force_thirdperson", function(on)
    if on then applyThirdPerson() else restoreThirdPerson() end
end)
Arvn:Connect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed or not Flags.auto_peek or Arvn:IsOpen() then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        captureAutoPeek()
        if AutoPeekOrigin then AutoPeekReturning = true end
    end
end)

local function optionalHook(object, key, predicate, replacement, watchedFlags)
    local original = object[key]
    if type(original) ~= "function" then
        Public.Compatibility.Missing[key] = watchedFlags
        warn("voidsense.cc: unavailable game function " .. key)
        return
    end
    local installed = false
    local function update()
        local enabled = predicate()
        if enabled and not installed then
            object[key] = replacement
            installed = true
        elseif installed and not enabled then
            if object[key] == replacement then object[key] = original end
            installed = false
        end
    end
    for _, flag in ipairs(watchedFlags) do Arvn:OnFlag(flag, update) end
    HookRestores[#HookRestores + 1] = function() if installed and object[key] == replacement then object[key] = original end; installed = false end
    update()
end

local OriginalPerformRaycast = Bullet._performRaycast
optionalHook(Bullet, "_performRaycast", function() return Flags.silent_aim or Flags.no_spread or Flags.bullet_tracers or Flags.hitmarker or Flags.hit_sound or Flags.rage_penetration end, function(self, spread)
    if not Flags.silent_aim and not Flags.no_spread then
        local packet = OriginalPerformRaycast(self, spread)
        recordShot(packet)
        return packet
    end
    local cam = camera()
    if not cam then return {Origin = Vector3.zero, Direction = Vector3.new(0, 0, -1), Distance = 0, Hits = {}} end
    local center = cam.ViewportSize * 0.5
    local viewRay = cam:ViewportPointToRay(center.X, center.Y)
    local selected = nil
    if Flags.silent_aim then
        if Flags.rage_aim then selected = select(2, rageTarget()) else selected = select(2, target(true)) end
    end
    local origin = viewRay.Origin
    local direction = selected and (aimPoint(selected) - origin).Unit or viewRay.Direction.Unit
    if not selected and not Flags.no_spread and spread and spread > 0 then
        local radius = math.rad(math.min(spread, 69) * 0.5)
        local theta = math.random() * math.pi * 2
        local phi = math.random() * radius
        local right = direction:Cross(Vector3.yAxis)
        if right.Magnitude < 0.001 then right = Vector3.xAxis end
        right = right.Unit
        local up = right:Cross(direction).Unit
        direction = (direction * math.cos(phi) + right * math.sin(phi) * math.cos(theta) + up * math.sin(phi) * math.sin(theta)).Unit
    end
    local distance = self.Properties.Range or 500
    if Flags.rage_penetration and Flags.rage_aim then
        local packet = penetrationPacket(origin, direction, self.Properties, selected)
        AimDiagnostics.RayHit = packet.Hits[1] and packet.Hits[1].Instance.Name or "none"
        AimDiagnostics.RayTarget = selected and selected.Parent.Name or "none"
        recordShot(packet)
        return packet
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.CollisionGroup = "Bullet"
    local own = localModel()
    params.FilterDescendantsInstances = own and {own, cam} or {cam}
    local hit = workspace:Raycast(origin, direction * distance, params)
    AimDiagnostics.RayHit = hit and hit.Instance.Name or "none"
    AimDiagnostics.RayTarget = selected and selected.Parent.Name or "none"
    local packet = {Origin = origin, Direction = direction, Distance = distance, Hits = {}}
    if hit then
        packet.Distance = (hit.Position - origin).Magnitude
        packet.Hits[1] = {Position = hit.Position, Instance = hit.Instance, Material = hit.Material.Name, Normal = hit.Normal, Exit = false}
    end
    recordShot(packet)
    return packet
end, {"silent_aim", "no_spread", "bullet_tracers", "hitmarker", "hit_sound", "rage_penetration"})

optionalHook(CameraController, "setWeaponRecoil", function() return Flags.no_recoil end, function()
    CameraController.resetWeaponRecoil()
end, {"no_recoil"})

local AutomaticShotCameraGuard = false
optionalHook(CameraController, "weaponKick", function() return Flags.no_kick or AutomaticShotCameraGuard and Flags.force_thirdperson and thirdPersonAvailable() end, function() end, {"no_kick", "force_thirdperson"})
do
    local soundModule = ReplicatedStorage.Classes:FindFirstChild("Sound")
    local ok, soundClass = pcall(function() return soundModule and require(soundModule :: ModuleScript) end)
    if ok and type(soundClass) == "table" then
        local original = soundClass.play
        optionalHook(soundClass, "play", function() return Flags.shot_sound end, function(self, options, ...)
            local parent = type(options) == "table" and options.Parent
            local own = Characters:FindFirstChild(LocalPlayer.Name)
            local gui = LocalPlayer:FindFirstChild("PlayerGui")
            local cam = workspace.CurrentCamera
            local localSound = typeof(parent) == "Instance" and ((gui and (parent == gui or parent:IsDescendantOf(gui))) or (cam and (parent == cam or parent:IsDescendantOf(cam))) or (own and (parent == own or parent:IsDescendantOf(own))))
            local weapons = ReplicatedStorage.Database.Audio:FindFirstChild("Weapons")
            local weaponGroup = type(self.SoundGroupName) == "string" and weapons and weapons:FindFirstChild(self.SoundGroupName)
            if localSound and weaponGroup and (options.Name == "Shoot" or options.Name == "Silencer") then
                return Public.PlayCombatSound("shot")
            end
            return original(self, options, ...)
        end, {"shot_sound"})
    end
end

optionalHook(CameraController, "setPerspective", function() return Flags.force_thirdperson end, function(firstPerson, mouseEnabled, distance)
    ThirdPersonMouseMode = mouseEnabled == true
    if Flags.force_thirdperson and thirdPersonAvailable() then
        ThirdPersonApplied = true
        setViewmodelHidden(true)
        local result = ThirdPersonOriginal(false, mouseEnabled, Flags.thirdperson_distance or 8)
        LocalPlayer.CameraMinZoomDistance = Flags.thirdperson_distance or 8
        return result
    end
    if not thirdPersonAvailable() then restoreThirdPerson() end
    return ThirdPersonOriginal(firstPerson, mouseEnabled, distance)
end, {"force_thirdperson"})

local OriginalFirePosition = CameraController.toWeaponFirePosition
optionalHook(CameraController, "toWeaponFirePosition", function() return Flags.force_thirdperson end, function(...)
    if thirdPersonAvailable() then return nil end
    return OriginalFirePosition(...)
end, {"force_thirdperson"})

optionalHook(CameraController, "updateCamera", function() return AutomaticShotCameraGuard and Flags.force_thirdperson and thirdPersonAvailable() end, function() end, {"force_thirdperson"})

local originalSample = CharacterClass.SampleInput
local AntiAimJitterSide = false
optionalHook(CharacterClass, "SampleInput", function() return Flags.anti_aim or Flags.rage_autostop or Flags.bunny_hop end, function(self, ...)
    local input = originalSample(self, ...)
    if type(input) == "table" then
        if Flags.bunny_hop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and self.Player == LocalPlayer and not self.IsDestroyed and not Arvn:IsOpen() and isrbxactive() then
            local movement = self.MovementState
            local moving = typeof(input.Move) == "Vector2" and input.Move.Magnitude > 0.01
            if movement and not self.IsClimbing then
                local grounded = movement.OnGround == true
                local wasJumping = MovementButtons.has(movement.PreviousButtons or 0, MovementButtons.Jump)
                input.Buttons = MovementButtons.with(input.Buttons or 0, MovementButtons.Jump, grounded and not wasJumping)
                if not grounded and moving then
                    local velocity = movement.Velocity or self.GlobalVelocity
                    if typeof(velocity) == "Vector3" then
                        local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
                        local config = MovementSettings.getMovementConfig(64)
                        local cap = config.BunnyHopAirSpeedCap > 0 and config.BunnyHopAirSpeedCap or config.AirSpeedCap
                        if horizontal.Magnitude > math.max(cap, 0.5) then
                            local basis = CFrame.Angles(0, input.LookYaw or 0, 0)
                            local wish = basis:VectorToWorldSpace(Vector3.new(input.Move.X, 0, input.Move.Y)).Unit
                            local direction = horizontal.Unit
                            local turn = math.atan2(direction:Cross(wish).Y, direction:Dot(wish))
                            local angle = math.acos(math.clamp(cap * 0.8 / horizontal.Magnitude, 0, 1))
                            direction = CFrame.Angles(0, turn >= 0 and angle or -angle, 0):VectorToWorldSpace(direction)
                            local localDirection = basis:VectorToObjectSpace(direction)
                            input.Move = Vector2.new(localDirection.X, localDirection.Z)
                        end
                    end
                end
            end
        end
        if Flags.rage_autostop and Flags.rage_aim and CurrentTarget and (Flags.rage_autofire or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
            input.Move = Vector2.zero
        end
        if not Flags.anti_aim then return input end
        local originalYaw = input.LookYaw or 0
        local mode = Flags.anti_aim_mode or "Backwards"
        local offset = mode == "Forward" and 0 or mode == "Left" and -math.pi * 0.5 or mode == "Right" and math.pi * 0.5 or mode == "Spin" and math.rad((os.clock() * (Flags.spin_speed or 14400)) % 360) or math.pi
        AntiAimJitterSide = not AntiAimJitterSide
        local jitter = Flags.anti_aim_jitter or "Off"
        if jitter == "Offset" then offset += AntiAimJitterSide and 0.24 or 0 elseif jitter == "Center" then offset += AntiAimJitterSide and 0.24 or -0.24 elseif mode == "Jitter" then offset += AntiAimJitterSide and 0.65 or -0.65 end
        local alteredYaw = math.atan2(math.sin(originalYaw + offset), math.cos(originalYaw + offset))
        if typeof(input.Move) == "Vector2" and input.Move.Magnitude > 0 then
            local localMove = Vector3.new(input.Move.X, 0, input.Move.Y)
            local worldMove = CFrame.Angles(0, originalYaw, 0):VectorToWorldSpace(localMove)
            local correctedMove = CFrame.Angles(0, alteredYaw, 0):VectorToObjectSpace(worldMove)
            input.Move = Vector2.new(correctedMove.X, correctedMove.Z)
        end
        input.LookYaw = alteredYaw
        if Flags.anti_aim_pitch == "Up" then input.VerticalLook = 1 elseif Flags.anti_aim_pitch == "Down" then input.VerticalLook = -1 end
    end
    return input
end, {"anti_aim", "rage_autostop", "bunny_hop"})

local originalMove = Controls.moveFunction
optionalHook(Controls, "moveFunction", function() return Flags.dodge or Flags.air_strafe or Flags.slow_walk or Flags.quick_stop or Flags.auto_peek end, function(player, vector, relative)
    if Flags.air_strafe and not (Flags.bunny_hop and UserInputService:IsKeyDown(Enum.KeyCode.Space)) and typeof(vector) == "Vector3" then
        local character = CharacterController.getCurrentCharacter()
        local cam = camera()
        if cam then
            local _, yaw = cam.CFrame:ToEulerAnglesYXZ()
            local delta = LastStrafeYaw and math.atan2(math.sin(yaw - LastStrafeYaw), math.cos(yaw - LastStrafeYaw)) or 0
            LastStrafeYaw = yaw
            if character and character.OnGround == false and vector.Magnitude > 0.01 then
            local side = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
            if math.abs(delta) > 0.0001 then StrafeSide = delta > 0 and -1 or 1 elseif side ~= 0 then StrafeSide = side end
            if relative then vector = Vector3.new(StrafeSide, 0, 0) else
                local right = cam.CFrame.RightVector
                vector = Vector3.new(right.X, 0, right.Z).Unit * StrafeSide
            end
            end
        end
    end
    if typeof(vector) == "Vector3" and os.clock() - LastDodge > 0.4 then
        local own = localModel()
        local ownRoot = own and own.PrimaryPart
        if ownRoot then
            for _, model in ipairs(CharacterModels) do
                if model:IsA("Model") and isEnemy(model) and model.PrimaryPart then
                    local root = model.PrimaryPart
                    local delta = ownRoot.Position - root.Position
                    if delta.Magnitude < 35 and delta.Magnitude > 2 and root.CFrame.LookVector:Dot(delta.Unit) > 0.92 and visible(model, root.Position) then
                        DodgeSide = -DodgeSide
                        local sideVector = root.CFrame.RightVector * DodgeSide
                        local cam = camera()
                        if relative and cam then
                            local _, yaw = cam.CFrame:ToEulerAnglesYXZ()
                            sideVector = CFrame.Angles(0, yaw, 0):VectorToObjectSpace(sideVector)
                        end
                        vector = vector + sideVector
                        if vector.Magnitude > 1 then vector = vector.Unit end
                        LastDodge = os.clock()
                        break
                    end
                end
            end
        end
    end
    if Flags.slow_walk and typeof(vector) == "Vector3" then vector *= (Flags.slow_walk_speed or 35) / 100 end
    if Flags.quick_stop and typeof(vector) == "Vector3" and vector.Magnitude < 0.05 then
        local own = localModel()
        local root = own and own.PrimaryPart
        if root then
            local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            if velocity.Magnitude > 2 then
                if relative then
                    local cam = camera()
                    if cam then
                        local _, yaw = cam.CFrame:ToEulerAnglesYXZ()
                        velocity = CFrame.Angles(0, yaw, 0):VectorToObjectSpace(velocity)
                    end
                end
                vector = -velocity.Unit
            end
        end
    end
    if Flags.auto_peek and typeof(vector) == "Vector3" then
        captureAutoPeek()
        local own = localModel()
        local root = own and own.PrimaryPart
        if AutoPeekReturning and (own ~= AutoPeekModel or not root or not AutoPeekOrigin) then
            resetAutoPeek()
        elseif AutoPeekReturning then
            local delta = Vector3.new(AutoPeekOrigin.X - root.Position.X, 0, AutoPeekOrigin.Z - root.Position.Z)
            if delta.Magnitude <= 1.25 then
                AutoPeekReturning = false
            else
                local move = delta.Unit
                local cam = camera()
                if relative and cam then
                    local _, yaw = cam.CFrame:ToEulerAnglesYXZ()
                    move = CFrame.Angles(0, yaw, 0):VectorToObjectSpace(move)
                end
                vector = move
            end
        end
    elseif AutoPeekOrigin then
        resetAutoPeek()
    end
    return originalMove(player, vector, relative)
end, {"dodge", "air_strafe", "slow_walk", "quick_stop", "auto_peek"})

Runtime:Every("players", 1 / 20, function() local cam = camera(); if cam then updatePlayers(cam) end end)
Runtime:Every("hud", 1 / 15, function() local cam = camera(); if cam then applyThirdPerson(); updateHud(cam) end end)
Runtime:Every("shot visuals", 1 / 30, function() local cam = camera(); if cam then updateShotVisuals(cam) end end)
Runtime:Every("world objects", 0.1, function() local cam = camera(); if cam then updateObjects(cam) end end)
Runtime:Every("environment", 0.15, function() applyWorld(); applyEnvironment(); Public.SurfaceVisuals.Update() end)
Runtime:Every("body effects", 1 / 30, Public.UpdateBodyEffects)
Runtime:Every("ragdolls", 0.25, Public.UpdateRagdolls)
Runtime:Every("inventory", 0.2, function()
    applySkin()
    if Public.SkinStudio then Public.SkinStudio.UpdateHud() end
    if Public.SkinStudio then Public.SkinStudio.UpdateCharacterGloves() end
    local cam = camera()
    local weaponModel = cam and getCameraWeapon(cam)
    applyGloves(weaponModel)
    if not LocalPlayer:GetAttribute("IsSpectating") and (Flags.weapon_tint or Flags.glove_tint) then applyInventory() end
end)

RunService:BindToRenderStep("BloxStrikeArvn", Enum.RenderPriority.Camera.Value + 6, function(dt)
    if not Running then return end
    local cam = camera()
    if not cam then return end
    if Public.SkinStudio then Public.SkinStudio.UpdateKnife() end
    Public.UpdateShotAnimation()
    if Flags.rage_aim or Flags.aimbot or Flags.silent_aim then updateMotion(dt) end
    if Flags.force_thirdperson and thirdPersonAvailable() then updateThirdPersonPresentation() end
    FpsAverage = FpsAverage * 0.9 + (1 / math.max(dt, 0.001)) * 0.1
    if Flags.custom_fov then
        local equipped = InventoryController.peekCurrentEquippedForMovement()
        local fov = Flags.camera_fov or 80
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then fov *= 1 - (Flags.zoom_reduction or 0) / 100 end
        if not equipped or not equipped.IsAiming then cam.FieldOfView = fov end
    end
    local rmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    local lmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local legitMode = Flags.legit_activation or "Hold RMB"
    if Flags.aimbot and not Flags.rage_aim and not Arvn:IsOpen() and ((legitMode == "Hold RMB" and rmb) or (legitMode == "On attack" and lmb) or legitMode == "Always") then
        local model, part = target(true, Flags.legit_fov or 30)
        local state = Public.LegitState
        if model ~= state.Model then
            local reset = state.Model ~= nil and (Flags.legit_reset or 0) or 0
            state.Model = model
            state.Since = os.clock()
            state.ReadyAt = os.clock() + ((Flags.legit_reaction or 0) + reset) / 1000
        end
        if part and os.clock() >= state.ReadyAt then
            local mouse = UserInputService:GetMouseDelta().Magnitude
            local assistance = 1 / (1 + mouse * (Flags.mouse_override or 1) * 0.1)
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, (aimPoint(part))), math.clamp(dt * (31 - (Flags.aim_smooth or 8)) * 0.8 * assistance, 0.001, 1))
        end
    else
        Public.LegitState.Model = nil
    end
    local rageModel, ragePart = nil, nil
    if Flags.rage_aim then
        rageModel, ragePart = rageTarget()
        CurrentTarget = rageModel
        if ragePart and not Flags.silent_aim and not Arvn:IsOpen() and (lmb or rmb or Flags.rage_autofire) then
            local goal = CFrame.lookAt(cam.CFrame.Position, (aimPoint(ragePart)))
            local speed = Flags.rage_aim_speed or 100
            cam.CFrame = speed >= 100 and goal or cam.CFrame:Lerp(goal, math.clamp(dt * speed / 30, 0.01, 1))
        end
    else
        RageTargetModel = nil
        CurrentTarget = nil
    end
    if (Flags.rage_autofire or Flags.auto_scope) and Flags.rage_aim and not Arvn:IsOpen() and isrbxactive() then
        local weapon = InventoryController.peekCurrentEquippedForMovement()
        if weapon ~= LastAutoWeapon then LastAutoWeapon = weapon; LastAutoAttempt = 0 end
        AutoFireStats.Status = ragePart and "target ready" or "no eligible target"
        local automaticScope = Flags.auto_scope and not Flags.silent_aim
        if ragePart and weapon and automaticScope and weapon.Properties and weapon.Properties.HasScope and not weapon.IsAiming and type(weapon.scope) == "function" and os.clock() - Public.WeaponProfiles.LastScope >= 0.7 then
            Public.WeaponProfiles.LastScope = os.clock()
            pcall(weapon.scope, weapon, false)
        end
        local scopeReady = not automaticScope or not weapon or not weapon.Properties or not weapon.Properties.HasScope or weapon.IsAiming
        if Flags.rage_autofire and scopeReady and ragePart and weapon and not weapon.IsReloading and (weapon.Rounds or 0) > 0 and type(weapon.shoot) == "function" and os.clock() - LastAutoAttempt >= 1 / 120 then
            LastAutoAttempt = os.clock()
            if true then
                local before = weapon.Rounds
                AutoFireStats.Attempts += 1
                AutomaticShotCameraGuard = true
                local ok, err = pcall(weapon.shoot, weapon, "Primary")
                AutomaticShotCameraGuard = false
                if ok and weapon.Rounds < before then
                    LastTrigger = os.clock()
                    AutoFireStats.Shots += 1
                    AutoFireStats.Status = "shot fired"
                    if Flags.shot_logs then
                        local logs = Public.WeaponProfiles.Logs
                        logs[#logs + 1] = {Time = os.clock(), Text = string.format("%s → %s | %s | fired", weapon.Name or "Weapon", rageModel and rageModel.Name or "Unknown", ragePart.Name)}
                        local activeCount = 0
                        for _, entry in ipairs(logs) do if not entry.ExpireAt then activeCount += 1 end end
                        if activeCount > 5 then
                            for _, entry in ipairs(logs) do
                                if not entry.ExpireAt then entry.ExpireAt = math.min(entry.Time + 8, os.clock() + 0.45); break end
                            end
                        end
                    end
                else
                    AutoFireStats.Status = ok and "weapon not ready" or tostring(err)
                end
            end
        end
    end
    if Flags.triggerbot and not Flags.rage_aim and not Arvn:IsOpen() and isrbxactive() and os.clock() - LastTrigger > (Flags.trigger_delay or 160) / 1000 then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local own = localModel()
        params.FilterDescendantsInstances = own and {own, cam} or {cam}
        local result = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * (Flags.aim_distance or 1000), params)
        if result then
            local model = characterOf(result.Instance)
            if model and isEnemy(model) then mouse1click(); LastTrigger = os.clock() end
        end
    end
    Runtime:Tick(os.clock())
end)

for _, tab in pairs(Public.Navigation) do
    for _, column in ipairs(tab.entry.page or {}) do
        for _, section in ipairs(column) do
            if section.tabs then
                local nested = {}
                for _, page in ipairs(section.tabs) do
                    for _, row in ipairs(page.rows) do nested[row] = true end
                end
                local main = {}
                for _, row in ipairs(section.rows) do
                    if not nested[row] then main[#main + 1] = row end
                end
                if #main > 0 then table.insert(section.tabs, 1, {name = "Main", rows = main}) end
            end
        end
    end
end
for _, flags in pairs(Public.Compatibility.Missing) do
    for _, flag in ipairs(flags) do
        Arvn:SetFlag(flag, false)
        for _, tab in pairs(Public.Navigation) do
            for _, column in ipairs(tab.entry.page or {}) do
                for _, section in ipairs(column) do
                    for _, row in ipairs(section.rows) do if row.id == flag then row.hidden = true end end
                end
            end
        end
    end
end
print("NETANYAHU_CC_READY")

end
