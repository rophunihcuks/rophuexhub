--==========================================================
--  1AxaTab_SpectateESP.lua
--  Spectate + ESP + TP FORCE + SPECT PRO + SPECT DRONE + ESP LINES
--  Env: TAB_FRAME, TAB_ID, Players, LocalPlayer, RunService, Camera
--==========================================================
local frame      = TAB_FRAME
local player     = LocalPlayer
local players    = Players
local runService = RunService
local Workspace  = game:GetService("Workspace")

local rows, activeESP, conns = {}, {}, {}
local antennaLinks = {}
local currentSpectateTarget, spectateMode, respawnConn = nil, "none", nil
local espAllOn, espAntennaOn, STUDS_TO_METERS = false, false, 1
local miniNav
local currentIndex, currentTotal = 0, 0
local proLastCF = nil -- cache CFrame target (dipakai PRO & DRONE)

-- FOV default & FOV drone
local defaultFOV = (Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView) or 70
local DRONE_FOV  = 80

-- Raycast param untuk anti tembok kamera drone
local droneRayParams = RaycastParams.new()
droneRayParams.FilterType = Enum.RaycastFilterType.Blacklist
droneRayParams.IgnoreWater = true

-- Folder untuk antena (beam merah)
local antennaFolder = Instance.new("Folder")
antennaFolder.Name = "AxaSpect_AntennaFolder"
antennaFolder.Parent = workspace

-- ========== SMALL HELPERS ==========
local function makeCorner(gui, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px or 8)
    c.Parent = gui
    return c
end

local function makeButton(parent, name, text, size, pos, bg, tc, ts, font)
    local b = Instance.new("TextButton")
    b.Name, b.Size, b.Position = name, size, pos or UDim2.new()
    b.BackgroundColor3 = bg or Color3.fromRGB(230,230,245)
    b.BorderSizePixel, b.Font = 0, font or Enum.Font.GothamBold
    b.TextSize, b.TextColor3, b.Text = ts or 13, tc or Color3.fromRGB(40,40,60), text or ""
    b.AutoButtonColor = true
    b.Parent = parent
    makeCorner(b, 8)
    return b
end

local function makeLabel(parent, name, text, size, pos, p)
    local l = Instance.new("TextLabel")
    l.Name, l.Size, l.Position = name, size, pos or UDim2.new()
    l.BackgroundTransparency = 1
    l.Font       = p and p.Font or Enum.Font.Gotham
    l.TextSize   = p and p.TextSize or 12
    l.TextColor3 = p and p.TextColor3 or Color3.fromRGB(40,40,60)
    l.TextXAlignment = p and p.XAlign or Enum.TextXAlignment.Left
    l.TextYAlignment = p and p.YAlign or Enum.TextYAlignment.Center
    l.TextWrapped    = p and p.Wrapped or false
    l.Text, l.Parent = text or "", parent
    return l
end

