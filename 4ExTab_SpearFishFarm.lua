--==========================================================
--  4AxaTab_SpearFishFarm.lua
--  TAB 4: "Spear Fish Farm PRO++"
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame = TAB_FRAME
local tabId = TAB_ID or "spearfishfarm"

local Players             = Players             or game:GetService("Players")
local LocalPlayer         = LocalPlayer         or Players.LocalPlayer
local RunService          = RunService          or game:GetService("RunService")
local UserInputService    = UserInputService    or game:GetService("UserInputService")
local StarterGui          = StarterGui          or game:GetService("StarterGui")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local workspace           = workspace
local TweenService        = TweenService        or game:GetService("TweenService")
local TeleportService     = TeleportService     or game:GetService("TeleportService")
local HttpService         = HttpService         or game:GetService("HttpService")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

_G.AxaHub            = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}

------------------- GLOBAL STATE -------------------
local alive        = true
local connections  = {}

local character    = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local Remotes      = ReplicatedStorage:FindFirstChild("Remotes")
local FireRE       = Remotes and Remotes:FindFirstChild("FireRE")
local ToolRE       = Remotes and Remotes:FindFirstChild("ToolRE")

local WorldSea     = workspace:FindFirstChild("WorldSea")
local WorldBoss    = workspace:FindFirstChild("WorldBoss")
local WorldFp      = workspace:FindFirstChild("WorldFp")

--==========================================================
--  UNLOCK CURSOR (AUTO ON, NO TOGGLE/BUTTON)
--==========================================================
local isCursorUnlocked = true

local function forceCursorUnlocked()
    if not isCursorUnlocked then
        return
    end

    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end

    if UserInputService.MouseIconEnabled == false then
        UserInputService.MouseIconEnabled = true
    end
end

table.insert(connections, RunService.RenderStepped:Connect(function()
    if alive then
        forceCursorUnlocked()
    end
end))

-- Auto farm flags
local autoFarmAll      = true   -- All fish according to Sea filter
local autoFarmBoss     = true   -- Boss in WorldBoss
local autoFarmRare     = false  -- Mythic/Legendary/Secret Sea4, Sea5, Sea8, Sea9
local autoFarmIllahi   = false  -- Divine Sea6, Sea7, Sea8, Sea10

local function isAnyAutoFarmActive()
    return autoFarmAll or autoFarmBoss or autoFarmRare or autoFarmIllahi
end

-- Fire First (toggle removed from UI, still active in logic)
local fireFirstEnabled   = isAnyAutoFarmActive()
local fireChargeEnabled  = true

local function updateFireFirstState()
    fireFirstEnabled = isAnyAutoFarmActive()
end

-- Chest Farm flags + state
local autoChestEnabled       = true
local chestReturnEnabled     = true
local lastLocationCFrame     = nil
local chestCurrentTargetPart = nil
local chestHadRecently       = false
local activeChestTween       = nil

-- AutoTP Boss flags
local autoTpPoint1Enabled = false
local autoTpPoint2Enabled = false

-- AutoTP Boss coordinates
local BOSS_POINT1_POSITION = Vector3.new(1125.79, 91.66, -391.42)
local BOSS_POINT1_LOOKAT   = Vector3.new(1134.95, 91.66, -387.40)
local BOSS_POINT2_POSITION = Vector3.new(321.25, 113.24, -946.53)
local BOSS_POINT2_LOOKAT   = Vector3.new(329.28, 113.24, -952.48)

--==========================================================
--  AUTO TP INTERNAL STATE
--==========================================================
local chestActivityFlag         = false   -- true if Chest/LastLocation is still in progress
local chestJustFinishedFlag     = false   -- true for one tick right after Chest + Last Location finished
local lastBossAliveForTp        = false
local lastBossRegionForTp       = nil
local pendingTeleportTarget     = nil
local pendingTeleportAt         = nil
local pendingTeleportCreatedAt  = nil
local pendingTeleportMode       = nil
local tp1CycleState             = 0
local tp2CycleState             = 0
local NEAR_REMAIN_THRESHOLD     = 240
local MIN_NEAR_REMAIN           = 180
local AUTOTP_CHEST_FALLBACK     = 7   -- seconds

-- Sea mode (Sea6 & Sea7 combined)
local seaModeList = {
    "AutoDetect",
    "Sea1",
    "Sea2",
    "Sea3",
    "Sea4",
    "Sea5",
    "Sea6_7",
    "Sea8",
    "Sea9",
    "Sea10",
}
local seaModeIndex = 1

-- Rarity mode dropdown
local rarityModeList = {
    "Disabled",
    "Legendary/Mythic/Secret/Divine",
    "By Fish",
}
local rarityModeIndex = 1

-- Location names mapping for UI (no longer display "Sea1-10")
local SEA_UI_NAME_MAP = {
    Sea1   = "Beginner River",
    Sea2   = "Rushing Stream",
    Sea3   = "Island Center Lake",
    Sea4   = "Submerged Pond",
    Sea5   = "Island Soul Sea (Nether Island)",
    Sea6   = "Island Soul Sea Air (Nether Island)",
    Sea7   = "Island Soul Sea Floating (Nether Island)",
    Sea6_7 = "Island Soul Sea Air+Floating (Nether Island)",
    Sea8   = "Wrecks Sea - Lower Layers (Under Water)",
    Sea9   = "Wrecks Sea - Mid Layers (Under Water)",
    Sea10  = "Wrecks Sea - Upper Layers (Under Water)",
}

local function getSeaDisplayNameForUi(seaCode)
    if not seaCode or seaCode == "" then
        return "-"
    end
    if seaCode == "Sea6&Sea7" or seaCode == "Sea6_7" then
        return SEA_UI_NAME_MAP["Sea6_7"]
    end
    return SEA_UI_NAME_MAP[seaCode] or seaCode
end

-- AimLock + ESP Antenna
local aimLockEnabled    = true
local espAntennaEnabled = true

-- Shooting range
local SHOOT_RANGE_MIN = 25
local SHOOT_RANGE_MAX = 1000
local shootRange      = 600

-- Farm delay
local FARM_DELAY_MIN  = 0.01
local FARM_DELAY_MAX  = 0.30
local farmDelay       = 0.01

-- Status label UI (currently not used, text cleared)
local statusLabel

-- Boss target
local currentBossTarget     = nil
local currentBossTargetPart = nil

------------------- FISH DATA SETS -------------------
-- Divine Nether Island (Sea6 & Sea7)
local ILLAHI_NET_SET = {
    Fish400 = true,
    Fish401 = true,
    Fish402 = true,
    Fish403 = true,
    Fish404 = true,
    Fish405 = true,
}

-- Divine Under Water (Sea8 & Sea10)
local ILLAHI_UW_SET = {
    Fish621 = true,
    Fish620 = true,
    Fish610 = true,
    Fish609 = true,
    Fish611 = true,
}

local ILLAHI_SET = {}
for id in pairs(ILLAHI_NET_SET) do
    ILLAHI_SET[id] = true
end
for id in pairs(ILLAHI_UW_SET) do
    ILLAHI_SET[id] = true
end

-- Rare Nether Island (Sea5)
local RARE_SEA5_SET = {
    Fish500 = true,
    Fish501 = true,
    Fish503 = true,
    Fish504 = true,
    Fish505 = true,
    Fish508 = true,
    Fish510 = true,
    Fish502 = true,
    Fish506 = true,
    Fish507 = true,
    Fish509 = true,
}

-- Sea4
local RARE_SEA4_SET = {
    Fish55  = true,
    Fish56  = true,
    Fish57  = true,
    Fish98  = true,
    Fish305 = true,
    Fish201 = true,
    Fish104 = true,
    Fish105 = true,
    Fish102 = true,
    Fish97  = true,
    Fish202 = true,
    Fish121 = true,
    Fish123 = true,
    Fish111 = true,
    Fish130 = true,
    Fish203 = true,
}

-- Sea9
local RARE_SEA9_SET = {
    Fish622 = true,
    Fish619 = true,
    Fish618 = true,
    Fish617 = true,
    Fish614 = true,
    Fish615 = true,
    Fish606 = true,
}

-- Sea8
local RARE_SEA8_SET = {
    Fish616 = true,
    Fish608 = true,
    Fish607 = true,
    Fish605 = true,
    Fish613 = true,
    Fish604 = true,
    Fish603 = true,
    Fish612 = true,
    Fish602 = true,
    Fish601 = true,
}

-- Boss IDs
local BOSS_IDS = {
    Boss01 = true,
    Boss02 = true,
    Boss03 = true,
}

