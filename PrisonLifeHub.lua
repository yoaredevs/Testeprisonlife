local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
local Window = Rayfield:CreateWindow({
    name = "Prison Life",
    subtitle = "AnTHuB | V1.0",
    theme = "frost",
    icon = 93364949241311,
})

local function notify(title, content, duration, icon)
    pcall(function()
        Window:Notify({
            title = title,
            content = content,
            duration = duration or 3,
            icon = icon or 125626312718314,
        })
    end)
end

local function getParent()
    if gethui then
        local ok, gui = pcall(gethui)
        if ok and gui then return gui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function characterParts(player)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")
    return character, humanoid, root, head
end

local function localRoot()
    local _, _, root = characterParts(LocalPlayer)
    return root
end

local function cleanName(value)
    return string.lower(tostring(value or ""))
end

local function findNamedPart(terms)
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("BasePart") or object:IsA("Model") then
            local name = cleanName(object.Name)
            for _, term in ipairs(terms) do
                if name:find(cleanName(term), 1, true) then
                    if object:IsA("BasePart") then return object end
                    return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
                end
            end
        end
    end
    return nil
end

local function findRemote(terms)
    local roots = { Workspace, ReplicatedStorage }
    for _, root in ipairs(roots) do
        for _, object in ipairs(root:GetDescendants()) do
            if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
                local name = cleanName(object.Name)
                for _, term in ipairs(terms) do
                    if name:find(cleanName(term), 1, true) then
                        return object
                    end
                end
            end
        end
    end
    return nil
end

local function invokeRemote(remote, ...)
    if not remote then return false end
    local args = { ... }
    local ok = pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args))
        else
            remote:FireServer(table.unpack(args))
        end
    end)
    return ok
end

local function teleportTo(cframe, label)
    local root = localRoot()
    if not root then
        notify("Teleport", "Your character is not ready.", 3, 91452555903853)
        return
    end
    if not cframe then
        notify("Teleport", label .. " was not found in this map.", 4, 91452555903853)
        return
    end
    pcall(function()
        root.CFrame = cframe + Vector3.new(0, 3, 0)
    end)
    notify("Teleport", "Moved to " .. label .. ".", 2, 125626312718314)
end

local function teleportToNamed(label, terms)
    local part = findNamedPart(terms)
    teleportTo(part and part.CFrame or nil, label)
end

local function teleportToCriminalCar()
    local chosen
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("VehicleSeat") or object:IsA("Seat") then
            local path = cleanName(object:GetFullName())
            if path:find("car", 1, true) or path:find("vehicle", 1, true)
                or path:find("van", 1, true) then
                chosen = object
                break
            end
        end
    end
    if not chosen then
        for _, object in ipairs(Workspace:GetDescendants()) do
            if object:IsA("VehicleSeat") then
                chosen = object
                break
            end
        end
    end
    teleportTo(chosen and chosen.CFrame or nil, "a criminal car")
end

local function isCriminal(player)
    local teamName = cleanName(player and player.Team and player.Team.Name)
    return teamName:find("criminal", 1, true) ~= nil
end

local function equipHandcuffs()
    local character, humanoid = characterParts(LocalPlayer)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local tool
    for _, container in ipairs({ character, backpack }) do
        if container then
            for _, object in ipairs(container:GetChildren()) do
                if object:IsA("Tool") and cleanName(object.Name):find("handcuff", 1, true) then
                    tool = object
                    break
                end
            end
        end
        if tool then break end
    end
    if tool and humanoid and tool.Parent ~= character then
        pcall(function() humanoid:EquipTool(tool) end)
    end
    return tool
end

local function arrestWithCuffs(player)
    if not player or player == LocalPlayer then return false end
    local _, _, targetRoot, targetHead = characterParts(player)
    local root = localRoot()
    local remote = findRemote({ "arrest" })
    if not targetRoot or not targetHead or not root or not remote then return false end

    local oldCFrame = root.CFrame
    equipHandcuffs()
    pcall(function()
        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2.5)
    end)
    task.wait(arrestStepDelay)
    local ok = invokeRemote(remote, targetHead)
    task.wait(arrestStepDelay)
    pcall(function() root.CFrame = oldCFrame end)
    return ok
end

local selectedPlayerName
local arrestStepDelay = 0.8
local weaponTracerEnabled = false
local weaponTracerEffects = false
local weaponTracerColor = Color3.fromRGB(255, 180, 70)
local shootEvent
local markShotTarget