local function connect(sig, fn)
    local c = sig:Connect(fn)
    conns[#conns+1] = c
    return c
end

-- helper aman untuk AudioListener (biar nggak error di client lama)
local function safeSetAudioListener(mode)
    local cam = workspace.CurrentCamera
    if not cam then return end
    if mode == "Camera" or mode == "Character" then
        pcall(function()
            cam.AudioListener = Enum.CameraAudioListener[mode]
        end)
    end
end

local function setDefaultFOV()
    local cam = workspace.CurrentCamera
    if cam then
        cam.FieldOfView = defaultFOV
    end
end

local function setDroneFOV()
    local cam = workspace.CurrentCamera
    if cam then
        cam.FieldOfView = DRONE_FOV
    end
end

--========== ANTENA MERAH (BEAM DARI BADAN KAMU KE PLAYER) ==========
local function clearAntennaLink(plr, link)
    if not link then return end

    pcall(function()
        if link.beam and link.beam.Parent then
            link.beam:Destroy()
        end
    end)

    pcall(function()
        if link.attachLocal and link.attachLocal.Parent then
            link.attachLocal:Destroy()
        end
    end)

    pcall(function()
        if link.attachTarget and link.attachTarget.Parent then
            link.attachTarget:Destroy()
        end
    end)

    if link.charConn then
        pcall(function()
            link.charConn:Disconnect()
        end)
    end
end

local function getTorsoForAntenna(char)
    if not char then return nil end
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function setAntennaForPlayer(plr, enabled)
    local old = antennaLinks[plr]
    if not enabled then
        if old then
            clearAntennaLink(plr, old)
        end
        antennaLinks[plr] = nil
        return
    end

    local localChar  = player.Character
    local torsoLocal = getTorsoForAntenna(localChar)
    if not torsoLocal then return end

    if old then
        clearAntennaLink(plr, old)
    end

    local attachLocal = Instance.new("Attachment")
    attachLocal.Name = "AxaSpect_Local_" .. plr.Name
    attachLocal.Position = Vector3.new(0, 0.5, 0)
    attachLocal.Parent = torsoLocal

    local beam = Instance.new("Beam")
    beam.Name = "AxaSpect_Beam_" .. plr.Name
    beam.Attachment0 = attachLocal
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 60, 60))
    beam.Width0 = 0.10
    beam.Width1 = 0.10
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.FaceCamera = true
    beam.Transparency = NumberSequence.new(0.05)
    beam.Segments = 10
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.Parent = antennaFolder

    local link = {
        beam        = beam,
        attachLocal = attachLocal,
        attachTarget= nil,
        charConn    = nil,
    }
    antennaLinks[plr] = link

    local function bindTargetChar(char)
        local torsoTarget = getTorsoForAntenna(char)
        if not torsoTarget then return end

        pcall(function()
            if link.attachTarget and link.attachTarget.Parent then
                link.attachTarget:Destroy()
            end
        end)

        local attachTarget = Instance.new("Attachment")
        attachTarget.Name = "AxaSpect_Target_" .. plr.Name
        attachTarget.Position = Vector3.new(0, 0.5, 0)
        attachTarget.Parent = torsoTarget
        link.attachTarget = attachTarget
        beam.Attachment1 = attachTarget
    end

    if plr.Character then
        bindTargetChar(plr.Character)
    end

    link.charConn = connect(plr.CharacterAdded, function(newChar)
        bindTargetChar(newChar)
    end)
end

-- Rebind attachment LocalPlayer kalau respawn
connect(player.CharacterAdded, function(newChar)
    local torsoLocal = getTorsoForAntenna(newChar)
    if not torsoLocal then return end

    for plr, link in pairs(antennaLinks) do
        pcall(function()
            if link.attachLocal and link.attachLocal.Parent then
                link.attachLocal:Destroy()
            end
        end)

        local newAttach = Instance.new("Attachment")
        newAttach.Name = "AxaSpect_Local_" .. plr.Name
        newAttach.Position = Vector3.new(0, 0.5, 0)
        newAttach.Parent = torsoLocal
        link.attachLocal = newAttach

        if link.beam then
            link.beam.Attachment0 = newAttach
        end
    end
end)

-- ========== HEADER ==========
makeLabel(frame,"Header","🎥 Spectate + ESP V1.3",
    UDim2.new(1,-10,0,22),UDim2.new(0,5,0,6),
    {Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(40,40,60),XAlign=Enum.TextXAlignment.Left}
)
makeLabel(frame,"Sub",
    "Pilih player, nyalakan ESP (meter), SPECT POV, SPECT FREE, SPECT PRO, SPECT DRONE, atau teleport (TP / TP FORCE).",
    UDim2.new(1,-10,0,32),UDim2.new(0,5,0,26),
    {Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(90,90,120),
     XAlign=Enum.TextXAlignment.Left,YAlign=Enum.TextYAlignment.Top,Wrapped=true}
)

-- ========== SEARCH BOX ==========
local searchBox = Instance.new("TextBox")
searchBox.Name, searchBox.PlaceholderText = "SearchBox","Search player..."
searchBox.Size  = UDim2.new(1,-12,0,24)
searchBox.Position = UDim2.new(0,6,0,60)
searchBox.BackgroundColor3 = Color3.fromRGB(230,230,245)
searchBox.TextColor3, searchBox.Font, searchBox.TextSize = Color3.fromRGB(40,40,60), Enum.Font.Gotham, 13
searchBox.TextXAlignment, searchBox.Text = Enum.TextXAlignment.Left, ""
searchBox.ClearTextOnFocus, searchBox.BorderSizePixel = false, 0
searchBox.Parent = frame
makeCorner(searchBox, 8)

-- ========== PLAYER LIST ==========
local list = Instance.new("ScrollingFrame")
list.Name = "PlayerList"
list.Position = UDim2.new(0,6,0,88)
list.Size = UDim2.new(1,-12,1,-130)
list.BackgroundTransparency, list.BorderSizePixel = 1, 0
list.ScrollBarThickness = 4
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.CanvasSize = UDim2.new(0,0,0,0)
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.FillDirection, layout.SortOrder = Enum.FillDirection.Vertical, Enum.SortOrder.Name
layout.Padding, layout.Parent = UDim.new(0,4), list
connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    list.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+6)
end)

