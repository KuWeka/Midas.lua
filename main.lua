-- ==============================================================================
-- PROSPECTING! Midas Touch (Ultimate V29)
-- Features: Auto Farm, Movement, Auto Sell, Auto Favourite, Teleport, Server hop, Shop, Settings
-- ==============================================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local coreGui = game:GetService("CoreGui")
local uiNameToDestroy = "FluentRenewed_ProspectingUI"
local uiElement = coreGui:FindFirstChild(uiNameToDestroy)
if not uiElement then
    local hiddenUI = coreGui:FindFirstChild("HiddenUI")
    if hiddenUI then uiElement = hiddenUI:FindFirstChild(uiNameToDestroy) end
end
if uiElement then uiElement:Destroy() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- 0. MEMORY MANAGEMENT & KNIGHTMARE BYPASS
-- ==========================================
local Connections = {}
local CharConnections = {}
local characterParts = {}

local function updateCharacterParts(char)
    table.clear(characterParts)
    for _, conn in ipairs(CharConnections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(CharConnections)
    if not char then return end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(characterParts, part) end
    end
    table.insert(CharConnections, char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then table.insert(characterParts, part) end
    end))
end

local function disableKnightmare()
    local function scanAndDestroy(parent)
        if not parent then return end
        for _, obj in ipairs(parent:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("ModuleScript") or obj:IsA("Script") then
                local name = string.lower(obj.Name)
                if name:match("^knightmare") or name:match("^anticheat") or name == "ac" then
                    pcall(function()
                        if obj:IsA("LocalScript") or obj:IsA("Script") then obj.Disabled = true end
                        obj:Destroy()
                    end)
                end
            end
        end
    end
    
    scanAndDestroy(LocalPlayer:WaitForChild("PlayerGui", 5))
    if LocalPlayer.Character then 
        scanAndDestroy(LocalPlayer.Character) 
        updateCharacterParts(LocalPlayer.Character)
    end
    
    table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)
        scanAndDestroy(char)
        scanAndDestroy(LocalPlayer:FindFirstChild("PlayerGui"))
        updateCharacterParts(char)
    end))
end

disableKnightmare()

-- ==========================================
-- 1. FLUENT UI & HOOKS INITIALIZATION
-- ==========================================
local g = getinfo or debug.getinfo
local d = false
local h = {}
local x, y
setthreadidentity(2)
for i, v in getgc(true) do
    if typeof(v) == "table" then
        local a = rawget(v, "Detected")
        local b = rawget(v, "Kill")
        if typeof(a) == "function" and not x then
            x = a
            local o; o = hookfunction(x, function(c, f, n)
                if c ~= "_" then if d then end end return true
            end)
            table.insert(h, x)
        end
        if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
            y = b
            local o; o = hookfunction(y, function(f) if d then end end)
            table.insert(h, y)
        end
    end
end
setthreadidentity(7)

local Library = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Prospecting! Midas Touch",
    SubTitle = "Ultimate V29",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl 
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main ⛏️", Icon = "home" }),
    Move = Window:AddTab({ Title = "Movement & Misc 🏃", Icon = "footprints" }),
    Sell = Window:AddTab({ Title = "Auto Sell 💰", Icon = "shopping-cart" }),
    Favourite = Window:AddTab({ Title = "Auto Lock 🔒", Icon = "heart" }),
    Shop = Window:AddTab({ Title = "Shop 🏪", Icon = "shopping-cart" }),
    Teleport = Window:AddTab({ Title = "Teleport 🗺️", Icon = "map" }),
    Settings = Window:AddTab({ Title = "Settings ⚙️", Icon = "settings" })
}

local Options = Library.Options

-- ==========================================
-- 2. STATE & VARIABLES
-- ==========================================
local State = { 
    isFarming = false, 
    isSelling = false,
    digLocation = nil,
    panLocation = nil
}

local LogItems = false
local WebhookLink = ""

local MoveState = { WS = false, WS_Val = 50, JP = false, JP_Val = 100, IJ = false, NC = false }
local ncRayParams = RaycastParams.new()
local antiAFK = false

