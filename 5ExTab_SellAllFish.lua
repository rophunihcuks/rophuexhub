--==========================================================
--  5ExTab_SellAllFish.lua
--  TAB 5: "Sell All Fish PRO++ (Smart Inventory Scanner + Filter Kg)"
--  Integrasi dengan EXHUB PANEL V1 / AxaHub-style:
--  - Menggunakan TAB_FRAME sebagai root UI tab
--  - Register ke _G.AxaHub.TabCleanup[tabId]
--==========================================================

------------------- ENV / SHORTCUT -------------------
local frame = TAB_FRAME
local tabId = TAB_ID or "sellallfish"

local Players           = Players           or game:GetService("Players")
local LocalPlayer       = LocalPlayer       or Players.LocalPlayer
local RunService        = RunService        or game:GetService("RunService")
local UserInputService  = UserInputService  or game:GetService("UserInputService")
local StarterGui        = StarterGui        or game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace         = workspace
local TweenService      = TweenService      or game:GetService("TweenService")
local TeleportService   = TeleportService   or game:GetService("TeleportService")
local HttpService       = HttpService       or game:GetService("HttpService")

if not (frame and LocalPlayer) then
    return
end

frame:ClearAllChildren()
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0

------------------- GLOBAL STATE -------------------
local alive       = true
local connections = {}

------------------- REMOTES -------------------
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Events")
local FishRE        = remotesFolder and remotesFolder:FindFirstChild("FishRE")

------------------- STATE -------------------
local currentInventory = {}  -- list entry ikan (tiap: {UID=string, ...})
local lastScanCount    = 0

local filterMode = "ALL"     -- "ALL", "MAX", "MIN", "RANGE"
local minKg      = 0
local maxKg      = 300

-- UI refs (diisi setelah build UI)
local infoLabel, resultLabel, modeButton, minBox, maxBox

------------------- NOTIFY -------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Sell All Fish PRO++",
            Text     = text or "",
            Duration = dur or 4
        })
    end)
end

------------------- HELPER: INVENTORY / DETEKSI IKAN -------------------
local function getWeight(entry)
    if type(entry) ~= "table" then return nil end

    if type(entry.Weight) == "number" then
        return entry.Weight
    end
    if type(entry.Size) == "number" then
        return entry.Size
    end
    if type(entry.KG) == "number" then
        return entry.KG
    end
    if type(entry.kg) == "number" then
        return entry.kg
    end

    if type(entry.Weight) == "string" then
        local n = tonumber(entry.Weight:match("(%d+%.?%d*)"))
        if n then return n end
    end

    return nil
end

local function isFishEntry(entry)
    if type(entry) ~= "table" then return false end
    if type(entry.UID) ~= "string" then return false end

    if not (entry.ID or entry.FishID or entry.Fish or entry.Name) then
        return false
    end

    return true
end

local function extractFishListFromTable(t)
    if type(t) ~= "table" then return nil end

    local listFish = {}
    for _, v in pairs(t) do
        if isFishEntry(v) then
            table.insert(listFish, v)
        end
    end

    if #listFish > 0 then
        return listFish
    end

    return nil
end

local function tryScanViaShared()
    local sharedModule = ReplicatedStorage:FindFirstChild("Shared")
    if not sharedModule then return nil end

    local ok, SharedFactory = pcall(require, sharedModule)
    if not ok or type(SharedFactory) ~= "function" then
        return nil
    end

    local candidateNames = {
        "Inventory", "PlayerInventory", "FishInventory",
        "Fishing", "FishClient", "Fish", "Storage",
        "PlayerData", "Data", "ItemStorage"
    }

    local bestList

    for _, name in ipairs(candidateNames) do
        local ok2, mod = pcall(SharedFactory, name)
        if ok2 and type(mod) == "table" then
            local listFish = extractFishListFromTable(mod)
            if listFish and #listFish > 0 then
                if not bestList or #listFish > #bestList then
                    bestList = listFish
                end
            end
        end
    end

    return bestList
end

local function tryScanViaGetGC()
    if not getgc then
        return nil
    end

    local bestList
    local bestLen = 0

    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            local listFish = extractFishListFromTable(obj)
            if listFish and #listFish > 0 then
                if #listFish > bestLen then
                    bestLen  = #listFish
                    bestList = listFish
                end
            end
        end
    end

    return bestList
end

local function scanInventory()
    local inv = tryScanViaShared()
    if not inv then
        inv = tryScanViaGetGC()
    end

    if not inv or #inv == 0 then
        currentInventory = {}
        lastScanCount    = 0
        if infoLabel then
            infoLabel.Text = "Status: Inventory tidak ditemukan (cek modul / struktur game)."
        end
        notify("Sell All Fish PRO++", "Inventory tidak ditemukan.", 3)
        return
    end

    currentInventory = inv
    lastScanCount    = #inv
    if infoLabel then
        infoLabel.Text = string.format("Status: Inventory ditemukan (%d ikan terbaca).", lastScanCount)
    end
    notify("Sell All Fish PRO++", "Inventory terbaca: " .. tostring(lastScanCount) .. " ikan.", 3)
end

