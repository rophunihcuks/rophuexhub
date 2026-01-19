--==========================================================
--  5AxaTab_NPCTeleport.lua
--  TAB 5: "NPC Teleport PRO++"
--  Fitur:
--    - Scan WorldBoss Point (Point1 / Point2 / Point3) via tombol "Refresh Point"
--    - Dropdown list NPC per Point (Sell Fish, Harpoon Shop, GunShop, dll.)
--    - Tombol "Teleport to NPC" untuk teleport smooth ke NPC terpilih
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame = TAB_FRAME
local tabId = TAB_ID or "npcteleport"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local UserInputService  = UserInputService  or game:GetService("UserInputService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local TweenService      = TweenService      or game:GetService("TweenService")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local workspace         = workspace

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

------------------- GLOBAL STATE -------------------
local alive       = true
local connections = {}

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local WorldBoss  = workspace:FindFirstChild("WorldBoss")

------------------- CHARACTER / HRP -------------------
local function getHRP()
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
end))

------------------- NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "NPC Teleport",
            Text     = text or "",
            Duration = dur or 4,
        })
    end)
end

------------------- NPC CONFIG (STATIC POSITIONS) -------------------
-- Struktur:
--  NPC_CONFIG[pointName] = {
--      { id = "P1_SellFish1", name = "Sell Fish (Tabe)", position = Vector3.new(...), lookAt = Vector3.new(...) },
--      ...
--  }
--==========================================================
--  5AxaTab_NPCTeleport.lua
--  TAB 5: "NPC Teleport PRO++"
--  Fitur:
--    - Scan WorldBoss Point (Point1 / Point2 / Point3) via tombol "Refresh Point"
--    - Dropdown list NPC per Point (Sell Fish, Harpoon Shop, GunShop, dll.)
--    - Tombol "Teleport to NPC" untuk teleport smooth ke NPC terpilih
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame = TAB_FRAME
local tabId = TAB_ID or "npcteleport"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local UserInputService  = UserInputService  or game:GetService("UserInputService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local TweenService      = TweenService      or game:GetService("TweenService")
local ReplicatedStorage = ReplicatedStorage or game:GetService("ReplicatedStorage")
local workspace         = workspace

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

------------------- GLOBAL STATE -------------------
local alive       = true
local connections = {}

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local WorldBoss  = workspace:FindFirstChild("WorldBoss")

------------------- CHARACTER / HRP -------------------
local function getHRP()
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
end))

------------------- NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "NPC Teleport",
            Text     = text or "",
            Duration = dur or 4,
        })
    end)
end

------------------- NPC CONFIG (STATIC POSITIONS) -------------------
-- Struktur:
--  NPC_CONFIG[pointName] = {
--      { id = "P1_SellFish1", name = "Sell Fish (Tabe)", position = Vector3.new(...), lookAt = Vector3.new(...) },
--      ...
--  }

local NPC_CONFIG = {
    Point1 = {
        {
            id       = "P1_SellFish_1",
            name     = "Sell Fish (Tabe)",
            position = Vector3.new(1352.67, 96.04, -282.58),
            lookAt   = Vector3.new(1362.56, 96.04, -284.06),
        },
        {
            id       = "P1_HarpoonShop_1",
            name     = "Harpoon Shop (David)",
            position = Vector3.new(1396.57, 92.63, -166.08),
            lookAt   = Vector3.new(1406.55, 92.63, -165.48),
        },
        {
            id       = "P1_GunShop_1",
            name     = "GunShop (Uzi)",
            position = Vector3.new(1318.70, 88.41, -455.84),
            lookAt   = Vector3.new(1328.44, 88.41, -458.11),
        },
        {
            id       = "P1_BaitShop_1",
            name     = "Bait Shop (Jack)",
            position = Vector3.new(1414.43, 92.26, -237.04),
            lookAt   = Vector3.new(1419.48, 92.26, -245.68),
        },
        {
            id       = "P1_BasketShop_1",
            name     = "Basket Shop (Andy)",
            position = Vector3.new(1179.85, 89.86, -188.80),
            lookAt   = Vector3.new(1169.86, 89.86, -188.25),
        },
        {
            id       = "P1_SellFish_2",
            name     = "Sell Fish 2 (Tabe)",
            position = Vector3.new(1193.98, 98.69, 53.40),
            lookAt   = Vector3.new(1184.60, 98.69, 56.88),
        },
        {
            id       = "P1_HarpoonShop_2",
            name     = "Harpoon Shop 2 (David)",
            position = Vector3.new(1192.98, 99.69, 98.90),
            lookAt   = Vector3.new(1187.23, 99.69, 107.08),
        },
    },
    Point2 = {
        {
            id       = "P2_SellFish_1",
            name     = "Sell Fish (Tabe)",
            position = Vector3.new(383.88, 89.70, -915.45),
            lookAt   = Vector3.new(378.21, 89.70, -907.21),
        },
        {
            id       = "P2_GunShop_1",
            name     = "GunShop (Uzi)",
            position = Vector3.new(346.59, 88.79, -931.89),
            lookAt   = Vector3.new(338.53, 88.79, -925.98),
        },
    },
    Point3 = {
        {
            id       = "P3_SellFish_1",
            name     = "Sell Fish (Tabe)",
            position = Vector3.new(1379.17, -1133.39, 2845.70),
            lookAt   = Vector3.new(1389.15, -1133.45, 2845.11),
        },
    },
}