-- ==========================================
-- 3. UTILITIES & DATA SCRAPING
-- ==========================================
local function getEquippedTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function getBackpackTool()
    local backpackTwo = LocalPlayer:FindFirstChild("BackpackTwo") or LocalPlayer:FindFirstChild("Backpack")
    if backpackTwo then
        for _, item in ipairs(backpackTwo:GetChildren()) do
            if item:IsA("Tool") and (item.Name:match("Pan") or item.Name:match("Shovel") or item.Name:match("Worldshaker") or item.Name:match("Earthbreaker")) then
                return item
            end
        end
    end
    return nil
end

local function equipTool()
    local equipped = getEquippedTool()
    if equipped then return equipped end
    
    local tool = getBackpackTool()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if tool and hum then
        hum:EquipTool(tool)
        task.wait(0.1)
        return getEquippedTool()
    end
    return nil
end

local function getInventoryStats()
    -- Get Max Size using multiple fallbacks
    local maxCapacity = LocalPlayer:GetAttribute("InventorySize") or 500
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local invLabel = pgui:FindFirstChild("BackpackGui") and pgui.BackpackGui:FindFirstChild("Backpack", true) and pgui.BackpackGui.Backpack:FindFirstChild("InventorySize", true)
        if invLabel and invLabel.Text then
            local maxStr = string.match(invLabel.Text, "/%s*(%d+)")
            if maxStr then maxCapacity = tonumber(maxStr) or maxCapacity end
        end
    end

    -- Count valid items
    local backpackTwo = LocalPlayer:FindFirstChild("BackpackTwo")
    if not backpackTwo then return 0, maxCapacity end

    local items = backpackTwo:GetChildren()
    local charTool = getEquippedTool()
    if charTool then table.insert(items, charTool) end

    local count = 0
    for _, item in ipairs(items) do
        local itemType = item:GetAttribute("ItemType")
        if itemType == "Equipment" or itemType == "Valuable" then
            count = count + 1
        end
    end

    return count, maxCapacity
end

local function isPanFull()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return false end
    
    local fillTextLabel = pgui:FindFirstChild("ToolUI") 
        and pgui.ToolUI:FindFirstChild("FillingPan") 
        and pgui.ToolUI.FillingPan:FindFirstChild("FillText")
        
    if fillTextLabel and fillTextLabel:IsA("TextLabel") then
        local text = fillTextLabel.Text:gsub("<[^>]->", ""):gsub(",", "")
        local cur, max = string.match(text, "(%d+)%s*/%s*(%d+)")
        if cur and max then return tonumber(cur) >= tonumber(max) end
    end
    return false
end

-- ==========================================
-- 4. MERCHANT LOCATOR
-- ==========================================
local merchantData = {
    {Name = "StarterTown Merchant", Path = {"Map", "NPCs", "StarterTown", "Merchant"}},
    {Name = "RiverTown Merchant", Path = {"Map", "NPCs", "RiverTown", "Merchant"}},
    {Name = "Delta Shady Merchant", Path = {"Map", "NPCs", "Delta", "Shady Merchant"}},
    {Name = "Cavern Merchant", Path = {"Map", "NPCs", "Cavern", "Merchant"}},
    {Name = "Volcano Merchant", Path = {"Map", "NPCs", "Volcano", "Merchant"}}, 
}

