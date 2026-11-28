--[[
KAIZEN SHADOW V3 - CHAT + MEMBERS + TWO-STAGE SHUTDOWN
Based on the user's supplied chat/dances loader.
- Members list + JOIN to the member's recorded PlaceId/JobId
- Members refresh: 5 seconds
- Heartbeat: 5 seconds
- Chat receive polling: 0.5 seconds
- Chat send: immediate on button/Enter
- Chat message font: 15
- Two-stage shutdown:
  Stage 1 Yes -> Stage 2 prompt
  Stage 2 Yes -> stop core + chat + members
  Stage 2 No  -> stop core only; chat + members continue
No overhead chat bubbles are added.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ORIGINAL_URL = "https://raw.githubusercontent.com/aafsugjgkfhhn-code/Kaizen-Shadow-/refs/heads/main/KAIZEN_SHADOW_V3_NOCLIP_INFINITEJUMP_ANTIVOID.lua"
local API = "https://kaizen-chat-api.aafsugjgkfhhn.workers.dev"
local DANCE_URL = "https://rawscripts.net/raw/Universal-Script-7yd7-I-Emote-Script-48024"

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
    if responseBody == "" then return {} end
    return HttpService:JSONDecode(responseBody)
end

local function __KAIZEN_START_RUNTIME__()
-- Patch only the core shutdown hooks so the existing core shutdown function
-- can be called by the two-stage dialog below. The core feature code is unchanged.
local originalOk, originalErr = pcall(function()
    local source = game:HttpGet(ORIGINAL_URL)
    assert(type(source) == "string" and #source > 0, "Original script download was empty")

    local exportMarker = "-- X only hides the panel; the floating anime-style toggle restores it."
    local exportPos = string.find(source, exportMarker, 1, true)
    assert(exportPos, "Could not locate core shutdown export marker")

    source = string.sub(source, 1, exportPos - 1)
        .. "_G.KAIZEN_SHUTDOWN = shutdownScript\n"
        .. string.sub(source, exportPos)

    local oldBinding = "shutdownButton.Activated:Connect(function() confirm.Visible = true end)"
    local newBinding = [[shutdownButton.Activated:Connect(function()
    if type(_G.KAIZEN_TWO_STAGE_STOP) == "function" then
        _G.KAIZEN_TWO_STAGE_STOP()
    else
        confirm.Visible = true
    end
end)]]
    local bindStart, bindEnd = string.find(source, oldBinding, 1, true)
    assert(bindStart, "Could not locate original shutdown button binding")
    source = string.sub(source, 1, bindStart - 1)
        .. newBinding
        .. string.sub(source, bindEnd + 1)

    local chunk, compileError = loadstring(source)
    assert(type(chunk) == "function", "Original script compile failed: " .. tostring(compileError))
    chunk()
end)

if not originalOk then
    warn("[KAIZEN] Original script failed: " .. tostring(originalErr))
    return
end

task.wait(1)

local function make(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local red = Color3.fromRGB(145, 8, 35)
local dark = Color3.fromRGB(15, 12, 18)
local white = Color3.new(1, 1, 1)

local gui = Instance.new("ScreenGui")
gui.Name = "KAIZEN_CHAT_ADDON"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local alive = true
local coreStopped = false
gui.Destroying:Connect(function()
    alive = false
    if _G.KAIZEN_TWO_STAGE_STOP then
        _G.KAIZEN_TWO_STAGE_STOP = nil
    end
end)

-- Two-stage shutdown dialog, invoked by the original core menu's shutdown button.
local dialog = make("Frame", {
    Name = "KAIZEN_TWO_STAGE_CONFIRM",
    Size = UDim2.fromOffset(286, 154),
    Position = UDim2.new(0.5, -143, 0.5, -77),
    BackgroundColor3 = Color3.fromRGB(18, 12, 18),
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 100,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, dialog)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.8}, dialog)

local dialogText = make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 72),
    Position = UDim2.fromOffset(10, 8),
    BackgroundTransparency = 1,
    Text = "هل تريد إيقاف السكربت؟",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextWrapped = true,
    ZIndex = 101,
}, dialog)

local yesButton = make("TextButton", {
    Size = UDim2.new(0.43, 0, 0, 36),
    Position = UDim2.new(0.06, 0, 1, -46),
    BackgroundColor3 = Color3.fromRGB(155, 8, 38),
    Text = "نعم",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    ZIndex = 101,
}, dialog)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, yesButton)

