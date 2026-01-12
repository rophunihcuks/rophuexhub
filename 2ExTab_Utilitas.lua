--==========================================================
--  2AxaTab_Utilitas.lua (UI simple + checklist)
--  ShiftRun + Infinite Jump + Kompas HUD + Horizontal + Rejoin Voice + No Clip + Fly + Invisible (No Visual)
--==========================================================

------------------- SERVICES / ENV -------------------
local TAB = TAB_FRAME  -- frame dari CORE

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local TweenService         = game:GetService("TweenService")
local UserInputService     = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui           = game:GetService("StarterGui")
local Debris               = game:GetService("Debris")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local Workspace            = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local VoiceChatService
do
    local ok, svc = pcall(function() return game:GetService("VoiceChatService") end)
    VoiceChatService = ok and svc or nil
end

if not (TAB and LocalPlayer) then return end

-- Forward declare row Fly utk sync UI dari logic
local rowFly
local rowFlyNoclip

------------------- HELPER UI & NOTIF -------------------
local function ui(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = dur or 3
        })
    end)
end

local function setHorizontalPlaygame(enabled)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local ok, err = pcall(function()
        pg.ScreenOrientation = enabled
            and Enum.ScreenOrientation.LandscapeSensor
            or  Enum.ScreenOrientation.Sensor
    end)
    if not ok then
        warn("[AxaUtil] Gagal set ScreenOrientation:", err)
    end
end

local function createToggleRow(parent, orderName, labelText, defaultState)
    local row = ui("Frame", {
        Name = orderName,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(235,235,245),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0
    }, parent)
    ui("UICorner", {CornerRadius = UDim.new(0,8)}, row)

    local checkBtn = ui("TextButton", {
        Name = "Check",
        Size = UDim2.new(0, 28, 1, -6),
        Position = UDim2.new(0, 6, 0, 3),
        BackgroundColor3 = Color3.fromRGB(210,210,230),
        TextColor3 = Color3.fromRGB(50,50,80),
        Font = Enum.Font.Gotham,
        TextSize = 18,
        Text = ""
    }, row)
    ui("UICorner", {CornerRadius = UDim.new(0,6)}, checkBtn)

    ui("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 40, 0, 0),
        Size = UDim2.new(1, -45, 1, 0),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(40,40,70),
        Text = labelText
    }, row)

    local state = not not defaultState
    local callback
    local suppressCallback = false

    local function apply()
        checkBtn.Text = state and "☑" or "☐"
        checkBtn.BackgroundColor3 = state
            and Color3.fromRGB(140,190,255)
            or  Color3.fromRGB(210,210,230)
    end

    local function setState(new)
        state = not not new
        apply()
        if callback and not suppressCallback then
            task.spawn(callback, state)
        end
    end

    checkBtn.MouseButton1Click:Connect(function()
        setState(not state)
    end)

    local hit = ui("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.new(1,0,1,0)
    }, row)
    hit.MouseButton1Click:Connect(function()
        setState(not state)
    end)

    apply()

    return {
        Frame = row,
        Set = function(v) setState(v) end,
        SetSilent = function(v)
            suppressCallback = true
            setState(v)
            suppressCallback = false
        end,
        Get = function() return state end,
        OnChanged = function(cb) callback = cb end,
    }
end

------------------- SHIFT RUN -------------------
local SR_AnimationID   = 10862419793
local SR_RunningSpeed  = 40
local SR_NormalSpeed   = 20
local SR_RunFOV        = 80
local SR_NormalFOV     = 70
local SR_KeyString     = "LeftShift"
local SR_ACTION_NAME   = "RunBind"

local SR_sprintEnabled = false
local SR_Running       = false
local SR_Humanoid, SR_RAnimation
local SR_TweenRun, SR_TweenWalk
local SR_HeartbeatConn

local function SR_ensureTweens()
    local info = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    SR_TweenRun  = TweenService:Create(camera, info, {FieldOfView = SR_RunFOV})
    SR_TweenWalk = TweenService:Create(camera, info, {FieldOfView = SR_NormalFOV})
end

local function SR_walk()
    if SR_Humanoid then SR_Humanoid.WalkSpeed = SR_NormalSpeed end
    if SR_RAnimation and SR_RAnimation.IsPlaying then pcall(function() SR_RAnimation:Stop() end) end
    if SR_TweenWalk then SR_TweenWalk:Play() else camera.FieldOfView = SR_NormalFOV end
end

local function SR_run()
    if SR_Humanoid then SR_Humanoid.WalkSpeed = SR_RunningSpeed end
    if SR_RAnimation and not SR_RAnimation.IsPlaying then pcall(function() SR_RAnimation:Play() end) end
    if SR_TweenRun then SR_TweenRun:Play() else camera.FieldOfView = SR_RunFOV end
end

local function SR_setSprintEnabled(on)
    SR_sprintEnabled = not not on
    if not SR_Humanoid then return end
    if not SR_sprintEnabled then
        SR_Running = false
        SR_walk()
    else
        local keyEnum = Enum.KeyCode[SR_KeyString] or Enum.KeyCode.LeftShift
        local holding = UserInputService:IsKeyDown(keyEnum)
        if holding and SR_Humanoid.MoveDirection.Magnitude > 0 then
            SR_Running = true; SR_run()
        else
            SR_Running = false; SR_walk()
        end
    end
end

local function SR_bindAction()
    local keyEnum = Enum.KeyCode[SR_KeyString] or Enum.KeyCode.LeftShift
    pcall(function() ContextActionService:UnbindAction(SR_ACTION_NAME) end)
    ContextActionService:BindAction(SR_ACTION_NAME, function(_, state)
        if state == Enum.UserInputState.Begin then
            SR_Running = true
        elseif state == Enum.UserInputState.End then
            SR_Running = false
        end
        if not SR_sprintEnabled then
            SR_walk(); return
        end
        if SR_Running then SR_run() else SR_walk() end
    end, true, keyEnum)
end

local function SR_startHeartbeat()
    if SR_HeartbeatConn then SR_HeartbeatConn:Disconnect() end
    SR_HeartbeatConn = RunService.Heartbeat:Connect(function()
        if not SR_Humanoid then return end
        if not SR_sprintEnabled then
            if SR_Humanoid.WalkSpeed ~= SR_NormalSpeed
            or (SR_RAnimation and SR_RAnimation.IsPlaying)
            or camera.FieldOfView ~= SR_NormalFOV then
                SR_walk()
            end
        else
            if SR_Running then
                if SR_Humanoid.WalkSpeed ~= SR_RunningSpeed
                or (SR_RAnimation and not SR_RAnimation.IsPlaying)
                or camera.FieldOfView ~= SR_RunFOV then
                    SR_run()
                end
            else
                if SR_Humanoid.WalkSpeed ~= SR_NormalSpeed
                or (SR_RAnimation and SR_RAnimation.IsPlaying)
                or camera.FieldOfView ~= SR_NormalFOV then
                    SR_walk()
                end
            end
        end
    end)