local function getTargetMerchant()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local selectedMerchant = Options.MerchantSelector and Options.MerchantSelector.Value or "Closest"
    local targetPos = nil
    
    if selectedMerchant == "Closest" then
        local minDist = math.huge
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:match("Merchant") or obj.Name:match("Seller")) then
                local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                if hrp then
                    local dist = (root.Position - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        targetPos = hrp.Position
                    end
                end
            end
        end
    else
        for _, data in ipairs(merchantData) do
            if data.Name == selectedMerchant then
                if data.Name == "Volcano Merchant" then
                    local volcanoFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("NPCs") and Workspace.Map.NPCs:FindFirstChild("Volcano")
                    if volcanoFolder then
                        local minDistance = math.huge
                        for _, obj in ipairs(volcanoFolder:GetChildren()) do
                            if obj.Name == "Merchant" and obj:FindFirstChild("HumanoidRootPart") then
                                local dist = (root.Position - obj.HumanoidRootPart.Position).Magnitude
                                if dist < minDistance then
                                    minDistance = dist
                                    targetPos = obj.HumanoidRootPart.Position
                                end
                            end
                        end
                    end
                else
                    local merchant = Workspace
                    for _, partName in ipairs(data.Path) do
                        merchant = merchant:FindFirstChild(partName)
                        if not merchant then break end
                    end
                    if merchant then
                        local hrp = merchant:FindFirstChild("HumanoidRootPart") or merchant.PrimaryPart
                        if hrp then targetPos = hrp.Position end
                    end
                end
                break
            end
        end
    end
    return targetPos
end

-- ==========================================
-- 5. AUTO SELL & WEBHOOK LOGIC (INSTANT)
-- ==========================================
local function shouldAutoSell()
    if not Options.AutoSellToggle or not Options.AutoSellToggle.Value then return false end
    
    local mode = Options.AutoSellMode and Options.AutoSellMode.Value or "Full Inventory"
    local cur, max = getInventoryStats()
    
    if mode == "Full Inventory" then
        return (max > 0 and cur >= max)
    elseif mode == "Target Inventory" then
        local targetStr = Options.TargetInventoryValue and Options.TargetInventoryValue.Value or "275"
        local target = tonumber(targetStr) or 275
        return (cur >= target)
    end
    return false
end

local lastSellAttempt = 0
local function instantSellAll()
    if State.isSelling then return end
    if tick() - lastSellAttempt < 2 then return end 
    State.isSelling = true
    lastSellAttempt = tick()
    
    local success, err = pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local originalCFrame = root.CFrame
        local merchantPos = getTargetMerchant()
        
        if not merchantPos then
            Library:Notify({ Title = "Sell Error", Content = "Merchant tidak ditemukan!", Duration = 4 })
            return
        end
        
        -- INSTANT TELEPORT
        root.CFrame = CFrame.new(merchantPos + Vector3.new(3, 1, 0))
        task.wait(0.1)
        root.Anchored = true
        task.wait(0.1)
        
        -- INSTANT SELL REMOTE
        local shopFolder = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Shop")
        local sellRemote = shopFolder and shopFolder:FindFirstChild("SellAll")
        if sellRemote then
            if sellRemote:IsA("RemoteFunction") then sellRemote:InvokeServer()
            elseif sellRemote:IsA("RemoteEvent") then sellRemote:FireServer() end
        end
        
        task.wait(0.3)
        
        -- INSTANT RETURN
        root.Anchored = false
        root.CFrame = originalCFrame
        task.wait(0.1)
        root.Anchored = true
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        root.Anchored = false
        
        -- Discord Webhook
        if LogItems and WebhookLink ~= "" then
            pcall(function()
                request({
                    Url = WebhookLink,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({content = "Successfully auto-sold inventory to merchant.", username = "Midas Touch Webhook"})
                })
            end)
        end
    end)
    
    State.isSelling = false
    if not success then warn("[SELL ERROR] " .. tostring(err)) end
end

-- ==========================================
-- 6. AUTO FAVOURITE (LOCK) LOGIC
-- ==========================================
local pendingLocks = {}