------------------- DISPLAY NAME MAP -------------------
local FISH_DISPLAY_NAME_MAP = {
    Fish55  = "Purple Jellyfish",
    Fish56  = "Prism Jellyfish",
    Fish57  = "Prism Crab",
    Fish98  = "Shark",
    Fish305 = "Christmas Shark",
    Fish201 = "Shimmer Puffer",

    Fish104 = "Bullfrog",
    Fish105 = "Poison Dart Frog",
    Fish102 = "Swamp Crocodile",
    Fish97  = "Sawtooth Shark",
    Fish202 = "Nebula Lantern Carp",

    Fish121 = "Dragon Whisker Fish",
    Fish123 = "Leatherback Turtle",
    Fish111 = "Frost Anglerfish",
    Fish130 = "Devil Ray",
    Fish203 = "Shimmer Unicorn Fish",

    Fish500 = "Abyssal Demon Shark",
    Fish501 = "Nighfall Demon Shark",
    Fish503 = "Ancient Gopala",
    Fish504 = "Nighfall Gopala",
    Fish505 = "Sharkster",
    Fish508 = "Mayfly Dragon",
    Fish510 = "Nighfall Sharkster",

    Fish502 = "Ocean Sunfish",
    Fish506 = "Squid",
    Fish507 = "Belthfish",
    Fish509 = "Cylostome",

    Fish400 = "Nether Barracuda",
    Fish401 = "Nether Anglerfish",
    Fish402 = "Nether Manta Ray",
    Fish403 = "Nether SwordFish",
    Fish404 = "Nether Flying Fish",
    Fish405 = "Diamond Flying Fish",

    Fish621 = "Amethyst Ray",
    Fish620 = "Ray",
    Fish610 = "Shovelnose Ray",
    Fish609 = "Greyback Lognose Shark",

    Fish622 = "Grouper",
    Fish619 = "Golden Arowana",
    Fish618 = "Red Arowana",
    Fish617 = "Jadefin Thin Eel",
    Fish614 = "Azure-Pattern Discus",
    Fish615 = "Bannerfin Butterflyfish",
    Fish606 = "Reef Grouper",

    Fish616 = "Yellowfin Thin Eel",
    Fish608 = "Emerald Flounder",
    Fish607 = "Amethyst Squid",
    Fish605 = "Sproud Seahorse",
    Fish613 = "Crimson-Jade Discus",
    Fish604 = "Golden Seahorse",
    Fish603 = "Crimson Arrow Squid",
    Fish612 = "Golden-Spotted Discus",
    Fish602 = "Red-Fin Roundbelly",
    Fish601 = "Abyss Sunfish",
    Fish611 = "Star-Marked Sea Turtle",
}

local BOSS_DISPLAY_NAME_MAP = {
    Boss01 = "Humpback Whale",
    Boss02 = "Whale Shark",
    Boss03 = "Crimson Rift Dragon",
}

local function resolveFishDisplayName(rawName)
    if not rawName or rawName == "" then
        return "Fish"
    end
    return FISH_DISPLAY_NAME_MAP[rawName] or rawName
end

local function resolveBossDisplayName(rawName)
    if not rawName or rawName == "" then
        return "Boss"
    end
    return BOSS_DISPLAY_NAME_MAP[rawName] or rawName
end

------------------- PER FISH CONFIG -------------------
-- UI names cleaned: without "Sea4-10" and without "Climate" in toggle labels
local PER_FISH_CONFIG = {
    { id = "Fish55",  sea = "Sea4", climates = {"Grassland"}, name = "Purple Jellyfish Legendary" },
    { id = "Fish56",  sea = "Sea4", climates = {"Grassland"}, name = "Prism Jellyfish Legendary" },
    { id = "Fish57",  sea = "Sea4", climates = {"Grassland"}, name = "Prism Crab Legendary" },
    { id = "Fish98",  sea = "Sea4", climates = {"Grassland"}, name = "Shark Mythic" },
    { id = "Fish305", sea = "Sea4", climates = {"Grassland","Marsh","Iceborne"}, name = "Christmas Shark Mythic" },
    { id = "Fish201", sea = "Sea4", climates = {"Grassland"}, name = "Shimmer Puffer Secret" },

    { id = "Fish104", sea = "Sea4", climates = {"Marsh"}, name = "Bullfrog Legendary" },
    { id = "Fish105", sea = "Sea4", climates = {"Marsh"}, name = "Poison Dart Frog Mythic" },
    { id = "Fish102", sea = "Sea4", climates = {"Marsh"}, name = "Swamp Crocodile Mythic" },
    { id = "Fish97",  sea = "Sea4", climates = {"Marsh"}, name = "Sawtooth Shark Mythic" },
    { id = "Fish202", sea = "Sea4", climates = {"Marsh"}, name = "Nebula Lantern Carp Secret" },

    { id = "Fish121", sea = "Sea4", climates = {"Iceborne"}, name = "Dragon Whisker Fish Legendary" },
    { id = "Fish123", sea = "Sea4", climates = {"Iceborne"}, name = "Leatherback Turtle Mythic" },
    { id = "Fish111", sea = "Sea4", climates = {"Iceborne"}, name = "Frost Anglerfish Mythic" },
    { id = "Fish130", sea = "Sea4", climates = {"Iceborne"}, name = "Devil Ray Mythic" },
    { id = "Fish203", sea = "Sea4", climates = {"Iceborne"}, name = "Shimmer Unicorn Fish Secret" },

    { id = "Fish500", sea = "Sea5", name = "Abyssal Demon Shark Secret" },
    { id = "Fish501", sea = "Sea5", name = "Nighfall Demon Shark Secret" },
    { id = "Fish503", sea = "Sea5", name = "Ancient Gopala Secret" },
    { id = "Fish504", sea = "Sea5", name = "Nighfall Gopala Secret" },
    { id = "Fish505", sea = "Sea5", name = "Sharkster Secret" },
    { id = "Fish508", sea = "Sea5", name = "Mayfly Dragon Secret" },
    { id = "Fish510", sea = "Sea5", name = "Nighfall Sharkster Secret" },

    { id = "Fish502", sea = "Sea5", name = "Ocean Sunfish Mythic" },
    { id = "Fish506", sea = "Sea5", name = "Squid Mythic" },
    { id = "Fish507", sea = "Sea5", name = "Belthfish Mythic" },
    { id = "Fish509", sea = "Sea5", name = "Cylostome Mythic" },

    { id = "Fish400", sea = "Sea7", name = "Nether Barracuda Divine" },
    { id = "Fish401", sea = "Sea7", name = "Nether Anglerfish Divine" },
    { id = "Fish402", sea = "Sea6", name = "Nether Manta Ray Divine" },
    { id = "Fish403", sea = "Sea6", name = "Nether SwordFish Divine" },
    { id = "Fish404", sea = "Sea6", name = "Nether Flying Fish Divine" },
    { id = "Fish405", sea = "Sea6", name = "Diamond Flying Fish Divine" },

    { id = "Fish621", sea = "Sea10", name = "Amethyst Ray Divine" },
    { id = "Fish620", sea = "Sea10", name = "Ray Divine" },
    { id = "Fish610", sea = "Sea10", name = "Shovelnose Ray Divine" },
    { id = "Fish609", sea = "Sea10", name = "Greyback Lognose Shark Divine" },

    { id = "Fish611", sea = "Sea8",  name = "Star-Marked Sea Turtle Divine" },

    { id = "Fish622", sea = "Sea9", name = "Grouper Secret" },
    { id = "Fish619", sea = "Sea9", name = "Golden Arowana Secret" },
    { id = "Fish618", sea = "Sea9", name = "Red Arowana Secret" },
    { id = "Fish617", sea = "Sea9", name = "Jadefin Thin Eel Secret" },
    { id = "Fish614", sea = "Sea9", name = "Azure-Pattern Discus Mythic" },
    { id = "Fish615", sea = "Sea9", name = "Bannerfin Butterflyfish Mythic" },
    { id = "Fish606", sea = "Sea9", name = "Reef Grouper Legendary" },

    { id = "Fish616", sea = "Sea8", name = "Yellowfin Thin Eel Secret" },
    { id = "Fish608", sea = "Sea8", name = "Emerald Flounder Secret" },
    { id = "Fish607", sea = "Sea8", name = "Amethyst Squid Secret" },
    { id = "Fish605", sea = "Sea8", name = "Sproud Seahorse Secret" },
    { id = "Fish613", sea = "Sea8", name = "Crimson-Jade Discus Mythic" },
    { id = "Fish604", sea = "Sea8", name = "Golden Seahorse Mythic" },
    { id = "Fish603", sea = "Sea8", name = "Crimson Arrow Squid Mythic" },
    { id = "Fish612", sea = "Sea8", name = "Golden-Spotted Discus Legendary" },
    { id = "Fish602", sea = "Sea8", name = "Red-Fin Roundbelly Legendary" },
    { id = "Fish601", sea = "Sea8", name = "Abyss Sunfish Legendary" },
}

local PER_FISH_FLAGS = {}
for _, cfg in ipairs(PER_FISH_CONFIG) do
    PER_FISH_FLAGS[cfg.id] = false
end

------------------- NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Spear Fish Farm",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

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

------------------- ESP DATA STRUCT -------------------
local trackedFishEspTargets = {}
local fishEspMap    = {}
local hrpAttachment = nil

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

    if data.beam then pcall(function() data.beam:Destroy() end) end
    if data.attachment and data.attachment.Parent then pcall(function() data.attachment:Destroy() end) end
    if data.billboard then pcall(function() data.billboard:Destroy() end) end

    fishEspMap[part] = nil
