--[[
KAIZEN SHADOW V3 - START GATE + REAL STOP + FAST CHAT + MEMBERS + JOIN
- Nothing loads until the user presses START.
- Original core shutdownScript is exported and called for real shutdown.
- Stop flow: first confirmation, then chat/members confirmation.
- Chat polling: 0.5 seconds.
- Members refresh: 5 seconds.
- Heartbeat: 5 seconds.
- Chat text size increased.
- Overhead chat bubbles are client-side: visible to users running this script
  when the sender is in the same Roblox server.
- JOIN uses each member's own PlaceId + JobId.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

_G.KAIZEN_SHUTDOWN = nil

local MEMBERS_URL =
    "https://raw.githubusercontent.com/aafsugjgkfhhn-code/Kaizen-Shadow-/refs/heads/main/KAIZEN_SHADOW_V3_CHAT_MEMBERS.lua"

local function replaceOnce(source, oldText, newText, label)
    local first, last = string.find(source, oldText, 1, true)
    assert(first, "Patch point not found: " .. tostring(label or oldText))
    return string.sub(source, 1, first - 1)
        .. newText
        .. string.sub(source, last + 1)
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local RED = Color3.fromRGB(145, 8, 35)
local DARK = Color3.fromRGB(15, 12, 18)
local WHITE = Color3.new(1, 1, 1)

local gateGui = make("ScreenGui", {
    Name = "KAIZEN_START_AND_CONTROL",
    ResetOnSpawn = false,
    DisplayOrder = 10000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local welcome = make("Frame", {
    Name = "WelcomePanel",
    Size = UDim2.fromOffset(310, 205),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = DARK,
    BorderSizePixel = 0,
}, gateGui)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, welcome)
make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.5}, welcome)

make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 45),
    Position = UDim2.fromOffset(10, 12),
    BackgroundTransparency = 1,
    Text = "KAIZEN SHADOW V3",
    TextColor3 = WHITE,
    Font = Enum.Font.GothamBlack,
    TextSize = 21,
}, welcome)

make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 38),
    Position = UDim2.fromOffset(12, 61),
    BackgroundTransparency = 1,
    Text = "أهلاً بك في KAIZEN SHADOW",
    TextColor3 = Color3.fromRGB(225, 190, 200),
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextWrapped = true,
}, welcome)

local status = make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 22),
    Position = UDim2.fromOffset(10, 105),
    BackgroundTransparency = 1,
    Text = "جاهز للتشغيل",
    TextColor3 = Color3.fromRGB(255, 120, 145),
    Font = Enum.Font.Gotham,
    TextSize = 12,
}, welcome)

local startButton = make("TextButton", {
    Size = UDim2.new(1, -40, 0, 43),
    Position = UDim2.fromOffset(20, 145),
    BackgroundColor3 = RED,
    Text = "ابدأ",
    TextColor3 = WHITE,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
}, welcome)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, startButton)

local function showConfirm(message, callback)
    local shade = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35,
        ZIndex = 100,
    }, gateGui)

    local box = make("Frame", {
        Size = UDim2.fromOffset(292, 148),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = DARK,
        BorderSizePixel = 0,
        ZIndex = 101,
    }, shade)
    make("UICorner", {CornerRadius = UDim.new(0, 12)}, box)
    make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.5}, box)

    make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 72),
        Position = UDim2.fromOffset(10, 7),
        BackgroundTransparency = 1,
        Text = message,
        TextColor3 = WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextWrapped = true,
        ZIndex = 102,
    }, box)

    local yes = make("TextButton", {
        Size = UDim2.fromOffset(112, 38),
        Position = UDim2.fromOffset(20, 98),
        BackgroundColor3 = RED,
        Text = "نعم",
        TextColor3 = WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        ZIndex = 102,
    }, box)
    make("UICorner", {CornerRadius = UDim.new(0, 7)}, yes)

    local no = make("TextButton", {
        Size = UDim2.fromOffset(112, 38),
        Position = UDim2.new(1, -132, 0, 98),
        BackgroundColor3 = Color3.fromRGB(65, 60, 68),
        Text = "لا",
        TextColor3 = WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        ZIndex = 102,
    }, box)
    make("UICorner", {CornerRadius = UDim.new(0, 7)}, no)

    local answered = false
    local function finish(value)
        if answered then return end
        answered = true
        shade:Destroy()
        callback(value)
    end
    yes.Activated:Connect(function() finish(true) end)
    no.Activated:Connect(function() finish(false) end)
end

