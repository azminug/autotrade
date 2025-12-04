--[[
    Roblox Firebase Heartbeat Module v3
    ====================================
    For Fish It! game monitoring.
    
    Features:
    - Simple inventory scanning for Fish It!
    - Device info comes from run.py (not hardcoded)
    - Clean connection management
    - Status: online when in game
    
    Usage:
    loadstring(game:HttpGet("URL"))()
--]]

-- ============================================
-- CONFIGURATION
-- ============================================

local CONFIG = {
    -- Firebase Realtime Database
    FIREBASE_URL = "https://autofarm-861ab-default-rtdb.asia-southeast1.firebasedatabase.app",
    
    -- Intervals (seconds)
    HEARTBEAT_INTERVAL = 15,
    BACKPACK_INTERVAL = 30,
    
    -- Debug mode
    DEBUG = false,
}

-- ============================================
-- SERVICES
-- ============================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Username = LocalPlayer and string.lower(LocalPlayer.Name) or "unknown"
local UserId = LocalPlayer and LocalPlayer.UserId or 0

-- ============================================
-- CONNECTION CLEANUP REGISTRY
-- ============================================

local Connections = {}

local function RegisterConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

local function CleanupConnections()
    for _, conn in ipairs(Connections) do
        pcall(function()
            if conn and conn.Disconnect then
                conn:Disconnect()
            end
        end)
    end
    Connections = {}
end

-- ============================================
-- UTILITY
-- ============================================

local function log(msg, level)
    level = level or "INFO"
    if CONFIG.DEBUG or level == "ERROR" or level == "WARN" then
        print(string.format("[HB][%s] %s", level, msg))
    end
end

local function httpRequest(url, method, body)
    local bodyStr = body and HttpService:JSONEncode(body) or nil
    
    local requestFunc = nil
    if syn and syn.request then
        requestFunc = syn.request
    elseif request then
        requestFunc = request
    elseif http_request then
        requestFunc = http_request
    elseif fluxus and fluxus.request then
        requestFunc = fluxus.request
    end
    
    if not requestFunc then
        log("No HTTP function available", "ERROR")
        return nil
    end
    
    local success, result = pcall(function()
        return requestFunc({
            Url = url,
            Method = method or "GET",
            Headers = {["Content-Type"] = "application/json"},
            Body = bodyStr
        })
    end)
    
    if success and result then
        return result
    else
        log("HTTP failed: " .. tostring(result), "ERROR")
        return nil
    end
end

local function firebasePatch(path, data)
    local url = CONFIG.FIREBASE_URL .. "/" .. path .. ".json"
    local result = httpRequest(url, "PATCH", data)
    return result and result.StatusCode == 200
end

local function firebasePut(path, data)
    local url = CONFIG.FIREBASE_URL .. "/" .. path .. ".json"
    local result = httpRequest(url, "PUT", data)
    return result and result.StatusCode == 200
end

-- ============================================
-- FISH IT! INVENTORY SCANNER
-- ============================================

local BackpackScanner = {}

-- Rarity tiers for Fish It!
local RARITY_ORDER = {"Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"}

