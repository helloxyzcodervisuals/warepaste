repeat task.wait() until game:IsLoaded()

local function isAdonisAC(tab) 
    return rawget(tab,"Detected") and typeof(rawget(tab,"Detected"))=="function" and rawget(tab,"RLocked") 
end
for _,v in next,getgc(true) do 
    if typeof(v)=="table" and isAdonisAC(v) then 
        for i,f in next,v do 
            if rawequal(i,"Detected") then 
                local old 
                old=hookfunction(f,function(action,info,crash)
                    if rawequal(action,"_") and rawequal(info,"_") and rawequal(crash,false) then 
                        return old(action,info,crash) 
                    end 
                    return task.wait(9e9) 
                end) 
                warn("bypassed") 
                break 
            end 
        end 
    end 
end
for _,v in pairs(getgc(true)) do 
    if type(v)=="table" then 
        local func=rawget(v,"DTXC1") 
        if type(func)=="function" then 
            hookfunction(func,function() return end) 
            break 
        end 
    end 
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local function vc()
    local v2 = "Font_" .. tostring(math.random(10000, 99999))
    local v24 = "Folder_" .. tostring(math.random(10000, 99999))
    if isfolder("UI_Fonts") then delfolder("UI_Fonts") end
    makefolder(v24)
    local v3 = v24 .. "/" .. v2 .. ".ttf"
    local v4 = v24 .. "/" .. v2 .. ".json"
    
    local success, body = pcall(function()
        return game:HttpGet("https://github.com/i77lhm/storage/blob/main/fonts/smallest_pixel-7.ttf?raw=true")
    end)
    
    if success then 
        writefile(v3, body) 
    else
        return Font.fromEnum(Enum.Font.Code)
    end

    local v16 = {
        name = v2,
        faces = {{
            name = "Regular",
            weight = 400,
            style = "Normal",
            assetId = getcustomasset(v3)
        }}
    }
    writefile(v4, game:GetService("HttpService"):JSONEncode(v16))
    return Font.new(getcustomasset(v4))
end

local CustomFont = vc()

local TargetList = {}
local Whitelist = {}

local function tablecontains(t, value)
    for _, v in ipairs(t) do if v == value then return true end end
    return false
end

local function tableRemove(t, value)
    for i, v in ipairs(t) do
        if v == value then table.remove(t, i) return true end
    end
    return false
end

local ConfigTable = {
    Ragebot = {
        Enabled = false,
        RapidFire = false,
        FireRate = 30,
        Prediction = true,
        PredictionAmount = 0.12,
        TeamCheck = false,
        VisibilityCheck = true,
        Wallbang = true,
        Tracers = true,
        TracerColor = Color3.fromRGB(255, 0, 0),
        TracerWidth = 1,
        TracerLifetime = 3,
        ShootRange = 15,
        HitRange = 15,
        HitNotify = true,
        AutoReload = true,
        HitSound = true,
        HitColor = Color3.fromRGB(255, 182, 193),
        UseTargetList = true,
        UseWhitelist = true,
        HitNotifyDuration = 5,
        LowHealthCheck = false,
        SelectedHitSound = "Skeet",
        FriendCheck = false,
        MaxTarget = 0,
        TracerTexture = "rbxassetid://7136858729",
        Keybind = Enum.KeyCode.LeftAlt
    }
}

local PerformanceCache = {
    TargetResults = {},
    RaycastResults = {},
    WallbangResults = {},
    LastTargetUpdate = 0,
    LastRaycastCleanup = 0,
    LastFrameTime = 0,
    FrameTimes = {},
    AverageFrameTime = 0.016,
    TargetUpdateInterval = 0.03,
    RaycastCacheDuration = 0.05,
    WallbangCacheDuration = 0.1,
    MaxCacheSize = 50,
    FrameHistory = 60
}

local hitNotifications = {}
local notificationYOffset = 5
local MAX_VISIBLE_NOTIFICATIONS = 15
local lastShotTime = 0
local cachedBestPositions = {shootPos = nil, hitPos = nil, target = nil}

local function getCurrentTool()
    if LocalPlayer.Character then 
        for _, tool in pairs(LocalPlayer.Character:GetChildren()) do 
            if tool:IsA("Tool") then 
                return tool 
            end 
        end 
    end
    return nil
end

local instantReloadConnections = {}
local characterAddedConnection = nil

local function autoReload()
    if not ConfigTable.Ragebot.AutoReload then
        if instantReloadConnections then
            for _,conn in pairs(instantReloadConnections) do 
                if conn then conn:Disconnect() end 
            end
            instantReloadConnections = {}
        end
        if characterAddedConnection then 
            characterAddedConnection:Disconnect() 
            characterAddedConnection = nil 
        end
        return
    end
    
    if not instantReloadConnections then
        instantReloadConnections = {}
    end
    
    local tool = getCurrentTool()
    if not tool then return end
    
    local values = tool:FindFirstChild("Values")
    if not values then return end
    
    local ammo = values:FindFirstChild("SERVER_Ammo")
    local storedAmmo = values:FindFirstChild("SERVER_StoredAmmo")
    if not ammo or not storedAmmo then return end
    
    for _,conn in pairs(instantReloadConnections) do 
        if conn then conn:Disconnect() end 
    end
    instantReloadConnections = {}
    
    if characterAddedConnection then 
        characterAddedConnection:Disconnect() 
        characterAddedConnection = nil 
    end
    
    local gunR_remote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("GNX_R")
    local me = Players.LocalPlayer
    
    local function setupToolListeners(toolObj)
        if not toolObj or not toolObj:FindFirstChild("IsGun") then return end
        
        local values = toolObj:FindFirstChild("Values")
        if not values then return end
        
        local ammo = values:FindFirstChild("SERVER_Ammo")
        local storedAmmo = values:FindFirstChild("SERVER_StoredAmmo")
        if not ammo or not storedAmmo then return end
        
        local conn1 = storedAmmo:GetPropertyChangedSignal("Value"):Connect(function()
            local currentRagebot = ConfigTable.Ragebot.AutoReload
            if currentRagebot then 
                gunR_remote:FireServer(tick(), "KLWE89U0", toolObj) 
            end
        end)
        
        if storedAmmo.Value ~= 0 then 
            gunR_remote:FireServer(tick(), "KLWE89U0", toolObj) 
        end
        
        local conn2 = ammo:GetPropertyChangedSignal("Value"):Connect(function()
            local currentRagebot = ConfigTable.Ragebot.AutoReload
            if currentRagebot and storedAmmo.Value ~= 0 then 
                gunR_remote:FireServer(tick(), "KLWE89U0", toolObj) 
            end
        end)
        
        table.insert(instantReloadConnections, conn1)
        table.insert(instantReloadConnections, conn2)
    end
    
    local char = me.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then 
            setupToolListeners(tool) 
        end
        
        local conn3 = char.ChildAdded:Connect(function(obj) 
            if obj:IsA("Tool") then 
                setupToolListeners(obj) 
            end 
        end)
        table.insert(instantReloadConnections, conn3)
    end
    
    characterAddedConnection = me.CharacterAdded:Connect(function(charr)
        repeat task.wait() until charr and charr.Parent
        local conn4 = charr.ChildAdded:Connect(function(obj) 
            if obj:IsA("Tool") then 
                setupToolListeners(obj) 
            end 
        end)
        table.insert(instantReloadConnections, conn4)
    end)
end

local function canSeeTarget(targetPart)
    if not ConfigTable.Ragebot.VisibilityCheck then return true end
    
    local localHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
    if not localHead then return false end
    
    local cacheKey = tostring(targetPart) .. tostring(localHead)
    local currentTime = tick()
    
    if PerformanceCache.RaycastResults[cacheKey] then
        local cached = PerformanceCache.RaycastResults[cacheKey]
        if currentTime - cached.time < PerformanceCache.RaycastCacheDuration then
            return cached.result
        end
    end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local startPos = localHead.Position
    local endPos = targetPart.Position
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    
    local raycastResult = Workspace:Raycast(startPos, direction.Unit * distance, raycastParams)
    local visible = true
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        if hitPart and hitPart.CanCollide then
            local model = hitPart:FindFirstAncestorOfClass("Model")
            if model then
                local humanoid = model:FindFirstChild("Humanoid")
                if humanoid then
                    local targetPlayer = Players:GetPlayerFromCharacter(model)
                    if targetPlayer then 
                        visible = true 
                    else 
                        visible = false 
                    end
                else 
                    visible = false 
                end
            else 
                visible = false 
            end
        end
    end
    
    PerformanceCache.RaycastResults[cacheKey] = {
        result = visible,
        time = currentTime
    }
    
    if currentTime - PerformanceCache.LastRaycastCleanup > 5 then
        local keys = {}
        for k, v in pairs(PerformanceCache.RaycastResults) do
            if currentTime - v.time > PerformanceCache.RaycastCacheDuration then
                table.insert(keys, k)
            end
        end
        for _, k in ipairs(keys) do
            PerformanceCache.RaycastResults[k] = nil
        end
        PerformanceCache.LastRaycastCleanup = currentTime
    end
    
    return visible
end

