--[[
KAIZEN SHADOW V3
Mobile client UI for a Roblox experience you own or are authorized to test.

Features:
- Camera-direction flight and flight speed controls
- Walk speed and jump power controls
- Discord link copy (when executor exposes setclipboard)
- Draggable black/red Arabic UI
- External Wall Hop loader button and client-side Anti-Slap controls; player ESP
- Hide/show panel controls and confirmed permanent shutdown

Important:
Client-side movement may be overridden by the game server.
This is a test build, not a guarantee of compatibility with every executor.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    Discord = "https://discord.gg/ADMjh44ug",
    WalkSpeed = 16,
    JumpPower = 50,
    FlySpeed = 55,
    MinWalkSpeed = 5,
    MaxWalkSpeed = 100,
    MinJumpPower = 10,
    MaxJumpPower = 250,
    MinFlySpeed = 10,
    MaxFlySpeed = 250,
    DiscordToastSeconds = 8,
    WallHopInterval = 0.26,
    WallHopDistance = 3.6,
    WallHopUpVelocity = 43,
    WallHopPushVelocity = 22,
    AntiSlapDeltaThreshold = 38,
}

local walkSpeed = CONFIG.WalkSpeed
local jumpPower = CONFIG.JumpPower
local flySpeed = CONFIG.FlySpeed
local HttpService = game:GetService("HttpService")
local SETTINGS_FILE = "KAIZEN_SHADOW_V3_SETTINGS.json"
local function saveSettings()
    if type(writefile) ~= "function" then
        return false, "unsupported"
    end

    local payload
    local encodedOk, encoded = pcall(function()
        return HttpService:JSONEncode({
            WalkSpeed = walkSpeed,
            JumpPower = jumpPower,
            FlySpeed = flySpeed,
        })
    end)
    if not encodedOk then
        return false, "encode"
    end
    payload = encoded

    local writeOk = pcall(function()
        writefile(SETTINGS_FILE, payload)
    end)
    if not writeOk then
        return false, "write"
    end

    -- Verify the saved data when this executor exposes readfile.
    if type(readfile) == "function" then
        local verifyOk, savedText = pcall(function()
            return readfile(SETTINGS_FILE)
        end)
        if not verifyOk or savedText ~= payload then
            return false, "verify"
        end
    end
    return true, "saved"
end
local function loadSettings()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return false end
    local ok, data = pcall(function()
        if not isfile(SETTINGS_FILE) then return nil end
        return HttpService:JSONDecode(readfile(SETTINGS_FILE))
    end)
    if not ok or type(data) ~= "table" then return false end
    if type(data.WalkSpeed) == "number" then walkSpeed = math.clamp(data.WalkSpeed, CONFIG.MinWalkSpeed, CONFIG.MaxWalkSpeed) end
    if type(data.JumpPower) == "number" then jumpPower = math.clamp(data.JumpPower, CONFIG.MinJumpPower, CONFIG.MaxJumpPower) end
    if type(data.FlySpeed) == "number" then flySpeed = math.clamp(data.FlySpeed, CONFIG.MinFlySpeed, CONFIG.MaxFlySpeed) end
    return true
end
local settingsLoaded = loadSettings()
local flying = false
local flyUpHeld = false
local flyDownHeld = false

local flyVelocity
local flyGyro
local flyConnection
local flyAnimateScript
local flyAnimateWasEnabled
local flyAutoRotateBefore
local dragEndConnection
local wallHopEnabled = false
local wallHopLaunchBusy = false
local espEnabled = false
local espObjects = {}
local espConnections = {}
local wallHopConnection
local jumpConnection
local lastWallHop = 0
local pendingWallJumpUntil = 0
local antiSlapEnabled = false
local antiSlapConnection
local noclipEnabled = false
local noclipConnection
local noclipOriginalCollisions = {}
local infiniteJumpEnabled = false
local infiniteJumpConnection
local antiVoidEnabled = false
local antiVoidConnection
local antiVoidSafeCFrame
local antiVoidCharacter
local previousHorizontalVelocity = Vector3.zero
local mainVisible = true
local scriptStopped = false

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- Noclip is opt-in: temporarily disable character-part collisions while enabled.
local function restoreNoclipCollisions()
    for part, originalValue in pairs(noclipOriginalCollisions) do
        if part and part.Parent then
            pcall(function() part.CanCollide = originalValue end)
        end
        noclipOriginalCollisions[part] = nil
    end
end

local function setNoclip(enabled)
    noclipEnabled = enabled
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    if not enabled then
        restoreNoclipCollisions()
        return
    end

    local function disableCharacterCollisions()
        local character = getCharacter()
        if not character then return end
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") then
                if noclipOriginalCollisions[descendant] == nil then
                    noclipOriginalCollisions[descendant] = descendant.CanCollide
                end
                descendant.CanCollide = false
            end
        end
    end

    disableCharacterCollisions()
    noclipConnection = RunService.Stepped:Connect(function()
        if scriptStopped or not noclipEnabled then
            setNoclip(false)
            return
        end
        disableCharacterCollisions()
    end)
end

-- Infinite Jump is opt-in and uses the normal Roblox jump request.
local function setInfiniteJump(enabled)
    infiniteJumpEnabled = enabled
    if infiniteJumpConnection then
        infiniteJumpConnection:Disconnect()
        infiniteJumpConnection = nil
    end
    if not enabled then return end

    infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
        if scriptStopped or not infiniteJumpEnabled then return end
        local humanoid = getHumanoid()
        if humanoid and humanoid.Health > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

-- Anti Void remembers grounded positions and returns the character before falling out.
local function setAntiVoid(enabled)
    antiVoidEnabled = enabled
    if antiVoidConnection then
        antiVoidConnection:Disconnect()
        antiVoidConnection = nil
    end
    if not enabled then
        antiVoidSafeCFrame = nil
        antiVoidCharacter = nil
        return
    end

    antiVoidConnection = RunService.Heartbeat:Connect(function()
        if scriptStopped or not antiVoidEnabled then
            setAntiVoid(false)
            return
        end
        local character = getCharacter()
        local humanoid = getHumanoid()
        local root = getRoot()
        if not character or not humanoid or not root or humanoid.Health <= 0 then return end
        if character ~= antiVoidCharacter then
            antiVoidCharacter = character
            antiVoidSafeCFrame = nil
        end

        local destroyHeight = workspace.FallenPartsDestroyHeight
        if humanoid.FloorMaterial ~= Enum.Material.Air and root.Position.Y > destroyHeight + 30 then
            antiVoidSafeCFrame = root.CFrame
        elseif root.Position.Y <= destroyHeight + 12 and antiVoidSafeCFrame then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = antiVoidSafeCFrame + Vector3.new(0, 4, 0)
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

local function applyMovement()
    local humanoid = getHumanoid()
    if not humanoid then return end
    humanoid.WalkSpeed = walkSpeed
    humanoid.UseJumpPower = true
    humanoid.JumpPower = jumpPower
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local gui = make("ScreenGui", {
    Name = "KAIZEN_SHADOW_V3",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

-- Compact landscape-style panel sized to stay inside smaller phone screens.
local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(390, 844)
local panelWidth = math.clamp(viewport.X - 16, 280, 520)
local panelHeight = 340
local main = make("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(panelWidth, panelHeight),
    Position = UDim2.new(0.5, -panelWidth / 2, 0.5, -panelHeight / 2),
    BackgroundColor3 = Color3.fromRGB(10, 10, 15),
    BorderSizePixel = 0,
    Active = true,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 18)}, main)
make("UIStroke", {
    Color = Color3.fromRGB(245, 28, 68),
    Thickness = 1.8,
}, main)
make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 12, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 13)),
    }),
    Rotation = 35,
}, main)