------------------- TELEPORT HELPER -------------------
local activeTeleportTween = nil

local function smoothTeleportTo(position, lookAtPos)
    local hrp = getHRP()
    if not hrp or not position then
        return
    end

    if activeTeleportTween then
        pcall(function()
            activeTeleportTween:Cancel()
        end)
        activeTeleportTween = nil
    end

    local targetCFrame
    if lookAtPos and (lookAtPos - position).Magnitude > 0.1 then
        targetCFrame = CFrame.new(position, lookAtPos)
    else
        targetCFrame = CFrame.new(position)
    end

    local fromPos  = hrp.Position
    local distance = (fromPos - position).Magnitude

    -- Kalau jarak dekat, langsung set tanpa tween
    if distance < 3 then
        hrp.CFrame = targetCFrame
        return
    end

    local duration = math.clamp(distance / 260, 0.05, 0.25)

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { CFrame = targetCFrame }
    )
    activeTeleportTween = tween
    tween:Play()

    task.spawn(function()
        pcall(function()
            tween.Completed:Wait()
        end)
        if activeTeleportTween == tween then
            activeTeleportTween = nil
        end
    end)
end

------------------- DETECT CURRENT POINT (WORLD BOSS) -------------------
local function ensureWorldBoss()
    if not WorldBoss or not WorldBoss.Parent then
        WorldBoss = workspace:FindFirstChild("WorldBoss")
    end
    return WorldBoss
end

local function getRegionCenter(region)
    if not region then
        return nil
    end

    if region:IsA("BasePart") then
        return region.Position
    end

    local sum   = Vector3.new(0, 0, 0)
    local count = 0

    local ok, descendants = pcall(function()
        return region:GetDescendants()
    end)
    if not ok or not descendants then
        return nil
    end

    for _, inst in ipairs(descendants) do
        if inst:IsA("BasePart") then
            sum   += inst.Position
            count += 1
        end
    end

    if count == 0 then
        return nil
    end

    return sum / count
end

local function detectCurrentPointName()
    local wb = ensureWorldBoss()
    if not wb then
        return nil
    end

    local hrp = getHRP()
    if not hrp then
        return nil
    end
    local hrpPos = hrp.Position

    local bestName
    local bestDist = math.huge

    for _, pointName in ipairs({ "Point1", "Point2", "Point3" }) do
        local region = wb:FindFirstChild(pointName)
        if region then
            local center = getRegionCenter(region)
            if center then
                local d = (center - hrpPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestName = pointName
                end
            end
        end
    end

    return bestName
end

------------------- UI HELPERS -------------------
local function createMainLayout()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Parent = frame
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    header.BackgroundTransparency = 0.1
    header.BorderSizePixel = 0
    header.Position = UDim2.new(0, 8, 0, 8)
    header.Size = UDim2.new(1, -16, 0, 46)

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    local headerStroke = Instance.new("UIStroke")
    headerStroke.Thickness = 1
    headerStroke.Color = Color3.fromRGB(70, 70, 70)
    headerStroke.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = header
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Position = UDim2.new(0, 14, 0, 4)
    title.Size = UDim2.new(1, -28, 0, 20)
    title.Text = "NPC Teleport V1.0 (WorldBoss)"

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Parent = header
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    subtitle.Position = UDim2.new(0, 14, 0, 22)
    subtitle.Size = UDim2.new(1, -28, 0, 18)
    subtitle.Text = "Scan Point1/2/3 lalu teleport cepat ke NPC (Sell Fish, Shop, dll.)."

    local bodyScroll = Instance.new("ScrollingFrame")
    bodyScroll.Name = "BodyScroll"
    bodyScroll.Parent = frame
    bodyScroll.BackgroundTransparency = 1
    bodyScroll.BorderSizePixel = 0
    bodyScroll.Position = UDim2.new(0, 8, 0, 62)
    bodyScroll.Size = UDim2.new(1, -16, 1, -70)
    bodyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    bodyScroll.ScrollBarThickness = 4
    bodyScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local padding = Instance.new("UIPadding")
    padding.Parent = bodyScroll
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)

    local layout = Instance.new("UIListLayout")
    layout.Parent = bodyScroll
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        bodyScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end))

    return header, bodyScroll
