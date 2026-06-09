local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
local Window = OrionLib:MakeWindow({
    Name = "Mod Menu",
    HidePremium = true,
    SaveConfig = true,
    IntroEnabled = true,
    IntroText = "Loading Mod Menu..."
})

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local BridgeNet2 = require(game.ReplicatedStorage.Requires.BridgeNet2)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StateMachine = require(game.ReplicatedStorage.Requires.StateMachine)
local COREGUI = game:GetService("CoreGui")

---------------------------------------------------------
-- STATE
---------------------------------------------------------
local FallDamage = BridgeNet2.ReferenceBridge("FallDamage")
local questActionBridge = BridgeNet2.ReferenceBridge("QuestAction")
local oldFire = FallDamage.Fire
local fallDamageEnabled = false
local zipEnabled = false
local zipConn = nil
local autoRotateFix = nil
local FLYING = false
local QEfly = true
local iyflyspeed = 1
local vehicleflyspeed = 1
local flyKeyDown, flyKeyUp

local ESPenabled = false
local espTransparency = 0.5
local espLogic = true
local espLoopConn = nil

local smugglerEnabled = false
local smugglerThread = nil

local noclip = false
local Clip = true
local Noclipping = nil

---------------------------------------------------------
-- NOCLIP
---------------------------------------------------------
local function setNoclip(state)
    noclip = state
    
    if Noclipping then 
        Noclipping:Disconnect() 
        Noclipping = nil 
    end

    if noclip then
        Clip = false
        task.wait(0.1)
        
        local function NoclipLoop()
            if Clip == false and plr.Character ~= nil then
                for _, child in pairs(plr.Character:GetDescendants()) do
                    if child:IsA("BasePart") and child.CanCollide == true then
                        child.CanCollide = false
                    end
                end
            end
        end
        Noclipping = RunService.Stepped:Connect(NoclipLoop)
    else
        Clip = true
        
        -- Force a clean state refresh so the physics engine re-evaluates character boundaries
        local character = plr.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end
---------------------------------------------------------
-- UTILITY
---------------------------------------------------------
local function getRoot(char)
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function tpTo(obj)
    local char = plr.Character
    if not (char and char:FindFirstChild("HumanoidRootPart")) then return end
    if obj:IsA("Model") then
        char:PivotTo(obj:GetPivot())
    elseif obj:IsA("BasePart") then
        char:PivotTo(obj.CFrame)
    end
end

---------------------------------------------------------
-- ZIP PATCH
---------------------------------------------------------
local function patchZip(char)
    if not zipEnabled then return end
    local effects = char:WaitForChild("Effects")
    if not effects:FindFirstChild("Ziplining") then
        local tag = Instance.new("BoolValue")
        tag.Name = "Ziplining"
        tag.Parent = effects
    end
end

local function removeZip(char)
    local effects = char and char:FindFirstChild("Effects")
    if effects then
        local tag = effects:FindFirstChild("Ziplining")
        if tag then tag:Destroy() end
    end
end

---------------------------------------------------------
-- AUTOROTATE FIX
---------------------------------------------------------
local function startAutoRotateFix()
    if autoRotateFix then return end
    RunService:BindToRenderStep("AutoRotateFix", Enum.RenderPriority.Last.Value + 1, function()
        if not zipEnabled then return end
        local char = plr.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if not hum then return end
        if StateMachine.getState() == "AimingGun" then
            hum.AutoRotate = false
        else
            hum.AutoRotate = true
        end
    end)
    autoRotateFix = true
end

local function stopAutoRotateFix()
    RunService:UnbindFromRenderStep("AutoRotateFix")
    autoRotateFix = nil
    local char = plr.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.AutoRotate = true end
    end
end