local header = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Color3.fromRGB(92, 0, 25),
    Text = "KAIZEN SHADOW  V3  •  كايزن شادو",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
}, main)
make("UICorner", {CornerRadius = UDim.new(0, 16)}, header)
make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 0, 34)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(72, 0, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 8, 18)),
    }),
    Rotation = 0,
}, header)

local closeButton = make("TextButton", {
    Name = "CloseButton",
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -36, 0, 7),
    BackgroundColor3 = Color3.fromRGB(145, 8, 35),
    Text = "×",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 23,
    AutoButtonColor = true,
    ZIndex = 5,
}, main)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, closeButton)

-- Drag support for touch and mouse.
do
    local dragging = false
    local dragStart
    local startPosition
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
        end
    end)
    dragInputConnection = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end)
    dragEndConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local statusLine = make("TextLabel", {
    Name = "PerformanceStats",
    Position = UDim2.fromOffset(12, 47),
    Size = UDim2.new(1, -24, 0, 18),
    BackgroundTransparency = 1,
    Text = "FPS: --   |   Ping: -- ms",
    TextColor3 = Color3.fromRGB(255, 105, 130),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Center,
}, main)
local scroll = make("ScrollingFrame", {
    Position = UDim2.fromOffset(9, 69),
    Size = UDim2.new(1, -18, 1, -124),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, main)
make("UIListLayout", {
    Padding = UDim.new(0, 7),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, scroll)
make("UIPadding", {
    PaddingTop = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 10),
}, scroll)

-- Live FPS and network ping readout in the panel header.
task.spawn(function()
    local frames, elapsed = 0, 0
    local lastFps = 0
    local statsService = game:GetService("Stats")
    local renderConnection
    renderConnection = RunService.RenderStepped:Connect(function(dt)
        if scriptStopped or not statusLine.Parent then
            if renderConnection then renderConnection:Disconnect() end
            return
        end
        frames += 1
        elapsed += dt
        if elapsed >= 1 then
            lastFps = math.floor(frames / elapsed + 0.5)
            frames, elapsed = 0, 0
            local pingText = "--"
            pcall(function()
                pingText = statsService.Network.ServerStatsItem["Data Ping"]:GetValueString():match("[%d%.]+") or "--"
            end)
            statusLine.Text = "FPS: " .. tostring(lastFps) .. "   |   Ping: " .. pingText .. " ms"
        end
    end)
end)

-- Animated anime banner: Roblox ImageLabels do not play GIF files natively,
-- so this uses a real uploaded image with looping UI tweens (glow/pulse/gradient).
local banner = make("Frame", {
    Name = "AnimatedAnimeBanner",
    LayoutOrder = 1,
    Size = UDim2.new(1, -8, 0, 86),
    BackgroundColor3 = Color3.fromRGB(24, 5, 12),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, scroll)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, banner)
local bannerStroke = make("UIStroke", {
    Color = Color3.fromRGB(210, 18, 52),
    Thickness = 1.8,
    Transparency = 0.15,
}, banner)
local bannerGradient = make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 0, 15)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 7, 13)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 0, 24)),
    }),
    Rotation = 0,
}, banner)
local bannerImage = make("ImageLabel", {
    Name = "AnimeArtwork",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -5, 0.5, 0),
    Size = UDim2.fromOffset(104, 104),
    Image = "rbxassetid://8592618664",
    ImageTransparency = 0.08,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 2,
}, banner)
local bannerTitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 12),
    Size = UDim2.new(1, -125, 0, 27),
    Text = "KAIZEN SHADOW V3",
    TextColor3 = Color3.fromRGB(255, 245, 248),
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBlack,
    TextSize = 17,
    ZIndex = 3,
}, banner)
local bannerSubtitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(13, 42),
    Size = UDim2.new(1, -125, 0, 20),
    Text = "THE SHADOW AWAKENS",
    TextColor3 = Color3.fromRGB(255, 75, 105),
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    ZIndex = 3,
}, banner)