------------------- HELPER: FILTER & UIDs -------------------
local function parseNumber(text, defaultValue)
    if not text or text == "" then
        return defaultValue
    end
    local n = tonumber(text)
    if not n then
        return defaultValue
    end
    return n
end

local function passesFilter(entry)
    if filterMode == "ALL" then
        return true
    end

    local w = getWeight(entry)
    if not w then
        return false
    end

    if filterMode == "MAX" then
        return w <= maxKg
    elseif filterMode == "MIN" then
        return w >= minKg
    elseif filterMode == "RANGE" then
        return (w >= minKg and w <= maxKg)
    end

    return true
end

local function buildUIDsFromInventory()
    local uids           = {}
    local countFiltered  = 0
    local countNoUID     = 0

    for _, fish in ipairs(currentInventory) do
        if passesFilter(fish) then
            countFiltered += 1
            if type(fish.UID) == "string" then
                table.insert(uids, fish.UID)
            else
                countNoUID += 1
            end
        end
    end

    return uids, countFiltered, countNoUID
end

------------------- HELPER: SCREEN MSG -------------------
local function sendScreenMsg(text)
    local screenMsg = LocalPlayer:FindFirstChild("ScreenMsg")
    if not screenMsg then
        return
    end

    local updateEvent = screenMsg:FindFirstChild("UpdateBE")
    if not updateEvent then
        return
    end

    local payload = {
        msg   = text,
        Param = {
            Clean = true,
        }
    }

    pcall(function()
        if updateEvent:IsA("BindableEvent") then
            updateEvent:Fire(payload)
        end
    end)
end

------------------- CORE-STYLE UI HELPERS -------------------
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
    title.Text = "Sell All Fish PRO++"

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
    subtitle.Text = "Smart Inventory Scanner + Kg Filter. One-click SellAll via FishRE."

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
    height = height or 320

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

