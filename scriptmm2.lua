local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- =========================================
-- НАСТРОЙКИ ESP
-- =========================================
local ESP_Settings = {
    Murderer = { Enabled = false, Name = true, Dist = true, Box = true, Tracer = true, Color = Color3.fromRGB(255, 0, 0) },
    Sheriff = { Enabled = false, Name = true, Dist = true, Box = true, Tracer = true, Color = Color3.fromRGB(0, 150, 255) },
    Hero = { Enabled = false, Name = true, Dist = true, Box = true, Tracer = true, Color = Color3.fromRGB(255, 165, 0) }, -- Оранжевый для Героя
    Innocent = { Enabled = false, Name = true, Dist = true, Box = true, Tracer = true, Color = Color3.fromRGB(0, 255, 0) },
    Lobby = { Enabled = false, Name = true, Dist = true, Box = true, Tracer = true, Color = Color3.fromRGB(150, 150, 150) },
    Gun = { Enabled = false, Color = Color3.fromRGB(255, 255, 0) }
}
local ESP_Objects = {}

local function IsInLobby(player)
    local lobby = workspace:FindFirstChild("Lobby")
    local char = player.Character
    if lobby and char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local lobbySpawn = lobby:FindFirstChild("SpawnLocation") or lobby:FindFirstChildWhichIsA("BasePart")
            if lobbySpawn then return (root.Position - lobbySpawn.Position).Magnitude <= 1000 end
            return (root.Position - lobby.Position).Magnitude <= 1000
        end
    end
    return false
end

local function ClearESP()
    for _, obj in pairs(ESP_Objects) do
        for _, drawing in pairs(obj) do pcall(function() drawing:Remove() end) end
    end
    ESP_Objects = {}
end

local function CreateESPForPlayer(player, role)
    local settings = ESP_Settings[role]
    if not settings then return end
    if role ~= "Lobby" and not settings.Enabled then return end
    if role == "Lobby" and not ESP_Settings.Lobby.Enabled then return end

    ESP_Objects[player] = {
        Box = settings.Box and Drawing.new("Square") or nil,
        Name = settings.Name and Drawing.new("Text") or nil,
        Dist = settings.Dist and Drawing.new("Text") or nil,
        Tracer = settings.Tracer and Drawing.new("Line") or nil
    }
    local esp = ESP_Objects[player]
    if esp.Box then esp.Box.Thickness = 1; esp.Box.Color = settings.Color; esp.Box.Filled = false end
    if esp.Name then esp.Name.Size = 14; esp.Name.Center = true; esp.Name.Outline = true; esp.Name.Color = settings.Color end
    if esp.Dist then esp.Dist.Size = 12; esp.Dist.Center = true; esp.Dist.Outline = true; esp.Dist.Color = Color3.new(1, 1, 1) end
    if esp.Tracer then esp.Tracer.Thickness = 1; esp.Tracer.Color = settings.Color end
end

local function UpdateESP()
    -- Отрисовка игроков
    for player, esp in pairs(ESP_Objects) do
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            for _, drawing in pairs(esp) do if drawing then drawing.Visible = false end end
            continue
        end
        local root = player.Character.HumanoidRootPart
        local head = player.Character:FindFirstChild("Head") or root
        local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude) or 0
        local vector, onScreen = Camera:WorldToViewportPoint(root.Position)
        
        if onScreen then
            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
            local height = math.abs(headPos.Y - legPos.Y)
            local width = height / 2
            if esp.Box then esp.Box.Visible = true; esp.Box.Size = Vector2.new(width, height); esp.Box.Position = Vector2.new(vector.X - width/2, vector.Y - height/2) end
            if esp.Name then esp.Name.Visible = true; esp.Name.Position = Vector2.new(vector.X, vector.Y - height/2 - 15); esp.Name.Text = player.Name end
            if esp.Dist then esp.Dist.Visible = true; esp.Dist.Position = Vector2.new(vector.X, vector.Y + height/2 + 5); esp.Dist.Text = math.floor(distance) .. "m" end
            if esp.Tracer then esp.Tracer.Visible = true; esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y); esp.Tracer.To = Vector2.new(vector.X, vector.Y + height/2) end
        else
            for _, drawing in pairs(esp) do if drawing then drawing.Visible = false end end
        end
    end
    
    -- Отрисовка пистолета (GunPrompt)
    if ESP_Settings.Gun.Enabled then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Parent and (obj.Parent.Name == "GunPrompt" or obj.Parent.Name == "Gun" or obj.Parent.Name == "Revolver") then
                local part = obj.Parent
                if part:IsA("BasePart") then
                    local vector, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local hl = part:FindFirstChild("GunESP") or Instance.new("Highlight")
                        hl.Name = "GunESP"
                        hl.FillColor = ESP_Settings.Gun.Color
                        hl.OutlineColor = ESP_Settings.Gun.Color
                        hl.FillTransparency = 0.5
                        hl.Parent = part
                    end
                end
            end
        end
    end