task.spawn(function()
    while gui.Parent and not scriptStopped and banner.Parent do
        local gradientTween = TweenService:Create(
            bannerGradient,
            TweenInfo.new(3.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
            {Rotation = bannerGradient.Rotation + 180}
        )
        local glowTween = TweenService:Create(
            bannerStroke,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {Transparency = 0.55, Thickness = 2.8}
        )
        local imageTween = TweenService:Create(
            bannerImage,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {ImageTransparency = 0.28, Position = UDim2.new(1, -9, 0.5, 0)}
        )
        gradientTween:Play(); glowTween:Play(); imageTween:Play()
        task.wait(1.1)
        if not banner.Parent then break end
        local glowBack = TweenService:Create(bannerStroke, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {
            Transparency = 0.12, Thickness = 1.8
        })
        local imageBack = TweenService:Create(bannerImage, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {
            ImageTransparency = 0.06, Position = UDim2.new(1, -5, 0.5, 0)
        })
        glowBack:Play(); imageBack:Play()
        task.wait(1.1)
    end
end)

local order = 1
local function section(title)
    order += 1
    local label = make("TextLabel", {
        LayoutOrder = order,
        Size = UDim2.new(1, -8, 0, 29),
        BackgroundColor3 = Color3.fromRGB(27, 12, 19),
        BackgroundTransparency = 0.12,
        Text = "   " .. title,
        TextColor3 = Color3.fromRGB(255, 92, 118),
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
    }, scroll)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, label)
    make("UIStroke", {Color = Color3.fromRGB(105, 20, 40), Thickness = 0.8, Transparency = 0.35}, label)
    make("Frame", {
        Size = UDim2.new(0, 3, 1, -10),
        Position = UDim2.fromOffset(5, 5),
        BackgroundColor3 = Color3.fromRGB(245, 35, 75),
        BorderSizePixel = 0,
    }, label)
    return label
end

local function button(title, callback)
    order += 1
    local b = make("TextButton", {
        LayoutOrder = order,
        Size = UDim2.new(1, -8, 0, 38),
        BackgroundColor3 = Color3.fromRGB(65, 8, 22),
        TextColor3 = Color3.new(1, 1, 1),
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        AutoButtonColor = true,
    }, scroll)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
    make("UIStroke", {
        Color = Color3.fromRGB(150, 15, 40),
        Thickness = 1,
    }, b)
    b.Activated:Connect(callback)
    return b
end

local function holdButton(title, onBegin, onEnd)
    local b = button(title, function() end)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            onBegin()
        end
    end)
    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            onEnd()
        end
    end)
    return b
end

-- Flight uses the camera's pitch and the mobile movement joystick.
local flyButton

local function stopFlying()
    flying = false
    flyUpHeld = false
    flyDownHeld = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end
    if flyGyro then
        flyGyro:Destroy()
        flyGyro = nil
    end

    -- Restore normal character animation and rotation after flight ends.
    local humanoid = getHumanoid()
    if humanoid then
        if flyAutoRotateBefore ~= nil then
            humanoid.AutoRotate = flyAutoRotateBefore
        else
            humanoid.AutoRotate = true
        end
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    if flyAnimateScript and flyAnimateScript.Parent and flyAnimateWasEnabled ~= nil then
        flyAnimateScript.Disabled = not flyAnimateWasEnabled
    end
    flyAnimateScript = nil
    flyAnimateWasEnabled = nil
    flyAutoRotateBefore = nil

    if flyButton then
        flyButton.Text = "الطيران: إيقاف"
    end
end

local characterAddedConnection
local characterRemovingConnection
local dragInputConnection
local function setPanelVisible(value)
    mainVisible = value
    main.Visible = value
end

local restoreAntiSlapMovement