local function checkClearPath(startPos, endPos)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    local raycastResult = Workspace:Raycast(startPos, direction.Unit * distance, raycastParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        if hitPart and hitPart.CanCollide then
            local model = hitPart:FindFirstAncestorOfClass("Model")
            if model then
                local humanoid = model:FindFirstChild("Humanoid")
                if not humanoid then 
                    return false 
                end
            else 
                return false 
            end
        end
    end
    return true
end

local function getClosestTarget()
    local currentTime = tick()
    
    if currentTime - PerformanceCache.LastTargetUpdate < PerformanceCache.TargetUpdateInterval then
        return PerformanceCache.TargetResults.lastTarget
    end
    
    local character = LocalPlayer.Character
    local localHead = character and character:FindFirstChild("Head")
    if not localHead then return nil end

    local closest = nil
    local shortestDistance = math.huge
    local validTargets = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local isWhitelisted = tablecontains(Whitelist, player.Name)
        if ConfigTable.Ragebot.FriendCheck and LocalPlayer:IsFriendsWith(player.UserId) then
            isWhitelisted = true
        end
        
        if ConfigTable.Ragebot.UseWhitelist and isWhitelisted then continue end
        if ConfigTable.Ragebot.UseTargetList and #TargetList > 0 and not tablecontains(TargetList, player.Name) then continue end
        if ConfigTable.Ragebot.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local head = char and char:FindFirstChild("Head")
        
        if hum and head and hum.Health > 0 then
            if char:FindFirstChildOfClass("ForceField") then continue end
            if ConfigTable.Ragebot.LowHealthCheck and hum.Health < 15 then continue end
            
            local distance = (head.Position - localHead.Position).Magnitude
            table.insert(validTargets, {
                head = head,
                distance = distance,
                player = player
            })
        end
    end
    
    table.sort(validTargets, function(a, b)
        return a.distance < b.distance
    end)
    
    local maxChecks = ConfigTable.Ragebot.MaxTarget > 0 and math.min(ConfigTable.Ragebot.MaxTarget, #validTargets) or #validTargets
    
    for i = 1, maxChecks do
        local targetData = validTargets[i]
        if targetData then
            if ConfigTable.Ragebot.VisibilityCheck then
                if canSeeTarget(targetData.head) then
                    closest = targetData.head
                    break
                end
            else
                closest = targetData.head
                break
            end
        end
    end
    
    PerformanceCache.TargetResults.lastTarget = closest
    PerformanceCache.LastTargetUpdate = currentTime
    
    return closest
end 
local function wallbang()
    local localHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
    if not localHead then return nil, nil, false end
    
    local target = getClosestTarget()
    if not target then 
        cachedBestPositions = {shootPos = nil, hitPos = nil, target = nil}
        return nil, nil, false
    end
    
    local startPos = localHead.Position
    local targetPos = target.Position
    local currentTime = tick()
    
    local cacheKey = string.format("%.0f_%.0f_%.0f_%.0f_%.0f_%.0f",
        startPos.X, startPos.Y, startPos.Z,
        targetPos.X, targetPos.Y, targetPos.Z)
    
    if PerformanceCache.WallbangResults[cacheKey] then
        local cached = PerformanceCache.WallbangResults[cacheKey]
        if currentTime - cached.time < 0.3 then
            cachedBestPositions = {
                shootPos = cached.shootPos,
                hitPos = cached.hitPos,
                target = target,
                lastCalcTime = currentTime
            }
            return cached.shootPos, cached.hitPos, false
        end
    end
    
    if not ConfigTable.Ragebot.Wallbang then
        cachedBestPositions = {shootPos = startPos, hitPos = targetPos, target = target}
        PerformanceCache.WallbangResults[cacheKey] = {
            shootPos = startPos,
            hitPos = targetPos,
            time = currentTime
        }
        return startPos, targetPos, false
    end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local candidates = {}
    
    for attempt = 1, 100 do
        local angle = (attempt / 25) * math.pi * 2
        local radius = ConfigTable.Ragebot.ShootRange * (0.7 + math.random() * 0.3)
        local yRadius = ConfigTable.Ragebot.ShootRange * 0.2 * (0.8 + math.random() * 0.4)
        
        local offsetX = math.cos(angle + math.random() * 0.3) * radius
        local offsetZ = math.sin(angle + math.random() * 0.3) * radius
        local offsetY = math.sin(angle * 3) * yRadius + math.random(-2, 2)
        
        local shootTry = Vector3.new(
            startPos.X + offsetX,
            startPos.Y + offsetY,
            startPos.Z + offsetZ
        )
        
        if checkClearPath(startPos, shootTry) then
            local hitAngle = (attempt / 25) * math.pi * 2 + math.random() * 0.5
            local hitRadius = ConfigTable.Ragebot.HitRange * (0.7 + math.random() * 0.3)
            local hitYRadius = ConfigTable.Ragebot.HitRange * 0.2 * (0.8 + math.random() * 0.4)
            
            local hitOffsetX = math.cos(hitAngle) * hitRadius
            local hitOffsetZ = math.sin(hitAngle) * hitRadius
            local hitOffsetY = math.sin(hitAngle * 3) * hitYRadius + math.random(-2, 2)
            
            local hitTry = Vector3.new(
                targetPos.X + hitOffsetX,
                targetPos.Y + hitOffsetY,
                targetPos.Z + hitOffsetZ
            )
            
            if checkClearPath(shootTry, hitTry) then
                local distToStart = (shootTry - startPos).Magnitude
                local distToTarget = (hitTry - targetPos).Magnitude
                local score = distToStart * 0.4 + distToTarget * 0.6
                
                table.insert(candidates, {
                    shootPos = shootTry,
                    hitPos = hitTry,
                    score = score
                })
            end
        end
    end
    
    if #candidates == 0 then
        local undergroundY = -15
        
        for attempt = 1, 60 do
            local xOffset = math.random(-3, 3)
            local zOffset = math.random(-3, 3)
            
            local shootTry = Vector3.new(
                startPos.X + xOffset,
                undergroundY,
                startPos.Z + zOffset
            )
            
            local xHitOffset = math.random(-3, 3)
            local zHitOffset = math.random(-3, 3)
            
            local hitTry = Vector3.new(
                targetPos.X + xHitOffset,
                undergroundY,
                targetPos.Z + zHitOffset
            )
            
            if checkClearPath(shootTry, hitTry) then
                local distToStart = (shootTry - startPos).Magnitude
                local distToTarget = (hitTry - targetPos).Magnitude
                local score = distToStart * 0.3 + distToTarget * 0.7
                
                table.insert(candidates, {
                    shootPos = shootTry,
                    hitPos = hitTry,
                    score = score
                })
            end
        end
    end
    
    if #candidates == 0 then
        return nil, nil, false
    end
    
    table.sort(candidates, function(a, b)
        return a.score < b.score
    end)
    
    local best = candidates[1]
    
    PerformanceCache.WallbangResults[cacheKey] = {
        shootPos = best.shootPos,
        hitPos = best.hitPos,
        time = currentTime
    }
    
    if #PerformanceCache.WallbangResults > 150 then
        local toRemove = {}
        for k, v in pairs(PerformanceCache.WallbangResults) do
            if currentTime - v.time > 2 then
                table.insert(toRemove, k)
            end
        end
        for _, k in ipairs(toRemove) do
            PerformanceCache.WallbangResults[k] = nil
        end
    end
    
    cachedBestPositions = {
        shootPos = best.shootPos,
        hitPos = best.hitPos,
        target = target,
        lastCalcTime = currentTime
    }
    
    return best.shootPos, best.hitPos, false
end
local function createHitNotification(toolName, offsetValue, playerName, usedCache)
    if not ConfigTable.Ragebot.HitNotify then return end
    
    local targetPlayer = game:GetService("Players"):FindFirstChild(playerName)
    local health = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") and math.floor(targetPlayer.Character.Humanoid.Health) or 0

    local ScreenGui = game:GetService("CoreGui"):FindFirstChild("HitNotifications") or Instance.new("ScreenGui")
    ScreenGui.Name = "HitNotifications"
    ScreenGui.Parent = game:GetService("CoreGui")
    
    local scrollFrame = ScreenGui:FindFirstChild("NotificationScroll") or Instance.new("ScrollingFrame")
    scrollFrame.Name = "NotificationScroll"
    scrollFrame.Parent = ScreenGui
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.Size = UDim2.new(0, 600, 0, 400)
    scrollFrame.Position = UDim2.new(0, 30, 0, 10)
    scrollFrame.ScrollingEnabled = false
    scrollFrame.ScrollBarThickness = 0
    scrollFrame.ClipsDescendants = false

    local THEME_COLOR = Color3.fromRGB(30, 30, 30)
    local THEME_TRANSPARENCY = 0.5
    local GLOW_WIDTH = 20
    local HIT_COLOR = ConfigTable.Ragebot.HitColor

    local box = Instance.new("Frame")
    box.Parent = scrollFrame
    box.BackgroundColor3 = THEME_COLOR
    box.BackgroundTransparency = THEME_TRANSPARENCY
    box.BorderSizePixel = 0
    
    local function createGlow(side)
        local glow = Instance.new("Frame")
        glow.Size = UDim2.new(0, GLOW_WIDTH, 1, 0)
        glow.Position = (side == "Left") and UDim2.new(0, -GLOW_WIDTH, 0, 0) or UDim2.new(1, 0, 0, 0)
        glow.BackgroundColor3 = THEME_COLOR
        glow.BackgroundTransparency = THEME_TRANSPARENCY
        glow.BorderSizePixel = 0
        glow.Parent = box
        local grad = Instance.new("UIGradient")
        grad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, (side == "Left" and 1 or 0)), NumberSequenceKeypoint.new(1, (side == "Left" and 0 or 1))})
        grad.Parent = glow
    end
    createGlow("Left")
    createGlow("Right")

    local parts = {
        {"hit ", Color3.fromRGB(255, 255, 255)},
        {playerName .. " ", HIT_COLOR},
        {"on head ", Color3.fromRGB(255, 255, 255)},
        {"Health at ", Color3.fromRGB(200, 200, 200)},
        {tostring(health) .. " ", Color3.fromRGB(0, 255, 120)},
        {"in ", Color3.fromRGB(200, 200, 200)},
        {string.format("%.2f", offsetValue) .. " ", HIT_COLOR}
    }
    
    if usedCache then
        table.insert(parts, {" via cache", Color3.fromRGB(150, 150, 150)})
    end

    local offsetX = 8
    local totalW, maxH = 0, 0
    for _, seg in ipairs(parts) do
        local label = Instance.new("TextLabel")
        label.Parent = box
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.TextColor3 = seg[2]
        label.FontFace = CustomFont
        label.TextSize = 10
        label.Text = seg[1]
        label.AutomaticSize = Enum.AutomaticSize.XY
        
        label.Position = UDim2.new(0, offsetX, 0, 0)
        local xSize = label.TextBounds.X
        offsetX = offsetX + xSize
        totalW = offsetX
        maxH = math.max(maxH, label.TextBounds.Y)
    end

    box.Size = UDim2.new(0, totalW + 8, 0, maxH + 4)
    table.insert(hitNotifications, {box = box, createTime = tick()})

    local function updateScrollFrame()
        local currentY = 0
        for i, notif in ipairs(hitNotifications) do
            if notif.box and notif.box.Parent then
                notif.box.Position = UDim2.new(0, GLOW_WIDTH, 0, currentY)
                currentY = currentY + notif.box.AbsoluteSize.Y + 4
            end
        end
    end

    updateScrollFrame()

    task.delay(ConfigTable.Ragebot.HitNotifyDuration, function()
        for i, notif in ipairs(hitNotifications) do 
            if notif.box == box then 
                table.remove(hitNotifications, i) 
                box:Destroy() 
                break 
            end 
        end
        updateScrollFrame()
    end)
