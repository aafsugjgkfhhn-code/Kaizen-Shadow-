--[[
KAIZEN SHADOW V3 - CHAT + DANCES LOADER
Runs the original GitHub script unchanged, then adds a compact companion panel.
The chat uses the existing Cloudflare Worker routes: /register, /send, /messages.
Requires an executor that exposes request, http_request, or syn.request.
]]
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local ORIGINAL_URL = "https://raw.githubusercontent.com/aafsugjgkfhhn-code/Kaizen-Shadow-/refs/heads/main/KAIZEN_SHADOW_V3_NOCLIP_INFINITEJUMP_ANTIVOID.lua"
local API = "https://kaizen-chat-api.aafsugjgkfhhn.workers.dev"
local DANCE_URL = "https://rawscripts.net/raw/Universal-Script-7yd7-I-Emote-Script-48024"

-- Start the original KAIZEN interface without editing its source.
local originalOk, originalErr = pcall(function()
    local source = game:HttpGet(ORIGINAL_URL)
    local chunk = loadstring(source)
    assert(type(chunk) == "function", "Original script could not be compiled")
    chunk()
end)
if not originalOk then
    warn("[KAIZEN] Original script failed: " .. tostring(originalErr))
    return
end

task.wait(1)

local function getRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    return nil
end

local http = getRequest()
local function apiCall(method, path, body)
    assert(http, "Executor HTTP request API is unavailable")
    local options = {
        Url = API .. path,
        Method = method,
        Headers = {["Content-Type"] = "application/json"},
    }
    if body ~= nil then options.Body = HttpService:JSONEncode(body) end
    local response = http(options)
    local status = response.StatusCode or response.Status or 0
    local responseBody = response.Body or response.body or ""
    if status < 200 or status >= 300 then
        error("HTTP " .. tostring(status) .. ": " .. tostring(responseBody))
    end
    return HttpService:JSONDecode(responseBody)
end

local gui = Instance.new("ScreenGui")
gui.Name = "KAIZEN_CHAT_ADDON"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function make(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local red = Color3.fromRGB(145, 8, 35)
local dark = Color3.fromRGB(15, 12, 18)

local launcher = make("TextButton", {
    Size = UDim2.fromOffset(116, 42),
    Position = UDim2.new(1, -130, 0.58, 0),
    BackgroundColor3 = red,
    Text = "KAIZEN CHAT",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = true,
    Active = true,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, launcher)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.5}, launcher)

-- Put the dance loader button inside the original KAIZEN scrolling menu.
local originalGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("KAIZEN_SHADOW_V3", 8)
local originalMain = originalGui and originalGui:FindFirstChild("Main")
local originalScroll = originalMain and originalMain:FindFirstChildWhichIsA("ScrollingFrame")
if originalScroll then
    local danceButton = make("TextButton", {
        Name = "KAIZEN_DANCES_BUTTON",
        LayoutOrder = 99999,
        Size = UDim2.new(1, -8, 0, 38),
        BackgroundColor3 = Color3.fromRGB(65, 8, 22),
        TextColor3 = Color3.new(1, 1, 1),
        Text = "رقصات",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        AutoButtonColor = true,
    }, originalScroll)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, danceButton)
    make("UIStroke", {Color = Color3.fromRGB(150, 15, 40), Thickness = 1}, danceButton)

    local danceBusy = false
    danceButton.Activated:Connect(function()
        if danceBusy then return end
        danceBusy = true
        task.spawn(function()
            local ok, err = pcall(function()
                local source = game:HttpGet(DANCE_URL)
                local loader = loadstring(source)
                assert(type(loader) == "function", "تعذر تحميل سكربت الرقصات")
                loader()
            end)
            if not ok then warn("[KAIZEN] Dance loader failed: " .. tostring(err)) end
            task.wait(1)
            danceBusy = false
        end)
    end)
else
    warn("[KAIZEN] Original menu not found; dance button was not inserted.")
end

-- Drag helper for the floating chat button and the chat window.
local UserInputService = game:GetService("UserInputService")
local function makeDraggable(target, handle)
    local dragging = false
    local dragStart, startPosition
    handle.InputBegan:Connect(function(inputObject)
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1
            or inputObject.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inputObject.Position
            startPosition = target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inputObject)
        if dragging and (inputObject.UserInputType == Enum.UserInputType.MouseMovement
            or inputObject.UserInputType == Enum.UserInputType.Touch) then
            local delta = inputObject.Position - dragStart
            target.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inputObject)
        if inputObject.UserInputType == Enum.UserInputType.MouseButton1
            or inputObject.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end
