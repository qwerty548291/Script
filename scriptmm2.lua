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
    Innocent = { Enabled = false, Name = true, Dist = true, Box = true, Tracer = true, Color = Color3.fromRGB(0, 255, 0) },
    Lobby = { Name = true, Dist = true, Box = true, Tracer = true, Color = Color3.fromRGB(150, 150, 150) }
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
end

task.spawn(function()
    while task.wait(0.2) do
        ClearESP()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if IsInLobby(player) then
                    CreateESPForPlayer(player, "Lobby")
                else
                    local isMurderer, isSheriff = false, false
                    local charTool = player.Character:FindFirstChildOfClass("Tool")
                    local backpack = player:FindFirstChild("Backpack")
                    if charTool then
                        if charTool.Name == "Knife" then isMurderer = true end
                        if charTool.Name == "Gun" or charTool.Name == "Revolver" then isSheriff = true end
                    end
                    if backpack then
                        if backpack:FindFirstChild("Knife") then isMurderer = true end
                        if backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver") then isSheriff = true end
                    end
                    if isMurderer then CreateESPForPlayer(player, "Murderer")
                    elseif isSheriff then CreateESPForPlayer(player, "Sheriff")
                    else CreateESPForPlayer(player, "Innocent") end
                end
            end
        end
    end
end)
RunService.RenderStepped:Connect(UpdateESP)
local AutoFarm_Active, Noclip_Active = false, false
local AutoFarmMode = "Smooth"
local Fling_Active, FlingTarget, FlingConnection, FlingStartPos = false, nil, nil, nil
local RageAim_Active, RageKnife_Active, AutoGun_Active = false, false, false
local LegitAimSheriff_Active, LegitAimMurderer_Active = false, false
local KillAll_Active, FarmDeath_Active = false, false
local GunReturnPos = nil

local function GetChar() return LocalPlayer.Character end
local function GetRoot() local c = GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end