local function makeLabel(parent, name, text, sizeY, textSize, bold, color3)
    local lbl = Instance.new("TextLabel")
    lbl.Name = name or "Label"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, sizeY)
    lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    lbl.TextSize = textSize
    lbl.TextColor3 = color3 or Color3.fromRGB(225, 230, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.TextWrapped = true
    lbl.Text = text
    lbl.RichText = true
    lbl.Parent = parent
    return lbl
end

local function makeButton(parent, name, text, sizeY)
    local btn = Instance.new("TextButton")
    btn.Name = name or "Button"
    btn.Size = UDim2.new(1, 0, 0, sizeY)
    btn.BackgroundColor3 = Color3.fromRGB(40, 110, 255)
    btn.AutoButtonColor = true
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(245, 247, 255)
    btn.Text = text
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

local function makeTextbox(parent, name, placeholder, sizeY)
    local box = Instance.new("TextBox")
    box.Name = name or "Input"
    box.Size = UDim2.new(1, 0, 0, sizeY)
    box.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
    box.TextColor3 = Color3.fromRGB(235, 240, 255)
    box.PlaceholderText = placeholder
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Text = ""
    box.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = box

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.Parent = box

    return box
end

------------------- UI HELPER: REFRESH MODE TEXT -------------------
local function refreshFilterModeText()
    if not modeButton then return end

    local text
    if filterMode == "ALL" then
        text = "Mode Filter: ALL (semua ikan)"
    elseif filterMode == "MAX" then
        text = string.format("Mode Filter: <= Max Kg (%.2f)", maxKg)
    elseif filterMode == "MIN" then
        text = string.format("Mode Filter: >= Min Kg (%.2f)", minKg)
    elseif filterMode == "RANGE" then
        text = string.format("Mode Filter: RANGE [%.2f - %.2f] Kg", minKg, maxKg)
    else
        text = "Mode Filter: (UNKNOWN)"
    end
    modeButton.Text = text
end

------------------- BUILD UI CARD: SELL ALL FISH -------------------
local function buildSellAllCard(bodyScroll)
    local card = createCard(
        bodyScroll,
        "Inventory Scanner + SellAll",
        "Scan inventory ikan (via Shared / getgc), pilih mode filter Kg, lalu kirim SellAll ke server.\nTidak ada loop berat, hanya jalan saat tombol ditekan.",
        1,
        260
    )

    local container = Instance.new("Frame")
    container.Name = "SellAllContainer"
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

    infoLabel = makeLabel(
        container,
        "Status",
        "Status: Belum scan inventory.",
        20,
        12,
        false,
        Color3.fromRGB(180, 220, 255)
    )
    infoLabel.LayoutOrder = 1

    modeButton = makeButton(container, "ModeButton", "Mode Filter: ALL (semua ikan)", 26)
    modeButton.LayoutOrder = 2

    minBox = makeTextbox(container, "MinKgBox", "Min Kg (untuk mode >= / RANGE) - kosong = 0", 24)
    minBox.LayoutOrder = 3

    maxBox = makeTextbox(container, "MaxKgBox", "Max Kg (untuk mode <= / RANGE) - kosong = 300", 24)
    maxBox.LayoutOrder = 4

    local scanButton = makeButton(container, "ScanButton", "Scan Inventory Ikan", 26)
    scanButton.LayoutOrder = 5

    local sellButton = makeButton(container, "SellButton", "Sell All (Sesuai Filter)", 26)
    sellButton.LayoutOrder = 6

    resultLabel = makeLabel(
        container,
        "Result",
        "Detail: TAB siap. Tekan 'Scan Inventory Ikan' lalu 'Sell All' sesuai filter.",
        40,
        12,
        false,
        Color3.fromRGB(190, 220, 190)
    )
    resultLabel.LayoutOrder = 7

    refreshFilterModeText()

    ------------------- EVENTS -------------------
    table.insert(connections, modeButton.MouseButton1Click:Connect(function()
        if filterMode == "ALL" then
            filterMode = "MAX"
        elseif filterMode == "MAX" then
            filterMode = "MIN"
        elseif filterMode == "MIN" then
            filterMode = "RANGE"
        else
            filterMode = "ALL"
        end

        minKg = parseNumber(minBox.Text, 0)
        maxKg = parseNumber(maxBox.Text, 300)
        refreshFilterModeText()
    end))

    table.insert(connections, minBox.FocusLost:Connect(function(_enterPressed)
        minKg = parseNumber(minBox.Text, 0)
        if filterMode == "MIN" or filterMode == "RANGE" then
            refreshFilterModeText()
        end
    end))

    table.insert(connections, maxBox.FocusLost:Connect(function(_enterPressed)
        maxKg = parseNumber(maxBox.Text, 300)
        if filterMode == "MAX" or filterMode == "RANGE" then
            refreshFilterModeText()
        end
    end))

    table.insert(connections, scanButton.MouseButton1Click:Connect(function()
        scanInventory()
        resultLabel.Text = string.format(
            "Detail: Hasil scan terakhir = %d ikan terdeteksi di inventory.",
            lastScanCount
        )
        sendScreenMsg(string.format("[SellAllFish] Scan inventory: %d ikan terbaca.", lastScanCount))
    end))

    table.insert(connections, sellButton.MouseButton1Click:Connect(function()
        if not FishRE then
            infoLabel.Text   = "Status: Remote 'FishRE' tidak ditemukan di ReplicatedStorage.Remotes."
            resultLabel.Text = "Detail: Pastikan nama remote FishRE benar."
            sendScreenMsg("[SellAllFish] Gagal SellAll: Remote FishRE tidak ditemukan.")
            notify("Sell All Fish PRO++", "Remote FishRE tidak ditemukan.", 4)
            return
        end

        if #currentInventory == 0 then
            scanInventory()
            if #currentInventory == 0 then
                resultLabel.Text = "Detail: Gagal SellAll, inventory kosong / tidak terdeteksi."
                sendScreenMsg("[SellAllFish] Gagal SellAll: inventory tidak ditemukan.")
                notify("Sell All Fish PRO++", "Inventory kosong / tidak terdeteksi.", 4)
                return
            end
        end

        minKg = parseNumber(minBox.Text, 0)
        maxKg = parseNumber(maxBox.Text, 300)
        refreshFilterModeText()

        local uids, countFiltered, countNoUID = buildUIDsFromInventory()

        if #uids == 0 then
            resultLabel.Text = string.format(
                "Detail: Tidak ada ikan yang lolos filter. Total terbaca: %d, Terfilter: %d, Tanpa UID: %d.",
                lastScanCount, countFiltered, countNoUID
            )
            sendScreenMsg("[SellAllFish] Tidak ada ikan yang sesuai filter untuk dijual.")
            notify("Sell All Fish PRO++", "Tidak ada ikan yang sesuai filter.", 4)
            return
        end

        local args = {
            [1] = "SellAll",
            [2] = {
                UIDs = uids
            }
        }

        local ok, err = pcall(function()
            FishRE:FireServer(unpack(args))
        end)

        if ok then
            local msg = string.format(
                "Berhasil kirim SellAll: %d ikan (UID) ke server. Mode=%s, Range=[%.2f, %.2f].",
                #uids, filterMode, minKg, maxKg
            )
            resultLabel.Text = "Detail: " .. msg
            sendScreenMsg("[SellAllFish] " .. msg)
            notify("Sell All Fish PRO++", "SellAll terkirim: " .. tostring(#uids) .. " ikan.", 4)
        else
            local msg = "Gagal FireServer SellAll: " .. tostring(err)
            resultLabel.Text = "Detail: " .. msg
            sendScreenMsg("[SellAllFish] " .. msg)
            notify("Sell All Fish PRO++", "SellAll gagal: cek output.", 4)
        end
    end))
end

------------------- BUILD UI -------------------
local function buildAllUI()
    local _, bodyScroll = createMainLayout()
    buildSellAllCard(bodyScroll)
end

buildAllUI()

------------------- TAB CLEANUP -------------------
_G.AxaHub.TabCleanup[tabId] = function()
    alive = false

    currentInventory = {}
    lastScanCount    = 0

    filterMode = "ALL"
    minKg      = 0
    maxKg      = 300

    infoLabel   = nil
    resultLabel = nil
    modeButton  = nil
    minBox      = nil
    maxBox      = nil

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