local function scanAndLockBackpack()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return end
    
    local gridFrame = pgui:FindFirstChild("BackpackGui")
        and pgui.BackpackGui:FindFirstChild("Backpack")
        and pgui.BackpackGui.Backpack:FindFirstChild("Inventory")
        and pgui.BackpackGui.Backpack.Inventory:FindFirstChild("ScrollingFrame")
        and pgui.BackpackGui.Backpack.Inventory.ScrollingFrame:FindFirstChild("UIGridFrame")
        
    if not gridFrame then return end

    local rarityValues = { ["Legendary"] = 5, ["Epic"] = 4, ["Rare"] = 3, ["Uncommon"] = 2, ["Common"] = 1 }
    local selectedRarityStr = Options.RarityDropdown and Options.RarityDropdown.Value or "None"
    local selectedRarityWeight = rarityValues[selectedRarityStr] or 0
    local minWeight = Options.WeightSlider and Options.WeightSlider.Value or 0
    local selectedNames = Options.LockItemName and Options.LockItemName.Value or {}
    
    for _, item in ipairs(gridFrame:GetChildren()) do
        if item:IsA("Frame") and not pendingLocks[item] then
            -- Verify it's not locked via UI indicators
            local isLocked = item:FindFirstChild("LockedIcon") or item:FindFirstChild("LockedStrokeFrame")
            if not isLocked then
                local itemNameLabel = item:FindFirstChild("ToolName")
                local toolWeightLabel = item:FindFirstChild("ToolWeight")
                
                if itemNameLabel and toolWeightLabel then
                    local itemName = itemNameLabel.Text
                    local weightText = toolWeightLabel.Text
                    local actualWeight = tonumber(string.match(weightText, "([%d%.]+)")) or 0
                    
                    local actualRarityStr = "Common"
                    local newTooltip = item:FindFirstChild("NewTooltip")
                    if newTooltip then
                        local rarityLabel = newTooltip:FindFirstChild("Stats") and newTooltip.Stats:FindFirstChild("Rarity") and newTooltip.Stats.Rarity:FindFirstChild("RarityText")
                        if rarityLabel then
                            actualRarityStr = rarityLabel.Text
                        end
                    end
                    local actualRarityWeight = rarityValues[actualRarityStr] or 0
                    
                    local shouldLock = false
                    if minWeight > 0 and actualWeight >= minWeight then shouldLock = true end
                    if selectedRarityWeight > 0 and actualRarityWeight >= selectedRarityWeight then shouldLock = true end
                    for selectedName, isSelected in pairs(selectedNames) do
                        if isSelected and string.lower(itemName):match(string.lower(selectedName)) then
                            shouldLock = true
                            break
                        end
                    end
                    
                    if shouldLock then
                        pendingLocks[item] = tick()
                        pcall(function()
                            local lockRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Inventory") and ReplicatedStorage.Remotes.Inventory:FindFirstChild("ToggleLock")
                            if lockRemote then
                                if lockRemote:IsA("RemoteFunction") then lockRemote:InvokeServer(item.Name)
                                elseif lockRemote:IsA("RemoteEvent") then lockRemote:FireServer(item.Name) end
                            end
                        end)
                        -- Timeout to prevent deadlock
                        task.delay(1, function() pendingLocks[item] = nil end)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.5) do
        if Options.AutoFavoriteToggle and Options.AutoFavoriteToggle.Value then
            scanAndLockBackpack()
        end
    end
end)

-- ==========================================
-- 7. FAST MODE CORE LOOP (SPAM)
-- ==========================================
local function doDig()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(State.digLocation.X, 0, State.digLocation.Z)).Magnitude > 3 then
        root.CFrame = CFrame.new(State.digLocation)
        task.wait(0.2)
    end
    
    local tool = equipTool()
    if not tool then task.wait(0.5); return end
    
    local scriptsFolder = tool:FindFirstChild("Scripts")
    local digRemote = scriptsFolder and (scriptsFolder:FindFirstChild("ToggleShovelActive") or scriptsFolder:FindFirstChild("Dig"))
    
    if digRemote then
        pcall(function()
            if digRemote:IsA("RemoteEvent") then digRemote:FireServer()
            elseif digRemote:IsA("RemoteFunction") then digRemote:InvokeServer() end
        end)
    end
    task.wait(0.1)
end

local function doPan()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(State.panLocation.X, 0, State.panLocation.Z)).Magnitude > 3 then
        root.CFrame = CFrame.new(State.panLocation)
        task.wait(0.2)
    end
    
    local tool = equipTool()
    if not tool then task.wait(0.5); return end
    
    local scriptsFolder = tool:FindFirstChild("Scripts")
    local panRemote = scriptsFolder and scriptsFolder:FindFirstChild("Pan")
    local shakeRemote = scriptsFolder and scriptsFolder:FindFirstChild("Shake")
    local collectRemote = scriptsFolder and scriptsFolder:FindFirstChild("Collect")
    
    if panRemote and shakeRemote then
        pcall(function()
            if panRemote:IsA("RemoteFunction") then panRemote:InvokeServer()
            elseif panRemote:IsA("RemoteEvent") then panRemote:FireServer() end
        end)
        
        while State.isFarming and isPanFull() do
            pcall(function()
                if shakeRemote:IsA("RemoteEvent") then shakeRemote:FireServer()
                elseif shakeRemote:IsA("RemoteFunction") then shakeRemote:InvokeServer() end
            end)
            task.wait(0.05)
        end
        
        if collectRemote then
            pcall(function()
                if collectRemote:IsA("RemoteFunction") then collectRemote:InvokeServer(1)
                elseif collectRemote:IsA("RemoteEvent") then collectRemote:FireServer(1) end
            end)
        end
    end
    task.wait(0.1)
