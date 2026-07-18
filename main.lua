-- ==============================================================================
-- PROSPECTING! Midas Touch (By Weka)
-- Features: Auto Farm, Movement, Auto Sell, Auto Favourite, Teleport, Server hop, Shop, Settings
-- ==============================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Menghapus UI Lama jika ada
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
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================
-- 0. MEMORY MANAGEMENT & KNIGHTMARE BYPASS (V26)
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
-- Anti-Cheat bypass (kept intact for executor compatibility from DOIT)
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
    SubTitle = "Ultimate V30",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl 
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main ", Icon = "home" }),
    Move = Window:AddTab({ Title = "Movement & Misc ", Icon = "footprints" }),
    Geode = Window:AddTab({ Title = "Geode Farm ", Icon = "gem" }),
    Sell = Window:AddTab({ Title = "Auto Sell ", Icon = "shopping-cart" }),
    Favourite = Window:AddTab({ Title = "Auto Lock ", Icon = "heart" }),
    Shop = Window:AddTab({ Title = "Shop ", Icon = "shopping-cart" }),
    Teleport = Window:AddTab({ Title = "Teleport ", Icon = "map" }),
    Changelog = Window:AddTab({ Title = "Changelog ", Icon = "scroll" }),
    Settings = Window:AddTab({ Title = "Settings ", Icon = "settings" })
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

local cachedInvLabel = nil
local cachedMerchantModel = nil
local cachedMerchantPos = nil
local merchantCacheTime = 0

-- Webhook Vars
local Itemnameandrarity = {}
local LogItems = false
local WebhookLink = ""

-- Auto-Favourite Vars
local autoLockConnections = {}
local pendingLocks = {}

-- Move & Jump Misc
local MoveState = { WS = false, WS_Val = 50, JP = false, JP_Val = 100, IJ = false, NC = false }
local ncRayParams = RaycastParams.new()
local antiAFK = false

-- ==========================================
-- 3. UTILITIES & FUNCTIONS
-- ==========================================
local function simulateMouseDown(guiObject)
    if not guiObject then return end
    local x = guiObject.AbsolutePosition.X + (guiObject.AbsoluteSize.X / 2)
    local y = guiObject.AbsolutePosition.Y + (guiObject.AbsoluteSize.Y / 2)
    VirtualInputManager:SendMouseButtonEvent(x, y + 36, 0, true, guiObject, 1)
end

local function simulateMouseUp(guiObject)
    if not guiObject then return end
    local x = guiObject.AbsolutePosition.X + (guiObject.AbsoluteSize.X / 2)
    local y = guiObject.AbsolutePosition.Y + (guiObject.AbsoluteSize.Y / 2)
    VirtualInputManager:SendMouseButtonEvent(x, y + 36, 0, false, guiObject, 1)
end

local function findPan()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:match("Pan") or tool.Name == "Worldshaker" or tool.Name == "Earthbreaker") then return tool end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:match("Pan") or tool.Name == "Worldshaker" or tool.Name == "Earthbreaker") then return tool end
    end
    return nil
end

local function getInventoryStats()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local invSpace = pgui:FindFirstChild("ToolUI") and pgui.ToolUI:FindFirstChild("FillingPan") and pgui.ToolUI.FillingPan:FindFirstChild("InventorySpace")
        if invSpace and invSpace:IsA("TextLabel") then
            local text = invSpace.Text:gsub("<[^>]->", ""):gsub(",", "")
            local curStr, maxStr = string.match(text, "(%d+)%s*/%s*(%d+)")
            if curStr and maxStr then
                return tonumber(curStr), tonumber(maxStr)
            end
        end
        
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible and (desc.Name == "InventorySpace" or desc.Name == "InventoryText") then
                local text = desc.Text:gsub("<[^>]->", ""):gsub(",", "")
                local curStr, maxStr = string.match(text, "(%d+)%s*/%s*(%d+)")
                if curStr and maxStr then
                    return tonumber(curStr), tonumber(maxStr)
                end
            end
        end
    end

    local maxCapacity = LocalPlayer:GetAttribute("InventorySize") or 500
    local backpackTwo = LocalPlayer:FindFirstChild("BackpackTwo")
    local count = 0
    
    if backpackTwo then
        local items = backpackTwo:GetChildren()
        local charTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if charTool then
            table.insert(items, charTool)
        end
        for _, item in ipairs(items) do
            if item:IsA("Tool") or item:IsA("Model") or item:GetAttribute("ItemType") then
                count = count + 1
            end
        end
    end

    return count, maxCapacity
end

