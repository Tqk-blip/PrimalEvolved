-- =========================================================
-- PRIMAL EVOLVED HUB V14 (COMBAT & PROJECTILE OVERHAUL)
-- Fix:
--   1. Enemy launching into sky on HitboxExpand (added Massless=true +
--      Zero-Density PhysicalProperties + safe HitboxSize slider)
--   2. Melee Strike registration (Attacker-to-Target vector instead of Camera,
--      15-stud MeleeRange gate, true direction vector, character facing sync)
--   3. Ranged / Bow & Bola Aim ("Aim All"): Ballistic drop + velocity prediction
--      hooking SetAimPitch, DeviceLook & Projectile remotes
-- =========================================================

-- =========================================================
-- BLOCK 1: CORE STATE, TELEMETRY HUD & IMGUI INTERFACE
-- =========================================================
do
    if _G.PrimalHubCleanup then
        pcall(_G.PrimalHubCleanup)
    end

    local CoreGui = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")
    local GuiParent = (gethui and gethui()) or CoreGui

    local oldGui = GuiParent:FindFirstChild("PrimalEvolvedHub")
    if oldGui then
        oldGui:Destroy()
    end

    local Hub = {
        Version = "V14",
        Config = {
            -- Sliders
            WalkSpeed = 28.0,
            TPSpeed = 105.0,
            TimeOfDay = 14.0,
            CameraFOV = 85.0,
            ESPSize = 11.0,
            ESPDistance = 1600.0,
            BuffMultiplier = 3.0,
            AimFOV = 160.0,
            MeleeRange = 16.0,
            HitboxSize = 5.0,
            ProjSpeed = 165.0,
            ProjGravity = 38.0,
            HungerThreshold = 45.0,
            -- Movement & Farm
            SpeedBoost = false,
            SmoothTP = true,
            PingCompensate = true,
            AntiFlyPulse = true,
            AutoFarmNotes = false,
            AutoGather = false,
            ResourceBuff = true,
            -- Survival & Visuals
            AutoSurvive = false,
            Fullbright = false,
            TimeOverride = false,
            FOVOverride = false,
            -- Combat / PVP (Melee + Bow + Bola)
            SilentAim = false,
            ProjectileAim = false,
            TargetCreatures = true,
            FaceTargetOnHit = true,
            CameraAim = false,
            HitboxExpand = false,
            -- ESP
            PlayerESP = false,
            CreatureESP = false,
            ItemESP = false,
            StructureESP = false,
            NoteESP = false,
            -- Security & Debug
            AntiBan = true,
            SniffIncoming = false,
            SniffOutgoing = false
        },
        Stats = {
            Health = 100,
            Food = 100,
            Water = 100,
            Stamina = 100,
            Weight = 0,
            PingMs = 0
        },
        Hooks = {
            Namecall = false,
            Newindex = false,
            FireServer = false,
            InvokeServer = false,
            MovePullBlocked = 0
        },
        CachedItems = {},
        CachedStructures = {},
        CachedNotes = {},
        CachedCreatures = {},
        VisitedNotes = setmetatable({}, { __mode = "k" }),
        MarkerAnchors = {},
        ItemTags = {},
        StructureTags = {},
        NoteTags = {},
        CreatureTags = {},
        OriginalSizes = {},
        LogLines = {},
        Connections = {},
        Tasks = {},
        -- Cross-block callbacks
        Log = nil,
        UpdateHUD = nil,
        OnToggle = nil,
        ScanNearbyFunc = nil,
        RunDiagnosticsFunc = nil,
        TPNoteFunc = nil,
        ResetNotesFunc = nil,
        DisableMovePull = nil,
        AttachIncomingSniffer = nil
    }
    _G.PrimalHub = Hub

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PrimalEvolvedHub"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = GuiParent
    Hub.ScreenGui = ScreenGui

    local Theme = {
        Bg = Color3.fromRGB(11, 12, 16),
        Header = Color3.fromRGB(74, 81, 148),
        TabActive = Color3.fromRGB(58, 64, 118),
        TabIdle = Color3.fromRGB(26, 28, 36),
        ControlBg = Color3.fromRGB(28, 30, 39),
        SliderBg = Color3.fromRGB(19, 21, 27),
        SliderThumb = Color3.fromRGB(158, 164, 184),
        Text = Color3.fromRGB(242, 244, 250),
        MutedText = Color3.fromRGB(167, 243, 208),
        AccentOn = Color3.fromRGB(74, 81, 148)
    }

    -- Floating Toggle Button
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

    -- Main Window
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0.47, 0, 0.92, 0)
    MainFrame.Position = UDim2.new(0.52, 0, 0.04, 0)
    MainFrame.BackgroundColor3 = Theme.Bg
    MainFrame.BackgroundTransparency = 0.06
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = true
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)
    local mfStroke = Instance.new("UIStroke", MainFrame)
    mfStroke.Color = Color3.fromRGB(48, 52, 66)
    mfStroke.Thickness = 1

    ToggleCircle.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    -- Header Bar
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
    Title.Text = "PrimalTool  |  BETA 1.01 (V14)"
    Title.TextColor3 = Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 12
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    -- Dragging via Header
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
                MainFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end))
    end

    -- Live Telemetry Strip
    local TelemetryBar = Instance.new("Frame")
    TelemetryBar.Size = UDim2.new(1, -10, 0, 20)
    TelemetryBar.Position = UDim2.new(0, 5, 0, 31)
    TelemetryBar.BackgroundColor3 = Theme.SliderBg
    TelemetryBar.BorderSizePixel = 0
    TelemetryBar.Parent = MainFrame
    Instance.new("UICorner", TelemetryBar).CornerRadius = UDim.new(0, 4)

    local TelemetryLbl = Instance.new("TextLabel")
    TelemetryLbl.Size = UDim2.new(1, -8, 1, 0)
    TelemetryLbl.Position = UDim2.new(0, 4, 0, 0)
    TelemetryLbl.BackgroundTransparency = 1
    TelemetryLbl.Text = "HP: -- | Food: -- | Water: -- | Ping: --ms"
    TelemetryLbl.TextColor3 = Theme.MutedText
    TelemetryLbl.Font = Enum.Font.Code
    TelemetryLbl.TextSize = 10
    TelemetryLbl.TextXAlignment = Enum.TextXAlignment.Center
    TelemetryLbl.Parent = TelemetryBar

    Hub.UpdateHUD = function()
        pcall(function()
            TelemetryLbl.Text = string.format(
                "HP:%d | Food:%d | Water:%d | Ping:%dms",
                math.floor(Hub.Stats.Health),
                math.floor(Hub.Stats.Food),
                math.floor(Hub.Stats.Water),
                math.floor(Hub.Stats.PingMs)
            )
        end)
    end

    -- Tab Bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -10, 0, 23)
    TabBar.Position = UDim2.new(0, 5, 0, 54)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = MainFrame

    local TabLayout = Instance.new("UIListLayout", TabBar)
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 4)

    local MainScroll = Instance.new("ScrollingFrame")
    MainScroll.Size = UDim2.new(1, -8, 1, -83)
    MainScroll.Position = UDim2.new(0, 4, 0, 80)
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
    DebugPage.Size = UDim2.new(1, -8, 1, -83)
    DebugPage.Position = UDim2.new(0, 4, 0, 80)
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
        Track.BackgroundColor3 = Theme.SliderBg
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

    -- Section 1: Sliders
    local SecSliders = CreateSection("Sliders", false)
    CreateImGuiSlider(SecSliders, "WalkSpeed", "WalkSpeed", 16, 100, 1)
    CreateImGuiSlider(SecSliders, "TPSpeed", "TPSpeed", 50, 300, 0)
    CreateImGuiSlider(SecSliders, "Melee Range", "MeleeRange", 8, 28, 1)
    CreateImGuiSlider(SecSliders, "Hitbox Size", "HitboxSize", 2, 10, 1)
    CreateImGuiSlider(SecSliders, "Aim FOV", "AimFOV", 50, 400, 0)
    CreateImGuiSlider(SecSliders, "Proj Speed", "ProjSpeed", 80, 350, 0)
    CreateImGuiSlider(SecSliders, "Proj Drop", "ProjGravity", 0, 100, 1)
    CreateImGuiSlider(SecSliders, "Buff Multi", "BuffMultiplier", 1, 5, 0)
    CreateImGuiSlider(SecSliders, "Auto Eat %", "HungerThreshold", 15, 85, 0)
    CreateImGuiSlider(SecSliders, "TimeOfDay", "TimeOfDay", 0, 24, 2)
    CreateImGuiSlider(SecSliders, "FOV", "CameraFOV", 40, 120, 1)
    CreateImGuiSlider(SecSliders, "ESP Size", "ESPSize", 8, 22, 0)
    CreateImGuiSlider(SecSliders, "ESP Distance", "ESPDistance", 100, 3000, 0)

    -- Section 2: Combat & Aim All (Melee + Bow + Bola)
    local SecPVP = CreateSection("Combat & Aim All (Cận Chiến / Cung / Bola)", true)
    CreateImGuiToggle(SecPVP, "Aim Cận Chiến (Strike Chuẩn Tầm)", "SilentAim", false)
    CreateImGuiToggle(SecPVP, "Aim Cung & Bola (Đón Đầu + Độ Rơi)", "ProjectileAim", false)
    CreateImGuiToggle(SecPVP, "Khóa Cả Sinh Vật / Khủng Long", "TargetCreatures", true)
    CreateImGuiToggle(SecPVP, "Tự Quay Mặt Vào Địch Khi Đánh", "FaceTargetOnHit", true)
    CreateImGuiToggle(SecPVP, "Aim Khóa Camera (FOV)", "CameraAim", false)
    CreateImGuiToggle(SecPVP, "Mở Rộng Hitbox An Toàn (Không Bay)", "HitboxExpand", false)

    -- Section 3: Buttons & Farm
    local SecButtons = CreateSection("Buttons & Farm", false)
    CreateImGuiAction(SecButtons, ">> TP Tới Note Gần Nhất", function() if Hub.TPNoteFunc then Hub.TPNoteFunc() end end)
    CreateImGuiAction(SecButtons, ">> Reset Danh Sách Note", function() if Hub.ResetNotesFunc then Hub.ResetNotesFunc() end end)
    CreateImGuiToggle(SecButtons, "Auto Farm Tất Cả Note", "AutoFarmNotes", false)
    CreateImGuiToggle(SecButtons, "Lướt TP Mượt (Chống Kéo Về)", "SmoothTP", true)
    CreateImGuiToggle(SecButtons, "Bù Độ Trễ Mạng (Ping-Safe TP)", "PingCompensate", true)
    CreateImGuiToggle(SecButtons, "Anti-Fly Pulse (Chặn r=fly)", "AntiFlyPulse", true)
    CreateImGuiToggle(SecButtons, "Buff Harvest / DecorPick / Mine", "ResourceBuff", true)
    CreateImGuiToggle(SecButtons, "Auto-Gather Aura (Tự Nhặt 20m)", "AutoGather", false)
    CreateImGuiToggle(SecButtons, "Bật Tốc Độ (WalkSpeed)", "SpeedBoost", false)

    -- Section 4: Survival & Visuals
    local SecSurvival = CreateSection("Survival & Visuals", false)
    CreateImGuiToggle(SecSurvival, "Auto Ăn Uống (Theo StatSync)", "AutoSurvive", false)
    CreateImGuiToggle(SecSurvival, "Nhìn Xuyên Đêm (Zero-Flicker)", "Fullbright", false)
    CreateImGuiToggle(SecSurvival, "Khóa Giờ Trong Ngày (TimeOfDay)", "TimeOverride", false)
    CreateImGuiToggle(SecSurvival, "Bật Góc Nhìn (Camera FOV)", "FOVOverride", false)

    -- Section 5: ESP
    local SecESP = CreateSection("ESP (5 Nhóm Thực Thể)", false)
    CreateImGuiToggle(SecESP, "ESP Người Chơi (Máu & Giai Đoạn)", "PlayerESP", false)
    CreateImGuiToggle(SecESP, "ESP Sinh Vật / Khủng Long", "CreatureESP", false)
    CreateImGuiToggle(SecESP, "ESP Nguyên Liệu (4 Nhóm)", "ItemESP", false)
    CreateImGuiToggle(SecESP, "ESP Công Trình, Nước & Obelisk", "StructureESP", false)
    CreateImGuiToggle(SecESP, "ESP Note (Đã lọc Obelisk)", "NoteESP", false)

    -- Section 6: Other
    local SecOther = CreateSection("Other", false)
    CreateImGuiToggle(SecOther, "Anti-Ban (Chống Kick & Lỗi)", "AntiBan", true)

    -- Debug Page Layout
    local DbgTop = Instance.new("Frame")
    DbgTop.Size = UDim2.new(1, 0, 0, 114)
    DbgTop.BackgroundTransparency = 1
    DbgTop.Parent = DebugPage
    local DbgList = Instance.new("UIListLayout", DbgTop)
    DbgList.SortOrder = Enum.SortOrder.LayoutOrder
    DbgList.Padding = UDim.new(0, 4)

    CreateImGuiToggle(DbgTop, "Đọc Dữ Liệu Server Gửi Về", "SniffIncoming", false)
    CreateImGuiToggle(DbgTop, "Soi Mọi Gói Tin Gửi Đi (Full Hook)", "SniffOutgoing", false)

    local DbgBtnRow1 = Instance.new("Frame")
    DbgBtnRow1.LayoutOrder = GetOrder()
    DbgBtnRow1.Size = UDim2.new(1, 0, 0, 24)
    DbgBtnRow1.BackgroundTransparency = 1
    DbgBtnRow1.Parent = DbgTop

    local ScanBtn = Instance.new("TextButton")
    ScanBtn.Size = UDim2.new(0.64, 0, 1, 0)
    ScanBtn.BackgroundColor3 = Theme.Header
    ScanBtn.Text = "Quét Vật Thể (50m)"
    ScanBtn.TextColor3 = Theme.Text
    ScanBtn.Font = Enum.Font.GothamBold
    ScanBtn.TextSize = 10
    ScanBtn.Parent = DbgBtnRow1
    Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 5)

    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Size = UDim2.new(0.34, 0, 1, 0)
    ClearBtn.Position = UDim2.new(0.66, 0, 0, 0)
    ClearBtn.BackgroundColor3 = Theme.ControlBg
    ClearBtn.Text = "Xóa Log"
    ClearBtn.TextColor3 = Theme.Text
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 10
    ClearBtn.Parent = DbgBtnRow1
    Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 5)

    local DiagBtn = Instance.new("TextButton")
    DiagBtn.LayoutOrder = GetOrder()
    DiagBtn.Size = UDim2.new(1, 0, 0, 24)
    DiagBtn.BackgroundColor3 = Theme.TabActive
    DiagBtn.Text = "Kiểm Tra Trạng Thái Hook & Cache (Self-Test)"
    DiagBtn.TextColor3 = Theme.Text
    DiagBtn.Font = Enum.Font.GothamBold
    DiagBtn.TextSize = 10
    DiagBtn.Parent = DbgTop
    Instance.new("UICorner", DiagBtn).CornerRadius = UDim.new(0, 5)

    local LogScroll = Instance.new("ScrollingFrame")
    LogScroll.Size = UDim2.new(1, 0, 1, -118)
    LogScroll.Position = UDim2.new(0, 0, 0, 118)
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
    LogLabel.Text = "[Hệ thống] Đang khởi tạo PrimalTool V14..."
    LogLabel.TextColor3 = Theme.MutedText
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
            if #Hub.LogLines > 45 then
                table.remove(Hub.LogLines, 1)
            end
            LogLabel.Text = table.concat(Hub.LogLines, "\n")
            task.defer(function()
                if LogScroll and LogScroll.Parent then
                    LogScroll.CanvasPosition = Vector2.new(0, 999999)
                end
            end)
        end)
    end

    ClearBtn.MouseButton1Click:Connect(function()
        table.clear(Hub.LogLines)
        LogLabel.Text = "[Đã xóa log]"
    end)

    ScanBtn.MouseButton1Click:Connect(function()
        if Hub.ScanNearbyFunc then pcall(Hub.ScanNearbyFunc) end
    end)

    DiagBtn.MouseButton1Click:Connect(function()
        if Hub.RunDiagnosticsFunc then pcall(Hub.RunDiagnosticsFunc) end
    end)
