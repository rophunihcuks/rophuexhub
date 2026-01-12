--==========================================================
--  3ExTab_SpearFishMisc.lua
--  TAB 3: "Spear Fishing PRO++"
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame   = TAB_FRAME
local tabId   = TAB_ID or "spearfishing"

local Players             = Players             or game:GetService("Players")
local LocalPlayer         = LocalPlayer         or Players.LocalPlayer
local RunService          = RunService          or game:GetService("RunService")
local TweenService        = TweenService        or game:GetService("TweenService")
local HttpService         = HttpService         or game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = UserInputService    or game:GetService("UserInputService")
local StarterGui          = StarterGui          or game:GetService("StarterGui")
local VirtualInputManager = VirtualInputManager or game:GetService("VirtualInputManager")
local MarketplaceService  = game:GetService("MarketplaceService")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

------------------- GLOBAL STATE / AXAHUB -------------------
_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

local alive              = true

-- Notifier
local spawnBossNotifier    = true      -- Spawn Boss Notifier (global)
local hpBossNotifier       = true      -- HP Boss HPBar Notifier (global)
local spawnIllahiNotifier  = false     -- (LOGIC Divine, label di UI/webhook = Divine)
local spawnSecretNotifier  = false     -- Secret Notifier (global)
local climateTimeNotifier  = false     -- Climate Time Notifier (global)

-- ESP
local espBoss              = true      -- ESP Boss global (default ON)
local espIllahi            = false     -- ESP Divine global (default OFF, label di UI = Divine)
local espSecret            = false     -- ESP Secret global (default OFF)

-- Auto Skill (slot ON/OFF)
local autoSkill1      = true
local autoSkill2      = false
local autoSkill3      = false
local autoSkill4      = false
local autoSkill5      = false

-- Mapping Skill ID -> Nama untuk UI
local SKILL_ID_TO_NAME = {
    Skill01 = "Thunder",
    Skill02 = "Cold Snap",
    Skill03 = "Demage Power I",
    Skill04 = "Demage Power II",
    Skill05 = "Quick Shoot",
    Skill06 = "Sniper Shot",
    Skill07 = "Laceration Creation",
    Skill08 = "Demage Power III",
    Skill09 = "Chain Lightning",
    Skill10 = "Dragon Flame",
}

local function normalizeSkillKey(str)
    if not str then return nil end
    str = tostring(str)
    str = str:lower()
    str = str:gsub("%s+", "")
    return str
end

-- Mapping Nama (input user) -> ID Skill (case-insensitive, ignore spasi)
local SKILL_NAME_TO_ID = {}
for id, name in pairs(SKILL_ID_TO_NAME) do
    local key = normalizeSkillKey(name)
    SKILL_NAME_TO_ID[key] = id
end
-- Tambahan: dukung input "skill01", "skill1", dll
for i = 1, 10 do
    local id = string.format("Skill%02d", i)
    SKILL_NAME_TO_ID["skill" .. tostring(i)]   = id
    SKILL_NAME_TO_ID["skill" .. string.format("%02d", i)] = id
end

local function getSkillUiNameFromId(id)
    if not id then return "Unknown" end
    local name = SKILL_ID_TO_NAME[id]
    if name and name ~= "" then
        return name
    end
    return id
end

-- Default mapping slot -> SkillID (SAMA seperti script lama, hanya sekarang bisa diubah via input)
local autoSkill1Id = "Skill04" -- Demage Power II
local autoSkill2Id = "Skill02" -- Cold Snap
local autoSkill3Id = "Skill08" -- Demage Power III
local autoSkill4Id = "Skill01" -- Thunder
local autoSkill5Id = "Skill07" -- Laceration Creation

local autoSkill1Name = getSkillUiNameFromId(autoSkill1Id)
local autoSkill2Name = getSkillUiNameFromId(autoSkill2Id)
local autoSkill3Name = getSkillUiNameFromId(autoSkill3Id)
local autoSkill4Name = getSkillUiNameFromId(autoSkill4Id)
local autoSkill5Name = getSkillUiNameFromId(autoSkill5Id)

-- Webhook umum (optional, diisi user dari UI)
local userWebhookUrl = ""          -- jika kosong -> hanya pakai webhook default di script

local function getUserWebhookTrimmed()
    if type(userWebhookUrl) ~= "string" then
        return nil
    end
    local url = userWebhookUrl:gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" then
        return nil
    end
    return url
end

local character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local backpack        = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack")

local connections     = {}
local ToolsData       = nil

-- UI globals (bagian status/cooldown dihilangkan, tetap disiapkan variabel bila perlu)
local statusLabel            = nil    -- tidak dipakai lagi (UI status panjang dihapus)

------------------- REMOTES & GAME INSTANCES -------------------
local RepRemotes    = ReplicatedStorage:FindFirstChild("Remotes")
local FireRE        = RepRemotes and RepRemotes:FindFirstChild("FireRE")
local ToolRE        = RepRemotes and RepRemotes:FindFirstChild("ToolRE")
local FishRE        = RepRemotes and RepRemotes:FindFirstChild("FishRE")

local GameFolder    = ReplicatedStorage:FindFirstChild("Game")

------------------- SAFE REQUIRE UTILITY / CONFIG MODULES -------------------
local UtilityFolder = ReplicatedStorage:FindFirstChild("Utility")
local ConfigFolder  = ReplicatedStorage:FindFirstChild("Config")

local function safeRequire(folder, name)
    if not folder then return nil end
    local obj = folder:FindFirstChild(name)
    if not obj then return nil end
    local ok, result = pcall(require, obj)
    if not ok then
        warn("[SpearFishing] Gagal require", name, ":", result)
        return nil
    end
    return result
end

local ItemUtil     = safeRequire(UtilityFolder, "ItemUtil")
local ToolUtil     = safeRequire(UtilityFolder, "ToolUtil")
local FormatUtil   = safeRequire(UtilityFolder, "Format")
local PurchaseUtil = safeRequire(UtilityFolder, "PurchaseUtil")
local MathUtil     = safeRequire(UtilityFolder, "MathUtil")
local FishUtil     = safeRequire(UtilityFolder, "FishUtil")
local RepMgr       = safeRequire(UtilityFolder, "RepMgr")

------------------- GAME NAME -------------------
local GAME_NAME = "Unknown Map"
do
    local okInfo, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if okInfo and info and info.Name then
        GAME_NAME = tostring(info.Name)
    end
end

------------------- HELPER: NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Spear Fishing",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

------------------- ID LISTS -------------------
local HARPOON_IDS = {
    "Harpoon01",
    "Harpoon02",
    "Harpoon03",
    "Harpoon04",
    "Harpoon05",
    "Harpoon06",
    "Harpoon07",
    "Harpoon08",
    "Harpoon09",
    "Harpoon10",
    "Harpoon11",
    "Harpoon12",
    "Harpoon20",
    "Harpoon21",
}

-- Illahi / Divine fish (Nether Island)
local ILLAHI_ORDER = {
    "Fish400",
    "Fish401",
    "Fish402",
    "Fish403",
    "Fish404",
    "Fish405",
}

local ILLAHI_FISH_DEFS = {
    Fish400 = { name = "Nether Barracuda",    sea = "Sea7" },
    Fish401 = { name = "Nether Anglerfish",   sea = "Sea7" },
    Fish402 = { name = "Nether Manta Ray",    sea = "Sea6" },
    Fish403 = { name = "Nether SwordFish",    sea = "Sea6" },
    Fish404 = { name = "Nether Flying Fish",  sea = "Sea6" },
    Fish405 = { name = "Diamond Flying Fish", sea = "Sea6" },
}

local ILLAHI_SEA_SET = {
    Sea6 = true,
    Sea7 = true,
}

-- Secret fish (Nether Island)
local SECRET_ORDER = {
    "Fish500",
    "Fish501",
    "Fish503",
    "Fish504",
    "Fish505",
    "Fish508",
    "Fish510",
}

local SECRET_FISH_DEFS = {
    Fish500 = { name = "Abyssal Demon Shark",   sea = "Sea5" },
    Fish501 = { name = "Nighfall Demon Shark",  sea = "Sea5" },
    Fish503 = { name = "Ancient Gopala",        sea = "Sea5" },
    Fish504 = { name = "Nighfall Gopala",       sea = "Sea5" },
    Fish505 = { name = "Sharkster",             sea = "Sea5" },
    Fish508 = { name = "Mayfly Dragon",         sea = "Sea5" },
    Fish510 = { name = "Nighfall Sharkster",    sea = "Sea5" },
}

local SECRET_SEA_SET = {
    Sea5 = true,
}

-- Per ikan toggle notifier
local illahiFishEnabled = {
    Fish400 = false,
    Fish401 = false,
    Fish402 = false,
    Fish403 = false,
    Fish404 = false,
    Fish405 = false,
}

local secretFishEnabled = {
    Fish500 = false,
    Fish501 = false,
    Fish503 = false,
    Fish504 = false,
    Fish505 = false,
    Fish508 = false,
    Fish510 = false,
}

-- Per ikan toggle ESP (default false semua)
local espIllahiFishEnabled = {
    Fish400 = false,
    Fish401 = false,
    Fish402 = false,
    Fish403 = false,
    Fish404 = false,
    Fish405 = false,
}

local espSecretFishEnabled = {
    Fish500 = false,
    Fish501 = false,
    Fish503 = false,
    Fish504 = false,
    Fish505 = false,
    Fish508 = false,
    Fish510 = false,
}

------------------- ESP DATA STRUCT -------------------
local trackedFishEspTargets = {} -- [part] = { fishId, fishType, displayName }
local fishEspMap    = {}        -- [part] = { beam, attachment, billboard, label, ... }
local hrpAttachment = nil

------------------- ESP HELPER -------------------
local function getHRP()
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function ensureHRPAttachment()
    local hrp = getHRP()
    if not hrp then
        hrpAttachment = nil
        return nil
    end

    if hrpAttachment and hrpAttachment.Parent == hrp then
        return hrpAttachment
    end

    local existing = hrp:FindFirstChild("AxaESP_HRP_Att")
    if existing and existing:IsA("Attachment") then
        hrpAttachment = existing
    else
        local att = Instance.new("Attachment")
        att.Name = "AxaESP_HRP_Att"
        att.Parent = hrp
        hrpAttachment = att
    end
    return hrpAttachment
end

local function destroyFishEsp(part)
    local data = fishEspMap[part]
    if not data then
        return
    end

    if data.beam then
        pcall(function()
            data.beam:Destroy()
        end)
    end

    if data.attachment and data.attachment.Parent then
        pcall(function()
            data.attachment:Destroy()
        end)
    end

    if data.billboard then
        pcall(function()
            data.billboard:Destroy()
        end)
    end

    fishEspMap[part] = nil
