--========================================================--
--  Prison Life Hub | AnTHuB V1.1 (WindUI Edition)
--  UI: WindUI (https://footagesus.github.io/treehub-web/docs/windui)
--  Icons: Solar (https://icones.js.org/collection/solar)
--========================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Prison Life",
    Icon = "solar:shield-user-bold",
    Author = "AnTHuB | V1.1",
    Folder = "AnTHuB_PrisonLife",
    Theme = "Dark",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    SideBarWidth = 180,
})

local function notify(title, content, duration, icon)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
            Icon = icon or "solar:bell-bold",
        })
    end)
end

--========================= Helpers =========================--

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
        notify("Teleport", "Your character is not ready.", 3, "solar:danger-triangle-bold")
        return
    end
    if not cframe then
        notify("Teleport", label .. " was not found in this map.", 4, "solar:danger-triangle-bold")
        return
    end
    pcall(function()
        root.CFrame = cframe + Vector3.new(0, 3, 0)
    end)
    notify("Teleport", "Moved to " .. label .. ".", 2, "solar:map-point-bold")
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

--========================= Arrest (FIXED) =========================--
-- Fixes vs V1.0:
--  1) arrestStepDelay was used BEFORE being declared (nil delay).
--  2) The arrest remote was searched on EVERY arrest (very slow).
--  3) Arrest All teleported back home after each target and waited an
--     extra delay even for players that were not criminals.
--  4) No retry: a single missed remote fire skipped the target forever.

local arrestStepDelay = 0.35
local arrestRemote

local function getArrestRemote()
    if arrestRemote and arrestRemote.Parent then return arrestRemote end
    arrestRemote = findRemote({ "arrest" })
    return arrestRemote
end

-- Fires the arrest remote against a single target (no return teleport).
local function fireArrest(player, remote)
    if not player or player == LocalPlayer then return false end
    local _, targetHumanoid, targetRoot, targetHead = characterParts(player)
    local root = localRoot()
    if not targetRoot or not targetHead or not root or not remote then return false end
    if targetHumanoid and targetHumanoid.Health <= 0 then return false end

    pcall(function()
        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2.5)
    end)
    task.wait(arrestStepDelay)
    return invokeRemote(remote, targetHead)
end

-- Arrest a single player and return to the original position.
local function arrestWithCuffs(player)
    local root = localRoot()
    local remote = getArrestRemote()
    if not root or not remote then return false end

    local oldCFrame = root.CFrame
    equipHandcuffs()
    local ok = fireArrest(player, remote)
    task.wait(arrestStepDelay)
    local currentRoot = localRoot()
    if currentRoot then
        pcall(function() currentRoot.CFrame = oldCFrame end)
    end
    return ok
end

local arrestAllRunning = false

local function arrestAllCriminals()
    if arrestAllRunning then
        notify("Arrest", "Arrest All is already running.", 3, "solar:danger-triangle-bold")
        return
    end
    local root = localRoot()
    local remote = getArrestRemote()
    if not root then
        notify("Arrest", "Your character is not ready.", 3, "solar:danger-triangle-bold")
        return
    end
    if not remote then
        notify("Arrest", "Arrest remote was not found.", 4, "solar:danger-triangle-bold")
        return
    end

    arrestAllRunning = true
    local oldCFrame = root.CFrame
    equipHandcuffs()

    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isCriminal(player) then
            -- Up to 3 attempts per target; stop as soon as they leave the criminal team.
            for _ = 1, 3 do
                if not player.Parent or not isCriminal(player) then break end
                if fireArrest(player, remote) then
                    task.wait(arrestStepDelay)
                    if not isCriminal(player) then
                        count = count + 1
                        break
                    end
                else
                    task.wait(arrestStepDelay)
                end
            end
        end
    end

    local currentRoot = localRoot()
    if currentRoot then
        pcall(function() currentRoot.CFrame = oldCFrame end)
    end
    arrestAllRunning = false
    notify("Arrest", "Criminals arrested: " .. tostring(count) .. ".", 3, "solar:siren-bold")
