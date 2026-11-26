-- =========================================================
-- PRIMAL EVOLVED HUB V11 (FULL MERGED - DELTA MOBILE)
-- Fix: Non-blocking Deferred SniffOutgoing (Fix mất đánh/nhặt khi bật soi gói tin),
--      Safe pcall wrapper cho toàn bộ __namecall hook
-- =========================================================

-- =========================================================
-- PHẦN 1: GIAO DIỆN IMGUI STYLE (PRIMAL EVOLVED V11)
-- =========================================================
do
    if _G.PrimalHubCleanup then
        pcall(_G.PrimalHubCleanup)
    end

    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")
    local GuiParent = (gethui and gethui()) or CoreGui

    if GuiParent:FindFirstChild("PrimalEvolvedHub") then
        GuiParent.PrimalEvolvedHub:Destroy()
    end

    local Hub = {
        Config = {
            -- Sliders
            WalkSpeed = 28.0,
            TPSpeed = 95.0,
            TimeOfDay = 14.0,
            CameraFOV = 85.0,
            ESPSize = 11.0,
            ESPDistance = 1600.0,
            BuffMultiplier = 3.0,
            AimFOV = 130.0,
            HungerThreshold = 45.0,
            -- Toggles
            SpeedBoost = false,
            TimeOverride = false,
            Fullbright = false,
            FOVOverride = false,
            SmoothTP = true,
            AntiFlyPulse = true,
            AutoFarmNotes = false,
            AutoGather = false,
            ResourceBuff = true,
            AutoSurvive = false,
            AntiBan = true,
            -- PVP
            SilentAim = false,
            ShieldBypass = false,
            CameraAim = false,
            HitboxExpand = false,
            -- ESP
            PlayerESP = false,
            ItemESP = false,
            StructureESP = false,
            NoteESP = false,
            -- Debug
            SniffIncoming = false,
            SniffOutgoing = false
        },
        Stats = {
            Health = 100,
            Food = 100,
            Water = 100,
            Stamina = 100
        },
        Connections = {},
        Tasks = {},
        ItemTags = {},
        StructureTags = {},
        NoteTags = {},
        MarkerAnchors = {},
        OriginalSizes = {},
        LogLines = {},
        OnToggle = nil,
        ScanNearbyFunc = nil,
        TPNoteFunc = nil,
        ResetNotesFunc = nil
    }
    _G.PrimalHub = Hub

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PrimalEvolvedHub"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = GuiParent
    Hub.ScreenGui = ScreenGui

    local Theme = {
        Bg = Color3.fromRGB(10, 11, 14),
        Header = Color3.fromRGB(74, 81, 148),
        TabActive = Color3.fromRGB(58, 64, 118),
        TabIdle = Color3.fromRGB(28, 30, 38),
        ControlBg = Color3.fromRGB(30, 32, 40),
        SliderThumb = Color3.fromRGB(150, 155, 170),
        Text = Color3.fromRGB(240, 242, 248),
        AccentOn = Color3.fromRGB(74, 81, 148)
    }

    -- Nút tròn trắng góc trên phải để ẩn/mở menu
    local ToggleCircle = Instance.new("TextButton")
    ToggleCircle.Size = UDim2.new(0, 38, 0, 38)
    ToggleCircle.Position = UDim2.new(1, -50, 0, 12)
    ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ToggleCircle.Text = ""
    ToggleCircle.ZIndex = 10
    ToggleCircle.Parent = ScreenGui
    Instance.new("UICorner", ToggleCircle).CornerRadius = UDim.new(1, 0)
    local tcStroke = Instance.new("UIStroke", ToggleCircle)
    tcStroke.Color = Theme.Header
    tcStroke.Thickness = 2

    -- Khung Menu chính neo bên phải màn hình
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0.47, 0, 0.92, 0)
    MainFrame.Position = UDim2.new(0.52, 0, 0.04, 0)
    MainFrame.BackgroundColor3 = Theme.Bg
    MainFrame.BackgroundTransparency = 0.08
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = true
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)
    local mfStroke = Instance.new("UIStroke", MainFrame)
    mfStroke.Color = Color3.fromRGB(45, 48, 60)
    mfStroke.Thickness = 1

    ToggleCircle.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    -- Thanh tiêu đề
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 28)
    Header.BackgroundColor3 = Theme.Header
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 6)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -46, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "PrimalTool  |  BETA 1.01 (V11)"
    Title.TextColor3 = Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 12
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    -- Kéo thả cửa sổ thông qua Header
    do
        local dragging, dragInput, dragStart, startPos
        Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        Header.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        table.insert(Hub.Connections, UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
    end

    -- Thanh Tab ngang (Main | Debug)
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -10, 0, 24)
    TabBar.Position = UDim2.new(0, 5, 0, 32)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = MainFrame

    local TabLayout = Instance.new("UIListLayout", TabBar)
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 4)

    local MainScroll = Instance.new("ScrollingFrame")
    MainScroll.Size = UDim2.new(1, -8, 1, -62)
    MainScroll.Position = UDim2.new(0, 4, 0, 59)
    MainScroll.BackgroundTransparency = 1
    MainScroll.BorderSizePixel = 0
    MainScroll.ScrollBarThickness = 3
    MainScroll.ScrollBarImageColor3 = Theme.Header
    MainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    MainScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    MainScroll.Parent = MainFrame

    local MainList = Instance.new("UIListLayout", MainScroll)
    MainList.SortOrder = Enum.SortOrder.LayoutOrder
    MainList.Padding = UDim.new(0, 4)
    MainList.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local DebugPage = Instance.new("Frame")
    DebugPage.Size = UDim2.new(1, -8, 1, -62)
    DebugPage.Position = UDim2.new(0, 4, 0, 59)
    DebugPage.BackgroundTransparency = 1
    DebugPage.Visible = false
    DebugPage.Parent = MainFrame

    local function MakeTabBtn(text, isDefault, order)
        local b = Instance.new("TextButton")
        b.LayoutOrder = order
        b.Size = UDim2.new(0, 74, 1, 0)
        b.BackgroundColor3 = isDefault and Theme.TabActive or Theme.TabIdle
        b.Text = text
        b.TextColor3 = Theme.Text
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 11
        b.Parent = TabBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end

    local TabMain = MakeTabBtn("Main", true, 1)
    local TabDebug = MakeTabBtn("Debug", false, 2)

    TabMain.MouseButton1Click:Connect(function()
        MainScroll.Visible = true
        DebugPage.Visible = false
        TabMain.BackgroundColor3 = Theme.TabActive
        TabDebug.BackgroundColor3 = Theme.TabIdle
    end)

    TabDebug.MouseButton1Click:Connect(function()
        MainScroll.Visible = false
        DebugPage.Visible = true
        TabDebug.BackgroundColor3 = Theme.TabActive
        TabMain.BackgroundColor3 = Theme.TabIdle
    end)

    local nextOrder = 0
    local function GetOrder()
        nextOrder = nextOrder + 1
        return nextOrder
    end

    local function CreateSection(titleText, defaultOpen)
        local isOpen = defaultOpen

        local HeaderBtn = Instance.new("TextButton")
        HeaderBtn.LayoutOrder = GetOrder()
        HeaderBtn.Size = UDim2.new(0.98, 0, 0, 26)
        HeaderBtn.BackgroundColor3 = Theme.Header
        HeaderBtn.Text = (isOpen and "  ▼  " or "  ▶  ") .. titleText
        HeaderBtn.TextColor3 = Theme.Text
        HeaderBtn.Font = Enum.Font.GothamBold
        HeaderBtn.TextSize = 11
        HeaderBtn.TextXAlignment = Enum.TextXAlignment.Left
        HeaderBtn.Parent = MainScroll
        Instance.new("UICorner", HeaderBtn).CornerRadius = UDim.new(0, 8)

        local Container = Instance.new("Frame")
        Container.LayoutOrder = GetOrder()
        Container.Size = UDim2.new(0.98, 0, 0, 0)
        Container.BackgroundTransparency = 1
        Container.AutomaticSize = Enum.AutomaticSize.Y
        Container.Visible = isOpen
        Container.Parent = MainScroll

        local CLayout = Instance.new("UIListLayout", Container)
        CLayout.SortOrder = Enum.SortOrder.LayoutOrder
        CLayout.Padding = UDim.new(0, 4)
        CLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        HeaderBtn.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            Container.Visible = isOpen
            HeaderBtn.Text = (isOpen and "  ▼  " or "  ▶  ") .. titleText
        end)

        return Container
    end

    local function CreateImGuiSlider(parent, labelRight, configKey, minVal, maxVal, decimals)
        local Row = Instance.new("Frame")
        Row.LayoutOrder = GetOrder()
        Row.Size = UDim2.new(1, 0, 0, 26)
        Row.BackgroundColor3 = Theme.ControlBg
        Row.Parent = parent
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

        local Track = Instance.new("Frame")
        Track.Size = UDim2.new(0.66, 0, 1, -4)
        Track.Position = UDim2.new(0, 2, 0, 2)
        Track.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
        Track.ClipsDescendants = true
        Track.Parent = Row
        Instance.new("UICorner", Track).CornerRadius = UDim.new(0, 6)

        local Thumb = Instance.new("Frame")
        Thumb.Size = UDim2.new(0, 12, 1, -2)
        Thumb.BackgroundColor3 = Theme.SliderThumb
        Thumb.BorderSizePixel = 0
        Thumb.Parent = Track
        Instance.new("UICorner", Thumb).CornerRadius = UDim.new(0, 3)

        local fmt = "%." .. tostring(decimals) .. "f"
        local ValueLbl = Instance.new("TextLabel")
        ValueLbl.Size = UDim2.new(1, 0, 1, 0)
        ValueLbl.BackgroundTransparency = 1
        ValueLbl.Text = string.format(fmt, Hub.Config[configKey])
        ValueLbl.TextColor3 = Theme.Text
        ValueLbl.Font = Enum.Font.GothamBold
        ValueLbl.TextSize = 11
        ValueLbl.ZIndex = 3
        ValueLbl.Parent = Track

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Size = UDim2.new(0.32, -6, 1, 0)
        NameLbl.Position = UDim2.new(0.68, 2, 0, 0)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Text = labelRight
        NameLbl.TextColor3 = Theme.Text
        NameLbl.Font = Enum.Font.GothamSemibold
        NameLbl.TextSize = 11
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        NameLbl.Parent = Row

        local function UpdateVisual(val)
            local alpha = math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
            Thumb.Position = UDim2.new(alpha, -alpha * 12, 0, 1)
            ValueLbl.Text = string.format(fmt, val)
        end
        UpdateVisual(Hub.Config[configKey])

        local sliding = false
        local function ApplyInput(input)
            local relX = math.clamp((input.Position.X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
            local raw = minVal + (maxVal - minVal) * relX
            local mult = 10 ^ decimals
            local rounded = math.floor(raw * mult + 0.5) / mult
            Hub.Config[configKey] = rounded
            UpdateVisual(rounded)
        end

        Track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true
                ApplyInput(input)
            end
        end)

        table.insert(Hub.Connections, UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                ApplyInput(input)
            end
        end))

        table.insert(Hub.Connections, UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = false
            end
        end))
    end

    local function CreateImGuiToggle(parent, labelText, configKey, defaultOn)
        local Btn = Instance.new("TextButton")
        Btn.LayoutOrder = GetOrder()
        Btn.Size = UDim2.new(1, 0, 0, 27)
        Btn.BackgroundColor3 = defaultOn and Theme.AccentOn or Theme.ControlBg
        Btn.Text = ""
        Btn.AutoButtonColor = false
        Btn.Parent = parent
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 7)

        local CheckBox = Instance.new("Frame")
        CheckBox.Size = UDim2.new(0, 15, 0, 15)
        CheckBox.Position = UDim2.new(0, 8, 0.5, -7)
        CheckBox.BackgroundColor3 = defaultOn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(18, 20, 26)
        CheckBox.Parent = Btn
        Instance.new("UICorner", CheckBox).CornerRadius = UDim.new(0, 3)

        local Lbl = Instance.new("TextLabel")
        Lbl.Size = UDim2.new(1, -34, 1, 0)
        Lbl.Position = UDim2.new(0, 30, 0, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.Text = labelText
        Lbl.TextColor3 = Theme.Text
        Lbl.Font = Enum.Font.GothamSemibold
        Lbl.TextSize = 11
        Lbl.TextXAlignment = Enum.TextXAlignment.Left
        Lbl.Parent = Btn

        Btn.MouseButton1Click:Connect(function()
            Hub.Config[configKey] = not Hub.Config[configKey]
            local st = Hub.Config[configKey]
            Btn.BackgroundColor3 = st and Theme.AccentOn or Theme.ControlBg
            CheckBox.BackgroundColor3 = st and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(18, 20, 26)
            if Hub.OnToggle then pcall(Hub.OnToggle, configKey, st) end
        end)
    end

    local function CreateImGuiAction(parent, labelText, callback)
        local Btn = Instance.new("TextButton")
        Btn.LayoutOrder = GetOrder()
        Btn.Size = UDim2.new(1, 0, 0, 27)
        Btn.BackgroundColor3 = Theme.TabActive
        Btn.Text = "  " .. labelText
        Btn.TextColor3 = Theme.Text
        Btn.Font = Enum.Font.GothamBold
        Btn.TextSize = 11
        Btn.TextXAlignment = Enum.TextXAlignment.Left
        Btn.Parent = parent
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 7)

        Btn.MouseButton1Click:Connect(function()
            if callback then pcall(callback) end
        end)
    end

    local SecSliders = CreateSection("Sliders", false)
    CreateImGuiSlider(SecSliders, "WalkSpeed", "WalkSpeed", 16, 100, 1)
    CreateImGuiSlider(SecSliders, "TPSpeed", "TPSpeed", 50, 300, 0)
    CreateImGuiSlider(SecSliders, "Buff Multi", "BuffMultiplier", 1, 5, 0)
    CreateImGuiSlider(SecSliders, "Auto Eat %", "HungerThreshold", 15, 85, 0)
    CreateImGuiSlider(SecSliders, "TimeOfDay", "TimeOfDay", 0, 24, 2)
    CreateImGuiSlider(SecSliders, "FOV", "CameraFOV", 40, 120, 1)
    CreateImGuiSlider(SecSliders, "ESP Size", "ESPSize", 8, 22, 0)
    CreateImGuiSlider(SecSliders, "ESP Distance", "ESPDistance", 100, 3000, 0)
    CreateImGuiSlider(SecSliders, "Aim FOV", "AimFOV", 50, 400, 0)

    local SecButtons = CreateSection("Buttons & Farm", true)
    CreateImGuiAction(SecButtons, ">> TP Tới Note Gần Nhất", function() if Hub.TPNoteFunc then Hub.TPNoteFunc() end end)
    CreateImGuiAction(SecButtons, ">> Reset Danh Sách Note", function() if Hub.ResetNotesFunc then Hub.ResetNotesFunc() end end)
    CreateImGuiToggle(SecButtons, "Auto Farm Tất Cả Note", "AutoFarmNotes", false)
    CreateImGuiToggle(SecButtons, "Lướt TP Mượt (Chống Kéo Về)", "SmoothTP", true)
    CreateImGuiToggle(SecButtons, "Anti-Fly Pulse (Chặn r=fly)", "AntiFlyPulse", true)
    CreateImGuiToggle(SecButtons, "Buff Harvest & Nhặt Tức Thì", "ResourceBuff", true)
    CreateImGuiToggle(SecButtons, "Auto-Gather Aura (Tự Nhặt 20m)", "AutoGather", false)
    CreateImGuiToggle(SecButtons, "Bật Tốc Độ (WalkSpeed)", "SpeedBoost", false)

    local SecSurvival = CreateSection("Survival & Visuals", false)
    CreateImGuiToggle(SecSurvival, "Auto Ăn Uống (Theo StatSync)", "AutoSurvive", false)
    CreateImGuiToggle(SecSurvival, "Nhìn Xuyên Đêm (Fullbright)", "Fullbright", false)
    CreateImGuiToggle(SecSurvival, "Khóa Giờ Trong Ngày (TimeOfDay)", "TimeOverride", false)
    CreateImGuiToggle(SecSurvival, "Bật Góc Nhìn (Camera FOV)", "FOVOverride", false)

    local SecPVP = CreateSection("PVP", false)
    CreateImGuiToggle(SecPVP, "Magic Bullet (Silent Aim)", "SilentAim", false)
    CreateImGuiToggle(SecPVP, "Shield Bypass (Xuyên Khiên)", "ShieldBypass", false)
    CreateImGuiToggle(SecPVP, "Aim Khóa Camera (FOV)", "CameraAim", false)
    CreateImGuiToggle(SecPVP, "Mở Rộng Hitbox (Cận Chiến)", "HitboxExpand", false)

    local SecESP = CreateSection("ESP", false)
    CreateImGuiToggle(SecESP, "ESP Người Chơi (Máu & Cấp)", "PlayerESP", false)
    CreateImGuiToggle(SecESP, "ESP Nguyên Liệu (4 Nhóm)", "ItemESP", false)
    CreateImGuiToggle(SecESP, "ESP Công Trình & Nước", "StructureESP", false)
    CreateImGuiToggle(SecESP, "ESP Note (Đã lọc Obelisk)", "NoteESP", false)

    local SecOther = CreateSection("Other", false)
    CreateImGuiToggle(SecOther, "Anti-Ban (Chống Kick & Lỗi)", "AntiBan", true)

    -- Giao diện Tab Debug
    local DbgTop = Instance.new("Frame")
    DbgTop.Size = UDim2.new(1, 0, 0, 86)
    DbgTop.BackgroundTransparency = 1
    DbgTop.Parent = DebugPage
    local DbgList = Instance.new("UIListLayout", DbgTop)
    DbgList.SortOrder = Enum.SortOrder.LayoutOrder
    DbgList.Padding = UDim.new(0, 4)

    CreateImGuiToggle(DbgTop, "Đọc Dữ Liệu Server Gửi Về", "SniffIncoming", false)
    CreateImGuiToggle(DbgTop, "Soi Gói Tin Khai Thác Gửi Đi", "SniffOutgoing", false)

    local DbgBtnRow = Instance.new("Frame")
    DbgBtnRow.LayoutOrder = GetOrder()
    DbgBtnRow.Size = UDim2.new(1, 0, 0, 24)
    DbgBtnRow.BackgroundTransparency = 1
    DbgBtnRow.Parent = DbgTop

    local ScanBtn = Instance.new("TextButton")
    ScanBtn.Size = UDim2.new(0.64, 0, 1, 0)
    ScanBtn.BackgroundColor3 = Theme.Header
    ScanBtn.Text = "Quét Vật Thể (50m)"
    ScanBtn.TextColor3 = Theme.Text
    ScanBtn.Font = Enum.Font.GothamBold
    ScanBtn.TextSize = 10
    ScanBtn.Parent = DbgBtnRow
    Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 5)

    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Size = UDim2.new(0.34, 0, 1, 0)
    ClearBtn.Position = UDim2.new(0.66, 0, 0, 0)
    ClearBtn.BackgroundColor3 = Theme.ControlBg
    ClearBtn.Text = "Xóa Log"
    ClearBtn.TextColor3 = Theme.Text
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 10
    ClearBtn.Parent = DbgBtnRow
    Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 5)

    local LogScroll = Instance.new("ScrollingFrame")
    LogScroll.Size = UDim2.new(1, 0, 1, -90)
    LogScroll.Position = UDim2.new(0, 0, 0, 90)
    LogScroll.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
    LogScroll.BorderSizePixel = 0
    LogScroll.ScrollBarThickness = 3
    LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogScroll.Parent = DebugPage
    Instance.new("UICorner", LogScroll).CornerRadius = UDim.new(0, 6)

    local LogLabel = Instance.new("TextLabel")
    LogLabel.Size = UDim2.new(1, -8, 0, 0)
    LogLabel.Position = UDim2.new(0, 4, 0, 4)
    LogLabel.BackgroundTransparency = 1
    LogLabel.AutomaticSize = Enum.AutomaticSize.Y
    LogLabel.Text = "[Hệ thống] Đang khởi tạo PrimalTool V11..."
    LogLabel.TextColor3 = Color3.fromRGB(167, 243, 208)
    LogLabel.Font = Enum.Font.Code
    LogLabel.TextSize = 10
    LogLabel.TextWrapped = true
    LogLabel.TextXAlignment = Enum.TextXAlignment.Left
    LogLabel.TextYAlignment = Enum.TextYAlignment.Top
    LogLabel.Parent = LogScroll

    Hub.Log = function(msg)
        pcall(function()
            local stamp = os.date("%H:%M:%S")
            table.insert(Hub.LogLines, string.format("[%s] %s", stamp, tostring(msg)))
            if #Hub.LogLines > 40 then table.remove(Hub.LogLines, 1) end
            LogLabel.Text = table.concat(Hub.LogLines, "\n")
        end)
    end

    ClearBtn.MouseButton1Click:Connect(function()
        table.clear(Hub.LogLines)
        LogLabel.Text = "[Đã xóa log]"
    end)

    ScanBtn.MouseButton1Click:Connect(function()
        if Hub.ScanNearbyFunc then pcall(Hub.ScanNearbyFunc) end
    end)