end

local function createEspInstancesForPart(part, displayName, fishType, fishId)
    local hrpAtt = ensureHRPAttachment()
    if not hrpAtt then
        return
    end
    if not part or not part:IsA("BasePart") then
        return
    end

    if fishEspMap[part] then
        return
    end

    local fishAttachment = part:FindFirstChild("AxaESP_Attachment")
    if not fishAttachment or not fishAttachment:IsA("Attachment") then
        fishAttachment = Instance.new("Attachment")
        fishAttachment.Name = "AxaESP_Attachment"
        fishAttachment.Parent = part
    end

    local beam = Instance.new("Beam")
    beam.Name = "AxaESP_Beam"
    beam.Attachment0 = hrpAtt
    beam.Attachment1 = fishAttachment
    beam.FaceCamera = true
    beam.Width0 = 0.12
    beam.Width1 = 0.12
    beam.Segments = 10
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Transparency = NumberSequence.new(0)
    beam.Parent = part

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AxaESP_Billboard"
    billboard.Size = UDim2.new(0, 160, 0, 24)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Parent = billboard
    label.BackgroundTransparency = 0.25
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.BorderSizePixel = 0
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(255, 255, 0)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextWrapped = true
    label.Text = displayName or "Fish"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    fishEspMap[part] = {
        beam        = beam,
        attachment  = fishAttachment,
        billboard   = billboard,
        label       = label,
        displayName = displayName or "Fish",
        fishType    = fishType,
        fishId      = fishId,
    }
end

local function evaluateEspForPart(part)
    local info = trackedFishEspTargets[part]
    if not info or not part or part.Parent == nil then
        destroyFishEsp(part)
        trackedFishEspTargets[part] = nil
        return
    end

    local should = false

    if info.fishType == "Boss" then
        should = espBoss
    elseif info.fishType == "Illahi" then
        -- Illahi = Divine, mengikuti toggle global + per ikan
        if espIllahi and espIllahiFishEnabled[info.fishId] == true then
            should = true
        end
    elseif info.fishType == "Secret" then
        if espSecret and espSecretFishEnabled[info.fishId] == true then
            should = true
        end
    end

    if not should then
        destroyFishEsp(part)
        return
    end

    if not fishEspMap[part] then
        createEspInstancesForPart(part, info.displayName, info.fishType, info.fishId)
    end
end

local function refreshAllEsp()
    for part, _ in pairs(fishEspMap) do
        destroyFishEsp(part)
    end
    for part, _ in pairs(trackedFishEspTargets) do
        evaluateEspForPart(part)
    end
end

local function registerFishPartForEsp(part, fishId, fishType, displayName)
    if not part or not part:IsA("BasePart") then
        return
    end

    trackedFishEspTargets[part] = {
        fishId      = fishId,
        fishType    = fishType,
        displayName = displayName or fishId or "Fish",
    }

    evaluateEspForPart(part)

    local conn = part.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            trackedFishEspTargets[part] = nil
            destroyFishEsp(part)
        end
    end)
    table.insert(connections, conn)
end

local function updateEspTextDistances()
    if not next(fishEspMap) then
        return
    end

    local hrp = getHRP()
    if not hrp then
        return
    end
    local hrpPos = hrp.Position

    for part, data in pairs(fishEspMap) do
        if not part or part.Parent == nil then
            destroyFishEsp(part)
        else
            local ok, dist = pcall(function()
                return (part.Position - hrpPos).Magnitude
            end)
            if ok and data.label then
                local nameText = data.displayName or "Fish"
                local d = math.floor(dist or 0)
                data.label.Text = string.format("%s | %d studs", nameText, d)
            end
        end
    end
end

------------------- TOOL / HARPOON DETECTION -------------------
local function isHarpoonTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return tool.Name:match("^Harpoon(%d+)$") ~= nil
end

local function getEquippedHarpoonTool()
    if not character then return nil end
    for _, child in ipairs(character:GetChildren()) do
        if isHarpoonTool(child) then
            return child
        end
    end
    return nil
end