end

local function createCard(parent, titleText, subtitleText, layoutOrder, height)
    height = height or 260

    local card = Instance.new("Frame")
    card.Name = titleText or "Card"
    card.Parent = parent
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, height)
    card.LayoutOrder = layoutOrder or 1

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 70)
    stroke.Thickness = 1
    stroke.Parent = card

    local padding = Instance.new("UIPadding")
    padding.Parent = card
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = card
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = titleText or "Card"
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Size = UDim2.new(1, 0, 0, 18)

    if subtitleText and subtitleText ~= "" then
        local subtitle = Instance.new("TextLabel")
        subtitle.Name = "Subtitle"
        subtitle.Parent = card
        subtitle.BackgroundTransparency = 1
        subtitle.Font = Enum.Font.Gotham
        subtitle.TextSize = 12
        subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.TextWrapped = true
        subtitle.Text = subtitleText
        subtitle.Position = UDim2.new(0, 0, 0, 20)
        subtitle.Size = UDim2.new(1, 0, 0, 26)
    end

    return card
end

local function createTextButton(parent, text, height)
    height = height or 30

    local button = Instance.new("TextButton")
    button.Name = (text or "Button"):gsub("%s+", "") .. "Button"
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.Size = UDim2.new(1, 0, 0, height)
    button.TextWrapped = true
    button.Text = text or "Button"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    return button
end

------------------- NPC TELEPORT UI & LOGIC -------------------
local currentPointName   = nil
local currentNpcList     = {}
local selectedNpcConfig  = nil

local pointLabel         = nil
local npcDropdownButton  = nil
local npcOptionsFrame    = nil
local teleportNpcButton  = nil

local function formatPointDisplayName(name)
    if name == "Point1" then
        return "Point1 (Main Island / Boss Area 1)"
    elseif name == "Point2" then
        return "Point2 (Boss Area 2)"
    elseif name == "Point3" then
        return "Point3 (Underwater Boss / Deep Area)"
    end
    return "Unknown"
end

local function updatePointLabel()
    if not pointLabel then
        return
    end

    if currentPointName then
        pointLabel.Text = "Current Point: " .. formatPointDisplayName(currentPointName)
    else
        pointLabel.Text = "Current Point: Unknown (WorldBoss not found / too far)"
    end
end