-- Compress items: group by name and count
local function compressItems(items, maxDisplay)
    maxDisplay = maxDisplay or 10
    local counts = {}
    local order = {}
    
    for _, item in ipairs(items) do
        local name = item.name or "Unknown"
        if not counts[name] then
            counts[name] = { count = 0, item = item }
            table.insert(order, name)
        end
        counts[name].count = counts[name].count + 1
    end
    
    local compressed = {}
    for i, name in ipairs(order) do
        if i > maxDisplay then
            table.insert(compressed, {
                name = "+" .. (#order - maxDisplay) .. " more",
                rarity = "info",
                count = 0
            })
            break
        end
        
        local data = counts[name]
        local displayName = data.count > 1 and (name .. " x" .. data.count) or name
        table.insert(compressed, {
            name = displayName,
            rarity = data.item.rarity or "Common",
            count = data.count
        })
    end
    
    return compressed
end

function BackpackScanner.scan()
    local result = {
        items = {},
        secretItems = {},
        totalValue = 0,
        rarityCount = {},
        timestamp = os.time()
    }
    
    local rawSecretItems = {}
    
    -- Method 1: Try to get inventory from Fish It! data stores
    local success = pcall(function()
        -- Fish It! uses different data structure
        -- Try common patterns for fishing games
        
        -- Check for Inventory in PlayerGui or leaderstats
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        
        -- Try to find inventory folder in player
        local inventory = LocalPlayer:FindFirstChild("Inventory") 
            or LocalPlayer:FindFirstChild("Backpack")
            or LocalPlayer:FindFirstChild("Fish")
            or LocalPlayer:FindFirstChild("Items")
        
        if inventory then
            for _, item in ipairs(inventory:GetChildren()) do
                local itemName = item.Name
                local rarity = "Common"
                local value = 0
                
                -- Try to get rarity from attributes or value objects
                if item:GetAttribute("Rarity") then
                    rarity = item:GetAttribute("Rarity")
                elseif item:FindFirstChild("Rarity") then
                    rarity = tostring(item.Rarity.Value)
                end
                
                if item:GetAttribute("Value") then
                    value = tonumber(item:GetAttribute("Value")) or 0
                elseif item:FindFirstChild("Value") then
                    value = tonumber(item.Value.Value) or 0
                end
                
                -- Track rarity counts
                result.rarityCount[rarity] = (result.rarityCount[rarity] or 0) + 1
                result.totalValue = result.totalValue + value
                
                -- Store all items
                table.insert(result.items, {
                    name = itemName,
                    rarity = rarity,
                    value = value
                })
                
                -- Store secret items separately
                if string.lower(rarity) == "secret" then
                    table.insert(rawSecretItems, {
                        name = itemName,
                        rarity = rarity,
                        value = value
                    })
                end
            end
        end
        
        -- Alternative: Check ReplicatedStorage for game data
        local gameData = ReplicatedStorage:FindFirstChild("GameData")
            or ReplicatedStorage:FindFirstChild("Data")
            or ReplicatedStorage:FindFirstChild("FishData")
        
        if gameData then
            -- Try to find fish/item definitions
            local fishFolder = gameData:FindFirstChild("Fish") or gameData:FindFirstChild("Items")
            if fishFolder then
                log("Found game data folder: " .. fishFolder.Name)
            end
        end
    end)
    
    -- Method 2: Fallback - scan player's Backpack tool items
    if not success or #result.items == 0 then
        pcall(function()
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") then
                        table.insert(result.items, {
                            name = item.Name,
                            rarity = "Unknown",
                            value = 0
                        })
                    end
                end
            end
        end)
    end
    
    -- Compress secret items for display
    result.secretItems = compressItems(rawSecretItems, 10)
    
    return result
end

-- ============================================
-- HEARTBEAT MODULE
-- ============================================

local Heartbeat = {}
Heartbeat.running = false
Heartbeat.lastHeartbeat = 0
Heartbeat.lastBackpack = 0
Heartbeat.loopThread = nil

function Heartbeat.getInfo()
    local info = {
        username = Username,
        userId = UserId,
        displayName = LocalPlayer.DisplayName or Username,
        status = "online",  -- Always online when script is running
        inGame = true,
        gameId = game.PlaceId,
        gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Fish It!",
        serverId = game.JobId,
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    -- Position
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                info.position = {
                    x = math.floor(hrp.Position.X),
                    y = math.floor(hrp.Position.Y),
                    z = math.floor(hrp.Position.Z)
                }
            end
        end
    end)
    
    return info
end

function Heartbeat.sendHeartbeat()
    local info = Heartbeat.getInfo()
    local path = "accounts/" .. Username .. "/roblox"
    
    if firebasePatch(path, info) then
        Heartbeat.lastHeartbeat = os.time()
        log("Heartbeat sent - " .. Username)
        return true
    end
    return false
end

function Heartbeat.sendBackpack()
    local data = BackpackScanner.scan()
    local path = "accounts/" .. Username .. "/backpack"
    
    if firebasePut(path, data) then
        Heartbeat.lastBackpack = os.time()
        log("Backpack sent: " .. #data.items .. " items, " .. #data.secretItems .. " secret")
        return true
    end
    return false
end

function Heartbeat.start()
    if Heartbeat.running then
        log("Already running", "WARN")
        return
    end
    
    Heartbeat.running = true
    log("Starting heartbeat for " .. Username)
    
    -- Initial sync
    Heartbeat.sendHeartbeat()
    Heartbeat.sendBackpack()
    
    -- Main loop
    Heartbeat.loopThread = task.spawn(function()
        while Heartbeat.running do
            local now = os.time()
            
            -- Heartbeat
            if now - Heartbeat.lastHeartbeat >= CONFIG.HEARTBEAT_INTERVAL then
                Heartbeat.sendHeartbeat()
            end
            
            -- Backpack
            if now - Heartbeat.lastBackpack >= CONFIG.BACKPACK_INTERVAL then
                Heartbeat.sendBackpack()
            end
            
            task.wait(1)
        end
    end)
    
    -- Player leaving handler
    RegisterConnection(Players.PlayerRemoving:Connect(function(player)
        if player == LocalPlayer then
            Heartbeat.stop()
        end
    end))
    
    -- Game closing handler - BindToClose only works on server
    if RunService:IsServer() then
        game:BindToClose(function()
            Heartbeat.stop()
        end)
    else
        -- Client-side: detect teleport
        LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Started then
                Heartbeat.stop()
            end
        end)
    end
end

function Heartbeat.stop()
    if not Heartbeat.running then return end
    
    Heartbeat.running = false
    log("Stopping heartbeat")
    
    -- Update offline status
    firebasePatch("accounts/" .. Username .. "/roblox", {
        inGame = false,
        status = "offline",
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    -- Cleanup connections
    CleanupConnections()
    
    -- Cancel loop thread
    if Heartbeat.loopThread then
        pcall(function()
            task.cancel(Heartbeat.loopThread)
        end)
        Heartbeat.loopThread = nil
    end
end

-- ============================================
-- INITIALIZATION
-- ============================================

-- Wait for game to load
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2)

-- Start heartbeat
Heartbeat.start()

-- Expose globals for debugging
getgenv().Heartbeat = Heartbeat
getgenv().BackpackScanner = BackpackScanner

print("[HB] Fish It! Heartbeat started for: " .. Username)