local function shutdownScript()
    if scriptStopped then return end
    scriptStopped = true

    saveSettings()
    setNoclip(false)
    setInfiniteJump(false)
    setAntiVoid(false)
    stopFlying()
    flyUpHeld = false
    flyDownHeld = false
    wallHopEnabled = false
    espEnabled = false
    for _, connection in ipairs(espConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(espConnections)
    if wallHopConnection then wallHopConnection:Disconnect(); wallHopConnection = nil end
    if jumpConnection then jumpConnection:Disconnect(); jumpConnection = nil end
    if antiSlapConnection then antiSlapConnection:Disconnect(); antiSlapConnection = nil end
    restoreAntiSlapMovement()
    for player, objects in pairs(espObjects) do
        for _, object in ipairs(objects) do
            if object and object.Parent then object:Destroy() end
        end
    end
    table.clear(espObjects)

    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end
    if characterRemovingConnection then
        characterRemovingConnection:Disconnect()
        characterRemovingConnection = nil
    end
    if dragInputConnection then dragInputConnection:Disconnect(); dragInputConnection = nil end
    if dragEndConnection then dragEndConnection:Disconnect(); dragEndConnection = nil end

    -- Restore the ordinary movement values before removing the interface.
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 50
    end

    if gui and gui.Parent then
        gui:Destroy()
    end
    print("[KAIZEN SHADOW] تم إيقاف السكربت.")
end

-- X only hides the panel; the floating anime-style toggle restores it.
closeButton.Activated:Connect(function()
    setPanelVisible(false)
end)

-- Confirmation dialog for permanent shutdown.
local confirm = make("Frame", {
    Name = "ShutdownConfirm",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(280, 142),
    BackgroundColor3 = Color3.fromRGB(17, 12, 18),
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 50,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, confirm)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 2}, confirm)
make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 56), Position = UDim2.fromOffset(10, 12),
    BackgroundTransparency = 1, Text = "هل تريد إيقاف السكربت نهائياً؟",
    TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold,
    TextSize = 16, TextWrapped = true, ZIndex = 51,
}, confirm)
local yesButton = make("TextButton", {
    Size = UDim2.new(0.43, 0, 0, 36), Position = UDim2.new(0.06, 0, 1, -48),
    BackgroundColor3 = Color3.fromRGB(155, 8, 38), Text = "نعم",
    TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 15, ZIndex = 51,
}, confirm)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, yesButton)
local noButton = make("TextButton", {
    Size = UDim2.new(0.43, 0, 0, 36), Position = UDim2.new(0.51, 0, 1, -48),
    BackgroundColor3 = Color3.fromRGB(55, 48, 55), Text = "لا",
    TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 15, ZIndex = 51,
}, confirm)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, noButton)
yesButton.Activated:Connect(shutdownScript)
noButton.Activated:Connect(function() confirm.Visible = false end)

-- Dedicated permanent shutdown button, kept separate from the small X.
local shutdownButton = make("TextButton", {
    Name = "PermanentShutdownButton",
    Position = UDim2.new(0, 10, 1, -47),
    Size = UDim2.new(1, -20, 0, 37),
    BackgroundColor3 = Color3.fromRGB(150, 5, 35),
    Text = "إلغاء السكربت نهائياً",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 14,
    AutoButtonColor = true,
    ZIndex = 6,
}, main)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, shutdownButton)
make("UIStroke", {Color = Color3.fromRGB(255, 65, 90), Thickness = 1.4}, shutdownButton)
shutdownButton.Activated:Connect(function() confirm.Visible = true end)

local function startFlying()
    local root = getRoot()
    if not root then return end

    stopFlying()
    root = getRoot()
    if not root then return end
    local humanoid = getHumanoid()
    if not humanoid then return end

    flying = true
    flyButton.Text = "الطيران: تشغيل"

    -- Hold the avatar in a steady upright pose while flying: pause the default
    -- animation controller and let the gyro control only the body's yaw.
    flyAutoRotateBefore = humanoid and humanoid.AutoRotate
    if humanoid then
        humanoid.AutoRotate = false
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                pcall(function() track:Stop(0.1) end)
            end
        end
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
    end
    local character = getCharacter()
    flyAnimateScript = character and character:FindFirstChild("Animate")
    if flyAnimateScript and flyAnimateScript:IsA("LocalScript") then
        flyAnimateWasEnabled = not flyAnimateScript.Disabled
        flyAnimateScript.Disabled = true
    else
        flyAnimateScript = nil
    end

    flyVelocity = make("BodyVelocity", {
        MaxForce = Vector3.new(1e6, 1e6, 1e6),
        P = 30000,
        Velocity = Vector3.zero,
    }, root)

    local initialLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
    if initialLook.Magnitude < 0.001 then
        initialLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    end
    if initialLook.Magnitude < 0.001 then
        initialLook = Vector3.new(0, 0, -1)
    end
    flyGyro = make("BodyGyro", {
        MaxTorque = Vector3.new(1e6, 1e6, 1e6),
        P = 30000,
        CFrame = CFrame.lookAt(root.Position, root.Position + initialLook.Unit, Vector3.yAxis),
    }, root)

    flyConnection = RunService.Heartbeat:Connect(function()
        if not flying or not root.Parent then
            stopFlying()
            return
        end

        local humanoid = getHumanoid()
        if not humanoid then return end

        -- Convert joystick movement into camera-relative forward/right input.
        -- Camera pitch affects forward movement, so looking up/down changes altitude.
        local move = humanoid.MoveDirection
        local cameraLook = Camera.CFrame.LookVector
        local cameraRight = Camera.CFrame.RightVector

        local forwardAmount = move:Dot(Vector3.new(cameraLook.X, 0, cameraLook.Z).Magnitude > 0
            and Vector3.new(cameraLook.X, 0, cameraLook.Z).Unit or cameraLook)
        local rightAmount = move:Dot(cameraRight)

        local direction = cameraLook * forwardAmount + cameraRight * rightAmount

        -- Explicit hold controls remain available as an accessibility fallback.
        if flyUpHeld then
            direction = direction + Vector3.new(0, 1, 0)
        elseif flyDownHeld then
            direction = direction + Vector3.new(0, -1, 0)
        end

        if direction.Magnitude > 0.05 then
            flyVelocity.Velocity = direction.Unit * flySpeed
        else
            flyVelocity.Velocity = Vector3.zero
        end

        local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        if flatLook.Magnitude < 0.001 then
            flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        end
        if flatLook.Magnitude > 0.001 then
            -- Keep the torso upright; camera pitch changes travel direction, not body pose.
            flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit, Vector3.yAxis)
        end
    end)
end

