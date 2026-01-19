--==========================================================
--  5AxaTab_NPCTeleport.lua
--  TAB 5: "NPC Teleport PRO++ / NPC Navigator"
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
local NPC_CONFIG = {
    Point1 = {
        {
            id       = "P1_SellFish_1",
            name     = "Tabe (Sell Fish)",
            position = Vector3.new(1352.67, 96.04, -282.58),
            lookAt   = Vector3.new(1362.56, 96.04, -284.06),
        },
        {
            id       = "P1_HarpoonShop_1",
            name     = "David (Harpoon Shop)",
            position = Vector3.new(1396.57, 92.63, -166.08),
            lookAt   = Vector3.new(1406.55, 92.63, -165.48),
        },
        {
            id       = "P1_GunShop_1",
            name     = "Uzi (Gun Shop)",
            position = Vector3.new(1318.70, 88.41, -455.84),
            lookAt   = Vector3.new(1328.44, 88.41, -458.11),
        },
        {
            id       = "P1_BaitShop_1",
            name     = "Jack (Bait Shop)",
            position = Vector3.new(1414.43, 92.26, -237.04),
            lookAt   = Vector3.new(1419.48, 92.26, -245.68),
        },
        {
            id       = "P1_BasketShop_1",
            name     = "Andy (Basket Shop)",
            position = Vector3.new(1179.85, 89.86, -188.80),
            lookAt   = Vector3.new(1169.86, 89.86, -188.25),
        },
        {
            id       = "P1_SellFish_2",
            name     = "Tabe (Sell Fish 2)",
            position = Vector3.new(1193.98, 98.69, 53.40),
            lookAt   = Vector3.new(1184.60, 98.69, 56.88),
        },
        {
            id       = "P1_HarpoonShop_2",
            name     = "David (Harpoon Shop 2)",
            position = Vector3.new(1192.98, 99.69, 98.90),
            lookAt   = Vector3.new(1187.23, 99.69, 107.08),
        },
    },
    Point2 = {
        {
            id       = "P2_SellFish_1",
            name     = "Tabe (Sell Fish)",
            position = Vector3.new(383.88, 89.70, -915.45),
            lookAt   = Vector3.new(378.21, 89.70, -907.21),
        },
        {
            id       = "P2_GunShop_1",
            name     = "Uzi (Gun Shop)",
            position = Vector3.new(346.59, 88.79, -931.89),
            lookAt   = Vector3.new(338.53, 88.79, -925.98),
        },
    },
    Point3 = {
        {
            id       = "P3_SellFish_1",
            name     = "Tabe (Sell Fish)",
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
            sum   = sum + inst.Position
            count = count + 1
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
    title.Text = "NPC Navigator"

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
    subtitle.Text = "Select NPC → Refresh List → Teleport Now."

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
    height = height or 220

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

------------------- NPC TELEPORT UI & LOGIC -------------------
local currentPointName  = nil
local currentNpcList    = {}
local selectedNpcConfig = nil

local npcDropdownButton  = nil
local npcOptionsFrame    = nil
local teleportNpcButton  = nil

local function rebuildNpcOptions()
    if not npcDropdownButton or not npcOptionsFrame then
        return
    end

    for _, child in ipairs(npcOptionsFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    selectedNpcConfig = nil
    currentNpcList    = {}

    if not currentPointName then
        npcDropdownButton.Text = "--"
        return
    end

    local list = NPC_CONFIG[currentPointName] or {}
    currentNpcList = list

    if #list == 0 then
        npcDropdownButton.Text = "--"
        return
    end

    -- Default pilih NPC pertama
    selectedNpcConfig = list[1]
    npcDropdownButton.Text = selectedNpcConfig.name or selectedNpcConfig.id or "--"

    for _, npc in ipairs(list) do
        local opt = Instance.new("TextButton")
        opt.Name = npc.id or npc.name or "NPC"
        opt.Parent = npcOptionsFrame
        opt.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        opt.BorderSizePixel = 0
        opt.AutoButtonColor = true
        opt.Font = Enum.Font.Gotham
        opt.TextSize = 12
        opt.TextColor3 = Color3.fromRGB(230, 230, 230)
        opt.TextXAlignment = Enum.TextXAlignment.Left
        opt.Size = UDim2.new(1, -8, 0, 26)
        opt.Position = UDim2.new(0, 4, 0, 0)
        opt.Text = "  " .. (npc.name or npc.id or "NPC")
        opt.ZIndex = 6

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = opt

        table.insert(connections, opt.MouseButton1Click:Connect(function()
            selectedNpcConfig = npc
            npcDropdownButton.Text = npc.name or npc.id or "--"
            npcOptionsFrame.Visible = false
        end))
    end
end

local function refreshCurrentPoint()
    local newPoint = detectCurrentPointName()
    currentPointName = newPoint
    rebuildNpcOptions()

    if currentPointName then
        notify("NPC Navigator", "Active Point detected: " .. tostring(currentPointName), 3)
    else
        notify("NPC Navigator", "Failed to detect Point (WorldBoss/HRP not found).", 4)
    end
end

local function buildNpcTeleportCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "NPC Navigator",
        "Dropdown NPC berdasarkan Point terdekat (Point1/2/3).",
        1,
        230
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

    ------------------- ROW 1: SELECT NPC -------------------
    local selectRow = Instance.new("Frame")
    selectRow.Name = "SelectRow"
    selectRow.Parent = container
    selectRow.BackgroundTransparency = 1
    selectRow.BorderSizePixel = 0
    selectRow.Size = UDim2.new(1, 0, 0, 40)

    local selectLayout = Instance.new("UIListLayout")
    selectLayout.Parent = selectRow
    selectLayout.FillDirection = Enum.FillDirection.Horizontal
    selectLayout.SortOrder = Enum.SortOrder.LayoutOrder
    selectLayout.Padding = UDim.new(0, 6)

    local selectLabel = Instance.new("TextLabel")
    selectLabel.Name = "SelectLabel"
    selectLabel.Parent = selectRow
    selectLabel.BackgroundTransparency = 1
    selectLabel.Font = Enum.Font.Gotham
    selectLabel.TextSize = 13
    selectLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    selectLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectLabel.Size = UDim2.new(0.45, 0, 1, 0)
    selectLabel.Text = "Select NPC"

    npcDropdownButton = Instance.new("TextButton")
    npcDropdownButton.Name = "NpcDropdownButton"
    npcDropdownButton.Parent = selectRow
    npcDropdownButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    npcDropdownButton.BorderSizePixel = 0
    npcDropdownButton.AutoButtonColor = true
    npcDropdownButton.Font = Enum.Font.Gotham
    npcDropdownButton.TextSize = 12
    npcDropdownButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    npcDropdownButton.TextXAlignment = Enum.TextXAlignment.Center
    npcDropdownButton.Size = UDim2.new(0.55, 0, 1, 0)
    npcDropdownButton.Text = "--"
    npcDropdownButton.ZIndex = 4

    local dropCorner = Instance.new("UICorner")
    dropCorner.CornerRadius = UDim.new(0, 10)
    dropCorner.Parent = npcDropdownButton

    ------------------- DROPDOWN PANEL -------------------
    npcOptionsFrame = Instance.new("Frame")
    npcOptionsFrame.Name = "NpcOptionsFrame"
    npcOptionsFrame.Parent = npcDropdownButton
    npcOptionsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    npcOptionsFrame.BorderSizePixel = 0
    npcOptionsFrame.Position = UDim2.new(0, 0, 1, 4)
    npcOptionsFrame.Size = UDim2.new(1, 0, 0, 0)
    npcOptionsFrame.Visible = false
    npcOptionsFrame.AutomaticSize = Enum.AutomaticSize.Y
    npcOptionsFrame.ZIndex = 5
    npcOptionsFrame.ClipsDescendants = true

    local optCorner = Instance.new("UICorner")
    optCorner.CornerRadius = UDim.new(0, 10)
    optCorner.Parent = npcOptionsFrame

    local optStroke = Instance.new("UIStroke")
    optStroke.Thickness = 1
    optStroke.Color = Color3.fromRGB(70, 70, 70)
    optStroke.Parent = npcOptionsFrame

    local optPadding = Instance.new("UIPadding")
    optPadding.Parent = npcOptionsFrame
    optPadding.PaddingTop = UDim.new(0, 4)
    optPadding.PaddingBottom = UDim.new(0, 4)
    optPadding.PaddingLeft = UDim.new(0, 4)
    optPadding.PaddingRight = UDim.new(0, 4)

    local optLayout = Instance.new("UIListLayout")
    optLayout.Parent = npcOptionsFrame
    optLayout.FillDirection = Enum.FillDirection.Vertical
    optLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optLayout.Padding = UDim.new(0, 2)

    ------------------- ROW 2: REFRESH LIST -------------------
    local refreshRow = Instance.new("TextButton")
    refreshRow.Name = "RefreshRow"
    refreshRow.Parent = container
    refreshRow.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    refreshRow.BorderSizePixel = 0
    refreshRow.AutoButtonColor = true
    refreshRow.Size = UDim2.new(1, 0, 0, 48)
    refreshRow.Text = ""
    refreshRow.ZIndex = 2

    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 10)
    refreshCorner.Parent = refreshRow

    local refreshTitle = Instance.new("TextLabel")
    refreshTitle.Name = "RefreshTitle"
    refreshTitle.Parent = refreshRow
    refreshTitle.BackgroundTransparency = 1
    refreshTitle.Font = Enum.Font.GothamSemibold
    refreshTitle.TextSize = 13
    refreshTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
    refreshTitle.TextXAlignment = Enum.TextXAlignment.Left
    refreshTitle.Position = UDim2.new(0, 10, 0, 4)
    refreshTitle.Size = UDim2.new(1, -20, 0, 18)
    refreshTitle.Text = "Refresh List"

    local refreshSub = Instance.new("TextLabel")
    refreshSub.Name = "RefreshSub"
    refreshSub.Parent = refreshRow
    refreshSub.BackgroundTransparency = 1
    refreshSub.Font = Enum.Font.Gotham
    refreshSub.TextSize = 11
    refreshSub.TextColor3 = Color3.fromRGB(180, 180, 180)
    refreshSub.TextXAlignment = Enum.TextXAlignment.Left
    refreshSub.Position = UDim2.new(0, 10, 0, 22)
    refreshSub.Size = UDim2.new(1, -20, 0, 18)
    refreshSub.Text = "Click if NPC is missing"

    ------------------- ROW 3: TELEPORT NOW -------------------
    teleportNpcButton = Instance.new("TextButton")
    teleportNpcButton.Name = "TeleportRow"
    teleportNpcButton.Parent = container
    teleportNpcButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    teleportNpcButton.BorderSizePixel = 0
    teleportNpcButton.AutoButtonColor = true
    teleportNpcButton.Size = UDim2.new(1, 0, 0, 48)
    teleportNpcButton.Text = ""
    teleportNpcButton.ZIndex = 2

    local teleportCorner = Instance.new("UICorner")
    teleportCorner.CornerRadius = UDim.new(0, 10)
    teleportCorner.Parent = teleportNpcButton

    local tpTitle = Instance.new("TextLabel")
    tpTitle.Name = "TeleportTitle"
    tpTitle.Parent = teleportNpcButton
    tpTitle.BackgroundTransparency = 1
    tpTitle.Font = Enum.Font.GothamSemibold
    tpTitle.TextSize = 13
    tpTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
    tpTitle.TextXAlignment = Enum.TextXAlignment.Left
    tpTitle.Position = UDim2.new(0, 10, 0, 15)
    tpTitle.Size = UDim2.new(1, -20, 0, 18)
    tpTitle.Text = "Teleport Now"

    ------------------- HOOKS -------------------
    table.insert(connections, npcDropdownButton.MouseButton1Click:Connect(function()
        if npcOptionsFrame.Visible then
            npcOptionsFrame.Visible = false
        else
            if not currentPointName then
                notify("NPC Navigator", "Click 'Refresh List' first to detect active Point.", 3)
                return
            end
            npcOptionsFrame.Visible = true
        end
    end))

    table.insert(connections, refreshRow.MouseButton1Click:Connect(function()
        npcOptionsFrame.Visible = false
        refreshCurrentPoint()
    end))

    table.insert(connections, teleportNpcButton.MouseButton1Click:Connect(function()
        npcOptionsFrame.Visible = false

        if not selectedNpcConfig then
            notify("NPC Navigator", "Select NPC from dropdown before teleport.", 3)
            return
        end

        local pos  = selectedNpcConfig.position
        local look = selectedNpcConfig.lookAt
        if not pos then
            notify("NPC Navigator", "Invalid NPC position.", 3)
            return
        end

        smoothTeleportTo(pos, look)
        notify("NPC Navigator", "Teleporting to: " .. (selectedNpcConfig.name or selectedNpcConfig.id or "NPC"), 3)
    end))
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