end

local function toggleAutoFarm(value)
    if State.isFarming == value then return end
    if value and (not State.digLocation or not State.panLocation) then
        Library:Notify({ Title = "Error", Content = "Set lokasi Dig & Pan dulu!", Duration = 5 })
        Options.AutoFarmToggle:SetValue(false)
        return
    end
    
    State.isFarming = value
    
    if value then
        task.spawn(function()
            while State.isFarming do
                local char = LocalPlayer.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then break end
                
                if shouldAutoSell() then
                    Options.AutoFarmToggle:SetValue(false)
                    task.wait(0.1)
                    instantSellAll()
                    Options.AutoFarmToggle:SetValue(true)
                    break 
                end
                
                if not isPanFull() then
                    doDig()
                else
                    doPan()
                end
            end
        end)
    end
end

-- ==========================================
-- 8. TAB 1: MAIN
-- ==========================================
Tabs.Main:AddToggle("AutoFarmToggle", { Title = "Auto Farm", Description = "Auto Farm All (Instant)", Default = false, Callback = toggleAutoFarm })

local waterStr = "Not set"
local sandStr = "Not set"
local locPara = nil

Tabs.Main:AddButton({
    Title = "🌊 Set Water Location",
    Description = "Save current position for Panning",
    Callback = function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            State.panLocation = root.Position
            waterStr = string.format("X: %.1f, Y: %.1f, Z: %.1f", root.Position.X, root.Position.Y, root.Position.Z)
            if locPara then locPara:SetDesc(string.format("🌊 Water: %s\n🏜️ Sand: %s", waterStr, sandStr)) end
            Library:Notify({ Title = "Success", Content = "Water location saved!", Duration = 3 })
        end
    end
})

Tabs.Main:AddButton({
    Title = "🏜️ Set Sand Location",
    Description = "Save current position for Digging",
    Callback = function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            State.digLocation = root.Position
            sandStr = string.format("X: %.1f, Y: %.1f, Z: %.1f", root.Position.X, root.Position.Y, root.Position.Z)
            if locPara then locPara:SetDesc(string.format("🌊 Water: %s\n🏜️ Sand: %s", waterStr, sandStr)) end
            Library:Notify({ Title = "Success", Content = "Dig location saved!", Duration = 3 })
        end
    end
})

locPara = Tabs.Main:AddParagraph({ Title = "📍 Saved Locations", Content = "🌊 Water: Not set\n🏜️ Sand: Not set" })

-- ==========================================
-- 9. TAB 2: AUTO-SELL
-- ==========================================
Tabs.Sell:AddToggle("AutoSellToggle", { Title = "Enable Auto Sell", Default = true })
Tabs.Sell:AddDropdown("MerchantSelector", {
    Title = "Select Merchant",
    Values = {"Closest", "StarterTown Merchant", "RiverTown Merchant", "Delta Shady Merchant", "Cavern Merchant", "Volcano Merchant"},
    Multi = false,
    Default = 1,
})
Tabs.Sell:AddDropdown("AutoSellMode", {
    Title = "Auto Sell Mode",
    Values = {"Full Inventory", "Target Inventory"},
    Multi = false,
    Default = 1,
})
Tabs.Sell:AddInput("TargetInventoryValue", {
    Title = "Target Inventory Amount",
    Default = "275",
    Numeric = true,
    Finished = false,
})
Tabs.Sell:AddButton({ 
    Title = "Sell All Now (Instan)", 
    Callback = function()
        task.spawn(function()
            local wasFarming = State.isFarming
            if wasFarming then Options.AutoFarmToggle:SetValue(false) end
            task.wait(0.2)
            instantSellAll()
            if wasFarming then Options.AutoFarmToggle:SetValue(true) end
        end)
    end 
})