local function getBestHarpoonTool()
    local bestTool, bestRank

    local function scanContainer(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if isHarpoonTool(tool) then
                local num = tonumber(tool.Name:match("^Harpoon(%d+)$")) or 0
                if (not bestRank) or num > bestRank then
                    bestRank = num
                    bestTool = tool
                end
            end
        end
    end

    scanContainer(character)
    scanContainer(backpack)

    return bestTool
end

local function isToolOwnedGeneric(id)
    if ToolsData and ToolsData:FindFirstChild(id) then
        return true
    end

    local function hasIn(container)
        if not container then return false end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == id then
                return true
            end
        end
        return false
    end

    if hasIn(character) or hasIn(backpack) then
        return true
    end

    return false
end

local function isHarpoonOwned(id)
    return isToolOwnedGeneric(id)
end

------------------- UI HELPERS -------------------
local harpoonCardsById = {}

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
    title.Text = "Spear Fish Misc V1.3"

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
    subtitle.Text = "Auto Skill + Notif Spawn Boss & HP + ESP Fish + Buy Harpoon."

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
    padding.PaddingLeft = UDim.new(0, 0)
    padding.PaddingRight = UDim.new(0, 0)

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
    height = height or 140

    local card = Instance.new("Frame")
    card.Name = (titleText or "Card")
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
        subtitle.Size = UDim2.new(1, 0, 0, 30) -- cukup tinggi supaya tidak tertimpa
    end

    return card
end

local function setToggleButtonState(button, labelText, state)
    if not button then
        return
    end
    labelText = labelText or "Toggle"
    if state then
        button.Text = labelText .. ": ON"
        button.BackgroundColor3 = Color3.fromRGB(45, 120, 75)
    else
        button.Text = labelText .. ": OFF"
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end
end

local function createToggleButton(parent, labelText, initialState)
    local button = Instance.new("TextButton")
    button.Name = (labelText or "Toggle"):gsub("%s+", "") .. "Button"
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.TextXAlignment = Enum.TextXAlignment.Center
    button.TextYAlignment = Enum.TextYAlignment.Center
    button.Size = UDim2.new(1, 0, 0, 30)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local function update(state)
        setToggleButtonState(button, labelText, state)
    end

    update(initialState)

    return button, update
end

------------------- AUTO SKILL 1 ~ 5 -------------------
local function fireSkill(id)
    if not alive or not FishRE then
        return
    end
    if not id or id == "" then
        return
    end
    local args = {
        [1] = "Skill",
        [2] = {
            ["ID"] = id
        }
    }
    local ok, err = pcall(function()
        FishRE:FireServer(unpack(args))
    end)
    if not ok then
        warn("[SpearFishing] Auto Skill gagal:", id, err)
    end
end

local function fireSkill1()
    if not autoSkill1 then return end
    fireSkill(autoSkill1Id or "Skill04")
end

local function fireSkill2()
    if not autoSkill2 then return end
    fireSkill(autoSkill2Id or "Skill02")
end

local function fireSkill3()
    if not autoSkill3 then return end
    fireSkill(autoSkill3Id or "Skill08")
end

local function fireSkill4()
    if not autoSkill4 then return end
    fireSkill(autoSkill4Id or "Skill01")
end

local function fireSkill5()
    if not autoSkill5 then return end
    fireSkill(autoSkill5Id or "Skill07")
end

------------------- SPAWN BOSS / HP BOSS / CLIMATE WEBHOOK CORE -------------------
local SPAWN_BOSS_WEBHOOK_URL   = "https://discord.com/api/webhooks/1435079884073341050/vEy2YQrpQQcN7pMs7isWqPtylN_AyJbzCAo_xDqM7enRacbIBp43SG1IR_hH-3j4zrfW"
local SPAWN_BOSS_BOT_USERNAME  = "Spawn Boss Notifier"
local SPAWN_BOSS_BOT_AVATAR    = "https://i.postimg.cc/tRVDMbPy/Ex-Logo2.png"
local DEFAULT_OWNER_DISCORD    = "<@1403052152691101857>"

local HP_BOSS_WEBHOOK_URL      = "https://discord.com/api/webhooks/1456150372686237849/NTDxNaXWeJ1ytvzTo9vnmG5Qvbl6gsvZor4MMb9rWUwKT4fFkRQ9NbNiPsy7-TWogTmR"
local HP_BOSS_BOT_USERNAME     = "HP Boss Notifier"

local CLIMATE_WEBHOOK_URL      = "https://discord.com/api/webhooks/1456868357138681938/-3FnsflNnf9z3tm2RQvsqbBHKoLjlgQxsTF1KVsTkBEmYd6sYRWr-bQndJQSG2Y0hWNf"
local CLIMATE_BOT_USERNAME     = "Climate Notifier"

-- Bot publik jika user mengisi webhook sendiri
local PUBLIC_WEBHOOK_BOT_USERNAME = "ExHub Notifier"
local PUBLIC_WEBHOOK_BOT_AVATAR   = SPAWN_BOSS_BOT_AVATAR

local BOSS_ID_NAME_MAP = {
    Boss01 = "Humpback Whale",
    Boss02 = "Whale Shark",
    Boss03 = "Crimson Rift Dragon",
}

local NEAR_REMAIN_THRESHOLD = 240

local bossRegionState        = {}
local hpRegionState          = {}
local spawnBossRequestFunc   = nil

local function getSpawnBossRequestFunc()
    if spawnBossRequestFunc then
        return spawnBossRequestFunc
    end

    if syn and syn.request then
        spawnBossRequestFunc = syn.request
    elseif http and http.request then
        spawnBossRequestFunc = http.request
    elseif http_request then
        spawnBossRequestFunc = http_request
    elseif request then
        spawnBossRequestFunc = request
    end

    return spawnBossRequestFunc
end

local function sendWebhookGeneric(url, username, avatar, embed)
    if not url or url == "" then
        return
    end

    local payload = {
        username   = username,
        avatar_url = avatar,
        --content    = DEFAULT_OWNER_DISCORD,
        embeds     = { embed },
    }

    local encoded
    local okEncode, resEncode = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if okEncode then
        encoded = resEncode
    else
        warn("[SpearFishing] JSONEncode failed:", resEncode)
        return
    end

    local reqFunc = getSpawnBossRequestFunc()
    if reqFunc then
        local okReq, resReq = pcall(reqFunc, {
            Url     = url,
            Method  = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body    = encoded,
        })
        if not okReq then
            warn("[SpearFishing] webhook request failed:", resReq)
        end
    else
        local okPost, errPost = pcall(function()
            HttpService:PostAsync(url, encoded, Enum.HttpContentType.ApplicationJson, false)
        end)
        if not okPost then
            warn("[SpearFishing] HttpService PostAsync failed:", errPost)
        end
    end
end

local function sendSpawnBossWebhookEmbed(embed)
    -- selalu kirim ke webhook default owner
    sendWebhookGeneric(SPAWN_BOSS_WEBHOOK_URL, SPAWN_BOSS_BOT_USERNAME, SPAWN_BOSS_BOT_AVATAR, embed)

    -- jika user isi webhook publik, kirim salinan embed ke sana juga
    local publicUrl = getUserWebhookTrimmed()
    if publicUrl then
        sendWebhookGeneric(publicUrl, PUBLIC_WEBHOOK_BOT_USERNAME, PUBLIC_WEBHOOK_BOT_AVATAR, embed)
    end
end

local function sendHpBossWebhookEmbed(embed)
    -- selalu kirim ke webhook default HP Boss
    sendWebhookGeneric(HP_BOSS_WEBHOOK_URL, HP_BOSS_BOT_USERNAME, SPAWN_BOSS_BOT_AVATAR, embed)

    -- jika user isi webhook publik, kirim salinan embed ke sana juga
    local publicUrl = getUserWebhookTrimmed()
    if publicUrl then
        sendWebhookGeneric(publicUrl, PUBLIC_WEBHOOK_BOT_USERNAME, PUBLIC_WEBHOOK_BOT_AVATAR, embed)
    end
end

------------------- BOSS / HP HELPERS -------------------
local function getRegionNameForBoss(region)
    if not region or not region.Name then
        return "Unknown"
    end

    local attrName = region:GetAttribute("RegionName")
    if type(attrName) == "string" and attrName ~= "" then
        return attrName
    end

    return region.Name
end

local function getBossNameForRegion(region)
    if not region then
        return "Unknown Boss"
    end

    for id, display in pairs(BOSS_ID_NAME_MAP) do
        local found = region:FindFirstChild(id, true)
        if found then
            return display
        end
    end

    if FishUtil and ItemUtil then
        local okDesc, descendants = pcall(function()
            return region:GetDescendants()
        end)
        if okDesc and descendants then
            for _, inst in ipairs(descendants) do
                if inst:IsA("BasePart") then
                    local okFish, isFish = pcall(function()
                        return FishUtil:isFish(inst)
                    end)
                    if okFish and isFish then
                        local fishId = inst.Name
                        if BOSS_ID_NAME_MAP[fishId] then
                            return BOSS_ID_NAME_MAP[fishId]
                        end
                        local okName, niceName = pcall(function()
                            return ItemUtil:getName(fishId)
                        end)
                        if okName and type(niceName) == "string" and niceName ~= "" then
                            return niceName
                        end
                    end
                end
            end
        end
    end

    return "Unknown Boss"
end

local function formatBossRemainingText(remainSeconds)
    remainSeconds = tonumber(remainSeconds) or 0
    if remainSeconds < 0 then
        remainSeconds = 0
    end

    local mmss
    if MathUtil then
        local okFmt, res = pcall(function()
            return MathUtil:secondsToMMSS(remainSeconds)
        end)
        if okFmt and type(res) == "string" and res ~= "" then
            mmss = res
        end
    end

    if not mmss then
        local total = math.floor(remainSeconds + 0.5)
        local m = math.floor(total / 60)
        local s = total % 60
        mmss = string.format("%02d:%02d", m, s)
    end

    return "Time Now: Guranteed Divine Boss In " .. mmss .. " menit"
end

local function buildSpawnBossEmbed(region, stageKey, remainSeconds, bossName)
    local remainingText

    if stageKey == "spawn" then
        remainingText = "Time Now: Guranteed Divine Boss In 00:00 menit"
    else
        remainingText = formatBossRemainingText(remainSeconds)
    end

    bossName = bossName or "Unknown Boss"

    local regionName = getRegionNameForBoss(region)

    local stageText
    local colorInt

    if stageKey == "start" then
        stageText = "Timer mulai"
        colorInt  = 0x00BFFF
    elseif stageKey == "near" then
        stageText = "Sisa waktu 3-4 menit"
        colorInt  = 0xFFA500
    elseif stageKey == "spawn" then
        stageText = "Boss Spawned"
        colorInt  = 0xFF0000
    else
        stageText = tostring(stageKey)
        colorInt  = 0xFFFFFF
    end

    local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
    local username    = LocalPlayer.Name or "Player"
    local userId      = LocalPlayer.UserId or 0

    local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))
    local serverId = game.JobId
    if not serverId or serverId == "" then
        serverId = "N/A"
    end

    local embed = {
        title       = "Spawn Boss",
        --description = DEFAULT_OWNER_DISCORD,
        color       = colorInt,
        fields      = {
            {
                name   = "Remaining Time",
                value  = remainingText,
                inline = false,
            },
            {
                name   = "Name Boss",
                value  = bossName,
                inline = true,
            },
            {
                name   = "Region",
                value  = regionName,
                inline = true,
            },
            {
                name   = "Stage",
                value  = stageText,
                inline = false,
            },
            {
                name   = "Name Map",
                value  = GAME_NAME,
                inline = false,
            },
            {
                name   = "Player",
                value  = playerValue,
                inline = false,
            },
            {
                name   = "Server ID",
                value  = serverId,
                inline = false,
            },
        },
        footer = {
            text = "Spear Fishing PRO+",
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    }

    return embed
end

local function buildHpBossEmbed(region, bossName, curHpText, maxHpText, percentText)
    bossName    = bossName or "Unknown Boss"
    curHpText   = curHpText or "0"
    maxHpText   = maxHpText or "0"
    percentText = percentText or "0%"

    local regionName = getRegionNameForBoss(region)

    local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
    local username    = LocalPlayer.Name or "Player"
    local userId      = LocalPlayer.UserId or 0
    local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

    local serverId = game.JobId
    if not serverId or serverId == "" then
        serverId = "N/A"
    end

    local description = string.format(
        "%s\nHP %s: %s / %s (%s)",
        --DEFAULT_OWNER_DISCORD,
        bossName,
        curHpText,
        maxHpText,
        percentText
    )

    local embed = {
        title       = "HP Boss",
        description = description,
        color       = 0x00FF00,
        fields      = {
            {
                name   = "Boss",
                value  = bossName,
                inline = true,
            },
            {
                name   = "HP",
                value  = curHpText .. " / " .. maxHpText,
                inline = true,
            },
            {
                name   = "HP Percent",
                value  = percentText,
                inline = true,
            },
            {
                name   = "Region",
                value  = regionName,
                inline = true,
            },
            {
                name   = "Name Map",
                value  = GAME_NAME,
                inline = false,
            },
            {
                name   = "Player",
                value  = playerValue,
                inline = false,
            },
            {
                name   = "Server ID",
                value  = serverId,
                inline = false,
            },
        },
        footer = {
            text = "Spear Fishing PRO+ | HP Boss Notifier",
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    }

    return embed
end

local function sendSpawnBossStage(region, stageKey, remainSeconds)
    if not alive or not spawnBossNotifier then
        return
    end

    local bossName
    if stageKey == "spawn" then
        bossName = getBossNameForRegion(region)
    else
        bossName = "Unknown Boss"
    end

    local embed = buildSpawnBossEmbed(region, stageKey, remainSeconds, bossName)
    sendSpawnBossWebhookEmbed(embed)
end

local function getBossPartInRegion(region)
    if not region then
        return nil
    end

    local okDesc, descendants = pcall(function()
        return region:GetDescendants()
    end)
    if not okDesc or not descendants then
        return nil
    end

    if FishUtil then
        for _, inst in ipairs(descendants) do
            if inst:IsA("BasePart") then
                local okFish, isFish = pcall(function()
                    return FishUtil:isFish(inst)
                end)
                if okFish and isFish then
                    local hpAttr = inst:GetAttribute("CurHP") or inst:GetAttribute("CurHp") or inst:GetAttribute("HP") or inst:GetAttribute("Hp")
                    if hpAttr ~= nil then
                        return inst
                    end
                end
            end
        end
    end

    for _, inst in ipairs(descendants) do
        if inst:IsA("BasePart") then
            local hpAttr = inst:GetAttribute("CurHP") or inst:GetAttribute("CurHp") or inst:GetAttribute("HP") or inst:GetAttribute("Hp")
            if hpAttr ~= nil then
                return inst
            end
        end
    end

    return nil
end

local function detachHpWatcher(region)
    local state = hpRegionState[region]
    if not state then
        return
    end

    local function safeDisc(conn)
        if conn and conn.Disconnect then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end

    safeDisc(state.conn)
    safeDisc(state.connCurHP)
    safeDisc(state.connHP)
    safeDisc(state.connHp)

    hpRegionState[region] = nil
end

local HP_SEND_MIN_INTERVAL = 1.5
local HP_MIN_DELTA_RATIO   = 0.005

local function sendHpBossProgress(region, bossPart)
    if not alive then
        return
    end

    local state = hpRegionState[region]
    if not state or state.bossPart ~= bossPart then
        return
    end

    local rawCur = bossPart:GetAttribute("CurHP") or bossPart:GetAttribute("CurHp")
    local rawMax = bossPart:GetAttribute("HP")   or bossPart:GetAttribute("Hp")

    if rawCur == nil and rawMax ~= nil then
        rawCur = rawMax
    elseif rawCur ~= nil and rawMax == nil then
        rawMax = rawCur
    end

    local curHp   = tonumber(rawCur or 0) or 0
    local totalHp = tonumber(rawMax or 0) or 0
    if totalHp <= 0 then
        totalHp = curHp
    end

    if totalHp <= 0 and curHp <= 0 then
        detachHpWatcher(region)
        return
    end

    local now      = os.clock()
    local lastHp   = state.lastHp
    local lastSend = state.lastSendTime or 0

    local changed
    if lastHp == nil then
        changed = true
    else
        changed = (curHp ~= lastHp)
    end

    if not changed then
        return
    end

    local dropRatio = 0
    if totalHp > 0 and lastHp ~= nil and lastHp > 0 then
        dropRatio = math.abs(curHp - lastHp) / totalHp
    end

    if not hpBossNotifier then
        state.lastHp = curHp
        return
    end

    local mustSend = false

    if lastHp == nil then
        mustSend = true
    elseif curHp <= 0 and lastHp > 0 then
        mustSend = true
    elseif (now - lastSend) >= HP_SEND_MIN_INTERVAL and dropRatio >= HP_MIN_DELTA_RATIO then
        mustSend = true
    elseif (now - lastSend) >= 5 then
        mustSend = true
    end

    state.lastHp = curHp
    if not mustSend then
        return
    end
    state.lastSendTime = now

    local curText   = tostring(curHp)
    local maxText   = tostring(totalHp)
    if FormatUtil then
        local ok1, res1 = pcall(function()
            return FormatUtil:DesignNumberShort(curHp)
        end)
        if ok1 and res1 then
            curText = res1
        end

        local ok2, res2 = pcall(function()
            return FormatUtil:DesignNumberShort(totalHp)
        end)
        if ok2 and res2 then
            maxText = res2
        end
    end

    local percentText = "N/A"
    if totalHp > 0 then
        local percent = math.max(0, math.min(1, curHp / totalHp)) * 100
        percentText = string.format("%.2f%%", percent)
    end

    local bossName = getBossNameForRegion(region)
    local embed    = buildHpBossEmbed(region, bossName, curText, maxText, percentText)
    sendHpBossWebhookEmbed(embed)

    if curHp <= 0 then
        detachHpWatcher(region)
    end
end

local function attachHpWatcher(region)
    if not region then
        return
    end

    local hasBoss = region:GetAttribute("HasBoss")
    if not hasBoss then
        detachHpWatcher(region)
        return
    end

    local bossPart = getBossPartInRegion(region)
    if not bossPart then
        return
    end

    local bossName = getBossNameForRegion(region)
    registerFishPartForEsp(bossPart, bossPart.Name or "Boss", "Boss", bossName)

    local state = hpRegionState[region]
    if state and state.bossPart == bossPart and (state.conn or state.connCurHP or state.connHP or state.connHp) then
        return
    end

    detachHpWatcher(region)

    state = {
        bossPart     = bossPart,
        lastHp       = nil,
        lastSendTime = 0,
        conn         = nil,
        connCurHP    = nil,
        connHP       = nil,
        connHp       = nil,
    }
    hpRegionState[region] = state

    local function onHpAttributeChanged()
        if not alive then return end
        sendHpBossProgress(region, bossPart)
    end

    local connCur = bossPart:GetAttributeChangedSignal("CurHP"):Connect(onHpAttributeChanged)
    state.connCurHP = connCur
    table.insert(connections, connCur)

    local connCur2 = bossPart:GetAttributeChangedSignal("CurHp"):Connect(onHpAttributeChanged)
    state.conn = connCur2
    table.insert(connections, connCur2)

    local connHP = bossPart:GetAttributeChangedSignal("HP"):Connect(onHpAttributeChanged)
    state.connHP = connHP
    table.insert(connections, connHP)

    local connHp = bossPart:GetAttributeChangedSignal("Hp"):Connect(onHpAttributeChanged)
    state.connHp = connHp
    table.insert(connections, connHp)

    task.spawn(function()
        sendHpBossProgress(region, bossPart)
    end)
end

local function updateWorldBossRegion(region)
    if not region then
        return
    end

    local state = bossRegionState[region]
    if not state then
        state = {
            sentStart = false,
            sentNear  = false,
            sentSpawn = false,
        }
        bossRegionState[region] = state
    end

    local hasBoss   = region:GetAttribute("HasBoss")
    local remainRaw = region:GetAttribute("RemainTime")
    local remain    = tonumber(remainRaw) or 0

    if not hasBoss and remain <= 0 then
        state.sentStart = false
        state.sentNear  = false
        state.sentSpawn = false
    end

    if remain > 0 and not hasBoss and not state.sentStart then
        state.sentStart = true
        task.spawn(function()
            sendSpawnBossStage(region, "start", remain)
        end)
    end

    if remain > 0
        and remain <= NEAR_REMAIN_THRESHOLD
        and remain >= 180
        and state.sentStart
        and not state.sentNear
    then
        state.sentNear = true
        task.spawn(function()
            sendSpawnBossStage(region, "near", remain)
        end)
    end

    if hasBoss and not state.sentSpawn then
        state.sentSpawn = true
        task.spawn(function()
            sendSpawnBossStage(region, "spawn", remain)
        end)
    end
end

local function registerWorldBossRegion(region)
    if not region then
        return
    end

    task.spawn(function()
        updateWorldBossRegion(region)
        attachHpWatcher(region)
    end)

    table.insert(connections, region:GetAttributeChangedSignal("HasBoss"):Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
        local hasBoss = region:GetAttribute("HasBoss")
        if hasBoss then
            attachHpWatcher(region)
        else
            detachHpWatcher(region)
        end
    end))

    table.insert(connections, region:GetAttributeChangedSignal("RemainTime"):Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
    end))

    table.insert(connections, region:GetAttributeChangedSignal("NextSpawnTime"):Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
    end))

    table.insert(connections, region.ChildAdded:Connect(function()
        if not alive then return end
        updateWorldBossRegion(region)
        attachHpWatcher(region)
    end))