end

local function SR_attachCharacter(char)
    SR_Humanoid = char:WaitForChild("Humanoid", 5)
    if not SR_Humanoid then return end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. SR_AnimationID
    local ok, track = pcall(function() return SR_Humanoid:LoadAnimation(anim) end)
    if ok then SR_RAnimation = track end
    SR_ensureTweens()
    camera.FieldOfView    = SR_NormalFOV
    SR_Humanoid.WalkSpeed = SR_NormalSpeed

    SR_Humanoid.Running:Connect(function(speed)
        if not SR_sprintEnabled then SR_walk(); return end
        if speed >= 10 and SR_Running and SR_RAnimation and not SR_RAnimation.IsPlaying then
            SR_run()
        elseif speed >= 10 and (not SR_Running) and SR_RAnimation and SR_RAnimation.IsPlaying then
            SR_walk()
        elseif speed < 10 and SR_RAnimation and SR_RAnimation.IsPlaying then
            SR_walk()
        end
    end)

    SR_Humanoid.Changed:Connect(function()
        if SR_Humanoid.Jump and SR_RAnimation and SR_RAnimation.IsPlaying then
            pcall(function() SR_RAnimation:Stop() end)
        end
    end)

    SR_bindAction()
    SR_startHeartbeat()
    SR_setSprintEnabled(SR_sprintEnabled)
end

if LocalPlayer.Character then SR_attachCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(SR_attachCharacter)

------------------- INFINITE JUMP -------------------
local IJ_Settings = {
    ExtraJumps          = 5,
    WhiteList           = {},
    EnableAirStepVFX    = true,
    AirStepLife         = 0.5,
    AirStepSize         = Vector3.new(2.5, 0.35, 2.5),
    AirStepTransparency = 0.25,
    AirStepMaterial     = Enum.Material.Neon,
}

local IJ_Enabled   = false
local IJ_Humanoid, IJ_Root
local IJ_JumpsDone = 0
local IJ_Grounded  = false
local IJ_AirTimer  = 0
local JumpPlatformTemplate = ReplicatedStorage:FindFirstChild("JumpPlatform")

local function IJ_isWhitelisted(p)
    local wl = IJ_Settings.WhiteList
    if wl and #wl > 0 then
        for _, id in ipairs(wl) do
            if id == p.UserId then return true end
        end
        return false
    end
    return true
end

local function IJ_spawnAirStepVFX(pos)
    if not IJ_Settings.EnableAirStepVFX then return end
    if JumpPlatformTemplate then
        local obj = JumpPlatformTemplate:Clone()
        obj.Name = "DJ_Pivot"
        obj.Parent = workspace
        if obj:IsA("BasePart") then
            obj.Anchored = true
            obj.CanCollide = false
            obj.CFrame = CFrame.new(pos)
        else
            if obj.PrimaryPart then
                obj:SetPrimaryPartCFrame(CFrame.new(pos))
            else
                obj:PivotTo(CFrame.new(pos))
            end
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Anchored = true
                    d.CanCollide = false
                end
            end
        end
        Debris:AddItem(obj, IJ_Settings.AirStepLife)
    else
        local p = Instance.new("Part")
        p.Name = "AirStep"
        p.Anchored = true
        p.CanCollide = false
        p.Size = IJ_Settings.AirStepSize
        p.Material = IJ_Settings.AirStepMaterial
        p.Color = Color3.new(1,1,1)
        p.Transparency = IJ_Settings.AirStepTransparency
        p.CFrame = CFrame.new(pos)
        p.Parent = workspace
        Debris:AddItem(p, IJ_Settings.AirStepLife)
    end
end

local function IJ_bindCharacter(char)
    IJ_Humanoid = char:WaitForChild("Humanoid")
    IJ_Root     = char:WaitForChild("HumanoidRootPart")
    IJ_JumpsDone = 0
    IJ_Grounded  = false

    IJ_Humanoid.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Landed
        or new == Enum.HumanoidStateType.Running
        or new == Enum.HumanoidStateType.RunningNoPhysics
        or new == Enum.HumanoidStateType.Swimming then
            IJ_JumpsDone = 0
            IJ_Grounded  = true
        elseif new == Enum.HumanoidStateType.Freefall then
            IJ_Grounded = false
        end
    end)
end

if LocalPlayer.Character then IJ_bindCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(IJ_bindCharacter)

UserInputService.JumpRequest:Connect(function()
    if not IJ_Enabled or not IJ_Humanoid or IJ_Humanoid.Health <= 0 then return end
    if not IJ_isWhitelisted(LocalPlayer) then return end
    if IJ_Grounded then return end

    if IJ_JumpsDone < (IJ_Settings.ExtraJumps or 0) then
        IJ_JumpsDone += 1
        local v = IJ_Root.Velocity
        local up = math.max(50, IJ_Humanoid.JumpPower * 1.15)
        IJ_Root.Velocity = Vector3.new(v.X, up, v.Z)
        IJ_Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        IJ_spawnAirStepVFX(IJ_Root.Position - Vector3.new(0,3,0))
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if IJ_Humanoid and IJ_Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
        IJ_AirTimer += dt
        if IJ_AirTimer > 3 then
            IJ_JumpsDone = math.min(IJ_JumpsDone, IJ_Settings.ExtraJumps or 0)
        end
    else
        IJ_AirTimer = 0
    end
end)

------------------- NO CLIP (SHARED: MANUAL + FLY + INVISIBLE) -------------------
local NC_SteppedConn   = nil
local NC_StoredCollide = {}
local NC_Manual        = false -- dari checkbox No Clip
local NC_FromFly       = false -- dari Fly+NoClip
local NC_FromInvisible = false -- dari Invisible FakeCharacter

local function NC_Enable()
    if NC_SteppedConn then return end
    NC_SteppedConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                if NC_StoredCollide[v] == nil then
                    NC_StoredCollide[v] = v.CanCollide
                end
                v.CanCollide = false
            end
        end
    end)
end

local function NC_Disable()
    if NC_SteppedConn then
        NC_SteppedConn:Disconnect()
        NC_SteppedConn = nil
    end
    for part, orig in pairs(NC_StoredCollide) do
        if part and part.Parent then
            part.CanCollide = orig
        end
    end
    if table.clear then
        table.clear(NC_StoredCollide)
    else
        for k in pairs(NC_StoredCollide) do
            NC_StoredCollide[k] = nil
        end
    end
end