local function playerOptions()
    local options = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(options, player.Name)
        end
    end
    table.sort(options)
    return options
end

local playerTab = Window:CreateTab({ name = "Players", icon = 111263549366178 })
local teleportTab = Window:CreateTab({ name = "Teleports", icon = 80387863064905 })
local espTab = Window:CreateTab({ name = "ESP", icon = 100604009889706 })
local movementTab = Window:CreateTab({ name = "Movement", icon = 125626312718314 })
local infoTab = Window:CreateTab({ name = "Info", icon = 129180860773723 })
local effectsTab = Window:CreateTab({ name = "Effects", icon = 91452555903853 })

infoTab:CreateDropdown({
    name = "Theme",
    options = { "default", "cobalt", "ember", "amethyst", "frost", "rose" },
    value = "frost",
    callback = function(theme)
        local selectedTheme = type(theme) == "table" and theme[1] or theme
        pcall(function() Window:ChangeTheme(selectedTheme) end)
    end,
})

local targetDropdown = playerTab:CreateDropdown({
    name = "Target",
    options = playerOptions(),
    value = nil,
    callback = function(value)
        selectedPlayerName = type(value) == "table" and value[1] or value
    end,
})

local function refreshPlayers()
    local options = playerOptions()
    pcall(function() targetDropdown:Refresh(options, false) end)
    if selectedPlayerName and not Players:FindFirstChild(selectedPlayerName) then
        selectedPlayerName = nil
    end
    notify("Players", "Player list refreshed.", 2, 100604009889706)
end

local function selectedPlayer()
    return selectedPlayerName and Players:FindFirstChild(selectedPlayerName) or nil
end

local function drawShotTracer(fromPosition, toPosition)
    if not weaponTracerEnabled then return end
    local beamPart = Instance.new("Part")
    beamPart.Name = "PrisonLifeLocalShotTracer"
    beamPart.Anchored = true
    beamPart.CanCollide = false
    beamPart.CanTouch = false
    beamPart.CanQuery = false
    beamPart.Material = weaponTracerEffects and Enum.Material.Neon or Enum.Material.SmoothPlastic
    beamPart.Color = weaponTracerColor
    local distance = (toPosition - fromPosition).Magnitude
    beamPart.Size = Vector3.new(weaponTracerEffects and 0.16 or 0.06, weaponTracerEffects and 0.16 or 0.06, distance)
    beamPart.CFrame = CFrame.lookAt((fromPosition + toPosition) * 0.5, toPosition)
    beamPart.Parent = Workspace
    task.delay(0.14, function()
        if beamPart and beamPart.Parent then beamPart:Destroy() end
    end)
end

local function shootSelectedPlayer()
    local target = selectedPlayer()
    local _, _, targetRoot = characterParts(target)
    local root = localRoot()
    if not shootEvent or not targetRoot or not root then
        notify("Shoot", "ShootEvent or target was not found.", 3, 91452555903853)
        return
    end
    local floor = Workspace:FindFirstChild("floor") or Workspace:FindFirstChild("Floor")
    markShotTarget(target)
    local args = {
        {
            {
                root.Position,
                targetRoot.Position,
                floor,
            },
        },
    }
    local ok = pcall(function() shootEvent:FireServer(unpack(args)) end)
    drawShotTracer(root.Position, targetRoot.Position)
    notify("Shoot", ok and "Shot sent." or "Shot failed.", 2,
        ok and 125626312718314 or 91452555903853)
end

playerTab:CreateButton({
    name = "Refresh player list",
    icon = 100604009889706,
    callback = refreshPlayers,
})

playerTab:CreateButton({
    name = "Shoot selected",
    icon = 125626312718314,
    callback = shootSelectedPlayer,
})

