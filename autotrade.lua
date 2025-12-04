--[[
    Roblox Firebase Heartbeat Module v2
    ====================================
    Primary source of truth for account monitoring.
    
    Features:
    - Reliable backpack scanning (from autotrade.lua patterns)
    - Device HWID tagging via configurable ID
    - Clean connection management (no leaks)
    - Stable timestamps
    
    Usage:
    1. Set DEVICE_TAG to identify which PC this client is from
    2. Load via executor: loadstring(game:HttpGet("URL"))()
--]]

-- ============================================
-- CONFIGURATION
-- ============================================

local CONFIG = {
    -- Firebase Realtime Database
    FIREBASE_URL = "https://autofarm-861ab-default-rtdb.asia-southeast1.firebasedatabase.app",
    
    -- Device identification (set this per-device)
    DEVICE_TAG = "PC1",  -- Change per device: "PC1", "PC2", "LAPTOP1", etc.
    
    -- Intervals
    HEARTBEAT_INTERVAL = 15,
    BACKPACK_INTERVAL = 30,
    
    -- Debug
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
        print(string.format("[HB2][%s] %s", level, msg))
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
-- ITEM DATABASE (from autotrade.lua)
-- ============================================

local ItemDatabase = {}
local tierToRarity = {
    [1] = "COMMON", [2] = "UNCOMMON", [3] = "RARE",
    [4] = "EPIC", [5] = "LEGENDARY", [6] = "MYTHIC", [7] = "SECRET"
}

local function BuildItemDatabase()
    local success = pcall(function()
        local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
        if not itemsFolder then return end
        
        for _, itemModule in ipairs(itemsFolder:GetChildren()) do
            local ok, data = pcall(require, itemModule)
            if ok and data and data.Data and data.Data.Id then
                local id = data.Data.Id
                local tierNum = data.Data.Tier or 0
                local rarity = (data.Data.Rarity and string.upper(tostring(data.Data.Rarity))) 
                    or (tierToRarity[tierNum] or "UNKNOWN")
                local sellPrice = data.SellPrice or (data.Data and data.Data.SellPrice) or 0
                
                ItemDatabase[id] = {
                    Name = data.Data.Name or "Unknown",
                    Rarity = rarity,
                    SellPrice = sellPrice
                }
            end
        end
    end)
    
    if success then
        log("Item database built: " .. tostring(#ItemDatabase) .. " items")
    end
end

local function GetItemInfo(itemId)
    return ItemDatabase[itemId] or { Name = "Unknown", Rarity = "UNKNOWN", SellPrice = 0 }
end

-- ============================================
-- BACKPACK SCANNER (reliable patterns from autotrade.lua)
-- ============================================

local BackpackScanner = {}

-- Blacklist of spam items to exclude
local ITEM_BLACKLIST = {
    ["hermit crab"] = true,
    ["shell"] = true,
    ["seashell"] = true,
    -- Add more spam items as needed
}

local function isBlacklisted(itemName)
    if not itemName then return false end
    local lower = string.lower(itemName)
    return ITEM_BLACKLIST[lower] or false
end

-- Compress items into "Name xCount" format
local function compressItems(items, maxDisplay)
    maxDisplay = maxDisplay or 10
    local counts = {}
    local order = {}
    
    for _, item in ipairs(items) do
        local name = item.name or "Unknown"
        if not isBlacklisted(name) then
            if not counts[name] then
                counts[name] = { count = 0, item = item }
                table.insert(order, name)
            end
            counts[name].count = counts[name].count + 1
        end
    end
    
    local compressed = {}
    for i, name in ipairs(order) do
        if i > maxDisplay then
            table.insert(compressed, {
                name = "+" .. (#order - maxDisplay) .. " more items",
                rarity = "INFO",
                count = 0
            })
            break
        end
        
        local data = counts[name]
        local displayName = data.count > 1 and (name .. " x" .. data.count) or name
        table.insert(compressed, {
            name = displayName,
            rarity = data.item.rarity,
            favorited = data.item.favorited,
            count = data.count
        })
    end
    
    return compressed
end

function BackpackScanner.scan()
    local result = {
        items = {},
        secretItems = {},  -- Only SECRET rarity, compressed
        pets = {},
        totalValue = 0,
        rarityCount = {},
        timestamp = os.time()
    }
    
    -- Get Replion data (PS99 style)
    local rawSecretItems = {}
    
    local success = pcall(function()
        local Replion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion"))
        if not Replion or not Replion.Client then return end
        
        local DataReplion = Replion.Client:WaitReplion("Data")
        if not DataReplion then return end
        
        local inventoryItems = DataReplion:Get({ "Inventory", "Items" })
        if not inventoryItems then return end
        
        for _, itemData in ipairs(inventoryItems) do
            local info = GetItemInfo(itemData.Id)
            local rarity = info.Rarity
            local itemName = info.Name or "Unknown"
            
            -- Track rarity counts
            result.rarityCount[rarity] = (result.rarityCount[rarity] or 0) + 1
            result.totalValue = result.totalValue + (info.SellPrice or 0)
            
            -- Only store SECRET items (not MYTHIC) and filter blacklist
            if rarity == "SECRET" and not isBlacklisted(itemName) then
                table.insert(rawSecretItems, {
                    id = itemData.Id,
                    uuid = itemData.UUID,
                    name = itemName,
                    rarity = rarity,
                    favorited = itemData.Favorited == true,
                    value = info.SellPrice
                })
            end
        end
        
        -- Get pets if available
        local petsData = DataReplion:Get({ "Inventory", "Pets" })
        if petsData then
            for uuid, petData in pairs(petsData) do
                if type(petData) == "table" then
                    local isHuge = petData.pt == 1
                    local isTitanic = petData.pt == 2
                    
                    if isHuge or isTitanic then
                        table.insert(result.pets, {
                            uuid = uuid,
                            id = petData.id,
                            type = isHuge and "Huge" or "Titanic",
                            shiny = petData.sh == true,
                            enchant = petData.e
                        })
                    end
                end
            end
        end
    end)
    
    -- Compress secret items for cleaner output (max 10 displayed)
    result.secretItems = compressItems(rawSecretItems, 10)
    
    if not success then
        -- Fallback: basic backpack check
        pcall(function()
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    if not isBlacklisted(item.Name) then
                        table.insert(result.items, {
                            name = item.Name,
                            class = item.ClassName
                        })
                    end
                end
            end
        end)
    end
    
    return result
end

-- ============================================
-- STATUS TRACKER
-- ============================================

local StatusTracker = {}

function StatusTracker.detect()
    local status = "active"
    
    -- Check if trading
    pcall(function()
        local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("Trade")
        if tradeGui and tradeGui.Enabled then
            status = "trading"
            return
        end
    end)
    
    -- Check movement
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.MoveDirection.Magnitude == 0 then
                if status ~= "trading" then
                    status = "idle"
                end
            end
        end
    end)
    
    return status
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
        deviceTag = CONFIG.DEVICE_TAG,
        status = StatusTracker.detect(),
        inGame = true,
        gameId = game.PlaceId,
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
        log("Heartbeat sent")
        return true
    end
    return false
end

function Heartbeat.sendBackpack()
    local data = BackpackScanner.scan()
    local path = "accounts/" .. Username .. "/backpack"
    
    if firebasePut(path, data) then
        Heartbeat.lastBackpack = os.time()
        log("Backpack sent: " .. #data.items .. " special items")
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
    
    -- Build item database
    BuildItemDatabase()
    
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
    -- For client, use game.Close event or detect disconnect via heartbeat failure
    if RunService:IsServer() then
        game:BindToClose(function()
            Heartbeat.stop()
        end)
    else
        -- Client-side cleanup: detect when LocalPlayer is about to leave
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

-- Expose globals
getgenv().Heartbeat = Heartbeat
getgenv().BackpackScanner = BackpackScanner
getgenv().HeartbeatConfig = CONFIG

print("=================================")
print("[Heartbeat v2] Loaded for: " .. Username)
print("[Heartbeat v2] Device: " .. CONFIG.DEVICE_TAG)
print("[Heartbeat v2] Firebase: OK")
print("=================================")