---------------------------------------------------------
-- FLY
---------------------------------------------------------
function sFLY(vfly)
    local char = plr.Character or plr.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        repeat task.wait() until char:FindFirstChildOfClass("Humanoid")
        humanoid = char:FindFirstChildOfClass("Humanoid")
    end

    if flyKeyDown then pcall(function() flyKeyDown:Disconnect() end) flyKeyDown = nil end
    if flyKeyUp then pcall(function() flyKeyUp:Disconnect() end) flyKeyUp = nil end

    local T = getRoot(char)
    local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
    local lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}

    local function FLY()
        FLYING = true
        local BG = Instance.new('BodyGyro')
        local BV = Instance.new('BodyVelocity')
        BG.P = 9e4
        BG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        BG.CFrame = T.CFrame
        BG.Parent = T
        BV.Velocity = Vector3.new(0, 0, 0)
        BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        BV.Parent = T

        humanoid.PlatformStand = true

        task.spawn(function()
            repeat
                task.wait()
                local camera = workspace.CurrentCamera
                local speed = (vfly and vehicleflyspeed or iyflyspeed) * 50

                local moveVec = Vector3.new(0, 0, 0)

                if (CONTROL.L + CONTROL.R) ~= 0 or (CONTROL.F + CONTROL.B) ~= 0 or (CONTROL.Q + CONTROL.E) ~= 0 then
                    moveVec = (camera.CFrame.LookVector * (CONTROL.F + CONTROL.B))
                        + (camera.CFrame.RightVector * (CONTROL.L + CONTROL.R))
                        + (Vector3.new(0, 1, 0) * (CONTROL.Q + CONTROL.E))
                    moveVec = moveVec.Unit * speed
                    lCONTROL = {F = CONTROL.F, B = CONTROL.B, L = CONTROL.L, R = CONTROL.R, Q = CONTROL.Q, E = CONTROL.E}
                else
                    moveVec = Vector3.new(0, 0, 0)
                end

                BV.Velocity = moveVec
                BG.CFrame = camera.CFrame
            until not FLYING

            BG:Destroy()
            BV:Destroy()
            if humanoid then humanoid.PlatformStand = false end
        end)
    end

    flyKeyDown = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        local spd = 1
        if input.KeyCode == Enum.KeyCode.W then
            CONTROL.F = spd
        elseif input.KeyCode == Enum.KeyCode.S then
            CONTROL.B = -spd
        elseif input.KeyCode == Enum.KeyCode.A then
            CONTROL.L = -spd
        elseif input.KeyCode == Enum.KeyCode.D then
            CONTROL.R = spd
        elseif input.KeyCode == Enum.KeyCode.E and QEfly then
            CONTROL.Q = spd
        elseif input.KeyCode == Enum.KeyCode.Q and QEfly then
            CONTROL.E = -spd
        end
    end)

    flyKeyUp = UserInputService.InputEnded:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.W then
            CONTROL.F = 0
        elseif input.KeyCode == Enum.KeyCode.S then
            CONTROL.B = 0
        elseif input.KeyCode == Enum.KeyCode.A then
            CONTROL.L = 0
        elseif input.KeyCode == Enum.KeyCode.D then
            CONTROL.R = 0
        elseif input.KeyCode == Enum.KeyCode.E then
            CONTROL.Q = 0
        elseif input.KeyCode == Enum.KeyCode.Q then
            CONTROL.E = 0
        end
    end)

    FLY()
end

function NOFLY()
    FLYING = false
    if flyKeyDown then pcall(function() flyKeyDown:Disconnect() end) flyKeyDown = nil end
    if flyKeyUp then pcall(function() flyKeyUp:Disconnect() end) flyKeyUp = nil end
    
    if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
        plr.Character:FindFirstChildOfClass("Humanoid").PlatformStand = false
    end
    pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
end

---------------------------------------------------------
-- ESP
---------------------------------------------------------
local function clearAllESP()
    if espLoopConn then
        espLoopConn:Disconnect()
        espLoopConn = nil
    end
    for _, v in pairs(COREGUI:GetChildren()) do
        if v.Name:match("_ESP$") then
            v:Destroy()
        end
    end
end