end

local function createEspInstancesForPart(part, displayName, fishType, fishId)
    local hrpAtt = ensureHRPAttachment()
    if not hrpAtt then return end
    if not part or not part:IsA("BasePart") then return end
    if fishEspMap[part] then return end

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
        displayName = displayName or fishId or "Fish",
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

    if not espAntennaEnabled then
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
            trackedFishEspTargets[part] = nil
        else
            local ok, dist = pcall(function()
                return (part.Position - hrpPos).Magnitude
            end)
            if ok then
                if dist > shootRange then
                    destroyFishEsp(part)
                    trackedFishEspTargets[part] = nil
                elseif data.label then
                    local nameText = data.displayName or "Fish"
                    local d = math.floor(dist or 0)
                    data.label.Text = string.format("%s | %d studs", nameText, d)
                end
            end
        end
    end
end

------------------- AIMLOCK STATE -------------------
local aimLockTarget     = nil
local aimLockTargetPart = nil
local aimLockLabelName  = "Target"

local function clearAimLockVisual()
    if aimLockTargetPart then
        destroyFishEsp(aimLockTargetPart)
        trackedFishEspTargets[aimLockTargetPart] = nil
    end
    aimLockTargetPart = nil
    aimLockTarget     = nil
end

local function setAimLockTarget(newPart, displayName)
    clearAimLockVisual()

    if not newPart or not newPart:IsA("BasePart") then
        return
    end

    aimLockTarget     = newPart
    aimLockTargetPart = newPart
    aimLockLabelName  = displayName or "Fish"

    registerFishPartForEsp(newPart, "AimLock", "AimLock", aimLockLabelName)
end

local function updateAimLockDistanceLabel()
    updateEspTextDistances()
end

------------------- TOOL HELPERS (HARPOON / GUN) -------------------
local lastAutoEquipWarn = 0

local function getBestToolFromCharacter()
    local char = character
    if not char then
        return nil
    end

    local bestHarpoon, bestHarpoonNum = nil, -1
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local n = child.Name:match("^Harpoon(%d+)$")
            if n then
                local num = tonumber(n) or 0
                if num > bestHarpoonNum then
                    bestHarpoonNum = num
                    bestHarpoon = child
                end
            end
        end
    end
    if bestHarpoon then
        return bestHarpoon
    end

    local bestGun, bestGunNum = nil, -1
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local n = child.Name:match("^Gun(%d+)$")
            if n then
                local num = tonumber(n) or 0
                if num > bestGunNum then
                    bestGunNum = num
                    bestGun = child
                end
            end
        end
    end
    if bestGun then
        return bestGun
    end

    return char:FindFirstChildWhichIsA("Tool")
end

local function ensureToolEquipped()
    local tool = getBestToolFromCharacter()
    if tool then
        return tool
    end

    if ToolRE then
        local args = {
            [1] = "Switch",
            [2] = { ["index"] = 1 }
        }
        pcall(function()
            ToolRE:FireServer(unpack(args))
        end)
        task.wait(0.2)
        tool = getBestToolFromCharacter()
        if tool then
            return tool
        end
    end

    local now = os.clock()
    if now - lastAutoEquipWarn > 5 then
        lastAutoEquipWarn = now
        notify("Spear Fish Farm", "Equip Harpoon/Gun before using AutoFarm.", 3)
    end
    return nil
end

------------------- SEA HELPERS -------------------
local function ensureWorldSea()
    if not WorldSea then
        WorldSea = workspace:FindFirstChild("WorldSea")
    end
    return WorldSea
end

-- Choose Teleport in WorldFp based on HRP position and target Boss Point
local function getTeleportPartForPoint(pointName)
    if not WorldFp or not WorldFp.Parent then
        WorldFp = workspace:FindFirstChild("WorldFp")
    end
    if not WorldFp then
        return nil
    end

    local candidates = {}
    local ok, descendants = pcall(function()
        return WorldFp:GetDescendants()
    end)
    if not ok or not descendants then
        descendants = WorldFp:GetChildren()
    end

    for _, child in ipairs(descendants) do
        if child:IsA("BasePart") and typeof(child.Name) == "string" and child.Name:sub(1, 8) == "Teleport" then
            table.insert(candidates, child)
        end
    end

    if #candidates == 0 then
        return nil
    end

    local hrp = getHRP()
    local bestPart
    local bestDist = math.huge

    if hrp then
        local hrpPos = hrp.Position
        for _, part in ipairs(candidates) do
            local d = (part.Position - hrpPos).Magnitude
            if d < bestDist then
                bestDist = d
                bestPart = part
            end
        end
        if bestPart then
            return bestPart
        end
    end

    local targetPos
    if pointName == "Point1" then
        targetPos = BOSS_POINT1_POSITION
    elseif pointName == "Point2" then
        targetPos = BOSS_POINT2_POSITION
    end

    if targetPos then
        bestPart = nil
        bestDist = math.huge
        for _, part in ipairs(candidates) do
            local d = (part.Position - targetPos).Magnitude
            if d < bestDist then
                bestDist = d
                bestPart = part
            end
        end
        if bestPart then
            return bestPart
        end
    end

    table.sort(candidates, function(a, b)
        return a:GetFullName() < b:GetFullName()
    end)
    return candidates[1]
end

