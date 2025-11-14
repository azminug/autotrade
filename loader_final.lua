-- Hansen Auto Trade Script Loader
-- Usage: loadstring(game:HttpGet('URL_SCRIPT_DISINI'))()

local Version = "1.6.53"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" ..
Version .. "/main.lua"))()

local Config = {
    DiscordWebhookURL = "https://discord.com/api/webhooks/1429674281746436198/qsHwLQuSF90qZhyMr6InuMGbHXhixqm5Jhyw3mEiIFFFB4Aqyqgf_RPWwaqODlJs_d0b"
}


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local net, InitiateTrade, ItemUtility, Replion, Promise, PromptController
pcall(function()
    net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
    InitiateTrade = net:WaitForChild("RF/InitiateTrade")
    ItemUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemUtility"))
    Replion = require(ReplicatedStorage.Packages.Replion)
    Promise = require(ReplicatedStorage.Packages.Promise) 
    PromptController = require(ReplicatedStorage.Controllers.PromptController) 
end)

if not (InitiateTrade and Replion and PromptController) then
    warn("❌ Gagal memuat modul inti. Skrip mungkin tidak berfungsi.")
end

-- State UI Global
_G.HansenConfig = {
    TargetPlayerName = "",
    FilterUnfavoritedOnly = false,
    TPtoPlayer = true,
    TradeDelay = 3, 
    RaritiesToTrade = {
        ["COMMON"] = 0, ["UNCOMMON"] = 0, ["RARE"] = 0, ["EPIC"] = 0,
        ["LEGENDARY"] = 0, ["MYTHIC"] = 0, ["SECRET"] = 0 
    },
    AutoAcceptActive = false,
    AutoTradeActive = false
}


local ItemDatabase = {}
local tierToRarity = {
    [1] = "COMMON", [2] = "UNCOMMON", [3] = "RARE",
    [4] = "EPIC", [5] = "LEGENDARY", [6] = "MYTHIC", [7] = "SECRET"
}
local rarityOrder = {"SECRET", "MYTHIC Favorite", "MYTHIC Unfavorite", "LEGENDARY", "EPIC", "RARE", "UNCOMMON", "COMMON"}
local rarityValue = { 
    SECRET = 8, MYTHIC = 7, LEGENDARY = 6, EPIC = 5, 
    RARE = 4, UNCOMMON = 3, COMMON = 2, UNKNOWN = 1 
}

local function safeJSONEncode(tbl)
    local ok, res = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then return res end
    return "{}"
end

local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

local function pickHTTPRequest(requestTable)
    local ok, result
    if type(http_request) == "function" then
        ok, result = pcall(function() return http_request(requestTable) end)
    elseif type(syn) == "table" and type(syn.request) == "function" then
        ok, result = pcall(function() return syn.request(requestTable) end)
    elseif type(request) == "function" then
        ok, result = pcall(function() return request(requestTable) end)
    elseif type(http) == "table" and type(http.request) == "function" then
        ok, result = pcall(function() return http.request(requestTable) end)
    end
    return ok, result
end

local function BuildItemDatabase()
    local itemsFolder = ReplicatedStorage:WaitForChild("Items")
    if not itemsFolder then return end
    
    for _, itemModule in ipairs(itemsFolder:GetChildren()) do
        local ok, data = pcall(require, itemModule)
        if ok and data.Data and data.Data.Id then
            local id = data.Data.Id
            local tierNum = data.Data.Tier or 0
            local rarity = (data.Data.Rarity and string.upper(tostring(data.Data.Rarity))) or (tierToRarity[tierNum] or "UNKNOWN")
            local sellPrice = data.SellPrice or (data.Data and data.Data.SellPrice) or 0
            
            ItemDatabase[id] = {
                Name = data.Data.Name or "Unknown",
                Type = data.Data.Type or "Unknown",
                Rarity = rarity,
                SellPrice = sellPrice
            }
        end
    end
end