local function rebuildNpcOptions()
    if not npcDropdownButton or not npcOptionsFrame then
        return
    end

    -- Clear options
    for _, child in ipairs(npcOptionsFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    selectedNpcConfig = nil

    if not currentPointName then
        npcDropdownButton.Text = "NPC: - (Refresh Point terlebih dahulu)"
        return
    end

    local list = NPC_CONFIG[currentPointName] or {}
    currentNpcList = list

    if #list == 0 then
        npcDropdownButton.Text = "NPC: (Tidak ada NPC terdaftar untuk Point ini)"
        return
    end

    -- Default: pilih NPC pertama
    selectedNpcConfig = list[1]
    npcDropdownButton.Text = "NPC: " .. (selectedNpcConfig.name or selectedNpcConfig.id or "Unknown")

    for _, npc in ipairs(list) do
        local opt = Instance.new("TextButton")
        opt.Name = npc.id or npc.name or "NPC"
        opt.Parent = npcOptionsFrame
        opt.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        opt.BorderSizePixel = 0
        opt.AutoButtonColor = true
        opt.Font = Enum.Font.Gotham
        opt.TextSize = 12
        opt.TextColor3 = Color3.fromRGB(230, 230, 230)
        opt.TextXAlignment = Enum.TextXAlignment.Left
        opt.Size = UDim2.new(1, 0, 0, 24)
        opt.Text = "  " .. (npc.name or npc.id or "NPC")

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = opt

        table.insert(connections, opt.MouseButton1Click:Connect(function()
            selectedNpcConfig = npc
            npcDropdownButton.Text = "NPC: " .. (npc.name or npc.id or "NPC")
            npcOptionsFrame.Visible = false
        end))
    end
end

local function refreshCurrentPoint()
    local newPoint = detectCurrentPointName()
    currentPointName = newPoint
    updatePointLabel()
    rebuildNpcOptions()

    if currentPointName then
        notify("NPC Teleport", "Point aktif sekarang: " .. currentPointName, 3)
    else
        notify("NPC Teleport", "Gagal mendeteksi Point (WorldBoss/HRP tidak ditemukan).", 4)
    end
end

local function buildNpcTeleportCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "NPC Teleport (WorldBoss)",
        "Pilih Point via scan, lalu pilih NPC dari dropdown dan teleport dengan sekali klik.",
        1,
        260
    )

    local container = Instance.new("Frame")
    container.Name = "NpcTeleportContainer"
    container.Parent = card
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Position = UDim2.new(0, 0, 0, 48)
    container.Size = UDim2.new(1, 0, 1, -48)

    local layout = Instance.new("UIListLayout")
    layout.Parent = container
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    ------------------- ROW: Current Point + Refresh -------------------
    local row = Instance.new("Frame")
    row.Name = "PointRow"
    row.Parent = container
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 28)

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.Parent = row
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Padding = UDim.new(0, 6)

    pointLabel = Instance.new("TextLabel")
    pointLabel.Name = "PointLabel"
    pointLabel.Parent = row
    pointLabel.BackgroundTransparency = 1
    pointLabel.Font = Enum.Font.Gotham
    pointLabel.TextSize = 12
    pointLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    pointLabel.TextXAlignment = Enum.TextXAlignment.Left
    pointLabel.Size = UDim2.new(1, -110, 1, 0)
    pointLabel.Text = "Current Point: Unknown"

    local refreshButton = Instance.new("TextButton")
    refreshButton.Name = "RefreshPointButton"
    refreshButton.Parent = row
    refreshButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    refreshButton.BorderSizePixel = 0
    refreshButton.AutoButtonColor = true
    refreshButton.Font = Enum.Font.GothamSemibold
    refreshButton.TextSize = 12
    refreshButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    refreshButton.Size = UDim2.new(0, 100, 1, 0)
    refreshButton.Text = "Refresh Point"

    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 8)
    refreshCorner.Parent = refreshButton

    ------------------- DROPDOWN: NPC LIST -------------------
    npcDropdownButton = Instance.new("TextButton")
    npcDropdownButton.Name = "NpcDropdownButton"
    npcDropdownButton.Parent = container
    npcDropdownButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    npcDropdownButton.BorderSizePixel = 0
    npcDropdownButton.AutoButtonColor = true
    npcDropdownButton.Font = Enum.Font.Gotham
    npcDropdownButton.TextSize = 12
    npcDropdownButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    npcDropdownButton.TextXAlignment = Enum.TextXAlignment.Left
    npcDropdownButton.Size = UDim2.new(1, 0, 0, 32)
    npcDropdownButton.Text = "NPC: - (Refresh Point terlebih dahulu)"

    local dropCorner = Instance.new("UICorner")
    dropCorner.CornerRadius = UDim.new(0, 8)
    dropCorner.Parent = npcDropdownButton

    local dropPadding = Instance.new("UIPadding")
    dropPadding.Parent = npcDropdownButton
    dropPadding.PaddingLeft = UDim.new(0, 10)
    dropPadding.PaddingRight = UDim.new(0, 10)

    -- Dropdown options frame (anak dari button, muncul di bawah)
    npcOptionsFrame = Instance.new("Frame")
    npcOptionsFrame.Name = "NpcOptionsFrame"
    npcOptionsFrame.Parent = npcDropdownButton
    npcOptionsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    npcOptionsFrame.BorderSizePixel = 0
    npcOptionsFrame.Position = UDim2.new(0, 0, 1, 4)
    npcOptionsFrame.Size = UDim2.new(1, 0, 0, 0)
    npcOptionsFrame.Visible = false
    npcOptionsFrame.AutomaticSize = Enum.AutomaticSize.Y

    local optCorner = Instance.new("UICorner")
    optCorner.CornerRadius = UDim.new(0, 8)
    optCorner.Parent = npcOptionsFrame

    local optStroke = Instance.new("UIStroke")
    optStroke.Thickness = 1
    optStroke.Color = Color3.fromRGB(70, 70, 70)
    optStroke.Parent = npcOptionsFrame

    local optLayout = Instance.new("UIListLayout")
    optLayout.Parent = npcOptionsFrame
    optLayout.FillDirection = Enum.FillDirection.Vertical
    optLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optLayout.Padding = UDim.new(0, 2)

    ------------------- BUTTON: TELEPORT TO NPC -------------------
    teleportNpcButton = createTextButton(container, "Teleport to NPC", 32)

    ------------------- HOOKS -------------------
    table.insert(connections, refreshButton.MouseButton1Click:Connect(function()
        refreshCurrentPoint()
    end))

    table.insert(connections, npcDropdownButton.MouseButton1Click:Connect(function()
        if npcOptionsFrame.Visible then
            npcOptionsFrame.Visible = false
        else
            -- Jangan buka jika belum ada Point (user belum klik Refresh)
            if not currentPointName then
                notify("NPC Teleport", "Klik dulu 'Refresh Point' untuk deteksi Point.", 3)
                return
            end
            npcOptionsFrame.Visible = true
        end
    end))

    table.insert(connections, teleportNpcButton.MouseButton1Click:Connect(function()
        if not selectedNpcConfig then
            notify("NPC Teleport", "Pilih NPC dulu di dropdown sebelum teleport.", 3)
            return
        end

        local pos   = selectedNpcConfig.position
        local look  = selectedNpcConfig.lookAt
        if not pos then
            notify("NPC Teleport", "Posisi NPC tidak valid.", 3)
            return
        end

        smoothTeleportTo(pos, look)
        notify("NPC Teleport", "Teleport ke: " .. (selectedNpcConfig.name or selectedNpcConfig.id or "NPC"), 3)
    end))

    -- Inisialisasi label
    updatePointLabel()