local function getSeaEntriesByBaseName(baseName)
    local ws = ensureWorldSea()
    local list = {}
    if not ws then
        return list
    end

    for _, child in ipairs(ws:GetChildren()) do
        if typeof(child.Name) == "string" and child.Name:sub(1, #baseName) == baseName then
            table.insert(list, { folder = child, seaName = baseName })
        end
    end
    return list
end

local function detectCurrentSea()
    local ws = ensureWorldSea()
    if not ws then
        return nil, nil
    end

    local hrp = getHRP()
    if not hrp then
        return nil, nil
    end

    local hrpPos = hrp.Position
    local bestName
    local bestDist = math.huge

    for i = 1, 10 do
        local baseName = "Sea" .. tostring(i)
        local entries = getSeaEntriesByBaseName(baseName)
        if #entries > 0 then
            local sum = Vector3.new(0, 0, 0)
            local count = 0

            for _, entry in ipairs(entries) do
                local seaFolder = entry.folder
                local okDesc, descendants = pcall(function()
                    return seaFolder:GetDescendants()
                end)
                if okDesc and descendants then
                    for _, inst in ipairs(descendants) do
                        if inst:IsA("BasePart") then
                            sum = sum + inst.Position
                            count = count + 1
                        end
                    end
                end
            end

            if count > 0 then
                local center = sum / count
                local d = (center - hrpPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestName = baseName
                end
            end
        end
    end

    if not bestName then
        return nil, nil
    end

    local entries = getSeaEntriesByBaseName(bestName)
    local firstFolder = entries[1] and entries[1].folder or nil
    return firstFolder, bestName
end

local function getActiveSeaEntries()
    local mode = seaModeList[seaModeIndex] or "AutoDetect"
    local entries = {}
    local displaySeaName

    if mode == "AutoDetect" then
        local _, detectedName = detectCurrentSea()
        if not detectedName then
            return nil, nil
        end
        entries = getSeaEntriesByBaseName(detectedName)
        displaySeaName = detectedName
    elseif mode == "Sea6_7" then
        local e6 = getSeaEntriesByBaseName("Sea6")
        local e7 = getSeaEntriesByBaseName("Sea7")
        for _, e in ipairs(e6) do table.insert(entries, e) end
        for _, e in ipairs(e7) do table.insert(entries, e) end
        displaySeaName = "Sea6_7"
    else
        entries = getSeaEntriesByBaseName(mode)
        displaySeaName = mode
    end

    if not entries or #entries == 0 then
        return nil, nil
    end

    return entries, displaySeaName
end

------------------- HIT / FIRE HELPERS -------------------
local function getHitPosFromFishInstance(fish)
    if not fish then
        return nil
    end

    if fish:IsA("BasePart") then
        return fish.Position
    end

    if fish:IsA("Model") then
        if fish.PrimaryPart then
            return fish.PrimaryPart.Position
        end
        local part = fish:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.Position
        end
    end

    return nil
end

local function isInRange(pos)
    local hrp = getHRP()
    if not hrp or not pos then
        return false
    end
    local dist = (hrp.Position - pos).Magnitude
    return dist <= shootRange
end

local function sendFire(fishPos, tool)
    if not FireRE then
        return
    end
    if not fireFirstEnabled then
        return
    end
    if not fishPos or not tool then
        return
    end

    local cam = workspace.CurrentCamera
    local origin = fishPos
    if cam and cam.CFrame then
        origin = fishPos + (cam.CFrame.LookVector * -2)
    else
        origin = fishPos + Vector3.new(0, 2, 0)
    end

    local args = {
        [1] = "Fire",
        [2] = {
            cameraOrigin = origin,
            player       = LocalPlayer,
            toolInstance = tool,
            destination  = fishPos,
            isCharge     = fireChargeEnabled and true or false
        }
    }

    pcall(function()
        FireRE:FireServer(unpack(args))
    end)
end

local function sendHit(fishInstance, hitPos, tool)
    if not FireRE then
        return
    end
    if not fishInstance or not hitPos or not tool then
        return
    end

    local args = {
        [1] = "Hit",
        [2] = {
            fishInstance = fishInstance,
            HitPos       = hitPos,
            toolInstance = tool
        }
    }

    pcall(function()
        FireRE:FireServer(unpack(args))
    end)
end

local function sendFireThenHit(fishInstance, hitPos, tool)
    sendFire(hitPos, tool)
    sendHit(fishInstance, hitPos, tool)
end

------------------- CHEST FARM HELPERS -------------------
local function getChestParts()
    local result = {}
    local ok, descendants = pcall(function()
        return workspace:GetDescendants()
    end)
    if not ok or not descendants then
        return result
    end

    for _, inst in ipairs(descendants) do
        if inst.Name == "Chest" then
            if inst:IsA("BasePart") then
                table.insert(result, inst)
            elseif inst:IsA("Model") then
                local primary = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
                if primary then
                    table.insert(result, primary)
                end
            end
        end
    end

    return result
end

local function getNearestChestPart()
    local hrp = getHRP()
    if not hrp then
        return nil
    end
    local hrpPos = hrp.Position

    local parts = getChestParts()
    local best
    local bestDist = math.huge

    for _, part in ipairs(parts) do
        if part and part.Parent then
            local d = (part.Position - hrpPos).Magnitude
            if d < bestDist then
                bestDist = d
                best     = part
            end
        end
    end

    return best
end

local function smoothTeleportTo(position, lookAtPos)
    local hrp = getHRP()
    if not hrp or not position then
        return
    end

    if activeChestTween then
        pcall(function()
            activeChestTween:Cancel()
        end)
        activeChestTween = nil
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

    local duration = math.clamp(distance / 260, 0.05, 0.22)

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { CFrame = targetCFrame }
    )
    activeChestTween = tween
    tween:Play()

    task.spawn(function()
        pcall(function()
            tween.Completed:Wait()
        end)
        if activeChestTween == tween then
            activeChestTween = nil
        end
    end)
end

------------------- BOSS PRIORITY (CHECK BOSS ALIVE) -------------------
local function isBossAlive()
    if not autoFarmBoss then
        return false
    end
    if not currentBossTargetPart or currentBossTargetPart.Parent == nil then
        return false
    end

    local pos = currentBossTargetPart.Position
    if not isInRange(pos) then
        return false
    end

    local curHp = currentBossTargetPart:GetAttribute("CurHP")
        or currentBossTargetPart:GetAttribute("CurHp")
        or currentBossTargetPart:GetAttribute("HP")
        or currentBossTargetPart:GetAttribute("Hp")

    if curHp ~= nil and tonumber(curHp) <= 0 then
        return false
    end

    return true
end

local function formatBossRemainingText(remainSeconds)
    remainSeconds = tonumber(remainSeconds) or 0
    if remainSeconds < 0 then
        remainSeconds = 0
    end

    local total = math.floor(remainSeconds + 0.5)
    local m = math.floor(total / 60)
    local s = total % 60
    local mmss = string.format("%02d:%02d", m, s)

    return "Time Now: Guaranteed Divine Boss In " .. mmss .. " minutes"
end

local function getRegionRemainSecondsInternal(region)
    if not region then
        return nil
    end

    local raw = region:GetAttribute("RemainTime")
        or region:GetAttribute("RemainSeconds")
        or region:GetAttribute("Remain")
        or region:GetAttribute("RemainSec")
        or region:GetAttribute("GuaranteedDivineBossIn")
        or region:GetAttribute("GuranteedDivineBossIn")

    if raw == nil then
        for _, child in ipairs(region:GetChildren()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") then
                if child.Name == "RemainTime"
                    or child.Name == "RemainSeconds"
                    or child.Name == "Remain"
                    or child.Name == "RemainSec"
                    or child.Name == "GuaranteedDivineBossIn"
                    or child.Name == "GuranteedDivineBossIn"
                then
                    raw = child.Value
                    break
                end
            elseif child:IsA("StringValue") then
                if child.Name == "RemainTime" or child.Name == "RemainTimeText" then
                    local num = tonumber(child.Value)
                    if num then
                        raw = num
                        break
                    end
                end
            end
        end
    end

    local sec = tonumber(raw)
    return sec
end

local function getRegionRemainSeconds(regionName)
    if not WorldBoss then
        WorldBoss = workspace:FindFirstChild("WorldBoss")
    end
    if not WorldBoss then
        return nil
    end

    local region = WorldBoss:FindFirstChild(regionName)
    if not region then
        return nil
    end

    local ok, sec = pcall(getRegionRemainSecondsInternal, region)
    if not ok then
        warn("[SpearFishFarm] getRegionRemainSeconds error:", sec)
        return nil
    end
    return sec
end

local function getRegionForBossPart(part)
    if not part then
        return nil
    end
    if not WorldBoss then
        WorldBoss = workspace:FindFirstChild("WorldBoss")
    end
    if not WorldBoss then
        return nil
    end

    for _, pointName in ipairs({"Point1", "Point2"}) do
        local region = WorldBoss:FindFirstChild(pointName)
        if region and part:IsDescendantOf(region) then
            return pointName
        end
    end
    return nil
end

-- Teleport Boss Point via WorldFp -> Teleport -> Boss Point (smooth)
local function teleportToBossPoint(pointName)
    local destPos, destLook
    if pointName == "Point1" then
        destPos  = BOSS_POINT1_POSITION
        destLook = BOSS_POINT1_LOOKAT
    elseif pointName == "Point2" then
        destPos  = BOSS_POINT2_POSITION
        destLook = BOSS_POINT2_LOOKAT
    else
        return
    end
    if not destPos then
        return
    end

    local telePart = getTeleportPartForPoint(pointName)
    if telePart and telePart:IsA("BasePart") then
        local telePos = telePart.Position + Vector3.new(0, 4, 0)

        smoothTeleportTo(telePos, telePart.Position)

        local startTime = os.clock()
        local timeout   = 3
        while os.clock() - startTime < timeout do
            task.wait(0.1)

            local hrp = getHRP()
            if not hrp then
                break
            end

            local curPos   = hrp.Position
            local fromTele = (curPos - telePos).Magnitude
            local toDest   = (curPos - destPos).Magnitude

            if fromTele > 20 or toDest < 900 then
                break
            end
        end
    end

    smoothTeleportTo(destPos, destLook)
end

local function scheduleAutoTeleport(targetPointName, modeTag, fromRegionName)
    local targetRegionName = (targetPointName == "Point1") and "Point1" or "Point2"
    local remainSecForTarget = getRegionRemainSeconds(targetRegionName)
    local extraText = ""
    if remainSecForTarget ~= nil and remainSecForTarget >= 0 then
        extraText = " " .. formatBossRemainingText(remainSecForTarget)
    end

    if autoChestEnabled then
        pendingTeleportTarget    = targetPointName
        pendingTeleportMode      = modeTag
        pendingTeleportCreatedAt = os.clock()
        pendingTeleportAt        = nil

        notify(
            "Spear Fish Farm",
            string.format(
                "Boss in %s is dead. Waiting for Chest to finish, then AutoTP to %s.%s",
                tostring(fromRegionName),
                targetPointName,
                extraText
            ),
            5
        )
    else
        pendingTeleportTarget    = targetPointName
        pendingTeleportMode      = modeTag
        pendingTeleportCreatedAt = nil
        pendingTeleportAt        = os.clock()

        notify(
            "Spear Fish Farm",
            string.format(
                "Boss in %s is dead. AutoChest OFF, teleport directly to %s.%s",
                tostring(fromRegionName),
                targetPointName,
                extraText
            ),
            5
        )
    end
end

--==========================================================
--  AUTO TELEPORT BOSS CHECK (WITH REGION/CHEST FALLBACK)
--==========================================================
local function autoTeleportBossCheck()
    local nowAlive = isBossAlive()
    if nowAlive and currentBossTargetPart then
        local regionName = getRegionForBossPart(currentBossTargetPart)
        if regionName == "Point1" or regionName == "Point2" then
            lastBossRegionForTp = regionName
        end
    end

    if lastBossAliveForTp and not nowAlive and not pendingTeleportTarget then
        local region = lastBossRegionForTp

        if region == "Point2" then
            if autoTpPoint1Enabled and tp1CycleState == 0 then
                scheduleAutoTeleport("Point1", "P1_FWD", "Point2")
            elseif autoTpPoint2Enabled and tp2CycleState == 1 then
                scheduleAutoTeleport("Point1", "P2_BACK_BOSS", "Point2")
            end

        elseif region == "Point1" then
            if autoTpPoint2Enabled and tp2CycleState == 0 then
                scheduleAutoTeleport("Point2", "P2_FWD", "Point1")
            elseif autoTpPoint1Enabled and tp1CycleState == 1 then
                scheduleAutoTeleport("Point2", "P1_BACK_BOSS", "Point1")
            end
        end
    end

    lastBossAliveForTp = nowAlive

    if not nowAlive and not pendingTeleportTarget then
        if autoTpPoint1Enabled and tp1CycleState == 1 then
            local sec = getRegionRemainSeconds("Point1")
            if sec and sec > NEAR_REMAIN_THRESHOLD then
                scheduleAutoTeleport("Point2", "P1_BACK_REMAIN", "Point1")
            end
        end

        if autoTpPoint2Enabled and tp2CycleState == 1 then
            local sec = getRegionRemainSeconds("Point2")
            if sec and sec > NEAR_REMAIN_THRESHOLD then
                scheduleAutoTeleport("Point1", "P2_BACK_REMAIN", "Point2")
            end
        end
    end

    if pendingTeleportTarget then
        if autoChestEnabled then
            if chestJustFinishedFlag then
                chestJustFinishedFlag     = false
                local dest = pendingTeleportTarget
                local mode = pendingTeleportMode

                pendingTeleportTarget     = nil
                pendingTeleportAt         = nil
                pendingTeleportCreatedAt  = nil
                pendingTeleportMode       = nil

                teleportToBossPoint(dest)
                notify("Spear Fish Farm", "Chest finished. AutoTP to " .. dest .. ".", 4)

                if mode == "P1_FWD" then
                    tp1CycleState = 1
                elseif mode == "P1_BACK_BOSS" or mode == "P1_BACK_REMAIN" then
                    tp1CycleState = 0
                elseif mode == "P2_FWD" then
                    tp2CycleState = 1
                elseif mode == "P2_BACK_BOSS" or mode == "P2_BACK_REMAIN" then
                    tp2CycleState = 0
                end

            else
                if pendingTeleportCreatedAt and (os.clock() - pendingTeleportCreatedAt) > AUTOTP_CHEST_FALLBACK then
                    if chestActivityFlag then
                        pendingTeleportCreatedAt = nil
                        notify(
                            "Spear Fish Farm",
                            "AutoTP fallback: Chest is still active after " ..
                                tostring(AUTOTP_CHEST_FALLBACK) ..
                                "s. Waiting for Chest to finish + Last Location before teleport.",
                            5
                        )
                    else
                        local dest = pendingTeleportTarget
                        local mode = pendingTeleportMode

                        pendingTeleportTarget     = nil
                        pendingTeleportAt         = nil
                        pendingTeleportCreatedAt  = nil
                        pendingTeleportMode       = nil

                        teleportToBossPoint(dest)
                        notify(
                            "Spear Fish Farm",
                            "AutoTP fallback (Chest not detected for " ..
                                tostring(AUTOTP_CHEST_FALLBACK) ..
                                "s). Teleport to " .. dest .. ".",
                            4
                        )

                        if mode == "P1_FWD" then
                            tp1CycleState = 1
                        elseif mode == "P1_BACK_BOSS" or mode == "P1_BACK_REMAIN" then
                            tp1CycleState = 0
                        elseif mode == "P2_FWD" then
                            tp2CycleState = 1
                        elseif mode == "P2_BACK_BOSS" or mode == "P2_BACK_REMAIN" then
                            tp2CycleState = 0
                        end
                    end
                end
            end
        else
            if pendingTeleportAt and os.clock() >= pendingTeleportAt then
                local dest = pendingTeleportTarget
                local mode = pendingTeleportMode

                pendingTeleportTarget     = nil
                pendingTeleportAt         = nil
                pendingTeleportCreatedAt  = nil
                pendingTeleportMode       = nil

                teleportToBossPoint(dest)
                notify("Spear Fish Farm", "AutoTP to " .. dest .. " (AutoChest OFF).", 4)

                if mode == "P1_FWD" then
                    tp1CycleState = 1
                elseif mode == "P1_BACK_BOSS" or mode == "P1_BACK_REMAIN" then
                    tp1CycleState = 0
                elseif mode == "P2_FWD" then
                    tp2CycleState = 1
                elseif mode == "P2_BACK_BOSS" or mode == "P2_BACK_REMAIN" then
                    tp2CycleState = 0
                end
            end
        end
    else
        chestJustFinishedFlag = false
    end
end

------------------- RARITY FILTER LOGIC -------------------
local function baseFlagsAllowFish(seaName, fishName)
    if autoFarmAll then
        return true
    end

    if autoFarmRare then
        if seaName == "Sea4" and RARE_SEA4_SET[fishName] then
            return true
        end
        if seaName == "Sea5" and RARE_SEA5_SET[fishName] then
            return true
        end
        if seaName == "Sea8" and RARE_SEA8_SET[fishName] then
            return true
        end
        if seaName == "Sea9" and RARE_SEA9_SET[fishName] then
            return true
        end
    end

    if autoFarmIllahi then
        if (seaName == "Sea6" or seaName == "Sea7" or seaName == "Sea8" or seaName == "Sea9" or seaName == "Sea10") and ILLAHI_SET[fishName] then
            return true
        end
    end

    return false
end

local function isRareTypeFish(seaName, fishName)
    if seaName == "Sea4" and RARE_SEA4_SET[fishName] then
        return true
    end
    if seaName == "Sea5" and RARE_SEA5_SET[fishName] then
        return true
    end
    if seaName == "Sea8" and RARE_SEA8_SET[fishName] then
        return true
    end
    if seaName == "Sea9" and RARE_SEA9_SET[fishName] then
        return true
    end
    if (seaName == "Sea6" or seaName == "Sea7" or seaName == "Sea8" or seaName == "Sea9" or seaName == "Sea10") and ILLAHI_SET[fishName] then
        return true
    end
    return false
end

local function anyIllahiPerFishEnabled()
    for fishId, _ in pairs(ILLAHI_SET) do
        if PER_FISH_FLAGS[fishId] == true then
            return true
        end
    end
    return false
end

local function shouldTargetFish(seaName, fishName)
    if not fishName or fishName == "" then
        return false
    end

    if BOSS_IDS[fishName] then
        return false
    end

    if not baseFlagsAllowFish(seaName, fishName) then
        return false
    end

    if ILLAHI_SET[fishName] then
        if anyIllahiPerFishEnabled() then
            return PER_FISH_FLAGS[fishName] == true
        end
    end

    if rarityModeIndex == 1 then
        return true
    elseif rarityModeIndex == 2 then
        return isRareTypeFish(seaName, fishName)
    elseif rarityModeIndex == 3 then
        return PER_FISH_FLAGS[fishName] == true
    end

    return false
end

------------------- AUTO FARM FISH (SEA) -------------------
local currentFishTarget      = nil
local currentFishTargetSea   = nil

local function pickNewFishTarget(seaEntries)
    if not seaEntries or #seaEntries == 0 then
        return nil
    end

    if not (autoFarmAll or autoFarmRare or autoFarmIllahi) then
        return nil
    end

    local hrp = getHRP()
    if not hrp then
        return nil
    end
    local hrpPos = hrp.Position

    local closestFish
    local closestPart
    local bestDist = math.huge
    local chosenSeaName = nil

    for _, entry in ipairs(seaEntries) do
        local seaFolder = entry.folder
        local seaName   = entry.seaName

        if seaFolder then
            for _, obj in ipairs(seaFolder:GetChildren()) do
                if typeof(obj) == "Instance" and obj.Name and obj.Name:sub(1, 4) == "Fish" then
                    if shouldTargetFish(seaName, obj.Name) then
                        local hitPos = getHitPosFromFishInstance(obj)
                        if hitPos and isInRange(hitPos) then
                            local d = (hitPos - hrpPos).Magnitude
                            if d < bestDist then
                                bestDist   = d
                                closestFish = obj

                                local p
                                if obj:IsA("BasePart") then
                                    p = obj
                                elseif obj:IsA("Model") then
                                    p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                                end
                                closestPart  = p
                                chosenSeaName = seaName
                            end
                        end
                    end
                end
            end
        end
    end

    if closestFish and closestPart then
        currentFishTarget    = closestFish
        currentFishTargetSea = chosenSeaName

        local dispName = resolveFishDisplayName(closestFish.Name)
        setAimLockTarget(closestPart, dispName)
        return closestFish
    end

    currentFishTarget    = nil
    currentFishTargetSea = nil
    clearAimLockVisual()
    return nil
end

local function processAutoFarmFishStep()
    if autoFarmBoss and isBossAlive() then
        return
    end

    if not (autoFarmAll or autoFarmRare or autoFarmIllahi) then
        return
    end

    local tool = ensureToolEquipped()
    if not tool then
        return
    end

    local seaEntries, _ = getActiveSeaEntries()
    if not seaEntries or #seaEntries == 0 then
        return
    end

    local target = currentFishTarget

    local function isValidTarget(fish)
        if not fish or not fish.Parent then
            return false
        end

        local seaNameForFish = nil
        for _, entry in ipairs(seaEntries) do
            if fish:IsDescendantOf(entry.folder) then
                seaNameForFish = entry.seaName
                break
            end
        end
        if not seaNameForFish then
            return false
        end

        if not shouldTargetFish(seaNameForFish, fish.Name) then
            return false
        end

        local pos = getHitPosFromFishInstance(fish)
        if not pos or not isInRange(pos) then
            return false
        end
        return true
    end

    if aimLockEnabled then
        if not isValidTarget(target) then
            target = pickNewFishTarget(seaEntries)
            if not target then
                return
            end
        end
    else
        target = pickNewFishTarget(seaEntries)
        if not target then
            return
        end
    end

    local hitPos = getHitPosFromFishInstance(target)
    if not hitPos then
        currentFishTarget = nil
        return
    end

    sendFireThenHit(target, hitPos, tool)
    task.wait(farmDelay)
end

------------------- AUTO FARM BOSS -------------------
local function getBossPartInRegion(region)
    if not region then
        return nil
    end
    local ok, descendants = pcall(function()
        return region:GetDescendants()
    end)
    if not ok or not descendants then
        return nil
    end

    for _, inst in ipairs(descendants) do
        if inst:IsA("BasePart") then
            if BOSS_IDS[inst.Name] then
                return inst
            end
            local hpAttr = inst:GetAttribute("CurHP")
                or inst:GetAttribute("CurHp")
                or inst:GetAttribute("HP")
                or inst:GetAttribute("Hp")
            if hpAttr ~= nil then
                return inst
            end
        end
    end
    return nil
end

local function pickBossTarget()
    if not WorldBoss then
        WorldBoss = workspace:FindFirstChild("WorldBoss")
        if not WorldBoss then
            return nil
        end
    end

    local hrp = getHRP()
    if not hrp then
        return nil
    end
    local hrpPos = hrp.Position

    local bestPart
    local bestDist = math.huge

    for _, pointName in ipairs({"Point1", "Point2"}) do
        local region = WorldBoss:FindFirstChild(pointName)
        if region then
            local bossPart = getBossPartInRegion(region)
            if bossPart and bossPart.Parent then
                local pos = bossPart.Position
                local d = (pos - hrpPos).Magnitude
                if d < bestDist and d <= shootRange then
                    bestDist = d
                    bestPart = bossPart
                end
            end
        end
    end

    if bestPart then
        currentBossTarget     = bestPart
        currentBossTargetPart = bestPart

        local dispName = resolveBossDisplayName(bestPart.Name)
        setAimLockTarget(bestPart, dispName)
        return bestPart
    end

    currentBossTarget     = nil
    currentBossTargetPart = nil
    return nil
end

local function processAutoFarmBossStep()
    if not autoFarmBoss then
        return
    end

    local tool = ensureToolEquipped()
    if not tool then
        return
    end

    local target = currentBossTarget

    local function isValidBoss(part)
        if not part or part.Parent == nil then
            return false
        end
        local pos = part.Position
        if not isInRange(pos) then
            return false
        end
        local curHp = part:GetAttribute("CurHP")
            or part:GetAttribute("CurHp")
            or part:GetAttribute("HP")
            or part:GetAttribute("Hp")
        if curHp ~= nil and tonumber(curHp) <= 0 then
            return false
        end
        return true
    end

    if not isValidBoss(target) then
        target = pickBossTarget()
        if not target then
            return
        end
    end

    local pos = target.Position
    sendFireThenHit(target, pos, tool)
    task.wait(farmDelay)
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
    title.Text = "Spear Fish Farm V1. (LITE 3)"

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
    subtitle.Text = "Auto Farm + Boss Priority + Divine (Nether + Under Water)."

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
    height = height or 480

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
    button.Size = UDim2.new(1, 0, 0, 30)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    setToggleButtonState(button, labelText, initialState)
    return button
end

local function createSliderWithBox(parent, titleText, minValue, maxValue, initialValue, decimals, onChanged)
    decimals = decimals or 0
    local factor = 10 ^ decimals
    local value  = initialValue

    local frame = Instance.new("Frame")
    frame.Name = titleText or "Slider"
    frame.Parent = parent
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 54)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(185, 185, 185)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Size = UDim2.new(0.6, 0, 0, 18)
    label.Text = titleText or "Slider"

    local box = Instance.new("TextBox")
    box.Name = "ValueBox"
    box.Parent = frame
    box.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamSemibold
    box.TextSize = 11
    box.TextColor3 = Color3.fromRGB(230, 230, 230)
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Position = UDim2.new(0.62, 0, 0, 0)
    box.Size = UDim2.new(0.38, 0, 0, 18)

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = box

    local sliderBack = Instance.new("Frame")
    sliderBack.Name = "SliderBack"
    sliderBack.Parent = frame
    sliderBack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sliderBack.BorderSizePixel = 0
    sliderBack.Position = UDim2.new(0, 0, 0, 24)
    sliderBack.Size = UDim2.new(1, 0, 0, 16)

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 6)
    sliderCorner.Parent = sliderBack

    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Parent = sliderBack
    sliderFill.BackgroundColor3 = Color3.fromRGB(120, 180, 80)
    sliderFill.BorderSizePixel = 0
    sliderFill.Size = UDim2.new(0, 0, 1, 0)

    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(0, 6)
    sliderFillCorner.Parent = sliderFill

    local dragging = false

    local function applyValue(newValue)
        newValue = math.clamp(newValue, minValue, maxValue)
        value = math.floor(newValue * factor + 0.5) / factor
        box.Text = string.format("%." .. decimals .. "f", value)

        local backSize = sliderBack.AbsoluteSize.X
        if backSize > 0 then
            local alpha = (value - minValue) / (maxValue - minValue)
            sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
        end

        if onChanged then
            onChanged(value)
        end
    end

    local function setFromX(x)
        local pos = sliderBack.AbsolutePosition.X
        local size = sliderBack.AbsoluteSize.X
        if size <= 0 then
            return
        end
        local alpha = math.clamp((x - pos) / size, 0, 1)
        local newValue = minValue + (maxValue - minValue) * alpha
        applyValue(newValue)
    end

    table.insert(connections, sliderBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end))
    table.insert(connections, sliderBack.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end))
    table.insert(connections, box.FocusLost:Connect(function()
        local raw = (box.Text or ""):gsub(",", ".")
        local num = tonumber(raw)
        if not num then
            applyValue(value)
            return
        end
        applyValue(num)
    end))

    applyValue(initialValue)
    return frame
