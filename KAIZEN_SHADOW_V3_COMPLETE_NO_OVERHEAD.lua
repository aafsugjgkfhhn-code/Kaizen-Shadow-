--[[
KAIZEN SHADOW V3 - NO OVERHEAD CHAT BUBBLES
This wrapper loads the current COMPLETE_START_CHAT_JOIN loader,
removes only the overhead-bubble insertion block in memory,
then runs the patched loader.
All other features remain as in the source loader.
]]

local SOURCE_URL = "https://raw.githubusercontent.com/aafsugjgkfhhn-code/Kaizen-Shadow-/refs/heads/main/KAIZEN_SHADOW_V3_COMPLETE_START_CHAT_JOIN.lua"

local ok, result = pcall(function()
    local source = game:HttpGet(SOURCE_URL)
    assert(type(source) == "string" and #source > 0, "Could not download KAIZEN loader")

    local startMarker = "    -- Add a client-only overhead bubble."
    local endMarker = "    -- Export the original local shutdown function immediately after its"

    local startPos = string.find(source, startMarker, 1, true)
    assert(startPos, "Overhead bubble block start was not found")

    local endPos = string.find(source, endMarker, startPos, true)
    assert(endPos, "Overhead bubble block end was not found")

    source = string.sub(source, 1, startPos - 1)
        .. string.sub(source, endPos)

    -- Update the file description so it no longer claims overhead bubbles.
    source = string.gsub(
        source,
        "%- Overhead chat bubbles are client%-side: visible to users running this script\n%-%s+when the sender is in the same Roblox server%.",
        "- Overhead chat bubbles are disabled."
    )

    local loader, compileError = loadstring(source)
    assert(type(loader) == "function", "Patched loader compilation failed: " .. tostring(compileError))
    loader()
end)

if not ok then
    warn("[KAIZEN NO-BUBBLES] " .. tostring(result))
end