-- ========== TOP BAR ==========
local topBar = Instance.new("Frame")
topBar.Name  = "TopBar"
topBar.Size  = UDim2.new(1,-12,0,28)
topBar.Position = UDim2.new(0,6,1,-34)
topBar.BackgroundTransparency = 1
topBar.Parent = frame

local statusLabel = makeLabel(
    topBar,"StatusLabel","Status: Idle",
    UDim2.new(1,-360,1,0),UDim2.new(0,0,0,0),
    {Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(70,70,100),XAlign=Enum.TextXAlignment.Left}
)

-- ganti tombol STOP menjadi tombol ESP LINES (di kiri ESP ALL)
local espAntennaBtn = makeButton(
    topBar,"ESPAntennaButton","ESP LINES: OFF",
    UDim2.new(0,120,1,0),UDim2.new(1,-304,0,0),
    Color3.fromRGB(80,80,120),Color3.fromRGB(255,255,255)
)

local espAllBtn = makeButton(
    topBar,"ESPAllButton","ESP ALL: OFF",
    UDim2.new(0,100,1,0),UDim2.new(1,-174,0,0),
    Color3.fromRGB(80,80,120),Color3.fromRGB(255,255,255)
)

local scrollLeftBtn = makeButton(
    topBar,"SpectPrevBtn","<",
    UDim2.new(0,24,0,24),UDim2.new(1,-64,0.5,-12),
    Color3.fromRGB(220,220,235),Color3.fromRGB(60,60,90),14
)

local scrollRightBtn = makeButton(
    topBar,"SpectNextBtn",">",
    UDim2.new(0,24,0,24),UDim2.new(1,-34,0.5,-12),
    Color3.fromRGB(220,220,235),Color3.fromRGB(60,60,90),14
)

-- ========== SPECTATE STATE ==========
local function setSpectateStatus(t) statusLabel.Text = "Status: "..t end

local function disconnectRespawn()
    if respawnConn then respawnConn:Disconnect() end
    respawnConn = nil
end

local function hardResetCameraToLocal()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    cam.CameraType, cam.CameraSubject = Enum.CameraType.Custom, hum or nil
    safeSetAudioListener("Camera")
    setDefaultFOV()
end

-- ========== MINI NAV UI ==========
local function destroyMiniNav()
    if miniNav and miniNav.Parent then miniNav:Destroy() end
    miniNav = nil
end

local function minimizeCoreToDock()
    local core = rawget(_G,"AxaHubCore"); if not core then return end
    local blur = game:GetService("Lighting"):FindFirstChild("AxaHubGlassBlur")
    if blur then blur.Enabled, blur.Size = false, 0 end
    local back = core.ScreenGui and core.ScreenGui:FindFirstChild("CheckerBackdrop")
    if back then back.Visible = false end
    if core.MainFrame then core.MainFrame.Visible = false end
end

local function updateMiniNavInfo()
    if not miniNav then return end
    local label = miniNav:FindFirstChild("Info")
    if not label or not label:IsA("TextLabel") then return end

    if currentSpectateTarget and currentTotal > 0 and currentIndex > 0 then
        local dn, un = currentSpectateTarget.DisplayName or currentSpectateTarget.Name, currentSpectateTarget.Name
        label.Text = string.format("%s (@%s)\n%d/%d", dn, un, currentIndex, currentTotal)
    else
        label.Text = "Tidak Ada Target\n0/0"
    end
end