end

-- Логика ролей
task.spawn(function()
    while task.wait(0.2) do
        ClearESP()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if IsInLobby(player) then
                    if ESP_Settings.Lobby.Enabled then
                        CreateESPForPlayer(player, "Lobby")
                    end
                else
                    local isMurderer, isSheriff, isHero = false, false, false
                    local charTool = player.Character:FindFirstChildOfClass("Tool")
                    local backpack = player:FindFirstChild("Backpack")
                    
                    local function HasTool(name)
                        if charTool and charTool.Name == name then return true end
                        if backpack and backpack:FindFirstChild(name) then return true end
                        return false
                    end

                    if HasTool("Knife") then isMurderer = true end
                    if HasTool("Gun") or HasTool("Revolver") then
                        -- Проверяем, Шериф это или Герой
                        if player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Sheriff") then
                            isSheriff = true
                        else
                            isHero = true
                        end
                    end
                    
                    if isMurderer then CreateESPForPlayer(player, "Murderer")
                    elseif isSheriff then CreateESPForPlayer(player, "Sheriff")
                    elseif isHero then CreateESPForPlayer(player, "Hero")
                    else CreateESPForPlayer(player, "Innocent") end
                end
            end
        end
    end
end)
RunService.RenderStepped:Connect(UpdateESP)
local function AutoFarmLoop()
    local originalGravity = workspace.Gravity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.P = 1000 
    bv.Parent = GetRoot()
    
    local NoCoinsTimer = tick()
    local IgnoredCoins = {}
    local IsPaused = false
    local HasSeenCoin = false 
    local IsDead = false
    local LastActionTime = tick()
    local LastPosition = GetRoot() and GetRoot().Position or Vector3.zero

    while AutoFarm_Active do
        task.wait(0.05)
        local root = GetRoot()
        local humanoid = GetChar() and GetChar():FindFirstChildOfClass("Humanoid")
        
        if not root or (humanoid and humanoid.Health <= 0) then
            IsDead = true; HasSeenCoin = false; NoCoinsTimer = tick()
            bv.Velocity = Vector3.zero; task.wait(0.5); continue
        else
            IsDead = false
        end

        if not bv.Parent then bv.Parent = root end

        local myTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
        local hasGun = myTool and (myTool.Name == "Gun" or myTool.Name == "Revolver")

        -- ЛОГИКА: Если сумка полная
        if IsBagFull() and FarmDeath_Active then
            if myTool and myTool.Name == "Knife" then
                -- Мы убийца
                if not KillAll_Active then KillAll_Active = true; task.spawn(KillAllLoop) end
            elseif hasGun then
                -- Мы шериф: идем убивать
                local murderer = GetMurderer()
                if murderer then
                    local targetRoot = murderer:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        bv.Velocity = Vector3.zero
                        root.CFrame = CFrame.new(targetRoot.Position - (targetRoot.CFrame.LookVector * 10), targetRoot.Position)
                        myTool:Activate()
                    end
                end
            else
                -- Мы невиновный
                if tick() - NoCoinsTimer > 5 then
                    if humanoid then humanoid.Health = 0 end
                    NoCoinsTimer = tick()
                end
            end
            task.wait(0.2)
            continue
        end

        local coinFolder = workspace:FindFirstChild("CoinContainer", true)
        if not coinFolder then continue end

        if not IsInLobby(LocalPlayer) then
            local isMoving = (root.Position - LastPosition).Magnitude > 1
            local isSearching = (bv.Velocity.Magnitude > 1 or isMoving)
            if not isSearching and tick() - LastActionTime > 0.5 then
                HasSeenCoin = false; IgnoredCoins = {}
                bv.Velocity = Vector3.new(0, 50, 0); task.wait(0.2)
                LastActionTime = tick()
            elseif isSearching then
                LastActionTime = tick()
            end
        end
        LastPosition = root.Position

        if IsInLobby(LocalPlayer) then
            IsPaused = true; bv.Velocity = Vector3.zero; NoCoinsTimer = tick(); task.wait(0.5); continue
        else
            IsPaused = false
        end

        -- Логика поиска монет (если сумка не полная)
        local nearestCoin = nil
        local minDist = math.huge

        for _, coin in ipairs(coinFolder:GetChildren()) do
            if coin.Name == "Coin_Server" and coin:IsA("BasePart") and not IgnoredCoins[coin] then
                local dist = (coin.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; nearestCoin = coin end
            end
        end

        if nearestCoin then
            HasSeenCoin = true; NoCoinsTimer = tick()
            local coinCollectedEvent = nearestCoin:FindFirstChild("CoinCollected") 
            if coinCollectedEvent and coinCollectedEvent:IsA("BindableEvent") then
                coinCollectedEvent.Event:Connect(function() IgnoredCoins[nearestCoin] = true end)
            end
        end

        if not nearestCoin and HasSeenCoin and not IsDead and not IsPaused and FarmDeath_Active and not IsBagFull() then
            if tick() - NoCoinsTimer > 5 then
                if myTool and myTool.Name == "Knife" then
                    if not KillAll_Active then KillAll_Active = true; task.spawn(KillAllLoop) end
                else
                    if humanoid then humanoid.Health = 0 end
                end
                HasSeenCoin = false; NoCoinsTimer = tick()
            end
        end

        if nearestCoin then
            if AutoFarmMode == "Smooth" then
                workspace.Gravity = 0
                if minDist <= 1 then
                    IgnoredCoins[nearestCoin] = true; bv.Velocity = Vector3.zero
                else
                    local dir = (nearestCoin.Position - root.Position).Unit
                    bv.Velocity = dir * 20
                end
            else
                bv.Velocity = Vector3.zero
                workspace.Gravity = originalGravity
                if nearestCoin.Parent and minDist > 1 then
                    local centerPos = nearestCoin.Position
                    root.CFrame = CFrame.new(centerPos)
                    local angle = 0
                    local orbitConn
                    orbitConn = RunService.Heartbeat:Connect(function(dt)
                        angle = angle + (dt * 2.5) 
                        local offsetX = math.cos(angle) * 1
                        local offsetY = math.sin(angle) * 1
                        local offsetZ = math.sin(angle) * 1
                        root.CFrame = CFrame.new(centerPos + Vector3.new(offsetX, offsetY, offsetZ))
                        root.AssemblyLinearVelocity = Vector3.zero
                    end)
                    task.spawn(function()
                        task.wait(0.1); root.AssemblyLinearVelocity = Vector3.new(0, 15, 0)
                        task.wait(0.1); root.AssemblyLinearVelocity = Vector3.new(0, -15, 0)
                    end)
                    task.wait(1.1)
                    if orbitConn then orbitConn:Disconnect() end
                    IgnoredCoins[nearestCoin] = true
                end
            end
        else
            bv.Velocity = Vector3.zero
        end
    end
    workspace.Gravity = originalGravity
    bv:Destroy()
end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_Multi"; ScreenGui.ResetOnSpawn = false; ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 300, 0, 400); Main.Position = UDim2.new(0.5, -150, 0.5, -200)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20); Main.BorderSizePixel = 2; Main.BorderColor3 = Color3.fromRGB(100, 0, 0)
Main.Active = true; Main.Draggable = true; Main.Parent = ScreenGui
local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0, 8); UICorner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30); Title.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
Title.Text = "MM2 Multi-Tool v9"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.GothamBold; Title.Parent = Main
local TitleCorner = Instance.new("UICorner"); TitleCorner.CornerRadius = UDim.new(0, 8); TitleCorner.Parent = Title