end

local function initWorldBossNotifier()
    task.spawn(function()
        task.wait(5)
        if not alive then
            return
        end

        local worldBossFolder = workspace:FindFirstChild("WorldBoss")
        if not worldBossFolder then
            local okWait, inst = pcall(function()
                return workspace:WaitForChild("WorldBoss", 10)
            end)
            if okWait and inst then
                worldBossFolder = inst
            end
        end

        if not worldBossFolder then
            warn("[SpearFishing] WorldBoss folder tidak ditemukan, Spawn/HP Boss Notifier idle.")
            return
        end

        for _, child in ipairs(worldBossFolder:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then
                registerWorldBossRegion(child)
            end
        end

        table.insert(connections, worldBossFolder.ChildAdded:Connect(function(child)
            if not alive then return end
            if child:IsA("BasePart") or child:IsA("Model") then
                registerWorldBossRegion(child)
            end
        end))
    end)
end

------------------- SPAWN DIVINE (ILLAHI) NOTIFIER -------------------
local function initIllahiSpawnNotifier()
    task.spawn(function()
        task.wait(3)
        if not alive then
            return
        end

        local WEBHOOK_URL = "https://discord.com/api/webhooks/1456157133325209764/ymVmoJR0gV21o_IpvCn6sj2jR31TqZPnWMem7jEmxZLt_Pn__7j1cdsqna1u1mBq7yWz"
        local BOT_USERNAME = "Spawn Divine Notifier"

        local function sendDivineWebhookEmbed(embed)
            -- selalu kirim ke webhook default Divine
            sendWebhookGeneric(WEBHOOK_URL, BOT_USERNAME, SPAWN_BOSS_BOT_AVATAR, embed)

            -- jika user isi webhook publik, kirim salinan embed ke sana juga
            local publicUrl = getUserWebhookTrimmed()
            if publicUrl then
                sendWebhookGeneric(publicUrl, PUBLIC_WEBHOOK_BOT_USERNAME, PUBLIC_WEBHOOK_BOT_AVATAR, embed)
            end
        end

        local function buildDivineSpawnEmbed(region, fishId, fishName)
            local regionName = getRegionNameForBoss(region)
            local islandName = "Nether Island"

            local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
            local username    = LocalPlayer.Name or "Player"
            local userId      = LocalPlayer.UserId or 0
            local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

            local serverId = game.JobId
            if not serverId or serverId == "" then
                serverId = "N/A"
            end

            local fishLabel = fishName or "Unknown"
            if fishId and fishId ~= "" then
                fishLabel = fishLabel .. " (" .. tostring(fishId) .. ")"
            end

            local embed = {
                title       = "Spawn Divine",
                --description = DEFAULT_OWNER_DISCORD,
                color       = 0x9400D3,
                fields      = {
                    {
                        name   = "Divine Fish",
                        value  = fishLabel,
                        inline = true,
                    },
                    {
                        name   = "Sea",
                        value  = regionName,
                        inline = true,
                    },
                    {
                        name   = "Island",
                        value  = islandName,
                        inline = true,
                    },
                    {
                        name   = "Name Map",
                        value  = GAME_NAME,
                        inline = false,
                    },
                    {
                        name   = "Player",
                        value  = playerValue,
                        inline = false,
                    },
                    {
                        name   = "Server ID",
                        value  = serverId,
                        inline = false,
                    },
                },
                footer = {
                    text = "Spear Fishing PRO+ | Spawn Divine Notifier",
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            }

            return embed
        end

        local function handleDivineFish(region, fishPart)
            if not fishPart or not fishPart.Name then
                return
            end

            local def = ILLAHI_FISH_DEFS[fishPart.Name]
            if not def then
                return
            end

            registerFishPartForEsp(fishPart, fishPart.Name, "Illahi", def.name)

            if not alive then
                return
            end
            if not spawnIllahiNotifier then
                return
            end
            if illahiFishEnabled[fishPart.Name] == false then
                return
            end

            local fishName = def.name or fishPart.Name
            local embed = buildDivineSpawnEmbed(region, fishPart.Name, fishName)
            sendDivineWebhookEmbed(embed)
        end

        local function registerDivineRegion(region)
            if not region or not region.Name then
                return
            end
            if not ILLAHI_SEA_SET[region.Name] then
                return
            end
            if not (region:IsA("BasePart") or region:IsA("Model")) then
                return
            end

            local function checkChild(child)
                if not child or not child.Name then
                    return
                end
                if not child:IsA("BasePart") then
                    return
                end
                if ILLAHI_FISH_DEFS[child.Name] then
                    handleDivineFish(region, child)
                end
            end

            for _, child in ipairs(region:GetChildren()) do
                checkChild(child)
            end

            table.insert(connections, region.ChildAdded:Connect(function(child)
                if not alive then return end
                checkChild(child)
            end))
        end

        local worldSea = workspace:FindFirstChild("WorldSea")
        if not worldSea then
            local okWait, inst = pcall(function()
                return workspace:WaitForChild("WorldSea", 10)
            end)
            if okWait and inst then
                worldSea = inst
            end
        end

        if not worldSea then
            warn("[SpearFishing] WorldSea folder tidak ditemukan, Spawn Divine Notifier idle.")
            return
        end

        for _, child in ipairs(worldSea:GetChildren()) do
            registerDivineRegion(child)
        end

        table.insert(connections, worldSea.ChildAdded:Connect(function(child)
            if not alive then return end
            registerDivineRegion(child)
        end))
    end)
end

------------------- SPAWN SECRET NOTIFIER -------------------
local function initSecretSpawnNotifier()
    task.spawn(function()
        task.wait(3)
        if not alive then
            return
        end

        local WEBHOOK_URL = "https://discord.com/api/webhooks/1456257955682062367/UKn20-hMHwtjd0BNsoH_aV_f30V7jlkTux2QNlwnb259BEEbabIifrYinj1I7XPK_0xK"
        local BOT_USERNAME = "Spawn Secret Notifier"

        local function sendSecretWebhookEmbed(embed)
            -- selalu kirim ke webhook default Secret
            sendWebhookGeneric(WEBHOOK_URL, BOT_USERNAME, SPAWN_BOSS_BOT_AVATAR, embed)

            -- jika user isi webhook publik, kirim salinan embed ke sana juga
            local publicUrl = getUserWebhookTrimmed()
            if publicUrl then
                sendWebhookGeneric(publicUrl, PUBLIC_WEBHOOK_BOT_USERNAME, PUBLIC_WEBHOOK_BOT_AVATAR, embed)
            end
        end

        local function buildSecretSpawnEmbed(region, fishId, fishName)
            local regionName = getRegionNameForBoss(region)
            local islandName = "Nether Island"

            local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
            local username    = LocalPlayer.Name or "Player"
            local userId      = LocalPlayer.UserId or 0
            local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

            local serverId = game.JobId
            if not serverId or serverId == "" then
                serverId = "N/A"
            end

            local fishLabel = fishName or "Unknown"
            if fishId and fishId ~= "" then
                fishLabel = fishLabel .. " (" .. tostring(fishId) .. ")"
            end

            local embed = {
                title       = "Spawn Secret",
                --description = DEFAULT_OWNER_DISCORD,
                color       = 0xFFD700,
                fields      = {
                    {
                        name   = "Secret Fish",
                        value  = fishLabel,
                        inline = true,
                    },
                    {
                        name   = "Sea",
                        value  = regionName,
                        inline = true,
                    },
                    {
                        name   = "Island",
                        value  = islandName,
                        inline = true,
                    },
                    {
                        name   = "Name Map",
                        value  = GAME_NAME,
                        inline = false,
                    },
                    {
                        name   = "Player",
                        value  = playerValue,
                        inline = false,
                    },
                    {
                        name   = "Server ID",
                        value  = serverId,
                        inline = false,
                    },
                },
                footer = {
                    text = "Spear Fishing PRO+ | Spawn Secret Notifier",
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            }

            return embed
        end

        local function handleSecretFish(region, fishPart)
            if not fishPart or not fishPart.Name then
                return
            end

            local def = SECRET_FISH_DEFS[fishPart.Name]
            if not def then
                return
            end

            registerFishPartForEsp(fishPart, fishPart.Name, "Secret", def.name)

            if not alive then
                return
            end
            if not spawnSecretNotifier then
                return
            end
            if secretFishEnabled[fishPart.Name] ~= true then
                return
            end

            local fishName = def.name or fishPart.Name
            local embed = buildSecretSpawnEmbed(region, fishPart.Name, fishName)
            sendSecretWebhookEmbed(embed)
        end

        local function registerSecretRegion(region)
            if not region or not region.Name then
                return
            end
            if not SECRET_SEA_SET[region.Name] then
                return
            end
            if not (region:IsA("BasePart") or region:IsA("Model")) then
                return
            end

            local function checkChild(child)
                if not child or not child.Name then
                    return
                end
                if not child:IsA("BasePart") then
                    return
                end
                if SECRET_FISH_DEFS[child.Name] then
                    handleSecretFish(region, child)
                end
            end

            for _, child in ipairs(region:GetChildren()) do
                checkChild(child)
            end

            table.insert(connections, region.ChildAdded:Connect(function(child)
                if not alive then return end
                checkChild(child)
            end))
        end

        local worldSea = workspace:FindFirstChild("WorldSea")
        if not worldSea then
            local okWait, inst = pcall(function()
                return workspace:WaitForChild("WorldSea", 10)
            end)
            if okWait and inst then
                worldSea = inst
            end
        end

        if not worldSea then
            warn("[SpearFishing] WorldSea folder tidak ditemukan, Spawn Secret Notifier idle.")
            return
        end

        for _, child in ipairs(worldSea:GetChildren()) do
            registerSecretRegion(child)
        end

        table.insert(connections, worldSea.ChildAdded:Connect(function(child)
            if not alive then return end
            registerSecretRegion(child)
        end))
    end)
end

------------------- CLIMATE TIME NOTIFIER -------------------
local function initClimateTimeNotifier()
    task.spawn(function()
        task.wait(3)
        if not alive then
            return
        end

        local repMgr = RepMgr
        if not repMgr then
            repMgr = safeRequire(UtilityFolder, "RepMgr")
        end
        if not repMgr then
            warn("[SpearFishing] RepMgr module tidak ditemukan, Climate Time Notifier idle.")
            return
        end

        local climateTimeParam
        local climateParam

        local okTime, resTime = pcall(function()
            return repMgr:GetParameterTarget("CurrentClimateTime")
        end)
        if okTime and resTime then
            climateTimeParam = resTime
        end

        local okClimate, resClimate = pcall(function()
            return repMgr:GetParameterTarget("CurrentClimate")
        end)
        if okClimate and resClimate then
            climateParam = resClimate
        end

        if not climateParam then
            warn("[SpearFishing] Parameter CurrentClimate tidak ditemukan, Climate Time Notifier idle.")
            return
        end

        local function getRemainSeconds()
            if not climateTimeParam then
                return 0
            end
            local ok, val = pcall(function()
                return climateTimeParam.Value
            end)
            if ok and type(val) == "number" then
                return val
            end
            return 0
        end

        local function formatRemainText(sec)
            sec = tonumber(sec) or 0
            if sec < 0 then
                sec = 0
            end

            if MathUtil then
                local okFmt, resFmt = pcall(function()
                    return MathUtil:secondsToMMSS(sec)
                end)
                if okFmt and type(resFmt) == "string" and resFmt ~= "" then
                    return resFmt
                end
            end

            local total = math.floor(sec + 0.5)
            local m = math.floor(total / 60)
            local s = total % 60
            return string.format("%02d:%02d", m, s)
        end

        local function sendClimateWebhook(climateId)
            if not alive then
                return
            end
            if not climateTimeNotifier then
                return
            end

            climateId = climateId or climateParam.Value
            if not climateId or climateId == "" then
                return
            end

            local remainSec  = getRemainSeconds()
            local remainText = formatRemainText(remainSec)

            local climateName = climateId
            if ItemUtil then
                local okName, resName = pcall(function()
                    return ItemUtil:getName(climateId)
                end)
                if okName and type(resName) == "string" and resName ~= "" then
                    climateName = resName
                end
            end

            local displayName = LocalPlayer.DisplayName or LocalPlayer.Name or "Player"
            local username    = LocalPlayer.Name or "Player"
            local userId      = LocalPlayer.UserId or 0
            local playerValue = string.format("%s (@%s) [%s]", tostring(displayName), tostring(username), tostring(userId))

            local serverId = game.JobId
            if not serverId or serverId == "" then
                serverId = "N/A"
            end

            local embed = {
                title       = "Climate Time",
                --description = DEFAULT_OWNER_DISCORD,
                color       = 0x1E90FF,
                fields      = {
                    {
                        name   = "Climate",
                        value  = string.format("%s (%s)", climateName, tostring(climateId)),
                        inline = false,
                    },
                    {
                        name   = "Countdown",
                        value  = string.format("Next climate change in %s", remainText),
                        inline = false,
                    },
                    {
                        name   = "Name Map",
                        value  = GAME_NAME,
                        inline = false,
                    },
                    {
                        name   = "Player",
                        value  = playerValue,
                        inline = false,
                    },
                    {
                        name   = "Server ID",
                        value  = serverId,
                        inline = false,
                    },
                },
                footer = {
                    text = "Spear Fishing PRO+ | Climate Time Notifier",
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            }

            -- selalu kirim ke webhook default Climate
            sendWebhookGeneric(CLIMATE_WEBHOOK_URL, CLIMATE_BOT_USERNAME, SPAWN_BOSS_BOT_AVATAR, embed)

            -- jika user isi webhook publik, kirim salinan embed ke sana juga
            local publicUrl = getUserWebhookTrimmed()
            if publicUrl then
                sendWebhookGeneric(publicUrl, PUBLIC_WEBHOOK_BOT_USERNAME, PUBLIC_WEBHOOK_BOT_AVATAR, embed)
            end
        end

        local lastClimateId = nil

        local okInit, currentClimateId = pcall(function()
            return climateParam.Value
        end)
        if okInit and currentClimateId ~= nil then
            lastClimateId = currentClimateId
            -- kirim satu kali saat init untuk state climate sekarang
            sendClimateWebhook(currentClimateId)
        end

        table.insert(connections, climateParam.Changed:Connect(function(newId)
            if not alive then
                return
            end
            if newId == lastClimateId then
                return
            end
            lastClimateId = newId
            sendClimateWebhook(newId)
        end))
    end)
end

------------------- HARPOON SHOP: DATA & UI -------------------
local function getHarpoonDisplayData(id)
    local name      = id
    local icon      = ""
    local dmgMin    = "-"
    local dmgMax    = "-"
    local crt       = "-"
    local charge    = "-"
    local priceText = "N/A"
    local assetType = "Currency"

    if ItemUtil then
        local okName, resName = pcall(function()
            return ItemUtil:getName(id)
        end)
        if okName and resName then
            name = resName
        end

        local okIcon, resIcon = pcall(function()
            return ItemUtil:getIcon(id)
        end)
        if okIcon and resIcon then
            icon = resIcon
        end

        local okDef, def = pcall(function()
            return ItemUtil:GetDef(id)
        end)
        if okDef and def and def.AssetType then
            assetType = def.AssetType
        end

        local okPrice, priceVal = pcall(function()
            return ItemUtil:getPrice(id)
        end)
        if okPrice and priceVal then
            if FormatUtil then
                local okFmt, fmtText = pcall(function()
                    return FormatUtil:DesignNumberShort(priceVal)
                end)
                if okFmt and fmtText then
                    priceText = fmtText
                else
                    priceText = tostring(priceVal)
                end
            else
                priceText = tostring(priceVal)
            end
        end
    end

    if ToolUtil then
        local okDmg, minVal, maxVal = pcall(function()
            return ToolUtil:getHarpoonDMG(id)
        end)
        if okDmg and minVal and maxVal then
            dmgMin = tostring(minVal)
            dmgMax = tostring(maxVal)
        end

        local okCharge, chargeVal = pcall(function()
            return ToolUtil:getHarpoonChargeTime(id)
        end)
        if okCharge and chargeVal then
            charge = tostring(chargeVal) .. "s"
        end

        local okCRT, crtVal = pcall(function()
            return ToolUtil:getToolCRT(id)
        end)
        if okCRT and crtVal then
            crt = tostring(crtVal) .. "%"
        end
    end

    return {
        name      = name,
        icon      = icon,
        dmgMin    = dmgMin,
        dmgMax    = dmgMax,
        crt       = crt,
        charge    = charge,
        priceText = priceText,
        assetType = assetType,
    }
end

local function refreshHarpoonOwnership()
    for id, entry in pairs(harpoonCardsById) do
        local btn = entry.buyButton
        if btn then
            local owned = isHarpoonOwned(id)
            if owned then
                btn.Text = "Owned"
                btn.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
                btn.TextColor3 = Color3.fromRGB(230, 230, 230)
                btn.AutoButtonColor = false
            else
                btn.Text = "Buy"
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.TextColor3 = Color3.fromRGB(235, 235, 235)
                btn.AutoButtonColor = true
            end
        end
    end
end

local function buildHarpoonShopCard(parent)
    local card = createCard(
        parent,
        "Harpoon Shop",
        "Toko Harpoon (Image + DMG + CRT + Charge + Price).",
        4,
        280
    )

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "HarpoonScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 52)   -- mulai di bawah deskripsi (tidak tertimpa)
    scroll.Size = UDim2.new(1, 0, 1, -56)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    scroll.ScrollingDirection = Enum.ScrollingDirection.XY
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local padding = Instance.new("UIPadding")
    padding.Parent = scroll
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    for index, id in ipairs(HARPOON_IDS) do
        local data = getHarpoonDisplayData(id)

        local item = Instance.new("Frame")
        item.Name = id
        item.Parent = scroll
        item.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        item.Size = UDim2.new(0, 150, 0, 210)
        item.LayoutOrder = index

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70, 70, 70)
        stroke.Thickness = 1
        stroke.Parent = item

        local img = Instance.new("ImageLabel")
        img.Name = "Icon"
        img.Parent = item
        img.BackgroundTransparency = 1
        img.BorderSizePixel = 0
        img.Position = UDim2.new(0, 6, 0, 6)
        img.Size = UDim2.new(1, -12, 0, 70)
        img.Image = data.icon or ""
        img.ScaleType = Enum.ScaleType.Fit

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Parent = item
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        nameLabel.Position = UDim2.new(0, 6, 0, 80)
        nameLabel.Size = UDim2.new(1, -12, 0, 16)
        nameLabel.Text = data.name or id

        local stats = Instance.new("TextLabel")
        stats.Name = "Stats"
        stats.Parent = item
        stats.BackgroundTransparency = 1
        stats.Font = Enum.Font.Gotham
        stats.TextSize = 11
        stats.TextXAlignment = Enum.TextXAlignment.Left
        stats.TextYAlignment = Enum.TextYAlignment.Top
        stats.TextColor3 = Color3.fromRGB(190, 190, 190)
        stats.TextWrapped = true
        stats.Position = UDim2.new(0, 6, 0, 98)
        stats.Size = UDim2.new(1, -12, 0, 72)
        stats.Text = string.format(
            "DMG: %s~%s\nCRT: %s\nCharge: %s\nPrice: %s",
            tostring(data.dmgMin),
            tostring(data.dmgMax),
            tostring(data.crt),
            tostring(data.charge),
            tostring(data.priceText)
        )

        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyButton"
        buyBtn.Parent = item
        buyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        buyBtn.BorderSizePixel = 0
        buyBtn.AutoButtonColor = true
        buyBtn.Font = Enum.Font.GothamSemibold
        buyBtn.TextSize = 12
        buyBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
        buyBtn.Text = "Buy"
        buyBtn.Position = UDim2.new(0, 6, 1, -30)
        buyBtn.Size = UDim2.new(1, -12, 0, 24)

        local cornerBtn = Instance.new("UICorner")
        cornerBtn.CornerRadius = UDim.new(0, 6)
        cornerBtn.Parent = buyBtn

        harpoonCardsById[id] = {
            frame     = item,
            buyButton = buyBtn,
            assetType = data.assetType or "Currency",
        }

        local function onBuy()
            if isHarpoonOwned(id) then
                notify("Spear Fishing", (data.name or id) .. " sudah dimiliki.", 3)
                refreshHarpoonOwnership()
                return
            end

            if not ToolRE then
                notify("Spear Fishing", "Remote ToolRE tidak ditemukan.", 4)
                return
            end

            local assetType = (harpoonCardsById[id] and harpoonCardsById[id].assetType) or "Currency"

            if assetType == "Robux" and PurchaseUtil then
                local ok, err = pcall(function()
                    PurchaseUtil:getPurchase(id)
                end)
                if not ok then
                    warn("[SpearFishing] PurchaseUtil:getPurchase gagal:", err)
                    notify("Spear Fishing", "Gagal membuka purchase Robux.", 4)
                end
            else
                local args = {
                    [1] = "Buy",
                    [2] = { ["ID"] = id }
                }

                local ok, err = pcall(function()
                    ToolRE:FireServer(unpack(args))
                end)

                if ok then
                    notify("Spear Fishing", "Request beli " .. (data.name or id) .. " dikirim.", 4)
                else
                    warn("[SpearFishing] ToolRE:Buy gagal:", err)
                    notify("Spear Fishing", "Gagal mengirim request beli, cek Output.", 4)
                end
            end
        end

        table.insert(connections, buyBtn.MouseButton1Click:Connect(onBuy))
    end

    refreshHarpoonOwnership()
end

------------------- TOOLS DATA INIT -------------------
local function initToolsDataWatcher()
    task.spawn(function()
        if ToolsData then return end

        local waitFn
        while alive and not waitFn do
            local ok, fn = pcall(function()
                return shared and shared.WaitPlayerData
            end)
            if ok and typeof(fn) == "function" then
                waitFn = fn
                break
            end
            task.wait(0.2)
        end

        if not alive or not waitFn then
            return
        end

        local ok2, result = pcall(function()
            return waitFn("Tools")
        end)
        if not ok2 or not result then
            warn("[SpearFishing] Gagal WaitPlayerData('Tools'):", ok2 and "no result" or result)
            return
        end

        ToolsData = result

        local function onToolsChanged()
            if not alive then return end
            refreshHarpoonOwnership()
        end

        if ToolsData.AttributeChanged then
            table.insert(connections, ToolsData.AttributeChanged:Connect(onToolsChanged))
        end
        table.insert(connections, ToolsData.ChildAdded:Connect(onToolsChanged))
        table.insert(connections, ToolsData.ChildRemoved:Connect(onToolsChanged))

        onToolsChanged()
    end)
end

------------------- STATUS LABEL HELPER (stub, UI status dihapus) -------------------
local function updateStatusLabel()
    -- sengaja dikosongkan, karena teks status panjang di UI sudah dihapus
end

------------------- UI BUILDERS -------------------
local function applySkillFromBox(slotIndex, box, descLabel)
    local raw = box.Text or ""
    raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then
        -- kosongkan -> revert ke nama sebelumnya
    else
        local key = normalizeSkillKey(raw)
        local foundId = SKILL_NAME_TO_ID[key]

        if not foundId and raw:match("^Skill%d+") then
            local num = tonumber(raw:match("(%d+)")) or 0
            if num > 0 and num <= 10 then
                local candidate = string.format("Skill%02d", num)
                if SKILL_ID_TO_NAME[candidate] then
                    foundId = candidate
                end
            end
        end

        if foundId then
            local uiName = getSkillUiNameFromId(foundId)

            if slotIndex == 1 then
                autoSkill1Id = foundId
                autoSkill1Name = uiName
            elseif slotIndex == 2 then
                autoSkill2Id = foundId
                autoSkill2Name = uiName
            elseif slotIndex == 3 then
                autoSkill3Id = foundId
                autoSkill3Name = uiName
            elseif slotIndex == 4 then
                autoSkill4Id = foundId
                autoSkill4Name = uiName
            elseif slotIndex == 5 then
                autoSkill5Id = foundId
                autoSkill5Name = uiName
            end

            box.Text = uiName
            if descLabel then
                descLabel.Text = string.format("Skill %d: %s", slotIndex, uiName)
            end
            return
        else
            notify("Spear Fishing", "Nama skill tidak dikenali, gunakan Thunder / Cold Snap / dll.", 4)
        end
    end

    -- revert jika gagal
    local uiName
    if slotIndex == 1 then
        uiName = autoSkill1Name
    elseif slotIndex == 2 then
        uiName = autoSkill2Name
    elseif slotIndex == 3 then
        uiName = autoSkill3Name
    elseif slotIndex == 4 then
        uiName = autoSkill4Name
    elseif slotIndex == 5 then
        uiName = autoSkill5Name
    end
    box.Text = uiName or ""
    if descLabel and uiName then
        descLabel.Text = string.format("Skill %d: %s", slotIndex, uiName)
    end
end

local function buildSpearControlsCard(bodyScroll)
    local controlCard = createCard(
        bodyScroll,
        "Spear Auto Skill",
        "Auto Skill 1~5 + custom nama skill (Thunder, Cold Snap, dll).",
        1,
        220
    )

    local controlsScroll = Instance.new("ScrollingFrame")
    controlsScroll.Name = "ControlsScroll"
    controlsScroll.Parent = controlCard
    controlsScroll.BackgroundTransparency = 1
    controlsScroll.BorderSizePixel = 0
    controlsScroll.Position = UDim2.new(0, 0, 0, 52)    -- di bawah deskripsi
    controlsScroll.Size = UDim2.new(1, 0, 1, -52)
    controlsScroll.ScrollBarThickness = 4
    controlsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    controlsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local controlsPadding = Instance.new("UIPadding")
    controlsPadding.Parent = controlsScroll
    controlsPadding.PaddingTop = UDim.new(0, 0)
    controlsPadding.PaddingBottom = UDim.new(0, 8)
    controlsPadding.PaddingLeft = UDim.new(0, 0)
    controlsPadding.PaddingRight = UDim.new(0, 0)

    local controlsLayout = Instance.new("UIListLayout")
    controlsLayout.Parent = controlsScroll
    controlsLayout.FillDirection = Enum.FillDirection.Vertical
    controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    controlsLayout.Padding = UDim.new(0, 6)

    table.insert(connections, controlsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        controlsScroll.CanvasSize = UDim2.new(0, 0, 0, controlsLayout.AbsoluteContentSize.Y + 8)
    end))

    -- Row builder (Toggle + TextBox + label deskripsi)
    local function createSkillRow(slotIndex, autoFlag, getName)
        local row = Instance.new("Frame")
        row.Name = "SkillRow" .. tostring(slotIndex)
        row.Parent = controlsScroll
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 32)

        local toggleButton, updateToggleUI = createToggleButton(row, "Auto Skill " .. tostring(slotIndex), autoFlag)
        toggleButton.Size = UDim2.new(0.45, -4, 1, 0)
        toggleButton.Position = UDim2.new(0, 0, 0, 0)

        local box = Instance.new("TextBox")
        box.Name = "SkillNameBox" .. tostring(slotIndex)
        box.Parent = row
        box.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.GothamSemibold
        box.TextSize = 11
        box.TextColor3 = Color3.fromRGB(230, 230, 230)
        box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.TextYAlignment = Enum.TextYAlignment.Center
        box.Position = UDim2.new(0.48, 0, 0, 0)
        box.Size = UDim2.new(0.52, 0, 1, 0)
        box.Text = getName()

        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 6)
        boxCorner.Parent = box

        local desc = Instance.new("TextLabel")
        desc.Name = "SkillDesc" .. tostring(slotIndex)
        desc.Parent = controlsScroll
        desc.BackgroundTransparency = 1
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 11
        desc.TextColor3 = Color3.fromRGB(185, 185, 185)
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextWrapped = true
        desc.Size = UDim2.new(1, 0, 0, 18)
        desc.Text = string.format("Skill %d: %s", slotIndex, getName())

        table.insert(connections, toggleButton.MouseButton1Click:Connect(function()
            if slotIndex == 1 then
                autoSkill1 = not autoSkill1
                updateToggleUI(autoSkill1)
            elseif slotIndex == 2 then
                autoSkill2 = not autoSkill2
                updateToggleUI(autoSkill2)
            elseif slotIndex == 3 then
                autoSkill3 = not autoSkill3
                updateToggleUI(autoSkill3)
            elseif slotIndex == 4 then
                autoSkill4 = not autoSkill4
                updateToggleUI(autoSkill4)
            elseif slotIndex == 5 then
                autoSkill5 = not autoSkill5
                updateToggleUI(autoSkill5)
            end
            updateStatusLabel()
        end))

        table.insert(connections, box.FocusLost:Connect(function()
            applySkillFromBox(slotIndex, box, desc)
        end))
    end

    createSkillRow(1, autoSkill1, function() return autoSkill1Name end)
    createSkillRow(2, autoSkill2, function() return autoSkill2Name end)
    createSkillRow(3, autoSkill3, function() return autoSkill3Name end)
    createSkillRow(4, autoSkill4, function() return autoSkill4Name end)
    createSkillRow(5, autoSkill5, function() return autoSkill5Name end)