local function ToggleNoclip(state)
    Noclip_Active = state
    if state then
        RunService.Stepped:Connect(function()
            if Noclip_Active and GetChar() then
                for _, part in ipairs(GetChar():GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end

local function AutoFarmLoop()
    local originalGravity = workspace.Gravity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.P = 1000 
    bv.Parent = GetRoot()
    
    local NoCoinsTimer = tick()
    local ZoneTimer = nil
    local IgnoredCoins = {}
    local IsPaused = false

    while AutoFarm_Active do
        task.wait(0.05)
        local root = GetRoot()
        if not root then break end
        if not bv.Parent then bv.Parent = root end

        local coinFolder = workspace:FindFirstChild("CoinContainer", true)
        if not coinFolder then continue end

        -- Проверка на лобби (пауза и сброс таймера)
        if IsInLobby(LocalPlayer) then
            IsPaused = true
            bv.Velocity = Vector3.zero
            NoCoinsTimer = tick()
            task.wait(0.5) -- Пауза, чтобы не спамить
            continue
        else
            IsPaused = false
        end

        local nearestCoin = nil
        local minDist = math.huge

        -- Ищем ближайшую монету
        for _, coin in ipairs(coinFolder:GetChildren()) do
            if coin.Name == "Coin_Server" and coin:IsA("BasePart") and not IgnoredCoins[coin] then
                local dist = (coin.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; nearestCoin = coin end
            end
        end

        -- Логика смерти при отсутствии монет (5 секунд) и только если есть роли
        local murdererExists = false
        local sheriffExists = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not IsInLobby(p) then
                local backpack = p:FindFirstChild("Backpack")
                if backpack then
                    if backpack:FindFirstChild("Knife") then murdererExists = true end
                    if backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver") then sheriffExists = true end
                end
            end
        end

        local RolesAssigned = (murdererExists or sheriffExists)
        
        if nearestCoin and minDist <= 1000 then
            NoCoinsTimer = tick()
        elseif tick() - NoCoinsTimer > 5 and FarmDeath_Active and RolesAssigned and not IsPaused then
            if GetChar():FindFirstChildOfClass("Tool") and GetChar():FindFirstChildOfClass("Tool").Name == "Knife" then
                KillAll_Active = true
            end
            if GetChar() and GetChar():FindFirstChildOfClass("Humanoid") then
                GetChar().Humanoid.Health = 0
            end
        end

        if nearestCoin then
            if minDist <= 1 then
                -- Зона сбора (1x1x1). Запускаем таймер для черного списка (0.5 сек)
                if not ZoneTimer then
                    ZoneTimer = tick()
                elseif tick() - ZoneTimer >= 0.5 then
                    IgnoredCoins[nearestCoin] = true
                    ZoneTimer = nil
                end
            else
                ZoneTimer = nil
            end

            if AutoFarmMode == "Smooth" then
                workspace.Gravity = 0
                if minDist <= 1 then
                    bv.Velocity = Vector3.zero
                else
                    local dir = (nearestCoin.Position - root.Position).Unit
                    bv.Velocity = dir * 20
                end
            else
                -- Режим ТП
                bv.Velocity = Vector3.zero
                workspace.Gravity = originalGravity
                if nearestCoin.Parent and minDist > 1 then
                    root.CFrame = CFrame.new(nearestCoin.Position)
                    
                    -- Движение вверх-вниз для регистрации сбора
                    task.spawn(function()
                        task.wait(0.1)
                        root.AssemblyLinearVelocity = Vector3.new(0, 15, 0)
                        task.wait(0.1)
                        root.AssemblyLinearVelocity = Vector3.new(0, -15, 0)
                    end)
                    
                    task.wait(1.1)
                end
            end
        else
            bv.Velocity = Vector3.zero
        end
    end
    workspace.Gravity = originalGravity
    bv:Destroy()
end

-- Авто-перезапуск фарма (если завис)
task.spawn(function()
    while true do
        task.wait(5)
        if AutoFarm_Active then
            if not GetChar() or not GetChar():FindFirstChild("HumanoidRootPart") then
                AutoFarm_Active = false
                task.wait(1)
                AutoFarm_Active = true
                task.spawn(AutoFarmLoop)
            end
        end
    end
end)

local function StopFling()
    Fling_Active = false
    if FlingConnection then FlingConnection:Disconnect() end
    if FlingStartPos and GetRoot() then
        GetRoot().CFrame = FlingStartPos
        GetRoot().AssemblyLinearVelocity = Vector3.zero
        GetRoot().AssemblyAngularVelocity = Vector3.zero
    end
    FlingStartPos, FlingTarget = nil, nil
end

local function StartFling(targetPlayer)
    StopFling()
    local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = GetRoot()
    if not targetRoot or not myRoot then return end
    Fling_Active, FlingTarget, FlingStartPos = true, targetPlayer, myRoot.CFrame
    local angle = 0
    FlingConnection = RunService.Heartbeat:Connect(function(dt)
        if not Fling_Active then return end
        local currentTargetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not currentTargetRoot or not GetRoot() then StopFling(); return end
        angle = angle + (dt * 50)
        local offset = Vector3.new(math.cos(angle) * 0.7, math.sin(angle) * 0.7, math.sin(angle) * 0.7)
        local newPos = currentTargetRoot.Position + offset
        GetRoot().CFrame = CFrame.new(newPos)
        GetRoot().AssemblyLinearVelocity = (currentTargetRoot.Position - newPos).Unit * 25000 + Vector3.new(0, 10000, 0)
        GetRoot().AssemblyAngularVelocity = Vector3.new(5000, 5000, 5000)
    end)
end

local function GetMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not IsInLobby(p) then
            local backpack = p:FindFirstChild("Backpack")
            if backpack and backpack:FindFirstChild("Knife") then return p.Character end
        end
    end
    return nil
end

local function GetNearestInnocent()
    local myRoot = GetRoot()
    if not myRoot then return nil end
    local closest, minDist = nil, 15
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not IsInLobby(p) then
            local charTool = p.Character:FindFirstChildOfClass("Tool")
            local backpack = p:FindFirstChild("Backpack")
            local isMurderer = (charTool and charTool.Name == "Knife") or (backpack and backpack:FindFirstChild("Knife"))
            local isSheriff = (charTool and (charTool.Name == "Gun" or charTool.Name == "Revolver")) or (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver")))
            if not isMurderer and not isSheriff then
                local tr = p.Character:FindFirstChild("HumanoidRootPart")
                if tr then
                    local d = (tr.Position - myRoot.Position).Magnitude
                    if d < minDist then minDist = d; closest = p.Character end
                end
            end
        end
    end
    return closest
end

local function RageAimLoop()
    while RageAim_Active do
        task.wait(0.05)
        local myTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
        local murderer = GetMurderer()
        if myTool and (myTool.Name == "Gun" or myTool.Name == "Revolver") and murderer then
            local targetRoot = murderer:FindFirstChild("HumanoidRootPart")
            local myRoot = GetRoot()
            if targetRoot and myRoot then
                myRoot.CFrame = CFrame.new(targetRoot.Position - (targetRoot.CFrame.LookVector * 10), targetRoot.Position)
                myTool:Activate()
            end
        end
    end
end

local function LegitAimSheriffLoop()
    while LegitAimSheriff_Active do
        RunService.RenderStepped:Wait()
        local myTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
        local murderer = GetMurderer()
        if myTool and (myTool.Name == "Gun" or myTool.Name == "Revolver") and murderer then
            local targetRoot = murderer:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {LocalPlayer.Character, murderer}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                local ray = workspace:Raycast(Camera.CFrame.Position, (targetRoot.Position - Camera.CFrame.Position), rayParams)
                if not ray then
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetRoot.Position), 0.15)
                    if (Camera.CFrame.LookVector - (targetRoot.Position - Camera.CFrame.Position).Unit).Magnitude < 0.1 then myTool:Activate() end
                end
            end
        end
    end
end

local function RageKnifeLoop()
    while RageKnife_Active do
        task.wait(0.05)
        local myTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
        if myTool and myTool.Name == "Knife" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and not IsInLobby(p) then
                    local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
                    local myRoot = GetRoot()
                    if targetRoot and myRoot then
                        myRoot.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 2, 0))
                        myTool:Activate()
                    end
                end
            end
        end
    end