-- Wall Hop: one outward/upward impulse for each explicit jump request near a wall.
local function findNearbyWall(character, root)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.IgnoreWater = true

    local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
    if look.Magnitude > 0 then look = look.Unit end
    if right.Magnitude > 0 then right = right.Unit end

    local directions = {look, -look, right, -right}
    local bestHit, bestDistance = nil, math.huge
    for _, direction in ipairs(directions) do
        if direction.Magnitude > 0 then
            local hit = workspace:Raycast(root.Position, direction * CONFIG.WallHopDistance, params)
            if hit and math.abs(hit.Normal.Y) < 0.35 then
                local distance = (hit.Position - root.Position).Magnitude
                if distance < bestDistance then bestHit, bestDistance = hit, distance end
            end
        end
    end
    return bestHit
end

local function setWallHop(enabled)
    wallHopEnabled = enabled
    if wallHopConnection then wallHopConnection:Disconnect(); wallHopConnection = nil end
    if jumpConnection then jumpConnection:Disconnect(); jumpConnection = nil end
    pendingWallJumpUntil = 0

    if enabled then
        -- JumpRequest is fired by Roblox's keyboard/gamepad/mobile jump controls.
        -- A request is consumed exactly once after the avatar enters an airborne state.
        jumpConnection = UserInputService.JumpRequest:Connect(function()
            if not scriptStopped and wallHopEnabled then
                pendingWallJumpUntil = os.clock() + 0.65
            end
        end)

        wallHopConnection = RunService.Heartbeat:Connect(function()
            if scriptStopped or not wallHopEnabled then return end
            local now = os.clock()
            if now > pendingWallJumpUntil then return end

            local character, root, humanoid = getCharacter(), getRoot(), getHumanoid()
            if not character or not root or not humanoid or humanoid.Health <= 0 then return end
            local state = humanoid:GetState()
            local airborne = state == Enum.HumanoidStateType.Freefall
                or state == Enum.HumanoidStateType.Jumping
            if not airborne then return end

            local hit = findNearbyWall(character, root)
            if not hit or now - lastWallHop < CONFIG.WallHopInterval then return end

            -- Consume before applying force: one jump press can never repeat the boost.
            pendingWallJumpUntil = 0
            lastWallHop = now
            local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
            if normal.Magnitude < 0.001 then return end
            normal = normal.Unit

            local current = root.AssemblyLinearVelocity
            local target = Vector3.new(
                normal.X * CONFIG.WallHopPushVelocity,
                math.max(current.Y, CONFIG.WallHopUpVelocity),
                normal.Z * CONFIG.WallHopPushVelocity
            )
            -- ApplyImpulse gives the avatar a physical kick away from the wall,
            -- rather than teleporting it or repeatedly setting velocity each frame.
            root:ApplyImpulse((target - current) * root.AssemblyMass)
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

-- Anti-Slap AFK lock: anchor the character's root part locally while enabled.
-- This is a client-side freeze; server-authoritative forces may still override it.
local antiSlapSaved = nil
local antiSlapRoot = nil

restoreAntiSlapMovement = function()
    local humanoid = getHumanoid()
    if humanoid and antiSlapSaved then
        humanoid.WalkSpeed = antiSlapSaved.WalkSpeed or CONFIG.WalkSpeed
        humanoid.UseJumpPower = antiSlapSaved.UseJumpPower
        if antiSlapSaved.UseJumpPower then
            humanoid.JumpPower = antiSlapSaved.JumpPower or CONFIG.JumpPower
        else
            humanoid.JumpHeight = antiSlapSaved.JumpHeight or 7.2
        end
        humanoid.AutoRotate = antiSlapSaved.AutoRotate
        humanoid.PlatformStand = antiSlapSaved.PlatformStand or false
    end
    if antiSlapRoot and antiSlapRoot.Parent then
        antiSlapRoot.Anchored = antiSlapSaved and antiSlapSaved.RootAnchored or false
    end
    antiSlapRoot = nil
    antiSlapSaved = nil
end

local function setAntiSlap(enabled)
    antiSlapEnabled = enabled
    if antiSlapConnection then
        antiSlapConnection:Disconnect()
        antiSlapConnection = nil
    end

    if not enabled then
        restoreAntiSlapMovement()
        return
    end

    -- AFK means no flying or wall-hop movement while the lock is active.
    if flying then stopFlying() end
    local humanoid, root = getHumanoid(), getRoot()
    if humanoid and root then
        antiSlapRoot = root
        antiSlapSaved = {
            WalkSpeed = humanoid.WalkSpeed,
            UseJumpPower = humanoid.UseJumpPower,
            JumpPower = humanoid.JumpPower,
            JumpHeight = humanoid.JumpHeight,
            AutoRotate = humanoid.AutoRotate,
            PlatformStand = humanoid.PlatformStand,
            RootAnchored = root.Anchored,
        }
        humanoid.WalkSpeed = 0
        humanoid.AutoRotate = false
        humanoid.PlatformStand = false
        if humanoid.UseJumpPower then
            humanoid.JumpPower = 0
        else
            humanoid.JumpHeight = 0
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = true
    end

    antiSlapConnection = RunService.Heartbeat:Connect(function()
        if scriptStopped or not antiSlapEnabled then return end
        local currentHumanoid, currentRoot = getHumanoid(), getRoot()
        if not currentHumanoid or not currentRoot or currentHumanoid.Health <= 0 then return end

        -- Handle respawns/new character roots without leaving the new character movable.
        if currentRoot ~= antiSlapRoot then
            antiSlapRoot = currentRoot
            antiSlapSaved = {
                WalkSpeed = currentHumanoid.WalkSpeed,
                UseJumpPower = currentHumanoid.UseJumpPower,
                JumpPower = currentHumanoid.JumpPower,
                JumpHeight = currentHumanoid.JumpHeight,
                AutoRotate = currentHumanoid.AutoRotate,
                PlatformStand = currentHumanoid.PlatformStand,
                RootAnchored = currentRoot.Anchored,
            }
        end
        currentHumanoid.WalkSpeed = 0
        currentHumanoid.AutoRotate = false
        if currentHumanoid.UseJumpPower then
            currentHumanoid.JumpPower = 0
        else
            currentHumanoid.JumpHeight = 0
        end
        currentHumanoid:Move(Vector3.zero, true)
        currentRoot.AssemblyLinearVelocity = Vector3.zero
        currentRoot.AssemblyAngularVelocity = Vector3.zero
        currentRoot.Anchored = true
    end)
end

-- Player ESP uses local Highlight + name tags with AlwaysOnTop; no remote/server changes.
local function clearPlayerEsp()
    for _, objects in pairs(espObjects) do
        for _, object in ipairs(objects) do
            if object and object.Parent then object:Destroy() end
        end
    end
    table.clear(espObjects)
end

local function addPlayerEsp(player)
    if not espEnabled or player == LocalPlayer or espObjects[player] then return end
    local character = player.Character
    if not character then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "KaizenPlayerHighlight"
    highlight.Adornee = character
    highlight.FillColor = Color3.fromRGB(220, 20, 55)
    highlight.OutlineColor = Color3.fromRGB(255, 90, 115)
    highlight.FillTransparency = 0.72
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = gui
    local tag = Instance.new("BillboardGui")
    tag.Name = "KaizenPlayerName"
    tag.Adornee = character:FindFirstChild("Head")
    tag.Size = UDim2.fromOffset(150, 28)
    tag.StudsOffset = Vector3.new(0, 2.5, 0)
    tag.AlwaysOnTop = true
    tag.Parent = gui
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = player.DisplayName .. "  (" .. player.Name .. ")"
    label.TextColor3 = Color3.fromRGB(255, 90, 115)
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = tag
    espObjects[player] = {highlight, tag}
end

local function setEsp(enabled)
    espEnabled = enabled
    for _, connection in ipairs(espConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(espConnections)
    clearPlayerEsp()
    if not enabled then return end
    for _, player in ipairs(Players:GetPlayers()) do addPlayerEsp(player) end
    table.insert(espConnections, Players.PlayerAdded:Connect(function(player)
        table.insert(espConnections, player.CharacterAdded:Connect(function()
            task.wait(0.5)
            addPlayerEsp(player)
        end))
    end))
    table.insert(espConnections, Players.PlayerRemoving:Connect(function(player)
        local objects = espObjects[player]
        if objects then
            for _, object in ipairs(objects) do if object and object.Parent then object:Destroy() end end
            espObjects[player] = nil
        end
    end))
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(espConnections, player.CharacterAdded:Connect(function()
                task.wait(0.5)
                addPlayerEsp(player)
            end))
        end
    end
end

section("الطيران")
flyButton = button("الطيران: إيقاف", function()
    if flying then stopFlying() else startFlying() end
end)
button("زيادة سرعة الطيران +", function()
    flySpeed = math.min(flySpeed + 10, CONFIG.MaxFlySpeed)
    saveSettings()
end)
button("تقليل سرعة الطيران -", function()
    flySpeed = math.max(flySpeed - 10, CONFIG.MinFlySpeed)
    saveSettings()
end)
holdButton("اضغط مطولاً للصعود", function()
    if flying then flyUpHeld = true end
end, function() flyUpHeld = false end)
holdButton("اضغط مطولاً للنزول", function()
    if flying then flyDownHeld = true end
end, function() flyDownHeld = false end)

section("السرعة")
button("زيادة سرعة المشي +", function()
    walkSpeed = math.min(walkSpeed + 5, CONFIG.MaxWalkSpeed)
    applyMovement()
    saveSettings()
end)
button("تقليل سرعة المشي -", function()
    walkSpeed = math.max(walkSpeed - 5, CONFIG.MinWalkSpeed)
    applyMovement()
    saveSettings()
end)

section("القفز")
button("زيادة قوة القفز +", function()
    jumpPower = math.min(jumpPower + 10, CONFIG.MaxJumpPower)
    applyMovement()
    saveSettings()
end)
button("تقليل قوة القفز -", function()
    jumpPower = math.max(jumpPower - 10, CONFIG.MinJumpPower)
    applyMovement()
    saveSettings()
end)

section("مميزات إضافية")
local noclipButton
noclipButton = button("Noclip: إيقاف", function()
    setNoclip(not noclipEnabled)
    noclipButton.Text = noclipEnabled and "Noclip: تشغيل" or "Noclip: إيقاف"
end)
local infiniteJumpButton
infiniteJumpButton = button("Infinite Jump: إيقاف", function()
    setInfiniteJump(not infiniteJumpEnabled)
    infiniteJumpButton.Text = infiniteJumpEnabled and "Infinite Jump: تشغيل" or "Infinite Jump: إيقاف"
end)
local antiVoidButton
antiVoidButton = button("Anti Void: إيقاف", function()
    setAntiVoid(not antiVoidEnabled)
    antiVoidButton.Text = antiVoidEnabled and "Anti Void: تشغيل" or "Anti Void: إيقاف"
end)
-- Wall Hop button re-runs the supplied external loader whenever tapped.
-- This lets the user restore the external script UI if it was dismissed.
local wallHopButton
wallHopButton = button("Wall Hop: تشغيل / إظهار", function()
    if wallHopLaunchBusy then return end
    wallHopLaunchBusy = true
    task.spawn(function()
        local ok, err = pcall(function()
            local source = game:HttpGet("https://raw.githubusercontent.com/Rawbr10/Roblox-Scripts/refs/heads/main/Ladder%20Flick%20And%20Wallhop")
            local loader = loadstring(source)
            assert(type(loader) == "function", "تعذر تحميل سكربت Wall Hop")
            loader()
        end)
        if not ok then
            warn("[KAIZEN] Wall Hop load failed: " .. tostring(err))
        end
        task.wait(0.8)
        wallHopLaunchBusy = false
    end)
end)

-- The pin opens a separate on-screen Anti-Slap switch.
local antiSlapRow = make("Frame", {
    Name = "AntiSlapRow",
    LayoutOrder = 0,
    Size = UDim2.new(1, -8, 0, 38),
    BackgroundTransparency = 1,
}, scroll)
-- Build the Anti-Slap control and pin side by side.
order += 1
antiSlapRow.LayoutOrder = order
local antiSlapMainButton = make("TextButton", {
    Size = UDim2.new(1, -49, 1, 0),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = Color3.fromRGB(65, 8, 22),
    TextColor3 = Color3.new(1, 1, 1),
    Text = "AFK: تشغيل",
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    AutoButtonColor = true,
}, antiSlapRow)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, antiSlapMainButton)
make("UIStroke", {Color = Color3.fromRGB(150, 15, 40), Thickness = 1}, antiSlapMainButton)
local pinButton = make("TextButton", {
    Size = UDim2.fromOffset(42, 38),
    Position = UDim2.new(1, -42, 0, 0),
    BackgroundColor3 = Color3.fromRGB(85, 0, 22),
    Text = "📌",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    AutoButtonColor = true,
}, antiSlapRow)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, pinButton)
make("UIStroke", {Color = Color3.fromRGB(180, 20, 50), Thickness = 1}, pinButton)