local function NC_Recalc()
    local should = NC_Manual or NC_FromFly or NC_FromInvisible
    if should then
        NC_Enable()
    else
        NC_Disable()
    end
end

local function NC_SetEnabled(on)
    NC_Manual = not not on
    NC_Recalc()
end

local function NC_SetFromFly(on)
    NC_FromFly = not not on
    NC_Recalc()
end

local function NC_SetFromInvisible(on)
    NC_FromInvisible = not not on
    NC_Recalc()
end

------------------- FLY (BodyGyro + BodyVelocity) -------------------
local Fly_Active         = false
local Fly_WithNoClip     = false
local Fly_Speed          = 50 -- kecepatan dasar (studs/s)
local Fly_BodyGyro       = nil
local Fly_BodyVel        = nil
local Fly_Humanoid       = nil
local Fly_AnimateScript  = nil
local Fly_DisabledStates = nil
local Fly_ConnStepped    = nil
local Fly_InputBeganConn = nil
local Fly_InputEndedConn = nil
local Fly_Vertical       = 0  -- -1 turun, 0 diam, 1 naik

local function Fly_Stop()
    if not Fly_Active then return end
    Fly_Active    = false
    Fly_Vertical  = 0

    if Fly_ConnStepped then
        Fly_ConnStepped:Disconnect()
        Fly_ConnStepped = nil
    end

    if Fly_BodyGyro then
        Fly_BodyGyro:Destroy()
        Fly_BodyGyro = nil
    end

    if Fly_BodyVel then
        Fly_BodyVel:Destroy()
        Fly_BodyVel = nil
    end

    if Fly_Humanoid then
        Fly_Humanoid.PlatformStand = false
        if Fly_DisabledStates then
            for st, enabled in pairs(Fly_DisabledStates) do
                Fly_Humanoid:SetStateEnabled(st, enabled)
            end
        end
    end
    Fly_DisabledStates = nil

    if Fly_AnimateScript and Fly_AnimateScript.Parent then
        Fly_AnimateScript.Disabled = false
    end
    Fly_Humanoid      = nil
    Fly_AnimateScript = nil

    if Fly_WithNoClip then
        NC_SetFromFly(false)
    end
    Fly_WithNoClip = false

    notify("Fly","Fly dimatikan.",3)
end

local function Fly_Start(withNoclip)
    withNoclip = not not withNoclip

    -- Jika sudah aktif & hanya ganti mode (Fly <-> Fly+NoClip)
    if Fly_Active and Fly_WithNoClip ~= withNoclip then
        Fly_WithNoClip = withNoclip
        NC_SetFromFly(withNoclip)
        notify("Fly", withNoclip and "Mode: Fly + NoClip." or "Mode: Fly (tanpa NoClip).", 3)
        return
    elseif Fly_Active and Fly_WithNoClip == withNoclip then
        return
    end

    -- Start baru
    Fly_Active     = true
    Fly_WithNoClip = withNoclip

    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid") or nil
    local root = nil
    if char then
        root = char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("UpperTorso")
    end

    if not (char and hum and root) then
        Fly_Active     = false
        Fly_WithNoClip = false
        local targetRow = withNoclip and rowFlyNoclip or rowFly
        if targetRow and targetRow.Get and targetRow.Get() then
            targetRow.SetSilent(false)
        end
        notify("Fly","Gagal mengaktifkan Fly (character belum siap).",3)
        return
    end

    Fly_Humanoid = hum

    -- Matikan animasi default supaya tidak "lari" di udara
    Fly_AnimateScript = char:FindFirstChild("Animate")
    if Fly_AnimateScript then
        Fly_AnimateScript.Disabled = true
    end
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        pcall(function() track:AdjustSpeed(0) end)
    end

    -- Disable beberapa state Humanoid
    Fly_DisabledStates = {}
    local statesToDisable = {
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Flying,
        Enum.HumanoidStateType.Freefall,
        Enum.HumanoidStateType.GettingUp,
        Enum.HumanoidStateType.Jumping,
        Enum.HumanoidStateType.Landed,
        Enum.HumanoidStateType.Physics,
        Enum.HumanoidStateType.Seated,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.PlatformStanding,
        Enum.HumanoidStateType.Running,
        Enum.HumanoidStateType.RunningNoPhysics,
        Enum.HumanoidStateType.StrafingNoPhysics,
    }
    for _, st in ipairs(statesToDisable) do
        Fly_DisabledStates[st] = hum:GetStateEnabled(st)
        hum:SetStateEnabled(st, false)
    end
    hum:ChangeState(Enum.HumanoidStateType.Swimming)
    hum.PlatformStand = true

    -- Body movers
    Fly_BodyGyro = Instance.new("BodyGyro")
    Fly_BodyGyro.P = 9e4
    Fly_BodyGyro.maxTorque = Vector3.new(9e9,9e9,9e9)
    Fly_BodyGyro.cframe = root.CFrame
    Fly_BodyGyro.Parent = root

    Fly_BodyVel = Instance.new("BodyVelocity")
    Fly_BodyVel.velocity = Vector3.new(0,0.1,0)
    Fly_BodyVel.maxForce = Vector3.new(9e9,9e9,9e9)
    Fly_BodyVel.Parent = root

    if Fly_WithNoClip then
        NC_SetFromFly(true)
    end

    -- Input (vertikal) – horizontal pakai MoveDirection (WASD / joystick)
    if not Fly_InputBeganConn then
        Fly_InputBeganConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe or not Fly_Active then return end
            local kc = input.KeyCode
            if kc == Enum.KeyCode.Space or kc == Enum.KeyCode.E then
                Fly_Vertical = 1
            elseif kc == Enum.KeyCode.LeftControl or kc == Enum.KeyCode.Q or kc == Enum.KeyCode.C then
                Fly_Vertical = -1
            end
        end)
        Fly_InputEndedConn = UserInputService.InputEnded:Connect(function(input, gpe)
            if gpe or not Fly_Active then return end
            local kc = input.KeyCode
            if kc == Enum.KeyCode.Space or kc == Enum.KeyCode.E then
                if Fly_Vertical > 0 then Fly_Vertical = 0 end
            elseif kc == Enum.KeyCode.LeftControl or kc == Enum.KeyCode.Q or kc == Enum.KeyCode.C then
                if Fly_Vertical < 0 then Fly_Vertical = 0 end
            end
        end)
    end

    if Fly_ConnStepped then
        Fly_ConnStepped:Disconnect()
        Fly_ConnStepped = nil
    end

    Fly_ConnStepped = RunService.RenderStepped:Connect(function()
        if not Fly_Active or not Fly_Humanoid or Fly_Humanoid.Health <= 0 then
            return
        end

        local rootPart = nil
        pcall(function()
            rootPart = Fly_Humanoid.RootPart
        end)
        if not rootPart then
            rootPart = Fly_Humanoid.Parent
                and (Fly_Humanoid.Parent:FindFirstChild("HumanoidRootPart")
                    or Fly_Humanoid.Parent:FindFirstChild("Torso")
                    or Fly_Humanoid.Parent:FindFirstChild("UpperTorso"))
        end
        if not rootPart then return end

        local moveDir = Fly_Humanoid.MoveDirection
        local cam = workspace.CurrentCamera
        local vel = Vector3.zero

        if moveDir.Magnitude > 0 then
            vel += moveDir.Unit * Fly_Speed
        end
        if Fly_Vertical ~= 0 then
            vel += Vector3.new(0, Fly_Vertical * Fly_Speed, 0)
        end

        Fly_BodyVel.velocity = vel
        if cam then
            Fly_BodyGyro.cframe = cam.CFrame
        end
    end)

    notify(
        "Fly",
        withNoclip and "Fly + NoClip AKTIF (WASD / joystick + Space/E naik, Ctrl/Q/C turun)." or
            "Fly AKTIF (WASD / joystick + Space/E naik, Ctrl/Q/C turun).",
        4
    )