end

local function LegitKnifeLoop()
    while LegitAimMurderer_Active do
        RunService.Heartbeat:Wait()
        local myTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
        if myTool and myTool.Name == "Knife" then
            local targetChar = GetNearestInnocent()
            if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetChar.HumanoidRootPart.Position), 0.3)
                myTool:Activate()
            end
        end
    end
end

local function KillAllLoop()
    while KillAll_Active do
        task.wait(0.05)
        local myTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
        if myTool and myTool.Name == "Knife" then
            local myRoot = GetRoot()
            if myRoot then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not IsInLobby(p) then
                        local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        if targetRoot then targetRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -3) end
                    end
                end
                myTool:Activate()
            end
        end
    end
end

local function AutoGunLoop()
    while AutoGun_Active do
        task.wait(0.5)
        local myRoot = GetRoot()
        if not myRoot then continue end
        local gunPart = workspace:FindFirstChild("GunPrompt", true)
        if gunPart and not gunPart:IsDescendantOf(workspace:FindFirstChild("Lobby")) then
            local myTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
            local hasGun = myTool and (myTool.Name == "Gun" or myTool.Name == "Revolver")
            if not hasGun then
                if (gunPart.Position - myRoot.Position).Magnitude <= 2000 then 
                    if not GunReturnPos then GunReturnPos = myRoot.CFrame end
                    myRoot.CFrame = gunPart.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.2)
                    local newTool = GetChar() and GetChar():FindFirstChildOfClass("Tool")
                    if newTool and (newTool.Name == "Gun" or newTool.Name == "Revolver") then
                        if GunReturnPos then myRoot.CFrame = GunReturnPos; GunReturnPos = nil end
                    end
                end
            elseif hasGun and GunReturnPos then
                myRoot.CFrame = GunReturnPos; GunReturnPos = nil
            end
        end
    end
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
Title.Text = "MM2 Multi-Tool v8"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.GothamBold; Title.Parent = Main
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

local function AddToggle(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40); btn.Text = text .. ": OFF"; btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Gotham; btn.TextSize = 14; btn.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    local state = false
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

CreateTab("ESP")
local EspSec = CreateSection("ESP")
AddToggle(EspSec, "Murderer ESP", function(s) ESP_Settings.Murderer.Enabled = s end)
AddToggle(EspSec, "Sheriff ESP", function(s) ESP_Settings.Sheriff.Enabled = s end)
AddToggle(EspSec, "Innocent ESP", function(s) ESP_Settings.Innocent.Enabled = s end)
AddToggle(EspSec, "Show Name", function(s) ESP_Settings.Murderer.Name = s; ESP_Settings.Sheriff.Name = s; ESP_Settings.Innocent.Name = s; ESP_Settings.Lobby.Name = s end)
AddToggle(EspSec, "Show Distance", function(s) ESP_Settings.Murderer.Dist = s; ESP_Settings.Sheriff.Dist = s; ESP_Settings.Innocent.Dist = s; ESP_Settings.Lobby.Dist = s end)
AddToggle(EspSec, "Show Box", function(s) ESP_Settings.Murderer.Box = s; ESP_Settings.Sheriff.Box = s; ESP_Settings.Innocent.Box = s; ESP_Settings.Lobby.Box = s end)
AddToggle(EspSec, "Show Tracer", function(s) ESP_Settings.Murderer.Tracer = s; ESP_Settings.Sheriff.Tracer = s; ESP_Settings.Innocent.Tracer = s; ESP_Settings.Lobby.Tracer = s end)