local function installStopButton()
    local coreGui = PlayerGui:WaitForChild("KAIZEN_SHADOW_V3", 15)
    assert(coreGui, "Original KAIZEN interface was not created")

    local main = coreGui:FindFirstChild("Main", true)
    assert(main, "Original main menu was not found")

    local scroll = main:FindFirstChildWhichIsA("ScrollingFrame", true)
    assert(scroll, "Main menu scrolling frame was not found")

    local oldStop = main:FindFirstChild("PermanentShutdownButton", true)
    if oldStop and oldStop:IsA("GuiObject") then
        oldStop.Visible = false
    end

    local oldConfirm = coreGui:FindFirstChild("ShutdownConfirm", true)
    if oldConfirm and oldConfirm:IsA("GuiObject") then
        oldConfirm.Visible = false
    end

    local stopButton = make("TextButton", {
        Name = "KAIZEN_STOP_SCRIPT",
        LayoutOrder = 100002,
        Size = UDim2.new(1, -8, 0, 38),
        BackgroundColor3 = RED,
        Text = "إيقاف السكربت",
        TextColor3 = WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
    }, scroll)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, stopButton)
    make("UIStroke", {Color = Color3.fromRGB(235, 25, 65), Thickness = 1.2}, stopButton)

    stopButton.Activated:Connect(function()
        showConfirm("هل تريد إيقاف السكربت؟", function(firstAnswer)
            if not firstAnswer then
                return
            end

            showConfirm("هل تريد إيقاف الشات والأعضاء أيضًا؟", function(stopChat)
                local shutdown = _G.KAIZEN_SHUTDOWN
                if type(shutdown) ~= "function" then
                    warn("[KAIZEN] Original shutdown function is unavailable")
                    return
                end

                local stopped, shutdownError = pcall(shutdown)
                if not stopped then
                    warn("[KAIZEN] Shutdown error: " .. tostring(shutdownError))
                end

                if stopChat then
                    local chatGui = PlayerGui:FindFirstChild("KAIZEN_CHAT_ADDON")
                    if chatGui then
                        chatGui:Destroy()
                    end
                end
                -- If stopChat is false, chat + members + their heartbeat
                -- remain active. The original core is still shut down.
            end)
        end)
    end)
end