end

local function buildSpawnControlsCard(bodyScroll)
    local spawnCard = createCard(
        bodyScroll,
        "Spawn Notif Controls",
        "Settings Notifier Spawn (Boss, HP Boss, Divine, Secret, Climate) global + by Fish.",
        2,
        460
    )

    local spawnScroll = Instance.new("ScrollingFrame")
    spawnScroll.Name = "SpawnScroll"
    spawnScroll.Parent = spawnCard
    spawnScroll.BackgroundTransparency = 1
    spawnScroll.BorderSizePixel = 0
    spawnScroll.Position = UDim2.new(0, 0, 0, 52)   -- di bawah deskripsi
    spawnScroll.Size = UDim2.new(1, 0, 1, -52)
    spawnScroll.ScrollBarThickness = 4
    spawnScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    spawnScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local spawnPadding = Instance.new("UIPadding")
    spawnPadding.Parent = spawnScroll
    spawnPadding.PaddingTop = UDim.new(0, 0)
    spawnPadding.PaddingBottom = UDim.new(0, 8)
    spawnPadding.PaddingLeft = UDim.new(0, 0)
    spawnPadding.PaddingRight = UDim.new(0, 0)

    local spawnLayout = Instance.new("UIListLayout")
    spawnLayout.Parent = spawnScroll
    spawnLayout.FillDirection = Enum.FillDirection.Vertical
    spawnLayout.SortOrder = Enum.SortOrder.LayoutOrder
    spawnLayout.Padding = UDim.new(0, 6)

    table.insert(connections, spawnLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        spawnScroll.CanvasSize = UDim2.new(0, 0, 0, spawnLayout.AbsoluteContentSize.Y + 8)
    end))

    -- Input box webhook publik
    local webhookFrame = Instance.new("Frame")
    webhookFrame.Name = "WebhookFrame"
    webhookFrame.Parent = spawnScroll
    webhookFrame.BackgroundTransparency = 1
    webhookFrame.BorderSizePixel = 0
    webhookFrame.Size = UDim2.new(1, 0, 0, 30)

    local webhookLabel = Instance.new("TextLabel")
    webhookLabel.Name = "WebhookLabel"
    webhookLabel.Parent = webhookFrame
    webhookLabel.BackgroundTransparency = 1
    webhookLabel.Font = Enum.Font.Gotham
    webhookLabel.TextSize = 11
    webhookLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
    webhookLabel.TextXAlignment = Enum.TextXAlignment.Left
    webhookLabel.Position = UDim2.new(0, 0, 0, 0)
    webhookLabel.Size = UDim2.new(0.42, 0, 1, 0)
    webhookLabel.Text = "Discord Webhook (optional):"

    local webhookBox = Instance.new("TextBox")
    webhookBox.Name = "WebhookBox"
    webhookBox.Parent = webhookFrame
    webhookBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    webhookBox.BorderSizePixel = 0
    webhookBox.Font = Enum.Font.GothamSemibold
    webhookBox.TextSize = 11
    webhookBox.TextColor3 = Color3.fromRGB(230, 230, 230)
    webhookBox.ClearTextOnFocus = false
    webhookBox.TextXAlignment = Enum.TextXAlignment.Left
    webhookBox.Position = UDim2.new(0.44, 0, 0, 0)
    webhookBox.Size = UDim2.new(0.56, 0, 1, 0)
    webhookBox.PlaceholderText = "https://discord.com/api/webhooks/..."
    webhookBox.Text = ""

    local webhookCorner = Instance.new("UICorner")
    webhookCorner.CornerRadius = UDim.new(0, 6)
    webhookCorner.Parent = webhookBox

    table.insert(connections, webhookBox.FocusLost:Connect(function()
        local raw = webhookBox.Text or ""
        raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
        userWebhookUrl = raw
        if raw ~= "" then
            notify("Spear Fishing", "Webhook publik diset. Notifier juga dikirim ke ExHub Notifier.", 3)
        else
            notify("Spear Fishing", "Webhook publik dikosongkan. Notifier hanya ke webhook default.", 3)
        end
    end))

    local spawnBossToggleButton =
        select(1, createToggleButton(spawnScroll, "Spawn Boss Notifier", spawnBossNotifier))

    local hpBossToggleButton =
        select(1, createToggleButton(spawnScroll, "HPBar Boss Notifier", hpBossNotifier))

    local climateToggleButton =
        select(1, createToggleButton(spawnScroll, "Climate Time Notifier", climateTimeNotifier))

    local spawnIllahiToggleButton =
        select(1, createToggleButton(spawnScroll, "Spawn Divine Notifier", spawnIllahiNotifier))

    local spawnSecretToggleButton =
        select(1, createToggleButton(spawnScroll, "Spawn Secret Notifier", spawnSecretNotifier))

    table.insert(connections, spawnBossToggleButton.MouseButton1Click:Connect(function()
        spawnBossNotifier = not spawnBossNotifier
        setToggleButtonState(spawnBossToggleButton, "Spawn Boss Notifier", spawnBossNotifier)
        updateStatusLabel()
        notify("Spear Fishing", "Spawn Boss Notifier: " .. (spawnBossNotifier and "ON" or "OFF"), 2)
    end))

    table.insert(connections, hpBossToggleButton.MouseButton1Click:Connect(function()
        hpBossNotifier = not hpBossNotifier
        setToggleButtonState(hpBossToggleButton, "HPBar Boss Notifier", hpBossNotifier)
        updateStatusLabel()
        notify("Spear Fishing", "HPBar Boss Notifier: " .. (hpBossNotifier and "ON" or "OFF"), 2)
    end))

    table.insert(connections, climateToggleButton.MouseButton1Click:Connect(function()
        climateTimeNotifier = not climateTimeNotifier
        setToggleButtonState(climateToggleButton, "Climate Time Notifier", climateTimeNotifier)
        updateStatusLabel()
        notify("Spear Fishing", "Climate Time Notifier: " .. (climateTimeNotifier and "ON" or "OFF"), 2)
    end))

    table.insert(connections, spawnIllahiToggleButton.MouseButton1Click:Connect(function()
        spawnIllahiNotifier = not spawnIllahiNotifier
        setToggleButtonState(spawnIllahiToggleButton, "Spawn Divine Notifier", spawnIllahiNotifier)
        updateStatusLabel()
        notify("Spear Fishing", "Spawn Divine Notifier: " .. (spawnIllahiNotifier and "ON" or "OFF"), 2)
    end))

    table.insert(connections, spawnSecretToggleButton.MouseButton1Click:Connect(function()
        spawnSecretNotifier = not spawnSecretNotifier
        setToggleButtonState(spawnSecretToggleButton, "Spawn Secret Notifier", spawnSecretNotifier)
        updateStatusLabel()
        notify("Spear Fishing", "Spawn Secret Notifier: " .. (spawnSecretNotifier and "ON" or "OFF"), 2)
    end))

    local illahiLabel = Instance.new("TextLabel")
    illahiLabel.Name = "DivineLabel"
    illahiLabel.Parent = spawnScroll
    illahiLabel.BackgroundTransparency = 1
    illahiLabel.Font = Enum.Font.GothamSemibold
    illahiLabel.TextSize = 12
    illahiLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    illahiLabel.TextXAlignment = Enum.TextXAlignment.Left
    illahiLabel.Size = UDim2.new(1, 0, 0, 18)
    illahiLabel.Text = "Divine Notifier per Ikan (Nether Island):"

    for _, fishId in ipairs(ILLAHI_ORDER) do
        illahiFishEnabled[fishId] = illahiFishEnabled[fishId] ~= false

        local btn = select(1, createToggleButton(
            spawnScroll,
            "Notifier Divine " .. ((ILLAHI_FISH_DEFS[fishId] and ILLAHI_FISH_DEFS[fishId].name) or fishId),
            illahiFishEnabled[fishId]
        ))

        table.insert(connections, btn.MouseButton1Click:Connect(function()
            local newState = not illahiFishEnabled[fishId]
            illahiFishEnabled[fishId] = newState
            local def = ILLAHI_FISH_DEFS[fishId]
            local labelText = "Notifier Divine " .. ((def and def.name) or fishId)
            setToggleButtonState(btn, labelText, newState)
        end))
    end

    local secretLabel = Instance.new("TextLabel")
    secretLabel.Name = "SecretLabel"
    secretLabel.Parent = spawnScroll
    secretLabel.BackgroundTransparency = 1
    secretLabel.Font = Enum.Font.GothamSemibold
    secretLabel.TextSize = 12
    secretLabel.TextColor3 = Color3.fromRGB(255, 220, 180)
    secretLabel.TextXAlignment = Enum.TextXAlignment.Left
    secretLabel.Size = UDim2.new(1, 0, 0, 18)
    secretLabel.Text = "Secret Notifier per Ikan (Nether Island):"

    for _, fishId in ipairs(SECRET_ORDER) do
        secretFishEnabled[fishId] = secretFishEnabled[fishId] == true

        local btn = select(1, createToggleButton(
            spawnScroll,
            "Notifier Secret " .. ((SECRET_FISH_DEFS[fishId] and SECRET_FISH_DEFS[fishId].name) or fishId),
            secretFishEnabled[fishId]
        ))

        table.insert(connections, btn.MouseButton1Click:Connect(function()
            local newState = not secretFishEnabled[fishId]
            secretFishEnabled[fishId] = newState
            local def = SECRET_FISH_DEFS[fishId]
            local labelText = "Notifier Secret " .. ((def and def.name) or fishId)
            setToggleButtonState(btn, labelText, newState)
        end))
    end