playerTab:CreateButton({
    name = "Fling selected",
    icon = 129180860773723,
    callback = function()
        local target = selectedPlayer()
        local _, _, targetRoot = characterParts(target)
        local root = localRoot()
        if not targetRoot or not root then
            notify("Fling", "Select a player with a loaded character.", 3, 91452555903853)
            return
        end
        local oldLinear = root.AssemblyLinearVelocity
        local oldAngular = root.AssemblyAngularVelocity
        local direction = targetRoot.Position - root.Position
        if direction.Magnitude < 0.1 then direction = targetRoot.CFrame.LookVector end
        direction = direction.Unit
        pcall(function()
            root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2)
            root.AssemblyAngularVelocity = Vector3.new(0, 140, 0)
            root.AssemblyLinearVelocity = direction * 140 + Vector3.new(0, 45, 0)
        end)
        task.delay(0.22, function()
            local currentRoot = localRoot()
            if currentRoot then
                pcall(function()
                    currentRoot.AssemblyAngularVelocity = oldAngular
                    currentRoot.AssemblyLinearVelocity = oldLinear
                end)
            end
        end)
    end,
})

playerTab:CreateButton({
    name = "Arrest selected",
    icon = 125626312718314,
    callback = function()
        local target = selectedPlayer()
        if not target then
            notify("Arrest", "Select a player first.", 3, 91452555903853)
            return
        end
        local ok = arrestWithCuffs(target)
        notify("Arrest", ok and "Teleported and arrested." or "Arrest failed.", 3,
            ok and 125626312718314 or 91452555903853)
    end,
})

playerTab:CreateButton({
    name = "Arrest all criminals",
    icon = 125626312718314,
    callback = function()
        local count = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if isCriminal(player) and arrestWithCuffs(player) then
                count = count + 1
            end
            task.wait(arrestStepDelay)
        end
        notify("Arrest", "Criminals arrested: " .. tostring(count) .. ".", 3, 125626312718314)
    end,
})

local espEnabled = false
local espBox = true
local espHealth = true
local espDistance = true
local espTracer = true
local espTracerEffects = true
local espNames = true
local espTeamCheck = false
local espObjects = {}
local espGui = Instance.new("ScreenGui")
espGui.Name = "PrisonLifeESP"
espGui.IgnoreGuiInset = true
espGui.ResetOnSpawn = false
espGui.Enabled = false
espGui.Parent = getParent()

local function textLabel(parent, size, color, align)
    local label = Instance.new("TextLabel")
    label.Size = size
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.5
    label.TextXAlignment = align or Enum.TextXAlignment.Center
    label.Parent = parent
    return label
end

local function createESP(player)
    if espObjects[player] then return espObjects[player] end
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = espGui
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 90, 90)
    stroke.Thickness = 1
    stroke.Parent = box

    local healthBack = Instance.new("Frame")
    healthBack.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    healthBack.BorderSizePixel = 0
    healthBack.Visible = false
    healthBack.Parent = espGui
    local healthFill = Instance.new("Frame")
    healthFill.BackgroundColor3 = Color3.fromRGB(70, 220, 100)
    healthFill.BorderSizePixel = 0
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.Position = UDim2.new(0, 0, 1, 0)
    healthFill.Parent = healthBack

    local name = textLabel(espGui, UDim2.fromOffset(220, 18), Color3.fromRGB(255, 255, 255))
    name.Visible = false
    local distance = textLabel(espGui, UDim2.fromOffset(180, 18), Color3.fromRGB(215, 215, 215))
    distance.Visible = false

    local tracerGlow = Instance.new("Frame")
    tracerGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tracerGlow.BackgroundTransparency = 0.75
    tracerGlow.BorderSizePixel = 0
    tracerGlow.AnchorPoint = Vector2.new(0.5, 0)
    tracerGlow.Visible = false
    tracerGlow.Parent = espGui

    local tracer = Instance.new("Frame")
    tracer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0)
    tracer.Visible = false
    tracer.Parent = espGui

    local entry = {
        box = box,
        healthBack = healthBack,
        healthFill = healthFill,
        name = name,
        distance = distance,
        tracer = tracer,
        tracerGlow = tracerGlow,
    }
    espObjects[player] = entry
    return entry
end

local function hideESP(entry)
    for _, object in pairs(entry) do
        if typeof(object) == "Instance" then object.Visible = false end
    end
end

local function removeESP(player)
    local entry = espObjects[player]
    if not entry then return end
    for _, object in pairs(entry) do
        if typeof(object) == "Instance" then object:Destroy() end
    end
    espObjects[player] = nil
end