local HideBtn = Instance.new("TextButton")
HideBtn.Size = UDim2.new(0, 60, 0, 20); HideBtn.Position = UDim2.new(1, -65, 0, 5)
HideBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0); HideBtn.Text = "Hide"; HideBtn.TextColor3 = Color3.new(1, 1, 1)
HideBtn.Font = Enum.Font.GothamBold; HideBtn.TextSize = 12; HideBtn.Parent = Title
local HideCorner = Instance.new("UICorner"); HideCorner.CornerRadius = UDim.new(0, 4); HideCorner.Parent = HideBtn

local TabsFrame = Instance.new("Frame")
TabsFrame.Size = UDim2.new(1, 0, 0, 30); TabsFrame.Position = UDim2.new(0, 0, 0, 35); TabsFrame.BackgroundTransparency = 1; TabsFrame.Parent = Main
local TabList = Instance.new("UIListLayout"); TabList.FillDirection = Enum.FillDirection.Horizontal; TabList.Padding = UDim.new(0, 5); TabList.Parent = TabsFrame

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -75); Content.Position = UDim2.new(0, 5, 0, 70)
Content.BackgroundTransparency = 1; Content.ScrollBarThickness = 4; Content.Parent = Main

local function CreateTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 65, 1, 0); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = name; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.Gotham; btn.TextSize = 12; btn.Parent = TabsFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        for _, child in ipairs(Content:GetChildren()) do
            if child:IsA("Frame") then child.Visible = false end
        end
        local section = Content:FindFirstChild(name .. "Section")
        if section then section.Visible = true end
    end)
    return btn