local function manageESP(logic)
    if espLoopConn then espLoopConn:Disconnect() end

    espLoopConn = RunService.RenderStepped:Connect(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player == plr then continue end

            local char = player.Character
            local root = char and getRoot(char)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and char:FindFirstChild("Head")

            local espName = player.Name .. "_ESP"
            local existing = COREGUI:FindFirstChild(espName)

            if char and root and hum and head and hum.Health > 0 then
                if existing then
                    local stale = false
                    for _, a in pairs(existing:GetChildren()) do
                        if a:IsA("BoxHandleAdornment") then
                            if not a.Adornee or not a.Adornee:IsDescendantOf(char) then
                                stale = true
                                break
                            end
                        end
                    end
                    if stale then
                        existing:Destroy()
                        existing = nil
                    end
                end

                if not existing then
                    local ESPholder = Instance.new("Folder")
                    ESPholder.Name = espName
                    ESPholder.Parent = COREGUI

                    for _, n in pairs(char:GetChildren()) do
                        if n:IsA("BasePart") then
                            local a = Instance.new("BoxHandleAdornment")
                            a.Name = player.Name
                            a.Parent = ESPholder
                            a.Adornee = n
                            a.AlwaysOnTop = true
                            a.ZIndex = 10
                            a.Size = n.Size
                            a.Transparency = espTransparency
                            a.Color = logic and BrickColor.new(
                                player.TeamColor == plr.TeamColor and "Bright green" or "Bright red"
                            ) or player.TeamColor
                        end
                    end

                    local BillboardGui = Instance.new("BillboardGui")
                    BillboardGui.Adornee = head
                    BillboardGui.Name = "Nametag"
                    BillboardGui.Parent = ESPholder
                    BillboardGui.Size = UDim2.new(0, 100, 0, 150)
                    BillboardGui.StudsOffset = Vector3.new(0, 1, 0)
                    BillboardGui.AlwaysOnTop = true

                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Parent = BillboardGui
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.Position = UDim2.new(0, 0, 0, -50)
                    TextLabel.Size = UDim2.new(0, 100, 0, 100)
                    TextLabel.Font = Enum.Font.SourceSansSemibold
                    TextLabel.TextSize = 20
                    TextLabel.TextColor3 = Color3.new(1, 1, 1)
                    TextLabel.TextStrokeTransparency = 0
                    TextLabel.TextYAlignment = Enum.TextYAlignment.Bottom
                    TextLabel.Text = "Loading..."
                    TextLabel.ZIndex = 10
                else
                    local nametag = existing:FindFirstChild("Nametag")
                    local textLabel = nametag and nametag:FindFirstChildOfClass("TextLabel")

                    if textLabel and plr.Character and getRoot(plr.Character) then
                        local dist = math.floor((getRoot(plr.Character).Position - root.Position).Magnitude)
                        textLabel.Text = "Name: " .. player.Name .. " | HP: " .. round(hum.Health, 1) .. " | " .. dist .. "st"
                    end

                    for _, a in pairs(existing:GetChildren()) do
                        if a:IsA("BoxHandleAdornment") then
                            a.Color = logic and BrickColor.new(
                                player.TeamColor == plr.TeamColor and "Bright green" or "Bright red"
                            ) or player.TeamColor
                        end
                    end
                end
            else
                if existing then existing:Destroy() end
            end
        end
    end)
end

---------------------------------------------------------
-- SMUGGLER AUTO
---------------------------------------------------------
local function waitForNPC(path, timeout)
    local deadline = tick() + (timeout or 60)
    while tick() < deadline do
        local obj = workspace
        local found = true
        for _, key in ipairs(path) do
            obj = obj:FindFirstChild(key)
            if not obj then found = false break end
        end
        if found then return obj end
        task.wait(1)
    end
    return nil
end