local function getBox2D(character)
    local cf, size = character:GetBoundingBox()
    local half = size * 0.5
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local point = cf * Vector3.new(half.X * x, half.Y * y, half.Z * z)
                local screen, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(point)
                if screen.Z > 0 then
                    visible = visible or onScreen
                    minX = math.min(minX, screen.X)
                    minY = math.min(minY, screen.Y)
                    maxX = math.max(maxX, screen.X)
                    maxY = math.max(maxY, screen.Y)
                end
            end
        end
    end
    if not visible or minX == math.huge then return nil end

    local height = maxY - minY
    if height <= 0 then return nil end
    local centerX = (minX + maxX) * 0.5
    local rectangularWidth = math.max(height * 0.45, 6)
    minX = centerX - rectangularWidth * 0.5
    return minX, minY, rectangularWidth, height
end

local function updateESP(player, entry)
    local character, humanoid, root = characterParts(player)
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        hideESP(entry)
        return
    end
    if espTeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        hideESP(entry)
        return
    end
    local x, y, width, height = getBox2D(character)
    if not x then
        hideESP(entry)
        return
    end
    local camera = Workspace.CurrentCamera
    local viewport = camera.ViewportSize
    local centerX = x + width * 0.5
    local bottomY = y + height
    local distance = math.floor((root.Position - camera.CFrame.Position).Magnitude)
    local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)

    entry.box.Position = UDim2.fromOffset(x, y)
    entry.box.Size = UDim2.fromOffset(width, height)
    entry.box.Visible = espEnabled and espBox

    entry.healthBack.Position = UDim2.fromOffset(x - 6, y)
    entry.healthBack.Size = UDim2.fromOffset(3, height)
    entry.healthBack.Visible = espEnabled and espHealth
    entry.healthFill.Size = UDim2.new(1, 0, ratio, 0)
    entry.healthFill.BackgroundColor3 = Color3.fromRGB(255 - math.floor(185 * ratio), 70 + math.floor(160 * ratio), 75)

    entry.name.Position = UDim2.fromOffset(centerX - 110, y - 20)
    entry.name.Text = player.DisplayName
    entry.name.Visible = espEnabled and espNames

    entry.distance.Position = UDim2.fromOffset(centerX - 90, bottomY + 2)
    entry.distance.Text = tostring(distance) .. " studs"
    entry.distance.Visible = espEnabled and espDistance

    local startX, startY = viewport.X * 0.5, viewport.Y
    local deltaX, deltaY = centerX - startX, bottomY - startY
    local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    local tracerRotation = math.deg(math.atan2(deltaY, deltaX)) + 90
    entry.tracer.Position = UDim2.fromOffset(startX, startY)
    entry.tracer.Size = UDim2.fromOffset(2, length)
    entry.tracer.Rotation = tracerRotation
    entry.tracer.Visible = espEnabled and espTracer
    entry.tracerGlow.Position = UDim2.fromOffset(startX, startY)
    entry.tracerGlow.Size = UDim2.fromOffset(espTracerEffects and 6 or 2, length)
    entry.tracerGlow.Rotation = tracerRotation
    entry.tracerGlow.Visible = espEnabled and espTracer and espTracerEffects
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then createESP(player) end
end

local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
    createESP(player)
end)
local playerRemovingConnection = Players.PlayerRemoving:Connect(removeESP)
local espConnection = RunService.RenderStepped:Connect(function()
    if not espEnabled then return end
    for player, entry in pairs(espObjects) do
        updateESP(player, entry)
    end
end)

espTab:CreateToggle({ name = "ESP", value = false, callback = function(value)
    espEnabled = value
    espGui.Enabled = value
    if not value then
        for _, entry in pairs(espObjects) do hideESP(entry) end
    end
end })
espTab:CreateToggle({ name = "Box", value = true, callback = function(value) espBox = value end })
espTab:CreateToggle({ name = "Health", value = true, callback = function(value) espHealth = value end })
espTab:CreateToggle({ name = "Distance", value = true, callback = function(value) espDistance = value end })
espTab:CreateToggle({ name = "Tracer", value = true, callback = function(value) espTracer = value end })
espTab:CreateToggle({ name = "Tracer effects", value = true, callback = function(value) espTracerEffects = value end })
espTab:CreateToggle({ name = "Names", value = true, callback = function(value) espNames = value end })
espTab:CreateToggle({ name = "Team check", value = false, callback = function(value) espTeamCheck = value end })