end

--========================= Tabs =========================--

local playerTab = Window:Tab({ Title = "Players", Icon = "solar:users-group-rounded-bold" })
local teleportTab = Window:Tab({ Title = "Teleports", Icon = "solar:map-point-bold" })
local espTab = Window:Tab({ Title = "ESP", Icon = "solar:eye-bold" })
local movementTab = Window:Tab({ Title = "Movement", Icon = "solar:running-round-bold" })
local infoTab = Window:Tab({ Title = "Info", Icon = "solar:info-circle-bold" })

--========================= Players tab (FIXED) =========================--
-- Fixes vs V1.0:
--  1) The dropdown never updated when players joined/left; it now
--     auto-refreshes on PlayerAdded / PlayerRemoving.
--  2) After a refresh the previous selection was silently lost; it is
--     now re-selected when the player is still in the server.
--  3) The selected target is validated (exists + has a character)
--     before every action.

local selectedPlayerName
local targetDropdown

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

local function selectedPlayer()
    return selectedPlayerName and Players:FindFirstChild(selectedPlayerName) or nil
end

targetDropdown = playerTab:Dropdown({
    Title = "Target",
    Desc = "Select a player to target",
    Values = playerOptions(),
    Value = nil,
    Callback = function(value)
        selectedPlayerName = type(value) == "table" and value[1] or value
    end,
})

local function refreshPlayerDropdown(silent)
    local options = playerOptions()
    task.spawn(function()
        pcall(function()
            targetDropdown:Refresh(options)
            if selectedPlayerName and table.find(options, selectedPlayerName) then
                targetDropdown:Select({ selectedPlayerName })
            else
                selectedPlayerName = nil
            end
        end)
    end)
    if not silent then
        notify("Players", "Player list refreshed.", 2, "solar:refresh-bold")
    end
end

playerTab:Button({
    Title = "Refresh player list",
    Icon = "solar:refresh-bold",
    Callback = function() refreshPlayerDropdown(false) end,
})

playerTab:Space()

playerTab:Button({
    Title = "Fling selected",
    Desc = "Launches the selected player",
    Icon = "solar:black-hole-bold",
    Callback = function()
        local target = selectedPlayer()
        local _, _, targetRoot = characterParts(target)
        local root = localRoot()
        if not target then
            notify("Fling", "Select a player first.", 3, "solar:danger-triangle-bold")
            return
        end
        if not targetRoot or not root then
            notify("Fling", "Target character is not loaded.", 3, "solar:danger-triangle-bold")
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

playerTab:Button({
    Title = "Arrest selected",
    Desc = "Teleports behind the target and arrests",
    Icon = "solar:siren-bold",
    Callback = function()
        local target = selectedPlayer()
        if not target then
            notify("Arrest", "Select a player first.", 3, "solar:danger-triangle-bold")
            return
        end
        task.spawn(function()
            local ok = arrestWithCuffs(target)
            notify("Arrest", ok and "Teleported and arrested." or "Arrest failed.", 3,
                ok and "solar:siren-bold" or "solar:danger-triangle-bold")
        end)
    end,
})

playerTab:Button({
    Title = "Arrest all criminals",
    Desc = "Arrests every criminal on the server",
    Icon = "solar:siren-rounded-bold",
    Callback = function()
        task.spawn(arrestAllCriminals)
    end,
})

--========================= ESP =========================--

local espEnabled = false
local espBox = true
local espHealth = true
local espDistance = true
local espTracer = true
local espTracerEffects = true
local espNames = true
local espTeamCheck = false
local espColor = Color3.fromRGB(255, 90, 90)
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
    stroke.Color = espColor
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

    local name = textLabel(espGui, UDim2.fromOffset(220, 18), espColor)
    name.Visible = false
    local distance = textLabel(espGui, UDim2.fromOffset(180, 18), Color3.fromRGB(215, 215, 215))
    distance.Visible = false

    local tracerGlow = Instance.new("Frame")
    tracerGlow.BackgroundColor3 = espColor
    tracerGlow.BackgroundTransparency = 0.75
    tracerGlow.BorderSizePixel = 0
    tracerGlow.AnchorPoint = Vector2.new(0.5, 0)
    tracerGlow.Visible = false
    tracerGlow.Parent = espGui

    local tracer = Instance.new("Frame")
    tracer.BackgroundColor3 = espColor
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0)
    tracer.Visible = false
    tracer.Parent = espGui

    local entry = {
        box = box,
        stroke = stroke,
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

local function applyESPColor(color)
    espColor = color
    for _, entry in pairs(espObjects) do
        pcall(function()
            entry.stroke.Color = color
            entry.name.TextColor3 = color
            entry.tracer.BackgroundColor3 = color
            entry.tracerGlow.BackgroundColor3 = color
        end)
    end
end

local function hideESP(entry)
    for _, object in pairs(entry) do
        if typeof(object) == "Instance" and object:IsA("GuiObject") then
            object.Visible = false
        end
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
    refreshPlayerDropdown(true)
end)
local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    if selectedPlayerName == player.Name then selectedPlayerName = nil end
    refreshPlayerDropdown(true)
end)
local espConnection = RunService.RenderStepped:Connect(function()
    if not espEnabled then return end
    for player, entry in pairs(espObjects) do
        updateESP(player, entry)
    end
end)