local function getFillLabelText()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    local toolUI = pgui and pgui:FindFirstChild("ToolUI")
    if toolUI then
        local fillingPan = toolUI:FindFirstChild("FillingPan")
        local fillText = fillingPan and fillingPan:FindFirstChild("FillText")
        if fillText and fillText:IsA("TextLabel") then
            return fillText.Text:gsub("<[^>]->", ""):gsub(",", "")
        end
    end
    return nil
end

local function isPanFull()
    local text = getFillLabelText()
    if text then
        local cur, max = string.match(text, "(%d+)%s*/%s*(%d+)")
        if cur and max then return tonumber(cur) >= tonumber(max) end
    end
    
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local mainUI = pgui:FindFirstChild("MainUI")
        local notifications = mainUI and mainUI:FindFirstChild("Notifications")
        if notifications then
            local panFull = notifications:FindFirstChild("Your pan is full! Wash it in nearby water!")
            if panFull and panFull:IsA("GuiObject") and panFull.Visible then
                return true
            end
        end
    end
    
    return false
end

-- ==========================================
-- 4. MOVEMENT UTILITIES (WALK VS LERP)
-- ==========================================
local function walkTo(targetPosition)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root and hum.Health > 0) then return end

    local timeout = 15 
    local startTime = tick()
    
    while tick() - startTime < timeout do
        if not char or hum.Health <= 0 then break end
        local currentPos = root.Position
        local dist = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(targetPosition.X, 0, targetPosition.Z)).Magnitude
        
        if dist <= 3 then break end
        
        hum:MoveTo(targetPosition)
        task.wait(0.1)
    end
end


local merchantData = {
    {Name = "StarterTown Merchant", Path = {"NPCs", "StarterTown", "Merchant"}},
    {Name = "RiverTown Merchant", Path = {"NPCs", "RiverTown", "Merchant"}},
    {Name = "Delta Shady Merchant", Path = {"NPCs", "Delta", "Shady Merchant"}},
    {Name = "Cavern Merchant", Path = {"NPCs", "Cavern", "Merchant"}},
    {Name = "Volcano Merchant", Path = {"NPCs", "Volcano", "Merchant"}}, 
}

local function getAllVolcanoMerchants()
    local volcanoFolder = Workspace:FindFirstChild("NPCs") and Workspace.NPCs:FindFirstChild("Volcano")
    local merchants = {}
    if volcanoFolder then
        for _, obj in ipairs(volcanoFolder:GetChildren()) do
            if obj.Name == "Merchant" and obj:FindFirstChild("HumanoidRootPart") then
                table.insert(merchants, obj)
            end
        end
    end
    return merchants
end

local function getTargetMerchant()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil, 0 end
    
    local selectedMerchant = Options.MerchantSelector and Options.MerchantSelector.Value or "Closest"
    
    if selectedMerchant == "Closest" then
        if cachedMerchantPos and (tick() - merchantCacheTime < 60) then
            return cachedMerchantModel, cachedMerchantPos, (root.Position - cachedMerchantPos).Magnitude
        end
        
        local minDist = math.huge
        local closestModel = nil
        local closestPos = nil
        
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:match("Merchant") or obj.Name:match("Seller")) then
                if not obj.Name:match("Traveling") and not obj.Name:match("Shard") then
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                    if hrp then
                        local dist = (root.Position - hrp.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            closestModel = obj
                            closestPos = hrp.Position
                        end
                    end
                end
            end
        end
        
        if closestModel then
            cachedMerchantModel = closestModel
            cachedMerchantPos = closestPos
            merchantCacheTime = tick()
        end
        return closestModel, closestPos, minDist
    else
        -- Find specific merchant based on DOIT's hardcoded paths
        local targetModel = nil
        local minDistance = math.huge
        local playerPos = root.Position
        
        for _, data in ipairs(merchantData) do
            if data.Name == selectedMerchant then
                if data.Name == "Volcano Merchant" then
                    local volcanoMerchants = getAllVolcanoMerchants()
                    for _, merchant in ipairs(volcanoMerchants) do
                        local dist = (playerPos - merchant.HumanoidRootPart.Position).Magnitude
                        if dist < minDistance then 
                            minDistance = dist
                            targetModel = merchant 
                        end
                    end
                else
                    local merchant = Workspace
                    for _, partName in ipairs(data.Path) do
                        merchant = merchant:FindFirstChild(partName)
                        if not merchant then break end
                    end
                    if merchant and merchant.PrimaryPart then
                        targetModel = merchant
                    elseif merchant and merchant:FindFirstChild("HumanoidRootPart") then
                        targetModel = merchant
                    end
                end
                break
            end
        end
        
        if targetModel then
            local hrp = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChildWhichIsA("BasePart")
            if hrp then
                return targetModel, hrp.Position, (playerPos - hrp.Position).Magnitude
            end
        end
        return nil, nil, 0
    end
end

-- ==========================================
-- 5. AUTO SELL & WEBHOOK LOGIC
-- ==========================================
local function tweenTo(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root then return end
    
    local startPos = root.Position
    local speed = 35
    local distance = (startPos - targetPos).Magnitude
    local duration = math.max(1.0, distance / speed)
    local startTime = tick()
    local arrived = false
    
    if hum then hum.PlatformStand = true end
    
    local originalCollisions = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisions[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    
    local noclipConn
    noclipConn = RunService.Stepped:Connect(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
    
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        local alpha = math.clamp(elapsed / duration, 0, 1)
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = CFrame.new(startPos:Lerp(targetPos, alpha))
        
        if alpha >= 1 then
            arrived = true
            conn:Disconnect()
        end
    end)
    
    while not arrived do task.wait(0.03) end
    
    if noclipConn then noclipConn:Disconnect() end
    for part, state in pairs(originalCollisions) do
        if part and part.Parent then part.CanCollide = state end
    end
    if hum then hum.PlatformStand = false end
end

local function pathfindTo(targetPos)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not root or not humanoid then return end

    local PathfindingService = game:GetService("PathfindingService")
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 4,
        AgentCanJump = true,
        AgentJumpHeight = 10,
        AgentMaxSlope = 45,
        WaypointSpacing = 3
    })
    
    local success, _ = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end
            humanoid:MoveTo(waypoint.Position)
            
            local timeout = tick() + 2
            while tick() < timeout do
                local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(waypoint.Position.X, 0, waypoint.Position.Z)).Magnitude
                if dist < 2 then break end
                task.wait(0.05)
            end
        end
    else
        tweenTo(targetPos)
    end