end

------------------- KOMPAS HUD -------------------
local Compass = {}
do
    local WIDTH, HEIGHT       = 480, 44
    local MARGIN_TOP, MARGIN_BOTTOM = 16, 16
    local BG_TRANSP, PPD      = 0.35, 2
    local TICK_EVERY          = 10
    local T_MIN, T_MID, T_MAX = 8, 12, 18

    local gui, container, headingLabel, centerArrow, tapeHolder, tape
    local SEG_W = 360 * PPD
    local rsConn
    local positionMode = "top"
    local enabled = false

    local FULL_DIRS = {
        "Utara","Timur Laut","Timur","Tenggara",
        "Selatan","Barat Daya","Barat","Barat Laut"
    }

    local function yawDegFromLook(v)
        local deg = math.deg(math.atan2(v.X, v.Z))
        return (deg % 360 + 360) % 360
    end

    local function labelForDeg(d)
        d = (d % 360 + 360) % 360
        if d == 0   then return "U"
        elseif d == 45  then return "TL"
        elseif d == 90  then return "T"
        elseif d == 135 then return "TG"
        elseif d == 180 then return "S"
        elseif d == 225 then return "BD"
        elseif d == 270 then return "B"
        elseif d == 315 then return "BL" end
    end

    local function addTick(parent, x, h)
        return ui("Frame", {
            Size = UDim2.fromOffset(2,h),
            AnchorPoint = Vector2.new(0.5,1),
            Position = UDim2.fromOffset(x, tapeHolder.AbsoluteSize.Y - 4),
            BackgroundColor3 = Color3.fromRGB(220,220,220),
            BorderSizePixel = 0
        }, parent)
    end

    local function addText(parent, x, text, size)
        return ui("TextLabel", {
            BackgroundTransparency = 1,
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = size,
            TextColor3 = Color3.fromRGB(230,230,230),
            AnchorPoint = Vector2.new(0.5,1),
            Position = UDim2.fromOffset(x, tapeHolder.AbsoluteSize.Y - 6 - T_MAX),
            Size = UDim2.fromOffset(44,18)
        }, parent)
    end

    local function buildSegment(parent, xOff)
        for deg = 0, 359, TICK_EVERY do
            local px = xOff + deg * PPD
            local lbl = labelForDeg(deg)
            if lbl then
                addTick(parent, px, T_MAX)
                addText(parent, px, lbl, 12)
            elseif deg % 30 == 0 then
                addTick(parent, px, T_MID)
                addText(parent, px, tostring(deg), 10)
            else
                addTick(parent, px, T_MIN)
            end
        end
    end

    local function rebuildTicksY()
        for _, c in ipairs(tape:GetChildren()) do
            if c:IsA("Frame") then
                c.Position = UDim2.fromOffset(c.Position.X.Offset, tapeHolder.AbsoluteSize.Y - 4)
            elseif c:IsA("TextLabel") then
                c.Position = UDim2.fromOffset(c.Position.X.Offset, tapeHolder.AbsoluteSize.Y - 6 - T_MAX)
            end
        end
    end

    local function setPosMode(mode)
        positionMode = (mode == "top") and "top" or "bottom"
        if not container then return end
        if positionMode == "top" then
            container.AnchorPoint = Vector2.new(0.5,0)
            container.Position    = UDim2.new(0.5,0,0,MARGIN_TOP)
        else
            container.AnchorPoint = Vector2.new(0.5,1)
            container.Position    = UDim2.new(0.5,0,1,-MARGIN_BOTTOM)
        end
        container.Size = UDim2.fromOffset(WIDTH,HEIGHT)
        centerArrow.AnchorPoint = Vector2.new(0.5,1)
        centerArrow.Position    = UDim2.new(0.5,0,1,-4)
    end

    local function updateTape()
        if not camera then return end
        local deg = yawDegFromLook(camera.CFrame.LookVector)
        local centerX = math.floor(container.AbsoluteSize.X/2 + 0.5)
        local desired = centerX - (SEG_W + deg * PPD)
        tape.Position = UDim2.fromOffset(desired,0)

        local idx = math.floor((deg + 22.5) / 45) % 8 + 1
        headingLabel.Text = ("Arah: %s (%.0f°)"):format(FULL_DIRS[idx], deg)
    end

    local function destroy()
        enabled = false
        if rsConn then rsConn:Disconnect() end
        rsConn = nil
        if gui then gui:Destroy() end
        gui, container, headingLabel, centerArrow, tapeHolder, tape = nil,nil,nil,nil,nil,nil
    end

    local function create()
        destroy()
        enabled = true

        local pg = LocalPlayer:WaitForChild("PlayerGui")
        local old = pg:FindFirstChild("AxaHUD_Compass")
        if old then old:Destroy() end
        local old2 = pg:FindFirstChild("CenterCompassHUD")
        if old2 then old2:Destroy() end

        gui = ui("ScreenGui", {
            Name = "AxaHUD_Compass",
            IgnoreGuiInset = true,
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 50
        }, pg)

        container = ui("Frame", {
            Name = "CompassContainer",
            Size = UDim2.fromOffset(WIDTH,HEIGHT),
            BackgroundColor3 = Color3.fromRGB(0,0,0),
            BackgroundTransparency = BG_TRANSP,
            BorderSizePixel = 0,
            ClipsDescendants = true
        }, gui)
        ui("UICorner", {CornerRadius = UDim.new(0,10)}, container)
        ui("UIStroke", {
            Thickness = 1,
            Color = Color3.fromRGB(255,255,255),
            Transparency = 0.75
        }, container)

        headingLabel = ui("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1,-16,0,18),
            Position = UDim2.fromOffset(8,4),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(230,230,230),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Arah: -"
        }, container)

        centerArrow = ui("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(20,20),
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = Color3.fromRGB(255,90,90),
            Text = "▲"
        }, container)

        tapeHolder = ui("Frame", {
            Name = "TapeHolder",
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,1,-20),
            Position = UDim2.fromOffset(0,20)
        }, container)

        tape = ui("Frame", {
            Name = "Tape",
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(SEG_W*3, tapeHolder.AbsoluteSize.Y),
            Position = UDim2.fromOffset(0,0)
        }, tapeHolder)

        tapeHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            tape.Size = UDim2.fromOffset(SEG_W*3, tapeHolder.AbsoluteSize.Y)
            rebuildTicksY()
        end)

        buildSegment(tape, 0)
        buildSegment(tape, SEG_W)
        buildSegment(tape, SEG_W*2)

        setPosMode(positionMode)

        rsConn = RunService.RenderStepped:Connect(function()
            if enabled then updateTape() end
        end)

        task.defer(function()
            for _ = 1,5 do updateTape(); task.wait(0.05) end
        end)
    end

    Compass.Create = create
    Compass.Destroy = destroy
    Compass.SetVisible = function(v)
        if v and not gui then create()
        elseif (not v) and gui then destroy() end
    end
    Compass.SetPositionMode = function(mode)
        positionMode = (mode == "top") and "top" or "bottom"
        if gui and container then setPosMode(positionMode) end
    end
    Compass.GetPositionMode = function() return positionMode end