espTab:Toggle({
    Title = "ESP",
    Icon = "solar:eye-bold",
    Value = false,
    Callback = function(value)
        espEnabled = value
        espGui.Enabled = value
        if not value then
            for _, entry in pairs(espObjects) do hideESP(entry) end
        end
    end,
})

espTab:Colorpicker({
    Title = "ESP color",
    Desc = "Box, tracer and name color",
    Default = espColor,
    Callback = applyESPColor,
})

espTab:Space()

espTab:Toggle({ Title = "Box", Icon = "solar:box-bold", Value = true, Callback = function(value) espBox = value end })
espTab:Toggle({ Title = "Health", Icon = "solar:health-bold", Value = true, Callback = function(value) espHealth = value end })
espTab:Toggle({ Title = "Distance", Icon = "solar:ruler-bold", Value = true, Callback = function(value) espDistance = value end })
espTab:Toggle({ Title = "Tracer", Icon = "solar:routing-bold", Value = true, Callback = function(value) espTracer = value end })
espTab:Toggle({ Title = "Tracer effects", Icon = "solar:stars-bold", Value = true, Callback = function(value) espTracerEffects = value end })
espTab:Toggle({ Title = "Names", Icon = "solar:tag-bold", Value = true, Callback = function(value) espNames = value end })
espTab:Toggle({ Title = "Team check", Icon = "solar:users-group-two-rounded-bold", Value = false, Callback = function(value) espTeamCheck = value end })

--========================= Movement =========================--

local speedEnabled = false
local jumpEnabled = false
local speedValue = 16
local jumpValue = 50
local noclipEnabled = false
local noclipOriginalCollisions = {}
local movementConnection

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

movementTab:Toggle({
    Title = "Enable WalkSpeed",
    Icon = "solar:running-bold",
    Value = false,
    Callback = function(value)
        speedEnabled = value
        applyMovement()
    end,
})

movementTab:Slider({
    Title = "WalkSpeed",
    Step = 1,
    Value = { Min = 16, Max = 250, Default = 16 },
    Callback = function(value)
        speedValue = value
        applyMovement()
    end,
})

movementTab:Space()

movementTab:Toggle({
    Title = "Enable JumpPower",
    Icon = "solar:double-alt-arrow-up-bold",
    Value = false,
    Callback = function(value)
        jumpEnabled = value
        applyMovement()
    end,
})