end

local function shouldAutoSell()
    if not Options.AutoSellToggle or not Options.AutoSellToggle.Value then return false end
    
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        -- 1. Cek notifikasi di MainUI
        local mainUI = pgui:FindFirstChild("MainUI")
        local notifications = mainUI and mainUI:FindFirstChild("Notifications")
        if notifications then
            local backpackFull = notifications:FindFirstChild("Your backpack is full!")
            if backpackFull and backpackFull:IsA("GuiObject") and backpackFull.Visible then
                return true
            end
            
            -- Cek juga anak-anak lain di dalam Notifications, siapa tahu teksnya sedikit berbeda
            for _, child in ipairs(notifications:GetChildren()) do
                if child:IsA("TextLabel") and child.Visible then
                    local text = string.lower(child.Text:gsub("<[^>]->", ""))
                    if string.find(text, "backpack is full") then
                        return true
                    end
                end
            end
        end

        -- 2. Fallback cek di ToolUI (jika gamenya menggunakan UI lama)
        local toolUI = pgui:FindFirstChild("ToolUI")
        local fillingPan = toolUI and toolUI:FindFirstChild("FillingPan")
        if fillingPan then
            local backpackFullOld = fillingPan:FindFirstChild("BackpackFull")
            if backpackFullOld and backpackFullOld:IsA("GuiObject") and backpackFullOld.Visible then
                return true
            end
            
            for _, child in ipairs(fillingPan:GetChildren()) do
                if child:IsA("TextLabel") and child.Visible then
                    local text = child.Text:gsub("<[^>]->", "")
                    if string.find(string.lower(text), "backpack is full") or string.find(string.lower(text), "full") then
                        return true
                    end
                end
            end
        end
    end
    
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
local MAX_SELL_RETRIES = 3

local function doSellTrip(originalCFrame, merchantModel, merchantPos, needToMove, moveMethod, safePos)
    local spamConnection
    spamConnection = RunService.Heartbeat:Connect(function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hasGamepass = Options.HasSellAnywhere and Options.HasSellAnywhere.Value
        if root and ((root.Position - merchantPos).Magnitude <= 49.9 or hasGamepass) then
            pcall(function()
                local shopFolder = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Shop")
                local sellRemote = shopFolder and shopFolder:FindFirstChild("SellAll")
                if sellRemote then
                    if sellRemote:IsA("RemoteFunction") then 
                        sellRemote:InvokeServer()
                    elseif sellRemote:IsA("RemoteEvent") then 
                        sellRemote:FireServer() 
                    end
                end
            end)
        end
    end)
    
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then 
        if spamConnection then spamConnection:Disconnect() end
        return 
    end
    root.Anchored = false
    
    if needToMove then
        if moveMethod == "Instant (TP)" then
            root.CFrame = CFrame.new(safePos)
            task.wait(1.5)
        elseif moveMethod == "Tween" then
            tweenTo(safePos)
            task.wait(1.5)
        elseif moveMethod == "PathFind" then
            pathfindTo(safePos)
            task.wait(1.5)
        else
            walkTo(safePos)
            task.wait(1.5)
        end
        
        if moveMethod == "Instant (TP)" then
            root.CFrame = originalCFrame
            root.Anchored = true
            task.wait(0.1)
            root.Anchored = false
        elseif moveMethod == "Tween" then
            tweenTo(originalCFrame.Position)
        elseif moveMethod == "PathFind" then
            pathfindTo(originalCFrame.Position)
        else
            walkTo(originalCFrame.Position)
        end
    else
        task.wait(1.5)
    end
    
    if spamConnection then spamConnection:Disconnect() end