local noButton = make("TextButton", {
    Size = UDim2.new(0.43, 0, 0, 36),
    Position = UDim2.new(0.51, 0, 1, -46),
    BackgroundColor3 = Color3.fromRGB(55, 48, 55),
    Text = "لا",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    ZIndex = 101,
}, dialog)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, noButton)

local dialogStage = 1
local function closeDialog()
    dialog.Visible = false
    dialogStage = 1
    dialogText.Text = "هل تريد إيقاف السكربت؟"
end

local function stopCore()
    if coreStopped then return end
    coreStopped = true
    local shutdown = _G.KAIZEN_SHUTDOWN
    if type(shutdown) == "function" then
        local ok, err = pcall(shutdown)
        if not ok then
            warn("[KAIZEN] Core shutdown error: " .. tostring(err))
        end
    else
        warn("[KAIZEN] Core shutdown function was not exported")
    end
end

_G.KAIZEN_TWO_STAGE_STOP = function()
    if not alive or coreStopped then return end
    dialogStage = 1
    dialogText.Text = "هل تريد إيقاف السكربت؟"
    dialog.Visible = true
end

yesButton.Activated:Connect(function()
    if dialogStage == 1 then
        dialogStage = 2
        dialogText.Text = "هل تريد إيقاف الشات والأعضاء أيضًا؟"
        return
    end

    -- Stage 2: Yes stops everything.
    stopCore()
    closeDialog()
    if gui and gui.Parent then
        gui:Destroy()
    end
end)

noButton.Activated:Connect(function()
    if dialogStage == 1 then
        -- Stage 1: No cancels without changing anything.
        closeDialog()
        return
    end

    -- Stage 2: No stops only the core script; chat/members stay active.
    stopCore()
    closeDialog()
end)

-- Floating buttons share one draggable holder.
local holder = make("Frame", {
    Name = "KAIZEN_FLOATING_BUTTONS",
    Size = UDim2.fromOffset(122, 88),
    Position = UDim2.new(1, -136, 0.58, 0),
    BackgroundTransparency = 1,
    Active = true,
}, gui)

local launcher = make("TextButton", {
    Name = "KAIZEN_CHAT_BUTTON",
    Size = UDim2.fromOffset(116, 42),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = red,
    Text = "KAIZEN CHAT",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = true,
    Active = true,
}, holder)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, launcher)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.5}, launcher)

local membersButton = make("TextButton", {
    Name = "KAIZEN_MEMBERS_BUTTON",
    Size = UDim2.fromOffset(116, 36),
    Position = UDim2.fromOffset(0, 47),
    BackgroundColor3 = Color3.fromRGB(65, 8, 22),
    Text = "عرض الأعضاء",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = true,
    Active = true,
}, holder)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, membersButton)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.2}, membersButton)

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
makeDraggable(holder, launcher)

-- Original KAIZEN menu: dance button and one toggle for both floating buttons.
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local originalGui = playerGui:WaitForChild("KAIZEN_SHADOW_V3", 8)
local originalMain = originalGui and originalGui:FindFirstChild("Main")
local originalScroll = originalMain and originalMain:FindFirstChildWhichIsA("ScrollingFrame")

if originalScroll then
    local danceButton = make("TextButton", {
        Name = "KAIZEN_DANCES_BUTTON",
        LayoutOrder = 99999,
        Size = UDim2.new(1, -8, 0, 38),
        BackgroundColor3 = Color3.fromRGB(65, 8, 22),
        TextColor3 = white,
        Text = "رقصات",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        AutoButtonColor = true,
    }, originalScroll)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, danceButton)
    make("UIStroke", {Color = Color3.fromRGB(150, 15, 40), Thickness = 1}, danceButton)

    local danceBusy = false
    danceButton.Activated:Connect(function()
        if danceBusy or not alive then return end
        danceBusy = true
        task.spawn(function()
            local ok, err = pcall(function()
                local source = game:HttpGet(DANCE_URL)
                local loader, compileError = loadstring(source)
                assert(type(loader) == "function", tostring(compileError or "تعذر تحميل سكربت الرقصات"))
                loader()
            end)
            if not ok then warn("[KAIZEN] Dance loader failed: " .. tostring(err)) end
            task.wait(1)
            danceBusy = false
        end)
    end)

    local toggleButton = make("TextButton", {
        Name = "KAIZEN_FLOATING_TOGGLE",
        LayoutOrder = 100000,
        Size = UDim2.new(1, -8, 0, 38),
        BackgroundColor3 = red,
        Text = "إخفاء أزرار الشات والأعضاء",
        TextColor3 = white,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    }, originalScroll)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, toggleButton)
    make("UIStroke", {Color = Color3.fromRGB(150, 15, 40), Thickness = 1}, toggleButton)

    local hidden = false
    toggleButton.Activated:Connect(function()
        hidden = not hidden
        holder.Visible = not hidden
        toggleButton.Text = hidden
            and "إظهار أزرار الشات والأعضاء"
            or "إخفاء أزرار الشات والأعضاء"
    end)
