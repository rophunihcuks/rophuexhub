--==========================================================
--  5ExTab_SellAllFish.lua
--  TAB 5: "Sell All Fish PRO++ (Smart Inventory Scanner + Filter Kg)"
--  Integrasi dengan EXHUB PANEL V1 / AxaHub-style:
--  - Menggunakan TAB_FRAME sebagai root UI tab
--  - Register ke _G.ExHub.TabCleanup dan _G.AxaHub.TabCleanup
--==========================================================

------------------- ENV / SHORTCUT -------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer       = Players.LocalPlayer

-- Diisi oleh CORE EXHUB PANEL V1
local frame = rawget(getfenv(), "TAB_FRAME")
local tabId = rawget(getfenv(), "TAB_ID") or "sellallfish"

if not frame or not frame.IsA or not frame:IsA("Frame") then
    warn("[5AxaTab_SellAllFish] TAB_FRAME tidak valid, tab tidak di-init.")
    return
end

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

-- untuk TabCleanup
local connections = {}

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

    -- kalau string, coba parse "123 Kg"
    if type(entry.Weight) == "string" then
        local n = tonumber(entry.Weight:match("(%d+%.?%d*)"))
        if n then return n end
    end

    return nil
end

local function isFishEntry(entry)
    if type(entry) ~= "table" then return false end
    if type(entry.UID) ~= "string" then return false end

    -- identitas ikan minimal
    if not (entry.ID or entry.FishID or entry.Fish or entry.Name) then
        return false
    end

    -- berat boleh nil (beberapa game simpan di tempat lain)
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

-- Coba lewat require(Shared)("...") lebih dulu (sesuai bocoran ScreenMsg)
local function tryScanViaShared()
    local sharedModule = ReplicatedStorage:FindFirstChild("Shared")
    if not sharedModule then return nil end

    local ok, SharedFactory = pcall(require, sharedModule)
    if not ok or type(SharedFactory) ~= "function" then
        return nil
    end

    -- kandidat nama modul inventory (bebas kamu expand nanti)
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

-- Fallback: scan table-table getgc (client-side only, but aman & one-shot)
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
        return
    end

    currentInventory = inv
    lastScanCount    = #inv
    if infoLabel then
        infoLabel.Text = string.format("Status: Inventory ditemukan (%d ikan terbaca).", lastScanCount)
    end
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
        -- inventory tanpa info Kg tidak dipakai untuk filter Kg
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

------------------- HELPER: SCREEN MSG (INTEGRASI UI GAME) -------------------
local function sendScreenMsg(text)
    local screenMsg = LocalPlayer:FindFirstChild("ScreenMsg")
    if not screenMsg then
        return
    end

    local updateEvent = screenMsg:FindFirstChild("UpdateBE")
    if not updateEvent then
        return
    end

    -- Mengikuti HandlePassBy(arg1): arg1.msg + arg1.Param.Clean
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

------------------- HELPER: UI BUILD -------------------
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

------------------- UI LAYOUT (MENGGUNAKAN TAB_FRAME SEBAGAI ROOT) -------------------
-- frame di-ASSUME sudah disiapkan CORE (glass box, padding, dsb).
-- Di sini kita isi child layout internal saja (UIListLayout + konten card).

-- Bersihkan isi lama (kalau tab di-reload)
for _, child in ipairs(frame:GetChildren()) do
    if not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIPadding") then
        child:Destroy()
    end
end

local body = Instance.new("Frame")
body.Name = "SellAllBody"
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 1, 0)
body.Parent = frame

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Left
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 6)
list.Parent = body

-- TITLE
local titleLabel = makeLabel(
    body,
    "Title",
    "Sell All Fish — Smart Filter",
    22,
    15,
    true,
    Color3.fromRGB(225, 230, 255)
)
titleLabel.LayoutOrder = 1

-- DESC
local descLabel = makeLabel(
    body,
    "Desc",
    "Scan inventory ikan (via Shared / getgc), pilih mode filter Kg, lalu SellAll.\nTidak ada loop berat, hanya jalan saat tombol ditekan.",
    38,
    12,
    false,
    Color3.fromRGB(180, 190, 230)
)
descLabel.LayoutOrder = 2