end

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
        local merchantModel, merchantPos, merchantDist = getTargetMerchant()
        
        if not merchantPos then
            Library:Notify({ Title = "Sell Error", Content = "Merchant tidak ditemukan!", Duration = 4 })
            return
        end
        
        local hasGamepass = Options.HasSellAnywhere and Options.HasSellAnywhere.Value
        local needToMove = (merchantDist > 45) and not hasGamepass
        local moveMethod = Options.SellMoveMethod and Options.SellMoveMethod.Value or "Instant (TP)"
        
        local safePos
        if merchantModel and merchantModel:FindFirstChild("HumanoidRootPart") then
            safePos = (merchantModel.HumanoidRootPart.CFrame * CFrame.new(3, 1, 0)).Position
        else
            safePos = merchantPos + Vector3.new(3, 1, 0)
        end
        
        local invBefore = getInventoryStats()
        
        for attempt = 1, MAX_SELL_RETRIES do
            doSellTrip(originalCFrame, merchantModel, merchantPos, needToMove, moveMethod, safePos)
            
            task.wait(0.5)
            local invAfter = getInventoryStats()
            
            if invAfter < invBefore then
                Library:Notify({ Title = "Sell Success", Content = "Berhasil menjual! (" .. invBefore .. "  " .. invAfter .. ")", Duration = 3 })
                break
            end
            
            if attempt < MAX_SELL_RETRIES then
                warn("[SELL RETRY] Attempt " .. attempt .. " gagal, inventory belum berkurang. Retry...")
                task.wait(1)
            else
                warn("[SELL FAILED] Gagal menjual setelah " .. MAX_SELL_RETRIES .. " percobaan.")
                Library:Notify({ Title = "Sell Failed", Content = "Gagal menjual setelah " .. MAX_SELL_RETRIES .. "x percobaan!", Duration = 5 })
            end
        end
        
        -- Discord Webhook
        if LogItems and WebhookLink ~= "" then
            pcall(function()
                request({
                    Url = WebhookLink,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({content = "Auto-sold inventory to merchant.", username = "Midas Touch Webhook"})
                })
            end)
        end
    end)
    
    State.isSelling = false
    if not success then warn("[SELL ERROR] " .. tostring(err)) end
end

-- ==========================================
-- 6. AUTO FAVOURITE LOGIC (V27 FIXED)
-- ==========================================

local function scanAndLockBackpack()
    -- Fitur ini dikosongkan untuk dibangun ulang dari 0 nanti
end

-- Loop Anti-Deadlock untuk Lock
task.spawn(function()
    while task.wait(0.5) do
        if Options.AutoFavoriteToggle and Options.AutoFavoriteToggle.Value then
            scanAndLockBackpack()
        end
    end
end)

-- ==========================================
-- 7. FAST MODE CORE LOOP (DOIT)
-- ==========================================