else
    warn("[KAIZEN] Original menu not found; dance/toggle buttons were not inserted")
end

-- Chat window.
local panel = make("Frame", {
    Name = "KAIZEN_CHAT_WINDOW",
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
    TextColor3 = white,
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local close = make("TextButton", {
    Size = UDim2.fromOffset(30, 28),
    Position = UDim2.new(1, -35, 0, 5),
    BackgroundColor3 = red,
    Text = "×",
    TextColor3 = white,
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
    TextColor3 = white,
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
    TextColor3 = white,
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
        Text = tostring(item.sender_id or item.username or "مستخدم") .. ": " .. tostring(item.message or ""),
        TextColor3 = Color3.fromRGB(255, 235, 240),
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, messagesFrame)
    make("UICorner", {CornerRadius = UDim.new(0, 5)}, label)
    task.defer(function()
        if messagesFrame.Parent then
            messagesFrame.CanvasPosition = Vector2.new(0, math.max(0, messagesFrame.AbsoluteCanvasSize.Y))
        end
    end)
end

local function sendMessage()
    if sending or not alive then return end
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
        if not alive then return end
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

-- Independent members window with JOIN.
local membersPanel = make("Frame", {
    Name = "KAIZEN_MEMBERS_WINDOW",
    Size = UDim2.fromOffset(270, 320),
    Position = UDim2.new(0.5, -135, 0.5, -160),
    BackgroundColor3 = dark,
    BorderSizePixel = 0,
    Visible = false,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, membersPanel)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.7}, membersPanel)

local membersTitle = make("TextLabel", {
    Size = UDim2.new(1, -45, 0, 36),
    Position = UDim2.fromOffset(10, 4),
    BackgroundTransparency = 1,
    Text = "KAIZEN • الأعضاء النشطون",
    TextColor3 = white,
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Active = true,
}, membersPanel)

local membersClose = make("TextButton", {
    Size = UDim2.fromOffset(30, 28),
    Position = UDim2.new(1, -36, 0, 5),
    BackgroundColor3 = red,
    Text = "×",
    TextColor3 = white,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
}, membersPanel)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, membersClose)
membersClose.Activated:Connect(function() membersPanel.Visible = false end)

local membersStatus = make("TextLabel", {
    Size = UDim2.new(1, -16, 0, 22),
    Position = UDim2.fromOffset(8, 40),
    BackgroundTransparency = 1,
    Text = "جارٍ تحميل الأعضاء...",
    TextColor3 = Color3.fromRGB(255, 125, 145),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, membersPanel)

local membersList = make("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -76),
    Position = UDim2.fromOffset(8, 66),
    BackgroundColor3 = Color3.fromRGB(24, 19, 25),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
}, membersPanel)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, membersList)
make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, membersList)
make("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
}, membersList)