-- STATUS
infoLabel = makeLabel(
    body,
    "Status",
    "Status: Belum scan inventory.",
    20,
    12,
    false,
    Color3.fromRGB(180, 220, 255)
)
infoLabel.LayoutOrder = 3

-- MODE FILTER BUTTON
modeButton = makeButton(body, "ModeButton", "Mode Filter: ALL (semua ikan)", 26)
modeButton.LayoutOrder = 4

-- INPUT MIN / MAX KG
minBox = makeTextbox(body, "MinKgBox", "Min Kg (untuk mode >= / RANGE) - kosong = 0", 24)
minBox.LayoutOrder = 5

maxBox = makeTextbox(body, "MaxKgBox", "Max Kg (untuk mode <= / RANGE) - kosong = 300", 24)
maxBox.LayoutOrder = 6

-- BUTTON SCAN
local scanButton = makeButton(body, "ScanButton", "Scan Inventory Ikan", 26)
scanButton.LayoutOrder = 7

-- BUTTON SELL
local sellButton = makeButton(body, "SellButton", "Sell All (Sesuai Filter)", 26)
sellButton.LayoutOrder = 8

-- DETAIL RESULT
resultLabel = makeLabel(
    body,
    "Result",
    "Detail: -",
    34,
    12,
    false,
    Color3.fromRGB(190, 220, 190)
)
resultLabel.LayoutOrder = 9

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

refreshFilterModeText()
resultLabel.Text = "Detail: TAB siap. Tekan 'Scan Inventory Ikan' lalu 'Sell All' sesuai filter."

------------------- EVENTS -------------------
-- Mode Filter cycle
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

-- Min box
table.insert(connections, minBox.FocusLost:Connect(function(_enterPressed)
    minKg = parseNumber(minBox.Text, 0)
    if filterMode == "MIN" or filterMode == "RANGE" then
        refreshFilterModeText()
    end
end))

-- Max box
table.insert(connections, maxBox.FocusLost:Connect(function(_enterPressed)
    maxKg = parseNumber(maxBox.Text, 300)
    if filterMode == "MAX" or filterMode == "RANGE" then
        refreshFilterModeText()
    end
end))

-- Scan inventory
table.insert(connections, scanButton.MouseButton1Click:Connect(function()
    scanInventory()
    resultLabel.Text = string.format(
        "Detail: Hasil scan terakhir = %d ikan terdeteksi di inventory.",
        lastScanCount
    )
    sendScreenMsg(string.format("[SellAllFish] Scan inventory: %d ikan terbaca.", lastScanCount))
end))

-- Sell All
table.insert(connections, sellButton.MouseButton1Click:Connect(function()
    if not FishRE then
        infoLabel.Text   = "Status: Remote 'FishRE' tidak ditemukan di ReplicatedStorage.Remotes."
        resultLabel.Text = "Detail: Pastikan nama remote FishRE benar."
        sendScreenMsg("[SellAllFish] Gagal SellAll: Remote FishRE tidak ditemukan.")
        return
    end

    if #currentInventory == 0 then
        -- auto scan sekali kalau belum
        scanInventory()
        if #currentInventory == 0 then
            resultLabel.Text = "Detail: Gagal SellAll, inventory kosong / tidak terdeteksi."
            sendScreenMsg("[SellAllFish] Gagal SellAll: inventory tidak ditemukan.")
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
    else
        local msg = "Gagal FireServer SellAll: " .. tostring(err)
        resultLabel.Text = "Detail: " .. msg
        sendScreenMsg("[SellAllFish] " .. msg)
    end
end))

------------------- TAB CLEANUP REGISTRASI -------------------
local function cleanup()
    for _, conn in ipairs(connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    connections = {}

    -- Tidak ada loop RunService, jadi cukup disconnect event dan biarkan CORE yang destroy frame/tab
end

_G.ExHub = _G.ExHub or {}
_G.ExHub.TabCleanup = _G.ExHub.TabCleanup or {}
_G.ExHub.TabCleanup[tabId] = cleanup

_G.AxaHub = _G.AxaHub or {}
_G.AxaHub.TabCleanup = _G.AxaHub.TabCleanup or {}
_G.AxaHub.TabCleanup[tabId] = cleanup