local function dig()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    
    local method = Options.AutoFarmMethod and Options.AutoFarmMethod.Value or "Fast"
    if method == "Legit" then
        if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(State.digLocation.X, 0, State.digLocation.Z)).Magnitude > 3 then
            walkTo(State.digLocation)
            task.wait(0.1)
        end
    else
        if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(State.digLocation.X, 0, State.digLocation.Z)).Magnitude > 3 then
            root.CFrame = CFrame.new(State.digLocation)
            task.wait(0.3)
        end
    end
    
    local panTool = findPan()
    if not panTool then task.wait(1); return end
    
    if panTool.Parent == LocalPlayer.Backpack then
        humanoid:EquipTool(panTool)
        task.wait(0.05)
    end
    
    local equippedPan = char:FindFirstChild(panTool.Name)
    if not equippedPan then task.wait(0.1); return end
    
    local fillBar
    for i = 1, 15 do
        fillBar = LocalPlayer.PlayerGui:FindFirstChild("ToolUI", true)
            and LocalPlayer.PlayerGui.ToolUI:FindFirstChild("FillingPan", true)
            and LocalPlayer.PlayerGui.ToolUI.FillingPan:FindFirstChild("Bar")
        if fillBar then break end
        task.wait(0.1)
    end

    if not fillBar then task.wait(0.5); return end

    if method == "Fast" then
        local collectButton
        for i = 1, 10 do
            collectButton = LocalPlayer.PlayerGui:FindFirstChild("ToolUI", true)
                and LocalPlayer.PlayerGui.ToolUI:FindFirstChild("Controls")
                and LocalPlayer.PlayerGui.ToolUI.Controls:FindFirstChild("Collect Deposit")
            if collectButton then break end
            task.wait(0.1)
        end

        local scriptsFolder = equippedPan:FindFirstChild("Scripts")
        local collectRemote = scriptsFolder and scriptsFolder:FindFirstChild("Collect")
        
        if collectButton and collectRemote then
            simulateMouseDown(collectButton)
            while fillBar.Size.X.Scale < 1 and State.isFarming do
                local success_collect = pcall(function() collectRemote:InvokeServer(1) end)
                task.wait(0.1)
                if not success_collect then task.wait(0.1) end
                if not (char and char.Parent and equippedPan and equippedPan.Parent) then break end
            end
            simulateMouseUp(collectButton)
        end
    else
        -- Legit Dig Method (Tahan sampai full tanpa putus)
        while fillBar.Size.X.Scale < 1 and State.isFarming do
            local digBar = LocalPlayer.PlayerGui:FindFirstChild("ToolUI", true)
                and LocalPlayer.PlayerGui.ToolUI:FindFirstChild("DigBar", true)
            if not digBar then break end
            
            simulateMouseDown(digBar)
            local digBarLine
            local perfectZone
            local wait_started = tick()
            local panBecameFull = false
            while (tick() - wait_started) < 2.0 and not (digBarLine and digBarLine.Visible and perfectZone and perfectZone.Visible) do
                if fillBar.Size.X.Scale >= 1 then panBecameFull = true; break end
                digBarLine = digBar:FindFirstChild("Line")
                if not perfectZone then
                    for _, child in ipairs(digBar:GetChildren()) do
                        if child:IsA("Frame") and child.BackgroundColor3.G > 0.5 and child.BackgroundColor3.R < 0.3 and child.BackgroundColor3.B < 0.3 then
                            perfectZone = child
                            break
                        end
                    end
                end
                task.wait(0.05)
            end
            if not panBecameFull and digBarLine and digBarLine.Visible and perfectZone and perfectZone.Visible then
                local topY = perfectZone.Position.Y.Scale
                local bottomY = topY + perfectZone.Size.Y.Scale
                local timing_started = tick()
                while (tick() - timing_started) < 3 and State.isFarming do
                    if fillBar.Size.X.Scale >= 1 then panBecameFull = true; break end
                    if not (digBarLine and digBarLine.Visible) then break end
                    if digBarLine.Position.Y.Scale >= topY and digBarLine.Position.Y.Scale <= bottomY then break end
                    task.wait(0.01)
                end
            end
            simulateMouseUp(digBar)
            task.wait(0.05)
        end
    end
    task.wait(0.08)
end