movementTab:Slider({
    Title = "JumpPower",
    Step = 5,
    Value = { Min = 50, Max = 200, Default = 50 },
    Callback = function(value)
        jumpValue = value
        applyMovement()
    end,
})

movementTab:Space()

movementTab:Toggle({
    Title = "NoClip",
    Icon = "solar:ghost-bold",
    Value = false,
    Callback = function(value)
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
    end,
})

--========================= Teleports =========================--

local locations = {
    { "Cafeteria", { "cafeteria", "cafe" }, "solar:cup-hot-bold" },
    { "Criminal base", { "criminal base", "criminalbase", "criminal" }, "solar:home-angle-bold" },
    { "Outside prison", { "outside", "yard", "escape" }, "solar:sun-bold" },
    { "Inside prison", { "inside prison", "prison interior", "prison" }, "solar:lock-keyhole-bold" },
    { "Police armory", { "armory", "gunroom", "gun room", "weapons" }, "solar:shield-bold" },
}
for _, location in ipairs(locations) do
    teleportTab:Button({
        Title = location[1],
        Icon = location[3],
        Callback = function()
            teleportToNamed(location[1], location[2])
        end,
    })
end

teleportTab:Button({
    Title = "Criminal cars",
    Icon = "solar:wheel-bold",
    Callback = teleportToCriminalCar,
})

teleportTab:Space()

teleportTab:Button({
    Title = "Get police card",
    Icon = "solar:card-bold",
    Callback = function()
        local remote = findRemote({ "itemhandler", "policecard", "keycard", "card" })
        if not remote then
            notify("Police card", "Item remote was not found.", 4, "solar:danger-triangle-bold")
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
        notify("Police card", "Request sent.", 3, "solar:card-bold")
    end,
})

--========================= Anti-AFK =========================--

local antiAfkConnection = LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

--========================= Info =========================--

infoTab:Dropdown({
    Title = "Theme",
    Icon = "solar:pallete-2-bold",
    Values = { "Dark", "Light" },
    Value = "Dark",
    Callback = function(theme)
        local selectedTheme = type(theme) == "table" and theme[1] or theme
        pcall(function() WindUI:SetTheme(selectedTheme) end)
    end,
})

infoTab:Space()

infoTab:Button({
    Title = "Prison Life V1.1",
    Icon = "solar:star-bold",
    Callback = function() notify("Version", "Prison Life V1.1 (WindUI)", 3, "solar:star-bold") end,
})
infoTab:Button({
    Title = "Next update: V1.2",
    Icon = "solar:rocket-bold",
    Callback = function() notify("Next update", "More locations and improvements.", 4, "solar:rocket-bold") end,
})
infoTab:Button({
    Title = "Made by akiev / yoaredevs",
    Icon = "solar:user-bold",
    Callback = function() notify("Creator", "Roblox user: 6r0lw", 4, "solar:user-bold") end,
})

infoTab:Space()

infoTab:Button({
    Title = "Unload hub",
    Icon = "solar:logout-2-bold",
    Callback = function()
        espEnabled = false
        espGui.Enabled = false
        if espConnection then espConnection:Disconnect() end
        if playerAddedConnection then playerAddedConnection:Disconnect() end
        if playerRemovingConnection then playerRemovingConnection:Disconnect() end
        if movementConnection then movementConnection:Disconnect() end
        if antiAfkConnection then antiAfkConnection:Disconnect() end
        for object, canCollide in pairs(noclipOriginalCollisions) do
            if object and object.Parent then
                pcall(function() object.CanCollide = canCollide end)
            end
        end
        noclipOriginalCollisions = {}
        for player in pairs(espObjects) do removeESP(player) end
        pcall(function() espGui:Destroy() end)
        pcall(function() Window:Destroy() end)
    end,
})

notify("Prison Life", "Ready. Press RightShift to toggle the UI.", 3, "solar:shield-user-bold")