end

------------------- STATUS LABEL -------------------
local function updateStatusLabel()
    -- Status text removed, no text at bottom so lower headers stay clean
end

------------------- CLIMATE + PER FISH UI SYNC -------------------
local perFishContainer
local perFishInfoLabel
local lastPerFishSeaName   = nil
local lastPerFishClimate   = nil

local function normalizeClimateName(raw)
    if not raw then
        return nil
    end
    local s = string.lower(tostring(raw))
    if s:find("grass") then return "Grassland" end
    if s:find("marsh") or s:find("swamp") then return "Marsh" end
    if s:find("ice") or s:find("frost") or s:find("snow") then return "Iceborne" end
    return nil
end

local function getCurrentClimateTag()
    local v = workspace:GetAttribute("Climate") or workspace:GetAttribute("ClimateName") or workspace:GetAttribute("CurClimate")
    local tag = normalizeClimateName(v)
    if tag then return tag end

    v = LocalPlayer and (LocalPlayer:GetAttribute("Climate") or LocalPlayer:GetAttribute("CurClimate"))
    tag = normalizeClimateName(v)
    if tag then return tag end

    local cands = {"Climate","CurClimate","ClimateName"}
    for _, name in ipairs(cands) do
        local inst = ReplicatedStorage:FindFirstChild(name)
        if inst and inst:IsA("StringValue") then
            tag = normalizeClimateName(inst.Value)
            if tag then
                return tag
            end
        end
    end

    return nil