local function runSmugglerLoop()
    local missionUI = plr.PlayerGui:FindFirstChild("Mission")

    while smugglerEnabled do
        local char = plr.Character
        if not (char and char:FindFirstChild("HumanoidRootPart")) then
            task.wait(1)
            continue
        end

        -- 1. CLEAN STATE REFRESH: Ensure any residual NPC from the last run is gone
        local questsFolder = workspace:FindFirstChild("Quests")
        if questsFolder and questsFolder:FindFirstChild("CourierNPC") then
            warn("[Smuggler] Clearing old NPC debris...")
            while smugglerEnabled and questsFolder and questsFolder:FindFirstChild("CourierNPC") do
                task.wait(0.5)
                questsFolder = workspace:FindFirstChild("Quests")
            end
        end

        if not smugglerEnabled then break end

        -- 2. FORCE RE-ALIGN DEALER LOCATION
        local scenic = workspace:FindFirstChild("Scenic NPCs")
        if scenic and scenic:FindFirstChild("MissionDealer1") then
            scenic.MissionDealer1:PivotTo(CFrame.new(-1565, -29, 510))
            task.wait(0.3)
        end

        -- 3. INTERACT & CLAIM NEW CONTRACT
        scenic = workspace:FindFirstChild("Scenic NPCs")
        local missionDealer = scenic and scenic:FindFirstChild("MissionDealer1")
        local dealerHead = missionDealer and missionDealer:FindFirstChild("Head")
        
        if dealerHead then
            tpTo(dealerHead)
            task.wait(0.5)

            warn("[Smuggler] Sending Network Handshake...")
            questActionBridge:Fire({
                Action = "Interact",
                TargetNPC = missionDealer
            })
            task.wait(0.3)

            warn("[Smuggler] Grabbing Contract...")
            questActionBridge:Fire({
                Action = "Confirm",
                QuestName = "Courier"
            })

            if missionUI then
                local mainFrame = missionUI:FindFirstChild("Main")
                if mainFrame then mainFrame.Visible = false end
                missionUI.Enabled = false
            end
            task.wait(1) -- Cooldown for server to process contract and spawn the target
        end

        if not smugglerEnabled then break end

        -- 4. DELIVERY TELEPORT LEG
        warn("[Smuggler] Tracking active CourierNPC...")
        local courierHead = waitForNPC({"Quests", "CourierNPC", "Head"}, 120)
        if not smugglerEnabled then break end
        
        if courierHead then
            tpTo(courierHead)
            task.wait(1.5) -- Time to register touch confirmation on server
        else
            warn("[Smuggler] Target lost, restarting loop context...")
            task.wait(1)
            continue
        end

        if not smugglerEnabled then break end

        -- 5. RETURN TURN-IN LEG
        scenic = workspace:FindFirstChild("Scenic NPCs")
        missionDealer = scenic and scenic:FindFirstChild("MissionDealer1")
        dealerHead = missionDealer and missionDealer:FindFirstChild("Head")
        if dealerHead then
            tpTo(dealerHead)
            task.wait(1.5)
        end

        if not smugglerEnabled then break end

        -- 6. FIXED COOLDOWN (No more infinite deadlock)
        warn("[Smuggler] Contract finalized. Waiting 3 seconds for session reset...")
        task.wait(3)
    end
    warn("[Smuggler] Loop stopped")
end
---------------------------------------------------------
-- TABS
---------------------------------------------------------
local Tab1 = Window:MakeTab({ Name = "Patches", PremiumOnly = false })
local TabMove = Window:MakeTab({ Name = "Movement", PremiumOnly = false })
local TabVis = Window:MakeTab({ Name = "Visuals", PremiumOnly = false })
local TabAuto = Window:MakeTab({ Name = "Auto", PremiumOnly = false })
local Tab3 = Window:MakeTab({ Name = "Scripts", PremiumOnly = false })
local Tab4 = Window:MakeTab({ Name = "Teleports", PremiumOnly = false })
local TabBinds = Window:MakeTab({ Name = "Keybinds", PremiumOnly = false })
local Tab2 = Window:MakeTab({ Name = "Options", PremiumOnly = false })

---------------------------------------------------------
-- PATCHES TAB
---------------------------------------------------------
Tab1:AddToggle({
    Name = "No Fall Damage",
    Default = false,
    Callback = function(Value)
        fallDamageEnabled = Value
        FallDamage.Fire = Value and function(self, ...) end or oldFire
    end
})