local function GetItemInfo(itemId)
    return ItemDatabase[itemId] or { Name = "Unknown", Type = "Unknown", Rarity = "UNKNOWN", SellPrice = 0 }
end

-- ============================================================================
-- FITUR 1: AUTO ACCEPT
-- ============================================================================
local function HookTradePrompt(enable)
    if not PromptController or not Promise then
        warn("Gagal hook trade: Modul PromptController/Promise tidak ditemukan.")
        return
    end

    if not _G.oldFirePrompt then
        _G.oldFirePrompt = PromptController.FirePrompt
    end

    if enable then
        _G.HansenConfig.AutoAcceptActive = true
        PromptController.FirePrompt = function(self, promptText, ...)
            if _G.HansenConfig.AutoAcceptActive and type(promptText) == "string" and promptText:find("Accept") and promptText:find("from:") then
                return Promise.new(function(resolve)
                    task.wait(1.5) 
                    resolve(true)
                end)
            end
            return _G.oldFirePrompt(self, promptText, ...)
        end
    else
        _G.HansenConfig.AutoAcceptActive = false
        PromptController.FirePrompt = _G.oldFirePrompt
    end
end

-- ============================================================================
-- FITUR 2: SCAN BACKPACK
-- ============================================================================
local function ScanBackpackAndReport()
    if not Config.DiscordWebhookURL or Config.DiscordWebhookURL == "URL_WEBHOOK_ANDA_DISINI" then
        WindUI:Notify({ Title = "Scan Error", Content = "Webhook URL tidak diatur di konfigurasi skrip." })
        return
    end
    if not Replion then return end

    WindUI:Notify({ Title = "Scan", Content = "Memindai Backpack..." })

    local DataReplion = Replion.Client:WaitReplion("Data")
    if not DataReplion then return end
    local inventoryItems = DataReplion:Get({ "Inventory", "Items" })
    if not inventoryItems then return end

    local totalWorth = 0
    local totalItems = 0
    local groupedItems = {} 
    local itemList = {}
    local rarityStats = {}
    
    for _, rarityName in ipairs(rarityOrder) do
        rarityStats[rarityName] = { Count = 0, Worth = 0 }
    end
    rarityStats["UNKNOWN"] = { Count = 0, Worth = 0 }

    for _, itemData in ipairs(inventoryItems) do
        local itemInfo = GetItemInfo(itemData.Id)
        local price = itemInfo.SellPrice or 0
        local rarity = itemInfo.Rarity
        totalItems = totalItems + 1
        totalWorth = totalWorth + price
        local categoryKey = rarity
        if rarity == "MYTHIC" then
            categoryKey = itemData.Favorited and "MYTHIC Favorite" or "MYTHIC Unfavorite"
        end
        if not rarityStats[categoryKey] then categoryKey = "UNKNOWN" end
        rarityStats[categoryKey].Count = rarityStats[categoryKey].Count + 1
        rarityStats[categoryKey].Worth = rarityStats[categoryKey].Worth + price
        if not groupedItems[itemInfo.Name] then
            local newItem = { Name = itemInfo.Name, Rarity = rarity, Count = 0 }
            table.insert(itemList, newItem)
            groupedItems[itemInfo.Name] = newItem
        end
        groupedItems[itemInfo.Name].Count = groupedItems[itemInfo.Name].Count + 1
    end

    table.sort(itemList, function(a, b)
        local aVal = rarityValue[a.Rarity] or 0
        local bVal = rarityValue[b.Rarity] or 0
        if aVal ~= bVal then return aVal > bVal end
        return a.Count > b.Count
    end)

    local rarityString = ""
    for _, rarityName in ipairs(rarityOrder) do
        local stats = rarityStats[rarityName]
        rarityString = rarityString .. string.format("**%s**: %d (%s)\n", rarityName, stats.Count, FormatNumber(stats.Worth))
    end
    if rarityStats["UNKNOWN"].Count > 0 then
        rarityString = rarityString .. string.format("**%s**: %d (%s)\n", "UNKNOWN", rarityStats["UNKNOWN"].Count, FormatNumber(rarityStats["UNKNOWN"].Worth))
    end

    local itemString = ""
    local maxItemsInList = 25
    for i = 1, math.min(#itemList, maxItemsInList) do
        local item = itemList[i]
        itemString = itemString .. string.format("`%dx` %s (%s)\n", item.Count, item.Name, item.Rarity)
    end
    if #itemList > maxItemsInList then
        itemString = itemString .. string.format("...dan %d jenis item lainnya.", #itemList - maxItemsInList)
    end
    if itemString == "" then itemString = "Kosong" end

    local payload = {
        embeds = {{
            title = "🎒 Scan Isi Backpack",
            color = 15844367,
            description = "**" .. LocalPlayer.Name .. "**",
            fields = {
                { name = "Total Item", value = totalItems, inline = true },
                { name = "Total Nilai (Worth)", value = string.format("`%s` Coins", FormatNumber(totalWorth)), inline = true },
                { name = "Rangkuman Rarity", value = rarityString, inline = false },
                { name = "Daftar Item (Terurut)", value = itemString, inline = false }
            },
            footer = { text = "Hansen Scan Script" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    local req = { Url = Config.DiscordWebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = safeJSONEncode(payload) }
    
    task.spawn(function()
        local ok, res = pickHTTPRequest(req)
        if ok then
            WindUI:Notify({ Title = "Scan", Content = "Laporan berhasil dikirim ke Discord." })
        else
            WindUI:Notify({ Title = "Scan Error", Content = "Gagal mengirim webhook." })
        end
    end)
end

-- ============================================================================
-- FITUR 3: AUTO TRADE
-- ============================================================================
local function SendFinalReport(targetPlayer, tradeResults)
    if not Config.DiscordWebhookURL or Config.DiscordWebhookURL == "URL_WEBHOOK_ANDA_DISINI" or tradeResults.TotalCount == 0 then
        return
    end
    local rarityString = ""
    for rarity, count in pairs(tradeResults.ByRarity) do
        rarityString = rarityString .. string.format("**%s**: %d\n", rarity, count)
    end
    local itemString = ""
    local maxItemsInList = 25
    for i = 1, math.min(#tradeResults.ItemList, maxItemsInList) do
        itemString = itemString .. tradeResults.ItemList[i] .. "\n"
    end
    if #tradeResults.ItemList > maxItemsInList then
        itemString = itemString .. string.format("...dan %d item lainnya.", #tradeResults.ItemList - maxItemsInList)
    end
    local payload = {
        embeds = {{
            title = "Auto Trade Log",
            color = 3066993,
            fields = {
                { name = "Target Player", value = targetPlayer.Name, inline = true },
                { name = "Total Item Terkirim", value = tradeResults.TotalCount, inline = true },
                { name = "Rangkuman Rarity", value = rarityString, inline = false },
                { name = "Daftar Item (Sebagian)", value = itemString, inline = false }
            },
            footer = { text = "Hansen Auto Trade Script" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    local req = { Url = Config.DiscordWebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = safeJSONEncode(payload) }
    task.spawn(function() pickHTTPRequest(req) end)
end

local function TeleportToTarget(targetPlayer)
    if not LocalPlayer.Character or not targetPlayer.Character then return false end
    local myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if myHRP and targetHRP then
        myHRP.CFrame = targetHRP.CFrame + Vector3.new(3, 0, 0)
        return true
    end
    return false
end

local function StartMassTradeByRarity()
    if not InitiateTrade then return end

    local targetPlayer = nil
    local targetName = _G.HansenConfig.TargetPlayerName
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == targetName or player.DisplayName == targetName then
            if player ~= LocalPlayer then
                targetPlayer = player
                break
            end
        end
    end
    
    if not targetPlayer then
        WindUI:Notify({ Title = "Auto Trade Error", Content = "Target player '" .. targetName .. "' tidak ditemukan." })
        _G.HansenConfig.AutoTradeActive = false
        return
    end
    
    local targetPlayerId = targetPlayer.UserId

    local DataReplion = Replion.Client:WaitReplion("Data")
    if not DataReplion then return end
    local inventoryItems = DataReplion:Get({ "Inventory", "Items" })
    if not inventoryItems then return end

    local tradeResults = { TotalCount = 0, ByRarity = {}, ItemList = {} }

    for _, itemData in ipairs(inventoryItems) do
        if not _G.HansenConfig.AutoTradeActive then break end

        local itemInfo = GetItemInfo(itemData.Id)
        local rarity = itemInfo.Rarity
        local configLimitStr = _G.HansenConfig.RaritiesToTrade[rarity]
        local configLimit = 0
        
        if type(configLimitStr) == "string" and configLimitStr:lower() == "all" then
            configLimit = "ALL"
        else
            configLimit = tonumber(configLimitStr) or 0
        end

        local currentSuccessCount = tradeResults.ByRarity[rarity] or 0
        
        if type(configLimit) == "number" and configLimit > 0 and currentSuccessCount >= configLimit then
            continue 
        end

        local shouldTake = false
        if configLimit == "ALL" or (type(configLimit) == "number" and configLimit > 0) then
            shouldTake = true 
        end
        
        if _G.HansenConfig.FilterUnfavoritedOnly and itemData.Favorited then
            shouldTake = false
        end

        if shouldTake then
            local item = { UUID = itemData.UUID, Category = itemInfo.Type or "Fish", Name = itemInfo.Name, Rarity = itemInfo.Rarity }
            local tradeSucceeded = false
            
            while not tradeSucceeded and _G.HansenConfig.AutoTradeActive do
                if _G.HansenConfig.TPtoPlayer then
                    if TeleportToTarget(targetPlayer) then
                        task.wait(0.5) 
                    end
                end
                
                local pcallSuccess, tradeResult = pcall(InitiateTrade.InvokeServer, InitiateTrade, targetPlayerId, item.UUID, item.Category)
                
                if pcallSuccess and tradeResult == true then
                    tradeSucceeded = true 
                    tradeResults.TotalCount = tradeResults.TotalCount + 1
                    tradeResults.ByRarity[rarity] = (tradeResults.ByRarity[rarity] or 0) + 1
                    table.insert(tradeResults.ItemList, item.Name)
                end
                
                if _G.HansenConfig.TradeDelay > 0 then
                    task.wait(_G.HansenConfig.TradeDelay)
                end
            end 
        end
    end
    
    WindUI:Notify({ Title = "Auto Trade", Content = "Mass Trade Selesai. Mengirim laporan..." })
    SendFinalReport(targetPlayer, tradeResults)
    _G.HansenConfig.AutoTradeActive = false
end

-- ============================================================================
-- DEFINISI UI (WindUI)
-- ============================================================================
local Window = WindUI:CreateWindow({
    Title = "Hansen Auto Trade Script",
    Icon = "crown",
    Author = "Hansen",
    Folder = "Hansen",
    Size = UDim2.fromOffset(400, 300),
    Transparent = true,
    KeySystem = false,
    ScrollBarEnabled = true,
    Theme = "Dark"   -- FIX
})


Window:EditOpenButton({
    Title = "Hansen",
    Icon = "star",
    Draggable = true,
})

-- TAB AUTO ACCEPT & SCAN
local AcceptScanTab = Window:Tab({ Title = "Auto Accept & Scan", Icon = "shield-check" })
AcceptScanTab:Section({ Title = "Auto Accept" })

_G.Keybind = AcceptScanTab:Keybind({
    Title = "Keybind",
    Desc = "Keybind to open UI",
    Value = "F",
    Callback = function(v)
        Window:SetToggleKey(Enum.KeyCode[v])
    end
})

AcceptScanTab:Toggle({
    Title = "Auto Accept (From Anyone)",
    Desc = "Otomatis menerima semua permintaan trade.",
    Value = _G.HansenConfig.AutoAcceptActive,
    Callback = function(state)
        HookTradePrompt(state)
        if state then
            WindUI:Notify({ Title = "Auto Accept", Content = "Sekarang menerima semua trade." })
        else
            WindUI:Notify({ Title = "Auto Accept", Content = "Auto Accept dinonaktifkan." })
        end
    end
})

AcceptScanTab:Section({ Title = "Scan Backpack" })
AcceptScanTab:Button({
    Title = "Scan Backpack Sekarang",
    Desc = "Pindai Backpack Anda dan kirim laporan ke Discord.",
    Icon = "scan-search",
    Callback = ScanBackpackAndReport
})

-- TAB AUTO TRADE
local AutoTradeTab = Window:Tab({ Title = "Auto Trade", Icon = "send" })
AutoTradeTab:Section({ Title = "Pengaturan Target & Trade" })

local function getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

AutoTradeTab:Dropdown({
    Title = "Pilih Target Player",
    Values = getPlayerList(),
    AllowNone = true,
    SearchBarEnabled = true,
    Callback = function(selected)
        _G.HansenConfig.TargetPlayerName = selected or ""
    end
})

AutoTradeTab:Slider({
    Title = "Trade Delay (Detik)",
    Desc = "Jeda antar setiap percobaan trade.",
    Value = { Min = 0, Max = 10, Default = _G.HansenConfig.TradeDelay },
    Precise = 1,
    Step = 0.5,
    Callback = function(v)
        _G.HansenConfig.TradeDelay = tonumber(v)
    end
})

AutoTradeTab:Toggle({
    Title = "Teleport ke Player",
    Desc = "Otomatis TP ke target sebelum setiap trade.",
    Value = _G.HansenConfig.TPtoPlayer,
    Callback = function(state)
        _G.HansenConfig.TPtoPlayer = state
    end
})

AutoTradeTab:Toggle({
    Title = "Filter Unfavorited Only",
    Desc = "Jika AKTIF, hanya item yang TIDAK difavorit yang akan ditrade.",
    Value = _G.HansenConfig.FilterUnfavoritedOnly,
    Callback = function(state)
        _G.HansenConfig.FilterUnfavoritedOnly = state
    end
})

AutoTradeTab:Section({ Title = "Jumlah Rarity (Ketik 'ALL' untuk semua)" })

local rarityInputs = {}
for _, rarityName in ipairs({"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET"}) do
    rarityInputs[rarityName] = AutoTradeTab:Input({
        Title = rarityName,
        Placeholder = "0",
        Type = "Input",
        Callback = function(val)
            _G.HansenConfig.RaritiesToTrade[rarityName] = val
        end
    })
end

AutoTradeTab:Section({ Title = "Eksekusi" })

AutoTradeTab:Button({
    Title = "MULAI AUTO TRADE",
    Icon = "play",
    Callback = function()
        if _G.HansenConfig.AutoTradeActive then
            WindUI:Notify({ Title = "Auto Trade", Content = "Sudah berjalan!", Icon = "alert-triangle" })
            return
        end
        WindUI:Notify({ Title = "Auto Trade", Content = "Memulai...", Icon = "loader" })
        task.spawn(StartMassTradeByRarity)
    end
})

AutoTradeTab:Button({
    Title = "STOP AUTO TRADE",
    Icon = "stop",
    Callback = function()
        if not _G.HansenConfig.AutoTradeActive then
            WindUI:Notify({ Title = "Auto Trade", Content = "Sudah berhenti.", Icon = "info" })
            return
        end
        WindUI:Notify({ Title = "Auto Trade", Content = "Menghentikan...", Icon = "ban" })
        _G.HansenConfig.AutoTradeActive = false
    end
})

-- ============================================================================
-- EKSEKUSI
-- ============================================================================
BuildItemDatabase()