end

local function buildEspCard(bodyScroll)
    local espCard = createCard(
        bodyScroll,
        "ESP Fish Controls",
        "ESP antena kuning dari karakter ke Boss/Divine/Secret + nama dan jarak (stud).",
        3,
        420
    )

    local espScroll = Instance.new("ScrollingFrame")
    espScroll.Name = "ESPScroll"
    espScroll.Parent = espCard
    espScroll.BackgroundTransparency = 1
    espScroll.BorderSizePixel = 0
    espScroll.Position = UDim2.new(0, 0, 0, 52)  -- di bawah deskripsi
    espScroll.Size = UDim2.new(1, 0, 1, -52)
    espScroll.ScrollBarThickness = 4
    espScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    espScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local espPadding = Instance.new("UIPadding")
    espPadding.Parent = espScroll
    espPadding.PaddingTop = UDim.new(0, 0)
    espPadding.PaddingBottom = UDim.new(0, 8)
    espPadding.PaddingLeft = UDim.new(0, 0)
    espPadding.PaddingRight = UDim.new(0, 0)

    local espLayout = Instance.new("UIListLayout")
    espLayout.Parent = espScroll
    espLayout.FillDirection = Enum.FillDirection.Vertical
    espLayout.SortOrder = Enum.SortOrder.LayoutOrder
    espLayout.Padding = UDim.new(0, 6)

    table.insert(connections, espLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        espScroll.CanvasSize = UDim2.new(0, 0, 0, espLayout.AbsoluteContentSize.Y + 8)
    end))

    local espBossButton =
        select(1, createToggleButton(espScroll, "ESP Boss", espBoss))

    local espIllahiButton =
        select(1, createToggleButton(espScroll, "ESP Divine", espIllahi))

    local espSecretButton =
        select(1, createToggleButton(espScroll, "ESP Secret", espSecret))

    table.insert(connections, espBossButton.MouseButton1Click:Connect(function()
        espBoss = not espBoss
        setToggleButtonState(espBossButton, "ESP Boss", espBoss)
        refreshAllEsp()
        updateStatusLabel()
        notify("Spear Fishing", "ESP Boss: " .. (espBoss and "ON" or "OFF"), 2)
    end))

    table.insert(connections, espIllahiButton.MouseButton1Click:Connect(function()
        espIllahi = not espIllahi
        setToggleButtonState(espIllahiButton, "ESP Divine", espIllahi)
        refreshAllEsp()
        updateStatusLabel()
        notify("Spear Fishing", "ESP Divine: " .. (espIllahi and "ON" or "OFF"), 2)
    end))

    table.insert(connections, espSecretButton.MouseButton1Click:Connect(function()
        espSecret = not espSecret
        setToggleButtonState(espSecretButton, "ESP Secret", espSecret)
        refreshAllEsp()
        updateStatusLabel()
        notify("Spear Fishing", "ESP Secret: " .. (espSecret and "ON" or "OFF"), 2)
    end))

    local espIllahiLabel = Instance.new("TextLabel")
    espIllahiLabel.Name = "ESPDivineLabel"
    espIllahiLabel.Parent = espScroll
    espIllahiLabel.BackgroundTransparency = 1
    espIllahiLabel.Font = Enum.Font.GothamSemibold
    espIllahiLabel.TextSize = 12
    espIllahiLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    espIllahiLabel.TextXAlignment = Enum.TextXAlignment.Left
    espIllahiLabel.Size = UDim2.new(1, 0, 0, 18)
    espIllahiLabel.Text = "ESP Divine per Ikan (Nether Island):"

    for _, fishId in ipairs(ILLAHI_ORDER) do
        espIllahiFishEnabled[fishId] = espIllahiFishEnabled[fishId] == true

        local btn = select(1, createToggleButton(
            espScroll,
            "ESP Divine " .. ((ILLAHI_FISH_DEFS[fishId] and ILLAHI_FISH_DEFS[fishId].name) or fishId),
            espIllahiFishEnabled[fishId]
        ))

        table.insert(connections, btn.MouseButton1Click:Connect(function()
            local newState = not espIllahiFishEnabled[fishId]
            espIllahiFishEnabled[fishId] = newState
            local def = ILLAHI_FISH_DEFS[fishId]
            local labelText = "ESP Divine " .. ((def and def.name) or fishId)
            setToggleButtonState(btn, labelText, newState)
            refreshAllEsp()
            updateStatusLabel()
        end))
    end

    local espSecretLabel = Instance.new("TextLabel")
    espSecretLabel.Name = "ESPSecretLabel"
    espSecretLabel.Parent = espScroll
    espSecretLabel.BackgroundTransparency = 1
    espSecretLabel.Font = Enum.Font.GothamSemibold
    espSecretLabel.TextSize = 12
    espSecretLabel.TextColor3 = Color3.fromRGB(255, 220, 180)
    espSecretLabel.TextXAlignment = Enum.TextXAlignment.Left
    espSecretLabel.Size = UDim2.new(1, 0, 0, 18)
    espSecretLabel.Text = "ESP Secret per Ikan (Nether Island):"

    for _, fishId in ipairs(SECRET_ORDER) do
        espSecretFishEnabled[fishId] = espSecretFishEnabled[fishId] == true

        local btn = select(1, createToggleButton(
            espScroll,
            "ESP Secret " .. ((SECRET_FISH_DEFS[fishId] and SECRET_FISH_DEFS[fishId].name) or fishId),
            espSecretFishEnabled[fishId]
        ))

        table.insert(connections, btn.MouseButton1Click:Connect(function()
            local newState = not espSecretFishEnabled[fishId]
            espSecretFishEnabled[fishId] = newState
            local def = SECRET_FISH_DEFS[fishId]
            local labelText = "ESP Secret " .. ((def and def.name) or fishId)
            setToggleButtonState(btn, labelText, newState)
            refreshAllEsp()
            updateStatusLabel()
        end))
    end