weaponTracerEnabled = false
weaponTracerEffects = false
weaponTracerColor = Color3.fromRGB(255, 180, 70)
local gunSoundEnabled = false
local gunSoundPresets = {
    ["Gun Shot"] = "rbxassetid://2811598570",
    ["Shooting Sound Effect"] = "rbxassetid://2934844996",
}
local gunSoundId = gunSoundPresets["Gun Shot"]
local killSoundEnabled = false
local killSoundPresets = {
    ["Kill Sound"] = "rbxassetid://8864069181",
}
local killSoundId = killSoundPresets["Kill Sound"]
local originalCombatVisuals = {}
local combatVisualConnection
local combatSoundConnection
local deathConnections = {}
local pendingKillTargets = {}
local gunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
shootEvent = gunRemotes and gunRemotes:FindFirstChild("ShootEvent")

local function isCombatVisual(object)
    if not (object:IsA("Beam") or object:IsA("Trail") or object:IsA("ParticleEmitter")
        or object:IsA("BasePart")) then
        return false
    end
    local name = cleanName(object.Name)
    return name:find("bullet", 1, true) or name:find("tracer", 1, true)
        or name:find("laser", 1, true) or name:find("muzzle", 1, true)
        or name:find("shot", 1, true)
end

local function applyCombatVisual(object)
    if not isCombatVisual(object) then return end
    if not originalCombatVisuals[object] then
        originalCombatVisuals[object] = {
            color = object.Color,
            brightness = object:IsA("Beam") and object.Brightness or nil,
            lifetime = object:IsA("Trail") and object.Lifetime or nil,
            material = object:IsA("BasePart") and object.Material or nil,
        }
    end
    if weaponTracerEnabled then
        pcall(function() object.Color = ColorSequence.new(weaponTracerColor) end)
        if object:IsA("Beam") then
            pcall(function() object.Brightness = weaponTracerEffects and 8 or 1 end)
        elseif object:IsA("Trail") then
            pcall(function() object.Lifetime = weaponTracerEffects and 1 or originalCombatVisuals[object].lifetime end)
        elseif object:IsA("BasePart") then
            pcall(function() object.Material = weaponTracerEffects and Enum.Material.Neon or originalCombatVisuals[object].material end)
        end
    end
end

local function restoreCombatVisuals()
    for object, original in pairs(originalCombatVisuals) do
        if object and object.Parent then
            pcall(function() object.Color = original.color end)
            if object:IsA("Beam") and original.brightness then
                pcall(function() object.Brightness = original.brightness end)
            elseif object:IsA("Trail") and original.lifetime then
                pcall(function() object.Lifetime = original.lifetime end)
            elseif object:IsA("BasePart") and original.material then
                pcall(function() object.Material = original.material end)
            end
        end
    end
end

local function isGunSound(object)
    if not object:IsA("Sound") then return false end
    local name = cleanName(object.Name)
    return name:find("shot", 1, true) or name:find("gun", 1, true)
        or name:find("fire", 1, true) or name:find("bullet", 1, true)
end

local function playEffectSound(soundId)
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 1
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
        task.delay(6, function()
            if sound and sound.Parent then sound:Destroy() end
        end)
    end)
end

markShotTarget = function(player)
    if player and player ~= LocalPlayer then
        pendingKillTargets[player] = os.clock() + 6
    end
end