end

local function playHitSound()
    if not ConfigTable.Ragebot.HitSound then return end
    local soundIds = {
        ["Bameware"] = "rbxassetid://3124331820",
        ["Bell"] = "rbxassetid://6534947240",
        ["Bubble"] = "rbxassetid://6534947588",
        ["Pick"] = "rbxassetid://1347140027",
        ["Pop"] = "rbxassetid://198598793",
        ["Rust"] = "rbxassetid://1255040462",
        ["Sans"] = "rbxassetid://3188795283",
        ["Fart"] = "rbxassetid://130833677",
        ["Big"] = "rbxassetid://5332005053",
        ["Vine"] = "rbxassetid://5332680810",
        ["Bruh"] = "rbxassetid://4578740568",
        ["Skeet"] = "rbxassetid://5633695679",
        ["Neverlose"] = "rbxassetid://6534948092",
        ["Fatality"] = "rbxassetid://6534947869",
        ["Bonk"] = "rbxassetid://5766898159",
        ["Minecraft"] = "rbxassetid://4018616850",
        ["xp"] = "rbxassetid://17148249625"
    }
    local soundId = soundIds[ConfigTable.Ragebot.SelectedHitSound] or soundIds["Skeet"]
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.75
    sound.Parent = Workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 0.75)
end

local tracerTextures = {
    ["rbxassetid://7136858729"] = "rbxassetid://7136858729",
    ["rbxassetid://6060542021"] = "rbxassetid://6060542021",
    ["rbxassetid://446111271"] = "rbxassetid://446111271",
    ["rbxassetid://875688442"] = "rbxassetid://875688442"
}