local function pan()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    
    local method = Options.AutoFarmMethod and Options.AutoFarmMethod.Value or "Fast"
    if method == "Legit" then
        if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(State.panLocation.X, 0, State.panLocation.Z)).Magnitude > 3 then
            walkTo(State.panLocation)
            task.wait(0.1)
        end
    else
        if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(State.panLocation.X, 0, State.panLocation.Z)).Magnitude > 3 then
            root.CFrame = CFrame.new(State.panLocation)
            task.wait(0.3)
        end
    end
    
    local panTool = findPan()
    if not panTool then task.wait(1); return end
    
    if panTool.Parent == LocalPlayer.Backpack then
        humanoid:EquipTool(panTool)
        task.wait(0.05)
    end
    
    local equippedPan = char:FindFirstChild(panTool.Name)
    if not equippedPan then task.wait(0.1); return end

    local fillBar
    for i = 1, 15 do
        fillBar = LocalPlayer.PlayerGui:FindFirstChild("ToolUI", true)
            and LocalPlayer.PlayerGui.ToolUI:FindFirstChild("FillingPan", true)
            and LocalPlayer.PlayerGui.ToolUI.FillingPan:FindFirstChild("Bar")
        if fillBar then break end
        task.wait(0.1)
    end
        
    if not fillBar then task.wait(0.5); return end
        
    local scriptsFolder = equippedPan:FindFirstChild("Scripts")
    if scriptsFolder then
        local shakeRemote = scriptsFolder:FindFirstChild("Shake")
        local panRemote = scriptsFolder:FindFirstChild("Pan")
        
        if shakeRemote then
            local panGUI
            for i = 1, 20 do
                panGUI = LocalPlayer.PlayerGui:FindFirstChild("ToolUI", true) 
                    and LocalPlayer.PlayerGui.ToolUI:FindFirstChild("Controls")
                    and LocalPlayer.PlayerGui.ToolUI.Controls:FindFirstChild("Pan")
                if panGUI then break end
                task.wait(0.1)
            end
            
            if panGUI then
                task.spawn(function() pcall(function() panRemote:InvokeServer() end) end)
                task.wait(0.1)
                
                while State.isFarming do
                    local controls = LocalPlayer.PlayerGui:FindFirstChild("ToolUI") 
                        and LocalPlayer.PlayerGui.ToolUI:FindFirstChild("Controls")
                    
                    if not controls then break end
                    
                    local success_shake = pcall(function() shakeRemote:FireServer() end)
                    task.wait(0.1) 
                    
                    if not success_shake then task.wait(0.1) end
                    if not (char and char.Parent and equippedPan and equippedPan.Parent) then break end
                    if not fillBar or not fillBar.Parent then break end
                    if fillBar.Size.X.Scale <= 0 then break end
                end
            end
        end
    end
    
    task.wait(0.08)
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
                
                -- Pastikan selalu megang pan agar script bisa membaca indikator UI pasir
                local panTool = findPan()
                if panTool and panTool.Parent == LocalPlayer.Backpack then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then 
                        hum:EquipTool(panTool)
                        task.wait(0.2) 
                    end
                end
                
                if shouldAutoSell() then
                    task.spawn(function()
                        -- Matikan toggle UI Auto Farm
                        Options.AutoFarmToggle:SetValue(false)
                        task.wait(0.5)
                        
                        -- Jalankan proses jual beli sampai kembali
                        instantSellAll()
                        
                        -- Nyalakan lagi toggle UI Auto Farm
                        Options.AutoFarmToggle:SetValue(true)
                    end)
                    break -- Matikan thread loop Auto Farm yang sedang berjalan saat ini
                end
                
                if not isPanFull() then
                    dig()
                else
                    pan()
                end
            end
        end)
    end
end

-- ==========================================
-- 8. TAB 1: MAIN (FARMING)
-- ==========================================
Tabs.Main:AddToggle("AutoFarmToggle", { Title = "Auto Farm", Description = "Auto Farm All", Default = false, Callback = toggleAutoFarm })

Tabs.Main:AddDropdown("AutoFarmMethod", { Title = "Auto Farm Method", Values = {"Legit", "Fast"}, Default = "Fast", Multi = false })

local waterStr = "Not set"
local sandStr = "Not set"
-- Placeholder agar bisa diubah isinya nanti, UI-nya ditaruh di bawah
local locPara = nil

Tabs.Main:AddButton({
    Title = " Set Water Location",
    Description = "Save current position for Panning",
    Callback = function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            State.panLocation = root.Position
            waterStr = string.format("X: %.1f, Y: %.1f, Z: %.1f", root.Position.X, root.Position.Y, root.Position.Z)
            if locPara then locPara:SetDesc(string.format(" Water: %s\n Sand: %s", waterStr, sandStr)) end
            Library:Notify({ Title = "Success", Content = "Water location saved!", Duration = 3 })
        end
    end
})

Tabs.Main:AddButton({
    Title = " Set Sand Location",
    Description = "Save current position for Digging",
    Callback = function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            State.digLocation = root.Position
            sandStr = string.format("X: %.1f, Y: %.1f, Z: %.1f", root.Position.X, root.Position.Y, root.Position.Z)
            if locPara then locPara:SetDesc(string.format(" Water: %s\n Sand: %s", waterStr, sandStr)) end
            Library:Notify({ Title = "Success", Content = "Dig location saved!", Duration = 3 })
        end
    end
})