end

local function CreateSection(name)
    local sec = Instance.new("Frame")
    sec.Name = name .. "Section"; sec.Size = UDim2.new(1, 0, 1, 0); sec.BackgroundTransparency = 1; sec.Visible = false; sec.Parent = Content
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 5); layout.Parent = sec
    return sec
end

local function AddToggle(parent, text, callback, defaultState)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40); btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Gotham; btn.TextSize = 14; btn.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    local state = defaultState or false
    btn.Text = text .. ": " .. (state and "ON" or "OFF")
    btn.BackgroundColor3 = state and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 40)
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 40)
        if callback then callback(state) end
    end)
    return btn
end

local function AddButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60); btn.Text = text; btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 14; btn.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

-- ESP
CreateTab("ESP")
local EspSec = CreateSection("ESP")
AddToggle(EspSec, "Murderer ESP", function(s) ESP_Settings.Murderer.Enabled = s end)
AddToggle(EspSec, "Sheriff ESP", function(s) ESP_Settings.Sheriff.Enabled = s end)
AddToggle(EspSec, "Hero ESP", function(s) ESP_Settings.Hero.Enabled = s end)
AddToggle(EspSec, "Innocent ESP", function(s) ESP_Settings.Innocent.Enabled = s end)
AddToggle(EspSec, "Lobby ESP", function(s) ESP_Settings.Lobby.Enabled = s end, true)
AddToggle(EspSec, "Gun ESP", function(s) ESP_Settings.Gun.Enabled = s end)

-- Misc
CreateTab("Misc")
local MiscSec = CreateSection("Misc")
AddToggle(MiscSec, "Noclip", ToggleNoclip)
AddToggle(MiscSec, "Auto Farm (Smooth)", function(s) AutoFarm_Active = s; if s then AutoFarmMode = "Smooth"; task.spawn(AutoFarmLoop) end end)
AddToggle(MiscSec, "Auto Farm (TP)", function(s) AutoFarm_Active = s; if s then AutoFarmMode = "TP"; task.spawn(AutoFarmLoop) end end)
AddToggle(MiscSec, "Farm Death (No Coins/Full Bag)", function(s) FarmDeath_Active = s end)
AddToggle(MiscSec, "Auto Grab Gun", function(s) AutoGun_Active = s; if s then task.spawn(AutoGunLoop) end end)
-- Fling
CreateTab("Fling")
local FlingSec = CreateSection("Fling")
local playerList = Instance.new("ScrollingFrame")
playerList.Size = UDim2.new(1, 0, 0, 200); playerList.BackgroundColor3