local floatingAntiSlap = make("TextButton", {
    Name = "AntiSlapFloatingToggle",
    Size = UDim2.fromOffset(94, 32),
    Position = UDim2.new(1, -106, 0.72, 0),
    BackgroundColor3 = Color3.fromRGB(65, 8, 22),
    TextColor3 = Color3.new(1, 1, 1),
    Text = "AFK: تشغيل",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    Visible = false,
    Active = true,
    AutoButtonColor = true,
    ZIndex = 30,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, floatingAntiSlap)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.5}, floatingAntiSlap)

-- The compact AFK switch can be dragged anywhere on the screen (touch or mouse).
do
    local dragging, dragStart, startPosition = false, nil, nil
    local dragChanged, dragEnded
    floatingAntiSlap.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPosition = floatingAntiSlap.Position
        end
    end)
    dragChanged = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            floatingAntiSlap.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
    dragEnded = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    floatingAntiSlap.Destroying:Connect(function()
        if dragChanged then dragChanged:Disconnect() end
        if dragEnded then dragEnded:Disconnect() end
    end)
end

local function refreshAntiSlapLabels()
    local label = antiSlapEnabled and "AFK: تشغيل" or "AFK: إيقاف"
    antiSlapMainButton.Text = label
    floatingAntiSlap.Text = label