local function createTracer(startPos, endPos)
    if not ConfigTable.Ragebot.Tracers then return end
    
    local tracerModel = Instance.new("Model")
    tracerModel.Name = "TracerBeam"
    
    local beam = Instance.new("Beam")
    beam.Color = ColorSequence.new(ConfigTable.Ragebot.TracerColor)
    beam.Width0 = ConfigTable.Ragebot.TracerWidth
    beam.Width1 = ConfigTable.Ragebot.TracerWidth
    beam.Texture = ConfigTable.Ragebot.TracerTexture
    beam.TextureSpeed = 1
    beam.Brightness = 2
    beam.LightEmission = 2
    beam.FaceCamera = true
    
    local a0 = Instance.new("Attachment")
    local a1 = Instance.new("Attachment")
    a0.WorldPosition = startPos
    a1.WorldPosition = endPos
    
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Parent = tracerModel
    a0.Parent = tracerModel
    a1.Parent = tracerModel
    tracerModel.Parent = Workspace
    
    local tweenInfo = TweenInfo.new(ConfigTable.Ragebot.TracerLifetime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(beam, tweenInfo, {Brightness = 0, Width0 = 0, Width1 = 0})
    tween:Play()
    
    tween.Completed:Connect(function()
        if tracerModel then tracerModel:Destroy() end
    end)
    
    task.delay(ConfigTable.Ragebot.TracerLifetime + 0.1, function()
        if tracerModel and tracerModel.Parent then tracerModel:Destroy() end
    end)
end

local function RandomString(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    for i = 1, length do 
        result = result .. charset:sub(math.random(1, #charset), math.random(1, #charset)) 
    end
    return result
end

local function shootAtTarget(targetHead)
    if not targetHead then return false end
    
    local localHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
    if not localHead then return false end
    
    local tool = getCurrentTool()
    if not tool then return false end
    
    local values = tool:FindFirstChild("Values")
    local hitMarker = tool:FindFirstChild("Hitmarker")
    if not values or not hitMarker then return false end
    
    local ammo = values:FindFirstChild("SERVER_Ammo")
    local storedAmmo = values:FindFirstChild("SERVER_StoredAmmo")
    if not ammo or not storedAmmo then return false end
    
    if ammo.Value <= 0 then 
        autoReload()
        Library:Notify("reloading...")
        return false 
    end
    
    local bestShootPos, bestHitPos = wallbang()
    if not bestShootPos or not bestHitPos then return false end
    
    local hitPosition = bestHitPos
    if ConfigTable.Ragebot.Prediction then 
        local velocity = targetHead.Velocity or Vector3.zero 
        hitPosition = hitPosition + velocity * ConfigTable.Ragebot.PredictionAmount 
    end
    
    local hitDirection = (hitPosition - bestShootPos).Unit
    local randomKey = RandomString(30) .. "0"
    
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end
    
    local GNX_S = events:FindFirstChild("GNX_S")
    local ZFKLF__H = events:FindFirstChild("ZFKLF__H")
    
    if not GNX_S or not ZFKLF__H then 
        Library:Notify("Failed to find remote events")
        return false 
    end
    
    local args1 = {tick(), randomKey, tool, "FDS9I83", bestShootPos, {hitDirection}, false}
    local args2 = {"🧈", tool, randomKey, 1, targetHead, hitPosition, hitDirection}
    
    local targetPlayer = Players:GetPlayerFromCharacter(targetHead.Parent)
    if targetPlayer then 
        local offset = (bestShootPos - localHead.Position).Magnitude
        local health = targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") and math.floor(targetPlayer.Character.Humanoid.Health) or 0
        Library:Notify("Hit " .. targetPlayer.Name .. " [" .. health .. "HP] " .. string.format("%.1f", offset) .. "m")
        playHitSound() 
    end
    
    GNX_S:FireServer(unpack(args1))
    ZFKLF__H:FireServer(unpack(args2))
    hitMarker:Fire(targetHead)
    
    if storedAmmo then
        storedAmmo.Value = storedAmmo.Value
    end
    
    createTracer(bestShootPos, hitPosition)
    return true
end

coroutine.wrap(function()
    while wait() do
        if not (ConfigTable.Ragebot.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") and getClosestTarget()) then continue end
        
        
        local target = getClosestTarget()
        local currentTool
        
        for _, tool in pairs(LocalPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") then currentTool = tool break end
        end
        
        local isSpecial = currentTool and (currentTool.Name == "TEC-9" or currentTool.Name == "Beretta")
        local fireRate
        
        if isSpecial then
            fireRate = ConfigTable.Ragebot.RapidFire and 9e14 or ConfigTable.Ragebot.FireRate
        else
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and rawget(v, "FireRate") and rawget(v, "Damage") and rawget(v, "MagSize") then
                    fireRate = rawget(v, "FireRate")
                    break
                end
            end
            fireRate = fireRate or 2.5
        end
        
        local currentTime = tick()
        if not isSpecial or not ConfigTable.Ragebot.RapidFire then
            if currentTime - lastShotTime >= 1 / fireRate then
                shootAtTarget(target)
                lastShotTime = currentTime
            end
        else
            shootAtTarget(target)
        end
    end
end)()
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/Library.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "skegg - Paid version",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab("Ragebot"),
    Misc = Window:AddTab("Misc"),
    --Targets = Window:AddTab("Targets"),
    UI = Window:AddTab("UI")
}

local RagebotGroup = Tabs.Main:AddLeftGroupbox("Ragebot Settings")

RagebotGroup:AddToggle("RagebotEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v) ConfigTable.Ragebot.Enabled = v end
})

RagebotGroup:AddDivider()

RagebotGroup:AddToggle("RapidFire", {
    Text = "Rapid Fire",
    Default = false,
    Callback = function(v) ConfigTable.Ragebot.RapidFire = v end
})

RagebotGroup:AddSlider("FireRate", {
    Text = "Fire Rate",
    Default = 30,
    Min = 1,
    Max = 100,
    Rounding = 1,
    Callback = function(v) ConfigTable.Ragebot.FireRate = v end
})

RagebotGroup:AddToggle("AutoReload", {
    Text = "Auto Reload",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.AutoReload = v end
})

RagebotGroup:AddDivider()

RagebotGroup:AddToggle("Prediction", {
    Text = "Prediction",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.Prediction = v end
})

RagebotGroup:AddSlider("PredictionAmount", {
    Text = "Prediction Amount",
    Default = 0.12,
    Min = 0.05,
    Max = 0.3,
    Rounding = 2,
    Callback = function(v) ConfigTable.Ragebot.PredictionAmount = v end
})

RagebotGroup:AddToggle("Wallbang", {
    Text = "Wallbang",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.Wallbang = v end
})

RagebotGroup:AddSlider("ShootRange", {
    Text = "Shoot Range",
    Default = 15,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(v) ConfigTable.Ragebot.ShootRange = v end
})

RagebotGroup:AddSlider("HitRange", {
    Text = "Hit Range",
    Default = 15,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(v) ConfigTable.Ragebot.HitRange = v end
})

local TargetGroup = Tabs.Main:AddRightGroupbox("Target Settings")

TargetGroup:AddToggle("TeamCheck", {
    Text = "Team Check",
    Default = false,
    Callback = function(v) ConfigTable.Ragebot.TeamCheck = v end
})

TargetGroup:AddToggle("VisibilityCheck", {
    Text = "Visibility Check",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.VisibilityCheck = v end
})

TargetGroup:AddToggle("FriendCheck", {
    Text = "Friend Check",
    Default = false,
    Callback = function(v) ConfigTable.Ragebot.FriendCheck = v end
})

TargetGroup:AddToggle("LowHealthCheck", {
    Text = "Low Health Check",
    Default = false,
    Callback = function(v) ConfigTable.Ragebot.LowHealthCheck = v end
})

TargetGroup:AddSlider("MaxTargets", {
    Text = "Max Targets",
    Default = 0,
    Min = 0,
    Max = 10,
    Rounding = 0,
    Callback = function(v) ConfigTable.Ragebot.MaxTarget = v end
})

TargetGroup:AddDivider()

TargetGroup:AddToggle("UseTargetList", {
    Text = "Use Target List",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.UseTargetList = v end
})

TargetGroup:AddToggle("UseWhitelist", {
    Text = "Use Whitelist",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.UseWhitelist = v end
})

local VisualGroup = Tabs.Main:AddLeftGroupbox("Visual Settings")

VisualGroup:AddToggle("Tracers", {
    Text = "Tracers",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.Tracers = v end
}):AddColorPicker("TracerColor", {
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(c) ConfigTable.Ragebot.TracerColor = c end
})

VisualGroup:AddSlider("TracerWidth", {
    Text = "Tracer Width",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Callback = function(v) ConfigTable.Ragebot.TracerWidth = v end
})

VisualGroup:AddSlider("TracerLifetime", {
    Text = "Tracer Lifetime",
    Default = 3,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) ConfigTable.Ragebot.TracerLifetime = v end
})

local TracerTextureList = {"rbxassetid://7136858729", "rbxassetid://6060542021", "rbxassetid://446111271", "rbxassetid://875688442"}

local TracerDropdown = VisualGroup:AddDropdown("TracerTexture", {
    Values = TracerTextureList,
    Default = "rbxassetid://7136858729",
    Text = "Tracer Texture",
    Callback = function(v) ConfigTable.Ragebot.TracerTexture = v end
})

VisualGroup:AddDivider()

VisualGroup:AddToggle("HitNotify", {
    Text = "Hit Notify",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.HitNotify = v end
}):AddColorPicker("HitColor", {
    Default = Color3.fromRGB(255, 182, 193),
    Callback = function(c) ConfigTable.Ragebot.HitColor = c end
})

VisualGroup:AddSlider("NotifyDuration", {
    Text = "Notify Duration",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) ConfigTable.Ragebot.HitNotifyDuration = v end
})

VisualGroup:AddToggle("HitSound", {
    Text = "Hit Sound",
    Default = true,
    Callback = function(v) ConfigTable.Ragebot.HitSound = v end
})

local SoundList = {"Skeet", "Neverlose", "Fatality", "Bameware", "Bell", "Bubble", "Pop", "Rust", "Sans", "Minecraft", "xp"}

local SoundDropdown = VisualGroup:AddDropdown("HitSoundType", {
    Values = SoundList,
    Default = "Skeet",
    Text = "Hit Sound",
    Callback = function(v) ConfigTable.Ragebot.SelectedHitSound = v end
})


local function GetOnlinePlayers()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    return players
end

local OnlineDropdown = TargetGroup:AddDropdown("OnlinePlayers", {
    Values = GetOnlinePlayers(),
    Default = 1,
    Text = "Online Players",
    Callback = function(selected) 
        if typeof(selected) == "table" then
            currentSelectedPlayer = selected[1]
        else
            currentSelectedPlayer = selected
        end
    end
})
TargetGroup:AddButton({
    Text = "Add to Target List",
    Func = function()
        local name = tostring(currentSelectedPlayer)
        if name and name ~= "nil" then
            if not tablecontains(TargetList, name) then
                table.insert(TargetList, name)
               -- TargetListDropdown:SetValues(TargetList)
                Library:Notify("Added " .. name .. " to Target List")
            end
        end
    end
})

TargetGroup:AddButton({
    Text = "Add to Whitelist",
    Func = function()
        local name = tostring(currentSelectedPlayer)
        if name and name ~= "nil" then
            if not tablecontains(Whitelist, name) then
                table.insert(Whitelist, name)
              --  WhitelistDropdown:SetValues(Whitelist)
                Library:Notify("Added " .. name .. " to Whitelist")
            end
        end
    end
})
TargetGroup:AddButton({
    Text = "Clear Selected Player",
    Func = function()
        local name = tostring(currentSelectedPlayer)
        if name and name ~= "nil" then
            for i, v in ipairs(TargetList) do if v == name then 
                table.remove(TargetList, i) 
              --  TargetListDropdown:SetValues(TargetList)
                Library:Notify("Removed " .. name .. " from Target List")
                break 
            end end
            for i, v in ipairs(Whitelist) do if v == name then 
                table.remove(Whitelist, i) 
              --  WhitelistDropdown:SetValues(Whitelist)
                  Library:Notify("Removed " .. name .. " from Whitelist")
                break 
            end end
        else
            Library:Notify("No player selected")
        end
    end
})

TargetGroup:AddButton({
    Text = "Clear All Lists",
    Func = function()
        table.clear(TargetList)
        table.clear(Whitelist)
      --  TargetListDropdown:SetValues({})
      --  WhitelistDropdown:SetValues({})
        Library:Notify("Cleared all lists")
    end
})

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        local newPlayers = GetOnlinePlayers()
        OnlineDropdown:SetValues(newPlayers)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player ~= LocalPlayer then
        local newPlayers = GetOnlinePlayers()
        OnlineDropdown:SetValues(newPlayers)
        
        local name = player.Name
        for i, v in ipairs(TargetList) do if v == name then 
            table.remove(TargetList, i) 
           -- TargetListDropdown:SetValues(TargetList)
            break 
        end end
        for i, v in ipairs(Whitelist) do if v == name then 
            table.remove(Whitelist, i) 
           -- WhitelistDropdown:SetValues(Whitelist)
            break 
        end end
    end
end)
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local forceTimeEnabled = false
local forceTimeValue = 12
local forceTimeConnection = nil

local speedEnabled = false
local speedValue = 50
local speedConnection = nil

local flyEnabled = false
local flySpeed = 50
local flyConnection = nil

local jumpPowerEnabled = false
local jumpPowerValue = 100
local jumpPowerConnection = nil

local loopFOVEnabled = false
local fovConnection = nil

local infStaminaEnabled = false
local infStaminaHook = nil

local noFallEnabled = false
local noFallHook = nil

local lockpickEnabled = false
local lockpickAddedConnection = nil

local instantPromptEnabled = false
local instantPromptConnection = nil

local autoDoorEnabled = false
local doorConnection = nil

local hideHeadEnabled = false
local hideHeadHook = nil
local hideHeadConnection = nil

local QuickUIFrame = Instance.new("Frame")
QuickUIFrame.Name = "QuickUIFrame"
QuickUIFrame.Size = UDim2.new(0, 80, 0, 30)
QuickUIFrame.Position = UDim2.new(0, 10, 0, 50)
QuickUIFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
QuickUIFrame.BackgroundTransparency = 0.5
QuickUIFrame.BorderSizePixel = 0

local QuickUIText = Instance.new("TextButton")
QuickUIText.Name = "QuickUIText"
QuickUIText.Size = UDim2.new(1, 0, 1, 0)
QuickUIText.BackgroundTransparency = 1
QuickUIText.Text = "FLY OFF"
QuickUIText.TextColor3 = Color3.fromRGB(255, 50, 50)
QuickUIText.Font = Enum.Font.GothamBold
QuickUIText.TextSize = 12
QuickUIText.Parent = QuickUIFrame

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "QuickUIScreen"
ScreenGui.Parent = CoreGui
QuickUIFrame.Parent = ScreenGui

local function enableForceTime()
    if forceTimeConnection then forceTimeConnection:Disconnect() end
    forceTimeConnection = RunService.RenderStepped:Connect(function()
        if not forceTimeEnabled then return end
        Lighting.ClockTime = forceTimeValue
        Lighting.TimeOfDay = string.format("%02d:00:00", forceTimeValue)
    end)
end

local function disableForceTime()
    if forceTimeConnection then forceTimeConnection:Disconnect() forceTimeConnection = nil end
end

local function enableSpeed()
    if speedConnection then speedConnection:Disconnect() end
    speedConnection = RunService.RenderStepped:Connect(function()
        if not speedEnabled then return end
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end
        humanoid.WalkSpeed = speedValue
    end)
end

local function disableSpeed()
    if speedConnection then speedConnection:Disconnect() speedConnection = nil end
    local character = LocalPlayer.Character
    if character then 
        local humanoid = character:FindFirstChild("Humanoid") 
        if humanoid then humanoid.WalkSpeed = 16 end 
    end
end

local function startFlying()
    local Char = LocalPlayer.Character
    if not Char then return end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Hum or not Root then return end
    
    local RagdollEvent = ReplicatedStorage:FindFirstChild("Events"):FindFirstChild("__RZDONL")
    if not RagdollEvent then
        RagdollEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("__RZDONL")
    end
    
    for _,child in ipairs(Char:GetDescendants()) do 
        if child:IsA("Motor6D") then child.Enabled = false end 
    end
    
    Hum.PlatformStand = true
    Hum:ChangeState(Enum.HumanoidStateType.Freefall)
    
    local flyMotors = {}
    for _,part in ipairs(Char:GetDescendants()) do
        if part:IsA("BasePart") and part ~= Root then
            local motor = Instance.new("Motor6D")
            motor.Name = "FlyMotor"
            motor.Part0 = Root
            motor.Part1 = part
            motor.C1 = CFrame.new()
            motor.C0 = Root.CFrame:ToObjectSpace(part.CFrame)
            motor.Parent = part
            table.insert(flyMotors, motor)
        end
    end
    
    flyConnection = RunService.Heartbeat:Connect(function()
        if not flyEnabled then
            if flyConnection then flyConnection:Disconnect() flyConnection = nil end
            Hum.PlatformStand = false
            Root.Velocity = Vector3.new(0,0,0)
            Hum:ChangeState(Enum.HumanoidStateType.Running)
            for _,motor in ipairs(flyMotors) do motor:Destroy() end
            for _,child in ipairs(Char:GetDescendants()) do 
                if child:IsA("Motor6D") and child.Name ~= "FlyMotor" then child.Enabled = true end 
            end
            return
        end
        
        local Cam = Workspace.CurrentCamera
        if not Cam then return end
        
        local cameraLook = Cam.CFrame.LookVector
        local IsMoving = Hum.MoveDirection.Magnitude > 0
        local targetLook = Vector3.new(cameraLook.X, cameraLook.Y, cameraLook.Z)
        
        if targetLook.Magnitude > 0 then 
            targetLook = targetLook.Unit 
            Root.CFrame = CFrame.new(Root.Position, Root.Position + targetLook) 
        end
        
        if IsMoving then
            local moveVector = Vector3.new(cameraLook.X, cameraLook.Y, cameraLook.Z).Unit
            Root.Velocity = moveVector * flySpeed
            RagdollEvent:FireServer("__---r",Vector3.zero,CFrame.new(-4574,3,-443,0,0,1,0,1,0,-1,0,0),true)
        else 
            Root.Velocity = Vector3.new(0,0,0) 
        end
    end)
end

local function disableFlying()
    flyEnabled = false
    if flyConnection then 
        flyConnection:Disconnect() 
        flyConnection = nil 
    end
    
    local Char = LocalPlayer.Character
    if not Char then return end
    
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    
    if Hum then
        Hum.PlatformStand = false
        Hum:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    if Root then
        Root.Velocity = Vector3.new(0,0,0)
    end
    
    for _, part in ipairs(Char:GetDescendants()) do
        local motor = part:FindFirstChild("FlyMotor")
        if motor then motor:Destroy() end
    end
    
    for _, child in ipairs(Char:GetDescendants()) do 
        if child:IsA("Motor6D") and child.Name ~= "FlyMotor" then 
            child.Enabled = true 
        end 
    end
end

QuickUIText.MouseButton1Click:Connect(function()
    flyEnabled = not flyEnabled
    if flyEnabled then 
        QuickUIText.Text = "FLY ON" 
        QuickUIText.TextColor3 = Color3.fromRGB(50, 255, 50) 
        startFlying()
    else 
        QuickUIText.Text = "FLY OFF" 
        QuickUIText.TextColor3 = Color3.fromRGB(255, 50, 50) 
        disableFlying() 
    end
end)

local function enableJumpPower()
    if jumpPowerConnection then jumpPowerConnection:Disconnect() end
    jumpPowerConnection = RunService.Heartbeat:Connect(function()
        if not jumpPowerEnabled then return end
        if not LocalPlayer.Character then return end
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if humanoid:GetState() == Enum.HumanoidStateType.Jumping then 
            hrp.Velocity = Vector3.new(hrp.Velocity.X, jumpPowerValue, hrp.Velocity.Z) 
        end
    end)
end

local function disableJumpPower()
    if jumpPowerConnection then jumpPowerConnection:Disconnect() jumpPowerConnection = nil end
end

local function enableLoopFOV()
    if fovConnection then fovConnection:Disconnect() end
    fovConnection = RunService.RenderStepped:Connect(function()
        if not loopFOVEnabled then return end
        Workspace.CurrentCamera.FieldOfView = 120
    end)
end

local function disableLoopFOV()
    if fovConnection then fovConnection:Disconnect() fovConnection = nil end
end

local function enableInfStamina()
    if infStaminaHook then return end
    local module
    for i,v in pairs(game:GetService("StarterPlayer").StarterPlayerScripts:GetDescendants()) do 
        if v:IsA("ModuleScript") and v.Name == "XIIX" then 
            module = v 
            break 
        end 
    end
    if module then
        module = require(module)
        local ac = module["XIIX"]
        local glob = getfenv(ac)["_G"]
        local stamina = getupvalues((getupvalues(glob["S_Check"]))[2])[1]
        if stamina ~= nil then 
            infStaminaHook = hookfunction(stamina,function() return 100,100 end) 
        end
    end
end

local function disableInfStamina()
    if infStaminaHook then 
        hookfunction(infStaminaHook, function() end)
        infStaminaHook = nil 
    end
end

local function enableNoFallDmg()
    if noFallHook then return end
    noFallHook = hookmetamethod(game,"__namecall",function(self,...)
        local args = {...}
        if getnamecallmethod() == "FireServer" and not checkcaller() and args[1] == "FlllD" and args[4] == false then 
            args[2] = 0 
            args[3] = 0 
        end
        return noFallHook(self,unpack(args))
    end)
end

local function disableNoFallDmg()
    if noFallHook then 
        hookmetamethod(game,"__namecall",noFallHook) 
        noFallHook = nil 
    end
end

local function enableLockpick()
    lockpickEnabled = true
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return end
    local function lockpick(gui)
        for _,a in pairs(gui:GetDescendants()) do
            if a:IsA("ImageLabel") and a.Name == "Bar" and a.Parent.Name ~= "Attempts" then
                local oldsize = a.Size
                RunService.RenderStepped:Connect(function()
                    if lockpickEnabled then a.Size = UDim2.new(0,280,0,280) else a.Size = oldsize end
                end)
            end
        end
    end
    if lockpickAddedConnection then lockpickAddedConnection:Disconnect() end
    lockpickAddedConnection = PlayerGui.ChildAdded:Connect(function(child) 
        if child:IsA("ScreenGui") and child.Name == "LockpickGUI" then lockpick(child) end 
    end)
    for _,child in pairs(PlayerGui:GetChildren()) do 
        if child:IsA("ScreenGui") and child.Name == "LockpickGUI" then lockpick(child) end 
    end
end

local function disableLockpick()
    lockpickEnabled = false
    if lockpickAddedConnection then 
        lockpickAddedConnection:Disconnect() 
        lockpickAddedConnection = nil 
    end
end

local function enableInstantPrompt()
    instantPromptEnabled = true
    for _,obj in pairs(game:GetDescendants()) do 
        if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end 
    end
    if instantPromptConnection then instantPromptConnection:Disconnect() end
    instantPromptConnection = game.DescendantAdded:Connect(function(obj) 
        if obj:IsA("ProximityPrompt") then task.wait() obj.HoldDuration = 0 end 
    end)
end

local function disableInstantPrompt()
    instantPromptEnabled = false
    if instantPromptConnection then 
        instantPromptConnection:Disconnect() 
        instantPromptConnection = nil 
    end
    for _,obj in pairs(game:GetDescendants()) do 
        if obj:IsA("ProximityPrompt") then obj.HoldDuration = 1 end 
    end
end

local function enableAutoDoor()
    autoDoorEnabled = true
    if doorConnection then doorConnection:Disconnect() end
    doorConnection = RunService.Heartbeat:Connect(function()
        if not autoDoorEnabled then return end
        if not LocalPlayer.Character then return end
        local charRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not charRoot then return end
        local Map = Workspace:FindFirstChild("Map")
        if not Map then return end
        local Doors = Map:FindFirstChild("Doors")
        if not Doors then return end
        local closestDoor = nil
        local closestDistance = 15
        for _,door in pairs(Doors:GetChildren()) do
            local knob = door:FindFirstChild("Knob1") or door:FindFirstChild("Knob2")
            if knob then
                local distance = (knob.Position - charRoot.Position).Magnitude
                if distance < closestDistance then 
                    closestDistance = distance 
                    closestDoor = door 
                end
            end
        end
        if closestDoor then
            local knob = closestDoor:FindFirstChild("Knob1") or closestDoor:FindFirstChild("Knob2")
            local events = closestDoor:FindFirstChild("Events")
            local toggleEvent = events and events:FindFirstChild("Toggle")
            if knob and toggleEvent then 
                local args = {"Open",knob} 
                toggleEvent:FireServer(unpack(args)) 
            end
        end
    end)
end

local function disableAutoDoor()
    autoDoorEnabled = false
    if doorConnection then doorConnection:Disconnect() doorConnection = nil end
end

local function lockNeckMotorForHideHead()
    local character = LocalPlayer.Character
    if not character then return end
    
    local torso = character:FindFirstChild("Torso")
    if not torso then return end
    
    local neck = torso:FindFirstChild("Neck")
    if not neck or not neck:IsA("Motor6D") then return end
    
    if hideHeadConnection then hideHeadConnection:Disconnect() end
    
    hideHeadConnection = RunService.RenderStepped:Connect(function()
        if not hideHeadEnabled then
            if hideHeadConnection then hideHeadConnection:Disconnect() hideHeadConnection = nil end
            return
        end
        neck.C0 = CFrame.new(0, 0, 0.75) * CFrame.Angles(math.rad(90), 0, 0)
        neck.C1 = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, 0)
    end)