end

local function getPerFishCandidates()
    local uiMode = seaModeList[seaModeIndex] or "AutoDetect"
    local _, detectedSeaName = detectCurrentSea()

    local allowedSeas = {}
    local seaText

    if uiMode == "Sea6_7" then
        allowedSeas["Sea6"] = true
        allowedSeas["Sea7"] = true
        seaText = "Sea6_7"
    elseif uiMode == "Sea4" or uiMode == "Sea5" or uiMode == "Sea6" or uiMode == "Sea7" or uiMode == "Sea8" or uiMode == "Sea9" or uiMode == "Sea10" then
        allowedSeas[uiMode] = true
        seaText = uiMode
    else
        if detectedSeaName and (
            detectedSeaName == "Sea4"
            or detectedSeaName == "Sea5"
            or detectedSeaName == "Sea6"
            or detectedSeaName == "Sea7"
            or detectedSeaName == "Sea8"
            or detectedSeaName == "Sea9"
            or detectedSeaName == "Sea10"
        ) then
            allowedSeas[detectedSeaName] = true
            seaText = detectedSeaName
        else
            return {}, detectedSeaName, nil
        end
    end

    local climateTag = getCurrentClimateTag()
    local result = {}

    -- FIX: filter By Fish purely based on active Sea (without overriding to Sea6-7)
    local function allowCfgForSea(cfg)
        if not cfg.sea then
            return true
        end
        return allowedSeas[cfg.sea] == true
    end

    for _, cfg in ipairs(PER_FISH_CONFIG) do
        if allowCfgForSea(cfg) then
            if not cfg.climates or not climateTag then
                table.insert(result, cfg)
            else
                for _, c in ipairs(cfg.climates) do
                    if c == climateTag then
                        table.insert(result, cfg)
                        break
                    end
                end
            end
        end
    end

    return result, seaText, climateTag