local function patchMembersSource(source)
    -- Faster member list and heartbeat, with exact single-match checks.
    source = replaceOnce(source, "task.wait(30)", "task.wait(5)", "heartbeat interval")
    source = replaceOnce(source, "task.wait(10)", "task.wait(5)", "members refresh interval")

    -- Capture the destination values on each JOIN button, then use those
    -- values rather than accidentally reading the local player's place/job.
    local oldJoin = [[
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
]]
    local newJoin = [[
            joinButton:SetAttribute("KAIZEN_TargetPlaceId", tostring(placeId))
            joinButton:SetAttribute("KAIZEN_TargetJobId", tostring(jobId))

            joinButton.Activated:Connect(function()
                local numericPlaceId = tonumber(
                    joinButton:GetAttribute("KAIZEN_TargetPlaceId")
                )
                local targetJobId = tostring(
                    joinButton:GetAttribute("KAIZEN_TargetJobId") or ""
                )

                if not numericPlaceId or targetJobId == "" then
                    membersStatus.Text = "بيانات سيرفر العضو غير متاحة"
                    return
                end

                if numericPlaceId == game.PlaceId and targetJobId == game.JobId then
                    membersStatus.Text = "اللاعب موجود في نفس سيرفرك"
                    return
                end

                membersStatus.Text = "جارٍ الانضمام إلى " .. username
                joinButton.Text = "..."
                local teleportOk, teleportError = pcall(function()
                    TeleportService:TeleportToPlaceInstance(
                        numericPlaceId,
                        targetJobId,
                        LocalPlayer
                    )
                end)

                if not teleportOk then
                    membersStatus.Text = "تعذر الانضمام: " .. tostring(teleportError)
                    joinButton.Text = "JOIN"
                    warn("[KAIZEN] Join error: " .. tostring(teleportError))
                end
            end)
]]
    source = replaceOnce(source, oldJoin, newJoin, "JOIN handler")

    -- Replace the nested dance loader with a patched version. The original
    -- core source gets a reference to its own real shutdownScript function.
    local oldLoaderBlock = [[
    local source = game:HttpGet(LOADER_URL)
    local loader = loadstring(source)
    assert(type(loader) == "function", "Loader compilation failed")
    loader()
]]
    local newLoaderBlock = [==[
    local source = game:HttpGet(LOADER_URL)

    local function patchOne(text, oldText, newText, label)
        local a, b = string.find(text, oldText, 1, true)
        assert(a, "Patch point not found: " .. tostring(label))
        return string.sub(text, 1, a - 1) .. newText .. string.sub(text, b + 1)
    end

    -- Chat receive polling: 4 seconds -> 0.5 seconds.
    source = patchOne(source, "task.wait(4)", "task.wait(0.5)", "chat polling interval")

    -- Increase the chat message text size from 12 to 15.
    local oldMessageFont = [[Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,]]
    local newMessageFont = [[Font = Enum.Font.Gotham,
        TextSize = 15,
        TextWrapped = true,]]
    source = patchOne(source, oldMessageFont, newMessageFont, "chat message font")

    -- Add a client-only overhead bubble. Each script user renders it locally
    -- for senders present in the same Roblox server.
    local bubbleAnchor = 'make("UICorner", {CornerRadius = UDim.new(0, 5)}, label)'
    local bubbleCode = [=[
make("UICorner", {CornerRadius = UDim.new(0, 5)}, label)

local senderName = tostring(item.sender_id or "")
local senderPlayer = Players:FindFirstChild(senderName)
if senderPlayer then
    task.spawn(function()
        local character = senderPlayer.Character or senderPlayer.CharacterAdded:Wait()
        local head = character and (
            character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
        )

        if head and head.Parent then
            local bubble = Instance.new("BillboardGui")
            bubble.Name = "KAIZEN_CHAT_BUBBLE_" .. tostring(id)
            bubble.Adornee = head
            bubble.Size = UDim2.fromOffset(230, 58)
            bubble.StudsOffset = Vector3.new(0, 3.25, 0)
            bubble.AlwaysOnTop = true
            bubble.MaxDistance = 120
            bubble.Parent = LocalPlayer:WaitForChild("PlayerGui")

            local bubbleText = Instance.new("TextLabel")
            bubbleText.Size = UDim2.fromScale(1, 1)
            bubbleText.BackgroundColor3 = Color3.fromRGB(24, 15, 22)
            bubbleText.BackgroundTransparency = 0.12
            bubbleText.BorderSizePixel = 0
            bubbleText.Text = tostring(item.message or "")
            bubbleText.TextColor3 = Color3.fromRGB(255, 240, 245)
            bubbleText.Font = Enum.Font.GothamBold
            bubbleText.TextSize = 15
            bubbleText.TextWrapped = true
            bubbleText.TextScaled = false
            bubbleText.Parent = bubble

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 9)
            corner.Parent = bubbleText

            local outline = Instance.new("UIStroke")
            outline.Color = Color3.fromRGB(235, 25, 65)
            outline.Thickness = 1.2
            outline.Parent = bubbleText

            task.delay(5, function()
                if bubble and bubble.Parent then
                    bubble:Destroy()
                end
            end)
        end
    end)
end
]=]

    local bubbleStart, bubbleEnd = string.find(source, bubbleAnchor, 1, true)
    assert(bubbleStart, "Overhead chat insertion point not found")
    source = string.sub(source, 1, bubbleStart - 1)
        .. bubbleCode
        .. string.sub(source, bubbleEnd + 1)

    -- Export the original local shutdown function immediately after its
    -- definition, before the rest of the original script continues.
    local coreFetchLine = "local source = game:HttpGet(ORIGINAL_URL)"
    local coreFetchPatch = [[
    local source = game:HttpGet(ORIGINAL_URL)

    local shutdownMarker = "-- X only hides the panel; the floating anime-style toggle restores it."
    local shutdownPosition = string.find(source, shutdownMarker, 1, true)
    assert(shutdownPosition, "Original shutdown function marker not found")

    source = string.sub(source, 1, shutdownPosition - 1)
        .. "_G.KAIZEN_SHUTDOWN = shutdownScript\n"
        .. string.sub(source, shutdownPosition)
]]
    source = patchOne(source, coreFetchLine, coreFetchPatch, "core shutdown export")

    local danceLoader = loadstring(source)
    assert(type(danceLoader) == "function", "Patched chat/dance loader did not compile")
    danceLoader()
]==]
    source = replaceOnce(source, oldLoaderBlock, newLoaderBlock, "members nested loader")

    return source
end

local started = false
startButton.Activated:Connect(function()
    if started then return end
    started = true
    startButton.Active = false
    startButton.Text = "جارٍ التشغيل..."
    status.Text = "تحميل السكربت والشات والأعضاء..."

    task.spawn(function()
        local ok, err = pcall(function()
            local membersSource = game:HttpGet(MEMBERS_URL)
            assert(type(membersSource) == "string" and #membersSource > 0,
                "Members source is empty")

            membersSource = patchMembersSource(membersSource)

            local membersLoader = loadstring(membersSource)
            assert(type(membersLoader) == "function", "Patched members loader did not compile")
            membersLoader()

            task.wait(3)
            assert(type(_G.KAIZEN_SHUTDOWN) == "function",
                "Original shutdown function was not registered")

            installStopButton()
        end)

        if not ok then
            warn("[KAIZEN STARTUP ERROR] " .. tostring(err))
            status.Text = "فشل التشغيل - راجع سجل الأخطاء"
            startButton.Text = "حاول مرة أخرى"
            startButton.Active = true
            started = false
            return
        end

        status.Text = "تم تشغيل KAIZEN SHADOW"
        task.wait(0.8)
        if welcome and welcome.Parent then
            welcome:Destroy()
        end
    end)
end)

print("[KAIZEN] Start gate ready. Press START to load the script.")