end

local function restoreNeckMotorsForHideHead()
    if hideHeadConnection then hideHeadConnection:Disconnect() hideHeadConnection = nil end
end

local function updateHideHeadHook()
    if hideHeadEnabled then
        if not hideHeadHook then
            hideHeadHook = hookmetamethod(game, "__namecall", function(self, ...)
                local methodName = getnamecallmethod()
                if tostring(methodName) == "FireServer" then
                    if self.Name == "MOVZREP" then 
                        if hideHeadEnabled then
                            local fixedArguments = {
                                {
                                    {
                                        Vector3.new(-5721.2001953125,-5,971.5162353515625),
                                        Vector3.new(-4181.38818359375,-6,11.123311996459961),
                                        Vector3.new(0.006237113382667303,-6,-0.18136750161647797),
                                        true,
                                        true,
                                        true,
                                        false
                                    },
                                    false,
                                    false,
                                    15.8
                                }
                            }
                            return hideHeadHook(self, table.unpack(fixedArguments))
                        end
                    end
                end
                return hideHeadHook(self, ...)
            end)
        end
        lockNeckMotorForHideHead()
    else
        if hideHeadHook then
            hookmetamethod(game, "__namecall", hideHeadHook)
            hideHeadHook = nil
        end
        restoreNeckMotorsForHideHead()
    end