local function bindTargetDeath(player)
    local function bindCharacter(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        if humanoid then
            local connection = humanoid.Died:Connect(function()
                local expiresAt = pendingKillTargets[player]
                if killSoundEnabled and expiresAt and expiresAt >= os.clock() then
                    pendingKillTargets[player] = nil
                    playEffectSound(killSoundId)
                else
                    pendingKillTargets[player] = nil
                end
            end)
            table.insert(deathConnections, connection)
        end
    end
    if player.Character then bindCharacter(player.Character) end
    local connection = player.CharacterAdded:Connect(bindCharacter)
    table.insert(deathConnections, connection)
end

for _, player in ipairs(Players:GetPlayers()) do
    bindTargetDeath(player)
end
local deathPlayerConnection = Players.PlayerAdded:Connect(bindTargetDeath)
combatVisualConnection = Workspace.DescendantAdded:Connect(function(object)
    if weaponTracerEnabled then applyCombatVisual(object) end
    if gunSoundEnabled and isGunSound(object) then
        pcall(function() object.SoundId = gunSoundId end)
    end
end)
combatSoundConnection = Workspace.DescendantAdded:Connect(function(object)
    if gunSoundEnabled and isGunSound(object) then
        pcall(function() object.SoundId = gunSoundId end)
    end
end)

 effectsTab:CreateToggle({ name = "Weapon tracer override", value = false, callback = function(value)
    weaponTracerEnabled = value
    if value then
        for _, object in ipairs(Workspace:GetDescendants()) do applyCombatVisual(object) end
    else
        restoreCombatVisuals()
    end
end })
effectsTab:CreateColorPicker({ name = "Weapon tracer color", color = weaponTracerColor, callback = function(color)
    weaponTracerColor = color
    if weaponTracerEnabled then
        for _, object in ipairs(Workspace:GetDescendants()) do applyCombatVisual(object) end
    end
end })
effectsTab:CreateToggle({ name = "Tracer glow", value = false, callback = function(value)
    weaponTracerEffects = value
    if weaponTracerEnabled then
        for _, object in ipairs(Workspace:GetDescendants()) do applyCombatVisual(object) end
    end
end })
effectsTab:CreateDropdown({ name = "Gun sound preset", options = { "Gun Shot", "Shooting Sound Effect" }, value = "Gun Shot", callback = function(value)
    local selected = type(value) == "table" and value[1] or value
    gunSoundId = gunSoundPresets[selected] or gunSoundId
    if gunSoundEnabled then
        for _, object in ipairs(Workspace:GetDescendants()) do
            if isGunSound(object) then pcall(function() object.SoundId = gunSoundId end) end
        end
    end
end })
effectsTab:CreateToggle({ name = "Gun sound override", value = false, callback = function(value)
    gunSoundEnabled = value
    if value then
        for _, object in ipairs(Workspace:GetDescendants()) do
            if isGunSound(object) then pcall(function() object.SoundId = gunSoundId end) end
        end
    end
end })
effectsTab:CreateInput({ name = "Custom gun sound ID", value = gunSoundId, placeholder = "rbxassetid://...", callback = function(value)
    gunSoundId = tostring(value)
    if gunSoundEnabled then
        for _, object in ipairs(Workspace:GetDescendants()) do
            if isGunSound(object) then pcall(function() object.SoundId = gunSoundId end) end
        end
    end
end })
effectsTab:CreateDropdown({ name = "Kill sound preset", options = { "Kill Sound" }, value = "Kill Sound", callback = function(value)
    local selected = type(value) == "table" and value[1] or value
    killSoundId = killSoundPresets[selected] or killSoundId
end })
effectsTab:CreateToggle({ name = "Kill sound for own shots", value = false, callback = function(value)
    killSoundEnabled = value
end })
effectsTab:CreateInput({ name = "Custom kill sound ID", value = killSoundId, placeholder = "rbxassetid://...", callback = function(value)
    killSoundId = tostring(value)
end })

effectsTab:CreateButton({ name = "Test kill sound", icon = 125626312718314, callback = function()
    playEffectSound(killSoundId)
end })

effectsTab:CreateButton({ name = "Restore combat visuals", icon = 91452555903853, callback = function()
    weaponTracerEnabled = false
    restoreCombatVisuals()
    notify("Effects", "Combat visuals restored.", 3, 91452555903853)
end })

local speedEnabled = false
local jumpEnabled = false
local speedValue = 16
local jumpValue = 50
local noclipEnabled = false
local noclipOriginalCollisions = {}
local movementConnection
local noclipConnection

local function applyMovement()
    local _, humanoid = characterParts(LocalPlayer)
    if not humanoid then return end
    pcall(function()
        humanoid.WalkSpeed = speedEnabled and speedValue or 16
        humanoid.UseJumpPower = true
        humanoid.JumpPower = jumpEnabled and jumpValue or 50
    end)
end

movementConnection = RunService.Heartbeat:Connect(function()
    if speedEnabled or jumpEnabled then applyMovement() end
    if noclipEnabled then
        local character = LocalPlayer.Character
        if character then
            for _, object in ipairs(character:GetDescendants()) do
                if object:IsA("BasePart") then
                    if noclipOriginalCollisions[object] == nil then
                        noclipOriginalCollisions[object] = object.CanCollide
                    end
                    object.CanCollide = false
                end
            end
        end
    end
end)

movementTab:CreateSlider({ name = "WalkSpeed", range = { 16, 250 }, increment = 1, value = 16, suffix = "", callback = function(value)
    speedValue = value
    applyMovement()
end })
movementTab:CreateToggle({ name = "Enable WalkSpeed", value = false, callback = function(value)
    speedEnabled = value
    applyMovement()
end })
movementTab:CreateSlider({ name = "JumpPower", range = { 50, 200 }, increment = 5, value = 50, suffix = "", callback = function(value)
    jumpValue = value
    applyMovement()
end })
movementTab:CreateToggle({ name = "Enable JumpPower", value = false, callback = function(value)
    jumpEnabled = value
    applyMovement()
end })
movementTab:CreateToggle({ name = "NoClip", value = false, callback = function(value)
    noclipEnabled = value
    if value then
        noclipOriginalCollisions = {}
    else
        for object, canCollide in pairs(noclipOriginalCollisions) do
            if object and object.Parent then
                pcall(function() object.CanCollide = canCollide end)
            end
        end
        noclipOriginalCollisions = {}
    end
end })

local locations = {
    { "Cafeteria", { "cafeteria", "cafe" } },
    { "Criminal base", { "criminal base", "criminalbase", "criminal" } },
    { "Outside prison", { "outside", "yard", "escape" } },
    { "Inside prison", { "inside prison", "prison interior", "prison" } },
    { "Police armory", { "armory", "gunroom", "gun room", "weapons" } },
}
for _, location in ipairs(locations) do
    teleportTab:CreateButton({
        name = location[1],
        icon = 80387863064905,
        callback = function()
            teleportToNamed(location[1], location[2])
        end,
    })
end
teleportTab:CreateButton({
    name = "Criminal cars",
    icon = 80387863064905,
    callback = teleportToCriminalCar,
})

teleportTab:CreateButton({
    name = "Get police card",
    icon = 125626312718314,
    callback = function()
        local remote = findRemote({ "itemhandler", "policecard", "keycard", "card" })
        if not remote then
            notify("Police card", "Item remote was not found.", 4, 91452555903853)
            return
        end
        local requests = {
            { "request", "PoliceCard" },
            { "request", "KeyCard" },
            { "request", "Key card" },
            { "request", "Police ID" },
        }
        for _, requestArgs in ipairs(requests) do
            invokeRemote(remote, table.unpack(requestArgs))
            task.wait(0.08)
        end
        notify("Police card", "Request sent.", 3, 125626312718314)
    end,
})

local antiAfkConnection = LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

local creatorUserId = 0
pcall(function() creatorUserId = Players:GetUserIdFromNameAsync("6r0lw") end)
local creatorAvatar = 125626312718314
if creatorUserId > 0 then
    creatorAvatar = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(creatorUserId) .. "&w=150&h=150"
end

infoTab:CreateButton({
    name = "Prison Life V1.0",
    icon = 93364949241311,
    callback = function() notify("Version", "Prison Life V1.0", 3, 93364949241311) end,
})
infoTab:CreateButton({
    name = "Next update: V1.1",
    icon = 100604009889706,
    callback = function() notify("Next update", "More locations and improvements.", 4, 100604009889706) end,
})
infoTab:CreateButton({
    name = "Made by akiev / yoaredevs",
    icon = creatorAvatar,
    callback = function() notify("Creator", "Roblox user: 6r0lw", 4, creatorAvatar) end,
})
infoTab:CreateButton({
    name = "Unload hub",
    icon = 91452555903853,
    callback = function()
        espEnabled = false
        espGui.Enabled = false
        if espConnection then espConnection:Disconnect() end
        if playerAddedConnection then playerAddedConnection:Disconnect() end
        if playerRemovingConnection then playerRemovingConnection:Disconnect() end
        if movementConnection then movementConnection:Disconnect() end
        if antiAfkConnection then antiAfkConnection:Disconnect() end
        if combatVisualConnection then combatVisualConnection:Disconnect() end
        if combatSoundConnection then combatSoundConnection:Disconnect() end
        if deathPlayerConnection then deathPlayerConnection:Disconnect() end
        for object, canCollide in pairs(noclipOriginalCollisions) do
            if object and object.Parent then
                pcall(function() object.CanCollide = canCollide end)
            end
        end
        noclipOriginalCollisions = {}
        for _, connection in ipairs(deathConnections) do
            pcall(function() connection:Disconnect() end)
        end
        for player in pairs(espObjects) do removeESP(player) end
        pcall(function() Window:Unload() end)
    end,
})

notify("Prison Life", "Ready.", 3, 125626312718314)