-- ==========================================
-- 10. TAB 3: FAVOURITE (AUTO-LOCK)
-- ==========================================
Tabs.Favourite:AddToggle("AutoFavoriteToggle", { Title = "Enable Auto Lock", Default = false })
Tabs.Favourite:AddDropdown("LockItemName", {
    Title = "Select Items to Lock",
    Values = {"Coal", "Copper", "Iron", "Silver", "Gold", "Diamond", "Emerald", "Ruby", "Sapphire", "Amethyst", "Topaz", "Crystal", "Magma", "Meteorite", "Relic", "Fossil", "Geode"},
    Multi = true,
    Default = {},
})
Tabs.Favourite:AddSlider("WeightSlider", { Title = "Minimum Weight (lbs/kg)", Default = 0, Min = 0, Max = 1000, Rounding = 1 })
Tabs.Favourite:AddDropdown("RarityDropdown", {
    Title = "Minimum Rarity",
    Values = {"None", "Common", "Uncommon", "Rare", "Epic", "Legendary"},
    Multi = false,
    Default = 1,
})

-- ==========================================
-- 11. TAB 4: SHOP (REMOTE)
-- ==========================================
Tabs.Shop:AddDropdown("ShopItemDropdown", {
    Title = "Pilih Alat",
    Values = {"Starter Shovel", "Starter Pan", "Bronze Shovel", "Bronze Pan", "Iron Shovel", "Iron Pan"},
    Multi = false,
    Default = 1,
})
Tabs.Shop:AddButton({
    Title = "Buy Remote Tool",
    Callback = function()
        local shopItem = Options.ShopItemDropdown and Options.ShopItemDropdown.Value
        if not shopItem then return end
        
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("Shop") and remotes.Shop:FindFirstChild("BuyItem") then
                local buyRemote = remotes.Shop.BuyItem
                if buyRemote:IsA("RemoteFunction") then buyRemote:InvokeServer(shopItem)
                elseif buyRemote:IsA("RemoteEvent") then buyRemote:FireServer(shopItem) end
                Library:Notify({ Title = "Shop", Content = "Berhasil membeli " .. shopItem, Duration = 3 })
            end
        end)
    end
})

-- ==========================================
-- 12. TAB 5: TELEPORT & SERVER HOP
-- ==========================================
local SelectedWaypoint = "Crystal Caverns"
Tabs.Teleport:AddDropdown("WaypointSelect", {
    Title = "Pilih Waypoint",
    Values = {
        "Crystal Caverns", "Deeproot Spring", "Fortune River", "Fortune River Delta",
        "Frostbitten Path", "Frozen Peak", "Meteor Valley", "Meteor Valley Entrance",
        "Museum", "Overgrown Grotto", "Rotwood Swamp", "Rubble Creek",
        "Snowy Shores", "Sunset Beach", "The Magma Furnace", "Timelocked Sanctuary", "Volcanic Sands"
    },
    Default = "Crystal Caverns",
    Callback = function(Value) SelectedWaypoint = Value end
})

Tabs.Teleport:AddButton({
    Title = "Teleport Instan",
    Callback = function()
        if not SelectedWaypoint then return end
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local waypointsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Waypoints")
        local model = waypointsFolder and waypointsFolder:FindFirstChild(SelectedWaypoint)
        if not model then return end
        
        local targetCFrame = model:GetPivot()
        root.CFrame = targetCFrame * CFrame.new(0, 3, 0)
    end
})