end

local MovementSection = Tabs.Misc:AddLeftGroupbox("Movement")

MovementSection:AddToggle("SpeedEnabled", {
    Text = "Speed",
    Default = false,
    Callback = function(v)
        speedEnabled = v
        if v then enableSpeed() else disableSpeed() end
    end
})

MovementSection:AddSlider("SpeedValue", {
    Text = "Speed Value",
    Default = 50,
    Min = 16,
    Max = 200,
    Rounding = 1,
    Callback = function(v) speedValue = v end
})

MovementSection:AddToggle("FlyEnabled", {
    Text = "Fly",
    Default = false,
    Callback = function(v)
        flyEnabled = v
        QuickUIText.Text = v and "FLY ON" or "FLY OFF"
        QuickUIText.TextColor3 = v and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
        if v then startFlying() else disableFlying() end
    end
})

MovementSection:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 1,
    Callback = function(v) flySpeed = v end
})

MovementSection:AddToggle("JumpPowerEnabled", {
    Text = "Jump Power",
    Default = false,
    Callback = function(v)
        jumpPowerEnabled = v
        if v then enableJumpPower() else disableJumpPower() end
    end
})

MovementSection:AddSlider("JumpPowerValue", {
    Text = "Jump Value",
    Default = 100,
    Min = 50,
    Max = 300,
    Rounding = 1,
    Callback = function(v) jumpPowerValue = v end
})

local WorldSection = Tabs.Misc:AddRightGroupbox("World")

WorldSection:AddToggle("ForceTimeEnabled", {
    Text = "Force Time",
    Default = false,
    Callback = function(v)
        forceTimeEnabled = v
        if v then enableForceTime() else disableForceTime() end
    end
})

WorldSection:AddSlider("ForceTimeValue", {
    Text = "Time",
    Default = 12,
    Min = 0,
    Max = 24,
    Rounding = 1,
    Suffix = "hr",
    Callback = function(v)
        forceTimeValue = v
        if forceTimeEnabled then
            Lighting.ClockTime = forceTimeValue
            Lighting.TimeOfDay = string.format("%02d:00:00", forceTimeValue)
        end
    end
})

local ToolsSection = Tabs.Misc:AddRightGroupbox("Tools")

ToolsSection:AddToggle("LoopFOVEnabled", {
    Text = "Loop FOV",
    Default = false,
    Callback = function(v)
        loopFOVEnabled = v
        if v then enableLoopFOV() else disableLoopFOV() end
    end
})

ToolsSection:AddToggle("InfStaminaEnabled", {
    Text = "Inf Stamina",
    Default = false,
    Callback = function(v)
        infStaminaEnabled = v
        if v then enableInfStamina() else disableInfStamina() end
    end
})

ToolsSection:AddToggle("NoFallEnabled", {
    Text = "No Fall Damage",
    Default = false,
    Callback = function(v)
        noFallEnabled = v
        if v then enableNoFallDmg() else disableNoFallDmg() end
    end
})

ToolsSection:AddToggle("LockpickEnabled", {
    Text = "No Fail Lockpick",
    Default = false,
    Callback = function(v)
        lockpickEnabled = v
        if v then enableLockpick() else disableLockpick() end
    end
})

ToolsSection:AddToggle("InstantPromptEnabled", {
    Text = "Instant Prompt",
    Default = false,
    Callback = function(v)
        instantPromptEnabled = v
        if v then enableInstantPrompt() else disableInstantPrompt() end
    end
})

ToolsSection:AddToggle("AutoDoorEnabled", {
    Text = "Auto Door",
    Default = false,
    Callback = function(v)
        autoDoorEnabled = v
        if v then enableAutoDoor() else disableAutoDoor() end
    end
})

ToolsSection:AddToggle("HideHeadEnabled", {
    Text = "Hide Head",
    Default = false,
    Callback = function(v)
        hideHeadEnabled = v
        updateHideHeadHook()
    end
})
local SafeESP = {
    Enabled = false,
    Cache = {},
    HighlightObjs = {},
    BillboardObjs = {},
    Connection = nil,
    MaxDistance = 250
}