end

-- =========================================================
-- PHẦN 2: NON-BLOCKING SNIFFER, MAPMARKERSYNC & HARVEST HOOK
-- =========================================================
do
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ScriptContext = game:GetService("ScriptContext")

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local Hub = _G.PrimalHub
    local unpackArgs = table.unpack or unpack

    local Config = Hub.Config
    local Log = Hub.Log
    local P2Conns = {}
    local P2Tasks = {}

    Hub.CachedItems = {}
    Hub.CachedStructures = {}
    Hub.CachedNotes = {}
    Hub.VisitedNotes = setmetatable({}, { __mode = "k" })

    local NoisyRemotes = {
        deviceping = true,
        devicepong = true,
        devicereport = true,
        devicelook = true,
        netprobeping = true,
        netprobepong = true,
        moveack = true,
        setaimpitch = true,
        setsprint = true
    }

    local function SafeToString(val)
        local ok, res = pcall(tostring, val)
        return ok and res or "<userdata>"
    end

    local function SerializeValue(v, depth)
        local ok, res = pcall(function()
            local t = typeof(v)
            if t == "Instance" then
                return v.Name .. "(" .. v.ClassName .. ")"
            elseif t == "Vector3" then
                return string.format("Vec3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
            elseif t == "CFrame" then
                local p = v.Position
                return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
            elseif t == "number" then
                return string.format("%.2f", v)
            elseif t == "table" then
                if depth >= 2 then
                    return "{table}"
                end
                local keys = {}
                for k, val in pairs(v) do
                    table.insert(keys, SafeToString(k) .. "=" .. SerializeValue(val, depth + 1))
                    if #keys >= 5 then break end
                end
                return "{" .. table.concat(keys, ",") .. "}"
            else
                return SafeToString(v)
            end
        end)
        return ok and res or "<err>"
    end

    local function SerializeArgs(args)
        local parts = {}
        for i = 1, math.min(#args, 5) do
            table.insert(parts, SerializeValue(args[i], 0))
        end
        return table.concat(parts, " | ")
    end

    -- Vô hiệu hóa MovePull / MoveAsk phía Client
    local PullBypassed = {}
    Hub.DisableMovePull = function()
        if not getconnections then return end
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and not PullBypassed[obj] then
                if obj.Name == "MovePull" or obj.Name == "MoveAsk" then
                    PullBypassed[obj] = true
                    for _, conn in ipairs(getconnections(obj.OnClientEvent)) do
                        pcall(function() conn:Disable() end)
                    end
                    if obj.Name == "MoveAsk" then
                        local ackRemote = obj.Parent and obj.Parent:FindFirstChild("MoveAck")
                        if ackRemote and ackRemote:IsA("RemoteEvent") then
                            local c = obj.OnClientEvent:Connect(function()
                                pcall(function() ackRemote:FireServer(2) end)
                            end)
                            table.insert(P2Conns, c)
                        end
                    end
                end
            end
        end
    end
    pcall(Hub.DisableMovePull)

    -- Đọc StatSync & MapMarkerSync từ Server
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            if obj.Name == "StatSync" then
                table.insert(P2Conns, obj.OnClientEvent:Connect(function(data)
                    if type(data) == "table" then
                        if type(data.Health) == "number" then Hub.Stats.Health = data.Health end
                        if type(data.Food) == "number" then Hub.Stats.Food = data.Food end
                        if type(data.Water) == "number" then Hub.Stats.Water = data.Water end
                        if type(data.Stamina) == "number" then Hub.Stats.Stamina = data.Stamina end
                    end
                end))
            elseif obj.Name == "MapMarkerSync" then
                table.insert(P2Conns, obj.OnClientEvent:Connect(function(data)
                    if type(data) == "table" and type(data.m) == "table" then
                        local added = 0
                        for k, v in pairs(data.m) do
                            local pos = nil
                            if typeof(v) == "Vector3" then
                                pos = v
                            elseif typeof(v) == "CFrame" then
                                pos = v.Position
                            elseif type(v) == "table" then
                                if typeof(v.pos) == "Vector3" then pos = v.pos
                                elseif typeof(v.Position) == "Vector3" then pos = v.Position
                                elseif type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number" then
                                    pos = Vector3.new(v.x, v.y, v.z)
                                end
                            end
                            if pos then
                                local keyId = "SrvMarker_" .. tostring(k)
                                local isDiscovered = (type(data.d) == "table" and data.d[k] ~= nil)
                                if not isDiscovered then
                                    local anchor = Hub.MarkerAnchors[keyId]
                                    if not anchor then
                                        anchor = Instance.new("Part")
                                        anchor.Name = keyId
                                        anchor.Anchored = true
                                        anchor.CanCollide = false
                                        anchor.Transparency = 1
                                        anchor.Size = Vector3.new(1, 1, 1)
                                        anchor.Parent = Workspace
                                        Hub.MarkerAnchors[keyId] = anchor
                                    end
                                    anchor.Position = pos
                                    local label = (type(v) == "table" and tostring(v.name or v.title or v.id or keyId)) or keyId
                                    Hub.CachedNotes[anchor] = {
                                        part = anchor,
                                        tag = "[NOTE-SRV]",
                                        color = Color3.fromRGB(253, 224, 71),
                                        name = label
                                    }
                                    added = added + 1
                                end
                            end
                        end
                        if added > 0 then
                            Log("[MAP] Đã nạp " .. added .. " Note từ MapMarkerSync!")
                        end
                    end
                end))
            end
        end
    end

    -- Hook mạng: Bọc an toàn tuyệt đối để SniffOutgoing không bao giờ chặn đánh/nhặt
    local MetaHooked = false
    local function SetupMetatableHook()
        if MetaHooked then return end
        MetaHooked = true

        pcall(function()
            if getconnections then
                for _, conn in ipairs(getconnections(ScriptContext.Error)) do
                    conn:Disable()
                end
            end
        end)

        pcall(function()
            local gm = getrawmetatable(game)
            setreadonly(gm, false)
            local oldNamecall = gm.__namecall

            gm.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()

                if Config.AntiBan and (method == "Kick" or method == "kick") and self == LocalPlayer then
                    task.defer(function() Log("[ANTI-BAN] Đã chặn lệnh Kick!") end)
                    return nil
                end

                if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                    local okHook, rName = pcall(function() return self.Name end)
                    if okHook and type(rName) == "string" then
                        local rLower = string.lower(rName)
                        local args = { ... }

                        -- Ghi log bất đồng bộ qua task.defer (không đụng GUI trong luồng game)
                        if Config.SniffOutgoing and not NoisyRemotes[rLower] and not string.find(rLower, "chat") then
                            local serialized = SerializeArgs(args)
                            local logMsg = "[GỬI ->] " .. rName .. " : " .. serialized
                            task.defer(function()
                                Log(logMsg)
                            end)
                        end

                        -- 1. Buff Khai Thác thực tế qua gói Harvest
                        if method == "FireServer" and Config.ResourceBuff and rName == "Harvest" then
                            local multi = math.floor(Config.BuffMultiplier)
                            if multi > 1 then
                                pcall(function()
                                    for _ = 1, math.min(multi - 1, 4) do
                                        oldNamecall(self, unpackArgs(args))
                                    end
                                end)
                                return oldNamecall(self, unpackArgs(args))
                            end
                        end

                        -- 2. Silent Aim cho Strike & DeviceLook
                        if method == "FireServer" and Config.SilentAim and (rName == "Strike" or rName == "DeviceLook") then
                            local modified = false
                            pcall(function()
                                local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                                local bestPos, bestPart, shortest = nil, nil, Config.AimFOV
                                for _, plr in ipairs(Players:GetPlayers()) do
                                    if plr ~= LocalPlayer and plr.Character then
                                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                                        local part = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
                                        if hum and hum.Health > 0 and part then
                                            local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                                            if onScreen then
                                                local d = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                                                if d <= shortest then
                                                    shortest = d
                                                    bestPos = part.Position
                                                    bestPart = part
                                                end
                                            end
                                        end
                                    end
                                end

                                if bestPos then
                                    local shootDir = Config.ShieldBypass and Vector3.new(0, 1, 0) or (bestPos - Camera.CFrame.Position).Unit
                                    if rName == "DeviceLook" then
                                        args[1], args[2], args[3] = shootDir.X, shootDir.Y, shootDir.Z
                                        modified = true
                                    elseif rName == "Strike" then
                                        args[1] = bestPart
                                        args[3], args[4], args[5] = shootDir.X, shootDir.Y, shootDir.Z
                                        modified = true
                                    end
                                end
                            end)
                            if modified then
                                return oldNamecall(self, unpackArgs(args))
                            end
                        end
                    end
                end

                return oldNamecall(self, ...)
            end)

            setreadonly(gm, true)
        end)
    end
    SetupMetatableHook()

    local SniffedRemotes = {}
    Hub.AttachIncomingSniffer = function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and not SniffedRemotes[obj] then
                SniffedRemotes[obj] = true
                local conn = obj.OnClientEvent:Connect(function(...)
                    if Config.SniffIncoming then
                        local rLower = string.lower(obj.Name)
                        if not NoisyRemotes[rLower] and not string.find(rLower, "chat") then
                            local serialized = SerializeArgs({ ... })
                            task.defer(function()
                                Log("[NHẬN <-] " .. obj.Name .. " : " .. serialized)
                            end)
                        end
                    end
                end)
                table.insert(P2Conns, conn)
            end
        end
    end

    -- Quét vật thể 50m đã loại bỏ hoàn toàn nhân vật & trang bị của mọi người chơi
    local function IsAnyPlayerObj(obj)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and (obj == plr.Character or obj:IsDescendantOf(plr.Character)) then
                return true
            end
        end
        return false
    end

    local LimbIgnore = {
        head = true, torso = true, uppertorso = true, lowertorso = true,
        humanoidrootpart = true, leftupperarm = true, leftlowerarm = true, lefthand = true,
        rightupperarm = true, rightlowerarm = true, righthand = true,
        leftupperleg = true, leftlowerleg = true, leftfoot = true,
        rightupperleg = true, rightlowerleg = true, rightfoot = true,
        browl = true, browr = true, eyer = true, eyel = true, shortsl = true, shortsr = true,
        handle = true
    }

    Hub.ScanNearbyFunc = function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local found = {}
        local count = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if (obj:IsA("BasePart") or obj:IsA("Model")) and obj.Name ~= "Baseplate" and obj.Name ~= "Terrain" then
                if not IsAnyPlayerObj(obj) then
                    local lower = string.lower(obj.Name)
                    if not LimbIgnore[lower] and not string.find(lower, "^cloth_") and not string.find(lower, "^bw_") then
                        local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                        if part then
                            local dist = math.floor((part.Position - myRoot.Position).Magnitude)
                            if dist <= 50 and not found[obj.Name] then
                                found[obj.Name] = true
                                count = count + 1
                                local hasPrompt = (obj:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil) and " [USE]" or ""
                                Log(string.format("[50m] %s (%dm)%s", obj.Name, dist, hasPrompt))
                                if count >= 25 then break end
                            end
                        end
                    end
                end
            end
        end
        if count == 0 then
            Log("[50m] Không có vật thể môi trường nào trong 50m.")
        end
    end

    -- Phân loại Note, Nguyên liệu & Công trình
    local NoteKeys = {"note", "explorer", "journal", "scroll", "lore", "dossier", "tablet", "relic"}
    local IgnoreObeliskParts = {
        glyph = true, glyphcore = true, panelframe = true, channel = true,
        spoke = true, spokeside = true, step = true, panel = true,
        terminalfoot = true, terminaledge = true, terminalcapa = true,
        terminalcapb = true, skirt = true, floorlight = true
    }

    local ResourceGroups = {
        { tag = "[CƠ BẢN]", color = Color3.fromRGB(217, 119, 6), keys = {"wood", "log", "thatch", "straw", "stone", "rock", "flint", "fiber", "branch", "stick", "leaflitter", "rootplate"} },
        { tag = "[KHOÁNG SẢN]", color = Color3.fromRGB(56, 189, 248), keys = {"metal", "iron", "ore", "crystal", "obsidian", "sulfur", "quartz", "gold"} },
        { tag = "[SINH VẬT]", color = Color3.fromRGB(248, 113, 113), keys = {"meat", "prime", "carcass", "corpse", "hide", "leather", "pelt", "bone", "horn", "keratin", "chitin"} },
        { tag = "[THẢO MỘC]", color = Color3.fromRGB(74, 222, 128), keys = {"berry", "berries", "seed", "herb", "fern", "fruit", "plant", "bush"} }
    }

    local function IsInsideObelisk(obj)
        local cur = obj.Parent
        while cur and cur ~= Workspace do
            local n = string.lower(cur.Name)
            if string.find(n, "terminal") or string.find(n, "obelisk") then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function ClassifyNote(obj)
        local lower = string.lower(obj.Name)
        if IgnoreObeliskParts[lower] or IsInsideObelisk(obj) then
            return false
        end
        for _, k in ipairs(NoteKeys) do
            if string.find(lower, k) then return true end
        end
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            local pText = string.lower(prompt.ObjectText .. " " .. prompt.ActionText)
            for _, k in ipairs({"note", "read", "dossier", "lore", "explorer", "journal"}) do
                if string.find(pText, k) then return true end
            end
        end
        return false
    end

    local function ClassifyResource(obj)
        local lower = string.lower(obj.Name)
        if IgnoreObeliskParts[lower] or IsInsideObelisk(obj) then return nil, nil end
        for _, grp in ipairs(ResourceGroups) do
            for _, k in ipairs(grp.keys) do
                if string.find(lower, k) then return grp.tag, grp.color end
            end
        end
        if obj:IsA("Tool") or obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChildOfClass("ClickDetector") then
            return "[NHẶT]", Color3.fromRGB(250, 204, 21)
        end
        return nil, nil
    end

    local function ClassifyStructure(obj)
        local lower = string.lower(obj.Name)
        if string.find(lower, "terminal") or string.find(lower, "obelisk") then
            return "[TRỤ OBELISK]", Color3.fromRGB(244, 63, 94)
        end
        for _, k in ipairs({"water", "pond", "lake", "river", "spring", "drink", "oasis"}) do
            if string.find(lower, k) then return "[NƯỚC]", Color3.fromRGB(56, 189, 248) end
        end
        for _, k in ipairs({"nest", "cave", "den", "forge", "camp", "shrine", "altar", "bed", "shelter", "garden"}) do
            if string.find(lower, k) then return "[CÔNG TRÌNH]", Color3.fromRGB(192, 132, 252) end
        end
        return nil, nil
    end

    local function RegisterWorldObject(obj)
        if not obj or not obj.Parent then return end
        if not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
        if obj.Name == "Baseplate" or obj.Name == "Terrain" then return end
        if IsAnyPlayerObj(obj) then return end

        local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
        if not part then return end

        if ClassifyNote(obj) then
            Hub.CachedNotes[obj] = { part = part, tag = "[NOTE]", color = Color3.fromRGB(253, 224, 71), name = obj.Name }
            return
        end
        local rTag, rCol = ClassifyResource(obj)
        if rTag then
            Hub.CachedItems[obj] = { part = part, tag = rTag, color = rCol, name = obj.Name }
        end
        local sTag, sCol = ClassifyStructure(obj)
        if sTag then
            Hub.CachedStructures[obj] = { part = part, tag = sTag, color = sCol, name = obj.Name }
        end
    end

    table.insert(P2Tasks, task.spawn(function()
        local all = Workspace:GetDescendants()
        for i = 1, #all do
            pcall(RegisterWorldObject, all[i])
            if i % 1500 == 0 then task.wait() end
        end
        local n = 0
        for _ in pairs(Hub.CachedNotes) do n = n + 1 end
        Log("[OK] Lập chỉ mục V11 xong (" .. n .. " Note).")
    end))

    table.insert(P2Conns, Workspace.DescendantAdded:Connect(function(obj)
        task.defer(function()
            pcall(RegisterWorldObject, obj)
            if Config.ResourceBuff and obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
        end)
    end))

    table.insert(P2Conns, Workspace.DescendantRemoving:Connect(function(obj)
        Hub.CachedNotes[obj] = nil
        Hub.CachedItems[obj] = nil
        Hub.CachedStructures[obj] = nil
    end))

    Hub.Part2Cleanup = function()
        for _, c in ipairs(P2Conns) do if c then pcall(function() c:Disconnect() end) end end
        for _, t in ipairs(P2Tasks) do if t then pcall(task.cancel, t) end end
        for _, anc in pairs(Hub.MarkerAnchors) do if anc then pcall(function() anc:Destroy() end) end end
        table.clear(Hub.MarkerAnchors)
        table.clear(P2Conns)
        table.clear(P2Tasks)
    end
end

-- =========================================================
-- PHẦN 3: ANTI-FLY TP NOTE, AUTO SURVIVE, FULLBRIGHT & RENDER
-- =========================================================
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Lighting = game:GetService("Lighting")

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local Hub = _G.PrimalHub

    local Config = Hub.Config
    local Log = Hub.Log
    local P3Conns = {}
    local P3Tasks = {}
    local IsTeleporting = false

    local function TriggerInteract(obj, part, myRoot)
        pcall(function()
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    d.HoldDuration = 0
                    if fireproximityprompt then fireproximityprompt(d) end
                elseif d:IsA("ClickDetector") then
                    if fireclickdetector then fireclickdetector(d) end
                end
            end
            local direct = obj:FindFirstChildOfClass("ProximityPrompt")
            if direct and direct.Enabled then
                direct.HoldDuration = 0
                if fireproximityprompt then fireproximityprompt(direct) end
            end
            if firetouchinterest and myRoot and part then
                firetouchinterest(myRoot, part, 0)
                firetouchinterest(myRoot, part, 1)
            end
        end)
    end

    local function SetNoclip(char, state)
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = not state end
        end
    end

    local function SafeTeleportToNote(obj, info)
        if IsTeleporting then return false end
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not myRoot or not myHum or myHum.Health <= 0 then return false end

        if Hub.DisableMovePull then pcall(Hub.DisableMovePull) end
        IsTeleporting = true
        local targetPart = info.part
        local noclipConn = RunService.Stepped:Connect(function() SetNoclip(myChar, true) end)

        if Config.SmoothTP then
            Log("[TP] Đang di chuyển an toàn tới " .. info.name .. "...")
            local lastGroundPulse = tick()
            while IsTeleporting and myRoot and myRoot.Parent and targetPart and targetPart.Parent do
                local dt = RunService.Heartbeat:Wait()
                local goalPos = targetPart.Position + Vector3.new(0, 2.5, 0)
                local diff = goalPos - myRoot.Position
                local dist = diff.Magnitude

                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero

                if Config.AntiFlyPulse and (tick() - lastGroundPulse >= 0.8) then
                    lastGroundPulse = tick()
                    pcall(function()
                        myHum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                    task.wait(0.06)
                end

                if dist <= 6 then
                    myRoot.CFrame = CFrame.new(goalPos)
                    break
                else
                    local step = math.min(dist, Config.TPSpeed * dt)
                    myRoot.CFrame = CFrame.new(myRoot.Position + diff.Unit * step)
                end
            end
        else
            local startHold = tick()
            while tick() - startHold < 0.55 do
                RunService.Heartbeat:Wait()
                if myRoot and myRoot.Parent and targetPart and targetPart.Parent then
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 2.5, 0))
                    TriggerInteract(obj, targetPart, myRoot)
                end
            end
        end

        for _ = 1, 3 do
            if myRoot and targetPart and targetPart.Parent then
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 2.5, 0))
                TriggerInteract(obj, targetPart, myRoot)
            end
            task.wait(0.08)
        end

        if noclipConn then noclipConn:Disconnect() end
        SetNoclip(myChar, false)
        Hub.VisitedNotes[obj] = true
        IsTeleporting = false
        Log("[OK] Đã tới & kích hoạt: " .. info.name)
        return true
    end

    local function GetNearestNote()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil, nil end
        local bestObj, bestInfo, bestDist = nil, nil, math.huge
        for obj, info in pairs(Hub.CachedNotes) do
            if obj and obj.Parent and info.part and info.part.Parent then
                if not Hub.VisitedNotes[obj] then
                    local d = (info.part.Position - myRoot.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestObj = obj
                        bestInfo = info
                    end
                end
            else
                Hub.CachedNotes[obj] = nil
            end
        end
        return bestObj, bestInfo
    end

    Hub.TPNoteFunc = function()
        local obj, info = GetNearestNote()
        if obj and info then
            task.spawn(SafeTeleportToNote, obj, info)
        else
            Log("[NOTE] Không tìm thấy Note mới trên map.")
        end
    end

    Hub.ResetNotesFunc = function()
        Hub.VisitedNotes = setmetatable({}, { __mode = "k" })
        Log("[NOTE] Đã reset danh sách Note.")
    end

    table.insert(P3Tasks, task.spawn(function()
        while task.wait(0.8) do
            if Config.AutoFarmNotes and not IsTeleporting then
                local obj, info = GetNearestNote()
                if obj and info then
                    SafeTeleportToNote(obj, info)
                    task.wait(0.4)
                else
                    Config.AutoFarmNotes = false
                    Log("[AUTO NOTE] Đã farm xong danh sách Note!")
                end
            end
        end
    end))

    -- Auto-Gather Aura (20m) & Auto Survive
    table.insert(P3Tasks, task.spawn(function()
        while task.wait(0.4) do
            pcall(function()
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myRoot then return end

                if Config.AutoGather and not IsTeleporting then
                    local count = 0
                    for obj, info in pairs(Hub.CachedItems) do
                        if count >= 5 then break end
                        if obj and obj.Parent and info.part and info.part.Parent and not obj:IsDescendantOf(myChar) then
                            if (info.part.Position - myRoot.Position).Magnitude <= 20 then
                                TriggerInteract(obj, info.part, myRoot)
                                count = count + 1
                            end
                        end
                    end
                end

                if Config.AutoSurvive then
                    local thresh = Config.HungerThreshold
                    if Hub.Stats.Food < thresh then
                        for obj, info in pairs(Hub.CachedItems) do
                            if (info.tag == "[SINH VẬT]" or info.tag == "[THẢO MỘC]") and info.part and info.part.Parent then
                                if (info.part.Position - myRoot.Position).Magnitude <= 25 then
                                    TriggerInteract(obj, info.part, myRoot)
                                    break
                                end
                            end
                        end
                    end
                    if Hub.Stats.Water < thresh then
                        for obj, info in pairs(Hub.CachedStructures) do
                            if info.tag == "[NƯỚC]" and info.part and info.part.Parent then
                                if (info.part.Position - myRoot.Position).Magnitude <= 30 then
                                    TriggerInteract(obj, info.part, myRoot)
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end))

    local function ClearTagMap(map)
        for k, gui in pairs(map) do
            if gui and gui.Parent then gui:Destroy() end
            map[k] = nil
        end
    end

    local function SyncCacheESP(cacheTable, tagMap, guiName, enabled, checkVisited)
        if not enabled then
            ClearTagMap(tagMap)
            return
        end
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local maxDist = Config.ESPDistance
        local fontSize = math.floor(Config.ESPSize)

        for obj, info in pairs(cacheTable) do
            if not obj or not obj.Parent or not info.part or not info.part.Parent then
                cacheTable[obj] = nil
                if tagMap[obj] then tagMap[obj]:Destroy() tagMap[obj] = nil end
            else
                local dist = myRoot and math.floor((info.part.Position - myRoot.Position).Magnitude) or 0
                if dist <= maxDist then
                    local bg = tagMap[obj]
                    if not bg or not bg.Parent then
                        bg = Instance.new("BillboardGui")
                        bg.Name = guiName
                        bg.Adornee = info.part
                        bg.Size = UDim2.new(0, 190, 0, 32)
                        bg.StudsOffset = Vector3.new(0, 2.2, 0)
                        bg.AlwaysOnTop = true

                        local lbl = Instance.new("TextLabel")
                        lbl.Name = "Txt"
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.TextStrokeTransparency = 0.2
                        lbl.Parent = bg

                        bg.Parent = info.part
                        tagMap[obj] = bg
                    end
                    local doneSuffix = (checkVisited and Hub.VisitedNotes[obj]) and " [ĐÃ QUA]" or ""
                    bg.Txt.TextSize = fontSize
                    bg.Txt.TextColor3 = (checkVisited and Hub.VisitedNotes[obj]) and Color3.fromRGB(156, 163, 175) or info.color
                    bg.Txt.Text = string.format("%s %s [%dm]%s", info.tag, info.name, dist, doneSuffix)
                elseif tagMap[obj] then
                    tagMap[obj]:Destroy()
                    tagMap[obj] = nil
                end
            end
        end
    end

    table.insert(P3Tasks, task.spawn(function()
        while task.wait(0.8) do
            pcall(SyncCacheESP, Hub.CachedNotes, Hub.NoteTags, "PrimalNoteTag", Config.NoteESP, true)
            pcall(SyncCacheESP, Hub.CachedItems, Hub.ItemTags, "PrimalItemTag", Config.ItemESP, false)
            pcall(SyncCacheESP, Hub.CachedStructures, Hub.StructureTags, "PrimalStructTag", Config.StructureESP, false)
        end
    end))

    local function RestoreAllHitboxes()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp and Hub.OriginalSizes[plr] then
                    hrp.Size = Hub.OriginalSizes[plr]
                    hrp.Transparency = 1
                end
            end
        end
        table.clear(Hub.OriginalSizes)
    end

    Hub.OnToggle = function(key, state)
        if key == "PlayerESP" and not state then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character then
                    local hl = plr.Character:FindFirstChild("PrimalPlrHL")
                    if hl then hl:Destroy() end
                    local tag = plr.Character:FindFirstChild("PrimalPlrTag", true)
                    if tag then tag:Destroy() end
                end
            end
        elseif key == "NoteESP" then
            SyncCacheESP(Hub.CachedNotes, Hub.NoteTags, "PrimalNoteTag", state, true)
        elseif key == "ItemESP" then
            SyncCacheESP(Hub.CachedItems, Hub.ItemTags, "PrimalItemTag", state, false)
        elseif key == "StructureESP" then
            SyncCacheESP(Hub.CachedStructures, Hub.StructureTags, "PrimalStructTag", state, false)
        elseif key == "HitboxExpand" and not state then
            RestoreAllHitboxes()
        elseif key == "SniffIncoming" and state and Hub.AttachIncomingSniffer then
            Hub.AttachIncomingSniffer()
        elseif key == "SpeedBoost" and state and Hub.DisableMovePull then
            pcall(Hub.DisableMovePull)
        elseif key == "ResourceBuff" and state then
            for _, p in ipairs(Workspace:GetDescendants()) do
                if p:IsA("ProximityPrompt") then p.HoldDuration = 0 end
            end
        end
    end

    table.insert(P3Conns, LocalPlayer.CharacterAdded:Connect(function()
        IsTeleporting = false
        table.clear(Hub.OriginalSizes)
        if Hub.DisableMovePull then pcall(Hub.DisableMovePull) end
    end))

    local FOVCircle
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1.8
        FOVCircle.Color = Color3.fromRGB(98, 108, 196)
        FOVCircle.Filled = false
        FOVCircle.Transparency = 0.85
        FOVCircle.Visible = false
    end)

    table.insert(P3Conns, RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            if FOVCircle then
                FOVCircle.Position = screenCenter
                FOVCircle.Radius = Config.AimFOV
                FOVCircle.Visible = (Config.SilentAim or Config.CameraAim or Config.HitboxExpand)
            end

            if Config.Fullbright then
                Lighting.ClockTime = 14
                Lighting.Brightness = 2
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 100000
            elseif Config.TimeOverride then
                Lighting.ClockTime = Config.TimeOfDay
            end

            if Config.FOVOverride then Camera.FieldOfView = Config.CameraFOV end

            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

            if Config.SpeedBoost and not IsTeleporting and myHum and myRoot and myHum.Health > 0 then
                myHum.WalkSpeed = Config.WalkSpeed
                if myHum.MoveDirection.Magnitude > 0 and Config.WalkSpeed > 20 then
                    local bonus = (Config.WalkSpeed - 16) * 0.45
                    myRoot.CFrame = myRoot.CFrame + (myHum.MoveDirection * bonus * dt)
                end
            end

            local bestAimPos, shortestAimDist = nil, Config.AimFOV
            local fontSize = math.floor(Config.ESPSize)

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local char = plr.Character
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head") or hrp
                    local hum = char:FindFirstChildOfClass("Humanoid")

                    if hrp and hum and hum.Health > 0 then
                        local dist = myRoot and math.floor((hrp.Position - myRoot.Position).Magnitude) or 0
                        if Config.PlayerESP and dist <= Config.ESPDistance then
                            local isAdult = hum.MaxHealth >= 800
                            local col = isAdult and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(251, 146, 60)
                            local stg = isAdult and "[TRƯỞNG THÀNH]" or "[NHỎ]"

                            local hl = char:FindFirstChild("PrimalPlrHL")
                            if not hl then
                                hl = Instance.new("Highlight")
                                hl.Name = "PrimalPlrHL"
                                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                                hl.FillTransparency = 0.55
                                hl.Parent = char
                            end
                            hl.FillColor = col

                            local tag = head:FindFirstChild("PrimalPlrTag")
                            if not tag then
                                tag = Instance.new("BillboardGui")
                                tag.Name = "PrimalPlrTag"
                                tag.Adornee = head
                                tag.Size = UDim2.new(0, 210, 0, 44)
                                tag.StudsOffset = Vector3.new(0, 3.3, 0)
                                tag.AlwaysOnTop = true

                                local lbl = Instance.new("TextLabel")
                                lbl.Name = "Info"
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextStrokeTransparency = 0
                                lbl.Parent = tag
                                tag.Parent = head
                            end

                            tag.Info.TextSize = fontSize
                            tag.Info.TextColor3 = col
                            tag.Info.Text = string.format("%s %s\nHP: %d/%d | %dm", stg, plr.DisplayName, math.floor(hum.Health), math.floor(hum.MaxHealth), dist)
                        else
                            local hl = char:FindFirstChild("PrimalPlrHL")
                            if hl then hl:Destroy() end
                            local tag = head and head:FindFirstChild("PrimalPlrTag")
                            if tag then tag:Destroy() end
                        end

                        if Config.HitboxExpand then
                            if not Hub.OriginalSizes[plr] then Hub.OriginalSizes[plr] = hrp.Size end
                            hrp.Size = Vector3.new(12, 12, 12)
                            hrp.Transparency = 0.85
                            hrp.CanCollide = false
                        end

                        if Config.CameraAim and head then
                            local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
                            if onScreen then
                                local d = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                                if d <= shortestAimDist then
                                    shortestAimDist = d
                                    bestAimPos = head.Position
                                end
                            end
                        end
                    else
                        local hl = char:FindFirstChild("PrimalPlrHL")
                        if hl then hl:Destroy() end
                        local tag = head and head:FindFirstChild("PrimalPlrTag")
                        if tag then tag:Destroy() end
                    end
                end
            end

            if Config.CameraAim and bestAimPos then
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, bestAimPos), 0.35)
            end
        end)
    end))

    Log("[OK] PrimalTool V11 (Fix SniffOutgoing Hook) sẵn sàng!")

    Hub.Part3Cleanup = function()
        IsTeleporting = false
        for _, c in ipairs(P3Conns) do if c then pcall(function() c:Disconnect() end) end end
        for _, t in ipairs(P3Tasks) do if t then pcall(task.cancel, t) end end
        table.clear(P3Conns)
        table.clear(P3Tasks)
        ClearTagMap(Hub.NoteTags)
        ClearTagMap(Hub.ItemTags)
        ClearTagMap(Hub.StructureTags)
        RestoreAllHitboxes()
        if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    end

    _G.PrimalHubCleanup = function()
        if Hub.Part3Cleanup then pcall(Hub.Part3Cleanup) end
        if Hub.Part2Cleanup then pcall(Hub.Part2Cleanup) end
        for _, c in ipairs(Hub.Connections) do if c then pcall(function() c:Disconnect() end) end end
        for _, t in ipairs(Hub.Tasks) do if t then pcall(task.cancel, t) end end
        if Hub.ScreenGui then pcall(function() Hub.ScreenGui:Destroy() end) end
        _G.PrimalHub = nil
    end
end