local function ensureMiniNav()
    local core = rawget(_G,"AxaHubCore")
    if not core or not core.ScreenGui then return end
    local existed = core.ScreenGui:FindFirstChild("AxaMiniSpectNav")
    if existed then miniNav = existed; updateMiniNavInfo(); return end

    miniNav = Instance.new("Frame")
    miniNav.Name = "AxaMiniSpectNav"
    miniNav.AnchorPoint = Vector2.new(1,1)
    miniNav.Position = UDim2.new(1,-12,1,-12)
    miniNav.Size = UDim2.new(0,210,0,52)
    miniNav.BackgroundColor3 = Color3.fromRGB(18,18,24)
    miniNav.BorderSizePixel = 0
    miniNav.Parent = core.ScreenGui
    makeCorner(miniNav,10)

    local st = Instance.new("UIStroke")
    st.Thickness, st.Color, st.Transparency = 1, Color3.fromRGB(70,70,90), 0.35
    st.Parent = miniNav

    local pad = Instance.new("UIPadding")
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0,6), UDim.new(0,6)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0,8), UDim.new(0,8)
    pad.Parent = miniNav

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1,-60,1,0)
    infoLabel.Position = UDim2.new(0,0,0,0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.TextColor3 = Color3.fromRGB(230,230,245)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.TextWrapped = true
    infoLabel.Parent = miniNav
    infoLabel.Text = "Tidak Ada Target\n0/0"

    local prevBtn = makeButton(
        miniNav,"Prev","<",
        UDim2.new(0,24,0,24),UDim2.new(1,-52,0.5,-12),
        Color3.fromRGB(230,230,240),Color3.fromRGB(40,40,70),16
    )
    local nextBtn = makeButton(
        miniNav,"Next",">",
        UDim2.new(0,24,0,24),UDim2.new(1,-24,0.5,-12),
        Color3.fromRGB(230,230,240),Color3.fromRGB(40,40,70),16
    )

    connect(prevBtn.MouseButton1Click, function() _G.__AxaSpect_Step(-1) end)
    connect(nextBtn.MouseButton1Click, function() _G.__AxaSpect_Step(1) end)

    local main = core.MainFrame
    if main then
        connect(main:GetPropertyChangedSignal("Visible"), function()
            if main.Visible then destroyMiniNav() end
        end)
    end

    updateMiniNavInfo()
end

local function stopSpectate()
    disconnectRespawn()
    currentSpectateTarget, spectateMode = nil, "none"
    currentIndex, currentTotal = 0, 0
    proLastCF = nil
    setDefaultFOV()
    hardResetCameraToLocal()
    setSpectateStatus("Idle")
    destroyMiniNav()
end

-- ========== GLOBAL HOOKS ==========
_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.StopSpectate = stopSpectate
_G.AxaHub_StopSpectate = stopSpectate
_G.AxaSpectate_Stop    = stopSpectate
_G.Axa_StopSpectate    = stopSpectate

-- ========== FILTER & ROW ==========
local function matchesSearch(plr)
    local q = string.lower(searchBox.Text or "")
    if q == "" then return true end
    local dn, un = string.lower(plr.DisplayName or plr.Name), string.lower(plr.Name)
    return dn:find(q,1,true) or un:find(q,1,true)
end

local function applySearchFilter()
    for plr,row in pairs(rows) do
        local m = matchesSearch(plr)
        row.Visible = m
        row.Size = UDim2.new(1,0,0,m and 40 or 0)
    end
end

local function buildRow(plr)
    local row = Instance.new("Frame")
    row.Name = plr.Name
    row.Size = UDim2.new(1,0,0,40)
    row.BackgroundColor3, row.BackgroundTransparency = Color3.fromRGB(230,230,244), 0.1
    row.BorderSizePixel, row.Parent = 0, list
    makeCorner(row,8)

    local rs = Instance.new("UIStroke")
    rs.Thickness, rs.Color = 1, Color3.fromRGB(200,200,220)
    rs.Parent = row
    if plr == player then
        row.BackgroundColor3 = Color3.fromRGB(210,230,255)
        rs.Color = Color3.fromRGB(120,160,235)
    end

    local hScroll = Instance.new("ScrollingFrame")
    hScroll.Name = "RowScroll"
    hScroll.Position = UDim2.new(0,4,0,4)
    hScroll.Size = UDim2.new(1,-8,1,-8)
    hScroll.BackgroundTransparency, hScroll.BorderSizePixel = 1, 0
    hScroll.ScrollBarThickness = 3
    hScroll.ScrollingDirection = Enum.ScrollingDirection.X
    hScroll.CanvasSize = UDim2.new(0,0,0,0)
    hScroll.ScrollBarImageTransparency = 0.1
    hScroll.Parent = row

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(0,420,1,0)
    content.BackgroundTransparency, content.BorderSizePixel = 1, 0
    content.Parent = hScroll

    makeLabel(
        content,"Name",
        string.format("%s (@%s)",plr.DisplayName or plr.Name,plr.Name),
        UDim2.new(0,170,1,0),UDim2.new(0,6,0,0),
        {Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.fromRGB(50,50,75),XAlign=Enum.TextXAlignment.Left}
    )

    local baseX, btnW, btnH, spacing = 190, 60, 24, 4
    local curX = baseX

    local espBtn = makeButton(
        content,"ESPBtn","ESP",
        UDim2.new(0,btnW,0,btnH),UDim2.new(0,curX,0.5,-btnH/2),
        Color3.fromRGB(220,220,230),Color3.fromRGB(60,60,90),12
    )
    curX = curX + btnW + spacing

    local spectateWidth = btnW + 4
    local spectateBtn = makeButton(
        content,"SpectateBtn","SPECT POV",
        UDim2.new(0,spectateWidth,0,btnH),UDim2.new(0,curX,0.5,-btnH/2),
        Color3.fromRGB(200,230,255),Color3.fromRGB(40,60,110),12
    )
    curX = curX + spectateWidth + spacing

    local spectFreeWidth = btnW + 12
    local spectFreeBtn = makeButton(
        content,"SpectFreeBtn","SPECT FREE",
        UDim2.new(0,spectFreeWidth,0,btnH),UDim2.new(0,curX,0.5,-btnH/2),
        Color3.fromRGB(210,220,255),Color3.fromRGB(40,60,120),12
    )
    curX = curX + spectFreeWidth + spacing

    local spectProWidth = btnW + 20
    local spectProBtn = makeButton(
        content,"SpectProBtn","SPECT PRO",
        UDim2.new(0,spectProWidth,0,btnH),UDim2.new(0,curX,0.5,-btnH/2),
        Color3.fromRGB(180,220,255),Color3.fromRGB(20,50,120),12
    )
    curX = curX + spectProWidth + spacing

    local spectDroneWidth = btnW + 28
    local spectDroneBtn = makeButton(
        content,"SpectDroneBtn","SPECT DRONE",
        UDim2.new(0,spectDroneWidth,0,btnH),UDim2.new(0,curX,0.5,-btnH/2),
        Color3.fromRGB(170,235,255),Color3.fromRGB(15,40,120),12
    )
    curX = curX + spectDroneWidth + spacing

    local tpBtn = makeButton(
        content,"TPBtn","TP",
        UDim2.new(0,btnW,0,btnH),UDim2.new(0,curX,0.5,-btnH/2),
        Color3.fromRGB(210,240,220),Color3.fromRGB(40,90,60),12
    )
    curX = curX + btnW + spacing

    local tpForceWidth = btnW + 24
    local tpForceBtn = makeButton(
        content,"TPForceBtn","TP FORCE",
        UDim2.new(0,tpForceWidth,0,btnH),UDim2.new(0,curX,0.5,-btnH/2),
        Color3.fromRGB(190,255,210),Color3.fromRGB(20,80,40),12
    )
    curX = curX + tpForceWidth + spacing

    local lastRight = curX + 8
    content.Size, hScroll.CanvasSize = UDim2.new(0,lastRight,1,0), UDim2.new(0,lastRight,0,0)

    connect(espBtn.MouseButton1Click,function()
        local s = not activeESP[plr]
        setESPOnTarget(plr,s)
        if s then
            espBtn.Text, espBtn.BackgroundColor3 = "ESP ON", Color3.fromRGB(130,190,255)
        else
            espBtn.Text, espBtn.BackgroundColor3 = "ESP", Color3.fromRGB(220,220,230)
        end
    end)
    connect(spectateBtn.MouseButton1Click,function()
        minimizeCoreToDock(); ensureMiniNav()
        startCustomSpectate(plr)
    end)
    connect(spectFreeBtn.MouseButton1Click,function()
        minimizeCoreToDock(); ensureMiniNav()
        startFreeSpectate(plr)
    end)
    connect(spectProBtn.MouseButton1Click,function()
        minimizeCoreToDock(); ensureMiniNav()
        startProSpectate(plr)
    end)
    connect(spectDroneBtn.MouseButton1Click,function()
        minimizeCoreToDock(); ensureMiniNav()
        startDroneSpectate(plr)
    end)
    connect(tpBtn.MouseButton1Click,function()
        teleportToPlayer(plr)
    end)
    connect(tpForceBtn.MouseButton1Click,function()
        teleportToPlayerForce(plr)
    end)

    rows[plr] = row
end

local function rebuildList()
    for _,plr in ipairs(players:GetPlayers()) do
        if not rows[plr] then buildRow(plr) end
    end
    applySearchFilter()
end

-- ========== SPECTATE LIST & INDEX ==========
local function getSpectateList()
    local arr = {}
    for _,plr in ipairs(players:GetPlayers()) do
        if plr ~= player then
            local row = rows[plr]
            if row and row.Visible ~= false then arr[#arr+1] = plr end
        end
    end
    table.sort(arr,function(a,b) return string.lower(a.Name) < string.lower(b.Name) end)
    return arr
end

local function locateIndexInList(plr)
    local lp = getSpectateList()
    local n = #lp
    currentTotal = n
    currentIndex = 0
    if n == 0 or not plr then
        updateMiniNavInfo()
        return
    end
    for i,p in ipairs(lp) do
        if p == plr then
            currentIndex = i
            break
        end
    end
    updateMiniNavInfo()
end

-- ========== SPECTATE MODES ==========
function startCustomSpectate(plr)
    disconnectRespawn()
    setDefaultFOV()
    currentSpectateTarget, spectateMode = plr, "custom"
    proLastCF = nil
    setSpectateStatus(plr and ("Spectate → "..(plr.DisplayName or plr.Name)) or "Idle")
    locateIndexInList(plr)
end

function startFreeSpectate(plr)
    disconnectRespawn()
    setDefaultFOV()
    currentSpectateTarget, spectateMode = plr, "free"
    proLastCF = nil

    local cam = workspace.CurrentCamera
    if plr and plr.Character and cam then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            cam.CameraSubject, cam.CameraType = hum, Enum.CameraType.Custom
            safeSetAudioListener("Character")
        end
    end

    respawnConn = plr and plr.CharacterAdded:Connect(function(char)
        local hum2 = char:WaitForChild("Humanoid")
        local cam2 = workspace.CurrentCamera
        if cam2 and hum2 then
            cam2.CameraSubject, cam2.CameraType = hum2, Enum.CameraType.Custom
            safeSetAudioListener("Character")
        end
    end) or nil

    setSpectateStatus(plr and ("SPECT FREE → "..(plr.DisplayName or plr.Name)) or "Idle")
    locateIndexInList(plr)
end

function startProSpectate(plr)
    disconnectRespawn()
    setDefaultFOV()
    currentSpectateTarget, spectateMode = plr, "pro"
    proLastCF = nil
    setSpectateStatus(plr and ("SPECT PRO → "..(plr.DisplayName or plr.Name)) or "Idle")
    locateIndexInList(plr)
end

function startDroneSpectate(plr)
    disconnectRespawn()
    currentSpectateTarget, spectateMode = plr, "drone"
    proLastCF = nil
    setDroneFOV()
    setSpectateStatus(plr and ("SPECT DRONE → "..(plr.DisplayName or plr.Name)) or "Idle")
    locateIndexInList(plr)
end

-- ========== ESP ==========
function setESPOnTarget(plr, enabled)
    if not plr then return end

    -- flag aktif ESP per-player
    activeESP[plr] = enabled or nil

    -- LINES PER-PLAYER:
    --  - kalau global ESP LINES OFF → ESP per-player ikut hidupkan/matikan lines untuk plr itu
    --  - kalau global ESP LINES ON  → lines diatur tombol global, jadi di-skip di sini
    if not espAntennaOn then
        setAntennaForPlayer(plr, enabled and true or false)
    end

    local char = plr.Character
    if not char then return end

    local hl   = char:FindFirstChild("AxaESPHighlight")
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char
    local bb   = head and head:FindFirstChild("AxaESPDistGui") or nil

    if enabled then
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "AxaESPHighlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillColor = Color3.fromRGB(90,180,255)
            hl.FillTransparency = 0.7
            hl.OutlineColor = Color3.fromRGB(40,130,255)
            hl.OutlineTransparency = 0.1
            hl.Parent = char
        end
        if head and not bb then
            bb = Instance.new("BillboardGui")
            bb.Name = "AxaESPDistGui"
            bb.Size = UDim2.new(0,260,0,26)
            bb.StudsOffset, bb.AlwaysOnTop, bb.MaxDistance = Vector3.new(0,3,0), true, 2000
            bb.Parent = head

            local t = Instance.new("TextLabel")
            t.Name, t.Size = "Text", UDim2.new(1,0,1,0)
            t.BackgroundColor3, t.BackgroundTransparency = Color3.fromRGB(0,0,0), 0.35
            t.BorderSizePixel, t.Font, t.TextSize = 0, Enum.Font.GothamBold, 13
            t.TextColor3 = Color3.fromRGB(255,255,255)
            t.TextStrokeTransparency, t.TextStrokeColor3 = 0.4, Color3.fromRGB(0,0,0)
            t.TextWrapped, t.TextXAlignment, t.TextYAlignment = true, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
            t.Text, t.ZIndex, t.Parent = "", 2, bb
            makeCorner(t,6)
        end
    else
        if hl then hl:Destroy() end
        if head and bb then bb:Destroy() end
    end
end

-- ========== TELEPORT (AKURAT 0 STUD, HRP ↔ HRP) ==========
function teleportToPlayer(target)
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end

    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local thrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

    if hrp and thrp then
        hrp.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = thrp.CFrame
    end
end

-- helper posisi robust (HRP → PrimaryPart → GetPivot)
local function getCharPosition(char)
    if not char or not char:IsA("Model") then return nil, nil end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position, hrp.CFrame
    end

    local primary = char.PrimaryPart
    if primary and primary:IsA("BasePart") then
        return primary.Position, primary.CFrame
    end

    local ok, cf = pcall(function()
        return char:GetPivot()
    end)
    if ok and typeof(cf) == "CFrame" then
        return cf.Position, cf
    end

    return nil, nil
end

-- ========== TELEPORT FORCE 0 STUD (pakai posisi robust) ==========
function teleportToPlayerForce(target)
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end

    local targetPos = getCharPosition(targetChar)
    if not targetPos then return end

    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    hrp.CFrame = CFrame.new(targetPos)
end

-- ========== SPECTATE SEQUENCE (< & >) ==========
local function spectateStep(dir)
    local lp = getSpectateList()
    local n = #lp
    if n == 0 then
        stopSpectate()
        return
    end

    local idx
    if currentSpectateTarget then
        for i,plr in ipairs(lp) do
            if plr == currentSpectateTarget then
                idx = i
                break
            end
        end
    end

    dir = dir or 1
    if not idx then
        idx = (dir >= 0) and 1 or n
    else
        idx = idx + dir
        if idx < 1 then
            idx = n
        elseif idx > n then
            idx = 1
        end
    end

    local target = lp[idx]
    currentTotal = n
    currentIndex = idx

    if target then
        -- DEFAULT KHUSUS TOMBOL < & > = SPECT FREE SELALU
        startFreeSpectate(target)
    else
        stopSpectate()
    end

    updateMiniNavInfo()
end

_G.__AxaSpect_Step = spectateStep

-- ========== WIRING ==========
connect(searchBox:GetPropertyChangedSignal("Text"), applySearchFilter)

connect(players.PlayerAdded,function(plr)
    buildRow(plr); applySearchFilter()
    if espAntennaOn and plr ~= player then
        setAntennaForPlayer(plr, true)
    end
end)

connect(players.PlayerRemoving,function(plr)
    local row = rows[plr]
    if row then row:Destroy() rows[plr] = nil end
    setESPOnTarget(plr,false)

    local link = antennaLinks[plr]
    if link then
        clearAntennaLink(plr, link)
        antennaLinks[plr] = nil
    end

    if plr == currentSpectateTarget then stopSpectate() end
end)

-- tombol ESP LINES global
connect(espAntennaBtn.MouseButton1Click,function()
    espAntennaOn = not espAntennaOn
    espAntennaBtn.Text = espAntennaOn and "ESP LINES: ON" or "ESP LINES: OFF"
    espAntennaBtn.BackgroundColor3 = espAntennaOn and Color3.fromRGB(190,80,80) or Color3.fromRGB(80,80,120)

    if espAntennaOn then
        local char = player.Character
        local torsoLocal = char and getTorsoForAntenna(char)
        if not torsoLocal then
            -- kalau badan kamu belum siap, balikin OFF biar nggak error
            espAntennaOn = false
            espAntennaBtn.Text = "ESP LINES: OFF"
            espAntennaBtn.BackgroundColor3 = Color3.fromRGB(80,80,120)
            return
        end

        for _,plr in ipairs(players:GetPlayers()) do
            if plr ~= player then
                setAntennaForPlayer(plr, true)
            end
        end
    else
        for plr, link in pairs(antennaLinks) do
            clearAntennaLink(plr, link)
        end
        table.clear(antennaLinks)
    end
end)

connect(espAllBtn.MouseButton1Click,function()
    espAllOn = not espAllOn
    espAllBtn.Text = espAllOn and "ESP ALL: ON" or "ESP ALL: OFF"
    espAllBtn.BackgroundColor3 = espAllOn and Color3.fromRGB(110,150,255) or Color3.fromRGB(80,80,120)
    for plr in pairs(rows) do
        if plr ~= player then setESPOnTarget(plr,espAllOn) end
    end
end)

connect(scrollLeftBtn.MouseButton1Click,function()
    minimizeCoreToDock(); ensureMiniNav(); spectateStep(-1)
end)
connect(scrollRightBtn.MouseButton1Click,function()
    minimizeCoreToDock(); ensureMiniNav(); spectateStep(1)
end)

-- ========== CAMERA & DISTANCE UPDATE ==========
connect(runService.RenderStepped,function()
    if not currentSpectateTarget or spectateMode == "none" then
        if statusLabel.Text ~= "Status: Idle" then setSpectateStatus("Idle") end
    end

    if currentSpectateTarget and spectateMode ~= "none" then
        local cam, char = workspace.CurrentCamera, currentSpectateTarget.Character
        if cam then
            if spectateMode == "custom" and char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    cam.CameraType = Enum.CameraType.Scriptable
                    local offset = hrp.CFrame.LookVector * -8 + Vector3.new(0,4,0)
                    cam.CFrame = CFrame.new(hrp.Position + offset, hrp.Position)
                    safeSetAudioListener("Camera")
                end
            elseif spectateMode == "free" and char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    cam.CameraType, cam.CameraSubject = Enum.CameraType.Custom, hum
                    safeSetAudioListener("Character")
                end
            elseif spectateMode == "pro" then
                cam.CameraType = Enum.CameraType.Scriptable
                local pos, cf = nil, nil
                if char then
                    local p, fullCF = getCharPosition(char)
                    if p and fullCF then
                        pos, cf = p, fullCF
                        proLastCF = fullCF
                    end
                end
                if not cf and proLastCF then
                    cf = proLastCF
                    pos = proLastCF.Position
                end
                if cf and pos then
                    local offset   = cf.LookVector * -10 + Vector3.new(0,5,0)
                    local targetCF = CFrame.new(pos + offset, pos)
                    if cam.CFrame then
                        cam.CFrame = cam.CFrame:Lerp(targetCF, 0.25)
                    else
                        cam.CFrame = targetCF
                    end
                    safeSetAudioListener("Camera")
                end
            elseif spectateMode == "drone" then
                cam.CameraType = Enum.CameraType.Scriptable
                local pos, cf = nil, nil
                if char then
                    local p, fullCF = getCharPosition(char)
                    if p and fullCF then
                        pos, cf = p, fullCF
                        proLastCF = fullCF
                    end
                end
                if not cf and proLastCF then
                    cf  = proLastCF
                    pos = proLastCF.Position
                end
                if cf and pos then
                    -- Posisi kamera drone: lebih tinggi + agak jauh di belakang, plus anti tembok
                    local from    = pos + Vector3.new(0,3,0)
                    local lookDir = (-cf.LookVector).Unit
                    local baseOffset = lookDir * 28 + Vector3.new(0,40,0)
                    local desiredPos = pos + baseOffset
                    local dir = desiredPos - from
                    local finalPos = desiredPos

                    if dir.Magnitude > 1e-3 then
                        droneRayParams.FilterDescendantsInstances = { char, player.Character }
                        local result = Workspace:Raycast(from, dir, droneRayParams)
                        if result then
                            finalPos = result.Position - dir.Unit * 2
                        end
                    end

                    local targetCF = CFrame.new(finalPos, pos)
                    if cam.CFrame then
                        cam.CFrame = cam.CFrame:Lerp(targetCF, 0.25)
                    else
                        cam.CFrame = targetCF
                    end
                    cam.FieldOfView = DRONE_FOV
                    safeSetAudioListener("Camera")
                end
            end
        end
    end

    local myChar, myHRP = player.Character, nil
    if myChar then myHRP = myChar:FindFirstChild("HumanoidRootPart") end
    if not myHRP then return end

    for plr in pairs(activeESP) do
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head") or hrp
            if hrp and head then
                local gui = head:FindFirstChild("AxaESPDistGui")
                if gui then
                    local label = gui:FindFirstChild("Text")
                    if label and label:IsA("TextLabel") then
                        local distStuds = (hrp.Position - myHRP.Position).Magnitude
                        local meters = math.floor(distStuds * STUDS_TO_METERS + 0.5)
                        label.Text = string.format("%s | @%s | %d meter",
                            plr.DisplayName or plr.Name, plr.Name, meters)
                    end
                end
            end
        end
    end
end)

-- ========== INIT ==========
rebuildList()
setSpectateStatus("Idle")

-- ========== TAB CLEANUP ==========
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}
_G.AxaHub.TabCleanup[TAB_ID or "spectateespp"] = function()
    stopSpectate()
    for plr in pairs(activeESP) do
        setESPOnTarget(plr,false)
    end

    for plr, link in pairs(antennaLinks) do
        clearAntennaLink(plr, link)
    end
    table.clear(antennaLinks)

    pcall(function()
        if antennaFolder and antennaFolder.Parent then
            antennaFolder:Destroy()
        end
    end)

    for _,c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
end