end

local function refreshPerFishButtons(force)
    if not perFishContainer then
        return
    end

    local configs, seaName, climateTag = getPerFishCandidates()
    if not force and seaName == lastPerFishSeaName and climateTag == lastPerFishClimate then
        return
    end
    lastPerFishSeaName = seaName
    lastPerFishClimate = climateTag

    for _, child in ipairs(perFishContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    if perFishInfoLabel then
        local locationText = getSeaDisplayNameForUi(seaName or "") or "Unknown"
        local climateText  = climateTag or "All"
        perFishInfoLabel.Text = string.format("By Fish (Location: %s, Climate: %s) - %d option.", locationText, climateText, #configs)
    end

    for _, cfg in ipairs(configs) do
        local btn = createToggleButton(perFishContainer, cfg.name, PER_FISH_FLAGS[cfg.id])
        table.insert(connections, btn.MouseButton1Click:Connect(function()
            local newState = not PER_FISH_FLAGS[cfg.id]
            PER_FISH_FLAGS[cfg.id] = newState
            setToggleButtonState(btn, cfg.name, newState)
        end))
    end
end

------------------- BUILD UI CARD: AUTO FARM SPEAR -------------------
local function buildAutoFarmCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "Auto Farm - Spear Fishing",
        "Priority Boss + Rare + Divine (Nether + Under Water). AimLock fish + ESP.",
        1,
        580
    )

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "AutoFarmScroll"
    scroll.Parent = card
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 0, 0, 48)
    scroll.Size = UDim2.new(1, 0, 1, -48)
    scroll.ScrollBarThickness = 4
    scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end))

    local autoFarmAllButton    = createToggleButton(scroll, "AutoFarm Universal", autoFarmAll)
    local autoFarmBossButton   = createToggleButton(scroll, "AutoFarm Boss Priority", autoFarmBoss)
    local autoFarmRareButton   = createToggleButton(scroll, "AutoFarm Mythic/Legendary/Secret", autoFarmRare)
    local autoFarmIllahiButton = createToggleButton(scroll, "AutoFarm Divine", autoFarmIllahi)

    -- Fire First toggle removed from UI, logic stays active (follows all AutoFarm)
    local aimLockButton        = createToggleButton(scroll, "AimLock Fish", aimLockEnabled)
    local espAntennaButton     = createToggleButton(scroll, "ESP Lines Fish", espAntennaEnabled)

    local seaModeButton = Instance.new("TextButton")
    seaModeButton.Name = "SeaModeButton"
    seaModeButton.Parent = scroll
    seaModeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    seaModeButton.BorderSizePixel  = 0
    seaModeButton.AutoButtonColor  = true
    seaModeButton.Font             = Enum.Font.Gotham
    seaModeButton.TextSize         = 11
    seaModeButton.TextColor3       = Color3.fromRGB(220, 220, 220)
    seaModeButton.TextWrapped      = true
    seaModeButton.Size             = UDim2.new(1, 0, 0, 26)

    local seaModeCorner = Instance.new("UICorner")
    seaModeCorner.CornerRadius = UDim.new(0, 8)
    seaModeCorner.Parent = seaModeButton

    local function updateSeaModeButtonText()
        local mode = seaModeList[seaModeIndex] or "AutoDetect"
        local desc
        if mode == "AutoDetect" then
            desc = "Auto Detect Location"
        else
            desc = getSeaDisplayNameForUi(mode)
        end
        seaModeButton.Text = "Sea Mode: " .. desc
    end
    updateSeaModeButtonText()

    local rarityModeButton = Instance.new("TextButton")
    rarityModeButton.Name = "RarityModeButton"
    rarityModeButton.Parent = scroll
    rarityModeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    rarityModeButton.BorderSizePixel  = 0
    rarityModeButton.AutoButtonColor  = true
    rarityModeButton.Font             = Enum.Font.Gotham
    rarityModeButton.TextSize         = 11
    rarityModeButton.TextColor3       = Color3.fromRGB(220, 220, 220)
    rarityModeButton.TextWrapped      = true
    rarityModeButton.Size             = UDim2.new(1, 0, 0, 26)

    local rarityModeCorner = Instance.new("UICorner")
    rarityModeCorner.CornerRadius = UDim.new(0, 8)
    rarityModeCorner.Parent = rarityModeButton

    local function updateRarityModeButtonText()
        if rarityModeIndex == 1 then
            rarityModeButton.Text = "Rarity Mode: Disabled (use AutoFarm toggles above)"
        elseif rarityModeIndex == 2 then
            rarityModeButton.Text = "Rarity Mode: Legendary/Mythic/Secret/Divine"
        else
            rarityModeButton.Text = "Rarity Mode: By Fish"
        end
    end
    updateRarityModeButtonText()

    createSliderWithBox(scroll, "Shooting Range 25 - 1000", SHOOT_RANGE_MIN, SHOOT_RANGE_MAX, shootRange, 0, function(val)
        shootRange = val
        updateStatusLabel()
    end)

    createSliderWithBox(scroll, "Farm Delay 0.01 - 0.30", FARM_DELAY_MIN, FARM_DELAY_MAX, farmDelay, 3, function(val)
        farmDelay = val
        updateStatusLabel()
    end)

    local perFishLabel = Instance.new("TextLabel")
    perFishLabel.Name = "PerFishLabel"
    perFishLabel.Parent = scroll
    perFishLabel.BackgroundTransparency = 1
    perFishLabel.Font = Enum.Font.GothamSemibold
    perFishLabel.TextSize = 12
    perFishLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    perFishLabel.TextXAlignment = Enum.TextXAlignment.Left
    perFishLabel.Size = UDim2.new(1, 0, 0, 18)
    perFishLabel.Text = "By Fish Selection:"

    perFishContainer = Instance.new("Frame")
    perFishContainer.Name = "PerFishContainer"
    perFishContainer.Parent = scroll
    perFishContainer.BackgroundTransparency = 1
    perFishContainer.BorderSizePixel = 0
    perFishContainer.Size = UDim2.new(1, 0, 0, 0)
    perFishContainer.AutomaticSize = Enum.AutomaticSize.Y

    local perFishLayout = Instance.new("UIListLayout")
    perFishLayout.Parent = perFishContainer
    perFishLayout.FillDirection = Enum.FillDirection.Vertical
    perFishLayout.SortOrder = Enum.SortOrder.LayoutOrder
    perFishLayout.Padding = UDim.new(0, 4)

    perFishInfoLabel = Instance.new("TextLabel")
    perFishInfoLabel.Name = "PerFishInfo"
    perFishInfoLabel.Parent = perFishContainer
    perFishInfoLabel.BackgroundTransparency = 1
    perFishInfoLabel.Font = Enum.Font.Gotham
    perFishInfoLabel.TextSize = 11
    perFishInfoLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
    perFishInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    perFishInfoLabel.TextWrapped = true
    perFishInfoLabel.Size = UDim2.new(1, 0, 0, 30)
    perFishInfoLabel.Text = "By Fish (Location: -, Climate: -)."

    updateStatusLabel()
    refreshPerFishButtons(true)

    table.insert(connections, autoFarmAllButton.MouseButton1Click:Connect(function()
        autoFarmAll = not autoFarmAll
        setToggleButtonState(autoFarmAllButton, "AutoFarm Universal", autoFarmAll)
        updateFireFirstState()
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Universal: " .. (autoFarmAll and "ON" or "OFF"), 2)
    end))
    table.insert(connections, autoFarmBossButton.MouseButton1Click:Connect(function()
        autoFarmBoss = not autoFarmBoss
        setToggleButtonState(autoFarmBossButton, "AutoFarm Boss Priority", autoFarmBoss)
        updateFireFirstState()
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Boss Priority: " .. (autoFarmBoss and "ON" or "OFF"), 2)
    end))
    table.insert(connections, autoFarmRareButton.MouseButton1Click:Connect(function()
        autoFarmRare = not autoFarmRare
        setToggleButtonState(autoFarmRareButton, "AutoFarm Mythic/Legendary/Secret", autoFarmRare)
        updateFireFirstState()
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Rare: " .. (autoFarmRare and "ON" or "OFF"), 2)
    end))
    table.insert(connections, autoFarmIllahiButton.MouseButton1Click:Connect(function()
        autoFarmIllahi = not autoFarmIllahi
        setToggleButtonState(autoFarmIllahiButton, "AutoFarm Divine", autoFarmIllahi)
        updateFireFirstState()
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoFarm Divine: " .. (autoFarmIllahi and "ON" or "OFF"), 2)
    end))

    table.insert(connections, aimLockButton.MouseButton1Click:Connect(function()
        aimLockEnabled = not aimLockEnabled
        setToggleButtonState(aimLockButton, "AimLock Fish", aimLockEnabled)
        updateStatusLabel()
        notify("Spear Fish Farm", "AimLock: " .. (aimLockEnabled and "ON" or "OFF"), 2)
    end))
    table.insert(connections, espAntennaButton.MouseButton1Click:Connect(function()
        espAntennaEnabled = not espAntennaEnabled
        setToggleButtonState(espAntennaButton, "ESP Lines Fish", espAntennaEnabled)
        refreshAllEsp()
        updateStatusLabel()
        notify("Spear Fish Farm", "ESP Lines Fish: " .. (espAntennaEnabled and "ON" or "OFF"), 2)
    end))
    table.insert(connections, seaModeButton.MouseButton1Click:Connect(function()
        seaModeIndex = seaModeIndex + 1
        if seaModeIndex > #seaModeList then seaModeIndex = 1 end
        updateSeaModeButtonText()
        updateStatusLabel()
        refreshPerFishButtons(true)
    end))
    table.insert(connections, rarityModeButton.MouseButton1Click:Connect(function()
        rarityModeIndex = rarityModeIndex + 1
        if rarityModeIndex > #rarityModeList then rarityModeIndex = 1 end
        updateRarityModeButtonText()
        updateStatusLabel()
        refreshPerFishButtons(true)
    end))