end
local function toggleAntiSlap()
    setAntiSlap(not antiSlapEnabled)
    refreshAntiSlapLabels()
end
antiSlapMainButton.Activated:Connect(toggleAntiSlap)
floatingAntiSlap.Activated:Connect(toggleAntiSlap)
pinButton.Activated:Connect(function()
    floatingAntiSlap.Visible = not floatingAntiSlap.Visible
end)
refreshAntiSlapLabels()

local espButton
espButton = button("كشف اللاعبين: إيقاف", function()
    setEsp(not espEnabled)
    espButton.Text = espEnabled and "كشف اللاعبين: تشغيل" or "كشف اللاعبين: إيقاف"
end)

section("مركز التحكم")
local saveSettingsButton
saveSettingsButton = button("حفظ الإعدادات الحالية", function()
    local saved, reason = saveSettings()
    local originalText = "حفظ الإعدادات الحالية"
    if saved then
        saveSettingsButton.Text = "تم حفظ الإعدادات ✓"
    elseif reason == "unsupported" then
        saveSettingsButton.Text = "الحفظ غير مدعوم بالمشغّل"
    else
        saveSettingsButton.Text = "فشل الحفظ - حاول مجددًا"
    end
    task.delay(2.5, function()
        if saveSettingsButton and saveSettingsButton.Parent then
            saveSettingsButton.Text = originalText
        end
    end)
end)
button("إعادة ضبط السرعة والقفز والطيران", function()
    walkSpeed = CONFIG.WalkSpeed
    jumpPower = CONFIG.JumpPower
    flySpeed = CONFIG.FlySpeed
    applyMovement()
    saveSettings()
    print("[KAIZEN] تمت إعادة ضبط إعدادات الحركة.")
end)
button("إيقاف جميع المميزات المحلية", function()
    setNoclip(false)
    if noclipButton then noclipButton.Text = "Noclip: إيقاف" end
    setInfiniteJump(false)
    if infiniteJumpButton then infiniteJumpButton.Text = "Infinite Jump: إيقاف" end
    setAntiVoid(false)
    if antiVoidButton then antiVoidButton.Text = "Anti Void: إيقاف" end
    stopFlying()
    flyUpHeld, flyDownHeld = false, false
    wallHopEnabled = false
    if wallHopConnection then wallHopConnection:Disconnect(); wallHopConnection = nil end
    if jumpConnection then jumpConnection:Disconnect(); jumpConnection = nil end
    setEsp(false)
    setAntiSlap(false)
    refreshAntiSlapLabels()
    applyMovement()
    print("[KAIZEN] تم إيقاف المميزات المحلية. يمكن إعادة تشغيلها من الواجهة.")
end)

