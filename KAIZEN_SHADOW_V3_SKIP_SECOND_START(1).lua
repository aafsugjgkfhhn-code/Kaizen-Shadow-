-- KAIZEN SHADOW V3 - Skip the second welcome/start screen
-- This bootstrap keeps the existing GitHub script and removes only the
-- inner welcome popup from the core script before it is compiled.

local WRAPPER_URL = "https://raw.githubusercontent.com/aafsugjgkfhhn-code/Kaizen-Shadow-/refs/heads/main/KAIZEN_SHADOW_V3_COMPLETE_CHAT_MEMBERS_TWO_STAGE.lua"

local ok, err = pcall(function()
    local wrapperSource = game:HttpGet(WRAPPER_URL)
    assert(type(wrapperSource) == "string" and #wrapperSource > 0, "Wrapper download failed")

    local needle = "    local chunk, compileError = loadstring(source)"
    local insertAt = string.find(wrapperSource, needle, 1, true)
    assert(insertAt, "Could not find the core compile point in the wrapper")

    local patch = [=[
    -- Remove the core's second welcome popup; the outer Start button is enough.
    local welcomeStart = string.find(
        source,
        "-- Arabic welcome message (shown once when the script starts)",
        1,
        true
    )
    assert(welcomeStart, "Could not find the core welcome screen")
    local welcomeEnd = string.find(source, "main.Visible = false", welcomeStart, true)
    assert(welcomeEnd, "Could not find the end of the core welcome screen")
    local welcomeEndAfter = welcomeEnd + #"main.Visible = false" - 1
    source = string.sub(source, 1, welcomeStart - 1)
        .. "main.Visible = true"
        .. string.sub(source, welcomeEndAfter + 1)
]=]

    wrapperSource =
        string.sub(wrapperSource, 1, insertAt - 1)
        .. patch .. "\n"
        .. string.sub(wrapperSource, insertAt)

    local loader, compileError = loadstring(wrapperSource)
    assert(type(loader) == "function", tostring(compileError or "Wrapper compile failed"))
    loader()
end)

if not ok then
    warn("[KAIZEN] Startup failed: " .. tostring(err))
end