CreateTab("Misc")
local MiscSec = CreateSection("Misc")
AddToggle(MiscSec, "Noclip", ToggleNoclip)
AddToggle(MiscSec, "Auto Farm (Smooth)", function(s) AutoFarm_Active = s; if s then AutoFarmMode = "Smooth"; task.spawn(AutoFarmLoop) end end)
AddToggle(MiscSec, "Auto Farm (TP)", function(s) AutoFarm_Active = s; if s then AutoFarmMode = "TP"; task.spawn(AutoFarmLoop) end end)
AddToggle(MiscSec, "Farm Death (No Coins)", function(s) FarmDeath_Active = s end)
AddToggle(MiscSec, "Auto Grab Gun", function(s) AutoGun_Active = s; if s then task.spawn(AutoGunLoop) end end)
CreateTab("Fling")
local FlingSec = CreateSection("Fling")
local playerList = Instance.new("ScrollingFrame")
playerList.Size = UDim2.new(1, 0, 0, 200); playerList.BackgroundColor3 = Color3.fromRGB(30, 30, 30); playerList.Parent = FlingSec
local plLayout = Instance.new("UIListLayout"); plLayout.Parent = playerList

local function RefreshPlayerList()
    for _, c in ipairs(playerList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not IsInLobby(p) then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 25); b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            b.Text = p.Name; b.TextColor3 = Color3.new(1, 1, 1); b.Parent = playerList
            b.MouseButton1Click:Connect(function() if FlingTarget == p then StopFling() else StartFling(p) end end)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and IsInLobby(p) then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 25); b.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
            b.Text = "[LOBBY] " .. p.Name; b.TextColor3 = Color3.new(1, 1, 1); b.Parent = playerList
            b.MouseButton1Click:Connect(function() if FlingTarget == p then StopFling() else StartFling(p) end end)
        end
    end
end
RefreshPlayerList()
Players.PlayerAdded:Connect(RefreshPlayerList); Players.PlayerRemoving:Connect(RefreshPlayerList)
AddButton(FlingSec, "STOP FLING", StopFling)

CreateTab("Aim")
local AimSec = CreateSection("Aim")

local sheriffLabel = Instance.new("TextLabel")
sheriffLabel.Size = UDim2.new(1, 0, 0, 20); sheriffLabel.BackgroundTransparency = 1; sheriffLabel.Text = "=== SHERIFF ==="
sheriffLabel.TextColor3 = Color3.fromRGB(0, 150, 255); sheriffLabel.Font = Enum.Font.GothamBold; sheriffLabel.Parent = AimSec
AddToggle(AimSec, "Rage Aim (TP)", function(s) RageAim_Active = s; if s then task.spawn(RageAimLoop) end end)
AddToggle(AimSec, "Legit Aim", function(s) LegitAimSheriff_Active = s; if s then task.spawn(LegitAimSheriffLoop) end end)

local murdererLabel = Instance.new("TextLabel")
murdererLabel.Size = UDim2.new(1, 0, 0, 20); murdererLabel.BackgroundTransparency = 1; murdererLabel.Text = "=== MURDERER ==="
murdererLabel.TextColor3 = Color3.fromRGB(255, 0, 0); murdererLabel.Font = Enum.Font.GothamBold; murdererLabel.Parent = AimSec
AddToggle(AimSec, "Rage Knife (TP)", function(s) RageKnife_Active = s; if s then task.spawn(RageKnifeLoop) end end)
AddToggle(AimSec, "Legit Knife", function(s) LegitAimMurderer_Active = s; if s then task.spawn(LegitKnifeLoop) end end)
AddToggle(AimSec, "KILL ALL (Local TP)", function(s) KillAll_Active = s; if s then task.spawn(KillAllLoop) end end)

CreateTab("TP")
local TpSec = CreateSection("TP")
local tpList = Instance.new("ScrollingFrame")
tpList.Size = UDim2.new(1, 0, 0, 250); tpList.BackgroundColor3 = Color3.fromRGB(30, 30, 30); tpList.Parent = TpSec
local tpLayout = Instance.new("UIListLayout"); tpLayout.Parent = tpList
local function RefreshTpList()
    for _, c in ipairs(tpList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not IsInLobby(p) then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 25); b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            b.Text = p.Name; b.TextColor3 = Color3.new(1, 1, 1); b.Parent = tpList
            b.MouseButton1Click:Connect(function()
                local root, targetRoot = GetRoot(), p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if root and targetRoot then root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3) end
            end)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and IsInLobby(p) then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 25); b.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
            b.Text = "[LOBBY] " .. p.Name; b.TextColor3 = Color3.new(1, 1, 1); b.Parent = tpList
            b.MouseButton1Click:Connect(function()
                local root, targetRoot = GetRoot(), p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if root and targetRoot then root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3) end
            end)
        end
    end
end
RefreshTpList()
Players.PlayerAdded:Connect(RefreshTpList); Players.PlayerRemoving:Connect(RefreshTpList)

EspSec.Visible = true
local hidden = false
HideBtn.MouseButton1Click:Connect(function()
    hidden = not hidden
    Main.Size = hidden and UDim2.new(0, 300, 0, 30) or UDim2.new(0, 300, 0, 400)
    Content.Visible = not hidden; TabsFrame.Visible = not hidden
end)

print("[MM2] Скрипт загружен.")