-- Arabic welcome message (shown once when the script starts)
local welcome = make("Frame", {
    Name = "Welcome",
    Size = UDim2.fromOffset(270, 112),
    Position = UDim2.new(0.5, -135, 0.5, -56),
    BackgroundColor3 = Color3.fromRGB(18, 18, 24),
    BorderSizePixel = 0,
    ZIndex = 20,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, welcome)
make("UIStroke", {
    Color = Color3.fromRGB(220, 20, 55),
    Thickness = 2,
}, welcome)

make("TextLabel", {
    Size = UDim2.new(1, -16, 0, 48),
    Position = UDim2.fromOffset(8, 8),
    BackgroundTransparency = 1,
    Text = "أهلاً بيك في KAIZEN SHADOW",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    TextWrapped = true,
    ZIndex = 21,
}, welcome)

local welcomeButton = make("TextButton", {
    Size = UDim2.new(1, -28, 0, 34),
    Position = UDim2.fromOffset(14, 66),
    BackgroundColor3 = Color3.fromRGB(120, 0, 30),
    Text = "ابدأ",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    ZIndex = 21,
}, welcome)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, welcomeButton)
welcomeButton.Activated:Connect(function()
    welcome:Destroy()
    main.Visible = true
end)
main.Visible = false

section("الديسكورد")
button("نسخ رابط الديسكورد", function()
    local copied = false
    if typeof(setclipboard) == "function" then
        copied = pcall(setclipboard, CONFIG.Discord)
    end
    if copied then
        print("[KAIZEN] Discord invite copied.")
    else
        print("[KAIZEN] Discord invite: " .. CONFIG.Discord)
    end
end)

-- Floating anime portrait button: tap it to show/hide the main panel.
local toggle = make("ImageButton", {
    Name = "AnimeToggle",
    Size = UDim2.fromOffset(60, 60),
    Position = UDim2.new(0, 14, 0.45, 0),
    BackgroundColor3 = Color3.fromRGB(120, 0, 30),
    Image = "rbxassetid://8592618664",
    ScaleType = Enum.ScaleType.Crop,
    AutoButtonColor = true,
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, toggle)
make("UIStroke", {Color = Color3.fromRGB(255, 65, 90), Thickness = 2.2}, toggle)
toggle.Activated:Connect(function()
    setPanelVisible(not mainVisible)
end)


-- Professional bottom Discord invitation toast (shown on activation)
local toast = make("Frame", {
    Name = "DiscordWelcomeToast",
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, 90),
    Size = UDim2.new(0.88, 0, 0, 62),
    BackgroundColor3 = Color3.fromRGB(18, 18, 25),
    BorderSizePixel = 0,
    ZIndex = 30,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 13)}, toast)
make("UIStroke", {
    Color = Color3.fromRGB(190, 15, 45),
    Thickness = 1.6,
}, toast)

make("Frame", {
    Size = UDim2.new(0, 5, 1, -14),
    Position = UDim2.fromOffset(7, 7),
    BackgroundColor3 = Color3.fromRGB(235, 25, 60),
    BorderSizePixel = 0,
    ZIndex = 31,
}, toast)

make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 27),
    Position = UDim2.fromOffset(18, 5),
    BackgroundTransparency = 1,
    Text = "يرجى دخول سيرفر الديسكورد",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 31,
}, toast)

local discordToastButton = make("TextButton", {
    Size = UDim2.new(1, -34, 0, 23),
    Position = UDim2.fromOffset(20, 33),
    BackgroundTransparency = 1,
    Text = "اضغط لنسخ رابط الدعوة",
    TextColor3 = Color3.fromRGB(255, 95, 120),
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    ZIndex = 31,
}, toast)

local toastCountdown = make("TextLabel", {
    Name = "ToastCountdown",
    Size = UDim2.fromOffset(72, 18),
    Position = UDim2.new(1, -78, 0, -18),
    BackgroundTransparency = 1,
    Text = tostring(CONFIG.DiscordToastSeconds) .. " ث",
    TextColor3 = Color3.fromRGB(255, 120, 140),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 32,
}, toast)

discordToastButton.Activated:Connect(function()
    if typeof(setclipboard) == "function" then
        local ok = pcall(setclipboard, CONFIG.Discord)
        if ok then
            discordToastButton.Text = "تم نسخ رابط الديسكورد"
        else
            discordToastButton.Text = CONFIG.Discord
        end
    else
        discordToastButton.Text = CONFIG.Discord
    end
end)

TweenService:Create(
    toast,
    TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    {Position = UDim2.new(0.5, 0, 1, -18)}
):Play()

task.spawn(function()
    for secondsLeft = CONFIG.DiscordToastSeconds, 1, -1 do
        if not toast or not toast.Parent or scriptStopped then return end
        toastCountdown.Text = tostring(secondsLeft) .. " ث"
        task.wait(1)
    end
    if toast and toast.Parent then
        local hideTween = TweenService:Create(
            toast,
            TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, 0, 1, 90)}
        )
        hideTween:Play()
        hideTween.Completed:Wait()
        if toast and toast.Parent then toast:Destroy() end
    end
end)


characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if not scriptStopped then
        applyMovement()
        if flying then
            stopFlying()
        end
    end
end)

characterRemovingConnection = LocalPlayer.CharacterRemoving:Connect(function()
    stopFlying()
end)

gui.Destroying:Connect(function()
    stopFlying()
end)

applyMovement()
print("[KAIZEN SHADOW V3] تم تشغيل السكربت.")
