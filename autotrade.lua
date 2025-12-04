--[[
    Roblox Firebase Heartbeat Module v4
    ====================================
    Uses proven Replion pattern from autotrade.lua for inventory scanning.
    
    Usage:
    loadstring(game:HttpGet("URL"))()
--]]

-- ============================================
-- CONFIGURATION
-- ============================================

local CONFIG = {
    FIREBASE_URL = "https://autofarm-861ab-default-rtdb.asia-southeast1.firebasedatabase.app",
    HEARTBEAT_INTERVAL = 15,
    BACKPACK_INTERVAL = 30,
    DEBUG = true,
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
-- MODULE LOADING (from autotrade.lua pattern)
-- ============================================

local Replion = nil
local ItemUtility = nil

pcall(function()
    Replion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion"))
end)

pcall(function()
    ItemUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemUtility"))
end)

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
-- ITEM DATABASE (from autotrade.lua)
-- ============================================

local ItemDatabase = {}
local tierToRarity = {
    [1] = "COMMON", [2] = "UNCOMMON", [3] = "RARE",
    [4] = "EPIC", [5] = "LEGENDARY", [6] = "MYTHIC", [7] = "SECRET"
}

local function BuildItemDatabase()
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then 
        log("Items folder not found", "WARN")
        return 
    end
    
    local count = 0
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
                Type = data.Data.Type or "Unknown",
                Rarity = rarity,
                SellPrice = sellPrice
            }
            count = count + 1
        end
    end
    log("Item database built: " .. count .. " items")
end

local function GetItemInfo(itemId)
    return ItemDatabase[itemId] or { Name = "Unknown", Type = "Unknown", Rarity = "UNKNOWN", SellPrice = 0 }
end

-- ============================================
-- BACKPACK SCANNER (from autotrade.lua pattern)
-- ============================================

local BackpackScanner = {}

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
    
    -- Use Replion pattern from autotrade.lua
    if Replion and Replion.Client then
        local success = pcall(function()
            local DataReplion = Replion.Client:WaitReplion("Data")
            if not DataReplion then 
                log("DataReplion not available", "WARN")
                return 
            end
            
            local inventoryItems = DataReplion:Get({ "Inventory", "Items" })
            if not inventoryItems then 
                log("Inventory items not found", "WARN")
                return 
            end
            
            log("Scanning " .. #inventoryItems .. " items...")
            
            for _, itemData in ipairs(inventoryItems) do
                local itemInfo = GetItemInfo(itemData.Id)
                local rarity = itemInfo.Rarity
                local price = itemInfo.SellPrice or 0
                local itemName = itemInfo.Name or "Unknown"
                
                -- Track rarity counts
                result.rarityCount[rarity] = (result.rarityCount[rarity] or 0) + 1
                result.totalValue = result.totalValue + price
                
                -- Store all items
                table.insert(result.items, {
                    id = itemData.Id,
                    uuid = itemData.UUID,
                    name = itemName,
                    rarity = rarity,
                    favorited = itemData.Favorited == true,
                    value = price
                })
                
                -- Store secret items separately
                if rarity == "SECRET" then
                    table.insert(rawSecretItems, {
                        id = itemData.Id,
                        name = itemName,
                        rarity = rarity,
                        favorited = itemData.Favorited == true,
                        value = price
                    })
                end
            end
            
            log("Scanned: " .. #result.items .. " items, " .. #rawSecretItems .. " secrets")
        end)
        
        if not success then
            log("Replion scan failed", "ERROR")
        end
    else
        log("Replion not available, using fallback", "WARN")
        
        -- Fallback: scan player's Backpack tool items
        pcall(function()
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") then
                        table.insert(result.items, {
                            name = item.Name,
                            rarity = "UNKNOWN",
                            value = 0
                        })
                    end
                end
                log("Fallback scan: " .. #result.items .. " tools")
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
        status = "online",
        inGame = true,
        gameId = game.PlaceId,
        serverId = game.JobId,
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    -- Try to get game name
    pcall(function()
        info.gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    
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
    
    -- Build item database first
    BuildItemDatabase()
    
    -- Initial sync
    Heartbeat.sendHeartbeat()
    Heartbeat.sendBackpack()
    
    -- Main loop
    Heartbeat.loopThread = task.spawn(function()
        while Heartbeat.running do
            local now = os.time()
            
            if now - Heartbeat.lastHeartbeat >= CONFIG.HEARTBEAT_INTERVAL then
                Heartbeat.sendHeartbeat()
            end
            
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
    
    -- Game closing handler
    if RunService:IsServer() then
        game:BindToClose(function()
            Heartbeat.stop()
        end)
    else
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
    
    firebasePatch("accounts/" .. Username .. "/roblox", {
        inGame = false,
        status = "offline",
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    CleanupConnections()
    
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

if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2)

Heartbeat.start()

getgenv().Heartbeat = Heartbeat
getgenv().BackpackScanner = BackpackScanner

print("[HB] Heartbeat v4 started for: " .. Username)
print("[HB] Replion available: " .. tostring(Replion ~= nil))