Tab1:AddToggle({
    Name = "Shoot In Air",
    Default = false,
    Callback = function(Value)
        zipEnabled = Value
        local char = plr.Character
        if Value then
            if char then patchZip(char) end
            if zipConn then zipConn:Disconnect() end
            zipConn = plr.CharacterAdded:Connect(patchZip)
            startAutoRotateFix()
        else
            if char then removeZip(char) end
            if zipConn then zipConn:Disconnect() zipConn = nil end
            stopAutoRotateFix()
        end
    end
})

---------------------------------------------------------
-- MOVEMENT TAB
---------------------------------------------------------
local noclipToggleUI = TabMove:AddToggle({
    Name = "Noclip",
    Default = false,
    Callback = function(Value)
        setNoclip(Value)
    end
})

local flyUIToggle = TabMove:AddToggle({
    Name = "Fly",
    Default = false,
    Callback = function(Value)
        if Value then sFLY(false) else NOFLY() end
    end
})

TabMove:AddSlider({
    Name = "Fly Speed",
    Min = 1,
    Max = 10,
    Default = 1,
    Color = Color3.fromRGB(255,255,255),
    Increment = 1,
    ValueName = "Multiplier",
    Callback = function(Value)
        iyflyspeed = Value
    end
})

---------------------------------------------------------
-- VISUALS TAB
---------------------------------------------------------
TabVis:AddToggle({
    Name = "Player ESP",
    Default = false,
    Callback = function(Value)
        ESPenabled = Value
        if Value then
            manageESP(espLogic)
        else
            clearAllESP()
        end
    end
})

---------------------------------------------------------
-- AUTO TAB
---------------------------------------------------------
TabAuto:AddLabel("Missions")

TabAuto:AddToggle({
    Name = "Auto Smuggler",
    Default = false,
    Callback = function(Value)
        smugglerEnabled = Value
        if Value then
            if smugglerThread then task.cancel(smugglerThread) end
            smugglerThread = task.spawn(runSmugglerLoop)
            warn("[Smuggler] Started")
        else
            if smugglerThread then
                task.cancel(smugglerThread)
                smugglerThread = nil
            end
            warn("[Smuggler] Stopped")
        end
    end
})

---------------------------------------------------------
-- SCRIPTS TAB
---------------------------------------------------------
Tab3:AddLabel("Loaders")

Tab3:AddButton({
    Name = "Infinite Yield",
    Callback = function()
        task.spawn(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        end)
    end
})

Tab3:AddButton({
    Name = "Dex++",
    Callback = function()
        task.spawn(function()
            loadstring(game:HttpGet("https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua"))()
        end)
    end
})

---------------------------------------------------------
-- TELEPORTS TAB
---------------------------------------------------------
Tab4:AddLabel("Safes")

Tab4:AddButton({
    Name = "TP to RedSafe",
    Callback = function()
        local redSafe = workspace:FindFirstChild("RedSafe", true)
        local char = plr.Character
        if redSafe and char and char:FindFirstChild("HumanoidRootPart") then
            char:PivotTo(redSafe:IsA("Model") and redSafe:GetPivot() or redSafe.CFrame)
        else
            warn("RedSafe not found.")
        end
    end
})

Tab4:AddLabel("Locations")

Tab4:AddButton({
    Name = "TP to Safehouse",
    Callback = function()
        local char = plr.Character
        if not (char and char:FindFirstChild("HumanoidRootPart")) then return end
        local scenicNPCs = workspace:FindFirstChild("Scenic NPCs")
        local dealer = scenicNPCs and scenicNPCs:FindFirstChild("Dropoff Dealer")
        local head = dealer and dealer:FindFirstChild("Head")
        if head then
            char:PivotTo(head:IsA("Model") and head:GetPivot() or head.CFrame)
        end
    end
})

Tab4:AddLabel("Heists")