end

------------------- BUILD UI -------------------
local function buildAllUI()
    local _, bodyScroll = createMainLayout()
    buildNpcTeleportCard(bodyScroll)
end

buildAllUI()

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    currentPointName  = nil
    currentNpcList    = {}
    selectedNpcConfig = nil

    if activeTeleportTween then
        pcall(function()
            activeTeleportTween:Cancel()
        end)
        activeTeleportTween = nil
    end

    for _, conn in ipairs(connections) do
        if conn and conn.Disconnect then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end
    connections = {}

    if frame then
        pcall(function()
            frame:ClearAllChildren()
        end)
    end
end

local NPC_CONFIG = {
    Point1 = {
        {
            id       = "P1_SellFish_1",
            name     = "Sell Fish (Tabe)",
            position = Vector3.new(1352.67, 96.04, -282.58),
            lookAt   = Vector3.new(1362.56, 96.04, -284.06),
        },
        {
            id       = "P1_HarpoonShop_1",
            name     = "Harpoon Shop (David)",
            position = Vector3.new(1396.57, 92.63, -166.08),
            lookAt   = Vector3.new(1406.55, 92.63, -165.48),
        },
        {
            id       = "P1_GunShop_1",
            name     = "GunShop (Uzi)",
            position = Vector3.new(1318.70, 88.41, -455.84),
            lookAt   = Vector3.new(1328.44, 88.41, -458.11),
        },
        {
            id       = "P1_BaitShop_1",
            name     = "Bait Shop (Jack)",
            position = Vector3.new(1414.43, 92.26, -237.04),
            lookAt   = Vector3.new(1419.48, 92.26, -245.68),
        },
        {
            id       = "P1_BasketShop_1",
            name     = "Basket Shop (Andy)",
            position = Vector3.new(1179.85, 89.86, -188.80),
            lookAt   = Vector3.new(1169.86, 89.86, -188.25),
        },
        {
            id       = "P1_SellFish_2",
            name     = "Sell Fish 2 (Tabe)",
            position = Vector3.new(1193.98, 98.69, 53.40),
            lookAt   = Vector3.new(1184.60, 98.69, 56.88),
        },
        {
            id       = "P1_HarpoonShop_2",
            name     = "Harpoon Shop 2 (David)",
            position = Vector3.new(1192.98, 99.69, 98.90),
            lookAt   = Vector3.new(1187.23, 99.69, 107.08),
        },
    },
    Point2 = {
        {
            id       = "P2_SellFish_1",
            name     = "Sell Fish (Tabe)",
            position = Vector3.new(383.88, 89.70, -915.45),
            lookAt   = Vector3.new(378.21, 89.70, -907.21),
        },
        {
            id       = "P2_GunShop_1",
            name     = "GunShop (Uzi)",
            position = Vector3.new(346.59, 88.79, -931.89),
            lookAt   = Vector3.new(338.53, 88.79, -925.98),
        },
    },
    Point3 = {
        {
            id       = "P3_SellFish_1",
            name     = "Sell Fish (Tabe)",
            position = Vector3.new(1379.17, -1133.39, 2845.70),
            lookAt   = Vector3.new(1389.15, -1133.45, 2845.11),
        },
    },
}

------------------- TELEPORT HELPER -------------------
local activeTeleportTween = nil

local function smoothTeleportTo(position, lookAtPos)
    local hrp = getHRP()
    if not hrp or not position then
        return
    end

    if activeTeleportTween then
        pcall(function()
            activeTeleportTween:Cancel()
        end)
        activeTeleportTween = nil
    end

    local targetCFrame
    if lookAtPos and (lookAtPos - position).Magnitude > 0.1 then
        targetCFrame = CFrame.new(position, lookAtPos)
    else
        targetCFrame = CFrame.new(position)
    end

    local fromPos  = hrp.Position
    local distance = (fromPos - position).Magnitude

    -- Kalau jarak dekat, langsung set tanpa tween
    if distance < 3 then
        hrp.CFrame = targetCFrame
        return
    end

    local duration = math.clamp(distance / 260, 0.05, 0.25)

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { CFrame = targetCFrame }
    )
    activeTeleportTween = tween
    tween:Play()

    task.spawn(function()
        pcall(function()
            tween.Completed:Wait()
        end)
        if activeTeleportTween == tween then
            activeTeleportTween = nil
        end
    end)