local function autoDetectLocations()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local function getClosest(folderName)
        local folder = workspace:FindFirstChild(folderName)
        if not folder then return nil end

        local closest = nil
        local shortestDist = math.huge

        for _, desc in ipairs(folder:GetDescendants()) do
            if desc:IsA("BasePart") then
                local dist = (desc.Position - root.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closest = desc.Position
                end
            end
        end
        return closest
    end

    local nearestSand = getClosest("Deposits")
    local nearestWater1 = getClosest("Water")
    local nearestWater2 = getClosest("Rivers")

    local nearestWater = nil
    local rootPos = root.Position
    if nearestWater1 and nearestWater2 then
        if (nearestWater1 - rootPos).Magnitude < (nearestWater2 - rootPos).Magnitude then
            nearestWater = nearestWater1
        else
            nearestWater = nearestWater2
        end
    elseif nearestWater1 then
        nearestWater = nearestWater1
    else
        nearestWater = nearestWater2
    end

    if nearestSand then
        State.digLocation = nearestSand
        sandStr = string.format("X: %.1f, Y: %.1f, Z: %.1f (Auto)", nearestSand.X, nearestSand.Y, nearestSand.Z)
    end
    
    if nearestWater then
        State.panLocation = nearestWater
        waterStr = string.format("X: %.1f, Y: %.1f, Z: %.1f (Auto)", nearestWater.X, nearestWater.Y, nearestWater.Z)
    end

    if locPara then locPara:SetDesc(string.format(" Water: %s\n Sand: %s", waterStr, sandStr)) end
    
    if nearestSand and nearestWater then
        Library:Notify({ Title = "Success", Content = "Auto-detected nearby Water & Sand!", Duration = 4 })
    elseif nearestSand then
        Library:Notify({ Title = "Partial", Content = "Found Sand, but no Water nearby.", Duration = 4 })
    elseif nearestWater then
        Library:Notify({ Title = "Partial", Content = "Found Water, but no Sand nearby.", Duration = 4 })
    else
        Library:Notify({ Title = "Failed", Content = "No Water or Sand found nearby!", Duration = 4 })
    end
end

Tabs.Main:AddButton({
    Title = " Auto Detect Nearby Locations",
    Description = "Scan for closest water and sand automatically",
    Callback = autoDetectLocations
})

locPara = Tabs.Main:AddParagraph({ Title = " Saved Locations", Content = " Water: Not set\n Sand: Not set" })

-- ==========================================
-- 9. TAB 2: AUTO-SELL
-- ==========================================
Tabs.Sell:AddToggle("HasSellAnywhere", { Title = "Has 'Sell Anywhere' Gamepass", Default = false })
Tabs.Sell:AddToggle("AutoSellToggle", { Title = "Enable Auto Sell", Default = true })

Tabs.Sell:AddDropdown("MerchantSelector", {
    Title = "Select Merchant",
    Values = {"Closest", "StarterTown Merchant", "RiverTown Merchant", "Delta Shady Merchant", "Cavern Merchant", "Volcano Merchant"},
    Multi = false,
    Default = 1,
})

Tabs.Sell:AddButton({
    Title = "Refresh Nearest Merchant",
    Description = "Memaksa pencarian ulang merchant terdekat",
    Callback = function()
        cachedMerchantModel = nil
        cachedMerchantPos = nil
        merchantCacheTime = 0
        local m, p, d = getTargetMerchant()
        if m then
            Library:Notify({ Title = "Refreshed", Content = "Merchant terdekat: " .. m.Name .. "\nJarak: " .. math.round(d) .. " studs", Duration = 3 })
        else
            Library:Notify({ Title = "Not Found", Content = "Tidak ada merchant di sekitarmu!", Duration = 3 })
        end
    end
})

Tabs.Sell:AddDropdown("SellMoveMethod", {
    Title = "Metode Pergerakan Jual",
    Values = {"Instant (TP)", "Tween", "Walk", "PathFind"},
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
            task.wait(0.5)
            instantSellAll()
            if wasFarming then Options.AutoFarmToggle:SetValue(true) end
        end)
    end 
})

-- ==========================================
-- 10. TAB 3: FAVOURITE (AUTO-LOCK)
-- ==========================================
-- UI dinonaktifkan sementara dan akan dibangun ulang dari 0

-- ==========================================
-- 11. TAB 4: SHOP (REMOTE)
-- ==========================================
-- Fitur Shop dinonaktifkan sementara dan akan dibangun ulang dari 0

-- ==========================================
-- 12. TAB 5: TELEPORT & SERVER HOP
-- ==========================================
-- Fitur Teleport dinonaktifkan sementara dan akan dibangun ulang dari 0

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

Tabs.Move:AddInput("DiscordWebhook", {
    Title = "Discord Webhook URL",
    Default = "",
    Numeric = false,
    Finished = false,
    Callback = function(v) WebhookLink = v end
})

Tabs.Move:AddToggle("LogItemsToDiscord", { Title = "Log Locked/Sold Items to Discord", Default = false, Callback = function(v) LogItems = v end })

-- ==========================================
-- 14. TAB 7: GEODE FARM
-- ==========================================
local autoCollectGeodes = false
Tabs.Geode:AddToggle("AutoCollectGeodes", { 
    Title = "Auto Collect Geodes", 
    Description = "Otomatis mengambil semua Geode yang muncul",
    Default = false, 
    Callback = function(v) 
        autoCollectGeodes = v 
    end 
})

