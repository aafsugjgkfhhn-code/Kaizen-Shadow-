--[[
KAIZEN SHADOW V3 - CHAT + MEMBERS + JOIN + HEARTBEAT
No Chat 2
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local API = "https://kaizen-chat-api.aafsugjgkfhhn.workers.dev"
local LOADER_URL = "https://raw.githubusercontent.com/aafsugjgkfhhn-code/Kaizen-Shadow-/refs/heads/main/KAIZEN_SHADOW_V3_CHAT_DANCES_DRAGGABLE.lua"

-- Run the existing chat + dances loader
local ok, err = pcall(function()
    local source = game:HttpGet(LOADER_URL)
    local loader = loadstring(source)
    assert(type(loader) == "function", "Loader compilation failed")
    loader()
end)
if not ok then
    warn("[KAIZEN] Loader error: " .. tostring(err))
    return
end

task.wait(2)

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("KAIZEN_CHAT_ADDON", 15)
if not gui then
    warn("[KAIZEN] Chat interface not found")
    return
end

local oldLauncher = gui:FindFirstChildWhichIsA("TextButton")
local chatPanel = gui:FindFirstChildWhichIsA("Frame")
if not oldLauncher or not chatPanel then
    warn("[KAIZEN] Could not find original chat components")
    return
end

local originalPosition = oldLauncher.Position
oldLauncher.Visible = false

local function make(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function round(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end

local function outline(obj)
    make("UIStroke", {
        Color = Color3.fromRGB(235, 25, 65),
        Thickness = 1.3
    }, obj)
end

local red = Color3.fromRGB(145, 8, 35)
local dark = Color3.fromRGB(15, 12, 18)
local white = Color3.new(1, 1, 1)

local function getRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    return nil
end

local http = getRequest()

local function apiCall(method, path, body)
    assert(http, "HTTP requests unavailable")
    local options = {
        Url = API .. path,
        Method = method,
        Headers = {["Content-Type"] = "application/json"}
    }
    if body then options.Body = HttpService:JSONEncode(body) end
    local response = http(options)
    local status = response.StatusCode or response.Status or 0
    local responseBody = response.Body or response.body or ""
    if status < 200 or status >= 300 then
        error("HTTP " .. tostring(status) .. ": " .. tostring(responseBody))
    end
    return HttpService:JSONDecode(responseBody)
end

-- Two floating buttons in one draggable holder
local holder = make("Frame", {
    Name = "KAIZEN_FLOATING_BUTTONS",
    Size = UDim2.fromOffset(116, 84),
    Position = originalPosition,
    BackgroundTransparency = 1,
    Active = true
}, gui)

local chatButton = make("TextButton", {
    Name = "KAIZEN_CHAT_BUTTON",
    Size = UDim2.fromOffset(116, 42),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = red,
    Text = "KAIZEN CHAT",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Active = true
}, holder)
round(chatButton, 9)
outline(chatButton)

local membersButton = make("TextButton", {
    Name = "KAIZEN_MEMBERS_BUTTON",
    Size = UDim2.fromOffset(116, 36),
    Position = UDim2.fromOffset(0, 47),
    BackgroundColor3 = Color3.fromRGB(65, 8, 22),
    Text = "عرض الأعضاء",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Active = true
}, holder)
round(membersButton, 9)
outline(membersButton)

local dragging, dragStart, startPosition
chatButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = holder.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        holder.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

chatButton.Activated:Connect(function()
    chatPanel.Visible = not chatPanel.Visible
end)

-- Independent members window
local membersPanel = make("Frame", {
    Name = "KAIZEN_MEMBERS_WINDOW",
    Size = UDim2.fromOffset(270, 320),
    Position = UDim2.new(0.5, -135, 0.5, -160),
    BackgroundColor3 = dark,
    BorderSizePixel = 0,
    Visible = false
}, gui)
round(membersPanel, 12)
outline(membersPanel)

local title = make("TextLabel", {
    Size = UDim2.new(1, -45, 0, 36),
    Position = UDim2.fromOffset(10, 4),
    BackgroundTransparency = 1,
    Text = "KAIZEN • الأعضاء النشطون",
    TextColor3 = white,
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Active = true
}, membersPanel)

local closeButton = make("TextButton", {
    Size = UDim2.fromOffset(30, 28),
    Position = UDim2.new(1, -36, 0, 5),
    BackgroundColor3 = red,
    Text = "×",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 20
}, membersPanel)
round(closeButton, 6)
closeButton.Activated:Connect(function()
    membersPanel.Visible = false
end)

-- Drag members window by its title
local windowDragging, windowStart, windowPosition
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        windowDragging = true
        windowStart = input.Position
        windowPosition = membersPanel.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if windowDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - windowStart
        membersPanel.Position = UDim2.new(
            windowPosition.X.Scale, windowPosition.X.Offset + delta.X,
            windowPosition.Y.Scale, windowPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        windowDragging = false
    end
end)

local membersStatus = make("TextLabel", {
    Size = UDim2.new(1, -16, 0, 22),
    Position = UDim2.fromOffset(8, 40),
    BackgroundTransparency = 1,
    Text = "جارٍ تحميل الأعضاء...",
    TextColor3 = Color3.fromRGB(255, 125, 145),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left
}, membersPanel)

local membersList = make("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -76),
    Position = UDim2.fromOffset(8, 66),
    BackgroundColor3 = Color3.fromRGB(24, 19, 25),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new()
}, membersPanel)
round(membersList, 7)

make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder
}, membersList)

make("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, membersList)

membersButton.Activated:Connect(function()
    membersPanel.Visible = not membersPanel.Visible
end)

local function clearMembers()
    for _, child in ipairs(membersList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function refreshMembers()
    local success, result = pcall(function()
        return apiCall("GET", "/members")
    end)
    if not success then
        membersStatus.Text = "تعذر تحميل الأعضاء"
        return
    end
    if type(result) ~= "table" or type(result.members) ~= "table" then
        membersStatus.Text = "استجابة الأعضاء غير صحيحة"
        return
    end

    clearMembers()
    local count = 0

    for _, member in ipairs(result.members) do
        local userId = tostring(member.user_id or "")
        local username = tostring(member.username or "Player")
        local placeId = tostring(member.place_id or "")
        local jobId = tostring(member.job_id or "")

        if userId ~= tostring(LocalPlayer.UserId) then
            count = count + 1
            local row = make("Frame", {
                Name = "MemberRow_" .. count,
                Size = UDim2.new(1, -4, 0, 48),
                BackgroundColor3 = Color3.fromRGB(42, 24, 32),
                BorderSizePixel = 0,
                LayoutOrder = count
            }, membersList)
            round(row, 6)

            make("TextLabel", {
                Size = UDim2.new(1, -75, 1, 0),
                Position = UDim2.fromOffset(7, 0),
                BackgroundTransparency = 1,
                Text = username,
                TextColor3 = white,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            }, row)

            local joinButton = make("TextButton", {
                Size = UDim2.fromOffset(60, 30),
                Position = UDim2.new(1, -66, 0.5, -15),
                BackgroundColor3 = Color3.fromRGB(20, 115, 65),
                Text = "JOIN",
                TextColor3 = white,
                Font = Enum.Font.GothamBold,
                TextSize = 11
            }, row)
            round(joinButton, 6)

            joinButton.Activated:Connect(function()
                local numericPlaceId = tonumber(placeId)
                if not numericPlaceId or jobId == "" then
                    membersStatus.Text = "بيانات سيرفر العضو غير متاحة"
                    return
                end

                membersStatus.Text = "جارٍ الانضمام إلى " .. username
                joinButton.Text = "..."

                local teleportOk, teleportError = pcall(function()
                    TeleportService:TeleportToPlaceInstance(
                        numericPlaceId, jobId, LocalPlayer
                    )
                end)

                if not teleportOk then
                    membersStatus.Text = "تعذر الانضمام إلى السيرفر"
                    joinButton.Text = "JOIN"
                    warn("[KAIZEN] Join error: " .. tostring(teleportError))
                end
            end)
        end
    end

    membersStatus.Text = "الأعضاء النشطون: " .. tostring(count)
end

-- Main menu toggle hides/shows both floating buttons together
task.spawn(function()
    local originalGui = playerGui:WaitForChild("KAIZEN_SHADOW_V3", 10)
    local originalMain = originalGui and originalGui:FindFirstChild("Main")
    local originalScroll = originalMain
        and originalMain:FindFirstChildWhichIsA("ScrollingFrame")

    if not originalScroll then
        warn("[KAIZEN] Main menu not found; floating toggle not added")
        return
    end

    local toggleButton = make("TextButton", {
        Name = "KAIZEN_FLOATING_TOGGLE",
        LayoutOrder = 100000,
        Size = UDim2.new(1, -8, 0, 38),
        BackgroundColor3 = red,
        Text = "إخفاء أزرار الشات والأعضاء",
        TextColor3 = white,
        Font = Enum.Font.GothamBold,
        TextSize = 12
    }, originalScroll)
    round(toggleButton, 8)
    outline(toggleButton)

    local hidden = false
    toggleButton.Activated:Connect(function()
        hidden = not hidden
        holder.Visible = not hidden
        toggleButton.Text = hidden
            and "إظهار أزرار الشات والأعضاء"
            or "إخفاء أزرار الشات والأعضاء"
    end)
end)

-- Heartbeat every 30 seconds
local alive = true
gui.Destroying:Connect(function()
    alive = false
end)

task.spawn(function()
    if not http then
        membersStatus.Text = "المشغّل لا يدعم HTTP"
        return
    end

    while alive and gui.Parent do
        local success, heartbeatError = pcall(function()
            apiCall("POST", "/heartbeat", {
                userId = tostring(LocalPlayer.UserId),
                username = tostring(LocalPlayer.Name),
                placeId = tostring(game.PlaceId),
                jobId = tostring(game.JobId)
            })
        end)

        if not success then
            warn("[KAIZEN] Heartbeat error: " .. tostring(heartbeatError))
        end
        task.wait(30)
    end
end)

-- Refresh members every 10 seconds
task.spawn(function()
    while alive and gui.Parent do
        refreshMembers()
        task.wait(10)
    end
end)

print("[KAIZEN] Members system loaded successfully")