end

------------------- INVISIBLE (NO VISUAL, REAL/FAKE CHARACTER) -------------------
local Invis_Keybind        = "JJ"    -- tombol keyboard untuk toggle
local Invis_Transparency   = true   -- fake character transparan (local)
local Invis_NoClipOn       = false  -- minta NoClip saat Invisible
local Invis_IsInvisible    = false
local Invis_CanToggle      = true

local Invis_RealCharacter  = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Invis_FakeCharacter  = nil
local Invis_AnchorPart     = nil
local Invis_PseudoAnchor   = nil    -- root yg diikat ke Anchor
local Invis_HR_Real        = nil
local Invis_HR_Fake        = nil

local function Invis_applyFakeTransparency()
    if not Invis_FakeCharacter then return end
    for _, v in pairs(Invis_FakeCharacter:GetDescendants()) do
        if v:IsA("BasePart") then
            -- NO VISUAL (local): full invisible saat transparan = true
            v.Transparency = Invis_Transparency and 1 or 0
        elseif v:IsA("Decal") or v:IsA("Texture") then
            if Invis_Transparency then
                v.Transparency = 1
            end
        end
    end
end

local function Invis_syncHumanoidStats(fromHum, toHum)
    if not (fromHum and toHum) then return end
    toHum.WalkSpeed = fromHum.WalkSpeed

    if toHum.UseJumpPower ~= nil then
        toHum.UseJumpPower = fromHum.UseJumpPower
    end

    if toHum.UseJumpPower then
        toHum.JumpPower = fromHum.JumpPower
    else
        toHum.JumpHeight = fromHum.JumpHeight
    end

    toHum.AutoRotate = fromHum.AutoRotate
end

local function Invis_cleanupCharacters()
    if Invis_FakeCharacter then
        Invis_FakeCharacter:Destroy()
        Invis_FakeCharacter = nil
    end
    if Invis_AnchorPart then
        Invis_AnchorPart:Destroy()
        Invis_AnchorPart = nil
    end
    Invis_PseudoAnchor = nil
    Invis_HR_Real      = nil
    Invis_HR_Fake      = nil
end

local function Invis_setupCharacters()
    Invis_cleanupCharacters()

    Invis_RealCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    if not Invis_RealCharacter then return end

    Invis_RealCharacter.Archivable = true
    Invis_FakeCharacter = Invis_RealCharacter:Clone()

    -- Anchor: jauh di sumbu Z tetapi Y tetap aman (tidak kena kill-plane)
    local realRoot = Invis_RealCharacter:FindFirstChild("HumanoidRootPart")
        or Invis_RealCharacter:FindFirstChild("Torso")
        or Invis_RealCharacter:FindFirstChild("UpperTorso")

    local basePos
    if realRoot then
        basePos = realRoot.Position
    else
        basePos = Vector3.new(0, 50, 0)
    end

    Invis_AnchorPart = Instance.new("Part")
    Invis_AnchorPart.Name = "AxaInvisibleAnchorPart"
    Invis_AnchorPart.Anchored = true
    Invis_AnchorPart.CanCollide = false
    Invis_AnchorPart.Size = Vector3.new(40, 2, 40)
    -- Pindah 5000 stud di sumbu Z agar benar2 di luar map tapi tetap aman di Y
    Invis_AnchorPart.CFrame = CFrame.new(basePos + Vector3.new(0, 0, 5000))
    Invis_AnchorPart.Parent = Workspace

    Invis_FakeCharacter.Parent = Workspace
    local fakeRoot = Invis_FakeCharacter:WaitForChild("HumanoidRootPart", 5)
        or Invis_FakeCharacter:FindFirstChild("Torso")
        or Invis_FakeCharacter:FindFirstChild("UpperTorso")

    if fakeRoot and Invis_AnchorPart then
        fakeRoot.CFrame = Invis_AnchorPart.CFrame * CFrame.new(0, 5, 0)
    end

    for _, v in pairs(Invis_RealCharacter:GetChildren()) do
        if v:IsA("LocalScript") then
            local clone = v:Clone()
            clone.Disabled = true
            clone.Parent = Invis_FakeCharacter
        end
    end

    if Invis_Transparency then
        Invis_applyFakeTransparency()
    end

    local realHum = Invis_RealCharacter:FindFirstChildOfClass("Humanoid")
    local fakeHum = Invis_FakeCharacter:FindFirstChildOfClass("Humanoid")
    Invis_syncHumanoidStats(realHum, fakeHum)

    Invis_PseudoAnchor = fakeRoot
    Invis_HR_Real      = realRoot
    Invis_HR_Fake      = fakeRoot

    if realHum then
        realHum.Died:Connect(function()
            Invis_cleanupCharacters()
        end)
    end
end

Invis_setupCharacters()