end

------------------- DETECT CURRENT POINT (WORLD BOSS) -------------------
local function ensureWorldBoss()
    if not WorldBoss or not WorldBoss.Parent then
        WorldBoss = workspace:FindFirstChild("WorldBoss")
    end
    return WorldBoss
end

local function getRegionCenter(region)
    if not region then
        return nil
    end

    if region:IsA("BasePart") then
        return region.Position
    end

    local sum   = Vector3.new(0, 0, 0)
    local count = 0

    local ok, descendants = pcall(function()
        return region:GetDescendants()
    end)
    if not ok or not descendants then
        return nil
    end

    for _, inst in ipairs(descendants) do
        if inst:IsA("BasePart") then
            sum   += inst.Position
            count += 1
        end
    end

    if count == 0 then
        return nil
    end

    return sum / count
end

local function detectCurrentPointName()
    local wb = ensureWorldBoss()
    if not wb then
        return nil
    end

    local hrp = getHRP()
    if not hrp then
        return nil
    end
    local hrpPos = hrp.Position

    local bestName
    local bestDist = math.huge

    for _, pointName in ipairs({ "Point1", "Point2", "Point3" }) do
        local region = wb:FindFirstChild(pointName)
        if region then
            local center = getRegionCenter(region)
            if center then
                local d = (center - hrpPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestName = pointName
                end
            end
        end
    end

    return bestName
end

------------------- UI HELPERS -------------------
local function createMainLayout()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Parent = frame
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    header.BackgroundTransparency = 0.1
    header.BorderSizePixel = 0
    header.Position = UDim2.new(0, 8, 0, 8)
    header.Size = UDim2.new(1, -16, 0, 46)

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    local headerStroke = Instance.new("UIStroke")
    headerStroke.Thickness = 1
    headerStroke.Color = Color3.fromRGB(70, 70, 70)
    headerStroke.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = header
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Position = UDim2.new(0, 14, 0, 4)
    title.Size = UDim2.new(1, -28, 0, 20)
    title.Text = "NPC Teleport V1.0 (WorldBoss)"

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Parent = header
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    subtitle.Position = UDim2.new(0, 14, 0, 22)
    subtitle.Size = UDim2.new(1, -28, 0, 18)
    subtitle.Text = "Scan Point1/2/3 lalu teleport cepat ke NPC (Sell Fish, Shop, dll.)."

    local bodyScroll = Instance.new("ScrollingFrame")
    bodyScroll.Name = "BodyScroll"
    bodyScroll.Parent = frame
    bodyScroll.BackgroundTransparency = 1
    bodyScroll.BorderSizePixel = 0
    bodyScroll.Position = UDim2.new(0, 8, 0, 62)
    bodyScroll.Size = UDim2.new(1, -16, 1, -70)
    bodyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    bodyScroll.ScrollBarThickness = 4
    bodyScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local padding = Instance.new("UIPadding")
    padding.Parent = bodyScroll
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)

    local layout = Instance.new("UIListLayout")
    layout.Parent = bodyScroll
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        bodyScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end))

    return header, bodyScroll
end

local function createCard(parent, titleText, subtitleText, layoutOrder, height)
    height = height or 260

    local card = Instance.new("Frame")
    card.Name = titleText or "Card"
    card.Parent = parent
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, height)
    card.LayoutOrder = layoutOrder or 1

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 70)
    stroke.Thickness = 1
    stroke.Parent = card

    local padding = Instance.new("UIPadding")
    padding.Parent = card
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = card
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = titleText or "Card"
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Size = UDim2.new(1, 0, 0, 18)

    if subtitleText and subtitleText ~= "" then
        local subtitle = Instance.new("TextLabel")
        subtitle.Name = "Subtitle"
        subtitle.Parent = card
        subtitle.BackgroundTransparency = 1
        subtitle.Font = Enum.Font.Gotham
        subtitle.TextSize = 12
        subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.TextWrapped = true
        subtitle.Text = subtitleText
        subtitle.Position = UDim2.new(0, 0, 0, 20)
        subtitle.Size = UDim2.new(1, 0, 0, 26)
    end

    return card
end

local function createTextButton(parent, text, height)
    height = height or 30

    local button = Instance.new("TextButton")
    button.Name = (text or "Button"):gsub("%s+", "") .. "Button"
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.Size = UDim2.new(1, 0, 0, height)
    button.TextWrapped = true
    button.Text = text or "Button"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    return button