end

------------------- BUILD ALL UI -------------------
local function buildAllUI()
    local _, bodyScroll = createMainLayout()
    buildSpearControlsCard(bodyScroll)
    buildSpawnControlsCard(bodyScroll)
    buildEspCard(bodyScroll)
    buildHarpoonShopCard(bodyScroll)
end

buildAllUI()

------------------- INIT WATCHERS -------------------
initToolsDataWatcher()
initWorldBossNotifier()
initIllahiSpawnNotifier()
initSecretSpawnNotifier()
initClimateTimeNotifier()

------------------- BACKPACK / CHARACTER EVENT -------------------
table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    task.delay(1, function()
        if alive then
            refreshHarpoonOwnership()
            refreshAllEsp()
        end
    end)
end))

table.insert(connections, LocalPlayer.ChildAdded:Connect(function(child)
    if child:IsA("Backpack") then
        backpack = child
        task.delay(0.5, function()
            if alive then
                refreshHarpoonOwnership()
            end
        end)
    end
end))

if backpack then
    table.insert(connections, backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            refreshHarpoonOwnership()
        end
    end))

    table.insert(connections, backpack.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            refreshHarpoonOwnership()
        end
    end))
end

------------------- BACKGROUND LOOPS -------------------
-- Loop Auto Skill 1 & 2 (sequence)
task.spawn(function()
    while alive do
        if autoSkill1 or autoSkill2 then
            if autoSkill1 and autoSkill2 then
                pcall(fireSkill1)
                local t = 0
                while t < 0.6 and alive and autoSkill1 and autoSkill2 do
                    task.wait(0.2)
                    t = t + 0.2
                end
                if not alive then break end
                if autoSkill1 and autoSkill2 then
                    pcall(fireSkill2)
                    local t2 = 0
                    while t2 < 0.6 and alive and autoSkill1 and autoSkill2 do
                        task.wait(0.2)
                        t2 = t2 + 0.2
                    end
                end
            else
                if autoSkill1 then
                    pcall(fireSkill1)
                elseif autoSkill2 then
                    pcall(fireSkill2)
                end
                local t = 0
                while t < 1 and alive and (autoSkill1 or autoSkill2) do
                    task.wait(0.2)
                    t = t + 0.2
                end
            end
        else
            task.wait(0.5)
        end
    end
end)