local geodeCollectMethod = "Teleport Player"
Tabs.Geode:AddDropdown("GeodeCollectMethod", {
    Title = "Metode Ambil Geode",
    Values = {"Teleport Player", "Bring Geode"},
    Multi = false,
    Default = 1,
    Callback = function(v) geodeCollectMethod = v end
})

task.spawn(function()
    while true do
        task.wait(0.2)
        if autoCollectGeodes then
            local geodeFolder = workspace:FindFirstChild("Geode")
            if geodeFolder then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local geodesFound = {}
                    for _, geodeModel in ipairs(geodeFolder:GetChildren()) do
                        local part = geodeModel:IsA("BasePart") and geodeModel or geodeModel:FindFirstChildWhichIsA("BasePart")
                        if part then
                            table.insert(geodesFound, part)
                        end
                    end
                    
                    if #geodesFound > 0 then
                        if geodeCollectMethod == "Teleport Player" then
                            local originalCFrame = root.CFrame
                            for _, part in ipairs(geodesFound) do
                                root.CFrame = part.CFrame
                                task.wait(0.15)
                                if firetouchinterest then
                                    firetouchinterest(root, part, 0)
                                    firetouchinterest(root, part, 1)
                                end
                            end
                            root.CFrame = originalCFrame
                        else
                            for _, part in ipairs(geodesFound) do
                                part.CFrame = root.CFrame
                                if firetouchinterest then
                                    firetouchinterest(root, part, 0)
                                    firetouchinterest(root, part, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

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
-- 14. TAB: CHANGELOG & SETTINGS
-- ==========================================
Tabs.Changelog:AddParagraph({
    Title = "V30 - Polish Update (18 Juli 2026)",
    Content = "1. shouldAutoSell scan dioptimasi (langsung target FillingPan).\n2. Sell Retry Verification: otomatis retry maks 3x jika gagal jual.\n3. tweenTo kini memiliki Noclip bawaan.\n4. Dead code dihapus (dynamicLerpTo, equipTool).\n5. Duplikat variabel (VirtualUser, pendingLocks) dibersihkan.\n6. Noclip redundan di Auto Sell dihapus.\n7. Script lebih ringan (1170 > 1141 baris)."
})

Tabs.Changelog:AddParagraph({
    Title = "V29.3 - Hotfix (18 Juli 2026, 01:03)",
    Content = "1. Memperbaiki crash 'attempt to call a nil value' - fungsi tweenTo & pathfindTo tidak sengaja terhapus saat refactor.\n2. Auto Farm ikut mati karena Auto Sell crash (efek domino) - sudah diperbaiki."
})

Tabs.Changelog:AddParagraph({
    Title = "V29.2 - Inventory Fix (18 Juli 2026, 00:55)",
    Content = "1. Fix pembacaan inventory langsung dari InventorySpace TextLabel.\n2. Auto Sell tidak lagi salah baca angka Pan Fill sebagai Inventory."
})

Tabs.Changelog:AddParagraph({
    Title = "V29.1 - Syntax Fix (18 Juli 2026, 00:27)",
    Content = "1. Fix Syntax Error pada single-line if-elseif yang menyebabkan script gagal di-execute di beberapa executor."
})

Tabs.Changelog:AddParagraph({
    Title = "V29 - PathFind & Unified Sell (17 Juli 2026)",
    Content = "1. Menambahkan metode PathFind (AI Pathfinding) ke Auto Sell.\n2. Semua metode pergerakan (TP, Tween, Walk, PathFind) kini berlaku untuk Auto Sell dan Sell All Now.\n3. Sistem spam SellAll saat memasuki area 49.9 studs dari merchant.\n4. Fix bug PathFind & Walk gagal karena karakter terkunci (Anchored)."
})

Tabs.Changelog:AddParagraph({
    Title = "V28 - Tween Flyby Sell (17 Juli 2026)",
    Content = "1. Logika Tween Flyby: spam trigger SellAll saat melewati area merchant.\n2. Dropdown metode pergerakan jual (Instant TP, Tween, Walk).\n3. Anti-Cheat Knightmare bypass ditingkatkan."
})

Tabs.Changelog:AddParagraph({
    Title = "V27 - Auto Lock & Movement (16 Juli 2026)",
    Content = "1. Tab Auto Lock (Favourite) ditambahkan.\n2. WalkSpeed, JumpPower, Infinite Jump, Smart NoClip.\n3. Anti-AFK system.\n4. Discord Webhook logging."
})

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
SaveManager:SetFolder("Prospecting/MidasTouchV30")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

Library:Notify({ Title = "Script Loaded!", Content = "Midas Touch (By Weka)", Duration = 5 })