membersButton.Activated:Connect(function()
    membersPanel.Visible = not membersPanel.Visible
end)
makeDraggable(membersPanel, membersTitle)

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
            count += 1
            local row = make("Frame", {
                Name = "MemberRow_" .. count,
                Size = UDim2.new(1, -4, 0, 48),
                BackgroundColor3 = Color3.fromRGB(42, 24, 32),
                BorderSizePixel = 0,
                LayoutOrder = count,
            }, membersList)
            make("UICorner", {CornerRadius = UDim.new(0, 6)}, row)

            make("TextLabel", {
                Size = UDim2.new(1, -75, 1, 0),
                Position = UDim2.fromOffset(7, 0),
                BackgroundTransparency = 1,
                Text = username,
                TextColor3 = white,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, row)

            local joinButton = make("TextButton", {
                Size = UDim2.fromOffset(60, 30),
                Position = UDim2.new(1, -66, 0.5, -15),
                BackgroundColor3 = Color3.fromRGB(20, 115, 65),
                Text = "JOIN",
                TextColor3 = white,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
            }, row)
            make("UICorner", {CornerRadius = UDim.new(0, 6)}, joinButton)

            joinButton.Activated:Connect(function()
                local numericPlaceId = tonumber(placeId)
                if not numericPlaceId or jobId == "" then
                    membersStatus.Text = "بيانات سيرفر العضو غير متاحة"
                    return
                end
                membersStatus.Text = "جارٍ الانضمام إلى " .. username
                joinButton.Text = "..."
                local teleportOk, teleportError = pcall(function()
                    TeleportService:TeleportToPlaceInstance(numericPlaceId, jobId, LocalPlayer)
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

-- Register once, then poll messages/members and send presence heartbeat.
task.spawn(function()
    if not http then
        status.Text = "المشغّل لا يدعم طلبات HTTP"
        membersStatus.Text = "المشغّل لا يدعم HTTP"
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
        membersStatus.Text = "تعذر التسجيل في النظام"
        return
    end

    task.spawn(function()
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
            task.wait(0.5)
        end
    end)

    task.spawn(function()
        while alive and gui.Parent do
            local success, heartbeatError = pcall(function()
                apiCall("POST", "/heartbeat", {
                    userId = tostring(LocalPlayer.UserId),
                    username = tostring(LocalPlayer.Name),
                    placeId = tostring(game.PlaceId),
                    jobId = tostring(game.JobId),
                })
            end)
            if not success then
                warn("[KAIZEN] Heartbeat error: " .. tostring(heartbeatError))
            end
            task.wait(5)
        end
    end)

    task.spawn(function()
        while alive and gui.Parent do
            refreshMembers()
            task.wait(5)
        end
    end)
end)

print("[KAIZEN] Chat + Members + Two-stage shutdown loaded")

end
-- Start gate: nothing in the core/chat/members addon starts until Start is pressed.
local gateGui = Instance.new("ScreenGui")
gateGui.Name = "KAIZEN_START_GATE"
gateGui.ResetOnSpawn = false
gateGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gateGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local gateFrame = Instance.new("Frame")
gateFrame.Name = "StartFrame"
gateFrame.Size = UDim2.fromOffset(260, 150)
gateFrame.Position = UDim2.new(0.5, -130, 0.5, -75)
gateFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 18)
gateFrame.BorderSizePixel = 0
gateFrame.Parent = gateGui

local gateCorner = Instance.new("UICorner")
gateCorner.CornerRadius = UDim.new(0, 14)
gateCorner.Parent = gateFrame

local gateStroke = Instance.new("UIStroke")
gateStroke.Color = Color3.fromRGB(235, 25, 65)
gateStroke.Thickness = 2
gateStroke.Parent = gateFrame

local gateTitle = Instance.new("TextLabel")
gateTitle.Size = UDim2.new(1, -20, 0, 48)
gateTitle.Position = UDim2.fromOffset(10, 12)
gateTitle.BackgroundTransparency = 1
gateTitle.Text = "KAIZEN SHADOW V3"
gateTitle.TextColor3 = Color3.new(1, 1, 1)
gateTitle.Font = Enum.Font.GothamBlack
gateTitle.TextSize = 19
gateTitle.Parent = gateFrame

local gateSubtitle = Instance.new("TextLabel")
gateSubtitle.Size = UDim2.new(1, -20, 0, 24)
gateSubtitle.Position = UDim2.fromOffset(10, 56)
gateSubtitle.BackgroundTransparency = 1
gateSubtitle.Text = "اضغط ابدأ لتشغيل السكربت والشات والأعضاء"
gateSubtitle.TextColor3 = Color3.fromRGB(220, 190, 200)
gateSubtitle.Font = Enum.Font.Gotham
gateSubtitle.TextSize = 11
gateSubtitle.Parent = gateFrame

local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(1, -36, 0, 42)
startButton.Position = UDim2.new(0, 18, 1, -54)
startButton.BackgroundColor3 = Color3.fromRGB(145, 8, 35)
startButton.Text = "ابدأ"
startButton.TextColor3 = Color3.new(1, 1, 1)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 16
startButton.Parent = gateFrame

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 9)
startCorner.Parent = startButton

local started = false
startButton.Activated:Connect(function()
    if started then return end
    started = true
    startButton.Text = "جارٍ التشغيل..."
    startButton.Active = false

    task.spawn(function()
        local ok, err = pcall(function()
            gateGui:Destroy()
            __KAIZEN_START_RUNTIME__()
        end)
        if not ok then
            warn("[KAIZEN] Startup failed: " .. tostring(err))
            if gateGui.Parent then
                gateFrame.Visible = true
                startButton.Text = "فشل التشغيل"
                startButton.Active = true
            end
        end
    end)
end)