local function tpToVault(path)
    local char = plr.Character
    if not (char and char:FindFirstChild("HumanoidRootPart")) then return end
    local obj = workspace
    for _, key in ipairs(path) do
        obj = obj:FindFirstChild(key)
        if not obj then warn("Path not found: "..key) return end
    end
    char:PivotTo(obj:IsA("Model") and obj:GetPivot() or obj.CFrame)
end

Tab4:AddButton({
    Name = "TP DataCenter Vault 1",
    Callback = function()
        local heists = workspace:FindFirstChild("Heists")
        local dc = heists and heists:FindFirstChild("DataCenter")
        if not dc then warn("DataCenter not found") return end
        local vaults = {}
        for _, d in ipairs(dc:GetDescendants()) do
            if d.Name == "Closed" then table.insert(vaults, d) end
        end
        local char = plr.Character
        if vaults[1] and char then
            char:PivotTo(vaults[1]:IsA("Model") and vaults[1]:GetPivot() or vaults[1].CFrame)
        end
    end
})

Tab4:AddButton({
    Name = "TP DataCenter Vault 2",
    Callback = function()
        local heists = workspace:FindFirstChild("Heists")
        local dc = heists and heists:FindFirstChild("DataCenter")
        if not dc then warn("DataCenter not found") return end
        local vaults = {}
        for _, d in ipairs(dc:GetDescendants()) do
            if d.Name == "Closed" then table.insert(vaults, d) end
        end
        local char = plr.Character
        if vaults[2] and char then
            char:PivotTo(vaults[2]:IsA("Model") and vaults[2]:GetPivot() or vaults[2].CFrame)
        end
    end
})

Tab4:AddButton({
    Name = "TP Bank Vault",
    Callback = function()
        tpToVault({"Heists", "Bank", "Vault", "Closed"})
    end
})

Tab4:AddButton({
    Name = "TP Jewelry Store Vault",
    Callback = function()
        tpToVault({"Heists", "JewelryStore", "Vault", "Closed"})
    end
})

Tab4:AddButton({
    Name = "TP Penthouse Vault",
    Callback = function()
        tpToVault({"Heists", "PentHouse", "Vault", "Closed"})
    end
})

---------------------------------------------------------
-- KEYBINDS TAB
---------------------------------------------------------
TabBinds:AddBind({
    Name = "Toggle GUI",
    Default = Enum.KeyCode.K,
    Hold = false,
    Callback = function()
        local orionGui = COREGUI:FindFirstChild("Orion") or (gethui and gethui():FindFirstChild("Orion"))
        if orionGui then orionGui.Enabled = not orionGui.Enabled end
    end
})

TabBinds:AddBind({
    Name = "Toggle Fly",
    Default = Enum.KeyCode.H,
    Hold = false,
    Callback = function()
        pcall(function() 
            flyUIToggle:Set(not flyUIToggle.Value) 
        end)
    end
})

TabBinds:AddBind({
    Name = "Toggle Noclip",
    Default = Enum.KeyCode.N,
    Hold = false,
    Callback = function()
        pcall(function()
            noclipToggleUI:Set(not noclip)
        end)
    end
})

---------------------------------------------------------
-- OPTIONS TAB
---------------------------------------------------------
Tab2:AddLabel("UI Options")

Tab2:AddButton({
    Name = "Kill UI",
    Callback = function()
        FallDamage.Fire = oldFire
        if zipConn then zipConn:Disconnect() end
        RunService:UnbindFromRenderStep("AutoRotateFix")
        
        -- Clean terminate active connections
        setNoclip(false)
        NOFLY()
        
        smugglerEnabled = false
        if smugglerThread then task.cancel(smugglerThread) smugglerThread = nil end
        ESPenabled = false
        clearAllESP()
        OrionLib:Destroy()
    end
})

---------------------------------------------------------
-- RESPAWN HANDLER
---------------------------------------------------------
plr.CharacterAdded:Connect(function(newChar)
    if FLYING then
        task.wait(0.5)
        sFLY(false)
    end
end)

---------------------------------------------------------
-- INIT
---------------------------------------------------------
OrionLib:Init()