local function Invis_onRespawn()
    Invis_CanToggle   = false
    Invis_IsInvisible = false
    NC_SetFromInvisible(false)

    Invis_cleanupCharacters()

    Invis_RealCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    if not Invis_RealCharacter then
        Invis_CanToggle = true
        return
    end

    Invis_setupCharacters()

    -- Pastikan kamera kembali ke karakter asli (visible)
    local realHum = Invis_RealCharacter:FindFirstChildOfClass("Humanoid")
    if realHum then
        Workspace.CurrentCamera.CameraSubject = realHum
    end

    Invis_CanToggle = true
end

-- Listener respawn
LocalPlayer.CharacterAppearanceLoaded:Connect(Invis_onRespawn)

-- Anchor handler (selalu jaga karakter yg "disembunyikan" tetap di anchor)
RunService.RenderStepped:Connect(function()
    if Invis_PseudoAnchor and Invis_AnchorPart then
        Invis_PseudoAnchor.CFrame = Invis_AnchorPart.CFrame * CFrame.new(0, 5, 0)
    end
end)

local function Invis_updateNoClip()
    -- NoClip khusus Invisible pakai NC_SetFromInvisible
    if Invis_IsInvisible and Invis_NoClipOn then
        NC_SetFromInvisible(true)
    else
        NC_SetFromInvisible(false)
    end
end

local function Invis_Toggle()
    if not Invis_CanToggle or not Invis_RealCharacter or not Invis_FakeCharacter then
        return
    end

    local realRoot = Invis_RealCharacter:FindFirstChild("HumanoidRootPart")
        or Invis_RealCharacter:FindFirstChild("Torso")
        or Invis_RealCharacter:FindFirstChild("UpperTorso")

    local fakeRoot = Invis_FakeCharacter:FindFirstChild("HumanoidRootPart")
        or Invis_FakeCharacter:FindFirstChild("Torso")
        or Invis_FakeCharacter:FindFirstChild("UpperTorso")

    local realHum = Invis_RealCharacter:FindFirstChildOfClass("Humanoid")
    local fakeHum = Invis_FakeCharacter:FindFirstChildOfClass("Humanoid")

    if not (realRoot and fakeRoot and realHum and fakeHum) then
        return
    end

    if not Invis_IsInvisible then
        -- Visible -> Invisible: player pindah pakai FakeCharacter, Real di-anchor jauh
        Invis_syncHumanoidStats(realHum, fakeHum)

        local storedCF = realRoot.CFrame
        realRoot.CFrame = fakeRoot.CFrame
        fakeRoot.CFrame = storedCF

        realHum:UnequipTools()
        LocalPlayer.Character = Invis_FakeCharacter
        Workspace.CurrentCamera.CameraSubject = fakeHum

        Invis_PseudoAnchor = realRoot

        for _, v in pairs(Invis_FakeCharacter:GetChildren()) do
            if v:IsA("LocalScript") then
                v.Disabled = false
            end
        end

        Invis_IsInvisible = true
        notify("Invisible","Mode: Invisible (No Visual) AKTIF.",3)
    else
        -- Invisible -> Visible: balik ke RealCharacter, Fake di-anchor jauh
        Invis_syncHumanoidStats(fakeHum, realHum)

        local storedCF = fakeRoot.CFrame
        fakeRoot.CFrame = realRoot.CFrame
        realRoot.CFrame = storedCF

        fakeHum:UnequipTools()
        LocalPlayer.Character = Invis_RealCharacter
        Workspace.CurrentCamera.CameraSubject = realHum

        Invis_PseudoAnchor = fakeRoot

        for _, v in pairs(Invis_FakeCharacter:GetChildren()) do
            if v:IsA("LocalScript") then
                v.Disabled = true
            end
        end

        Invis_IsInvisible = false
        notify("Invisible","Kembali Visible (normal).",3)
    end

    Invis_updateNoClip()
end

-- Keybind toggle Invisible (default E)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if input.KeyCode.Name:lower() == Invis_Keybind:lower()
        and Invis_CanToggle
        and Invis_RealCharacter
        and Invis_FakeCharacter then
        Invis_Toggle()
    end
end)

------------------- HELPER: JUMP VIA GUI -------------------
local function doJump()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Jump = true
    end
end