end

-- =========================================================
-- BLOCK 2: NETWORK LAYER, MELEE STRIKE FIX & PROJECTILE AIM
-- =========================================================
do
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local Lighting = game:GetService("Lighting")
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
        for i = 1, math.min(#args, 6) do
            table.insert(parts, SerializeValue(args[i], 0))
        end
        return table.concat(parts, " | ")
    end

    local function ExtractEntityId(model)
        if not model then return nil end
        for _, attrName in ipairs({"Id", "ID", "EntityId", "CreatureId", "SurvivorId", "uid", "UID"}) do
            local val = model:GetAttribute(attrName)
            if type(val) == "number" then return val end
        end
        for _, v in ipairs(model:GetChildren()) do
            if v:IsA("IntValue") or v:IsA("NumberValue") then
                local n = string.lower(v.Name)
                if n == "id" or n == "entityid" or n == "creatureid" then
                    return v.Value
                end
            end
        end
        return nil
    end

    -- Unified Target Finder (supports both Melee Range gate and Ranged FOV)
    local function GetBestTarget(maxStuds)
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local bestType, bestId, bestPart, shortest = nil, nil, nil, Config.AimFOV

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local part = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Head")
                if hum and hum.Health > 0 and part then
                    local worldDist = myRoot and (part.Position - myRoot.Position).Magnitude or 0
                    if worldDist <= maxStuds then
                        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local d = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                            if d <= shortest then
                                shortest = d
                                bestType = "survivor"
                                bestId = ExtractEntityId(plr.Character) or plr.UserId
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end

        if not bestType and Config.TargetCreatures then
            for model, info in pairs(Hub.CachedCreatures) do
                if model and model.Parent and info.part and info.part.Parent and info.hum and info.hum.Health > 0 then
                    local worldDist = myRoot and (info.part.Position - myRoot.Position).Magnitude or 0
                    if worldDist <= maxStuds then
                        local sp, onScreen = Camera:WorldToViewportPoint(info.part.Position)
                        if onScreen then
                            local d = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                            if d <= shortest then
                                shortest = d
                                bestType = "creature"
                                bestId = info.eid
                                bestPart = info.part
                            end
                        end
                    end
                else
                    Hub.CachedCreatures[model] = nil
                end
            end
        end

        return bestType, bestId, bestPart
    end

    -- Ballistic Velocity & Gravity Drop Prediction for Bow & Bola
    local function PredictProjectileAim(originPos, targetPart)
        local targetPos = targetPart.Position
        local targetVel = targetPart.AssemblyLinearVelocity or Vector3.zero
        local dist = (targetPos - originPos).Magnitude
        local speed = math.max(Config.ProjSpeed, 40)
        local travelTime = dist / speed
        local dropOffset = 0.5 * Config.ProjGravity * (travelTime ^ 2)
        local predictedPos = targetPos + (targetVel * travelTime) + Vector3.new(0, dropOffset, 0)
        local aimDir = (predictedPos - originPos).Unit
        return aimDir, predictedPos
    end

    -- MovePull & MoveAsk Mitigation
    local PullBypassed = {}
    Hub.DisableMovePull = function()
        if not getconnections then return end
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and not PullBypassed[obj] then
                if obj.Name == "MovePull" or obj.Name == "MoveAsk" then
                    PullBypassed[obj] = true
                    Hub.Hooks.MovePullBlocked = Hub.Hooks.MovePullBlocked + 1
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

    -- Server Telemetry Listeners (StatSync & MapMarkerSync)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            if obj.Name == "StatSync" then
                table.insert(P2Conns, obj.OnClientEvent:Connect(function(data)
                    if type(data) == "table" then
                        if type(data.Health) == "number" then Hub.Stats.Health = data.Health end
                        if type(data.Food) == "number" then Hub.Stats.Food = data.Food end
                        if type(data.Water) == "number" then Hub.Stats.Water = data.Water end
                        if type(data.Stamina) == "number" then Hub.Stats.Stamina = data.Stamina end
                        if type(data.WeightCarried) == "number" then Hub.Stats.Weight = data.WeightCarried end
                        if Hub.UpdateHUD then Hub.UpdateHUD() end
                    end
                end))
            elseif obj.Name == "MapMarkerSync" then
                table.insert(P2Conns, obj.OnClientEvent:Connect(function(data)
                    if type(data) == "table" and type(data.m) == "table" then
                        local added = 0
                        for k, v in pairs(data.m) do
                            local pos = nil
                            if typeof(v) == "Vector3" then pos = v
                            elseif typeof(v) == "CFrame" then pos = v.Position
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

    -- Unified Outgoing Packet Handler
    local function HandleOutgoing(self, method, args, rawCaller)
        local okName, rName = pcall(function() return self.Name end)
        if not okName or type(rName) ~= "string" then
            return rawCaller(self, unpackArgs(args))
        end

        local rLower = string.lower(rName)

        if Config.SniffOutgoing and not NoisyRemotes[rLower] and not string.find(rLower, "chat") then
            local tagPrefix = (method == "InvokeServer") and "[INVOKE ->] " or "[GỬI ->] "
            local logMsg = tagPrefix .. rName .. " : " .. SerializeArgs(args)
            task.defer(function()
                Log(logMsg)
            end)
        end

        -- 1. Resource Buff
        if method == "FireServer" and Config.ResourceBuff then
            if rName == "Harvest" or rName == "DecorPick" or rName == "DecorMine" then
                local multi = math.floor(Config.BuffMultiplier)
                if multi > 1 then
                    pcall(function()
                        for _ = 1, math.min(multi - 1, 4) do
                            rawCaller(self, unpackArgs(args))
                        end
                    end)
                    return rawCaller(self, unpackArgs(args))
                end
            end
        end

        -- 2. Melee Strike Aim (Attacker-to-Target vector + MeleeRange check + FaceTarget)
        if method == "FireServer" and Config.SilentAim and rName == "Strike" then
            local modified = false
            pcall(function()
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local tType, tId, tPart = GetBestTarget(Config.MeleeRange)
                if myRoot and tType and tId and tPart then
                    local diff = tPart.Position - myRoot.Position
                    if diff.Magnitude > 0.05 then
                        local hitDir = diff.Unit
                        args[1] = tType
                        args[2] = tId
                        args[3], args[4], args[5] = hitDir.X, hitDir.Y, hitDir.Z
                        modified = true

                        if Config.FaceTargetOnHit then
                            local flatLook = Vector3.new(tPart.Position.X, myRoot.Position.Y, tPart.Position.Z)
                            myRoot.CFrame = CFrame.new(myRoot.Position, flatLook)
                        end
                    end
                end
            end)
            if modified then
                return rawCaller(self, unpackArgs(args))
            end
        end

        -- 3. Ranged Projectile Aim ("Aim All": Bow & Bola via SetAimPitch, DeviceLook & Projectile Remotes)
        if Config.ProjectileAim then
            local modifiedProj = false
            pcall(function()
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local _, _, tPart = GetBestTarget(350)
                if myRoot and tPart then
                    local origin = myRoot.Position + Vector3.new(0, 1.5, 0)
                    local aimDir, predPos = PredictProjectileAim(origin, tPart)

                    if rName == "SetAimPitch" and type(args[1]) == "number" then
                        args[1] = math.asin(math.clamp(aimDir.Y, -0.99, 0.99))
                        modifiedProj = true
                    elseif rName == "DeviceLook" and #args >= 3 then
                        args[1], args[2], args[3] = aimDir.X, aimDir.Y, aimDir.Z
                        modifiedProj = true
                    elseif string.find(rLower, "bow") or string.find(rLower, "arrow")
                        or string.find(rLower, "bola") or string.find(rLower, "throw")
                        or string.find(rLower, "shoot") or string.find(rLower, "proj") then
                        for i, v in ipairs(args) do
                            if typeof(v) == "Vector3" then
                                args[i] = (v.Magnitude <= 1.2) and aimDir or predPos
                                modifiedProj = true
                            elseif typeof(v) == "CFrame" then
                                args[i] = CFrame.new(v.Position, predPos)
                                modifiedProj = true
                            end
                        end
                    end
                end
            end)
            if modifiedProj then
                return rawCaller(self, unpackArgs(args))
            end
        end

        return rawCaller(self, unpackArgs(args))
    end

    local MetaHooked = false
    local function SetupNetworkHooks()
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
            local oldNewindex = gm.__newindex

            local LockedLightingProps = {
                ClockTime = 14,
                Brightness = 2,
                GlobalShadows = false,
                FogEnd = 100000,
                Ambient = Color3.fromRGB(165, 165, 165),
                OutdoorAmbient = Color3.fromRGB(165, 165, 165)
            }

            gm.__newindex = newcclosure(function(self, key, val)
                if not checkcaller() and Config.Fullbright then
                    if self == Lighting and LockedLightingProps[key] ~= nil then
                        return oldNewindex(self, key, LockedLightingProps[key])
                    end
                    if typeof(self) == "Instance" and self:IsA("Atmosphere") and (key == "Density" or key == "Haze") then
                        return oldNewindex(self, key, 0)
                    end
                end
                return oldNewindex(self, key, val)
            end)
            Hub.Hooks.Newindex = true

            gm.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()

                if Config.AntiBan and (method == "Kick" or method == "kick") and self == LocalPlayer then
                    task.defer(function() Log("[ANTI-BAN] Đã chặn lệnh Kick!") end)
                    return nil
                end

                if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                    return HandleOutgoing(self, method, { ... }, oldNamecall)
                end

                return oldNamecall(self, ...)
            end)
            Hub.Hooks.Namecall = true

            setreadonly(gm, true)
        end)

        pcall(function()
            if hookfunction then
                local dummyRE = Instance.new("RemoteEvent")
                local oldFire
                oldFire = hookfunction(dummyRE.FireServer, newcclosure(function(self, ...)
                    if not checkcaller() and typeof(self) == "Instance" then
                        return HandleOutgoing(self, "FireServer", { ... }, oldFire)
                    end
                    return oldFire(self, ...)
                end))
                dummyRE:Destroy()
                Hub.Hooks.FireServer = true

                local dummyRF = Instance.new("RemoteFunction")
                local oldInvoke
                oldInvoke = hookfunction(dummyRF.InvokeServer, newcclosure(function(self, ...)
                    if not checkcaller() and typeof(self) == "Instance" then
                        return HandleOutgoing(self, "InvokeServer", { ... }, oldInvoke)
                    end
                    return oldInvoke(self, ...)
                end))
                dummyRF:Destroy()
                Hub.Hooks.InvokeServer = true
            end
        end)
    end
    SetupNetworkHooks()

    local SniffedRemotes = {}
    Hub.AttachIncomingSniffer = function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if (obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent")) and not SniffedRemotes[obj] then
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

    -- Entity & World Classification
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
        handle = true, hitbox = true, rig = true
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

        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum then
                local part = obj:FindFirstChild("Hitbox") or obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    Hub.CachedCreatures[obj] = {
                        part = part,
                        hum = hum,
                        eid = ExtractEntityId(obj),
                        name = obj.Name
                    }
                    return
                end
            end
        end

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
        local nNotes, nCreatures = 0, 0
        for _ in pairs(Hub.CachedNotes) do nNotes = nNotes + 1 end
        for _ in pairs(Hub.CachedCreatures) do nCreatures = nCreatures + 1 end
        Log(string.format("[OK] V14 Cache: %d Note | %d Sinh vật.", nNotes, nCreatures))
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
        Hub.CachedCreatures[obj] = nil
    end))

    Hub.RunDiagnosticsFunc = function()
        local nNotes, nCreatures, nItems = 0, 0, 0
        for _ in pairs(Hub.CachedNotes) do nNotes = nNotes + 1 end
        for _ in pairs(Hub.CachedCreatures) do nCreatures = nCreatures + 1 end
        for _ in pairs(Hub.CachedItems) do nItems = nItems + 1 end
        Log("=== SELF-TEST DIAGNOSTICS (V14) ===")
        Log(string.format("Hooks: __namecall=%s | __newindex=%s | Fire=%s | Invoke=%s",
            tostring(Hub.Hooks.Namecall), tostring(Hub.Hooks.Newindex),
            tostring(Hub.Hooks.FireServer), tostring(Hub.Hooks.InvokeServer)))
        Log(string.format("Anti-Pullback: %d MovePull/Ask đã chặn | Ping: %dms",
            Hub.Hooks.MovePullBlocked, math.floor(Hub.Stats.PingMs)))
        Log(string.format("Cache: %d Notes | %d Creatures | %d Items",
            nNotes, nCreatures, nItems))
    end

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
-- BLOCK 3: SAFE MASSLESS HITBOX, FULLBRIGHT, TP NOTE & ESP
-- =========================================================
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Lighting = game:GetService("Lighting")
    local StatsService = game:GetService("Stats")

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local Hub = _G.PrimalHub

    local Config = Hub.Config
    local Log = Hub.Log
    local P3Conns = {}
    local P3Tasks = {}
    local IsTeleporting = false

    local CachedAtmospheres = {}
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then
            CachedAtmospheres[v] = true
        end
    end
    table.insert(P3Conns, Lighting.ChildAdded:Connect(function(v)
        if v:IsA("Atmosphere") then CachedAtmospheres[v] = true end
    end))
    table.insert(P3Conns, Lighting.ChildRemoved:Connect(function(v)
        CachedAtmospheres[v] = nil
    end))

    local SavedLighting = {
        ClockTime = Lighting.ClockTime,
        Brightness = Lighting.Brightness,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient
    }

    local function ApplyFullbrightNow()
        Lighting.ClockTime = 14
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Ambient = Color3.fromRGB(165, 165, 165)
        Lighting.OutdoorAmbient = Color3.fromRGB(165, 165, 165)
        for atm in pairs(CachedAtmospheres) do
            if atm and atm.Parent then
                atm.Density = 0
                atm.Haze = 0
            end
        end
    end

    local RenderStepName = "PrimalV14_FullbrightLock"
    pcall(function() RunService:UnbindFromRenderStep(RenderStepName) end)
    RunService:BindToRenderStep(RenderStepName, Enum.RenderPriority.Last.Value + 1, function()
        if Config.Fullbright then
            pcall(ApplyFullbrightNow)
        elseif Config.TimeOverride then
            pcall(function() Lighting.ClockTime = Config.TimeOfDay end)
        end
    end)

    table.insert(P3Tasks, task.spawn(function()
        while task.wait(1.5) do
            pcall(function()
                local net = StatsService:FindFirstChild("Network")
                local ssi = net and net:FindFirstChild("ServerStatsItem")
                local pingItem = ssi and ssi:FindFirstChild("Data Ping")
                if pingItem then
                    Hub.Stats.PingMs = pingItem:GetValue()
                else
                    Hub.Stats.PingMs = LocalPlayer:GetNetworkPing() * 1000
                end
                if Hub.UpdateHUD then Hub.UpdateHUD() end
            end)
        end
    end))

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
            Log("[TP] Đang lướt an toàn tới " .. info.name .. "...")
            local lastGroundPulse = tick()
            while IsTeleporting and myRoot and myRoot.Parent and targetPart and targetPart.Parent do
                local dt = RunService.Heartbeat:Wait()
                local goalPos = targetPart.Position + Vector3.new(0, 2.5, 0)
                local diff = goalPos - myRoot.Position
                local dist = diff.Magnitude

                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero

                if Config.AntiFlyPulse and (tick() - lastGroundPulse >= 0.75) then
                    lastGroundPulse = tick()
                    pcall(function()
                        myHum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                    task.wait(0.06)
                end

                local effectiveSpeed = Config.TPSpeed
                if Config.PingCompensate and Hub.Stats.PingMs > 120 then
                    local scale = math.clamp(120 / Hub.Stats.PingMs, 0.45, 1.0)
                    effectiveSpeed = effectiveSpeed * scale
                end

                if dist <= 6 then
                    myRoot.CFrame = CFrame.new(goalPos)
                    break
                else
                    local step = math.min(dist, effectiveSpeed * dt)
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

    -- Auto-Gather Aura & Auto Survive
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

    -- ESP Synchronization
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
                        bg.Size = UDim2.new(0, 195, 0, 32)
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

    local function SyncCreatureESP()
        if not Config.CreatureESP then
            ClearTagMap(Hub.CreatureTags)
            return
        end
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local maxDist = Config.ESPDistance
        local fontSize = math.floor(Config.ESPSize)

        for model, info in pairs(Hub.CachedCreatures) do
            if not model or not model.Parent or not info.part or not info.part.Parent or not info.hum or info.hum.Health <= 0 then
                Hub.CachedCreatures[model] = nil
                if Hub.CreatureTags[model] then Hub.CreatureTags[model]:Destroy() Hub.CreatureTags[model] = nil end
            else
                local dist = myRoot and math.floor((info.part.Position - myRoot.Position).Magnitude) or 0
                if dist <= maxDist then
                    local bg = Hub.CreatureTags[model]
                    if not bg or not bg.Parent then
                        bg = Instance.new("BillboardGui")
                        bg.Name = "PrimalCreatureTag"
                        bg.Adornee = info.part
                        bg.Size = UDim2.new(0, 195, 0, 34)
                        bg.StudsOffset = Vector3.new(0, 3.0, 0)
                        bg.AlwaysOnTop = true

                        local lbl = Instance.new("TextLabel")
                        lbl.Name = "Txt"
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.TextColor3 = Color3.fromRGB(52, 211, 153)
                        lbl.TextStrokeTransparency = 0.2
                        lbl.Parent = bg

                        bg.Parent = info.part
                        Hub.CreatureTags[model] = bg
                    end
                    bg.Txt.TextSize = fontSize
                    bg.Txt.Text = string.format("[DINO] %s\nHP: %d/%d | %dm", info.name, math.floor(info.hum.Health), math.floor(info.hum.MaxHealth), dist)
                elseif Hub.CreatureTags[model] then
                    Hub.CreatureTags[model]:Destroy()
                    Hub.CreatureTags[model] = nil
                end
            end
        end
    end

    table.insert(P3Tasks, task.spawn(function()
        while task.wait(0.8) do
            pcall(SyncCacheESP, Hub.CachedNotes, Hub.NoteTags, "PrimalNoteTag", Config.NoteESP, true)
            pcall(SyncCacheESP, Hub.CachedItems, Hub.ItemTags, "PrimalItemTag", Config.ItemESP, false)
            pcall(SyncCacheESP, Hub.CachedStructures, Hub.StructureTags, "PrimalStructTag", Config.StructureESP, false)
            pcall(SyncCreatureESP)
        end
    end))

    -- Safe Hitbox Restoration (Restores Size, Massless, CustomPhysicalProperties)
    local function RestoreAllHitboxes()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                local saved = Hub.OriginalSizes[plr]
                if hrp and saved then
                    hrp.Size = saved.Size
                    hrp.Massless = saved.Massless
                    hrp.CustomPhysicalProperties = saved.Phys
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
        elseif key == "CreatureESP" then
            SyncCreatureESP()
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
        elseif key == "SniffOutgoing" and state then
            Log("[DEBUG] Đã bật soi mọi gói tin gửi đi.")
        elseif key == "Fullbright" then
            if state then
                SavedLighting.ClockTime = Lighting.ClockTime
                SavedLighting.Brightness = Lighting.Brightness
                SavedLighting.GlobalShadows = Lighting.GlobalShadows
                SavedLighting.FogEnd = Lighting.FogEnd
                SavedLighting.Ambient = Lighting.Ambient
                SavedLighting.OutdoorAmbient = Lighting.OutdoorAmbient
                ApplyFullbrightNow()
            else
                pcall(function()
                    Lighting.ClockTime = SavedLighting.ClockTime
                    Lighting.Brightness = SavedLighting.Brightness
                    Lighting.GlobalShadows = SavedLighting.GlobalShadows
                    Lighting.FogEnd = SavedLighting.FogEnd
                    Lighting.Ambient = SavedLighting.Ambient
                    Lighting.OutdoorAmbient = SavedLighting.OutdoorAmbient
                end)
            end
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

    local ZeroPhys = PhysicalProperties.new(0, 0, 0, 0, 0)

    table.insert(P3Conns, RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            if FOVCircle then
                FOVCircle.Position = screenCenter
                FOVCircle.Radius = Config.AimFOV
                FOVCircle.Visible = (Config.SilentAim or Config.ProjectileAim or Config.CameraAim or Config.HitboxExpand)
            end

            if Config.FOVOverride then
                Camera.FieldOfView = Config.CameraFOV
            end

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
            local hbSize = Config.HitboxSize

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

                        -- Massless + Zero-Density Hitbox (Prevents launching enemies into the sky)
                        if Config.HitboxExpand then
                            if not Hub.OriginalSizes[plr] then
                                Hub.OriginalSizes[plr] = {
                                    Size = hrp.Size,
                                    Massless = hrp.Massless,
                                    Phys = hrp.CustomPhysicalProperties
                                }
                            end
                            hrp.CanCollide = false
                            hrp.Massless = true
                            hrp.CustomPhysicalProperties = ZeroPhys
                            hrp.Size = Vector3.new(hbSize, hbSize, hbSize)
                            hrp.Transparency = 0.85
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

    Log("[OK] PrimalTool V14 (Fix Hitbox Bay + Aim All) sẵn sàng!")

    Hub.Part3Cleanup = function()
        IsTeleporting = false
        pcall(function() RunService:UnbindFromRenderStep(RenderStepName) end)
        for _, c in ipairs(P3Conns) do if c then pcall(function() c:Disconnect() end) end end
        for _, t in ipairs(P3Tasks) do if t then pcall(task.cancel, t) end end
        table.clear(P3Conns)
        table.clear(P3Tasks)
        ClearTagMap(Hub.NoteTags)
        ClearTagMap(Hub.ItemTags)
        ClearTagMap(Hub.StructureTags)
        ClearTagMap(Hub.CreatureTags)
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