end

------------------- NPC TELEPORT UI & LOGIC -------------------
local currentPointName   = nil
local currentNpcList     = {}
local selectedNpcConfig  = nil

local pointLabel         = nil
local npcDropdownButton  = nil
local npcOptionsFrame    = nil
local teleportNpcButton  = nil

local function formatPointDisplayName(name)
    if name == "Point1" then
        return "Point1 (Main Island / Boss Area 1)"
    elseif name == "Point2" then
        return "Point2 (Boss Area 2)"
    elseif name == "Point3" then
        return "Point3 (Underwater Boss / Deep Area)"
    end
    return "Unknown"
end

local function updatePointLabel()
    if not pointLabel then
        return
    end

    if currentPointName then
        pointLabel.Text = "Current Point: " .. formatPointDisplayName(currentPointName)
    else
        pointLabel.Text = "Current Point: Unknown (WorldBoss not found / too far)"
    end
end

local function rebuildNpcOptions()
    if not npcDropdownButton or not npcOptionsFrame then
        return
    end

    -- Clear options
    for _, child in ipairs(npcOptionsFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    selectedNpcConfig = nil

    if not currentPointName then
        npcDropdownButton.Text = "NPC: - (Refresh Point terlebih dahulu)"
        return
    end

    local list = NPC_CONFIG[currentPointName] or {}
    currentNpcList = list

    if #list == 0 then
        npcDropdownButton.Text = "NPC: (Tidak ada NPC terdaftar untuk Point ini)"
        return
    end

    -- Default: pilih NPC pertama
    selectedNpcConfig = list[1]
    npcDropdownButton.Text = "NPC: " .. (selectedNpcConfig.name or selectedNpcConfig.id or "Unknown")

    for _, npc in ipairs(list) do
        local opt = Instance.new("TextButton")
        opt.Name = npc.id or npc.name or "NPC"
        opt.Parent = npcOptionsFrame
        opt.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        opt.BorderSizePixel = 0
        opt.AutoButtonColor = true
        opt.Font = Enum.Font.Gotham
        opt.TextSize = 12
        opt.TextColor3 = Color3.fromRGB(230, 230, 230)
        opt.TextXAlignment = Enum.TextXAlignment.Left
        opt.Size = UDim2.new(1, 0, 0, 24)
        opt.Text = "  " .. (npc.name or npc.id or "NPC")

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = opt

        table.insert(connections, opt.MouseButton1Click:Connect(function()
            selectedNpcConfig = npc
            npcDropdownButton.Text = "NPC: " .. (npc.name or npc.id or "NPC")
            npcOptionsFrame.Visible = false
        end))
    end
end

local function refreshCurrentPoint()
    local newPoint = detectCurrentPointName()
    currentPointName = newPoint
    updatePointLabel()
    rebuildNpcOptions()

    if currentPointName then
        notify("NPC Teleport", "Point aktif sekarang: " .. currentPointName, 3)
    else
        notify("NPC Teleport", "Gagal mendeteksi Point (WorldBoss/HRP tidak ditemukan).", 4)
    end
end

local function buildNpcTeleportCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "NPC Teleport (WorldBoss)",
        "Pilih Point via scan, lalu pilih NPC dari dropdown dan teleport dengan sekali klik.",
        1,
        260
    )

    local container = Instance.new("Frame")
    container.Name = "NpcTeleportContainer"
    container.Parent = card
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Position = UDim2.new(0, 0, 0, 48)
    container.Size = UDim2.new(1, 0, 1, -48)

    local layout = Instance.new("UIListLayout")
    layout.Parent = container
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    ------------------- ROW: Current Point + Refresh -------------------
    local row = Instance.new("Frame")
    row.Name = "PointRow"
    row.Parent = container
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 28)

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.Parent = row
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Padding = UDim.new(0, 6)

    pointLabel = Instance.new("TextLabel")
    pointLabel.Name = "PointLabel"
    pointLabel.Parent = row
    pointLabel.BackgroundTransparency = 1
    pointLabel.Font = Enum.Font.Gotham
    pointLabel.TextSize = 12
    pointLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    pointLabel.TextXAlignment = Enum.TextXAlignment.Left
    pointLabel.Size = UDim2.new(1, -110, 1, 0)
    pointLabel.Text = "Current Point: Unknown"

    local refreshButton = Instance.new("TextButton")
    refreshButton.Name = "RefreshPointButton"
    refreshButton.Parent = row
    refreshButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    refreshButton.BorderSizePixel = 0
    refreshButton.AutoButtonColor = true
    refreshButton.Font = Enum.Font.GothamSemibold
    refreshButton.TextSize = 12
    refreshButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    refreshButton.Size = UDim2.new(0, 100, 1, 0)
    refreshButton.Text = "Refresh Point"

    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 8)
    refreshCorner.Parent = refreshButton

    ------------------- DROPDOWN: NPC LIST -------------------
    npcDropdownButton = Instance.new("TextButton")
    npcDropdownButton.Name = "NpcDropdownButton"
    npcDropdownButton.Parent = container
    npcDropdownButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    npcDropdownButton.BorderSizePixel = 0
    npcDropdownButton.AutoButtonColor = true
    npcDropdownButton.Font = Enum.Font.Gotham
    npcDropdownButton.TextSize = 12
    npcDropdownButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    npcDropdownButton.TextXAlignment = Enum.TextXAlignment.Left
    npcDropdownButton.Size = UDim2.new(1, 0, 0, 32)
    npcDropdownButton.Text = "NPC: - (Refresh Point terlebih dahulu)"

    local dropCorner = Instance.new("UICorner")
    dropCorner.CornerRadius = UDim.new(0, 8)
    dropCorner.Parent = npcDropdownButton

    local dropPadding = Instance.new("UIPadding")
    dropPadding.Parent = npcDropdownButton
    dropPadding.PaddingLeft = UDim.new(0, 10)
    dropPadding.PaddingRight = UDim.new(0, 10)

    -- Dropdown options frame (anak dari button, muncul di bawah)
    npcOptionsFrame = Instance.new("Frame")
    npcOptionsFrame.Name = "NpcOptionsFrame"
    npcOptionsFrame.Parent = npcDropdownButton
    npcOptionsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    npcOptionsFrame.BorderSizePixel = 0
    npcOptionsFrame.Position = UDim2.new(0, 0, 1, 4)
    npcOptionsFrame.Size = UDim2.new(1, 0, 0, 0)
    npcOptionsFrame.Visible = false
    npcOptionsFrame.AutomaticSize = Enum.AutomaticSize.Y

    local optCorner = Instance.new("UICorner")
    optCorner.CornerRadius = UDim.new(0, 8)
    optCorner.Parent = npcOptionsFrame

    local optStroke = Instance.new("UIStroke")
    optStroke.Thickness = 1
    optStroke.Color = Color3.fromRGB(70, 70, 70)
    optStroke.Parent = npcOptionsFrame

    local optLayout = Instance.new("UIListLayout")
    optLayout.Parent = npcOptionsFrame
    optLayout.FillDirection = Enum.FillDirection.Vertical
    optLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optLayout.Padding = UDim.new(0, 2)

    ------------------- BUTTON: TELEPORT TO NPC -------------------
    teleportNpcButton = createTextButton(container, "Teleport to NPC", 32)

    ------------------- HOOKS -------------------
    table.insert(connections, refreshButton.MouseButton1Click:Connect(function()
        refreshCurrentPoint()
    end))

    table.insert(connections, npcDropdownButton.MouseButton1Click:Connect(function()
        if npcOptionsFrame.Visible then
            npcOptionsFrame.Visible = false
        else
            -- Jangan buka jika belum ada Point (user belum klik Refresh)
            if not currentPointName then
                notify("NPC Teleport", "Klik dulu 'Refresh Point' untuk deteksi Point.", 3)
                return
            end
            npcOptionsFrame.Visible = true
        end
    end))

    table.insert(connections, teleportNpcButton.MouseButton1Click:Connect(function()
        if not selectedNpcConfig then
            notify("NPC Teleport", "Pilih NPC dulu di dropdown sebelum teleport.", 3)
            return
        end

        local pos   = selectedNpcConfig.position
        local look  = selectedNpcConfig.lookAt
        if not pos then
            notify("NPC Teleport", "Posisi NPC tidak valid.", 3)
            return
        end

        smoothTeleportTo(pos, look)
        notify("NPC Teleport", "Teleport ke: " .. (selectedNpcConfig.name or selectedNpcConfig.id or "NPC"), 3)
    end))

    -- Inisialisasi label
    updatePointLabel()
end

------------------- BUILD UI -------------------
local function buildAllUI()
    local _, bodyScroll = createMainLayout()
    buildNpcTeleportCard(bodyScroll)
end

buildAllUI()

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    currentPointName  = nil
    currentNpcList    = {}
    selectedNpcConfig = nil

    if activeTeleportTween then
        pcall(function()
            activeTeleportTween:Cancel()
        end)
        activeTeleportTween = nil
    end

    for _, conn in ipairs(connections) do
        if conn and conn.Disconnect then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end
    connections = {}

    if frame then
        pcall(function()
            frame:ClearAllChildren()
        end)
    end
end