-- Loop Auto Skill 3-5
task.spawn(function()
    while alive do
        if autoSkill3 or autoSkill4 or autoSkill5 then
            if autoSkill3 then
                pcall(fireSkill3)
            end
            task.wait(0.2)
            if not alive then break end

            if autoSkill4 then
                pcall(fireSkill4)
            end
            task.wait(0.2)
            if not alive then break end

            if autoSkill5 then
                pcall(fireSkill5)
            end

            local t = 0
            while t < 1 and alive and (autoSkill3 or autoSkill4 or autoSkill5) do
                task.wait(0.2)
                t = t + 0.2
            end
        else
            task.wait(0.5)
        end
    end
end)

-- Loop update ESP distance
task.spawn(function()
    while alive do
        pcall(updateEspTextDistances)
        task.wait(0.25)
    end
end)

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive                 = false
    autoSkill1            = false
    autoSkill2            = false
    autoSkill3            = false
    autoSkill4            = false
    autoSkill5            = false
    spawnBossNotifier     = false
    hpBossNotifier        = false
    spawnIllahiNotifier   = false
    spawnSecretNotifier   = false
    climateTimeNotifier   = false
    espBoss               = false
    espIllahi             = false
    espSecret             = false
    bossRegionState       = {}
    hpRegionState         = {}
    trackedFishEspTargets = {}

    for part, _ in pairs(fishEspMap) do
        destroyFishEsp(part)
    end
    fishEspMap    = {}
    hrpAttachment = nil

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