Tabs.Teleport:AddButton({
    Title = "Server Hop (Smallest Server)",
    Callback = function()
        local PlaceID = game.PlaceId
        local AllIDs = {}
        local foundAnything = ""
        local actualHour = os.date("!*t").hour
        
        pcall(function() AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json")) end)
        if #AllIDs == 0 then table.insert(AllIDs, actualHour) pcall(function() writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs)) end) end
        
        local function TPReturner()
            local Site
            if foundAnything == "" then
                Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
            else
                Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
            end
            if Site.nextPageCursor and Site.nextPageCursor ~= "null" then foundAnything = Site.nextPageCursor end
            
            local num = 0
            for i,v in pairs(Site.data) do
                local Possible = true
                local ID = tostring(v.id)
                if tonumber(v.maxPlayers) > tonumber(v.playing) then
                    for _,Existing in pairs(AllIDs) do
                        if num ~= 0 then
                            if ID == tostring(Existing) then Possible = false end
                        else
                            if tonumber(actualHour) ~= tonumber(Existing) then
                                pcall(function() delfile("NotSameServers.json") AllIDs = {} table.insert(AllIDs, actualHour) end)
                            end
                        end
                        num = num + 1
                    end
                    if Possible == true then
                        table.insert(AllIDs, ID)
                        task.wait()
                        pcall(function()
                            writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
                            task.wait()
                            TeleportService:TeleportToPlaceInstance(PlaceID, ID, LocalPlayer)
                        end)
                        task.wait(4)
                    end
                end
            end
        end
        task.spawn(function()
            while task.wait(0.5) do pcall(function() TPReturner() if foundAnything ~= "" then TPReturner() end end) end
        end)
    end
})

-- ==========================================
-- 13. TAB 6: MOVEMENT & MISC
-- ==========================================
Tabs.Move:AddToggle("AntiAFK", { Title = "Enable Anti-AFK", Default = false, Callback = function(v) antiAFK = v end })
table.insert(Connections, LocalPlayer.Idled:Connect(function()
    if antiAFK then 
        VirtualUser:CaptureController() 
        VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
    end
end))
Tabs.Move:AddInput("DiscordWebhook", { Title = "Discord Webhook URL", Default = "", Numeric = false, Finished = false, Callback = function(v) WebhookLink = v end })
Tabs.Move:AddToggle("LogItemsToDiscord", { Title = "Log Locked/Sold Items to Discord", Default = false, Callback = function(v) LogItems = v end })
Tabs.Move:AddToggle("WalkSpeed", { Title = "WalkSpeed", Default = false, Callback = function(v) MoveState.WS = v end })
Tabs.Move:AddSlider("WalkSpeedVal", { Title = "Speed", Default = 50, Min = 16, Max = 350, Rounding = 0, Callback = function(v) MoveState.WS_Val = v end })
Tabs.Move:AddToggle("JumpPower", { Title = "JumpPower", Default = false, Callback = function(v) MoveState.JP = v end })
Tabs.Move:AddSlider("JumpPowerVal", { Title = "Jump", Default = 100, Min = 50, Max = 300, Rounding = 0, Callback = function(v) MoveState.JP_Val = v end })
Tabs.Move:AddToggle("InfJump", { Title = "Infinite Jump", Default = false, Callback = function(v) MoveState.IJ = v end })
Tabs.Move:AddToggle("NoClip", { Title = "Smart NoClip", Default = false, Callback = function(v) MoveState.NC = v end })

table.insert(Connections, RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    
    if MoveState.WS and hum.MoveDirection.Magnitude > 0 then
        local extra = (MoveState.WS_Val - 16)
        if extra > 0 then root.CFrame = root.CFrame + (hum.MoveDirection * extra * dt) end
    end
    
    if MoveState.NC then
        for i = 1, #characterParts do
            local part = characterParts[i]
            if part and part.Parent then part.CanCollide = false end
        end
        ncRayParams.FilterDescendantsInstances = {char} 
        ncRayParams.FilterType = Enum.RaycastFilterType.Exclude
        local hit = workspace:Raycast(root.Position, Vector3.new(0, -4, 0), ncRayParams)
        if hit then
            local yVel = root.AssemblyLinearVelocity.Y
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then yVel = 50 elseif yVel < 0 then yVel = 0 end
            local moveVel = hum.MoveDirection * (hum.WalkSpeed > 0 and hum.WalkSpeed or 16)
            root.AssemblyLinearVelocity = Vector3.new(moveVel.X, yVel, moveVel.Z)
        end
    end
end))

table.insert(Connections, UserInputService.JumpRequest:Connect(function()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    if MoveState.JP then root.Velocity = Vector3.new(root.Velocity.X, MoveState.JP_Val, root.Velocity.Z)
    elseif MoveState.IJ then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

-- ==========================================
-- 14. TAB 7: SETTINGS
-- ==========================================
Tabs.Settings:AddButton({
    Title = "Unload Script",
    Callback = function()
        State.isFarming = false
        State.isSelling = false
        for _, conn in ipairs(Connections) do
            if conn.Connected then conn:Disconnect() end
        end
        for _, conn in ipairs(CharConnections) do
            if conn.Connected then conn:Disconnect() end
        end
        table.clear(Connections)
        table.clear(CharConnections)
        Library:Unload()
    end
})

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
InterfaceManager:SetFolder("ProspectingUI")
SaveManager:SetFolder("Prospecting/MidasTouchV29")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
Library:Notify({ Title = "Script Loaded!", Content = "Midas Touch (Ultimate V29)", Duration = 5 })