local function createSafeESP(safePart)
    if not safePart or not safePart.Parent then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "SafeHighlight"
    highlight.FillColor = Color3.fromRGB(255, 215, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = safePart.Parent
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SafeBillboard"
    billboard.Size = UDim2.new(0, 120, 0, 35)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = safePart.Parent
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "SAFE"
    label.TextColor3 = Color3.fromRGB(255, 215, 0)
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.Code
    label.TextSize = 16
    label.Parent = frame
    
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, 0, 0, 15)
    distanceLabel.Position = UDim2.new(0, 0, 1, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = ""
    distanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distanceLabel.Font = Enum.Font.Code
    distanceLabel.TextSize = 12
    distanceLabel.Parent = billboard
    
    SafeESP.HighlightObjs[safePart.Parent] = highlight
    SafeESP.BillboardObjs[safePart.Parent] = billboard
end

local function updateSafeDistances()
    if not SafeESP.Enabled then return end
    
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    local cameraPos = camera.CFrame.Position
    
    for model, billboard in pairs(SafeESP.BillboardObjs) do
        if model and model.PrimaryPart then
            local distance = (model.PrimaryPart.Position - cameraPos).Magnitude
            local distanceLabel = billboard:FindFirstChild("DistanceLabel")
            
            if distance <= SafeESP.MaxDistance then
                billboard.Enabled = true
                SafeESP.HighlightObjs[model].Enabled = true
                if distanceLabel then
                    distanceLabel.Text = math.floor(distance) .. "studs"
                end
            else
                billboard.Enabled = false
                SafeESP.HighlightObjs[model].Enabled = false
            end
        end
    end
end

local function scanForSafes()
    if not SafeESP.Enabled then return end
    
    local scanStart = tick()
    local scanCount = 0
    local maxScanTime = 0.01
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if not SafeESP.Enabled then break end
        if scanCount > 50 or tick() - scanStart > maxScanTime then
            task.wait()
            scanStart = tick()
            scanCount = 0
        end
        
        if obj:IsA("BasePart") and obj.Name then
            local objName = obj.Name:lower()
            if (objName:find("smallsafe") or objName:find("mediumsafe")) and not SafeESP.Cache[obj] then
                SafeESP.Cache[obj] = true
                createSafeESP(obj)
                scanCount = scanCount + 1
            end
        end
    end
end

local function clearSafeESP()
    for _, highlight in pairs(SafeESP.HighlightObjs) do
        if highlight then highlight:Destroy() end
    end
    for _, billboard in pairs(SafeESP.BillboardObjs) do
        if billboard then billboard:Destroy() end
    end
    SafeESP.HighlightObjs = {}
    SafeESP.BillboardObjs = {}
    SafeESP.Cache = {}
end

local function enableSafeESP()
    SafeESP.Enabled = true
    if SafeESP.Connection then SafeESP.Connection:Disconnect() end
    SafeESP.Connection = RunService.RenderStepped:Connect(function()
        if not SafeESP.Enabled then return end
        scanForSafes()
        updateSafeDistances()
    end)
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name then
            local objName = obj.Name:lower()
            if objName:find("smallsafe") or objName:find("mediumsafe") then
                SafeESP.Cache[obj] = true
                createSafeESP(obj)
                break
            end
        end
    end
end

local function disableSafeESP()
    SafeESP.Enabled = false
    if SafeESP.Connection then
        SafeESP.Connection:Disconnect()
        SafeESP.Connection = nil
    end
    clearSafeESP()
end

local function onSafeAdded(obj)
    if not SafeESP.Enabled then return end
    if obj:IsA("BasePart") and obj.Name then
        local objName = obj.Name:lower()
        if (objName:find("smallsafe") or objName:find("mediumsafe")) and not SafeESP.Cache[obj] then
            task.wait(0.05)
            SafeESP.Cache[obj] = true
            createSafeESP(obj)
        end
    end
end

Workspace.DescendantAdded:Connect(onSafeAdded)

local SafeESPSection = Tabs.Misc:AddRightGroupbox("Safe")

SafeESPSection:AddToggle("SafeESPEnabled", {
    Text = "Enable Safe ESP",
    Default = false,
    Callback = function(v)
        if v then
            enableSafeESP()
            Library:Notify("Safe ESP Enabled")
        else
            disableSafeESP()
            Library:Notify("Safe ESP Disabled")
        end
    end
})

SafeESPSection:AddSlider("SafeMaxDistance", {
    Text = "Max Distance",
    Default = 250,
    Min = 50,
    Max = 500,
    Rounding = 1,
    Suffix = "studs",
    Callback = function(v)
        SafeESP.MaxDistance = v
    end
})
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Settings = {
    Enabled = true,
    Box = true,
    BoxTransparency = 0.5,
    Skeleton = true,
    HealthBar = true,
    Names = true,
    Distance = true,
    Colors = {
        Box = Color3.fromRGB(255, 255, 255),
        Skeleton = Color3.fromRGB(255, 255, 255),
        Name = Color3.fromRGB(255, 255, 255),
        Distance = Color3.fromRGB(220, 220, 220),
        HealthLow = Color3.fromRGB(255, 0, 0),
        HealthMid = Color3.fromRGB(255, 255, 0),
        HealthHigh = Color3.fromRGB(0, 255, 0)
    }
}

local WorldSettings = {
    Enabled = false,
    ColorCorrection = false,
    Brightness = 1,
    Contrast = 0,
    Saturation = 1,
    TintColor = Color3.fromRGB(255, 255, 255),
    Ambient = Color3.fromRGB(128, 128, 128),
    OutdoorAmbient = Color3.fromRGB(128, 128, 128),
    FogColor = Color3.fromRGB(192, 192, 192),
    FogStart = 0,
    FogEnd = 1000,
    FogEnabled = false,
    GlobalShadows = true
}

local Library = {
    directory = "YourLibraryFolder",
    folders = {"fonts", "configs"}
}

for _, path in next, Library.folders do 
    if not isfolder(Library.directory .. "/" .. path) then makefolder(Library.directory .. "/" .. path) end
end

local fontPath = Library.directory .. "/fonts/main.ttf"
local encodedPath = Library.directory .. "/fonts/main_encoded.ttf"
local fontUrl = "https://github.com/f1nobe7650/Nebula/raw/refs/heads/main/Minecraftia-Regular.ttf"

if not isfile(fontPath) then
    writefile(fontPath, game:HttpGet(fontUrl))
end

local minecraftia = {
    name = "Minecraftia",
    faces = {{name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(fontPath)}}
}
writefile(encodedPath, game:GetService("HttpService"):JSONEncode(minecraftia))
Library.font = Font.new(getcustomasset(encodedPath))

local WTVP, UD2_Offset, UD2_Scale = Camera.WorldToViewportPoint, UDim2.fromOffset, UDim2.fromScale

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.IgnoreGuiInset = true

local R6_Rig = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local R15_Rig = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}, {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"}
}

local Cache = {}
local ColorCorrection = Instance.new("ColorCorrectionEffect", Lighting)

local function UpdateWorld()
    if not WorldSettings.Enabled then
        ColorCorrection.Enabled = false
        return
    end
    
    if WorldSettings.ColorCorrection then
        ColorCorrection.Enabled = true
        ColorCorrection.Brightness = WorldSettings.Brightness
        ColorCorrection.Contrast = WorldSettings.Contrast
        ColorCorrection.Saturation = WorldSettings.Saturation
        ColorCorrection.TintColor = WorldSettings.TintColor
    else
        ColorCorrection.Enabled = false
    end
    
    Lighting.Ambient = WorldSettings.Ambient
    Lighting.OutdoorAmbient = WorldSettings.OutdoorAmbient
    Lighting.FogColor = WorldSettings.FogColor
    Lighting.FogStart = WorldSettings.FogStart
    Lighting.FogEnd = WorldSettings.FogEnd
    Lighting.FogEnabled = WorldSettings.FogEnabled
    Lighting.GlobalShadows = WorldSettings.GlobalShadows
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    local Obj = {Lines = {}}

    local Container = Instance.new("Frame", ScreenGui)
    Container.BackgroundTransparency = 1
    Container.Visible = false
    
    local Box = Instance.new("Frame", Container)
    Box.BorderSizePixel = 0
    Box.BackgroundColor3 = Settings.Colors.Box
    Box.BackgroundTransparency = Settings.BoxTransparency
    Box.Size = UD2_Scale(1, 1)
    local BoxStroke = Instance.new("UIStroke", Box)
    BoxStroke.Color = Color3.new(0,0,0)
    BoxStroke.Thickness = 1

    local HealthOutline = Instance.new("Frame", Container)
    HealthOutline.BackgroundColor3 = Color3.new(0, 0, 0)
    HealthOutline.BorderSizePixel = 0
    
    local HealthInner = Instance.new("Frame", HealthOutline)
    HealthInner.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    HealthInner.BorderSizePixel = 0
    HealthInner.Position = UD2_Offset(1, 1)

    local HealthBar = Instance.new("Frame", HealthInner)
    HealthBar.BorderSizePixel = 0
    HealthBar.Size = UD2_Scale(1, 1)
    
    local Gradient = Instance.new("UIGradient", HealthBar)
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Settings.Colors.HealthLow),
        ColorSequenceKeypoint.new(0.5, Settings.Colors.HealthMid),
        ColorSequenceKeypoint.new(1, Settings.Colors.HealthHigh)
    })
    Gradient.Rotation = -90

    local HealthText = Instance.new("TextLabel", Container)
    HealthText.BackgroundTransparency = 1
    HealthText.FontFace = Library.font
    HealthText.TextColor3 = Color3.new(1, 1, 1)
    HealthText.TextSize = 12
    HealthText.TextStrokeTransparency = 0
    HealthText.TextXAlignment = Enum.TextXAlignment.Right
    HealthText.Size = UD2_Offset(40, 12)

    local NameLabel = Instance.new("TextLabel", ScreenGui)
    NameLabel.BackgroundTransparency = 1
    NameLabel.FontFace = Library.font
    NameLabel.TextColor3 = Settings.Colors.Name
    NameLabel.TextSize = 13
    NameLabel.TextStrokeTransparency = 0
    
    local DistanceLabel = Instance.new("TextLabel", ScreenGui)
    DistanceLabel.BackgroundTransparency = 1
    DistanceLabel.FontFace = Library.font
    DistanceLabel.TextColor3 = Settings.Colors.Distance
    DistanceLabel.TextSize = 11
    DistanceLabel.TextStrokeTransparency = 0

    for i = 1, 15 do
        local L = Instance.new("Frame", ScreenGui)
        L.BorderSizePixel = 0
        L.BackgroundColor3 = Settings.Colors.Skeleton
        L.AnchorPoint = Vector2.new(0.5, 0.5)
        L.Visible = false
        Obj.Lines[i] = L
    end

    Obj.Container, Obj.HealthBar, Obj.HealthOutline, Obj.HealthInner, Obj.HealthText, Obj.NameLabel, Obj.DistanceLabel = Container, HealthBar, HealthOutline, HealthInner, HealthText, NameLabel, DistanceLabel
    Cache[player] = Obj
end