------------------- UI TAB UTILITAS (HEADER + SCROLL CHECKBOX) -------------------
do
    -- Header simple di dalam kartu CORE
    ui("TextLabel", {
        Name = "UtilHeader",
        Size = UDim2.new(1,-10,0,22),
        Position = UDim2.new(0,5,0,6),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(40,40,70),
        Text = "⚙️ Utilitas V1.3 - Invisible"
    }, TAB)

    -- ScrollingFrame vertikal berisi checkbox checklist
    local scroll = ui("ScrollingFrame", {
        Name = "UtilScroll",
        Position = UDim2.new(0,5,0,30),
        Size = UDim2.new(1,-10,1,-35),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0,0,0,0)
    }, TAB)

    local layout = ui("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.Name,
        Padding = UDim.new(0,6),
        HorizontalAlignment = Enum.HorizontalAlignment.Left
    }, scroll)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local size = layout.AbsoluteContentSize
        scroll.CanvasSize = UDim2.new(0,0,0,size.Y + 8)
    end)

    -- Checkbox: Horizontal Playgame (default ON)
    local rowHorizontal = createToggleRow(
        scroll,
        "0_HorizontalPlay",
        "Horizontal Playgame (kunci layar ke landscape)",
        true
    )
    rowHorizontal.OnChanged(function(state)
        setHorizontalPlaygame(state)
        notify("Horizontal Playgame",
            state and "Orientasi dikunci ke landscape." or "Orientasi kembali auto.",
            3
        )
    end)
    setHorizontalPlaygame(rowHorizontal.Get())

    ----------------------------------------------------------------
    -- INVISIBLE BLOCK CHECKBOX (3 CHECKBOX)
    ----------------------------------------------------------------

    -- 1) Invisible / Visible (key E, No Visual)
    local rowInvisible = createToggleRow(
        scroll,
        "0a_InvisibleToggle",
        "Invisible / Visible (toggle key JJ, No Visual)",
        false
    )
    rowInvisible.OnChanged(function(state)
        -- Samakan dengan state Invisible sekarang
        if state ~= Invis_IsInvisible then
            Invis_Toggle()
        end
    end)

    -- 2) Transparent Fake Character (default true)
    local rowTransparentFake = createToggleRow(
        scroll,
        "0b_TransparentFake",
        "Transparent Fake Character (local, default ON)",
        true
    )
    rowTransparentFake.OnChanged(function(state)
        Invis_Transparency = state
        Invis_applyFakeTransparency()
        notify("Invisible","Transparent Fake: "..(state and "ON" or "OFF"),2)
    end)
    -- apply default
    Invis_Transparency = rowTransparentFake.Get()
    Invis_applyFakeTransparency()

    -- 3) NoClip Fake Character (default false)
    local rowInvisibleNoclip = createToggleRow(
        scroll,
        "0c_InvisNoclip",
        "NoClip Fake Character (saat Invisible)",
        false
    )
    rowInvisibleNoclip.OnChanged(function(state)
        Invis_NoClipOn = state
        Invis_updateNoClip()
        notify("Invisible","NoClip Fake: "..(state and "ON" or "OFF"),2)
    end)

    ----------------------------------------------------------------
    -- Fitur lain seperti sebelumnya
    ----------------------------------------------------------------

    -- Checkbox: ShiftRun
    local rowShift = createToggleRow(
        scroll,
        "1_ShiftRun",
        "ShiftRun (LeftShift, anim, FOV Run/Normal)",
        false
    )
    rowShift.OnChanged(function(state)
        SR_sprintEnabled = state
        SR_setSprintEnabled(state)
        notify("ShiftRun",
            state and "ShiftRun AKTIF (tahan LeftShift)." or "ShiftRun dimatikan.",
            3
        )
    end)

    ----------------------------------------------------------------
    -- INPUT BOX: SHIFT RUN SPEED & FOV (DIBAWAH SHIFT RUN)
    ----------------------------------------------------------------
    local srConfigRow = ui("Frame", {
        Name = "1a_ShiftRunConfig",
        Size = UDim2.new(1,0,0,30),
        BackgroundTransparency = 1
    }, scroll)

    ui("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0,150,1,0),
        Position = UDim2.new(0,0,0,0),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(40,40,70),
        Text = "ShiftRun Speed / FOV:"
    }, srConfigRow)

    local speedBox = ui("TextBox", {
        Name = "SpeedBox",
        Size = UDim2.new(0,70,0,24),
        Position = UDim2.new(0,160,0,3),
        BackgroundColor3 = Color3.fromRGB(235,235,245),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(40,40,70),
        PlaceholderText = "40",
        Text = tostring(SR_RunningSpeed),
        ClearTextOnFocus = false
    }, srConfigRow)
    ui("UICorner", {CornerRadius = UDim.new(0,6)}, speedBox)

    local fovBox = ui("TextBox", {
        Name = "FOVBox",
        Size = UDim2.new(0,70,0,24),
        Position = UDim2.new(0,240,0,3),
        BackgroundColor3 = Color3.fromRGB(235,235,245),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(40,40,70),
        PlaceholderText = "80",
        Text = tostring(SR_RunFOV),
        ClearTextOnFocus = false
    }, srConfigRow)
    ui("UICorner", {CornerRadius = UDim.new(0,6)}, fovBox)

    -- TANPA BATAS MAX: hanya minimal 0 utk speed, minimal 1 utk FOV
    speedBox.FocusLost:Connect(function()
        local txt = speedBox.Text
        local num = tonumber(txt)
        if not num then
            speedBox.Text = tostring(SR_RunningSpeed)
            notify("ShiftRun","Speed harus angka (contoh: 40).",2)
            return
        end
        if num < 0 then
            num = 0
        end
        SR_RunningSpeed = num
        speedBox.Text = tostring(num)

        if SR_Humanoid and SR_sprintEnabled and SR_Running then
            SR_run()
        end
        notify("ShiftRun","RunningSpeed di-set ke "..tostring(num)..".",2)
    end)

    fovBox.FocusLost:Connect(function()
        local txt = fovBox.Text
        local num = tonumber(txt)
        if not num then
            fovBox.Text = tostring(SR_RunFOV)
            notify("ShiftRun","Run FOV harus angka (contoh: 80).",2)
            return
        end
        if num < 1 then
            num = 1
        end
        SR_RunFOV = num
        fovBox.Text = tostring(num)

        SR_ensureTweens()
        if SR_sprintEnabled and SR_Running then
            SR_run()
        else
            SR_walk()
        end
        notify("ShiftRun","Run FOV di-set ke "..tostring(num)..".",2)
    end)

    -- Checkbox: Infinite Jump
    local rowInfJump = createToggleRow(
        scroll,
        "2_InfiniteJump",
        ("Infinite Jump (%d extra jump di udara + pijakan VFX)"):format(IJ_Settings.ExtraJumps),
        false
    )
    rowInfJump.OnChanged(function(state)
        IJ_Enabled = state
        IJ_JumpsDone = 0
        notify("Infinite Jump",
            state and ("Aktif (%d extra jump)."):format(IJ_Settings.ExtraJumps) or "Dimatikan.",
            3
        )
    end)

    ----------------------------------------------------------------
    -- INPUT BOX: EXTRA JUMPS (DIBAWAH INFINITE JUMP) - TANPA BATAS MAX
    ----------------------------------------------------------------
    local ijConfigRow = ui("Frame", {
        Name = "2_InfiniteJumpConfig",
        Size = UDim2.new(1,0,0,30),
        BackgroundTransparency = 1
    }, scroll)

    ui("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0,150,1,0),
        Position = UDim2.new(0,0,0,0),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(40,40,70),
        Text = "Extra Jumps (udara):"
    }, ijConfigRow)

    local extraBox = ui("TextBox", {
        Name = "ExtraJumpsBox",
        Size = UDim2.new(0,70,0,24),
        Position = UDim2.new(0,160,0,3),
        BackgroundColor3 = Color3.fromRGB(235,235,245),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(40,40,70),
        PlaceholderText = "5",
        Text = tostring(IJ_Settings.ExtraJumps),
        ClearTextOnFocus = false
    }, ijConfigRow)
    ui("UICorner", {CornerRadius = UDim.new(0,6)}, extraBox)

    extraBox.FocusLost:Connect(function()
        local txt = extraBox.Text
        local num = tonumber(txt)
        if not num then
            extraBox.Text = tostring(IJ_Settings.ExtraJumps)
            notify("Infinite Jump","ExtraJumps harus angka (contoh: 5).",2)
            return
        end
        -- TANPA BATAS MAX: hanya paksa minimal 0 dan bulatkan
        num = math.floor(num + 0.5)
        if num < 0 then
            num = 0
        end

        IJ_Settings.ExtraJumps = num
        IJ_JumpsDone = 0
        extraBox.Text = tostring(num)

        -- update label row Infinite Jump
        local lbl = rowInfJump
            and rowInfJump.Frame
            and rowInfJump.Frame:FindFirstChild("Label")
        if lbl and lbl:IsA("TextLabel") then
            lbl.Text = ("Infinite Jump (%d extra jump di udara + pijakan VFX)"):format(IJ_Settings.ExtraJumps)
        end

        notify("Infinite Jump","ExtraJumps di-set ke "..tostring(num)..".",2)
    end)

    -- Checkbox: Fly (tanpa NoClip)
    rowFly = createToggleRow(
        scroll,
        "2a_Fly",
        "Fly (gerak bebas, WASD/joystick + Space/E naik, Ctrl/Q/C turun)",
        false
    )
    rowFly.OnChanged(function(state)
        if state then
            if rowFlyNoclip and rowFlyNoclip.Get() then
                rowFlyNoclip.SetSilent(false)
            end
            Fly_Start(false)
        else
            if not (rowFlyNoclip and rowFlyNoclip.Get()) then
                Fly_Stop()
            end
        end
    end)

    -- Checkbox: Fly + No Clip
    rowFlyNoclip = createToggleRow(
        scroll,
        "2b_FlyNoclip",
        "Fly + No Clip (terbang & tembus tembok)",
        false
    )
    rowFlyNoclip.OnChanged(function(state)
        if state then
            if rowFly and rowFly.Get() then
                rowFly.SetSilent(false)
            end
            Fly_Start(true)
        else
            if not (rowFly and rowFly.Get()) then
                Fly_Stop()
            else
                Fly_Start(false)
            end
        end
    end)

    -- Checkbox: No Clip (manual)
    local rowNoclip = createToggleRow(
        scroll,
        "2c_Noclip",
        "No Clip (tembus tembok, hati-hati ban)",
        false
    )
    rowNoclip.OnChanged(function(state)
        NC_SetEnabled(state)
        notify(
            "No Clip",
            state and "No Clip AKTIF (badan tembus, collider dimatikan)." or "No Clip dimatikan, collider dikembalikan.",
            3
        )
    end)

    -- Checkbox: Kompas HUD (default ON)
    local rowCompass = createToggleRow(
        scroll,
        "3_CompassHUD",
        "Kompas HUD (pita derajat & heading)",
        true
    )
    rowCompass.OnChanged(function(state)
        Compass.SetVisible(state)
        notify("Kompas",
            state and "Kompas ditampilkan." or "Kompas disembunyikan.",
            2
        )
    end)
    Compass.SetVisible(rowCompass.Get())

    -- Baris pilihan posisi kompas (atas/bawah)
    local posRow = ui("Frame", {
        Name = "3b_CompassPos",
        Size = UDim2.new(1,0,0,30),
        BackgroundTransparency = 1
    }, scroll)

    ui("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0,140,1,0),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(40,40,70),
        Text = "Posisi Kompas:"
    }, posRow)

    local function styleBtn(btn, active)
        btn.BackgroundColor3 = active and Color3.fromRGB(140,190,255) or Color3.fromRGB(220,222,235)
        btn.TextColor3       = active and Color3.fromRGB(20,30,50)   or Color3.fromRGB(50,60,90)
    end

    local btnTop = ui("TextButton", {
        Size = UDim2.new(0,100,0,26),
        Position = UDim2.new(0,150,0,2),
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        Text = "Atas"
    }, posRow)
    ui("UICorner", {CornerRadius = UDim.new(0,7)}, btnTop)

    local btnBottom = ui("TextButton", {
        Size = UDim2.new(0,100,0,26),
        Position = UDim2.new(0,256,0,2),
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        Text = "Bawah"
    }, posRow)
    ui("UICorner", {CornerRadius = UDim.new(0,7)}, btnBottom)

    local currentPos = Compass.GetPositionMode()
    styleBtn(btnTop,    currentPos == "top")
    styleBtn(btnBottom, currentPos == "bottom")

    btnTop.MouseButton1Click:Connect(function()
        Compass.SetPositionMode("top")
        styleBtn(btnTop,true); styleBtn(btnBottom,false)
        notify("Kompas", "Posisi: Atas", 2)
    end)

    btnBottom.MouseButton1Click:Connect(function()
        Compass.SetPositionMode("bottom")
        styleBtn(btnTop,false); styleBtn(btnBottom,true)
        notify("Kompas", "Posisi: Bawah", 2)
    end)

    -- Checkbox: Rejoin Voice
    local rowRejoinVoice = createToggleRow(
        scroll,
        "4_RejoinVoice",
        "Rejoin Voice Chat (coba sambung ulang)",
        false
    )
    rowRejoinVoice.OnChanged(function(state)
        if not state then return end
        if not VoiceChatService then
            notify("Rejoin Voice","VoiceChatService tidak tersedia di game ini.",4)
            return
        end
        task.spawn(function()
            local ok, err = pcall(function()
                VoiceChatService:JoinVoice()
            end)
            if ok then
                notify("Rejoin Voice","Percobaan join voice dikirim.",3)
            else
                warn("[AxaUtil] JoinVoice gagal:", err)
                notify("Rejoin Voice","Gagal join voice: "..tostring(err),4)
            end
        end)
    end)

    -- Checkbox: Jump Button (GUI)
    local rowJumpBtn = createToggleRow(
        scroll,
        "5_JumpButton",
        "Jump Button (tombol lompat di UI)",
        false
    )
    -- Row ini hanya indikator; tombol real-nya di bawah
    rowJumpBtn.OnChanged(function() end)

    -- Satu baris button Jump
    local jumpRow = ui("Frame", {
        Name = "5b_JumpRow",
        Size = UDim2.new(1,0,0,30),
        BackgroundTransparency = 1
    }, scroll)

    local jumpButton = ui("TextButton", {
        Name = "JumpButton",
        Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = Color3.fromRGB(52,52,64),
        AutoButtonColor = true,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(230,230,240),
        Text = "Jump"
    }, jumpRow)
    ui("UICorner", {CornerRadius = UDim.new(0,8)}, jumpButton)
    ui("UIStroke", {
        Thickness = 1,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0.82
    }, jumpButton)

    jumpButton.MouseButton1Click:Connect(function()
        doJump()
    end)

    -- Saat character respawn: matikan Fly & reset checklist Fly, Invisible ikut reset
    LocalPlayer.CharacterAdded:Connect(function()
        Fly_Stop()
        if rowFly and rowFly.Get() then
            rowFly.SetSilent(false)
        end
        if rowFlyNoclip and rowFlyNoclip.Get() then
            rowFlyNoclip.SetSilent(false)
        end

        -- Invisible reset ke Visible di UI
        if rowInvisible and rowInvisible.Get() then
            rowInvisible.SetSilent(false)
        end
        Invis_IsInvisible = false
        Invis_updateNoClip()
    end)
end

--------------------- SOUND + NOTIF LOAD ---------------------
do
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://232127604"
    sound.Volume = 1
    sound.Parent = Workspace
    sound:Play()
    Debris:AddItem(sound, 10)

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = "ExHub Utility Loaded",
            Text     = "ShiftRun, Infinite Jump, Kompas, Fly, Invisible (key E) siap.",
            Duration = 5,
            Button1  = "Oke",
        })
    end)
end
