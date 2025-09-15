-- AutoChestMain.lua
-- Purpose: local auto-collector that collects chests in folders named in folderNames
-- Intended to be executed client-side (LocalScript or via executor loader)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- CONFIG: change folder names if your game uses different names
local folderNames = {"Chests","Chests2","Chests3","Chests4"}
local TELEPORT_FALLBACK = false        -- set true to briefly teleport to chest if touch fails
local TELEPORT_OFFSET = Vector3.new(0, 3, 0)
local RETRIES = 3
local RETRY_DELAY = 0.06

local hrpOrHead = nil

-- Bind to character and pick HRP (or Head)
local function bindCharacter(char)
    if not char then return end
    hrpOrHead = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not hrpOrHead then
        hrpOrHead = char:WaitForChild("HumanoidRootPart", 5) or char:WaitForChild("Head", 5)
    end
    if hrpOrHead then
        print("[AutoChestMain] Bound to:", hrpOrHead:GetFullName())
    else
        warn("[AutoChestMain] Could not find HumanoidRootPart/Head on character")
    end
end

if player and player.Character then
    bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

-- Get a usable BasePart from a Model or return the part directly
local function getBasePart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart and obj.PrimaryPart:IsA("BasePart") then return obj.PrimaryPart end
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
    end
    return nil
end

-- Try ProximityPrompt if present
local function tryProximityPrompt(obj)
    if not obj then return false end
    local prompt = obj:FindFirstChildOfClass("ProximityPrompt") or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then
        local ok, err = pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.12)
            prompt:InputHoldEnd()
        end)
        if not ok then warn("[AutoChestMain] ProximityPrompt error:", err) end
        return ok
    end
    return false
end

-- Simulate touch safely
local function simulateTouch(part)
    if not part or not hrpOrHead then return false end
    for i = 1, RETRIES do
        local ok, err = pcall(function()
            firetouchinterest(hrpOrHead, part, 0)
            task.wait(0.03)
            firetouchinterest(hrpOrHead, part, 1)
        end)
        if ok then return true end
        warn("[AutoChestMain] firetouchinterest attempt", i, "failed:", err)
        task.wait(RETRY_DELAY)
    end
    return false
end

-- Teleport fallback
local function teleportTouch(part)
    if not part or not hrpOrHead then return false end
    local ok, err = pcall(function()
        local old = hrpOrHead.CFrame
        hrpOrHead.CFrame = part.CFrame + TELEPORT_OFFSET
        task.wait(0.06)
        firetouchinterest(hrpOrHead, part, 0)
        task.wait(0.03)
        firetouchinterest(hrpOrHead, part, 1)
        task.wait(0.06)
        hrpOrHead.CFrame = old
    end)
    if not ok then warn("[AutoChestMain] teleportTouch error:", err) end
    return ok
end

-- Collect a single object
local function collectObject(obj)
    if not obj then return end
    if not hrpOrHead then
        warn("[AutoChestMain] HRP/Head not bound, waiting 0.2s")
        task.wait(0.2)
    end
    local part = getBasePart(obj)
    if not part then
        warn("[AutoChestMain] No base part for", obj:GetFullName())
        return
    end

    print("[AutoChestMain] Collecting:", obj:GetFullName(), "-> part:", part:GetFullName())

    if tryProximityPrompt(obj) then
        print("[AutoChestMain] Collected via ProximityPrompt:", obj.Name)
        return
    end

    if simulateTouch(part) then
        print("[AutoChestMain] Collected via touch:", part:GetFullName())
        return
    end

    if TELEPORT_FALLBACK and teleportTouch(part) then
        print("[AutoChestMain] Collected via teleport-touch:", part:GetFullName())
        return
    end

    warn("[AutoChestMain] Failed to collect:", obj:GetFullName())
end

-- Collect all children in a given folder
local function collectFromFolder(folder)
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        collectObject(child)
    end
end

-- Set listeners and run initial pass
for _, name in ipairs(folderNames) do
    local folder = Workspace:FindFirstChild(name)
    if not folder then
        warn("[AutoChestMain] Folder not found:", name)
    else
        -- initial pass
        collectFromFolder(folder)
        -- collect on spawn
        folder.ChildAdded:Connect(function(ch)
            task.wait(0.12)
            collectObject(ch)
        end)
    end
end

-- Re-run a scan when the character spawns (so HRP is bound)
player.CharacterAdded:Connect(function()
    task.wait(0.4)
    for _, name in ipairs(folderNames) do
        local folder = Workspace:FindFirstChild(name)
        if folder then collectFromFolder(folder) end
    end
end)

print("[AutoChestMain] Auto-collector loaded.")