RunService.RenderStepped:Connect(function()
    UpdateWorld()
    
    local CamCF = Camera.CFrame.Position
    local TanFOV = math.tan(math.rad(Camera.FieldOfView * 0.5)) * 2

    for player, obj in next, Cache do
        local Char = player.Character
        local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
        local Root = Char and Char:FindFirstChild("HumanoidRootPart")

        if Settings.Enabled and Root and Hum and Hum.Health > 0 then
            local Pos, OnScreen = WTVP(Camera, Root.Position)
            if OnScreen then
                local Scale = 1 / (Pos.Z * TanFOV) * 100
                local W, H = 45 * Scale, 65 * Scale
                local HP = Hum.Health / Hum.MaxHealth
                
                obj.Container.Visible = Settings.Box
                if Settings.Box then
                    obj.Container.Position = UD2_Offset(Pos.X - (W*0.5), Pos.Y - (H*0.5))
                    obj.Container.Size = UD2_Offset(W, H)
                    obj.Container.BackgroundColor3 = Settings.Colors.Box
                    obj.Container.BackgroundTransparency = Settings.BoxTransparency
                end

                obj.HealthOutline.Visible = Settings.HealthBar
                if Settings.HealthBar then
                    obj.HealthOutline.Position = UD2_Offset(-6, -1)
                    obj.HealthOutline.Size = UD2_Offset(4, H + 2)
                    obj.HealthInner.Size = UD2_Offset(2, H)
                    obj.HealthBar.Size = UD2_Scale(1, HP)
                    obj.HealthBar.Position = UD2_Scale(0, 1 - HP)
                    
                    Gradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Settings.Colors.HealthLow),
                        ColorSequenceKeypoint.new(0.5, Settings.Colors.HealthMid),
                        ColorSequenceKeypoint.new(1, Settings.Colors.HealthHigh)
                    })

                    obj.HealthText.Text = math.floor(Hum.Health)
                    obj.HealthText.Position = UD2_Offset(-48, (1 - HP) * H - 6)
                end

                obj.NameLabel.Visible = Settings.Names
                if Settings.Names then
                    obj.NameLabel.Text = player.Name
                    obj.NameLabel.Position = UD2_Offset(Pos.X, Pos.Y - (H*0.5) - 15)
                    obj.NameLabel.TextColor3 = Settings.Colors.Name
                end

                obj.DistanceLabel.Visible = Settings.Distance
                if Settings.Distance then
                    obj.DistanceLabel.Text = math.floor((CamCF - Root.Position).Magnitude) .. "m"
                    obj.DistanceLabel.Position = UD2_Offset(Pos.X, Pos.Y + (H*0.5) + 5)
                    obj.DistanceLabel.TextColor3 = Settings.Colors.Distance
                end

                local Rig = Hum.RigType == Enum.HumanoidRigType.R15 and R15_Rig or R6_Rig
                for i = 1, 15 do
                    local Bone = Rig[i]
                    if Bone and Settings.Skeleton then
                        local p1, p2 = Char:FindFirstChild(Bone[1]), Char:FindFirstChild(Bone[2])
                        if p1 and p2 then
                            local v1, o1 = WTVP(Camera, p1.Position)
                            local v2, o2 = WTVP(Camera, p2.Position)
                            if o1 and o2 then
                                local s, e = Vector2.new(v1.X, v1.Y), Vector2.new(v2.X, v2.Y)
                                local diff = e - s
                                obj.Lines[i].Visible = true
                                obj.Lines[i].BackgroundColor3 = Settings.Colors.Skeleton
                                obj.Lines[i].Size = UD2_Offset(diff.Magnitude, 1)
                                obj.Lines[i].Position = UD2_Offset((s.X + e.X)/2, (s.Y + e.Y)/2)
                                obj.Lines[i].Rotation = math.deg(math.atan2(diff.Y, diff.X))
                                continue
                            end
                        end
                    end
                    obj.Lines[i].Visible = false
                end
                continue
            end
        end
        obj.Container.Visible, obj.NameLabel.Visible, obj.DistanceLabel.Visible = false, false, false
        for i=1, 15 do obj.Lines[i].Visible = false end
    end
end)

Players.PlayerAdded:Connect(CreateESP)
for _, p in next, Players:GetPlayers() do CreateESP(p) end

local VisualTab = Tabs.Main:AddTab("Visuals")

local ESPGroup = VisualTab:AddLeftGroupbox("ESP Settings")

ESPGroup:AddToggle("ESPToggle", {
    Text = "Enable ESP",
    Default = Settings.Enabled,
    Callback = function(v) Settings.Enabled = v end
})

ESPGroup:AddDivider()

ESPGroup:AddToggle("BoxToggle", {
    Text = "Box",
    Default = Settings.Box,
    Callback = function(v) Settings.Box = v end
}):AddColorPicker("BoxColor", {
    Default = Settings.Colors.Box,
    Title = "Box Color",
    Callback = function(c) Settings.Colors.Box = c end
})

ESPGroup:AddSlider("BoxTransparency", {
    Text = "Box Transparency",
    Default = Settings.BoxTransparency * 100,
    Min = 0,
    Max = 100,
    Rounding = 1,
    Suffix = "%",
    Callback = function(v) Settings.BoxTransparency = v / 100 end
})

ESPGroup:AddToggle("SkeletonToggle", {
    Text = "Skeleton",
    Default = Settings.Skeleton,
    Callback = function(v) Settings.Skeleton = v end
}):AddColorPicker("SkeletonColor", {
    Default = Settings.Colors.Skeleton,
    Title = "Skeleton Color",
    Callback = function(c) Settings.Colors.Skeleton = c end
})

ESPGroup:AddToggle("HealthBarToggle", {
    Text = "Health Bar",
    Default = Settings.HealthBar,
    Callback = function(v) Settings.HealthBar = v end
})

ESPGroup:AddLabel("Health Colors"):AddColorPicker("HealthLowColor", {
    Default = Settings.Colors.HealthLow,
    Title = "Low Health Color",
    Callback = function(c) Settings.Colors.HealthLow = c end
}):AddColorPicker("HealthMidColor", {
    Default = Settings.Colors.HealthMid,
    Title = "Mid Health Color",
    Callback = function(c) Settings.Colors.HealthMid = c end
}):AddColorPicker("HealthHighColor", {
    Default = Settings.Colors.HealthHigh,
    Title = "High Health Color",
    Callback = function(c) Settings.Colors.HealthHigh = c end
})

ESPGroup:AddToggle("NamesToggle", {
    Text = "Names",
    Default = Settings.Names,
    Callback = function(v) Settings.Names = v end
}):AddColorPicker("NameColor", {
    Default = Settings.Colors.Name,
    Title = "Name Color",
    Callback = function(c) Settings.Colors.Name = c end
})

ESPGroup:AddToggle("DistanceToggle", {
    Text = "Distance",
    Default = Settings.Distance,
    Callback = function(v) Settings.Distance = v end
}):AddColorPicker("DistanceColor", {
    Default = Settings.Colors.Distance,
    Title = "Distance Color",
    Callback = function(c) Settings.Colors.Distance = c end
})

local WorldGroup = VisualTab:AddRightGroupbox("World Settings")

WorldGroup:AddToggle("WorldToggle", {
    Text = "Enable World Effects",
    Default = WorldSettings.Enabled,
    Callback = function(v) WorldSettings.Enabled = v end
})

WorldGroup:AddDivider()

WorldGroup:AddToggle("ColorCorrectionToggle", {
    Text = "Color Correction",
    Default = WorldSettings.ColorCorrection,
    Callback = function(v) WorldSettings.ColorCorrection = v end
})

WorldGroup:AddSlider("Brightness", {
    Text = "Brightness",
    Default = WorldSettings.Brightness * 100,
    Min = 0,
    Max = 200,
    Rounding = 1,
    Suffix = "%",
    Callback = function(v) WorldSettings.Brightness = v / 100 end
})

WorldGroup:AddSlider("Contrast", {
    Text = "Contrast",
    Default = WorldSettings.Contrast * 100,
    Min = -100,
    Max = 100,
    Rounding = 1,
    Suffix = "%",
    Callback = function(v) WorldSettings.Contrast = v / 100 end
})

WorldGroup:AddSlider("Saturation", {
    Text = "Saturation",
    Default = WorldSettings.Saturation * 100,
    Min = 0,
    Max = 200,
    Rounding = 1,
    Suffix = "%",
    Callback = function(v) WorldSettings.Saturation = v / 100 end
})

WorldGroup:AddLabel("Tint Color"):AddColorPicker("TintColor", {
    Default = WorldSettings.TintColor,
    Title = "Tint Color",
    Callback = function(c) WorldSettings.TintColor = c end
})

WorldGroup:AddDivider()

WorldGroup:AddLabel("Ambient Colors"):AddColorPicker("AmbientColor", {
    Default = WorldSettings.Ambient,
    Title = "Ambient Color",
    Callback = function(c) WorldSettings.Ambient = c end
}):AddColorPicker("OutdoorAmbientColor", {
    Default = WorldSettings.OutdoorAmbient,
    Title = "Outdoor Ambient",
    Callback = function(c) WorldSettings.OutdoorAmbient = c end
})

WorldGroup:AddDivider()

WorldGroup:AddToggle("FogToggle", {
    Text = "Fog",
    Default = WorldSettings.FogEnabled,
    Callback = function(v) WorldSettings.FogEnabled = v end
}):AddColorPicker("FogColor", {
    Default = WorldSettings.FogColor,
    Title = "Fog Color",
    Callback = function(c) WorldSettings.FogColor = c end
})

WorldGroup:AddSlider("FogStart", {
    Text = "Fog Start",
    Default = WorldSettings.FogStart,
    Min = 0,
    Max = 1000,
    Rounding = 1,
    Callback = function(v) WorldSettings.FogStart = v end
})

WorldGroup:AddSlider("FogEnd", {
    Text = "Fog End",
    Default = WorldSettings.FogEnd,
    Min = 100,
    Max = 5000,
    Rounding = 1,
    Callback = function(v) WorldSettings.FogEnd = v end
})

WorldGroup:AddToggle("GlobalShadows", {
    Text = "Global Shadows",
    Default = WorldSettings.GlobalShadows,
    Callback = function(v) WorldSettings.GlobalShadows = v end
})
local UIGroup = Tabs.UI:AddLeftGroupbox("UI Settings")

UIGroup:AddToggle("KeybindMenu", {
    Text = "Open Keybind Menu",
    Default = Library.KeybindFrame.Visible,
    Callback = function(v) Library.KeybindFrame.Visible = v end
})

UIGroup:AddToggle("CustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(v) Library.ShowCustomCursor = v end
})

UIGroup:AddDivider()

UIGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKey", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu Keybind"
})

UIGroup:AddButton({
    Text = "Unload",
    Func = function() Library:Unload() end
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKey"})

ThemeManager:SetFolder("RagebotHub")
SaveManager:SetFolder("RagebotHub/Game")
SaveManager:SetSubFolder("Place")

SaveManager:BuildConfigSection(Tabs.UI)
ThemeManager:ApplyToTab(Tabs.UI)

SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
    print("Ragebot Unloaded")
end)