makeDraggable(launcher, launcher)

local panel = make("Frame", {
    Size = UDim2.new(0, 250, 0, 285),
    Position = UDim2.new(0.5, -125, 0.5, -142),
    BackgroundColor3 = dark,
    BorderSizePixel = 0,
    Visible = false,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.7}, panel)

local title = make("TextLabel", {
    Size = UDim2.new(1, -42, 0, 34),
    Position = UDim2.fromOffset(8, 4),
    BackgroundTransparency = 1,
    Active = true,
    Text = "KAIZEN CHAT • عام",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local close = make("TextButton", {
    Size = UDim2.fromOffset(30, 28),
    Position = UDim2.new(1, -35, 0, 5),
    BackgroundColor3 = red,
    Text = "×",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 20,
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, close)
close.Activated:Connect(function() panel.Visible = false end)
launcher.Activated:Connect(function() panel.Visible = not panel.Visible end)
makeDraggable(panel, title)

local status = make("TextLabel", {
    Size = UDim2.new(1, -16, 0, 20),
    Position = UDim2.fromOffset(8, 38),
    BackgroundTransparency = 1,
    Text = "جارٍ الاتصال...",
    TextColor3 = Color3.fromRGB(255, 125, 145),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local messagesFrame = make("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -112),
    Position = UDim2.fromOffset(8, 62),
    BackgroundColor3 = Color3.fromRGB(24, 19, 25),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, messagesFrame)
make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, messagesFrame)
make("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
}, messagesFrame)

local input = make("TextBox", {
    Size = UDim2.new(1, -82, 0, 34),
    Position = UDim2.new(0, 8, 1, -42),
    BackgroundColor3 = Color3.fromRGB(35, 28, 35),
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderText = "اكتب رسالتك...",
    PlaceholderColor3 = Color3.fromRGB(180, 160, 170),
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    Text = "",
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, input)

local send = make("TextButton", {
    Size = UDim2.fromOffset(66, 34),
    Position = UDim2.new(1, -74, 1, -42),
    BackgroundColor3 = red,
    Text = "إرسال",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, send)

local lastMessageId = 0
local sending = false
local function addMessage(item)
    local id = tonumber(item.id) or 0
    if id <= lastMessageId then return end
    lastMessageId = math.max(lastMessageId, id)
    local label = make("TextLabel", {
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(42, 24, 32),
        BorderSizePixel = 0,
        Text = tostring(item.sender_id or "مستخدم") .. ": " .. tostring(item.message or ""),
        TextColor3 = Color3.fromRGB(255, 235, 240),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, messagesFrame)
    make("UICorner", {CornerRadius = UDim.new(0, 5)}, label)
    task.defer(function()
        messagesFrame.CanvasPosition = Vector2.new(0, math.max(0, messagesFrame.AbsoluteCanvasSize.Y))
    end)
end

local function sendMessage()
    if sending then return end
    local message = input.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then return end
    if #message > 500 then
        status.Text = "الرسالة أطول من 500 حرف"
        return
    end
    sending = true
    send.Text = "..."
    task.spawn(function()
        local ok, err = pcall(function()
            apiCall("POST", "/send", {
                senderId = LocalPlayer.Name,
                message = message,
            })
        end)
        if ok then
            input.Text = ""
            status.Text = "تم إرسال الرسالة"
        else
            status.Text = "فشل الإرسال: " .. tostring(err):sub(1, 70)
        end
        send.Text = "إرسال"
        sending = false
    end)
end
send.Activated:Connect(sendMessage)
input.FocusLost:Connect(function(enterPressed)
    if enterPressed then sendMessage() end
end)

local alive = true
gui.Destroying:Connect(function() alive = false end)

task.spawn(function()
    if not http then
        status.Text = "المشغّل لا يدعم طلبات HTTP"
        return
    end

    local registered, registerError = pcall(function()
        apiCall("POST", "/register", {
            userId = tostring(LocalPlayer.UserId),
            username = tostring(LocalPlayer.Name),
        })
    end)
    if registered then
        status.Text = "متصل • الشات العام"
    else
        status.Text = "تعذر التسجيل: " .. tostring(registerError):sub(1, 65)
        return
    end

    while alive and gui.Parent do
        local ok, result = pcall(function()
            return apiCall("GET", "/messages?after=" .. tostring(lastMessageId))
        end)
        if ok and type(result) == "table" and type(result.messages) == "table" then
            for _, item in ipairs(result.messages) do
                addMessage(item)
            end
        elseif not ok then
            status.Text = "انقطع الاتصال - إعادة المحاولة..."
        end
        task.wait(4)
    end
end)