end

------------------- BUILD UI CARD: CHEST FARM + AUTOTP -------------------
local function buildChestFarmCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "Chest Farm",
        "Auto teleport to Chest and back to Last Location + AutoTP Boss",
        2,
        300
    )

    local container = Instance.new("Frame")
    container.Name = "ChestFarmContainer"
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

    local autoChestButton      = createToggleButton(container, "Auto Chest", autoChestEnabled)
    local lastLocButton        = createToggleButton(container, "Last Location", chestReturnEnabled)
    local autoTpPoint1Button   = createToggleButton(container, "AutoTP Humpback Whale & Whale Shark", autoTpPoint1Enabled)
    local autoTpPoint2Button   = createToggleButton(container, "AutoTP Crimson Rift Dragon", autoTpPoint2Enabled)

    table.insert(connections, autoChestButton.MouseButton1Click:Connect(function()
        autoChestEnabled = not autoChestEnabled
        setToggleButtonState(autoChestButton, "Auto Chest", autoChestEnabled)
        if not autoChestEnabled then
            chestCurrentTargetPart = nil
            lastLocationCFrame     = nil
            chestHadRecently       = false
            chestActivityFlag      = false
            chestJustFinishedFlag  = false
        end
        updateStatusLabel()
        notify("Spear Fish Farm", "Auto Chest: " .. (autoChestEnabled and "ON" or "OFF"), 2)
    end))

    table.insert(connections, lastLocButton.MouseButton1Click:Connect(function()
        chestReturnEnabled = not chestReturnEnabled
        setToggleButtonState(lastLocButton, "Last Location", chestReturnEnabled)
        if not chestReturnEnabled then
            lastLocationCFrame = nil
        end
        updateStatusLabel()
        notify("Spear Fish Farm", "Last Location: " .. (chestReturnEnabled and "ON" or "OFF"), 2)
    end))

    table.insert(connections, autoTpPoint1Button.MouseButton1Click:Connect(function()
        autoTpPoint1Enabled = not autoTpPoint1Enabled
        setToggleButtonState(autoTpPoint1Button, "AutoTP Humpback Whale & Whale Shark", autoTpPoint1Enabled)
        if not autoTpPoint1Enabled then
            tp1CycleState = 0
        end
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoTP Humpback Whale & Whale Shark: " .. (autoTpPoint1Enabled and "ON" or "OFF"), 2)
    end))

    table.insert(connections, autoTpPoint2Button.MouseButton1Click:Connect(function()
        autoTpPoint2Enabled = not autoTpPoint2Enabled
        setToggleButtonState(autoTpPoint2Button, "AutoTP Crimson Rift Dragon", autoTpPoint2Enabled)
        if not autoTpPoint2Enabled then
            tp2CycleState = 0
        end
        updateStatusLabel()
        notify("Spear Fish Farm", "AutoTP Crimson Rift Dragon: " .. (autoTpPoint2Enabled and "ON" or "OFF"), 2)
    end))
end

------------------- BUILD UI -------------------
local function buildAllUI()
    local _, bodyScroll = createMainLayout()
    buildAutoFarmCard(bodyScroll)
    buildChestFarmCard(bodyScroll)
end

buildAllUI()
updateFireFirstState()

------------------- BACKGROUND LOOPS -------------------
task.spawn(function()
    while alive do
        local ok, err = pcall(processAutoFarmFishStep)
        if not ok then warn("[SpearFishFarm] AutoFarmFish error:", err) end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while alive do
        local ok, err = pcall(processAutoFarmBossStep)
        if not ok then warn("[SpearFishFarm] AutoFarmBoss error:", err) end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while alive do
        pcall(updateAimLockDistanceLabel)
        task.wait(0.05)
    end
end)

-- OPTIMIZED: auto-refresh By Fish hanya saat benar-benar dipakai
task.spawn(function()
    while alive do
        pcall(function()
            -- Hanya scan Sea (detectCurrentSea) jika:
            -- 1) Rarity Mode = "By Fish" (index 3)
            -- 2) Ada AutoFarm berbasis ikan yang ON (All/Rare/Illahi)
            if rarityModeIndex == 3 and (autoFarmAll or autoFarmRare or autoFarmIllahi) then
                refreshPerFishButtons(false)
            end
        end)
        task.wait(3)
    end
end)

local function chestFarmStep()
    if not autoChestEnabled then
        return
    end

    local hrp = getHRP()
    if not hrp then
        return
    end

    local chestPart = getNearestChestPart()
    if chestPart then
        if chestReturnEnabled and not lastLocationCFrame then
            lastLocationCFrame = hrp.CFrame
        end

        if chestPart ~= chestCurrentTargetPart then
            chestCurrentTargetPart = chestPart
            chestHadRecently       = true

            local chestPos = chestPart.Position
            smoothTeleportTo(chestPos + Vector3.new(0, 4, 0), chestPos)
        end
    else
        if chestHadRecently then
            chestHadRecently       = false
            chestCurrentTargetPart = nil

            if chestReturnEnabled and lastLocationCFrame then
                local backPos = lastLocationCFrame.Position
                local lookPos = backPos + lastLocationCFrame.LookVector
                smoothTeleportTo(backPos, lookPos)
            end

            lastLocationCFrame = nil
        end
    end
end

task.spawn(function()
    while alive do
        local ok, err = pcall(chestFarmStep)
        if not ok then
            warn("[SpearFishFarm] ChestFarm error:", err)
        end

        local nowActive = false
        if autoChestEnabled and (chestHadRecently or chestCurrentTargetPart ~= nil or lastLocationCFrame ~= nil) then
            nowActive = true
        end

        if chestActivityFlag and not nowActive then
            chestJustFinishedFlag = true
        end

        chestActivityFlag = nowActive

        task.wait(0.1)
    end
end)

task.spawn(function()
    while alive do
        local ok, err = pcall(autoTeleportBossCheck)
        if not ok then
            warn("[SpearFishFarm] AutoTPBoss error:", err)
        end
        task.wait(0.2)
    end
end)

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    autoFarmAll        = false
    autoFarmBoss       = false
    autoFarmRare       = false
    autoFarmIllahi     = false
    fireFirstEnabled   = false
    aimLockEnabled     = false
    espAntennaEnabled  = false

    autoChestEnabled       = false
    chestReturnEnabled     = false
    lastLocationCFrame     = nil
    chestCurrentTargetPart = nil
    chestHadRecently       = false
    chestActivityFlag      = false
    chestJustFinishedFlag  = false

    autoTpPoint1Enabled    = false
    autoTpPoint2Enabled    = false
    lastBossAliveForTp     = false
    lastBossRegionForTp    = nil
    pendingTeleportTarget  = nil
    pendingTeleportAt      = nil
    pendingTeleportCreatedAt = nil
    pendingTeleportMode    = nil
    tp1CycleState          = 0
    tp2CycleState          = 0

    currentFishTarget      = nil
    currentFishTargetSea   = nil
    currentBossTarget      = nil
    currentBossTargetPart  = nil

    clearAimLockVisual()

    trackedFishEspTargets = {}
    fishEspMap            = {}

    if activeChestTween then
        pcall(function()
            activeChestTween:Cancel()
        end)
        activeChestTween = nil
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
