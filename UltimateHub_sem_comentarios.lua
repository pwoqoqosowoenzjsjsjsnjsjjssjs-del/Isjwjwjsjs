if getgenv and getgenv().UltimateHubLoaded then
    pcall(function() getgenv().UltimateHubUnload() end)
end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local CoreGui          = game:GetService("CoreGui")
local StarterGui       = game:GetService("StarterGui")
local Workspace        = game:GetService("Workspace")

local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local VirtualUser
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Connections = {}
local Cleanup = {}

local function Track(conn)
    table.insert(Connections, conn)
    return conn
end

local function OnUnload(fn)
    table.insert(Cleanup, fn)
end

local Util = {}

function Util.Tween(obj, time, props, style, dir)
    if not obj then return end
    local info = TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

function Util.Spring(obj, props, time)
    return Util.Tween(obj, time or 0.45, props, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

function Util.Create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

function Util.Corner(parent, radius)
    return Util.Create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function Util.Round(parent)
    return Util.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function Util.Stroke(parent, color, thickness, transparency)
    return Util.Create("UIStroke", {
        Color = color or Color3.fromRGB(255, 255, 255),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function Util.Padding(parent, t, r, b, l)
    return Util.Create("UIPadding", {
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or t or 0),
        PaddingBottom = UDim.new(0, b or t or 0),
        PaddingLeft = UDim.new(0, l or r or t or 0),
        Parent = parent,
    })
end

function Util.List(parent, padding, dir, halign, valign)
    return Util.Create("UIListLayout", {
        Padding = UDim.new(0, padding or 6),
        FillDirection = dir or Enum.FillDirection.Vertical,
        HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = valign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

function Util.Clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

function Util.Lerp(a, b, t)
    return a + (b - a) * t
end

function Util.RoundTo(x, step)
    step = step or 1
    return math.floor(x / step + 0.5) * step
end

function Util.Flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

function Util.SafeUnit(v)
    if v.Magnitude < 1e-4 then
        return Vector3.new(0, 0, 0)
    end
    return v.Unit
end

function Util.ColorToTable(c)
    return { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }
end

function Util.TableToColor(t)
    return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255)
end

function Util.Darken(c, amount)
    local h, s, v = c:ToHSV()
    return Color3.fromHSV(h, s, Util.Clamp(v - amount, 0, 1))
end

function Util.Lighten(c, amount)
    local h, s, v = c:ToHSV()
    return Color3.fromHSV(h, Util.Clamp(s - amount * 0.3, 0, 1), Util.Clamp(v + amount, 0, 1))
end

function Util.GetGuiParent()
    local ok, hui = pcall(function()
        if gethui then return gethui() end
        return nil
    end)
    if ok and hui then return hui end
    local ok2 = pcall(function() local _ = CoreGui.Name end)
    if ok2 then
        local test = Instance.new("ScreenGui")
        local ok3 = pcall(function() test.Parent = CoreGui end)
        test:Destroy()
        if ok3 then return CoreGui end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function Util.Protect(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)
end

function Util.IsMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Util.Character()
    return LocalPlayer.Character
end

function Util.Root()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Util.Humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Util.FormatNumber(n)
    local s = tostring(math.floor(n))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    if formatted:sub(1, 1) == "." then formatted = formatted:sub(2) end
    return formatted
end

function Util.PressKey(keyCode, hold)
    if not VirtualInputManager or not keyCode then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.delay(hold or 0.05, function()
            pcall(function() VirtualInputManager:SendKeyEvent(false, keyCode, false, game) end)
        end)
    end)
end

function Util.HoldKey(keyCode, down)
    if not VirtualInputManager or not keyCode then return end
    pcall(function() VirtualInputManager:SendKeyEvent(down, keyCode, false, game) end)
end

function Util.Click(button)
    if not VirtualInputManager then return end
    pcall(function()
        local vp = Camera.ViewportSize
        local b = button or 0
        VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, b, true, game, 0)
        task.delay(0.05, function()
            pcall(function() VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, b, false, game, 0) end)
        end)
    end)
end

local Theme = {
    Background   = Color3.fromRGB(18, 18, 20),
    Topbar       = Color3.fromRGB(18, 18, 20),
    Element      = Color3.fromRGB(30, 30, 33),
    ElementHover = Color3.fromRGB(37, 37, 41),
    ElementPress = Color3.fromRGB(44, 44, 49),
    Stroke       = Color3.fromRGB(48, 48, 54),
    Text         = Color3.fromRGB(236, 236, 240),
    SubText      = Color3.fromRGB(138, 138, 148),
    Muted        = Color3.fromRGB(96, 96, 104),
    TabIdle      = Color3.fromRGB(26, 26, 29),
    TabActive    = Color3.fromRGB(46, 46, 51),
    Accent       = Color3.fromRGB(40, 190, 110),
    AccentDark   = Color3.fromRGB(20, 92, 58),
    AccentDeep   = Color3.fromRGB(16, 46, 32),
    Track        = Color3.fromRGB(42, 42, 47),
    Knob         = Color3.fromRGB(245, 245, 247),
    KnobOff      = Color3.fromRGB(78, 78, 86),
    Badge        = Color3.fromRGB(255, 194, 26),
    BadgeText    = Color3.fromRGB(40, 28, 0),
    Danger       = Color3.fromRGB(235, 84, 84),
    Warning      = Color3.fromRGB(255, 176, 46),
    Font         = Enum.Font.GothamMedium,
    FontBold     = Enum.Font.GothamBold,
    FontRegular  = Enum.Font.Gotham,
}

local AccentPresets = {
    ["Verde"]    = Color3.fromRGB(40, 190, 110),
    ["Azul"]     = Color3.fromRGB(56, 140, 255),
    ["Roxo"]     = Color3.fromRGB(150, 98, 255),
    ["Vermelho"] = Color3.fromRGB(236, 72, 80),
    ["Laranja"]  = Color3.fromRGB(255, 140, 40),
    ["Rosa"]     = Color3.fromRGB(240, 90, 170),
    ["Ciano"]    = Color3.fromRGB(30, 200, 210),
}

local AccentBindings = {}

local function BindAccent(obj, prop, kind, condition)
    table.insert(AccentBindings, { obj = obj, prop = prop, kind = kind or "Accent", condition = condition })
end

local AccentCallbacks = {}
local function OnAccentChanged(fn)
    table.insert(AccentCallbacks, fn)
end

local function ResolveAccent(kind)
    if kind == "Accent" then return Theme.Accent end
    if kind == "AccentDark" then return Theme.AccentDark end
    if kind == "AccentDeep" then return Theme.AccentDeep end
    return Theme.Accent
end

local GradientBindings = {}

local function ApplyAccent(color)
    Theme.Accent = color
    Theme.AccentDark = Util.Darken(color, 0.42)
    Theme.AccentDeep = Util.Darken(color, 0.6)
    for i = #AccentBindings, 1, -1 do
        local b = AccentBindings[i]
        if b.obj and b.obj.Parent then
            if b.condition == nil or b.condition() then
                Util.Tween(b.obj, 0.35, { [b.prop] = ResolveAccent(b.kind) })
            end
        else
            table.remove(AccentBindings, i)
        end
    end
    for i = #GradientBindings, 1, -1 do
        local g = GradientBindings[i]
        if g and g.Parent then
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Theme.AccentDeep),
                ColorSequenceKeypoint.new(1, Theme.Accent),
            })
        else
            table.remove(GradientBindings, i)
        end
    end
    for _, fn in ipairs(AccentCallbacks) do
        pcall(fn, color)
    end
end

local Icons = {}

local function Piece(parent, size, pos, color, rot, round, z)
    local f = Util.Create("Frame", {
        Size = size,
        Position = pos,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Rotation = rot or 0,
        ZIndex = z or 1,
        Parent = parent,
    })
    if round == true then
        Util.Round(f)
    elseif type(round) == "number" then
        Util.Corner(f, round)
    end
    return f
end

local function Ring(parent, size, pos, color, thickness, z)
    local f = Util.Create("Frame", {
        Size = size,
        Position = pos,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = z or 1,
        Parent = parent,
    })
    Util.Round(f)
    Util.Stroke(f, color, thickness or 2, 0)
    return f
end

local function Holder(parent, size)
    return Util.Create("Frame", {
        Name = "Icon",
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })
end

local function C(x, y) return UDim2.fromScale(x, y) end

Icons.Draw = {}

Icons.Draw.home = function(h, s, col)

    Piece(h, UDim2.fromOffset(s * 0.56, s * 0.56), C(0.5, 0.42), col, 45, 2)
    Piece(h, UDim2.fromOffset(s * 0.62, s * 0.44), C(0.5, 0.7), col, 0, 2)
end

Icons.Draw.shield = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.7, s * 0.46), C(0.5, 0.35), col, 0, 3)
    Piece(h, UDim2.fromOffset(s * 0.5, s * 0.5), C(0.5, 0.56), col, 45, 2)
end

Icons.Draw.glove = function(h, s, col)

    Piece(h, UDim2.fromOffset(s * 0.56, s * 0.42), C(0.5, 0.68), col, 0, 4)
    for i = 0, 3 do
        Piece(h, UDim2.fromOffset(s * 0.12, s * 0.38), C(0.29 + i * 0.14, 0.38 - (i == 1 and 0.05 or 0) - (i == 2 and 0.05 or 0)), col, 0, true)
    end
    Piece(h, UDim2.fromOffset(s * 0.12, s * 0.32), C(0.82, 0.6), col, 35, true)
end

Icons.Draw.ball = function(h, s, col)
    Ring(h, UDim2.fromOffset(s * 0.82, s * 0.82), C(0.5, 0.5), col, math.max(1.5, s / 10))
    Piece(h, UDim2.fromOffset(s * 0.26, s * 0.26), C(0.5, 0.5), col, 45, 1)
    Piece(h, UDim2.fromOffset(s * 0.08, s * 0.2), C(0.5, 0.24), col, 0, 0)
    Piece(h, UDim2.fromOffset(s * 0.08, s * 0.2), C(0.27, 0.6), col, 60, 0)
    Piece(h, UDim2.fromOffset(s * 0.08, s * 0.2), C(0.73, 0.6), col, -60, 0)
end

Icons.Draw.user = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.38, s * 0.38), C(0.5, 0.3), col, 0, true)
    Piece(h, UDim2.fromOffset(s * 0.72, s * 0.4), C(0.5, 0.82), col, 0, math.floor(s * 0.2))
end

Icons.Draw.eye = function(h, s, col)
    local e = Ring(h, UDim2.fromOffset(s * 0.86, s * 0.5), C(0.5, 0.5), col, math.max(1.5, s / 10))
    e:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
    Piece(h, UDim2.fromOffset(s * 0.26, s * 0.26), C(0.5, 0.5), col, 0, true)
end

Icons.Draw.gear = function(h, s, col, bg)
    for i = 0, 3 do
        Piece(h, UDim2.fromOffset(s * 0.22, s * 0.9), C(0.5, 0.5), col, i * 45, 2)
    end
    Piece(h, UDim2.fromOffset(s * 0.64, s * 0.64), C(0.5, 0.5), col, 0, true)
    Piece(h, UDim2.fromOffset(s * 0.28, s * 0.28), C(0.5, 0.5), bg or Theme.Background, 0, true)
end

Icons.Draw.search = function(h, s, col)
    Ring(h, UDim2.fromOffset(s * 0.56, s * 0.56), C(0.42, 0.42), col, math.max(1.5, s / 9))
    Piece(h, UDim2.fromOffset(s * 0.13, s * 0.36), C(0.76, 0.76), col, -45, 1)
end

Icons.Draw.list = function(h, s, col)
    for i = 0, 2 do
        Piece(h, UDim2.fromOffset(s * 0.7, s * 0.11), C(0.5, 0.26 + i * 0.24), col, 0, 1)
    end
end

Icons.Draw.close = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.1, s * 0.86), C(0.5, 0.5), col, 45, 1)
    Piece(h, UDim2.fromOffset(s * 0.1, s * 0.86), C(0.5, 0.5), col, -45, 1)
end

Icons.Draw.minus = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.7, s * 0.1), C(0.5, 0.5), col, 0, 1)
end

Icons.Draw.plus = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.7, s * 0.12), C(0.5, 0.5), col, 0, 1)
    Piece(h, UDim2.fromOffset(s * 0.12, s * 0.7), C(0.5, 0.5), col, 0, 1)
end

Icons.Draw.chevron = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.12, s * 0.46), C(0.38, 0.5), col, -45, 1)
    Piece(h, UDim2.fromOffset(s * 0.12, s * 0.46), C(0.62, 0.5), col, 45, 1)
end

Icons.Draw.target = function(h, s, col)
    Ring(h, UDim2.fromOffset(s * 0.84, s * 0.84), C(0.5, 0.5), col, math.max(1.5, s / 11))
    Ring(h, UDim2.fromOffset(s * 0.46, s * 0.46), C(0.5, 0.5), col, math.max(1.5, s / 11))
    Piece(h, UDim2.fromOffset(s * 0.14, s * 0.14), C(0.5, 0.5), col, 0, true)
end

Icons.Draw.bolt = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.16, s * 0.56), C(0.56, 0.3), col, 25, 1)
    Piece(h, UDim2.fromOffset(s * 0.5, s * 0.14), C(0.5, 0.5), col, -10, 1)
    Piece(h, UDim2.fromOffset(s * 0.16, s * 0.56), C(0.44, 0.7), col, 25, 1)
end

Icons.Draw.star = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.5, s * 0.5), C(0.5, 0.5), col, 0, 1)
    Piece(h, UDim2.fromOffset(s * 0.5, s * 0.5), C(0.5, 0.5), col, 45, 1)
end

Icons.Draw.check = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.13, s * 0.36), C(0.34, 0.6), col, -45, 1)
    Piece(h, UDim2.fromOffset(s * 0.13, s * 0.66), C(0.6, 0.48), col, 40, 1)
end

Icons.Draw.info = function(h, s, col)
    Ring(h, UDim2.fromOffset(s * 0.84, s * 0.84), C(0.5, 0.5), col, math.max(1.5, s / 11))
    Piece(h, UDim2.fromOffset(s * 0.12, s * 0.32), C(0.5, 0.58), col, 0, 1)
    Piece(h, UDim2.fromOffset(s * 0.13, s * 0.13), C(0.5, 0.3), col, 0, true)
end

Icons.Draw.warn = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.13, s * 0.44), C(0.5, 0.4), col, 0, 1)
    Piece(h, UDim2.fromOffset(s * 0.14, s * 0.14), C(0.5, 0.82), col, 0, true)
end

Icons.Draw.goal = function(h, s, col)

    Piece(h, UDim2.fromOffset(s * 0.1, s * 0.64), C(0.14, 0.6), col, 0, 0)
    Piece(h, UDim2.fromOffset(s * 0.1, s * 0.64), C(0.86, 0.6), col, 0, 0)
    Piece(h, UDim2.fromOffset(s * 0.82, s * 0.1), C(0.5, 0.3), col, 0, 0)
    for i = 1, 3 do
        local net = Piece(h, UDim2.fromOffset(s * 0.04, s * 0.5), C(0.14 + i * 0.18, 0.6), col, 0, 0)
        net.BackgroundTransparency = 0.55
    end
end

Icons.Draw.camera = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.84, s * 0.56), C(0.5, 0.56), col, 0, 3)
    Piece(h, UDim2.fromOffset(s * 0.3, s * 0.16), C(0.36, 0.26), col, 0, 1)
    Ring(h, UDim2.fromOffset(s * 0.3, s * 0.3), C(0.5, 0.56), Theme.Background, math.max(1.5, s / 10), 2)
end

Icons.Draw.run = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.24, s * 0.24), C(0.62, 0.16), col, 0, true)
    Piece(h, UDim2.fromOffset(s * 0.14, s * 0.42), C(0.52, 0.46), col, 20, 1)
    Piece(h, UDim2.fromOffset(s * 0.12, s * 0.38), C(0.36, 0.78), col, 35, 1)
    Piece(h, UDim2.fromOffset(s * 0.12, s * 0.38), C(0.62, 0.8), col, -25, 1)
    Piece(h, UDim2.fromOffset(s * 0.34, s * 0.1), C(0.4, 0.4), col, -20, 1)
end

Icons.Draw.save = function(h, s, col, bg)
    Piece(h, UDim2.fromOffset(s * 0.78, s * 0.78), C(0.5, 0.5), col, 0, 3)
    Piece(h, UDim2.fromOffset(s * 0.42, s * 0.22), C(0.5, 0.28), bg or Theme.Element, 0, 1)
    Piece(h, UDim2.fromOffset(s * 0.5, s * 0.26), C(0.5, 0.72), bg or Theme.Element, 0, 1)
end

Icons.Draw.trash = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.56, s * 0.6), C(0.5, 0.62), col, 0, 2)
    Piece(h, UDim2.fromOffset(s * 0.76, s * 0.1), C(0.5, 0.24), col, 0, 1)
    Piece(h, UDim2.fromOffset(s * 0.26, s * 0.1), C(0.5, 0.14), col, 0, 1)
end

Icons.Draw.keyboard = function(h, s, col, bg)
    Piece(h, UDim2.fromOffset(s * 0.9, s * 0.56), C(0.5, 0.5), col, 0, 3)
    for i = 0, 3 do
        Piece(h, UDim2.fromOffset(s * 0.1, s * 0.1), C(0.22 + i * 0.19, 0.4), bg or Theme.Element, 0, 0)
    end
    Piece(h, UDim2.fromOffset(s * 0.5, s * 0.1), C(0.5, 0.62), bg or Theme.Element, 0, 0)
end

Icons.Draw.brush = function(h, s, col)
    Piece(h, UDim2.fromOffset(s * 0.16, s * 0.6), C(0.6, 0.38), col, 40, 1)
    Piece(h, UDim2.fromOffset(s * 0.3, s * 0.3), C(0.3, 0.72), col, 40, 4)
end

Icons.Draw.globe = function(h, s, col)
    Ring(h, UDim2.fromOffset(s * 0.84, s * 0.84), C(0.5, 0.5), col, math.max(1.5, s / 11))
    local m = Ring(h, UDim2.fromOffset(s * 0.36, s * 0.84), C(0.5, 0.5), col, math.max(1.5, s / 11))
    m:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
    Piece(h, UDim2.fromOffset(s * 0.84, s * 0.08), C(0.5, 0.5), col, 0, 0)
end

function Icons.New(parent, name, size, color, bg)
    local s = size or 16
    local ink = color or Theme.SubText
    local h = Holder(parent, s)
    local fn = Icons.Draw[name] or Icons.Draw.star
    fn(h, s, ink, bg)
    for _, d in ipairs(h:GetDescendants()) do
        if d:IsA("Frame") and d.BackgroundTransparency < 1 and d.BackgroundColor3 == ink then
            d:SetAttribute("Ink", true)
        elseif d:IsA("UIStroke") and d.Color == ink then
            d:SetAttribute("Ink", true)
        end
    end
    return h
end

function Icons.Recolor(holder, to, time)
    if not holder then return end
    for _, d in ipairs(holder:GetDescendants()) do
        if d:GetAttribute("Ink") then
            if d:IsA("Frame") then
                Util.Tween(d, time or 0.2, { BackgroundColor3 = to })
            elseif d:IsA("UIStroke") then
                Util.Tween(d, time or 0.2, { Color = to })
            end
        end
    end
end

local TextService = game:GetService("TextService")

local Library = {
    Flags = {},
    Elements = {},
    Tabs = {},
    CurrentTab = nil,
    Visible = true,
    Minimized = false,
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "UltimateHub",
    ConfigFile = "FutebolProibido.json",
    Searchable = {},
}

local function TextWidth(text, size, font)
    local ok, v = pcall(function()
        return TextService:GetTextSize(text, size, font, Vector2.new(1000, 100)).X
    end)
    if ok then return v end
    return #text * size * 0.55
end

local function Label(parent, props)
    local l = Util.Create("TextLabel", {
        BackgroundTransparency = 1,
        Font = props.Font or Theme.Font,
        Text = props.Text or "",
        TextSize = props.TextSize or 14,
        TextColor3 = props.Color or Theme.Text,
        TextXAlignment = props.XAlign or Enum.TextXAlignment.Left,
        TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
        Size = props.Size or UDim2.new(1, 0, 0, 18),
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.new(),
        TextTruncate = props.Truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
        TextWrapped = props.Wrapped or false,
        RichText = props.Rich or false,
        ZIndex = props.ZIndex or 1,
        Name = props.Name or "Label",
        Parent = parent,
    })
    return l
end

local function Clicker(parent, z)
    return Util.Create("TextButton", {
        Name = "Clicker",
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = z or 5,
        Parent = parent,
    })
end

local function Ripple(parent, x, y)
    local abs = parent.AbsolutePosition
    local r = Util.Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.86,
        Size = UDim2.fromOffset(0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset((x or abs.X + parent.AbsoluteSize.X / 2) - abs.X, (y or abs.Y + parent.AbsoluteSize.Y / 2) - abs.Y),
        ZIndex = 4,
        Parent = parent,
    })
    Util.Round(r)
    local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2
    Util.Tween(r, 0.55, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
    task.delay(0.6, function() r:Destroy() end)
end

local function Hover(card, clicker)
    clicker.MouseEnter:Connect(function()
        Util.Tween(card, 0.18, { BackgroundColor3 = Theme.ElementHover })
    end)
    clicker.MouseLeave:Connect(function()
        Util.Tween(card, 0.25, { BackgroundColor3 = Theme.Element })
    end)
end

local function Card(parent, height, order)
    local f = Util.Create("Frame", {
        Name = "Element",
        BackgroundColor3 = Theme.Element,
        Size = UDim2.new(1, 0, 0, height or 46),
        LayoutOrder = order or 0,
        ClipsDescendants = true,
        Parent = parent,
    })
    Util.Corner(f, 12)
    Util.Stroke(f, Theme.Stroke, 1, 0.55)
    return f
end

local function MakeDraggable(handle, target, onDragEnd)
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onDragEnd then onDragEnd() end
                    conn:Disconnect()
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart then
            local delta = input.Position - dragStart
            Util.Tween(target, 0.12, {
                Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            }, Enum.EasingStyle.Quad)
        end
    end))
end

local function KeyName(key)
    if typeof(key) ~= "EnumItem" then return "Nenhuma" end
    local n = key.Name
    local map = {
        LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
        LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Enter", Space = "Espaco",
        MouseButton1 = "Mouse1", MouseButton2 = "Mouse2",
    }
    return map[n] or n
end

local function SetFlag(flag, value)
    if flag then Library.Flags[flag] = value end
end

local function SafeCallback(cb, ...)
    if not cb then return end
    local args = { ... }
    task.spawn(function()
        local ok, err = pcall(cb, unpack(args))
        if not ok then warn("[UltimateHub] callback erro: " .. tostring(err)) end
    end)
end

local NotifyHolder, ToastHolder

function Library:Notify(opts)
    opts = opts or {}
    if not NotifyHolder then return end
    local duration = opts.Duration or 4
    local kind = opts.Type or "info"
    local color = Theme.Accent
    local icon = "info"
    if kind == "success" then icon = "check" elseif kind == "warn" then icon = "warn"; color = Theme.Warning
    elseif kind == "error" then icon = "warn"; color = Theme.Danger end

    local slot = Util.Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = false,
        Parent = NotifyHolder,
    })
    local card = Util.Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(22, 22, 25),
        Size = UDim2.new(1, 0, 0, 72),
        Position = UDim2.new(1, 40, 0, 0),
        Parent = slot,
    })
    Util.Corner(card, 14)
    Util.Stroke(card, Theme.Stroke, 1, 0.2)
    local iconBg = Util.Create("Frame", {
        BackgroundColor3 = Util.Darken(color, 0.55),
        Size = UDim2.fromOffset(34, 34),
        Position = UDim2.fromOffset(14, 19),
        Parent = card,
    })
    Util.Corner(iconBg, 10)
    local ic = Icons.New(iconBg, icon, 16, color, Util.Darken(color, 0.55))
    ic.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.Position = UDim2.fromScale(0.5, 0.5)

    Label(card, { Text = opts.Title or "Ultimate Hub", Font = Theme.FontBold, TextSize = 14, Position = UDim2.fromOffset(60, 16), Size = UDim2.new(1, -74, 0, 18), Truncate = true })
    Label(card, { Text = opts.Content or "", TextSize = 13, Color = Theme.SubText, Font = Theme.FontRegular, Position = UDim2.fromOffset(60, 36), Size = UDim2.new(1, -74, 0, 18), Truncate = true })

    local bar = Util.Create("Frame", {
        BackgroundColor3 = color,
        Size = UDim2.new(1, -28, 0, 2),
        Position = UDim2.new(0, 14, 1, -6),
        BorderSizePixel = 0,
        Parent = card,
    })
    Util.Round(bar)

    Util.Tween(slot, 0.3, { Size = UDim2.new(1, 0, 0, 72) })
    Util.Tween(card, 0.5, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    Util.Tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        Util.Tween(card, 0.4, { Position = UDim2.new(1, 40, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.35)
        Util.Tween(slot, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
        task.wait(0.3)
        slot:Destroy()
    end)
end

function Library:Toast(title, sub, duration)
    if not ToastHolder then return end
    local pill = Util.Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(8, 8, 9),
        Size = UDim2.fromOffset(0, 58),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -70),
        ClipsDescendants = true,
        Parent = ToastHolder,
    })
    Util.Round(pill)
    Util.Stroke(pill, Theme.Stroke, 1, 0.5)
    local ic = Icons.New(pill, "star", 24, Theme.Text, Color3.fromRGB(8, 8, 9))
    ic.Position = UDim2.fromOffset(20, 17)
    Label(pill, { Text = title or "Ultimate Hub", Font = Theme.FontBold, TextSize = 16, Position = UDim2.fromOffset(58, 10), Size = UDim2.new(1, -70, 0, 20) })
    Label(pill, { Text = sub or "", TextSize = 13, Color = Theme.SubText, Font = Theme.FontRegular, Position = UDim2.fromOffset(58, 30), Size = UDim2.new(1, -70, 0, 18) })
    local w = math.max(TextWidth(title or "", 16, Theme.FontBold), TextWidth(sub or "", 13, Theme.FontRegular)) + 90
    Util.Tween(pill, 0.55, { Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(w, 58) }, Enum.EasingStyle.Back)
    task.delay(duration or 2.5, function()
        Util.Tween(pill, 0.4, { Position = UDim2.new(0.5, 0, 0, -70), Size = UDim2.fromOffset(w * 0.7, 58) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.45)
        pill:Destroy()
    end)
end

function Library:CreateWindow(opts)
    opts = opts or {}
    local Window = {}
    local mobile = Util.IsMobile()

    local gui = Util.Create("ScreenGui", {
        Name = "UltimateHub_" .. tostring(math.random(1000, 9999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
    })
    Util.Protect(gui)
    gui.Parent = Util.GetGuiParent()
    Library.Gui = gui
    OnUnload(function() gui:Destroy() end)

    NotifyHolder = Util.Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 300, 1, -40),
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -20),
        Parent = gui,
    })
    local nl = Util.List(NotifyHolder, 8)
    nl.VerticalAlignment = Enum.VerticalAlignment.Bottom

    ToastHolder = Util.Create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = gui,
    })

    local W, H = 500, 590
    local Root = Util.Create("Frame", {
        Name = "Root",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(W, H),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Parent = gui,
    })
    local scale = Util.Create("UIScale", { Scale = 1, Parent = Root })
    Window.Scale = scale
    Window.BaseScale = 1
    local vp = Camera.ViewportSize
    if mobile or vp.Y < 700 then
        Window.BaseScale = Util.Clamp(math.min(vp.Y / (H + 60), vp.X / (W + 40)), 0.55, 1)
    end

    for i = 1, 6 do
        local sh = Util.Create("Frame", {
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.82 + i * 0.025,
            Size = UDim2.new(1, i * 8, 1, i * 8),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 6),
            ZIndex = 0,
            Parent = Root,
        })
        Util.Corner(sh, 18 + i * 4)
    end

    local Main = Util.Create("CanvasGroup", {
        Name = "Main",
        BackgroundColor3 = Theme.Background,
        Size = UDim2.fromScale(1, 1),
        GroupTransparency = 1,
        Parent = Root,
    })
    Util.Corner(Main, 20)
    Util.Stroke(Main, Theme.Stroke, 1, 0.25)
    Window.Main = Main
    Window.Root = Root

    local glow = Util.Create("Frame", {
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.93,
        Size = UDim2.new(1, 0, 0, 160),
        BorderSizePixel = 0,
        Parent = Main,
    })
    local gg = Util.Create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
        Parent = glow,
    })
    BindAccent(glow, "BackgroundColor3")

    local Topbar = Util.Create("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 66),
        Parent = Main,
    })
    local title = opts.Title or "Ultimate Hub"
    Label(Topbar, { Text = title, Font = Theme.FontBold, TextSize = 19, Position = UDim2.fromOffset(22, 16), Size = UDim2.fromOffset(260, 22) })
    Label(Topbar, { Text = opts.Subtitle or "Rayfield Gen2", Font = Theme.FontRegular, TextSize = 12, Color = Theme.Muted, Position = UDim2.fromOffset(22, 38), Size = UDim2.fromOffset(260, 14) })

    local tw = TextWidth(title, 19, Theme.FontBold)
    local badgeText = opts.Badge or "updated"
    local bw = TextWidth(badgeText, 13, Theme.FontBold) + 22
    local badge = Util.Create("Frame", {
        BackgroundColor3 = Theme.Badge,
        Size = UDim2.fromOffset(bw, 24),
        Position = UDim2.fromOffset(22 + tw + 10, 15),
        Parent = Topbar,
    })
    Util.Round(badge)
    Label(badge, { Text = badgeText, Font = Theme.FontBold, TextSize = 13, Color = Theme.BadgeText, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })

    task.spawn(function()
        while badge.Parent do
            Util.Tween(badge, 1.2, { BackgroundColor3 = Color3.fromRGB(255, 210, 80) }, Enum.EasingStyle.Sine)
            task.wait(1.2)
            Util.Tween(badge, 1.2, { BackgroundColor3 = Theme.Badge }, Enum.EasingStyle.Sine)
            task.wait(1.2)
        end
    end)

    local function TopButton(iconName, xOffset, size)
        local b = Util.Create("TextButton", {
            BackgroundColor3 = Theme.ElementHover,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(30, 30),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, xOffset, 0, 18),
            Text = "",
            AutoButtonColor = false,
            Parent = Topbar,
        })
        Util.Corner(b, 9)
        local ic = Icons.New(b, iconName, size or 16, Theme.SubText, Theme.Background)
        ic.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Position = UDim2.fromScale(0.5, 0.5)
        b.MouseEnter:Connect(function()
            Util.Tween(b, 0.15, { BackgroundTransparency = 0 })
            Icons.Recolor(ic, Theme.Text)
        end)
        b.MouseLeave:Connect(function()
            Util.Tween(b, 0.2, { BackgroundTransparency = 1 })
            Icons.Recolor(ic, Theme.SubText)
        end)
        return b, ic
    end

    local closeBtn = TopButton("close", -16, 14)
    local minBtn = TopButton("minus", -50, 14)
    local setBtn, setIcon = TopButton("gear", -84, 17)
    local searchBtn = TopButton("search", -118, 16)

    MakeDraggable(Topbar, Root)

    local SearchBar = Util.Create("Frame", {
        BackgroundColor3 = Theme.Element,
        Size = UDim2.new(1, -40, 0, 0),
        Position = UDim2.fromOffset(20, 64),
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 6,
        Parent = Main,
    })
    Util.Corner(SearchBar, 12)
    Util.Stroke(SearchBar, Theme.Stroke, 1, 0.3)
    local sIc = Icons.New(SearchBar, "search", 14, Theme.Muted, Theme.Element)
    sIc.Position = UDim2.fromOffset(14, 11)
    sIc.ZIndex = 7
    local SearchBox = Util.Create("TextBox", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.fromOffset(38, 0),
        Font = Theme.Font,
        TextSize = 14,
        PlaceholderText = "Buscar funcao...",
        PlaceholderColor3 = Theme.Muted,
        Text = "",
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 7,
        Parent = SearchBar,
    })

    local TabBar = Util.Create("ScrollingFrame", {
        Name = "TabBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.fromOffset(0, 66),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0,
        BorderSizePixel = 0,
        Parent = Main,
    })
    Util.Padding(TabBar, 2, 20, 2, 20)
    Util.List(TabBar, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    local Content = Util.Create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -118),
        Position = UDim2.fromOffset(0, 118),
        ClipsDescendants = true,
        Parent = Main,
    })

    local fade = Util.Create("Frame", {
        BackgroundColor3 = Theme.Background,
        Size = UDim2.new(1, 0, 0, 34),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
        ZIndex = 20,
        Parent = Main,
    })
    Util.Create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
        Parent = fade,
    })

    local searchOpen = false
    local function SetSearch(open)
        searchOpen = open
        if open then
            SearchBar.Visible = true
            Util.Tween(SearchBar, 0.3, { Size = UDim2.new(1, -40, 0, 38) })
            Util.Tween(TabBar, 0.3, { Position = UDim2.fromOffset(0, 108) })
            Util.Tween(Content, 0.3, { Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 1, -160) })
            task.delay(0.1, function() SearchBox:CaptureFocus() end)
        else
            SearchBox.Text = ""
            Util.Tween(SearchBar, 0.25, { Size = UDim2.new(1, -40, 0, 0) })
            Util.Tween(TabBar, 0.3, { Position = UDim2.fromOffset(0, 66) })
            Util.Tween(Content, 0.3, { Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 1, -118) })
            task.delay(0.26, function() if not searchOpen then SearchBar.Visible = false end end)
        end
    end
    searchBtn.MouseButton1Click:Connect(function() SetSearch(not searchOpen) end)

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(SearchBox.Text)
        local tab = Library.CurrentTab
        if not tab then return end
        for _, item in ipairs(tab.Items) do
            if item.Frame and item.Frame.Parent then
                if q == "" then
                    item.Frame.Visible = true
                elseif item.IsHeader then
                    item.Frame.Visible = false
                else
                    item.Frame.Visible = string.find(string.lower(item.Name), q, 1, true) ~= nil
                end
            end
        end
    end)

    local Dim = Util.Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 40,
        Parent = Main,
    })
    local Dialog = Util.Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(26, 26, 29),
        Size = UDim2.fromOffset(300, 150),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.55),
        ZIndex = 41,
        Parent = Dim,
    })
    Util.Corner(Dialog, 16)
    Util.Stroke(Dialog, Theme.Stroke, 1, 0)
    Label(Dialog, { Text = "Fechar o Ultimate Hub?", Font = Theme.FontBold, TextSize = 16, Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 0, 20), ZIndex = 42 })
    Label(Dialog, { Text = "Todas as funcoes serao desligadas.", Font = Theme.FontRegular, TextSize = 13, Color = Theme.SubText, Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -40, 0, 18), ZIndex = 42 })
    local function DialogButton(text, x, primary)
        local b = Util.Create("TextButton", {
            BackgroundColor3 = primary and Theme.Danger or Theme.Element,
            Size = UDim2.new(0.5, -26, 0, 38),
            Position = UDim2.new(x, x == 0 and 20 or 6, 1, -56),
            Text = text,
            Font = Theme.FontBold,
            TextSize = 14,
            TextColor3 = primary and Color3.fromRGB(255, 255, 255) or Theme.Text,
            AutoButtonColor = false,
            ZIndex = 42,
            Parent = Dialog,
        })
        Util.Corner(b, 10)
        return b
    end
    local cancelB = DialogButton("Cancelar", 0, false)
    local confirmB = DialogButton("Fechar", 0.5, true)
    local function ShowDialog(show)
        if show then
            Dim.Visible = true
            Dialog.Position = UDim2.fromScale(0.5, 0.58)
            Util.Tween(Dim, 0.25, { BackgroundTransparency = 0.45 })
            Util.Spring(Dialog, { Position = UDim2.fromScale(0.5, 0.5) }, 0.45)
        else
            Util.Tween(Dim, 0.2, { BackgroundTransparency = 1 })
            Util.Tween(Dialog, 0.2, { Position = UDim2.fromScale(0.5, 0.58) })
            task.delay(0.21, function() Dim.Visible = false end)
        end
    end
    closeBtn.MouseButton1Click:Connect(function() ShowDialog(true) end)
    cancelB.MouseButton1Click:Connect(function() ShowDialog(false) end)
    confirmB.MouseButton1Click:Connect(function()
        ShowDialog(false)
        Util.Tween(Main, 0.3, { GroupTransparency = 1 })
        Util.Tween(scale, 0.3, { Scale = Window.BaseScale * 0.9 })
        task.wait(0.32)
        if getgenv and getgenv().UltimateHubUnload then
            getgenv().UltimateHubUnload()
        end
    end)

    local Pill = Util.Create("TextButton", {
        BackgroundColor3 = Color3.fromRGB(8, 8, 9),
        Size = UDim2.fromOffset(250, 62),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -80),
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        Parent = gui,
    })
    Util.Round(Pill)
    Util.Stroke(Pill, Theme.Stroke, 1, 0.4)
    local pIc = Icons.New(Pill, "star", 26, Theme.Text, Color3.fromRGB(8, 8, 9))
    pIc.Position = UDim2.fromOffset(22, 18)
    Label(Pill, { Text = title, Font = Theme.FontBold, TextSize = 17, Position = UDim2.fromOffset(62, 11), Size = UDim2.new(1, -74, 0, 22) })
    Label(Pill, { Text = mobile and "Toque para mostrar" or ("Toque ou aperte " .. KeyName(Library.ToggleKey)), Name = "Hint", Font = Theme.FontRegular, TextSize = 13, Color = Theme.SubText, Position = UDim2.fromOffset(62, 33), Size = UDim2.new(1, -74, 0, 18) })
    MakeDraggable(Pill, Pill)
    local pillMoved = false
    local pillDown
    Pill.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            pillDown = i.Position
            pillMoved = false
        end
    end)
    Pill.InputEnded:Connect(function(i)
        if pillDown and (i.Position - pillDown).Magnitude > 8 then pillMoved = true end
    end)

    function Window:SetVisible(v)
        Library.Visible = v
        if v then
            Root.Visible = true
            Util.Tween(Pill, 0.35, { Position = UDim2.new(Pill.Position.X.Scale, Pill.Position.X.Offset, 0, -80) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            task.delay(0.35, function() if Library.Visible then Pill.Visible = false end end)
            scale.Scale = Window.BaseScale * 0.92
            Util.Tween(Main, 0.35, { GroupTransparency = 0 })
            Util.Spring(scale, { Scale = Window.BaseScale }, 0.5)
        else
            Util.Tween(Main, 0.25, { GroupTransparency = 1 })
            Util.Tween(scale, 0.25, { Scale = Window.BaseScale * 0.92 })
            task.delay(0.26, function() if not Library.Visible then Root.Visible = false end end)
            Pill.Visible = true
            Pill.Position = UDim2.new(Pill.Position.X.Scale, Pill.Position.X.Offset, 0, -80)
            Util.Spring(Pill, { Position = UDim2.new(Pill.Position.X.Scale, Pill.Position.X.Offset, 0, 18) }, 0.55)
        end
    end

    function Window:Toggle()
        Window:SetVisible(not Library.Visible)
    end

    minBtn.MouseButton1Click:Connect(function() Window:SetVisible(false) end)
    Pill.MouseButton1Click:Connect(function()
        if not pillMoved then Window:SetVisible(true) end
    end)

    Track(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Library.ToggleKey then
            Window:Toggle()
        end
    end))

    function Window:UpdatePillHint()
        local hint = Pill:FindFirstChild("Hint")
        if hint then
            hint.Text = mobile and "Toque para mostrar" or ("Toque ou aperte " .. KeyName(Library.ToggleKey))
        end
    end

    scale.Scale = Window.BaseScale * 0.88
    task.defer(function()
        Util.Tween(Main, 0.5, { GroupTransparency = 0 })
        Util.Spring(scale, { Scale = Window.BaseScale }, 0.6)
    end)

    function Window:CreateTab(name, iconName)
        local Tab = { Name = name, Items = {}, Order = 0 }

        local textW = TextWidth(name, 14, Theme.Font)
        local btn = Util.Create("TextButton", {
            Name = name,
            BackgroundColor3 = Theme.TabIdle,
            Size = UDim2.fromOffset(textW + 54, 36),
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = #Library.Tabs + 1,
            Parent = TabBar,
        })
        Util.Round(btn)
        local bStroke = Util.Stroke(btn, Theme.Stroke, 1, 0.55)
        local ic = Icons.New(btn, iconName or "home", 14, Theme.Muted, Theme.TabIdle)
        ic.Position = UDim2.fromOffset(16, 11)
        local tl = Label(btn, { Text = name, TextSize = 14, Color = Theme.SubText, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -38, 1, 0) })

        local holder = Util.Create("CanvasGroup", {
            Name = name .. "_Page",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            GroupTransparency = 1,
            Visible = false,
            Parent = Content,
        })
        local page = Util.Create("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            ScrollBarImageTransparency = 0.4,
            BorderSizePixel = 0,
            Parent = holder,
        })
        BindAccent(page, "ScrollBarImageColor3")
        Util.Padding(page, 6, 20, 40, 20)
        Util.List(page, 8)
        Tab.Page = page
        Tab.Holder = holder
        Tab.Button = btn

        function Tab:Activate()
            if Library.CurrentTab == Tab then return end
            local old = Library.CurrentTab
            Library.CurrentTab = Tab
            if old then
                Util.Tween(old.Button, 0.25, { BackgroundColor3 = Theme.TabIdle })
                Util.Tween(old.Stroke, 0.25, { Transparency = 0.55 })
                Util.Tween(old.TextLabel, 0.25, { TextColor3 = Theme.SubText })
                Icons.Recolor(old.Icon, Theme.Muted, 0.25)
                local oh = old.Holder
                Util.Tween(oh, 0.18, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -8) })
                task.delay(0.19, function()
                    if Library.CurrentTab ~= old then oh.Visible = false end
                end)
            end
            Util.Tween(btn, 0.25, { BackgroundColor3 = Theme.TabActive })
            Util.Tween(bStroke, 0.25, { Transparency = 0.1 })
            Util.Tween(tl, 0.25, { TextColor3 = Theme.Text })
            Icons.Recolor(ic, Theme.Text, 0.25)
            holder.Visible = true
            holder.Position = UDim2.fromOffset(0, 16)
            holder.GroupTransparency = 1
            Util.Tween(holder, 0.38, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
            if SearchBox.Text ~= "" then SearchBox.Text = "" end
        end
        Tab.Stroke = bStroke
        Tab.TextLabel = tl
        Tab.Icon = ic

        btn.MouseButton1Click:Connect(function()
            Tab:Activate()
            Util.Tween(btn, 0.08, { Size = UDim2.fromOffset(textW + 50, 34) })
            task.delay(0.08, function() Util.Spring(btn, { Size = UDim2.fromOffset(textW + 54, 36) }, 0.3) end)
        end)
        btn.MouseEnter:Connect(function()
            if Library.CurrentTab ~= Tab then Util.Tween(tl, 0.15, { TextColor3 = Theme.Text }) end
        end)
        btn.MouseLeave:Connect(function()
            if Library.CurrentTab ~= Tab then Util.Tween(tl, 0.2, { TextColor3 = Theme.SubText }) end
        end)

        local function NextOrder()
            Tab.Order = Tab.Order + 1
            return Tab.Order
        end

        local function Register(frame, nameText, isHeader)
            table.insert(Tab.Items, { Frame = frame, Name = nameText or "", IsHeader = isHeader })
        end

        local Builders = {}

        function Builders.Toggle(parent, o)
            o = o or {}
            local state = o.Default == true
            local card = Card(parent, 46, NextOrder())
            Register(card, o.Name)
            Label(card, { Text = o.Name or "Toggle", TextSize = 14, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -80, 1, 0), Truncate = true })
            local trackF = Util.Create("Frame", {
                BackgroundColor3 = Theme.Track,
                Size = UDim2.fromOffset(46, 26),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Parent = card,
            })
            Util.Round(trackF)
            local tStroke = Util.Stroke(trackF, Theme.Stroke, 1, 0.2)
            local knob = Util.Create("Frame", {
                BackgroundColor3 = Theme.KnobOff,
                Size = UDim2.fromOffset(20, 20),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                Parent = trackF,
            })
            Util.Round(knob)
            local kGlow = Util.Stroke(knob, Theme.Accent, 3, 1)

            local Toggle = { Value = state, Type = "Toggle" }
            local function Render(animate)
                local t = animate and 0.32 or 0
                if Toggle.Value then
                    Util.Tween(trackF, t, { BackgroundColor3 = Theme.AccentDeep })
                    Util.Tween(tStroke, t, { Color = Theme.AccentDark, Transparency = 0 })
                    Util.Tween(knob, t, { Position = UDim2.new(0, 23, 0.5, 0), BackgroundColor3 = Theme.Accent })
                    Util.Tween(kGlow, t, { Transparency = 0.75, Color = Theme.Accent })
                else
                    Util.Tween(trackF, t, { BackgroundColor3 = Theme.Track })
                    Util.Tween(tStroke, t, { Color = Theme.Stroke, Transparency = 0.2 })
                    Util.Tween(knob, t, { Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Theme.KnobOff })
                    Util.Tween(kGlow, t, { Transparency = 1 })
                end
                if animate then
                    Util.Tween(knob, 0.12, { Size = UDim2.fromOffset(25, 18) }, Enum.EasingStyle.Quad)
                    task.delay(0.12, function() Util.Spring(knob, { Size = UDim2.fromOffset(20, 20) }, 0.3) end)
                end
            end
            OnAccentChanged(function() Render(true) end)

            function Toggle:Set(v, silent)
                Toggle.Value = v and true or false
                SetFlag(o.Flag, Toggle.Value)
                Render(true)
                if not silent then SafeCallback(o.Callback, Toggle.Value) end
            end

            local cl = Clicker(card)
            Hover(card, cl)
            cl.MouseButton1Click:Connect(function()
                Toggle:Set(not Toggle.Value)
            end)
            Render(false)
            SetFlag(o.Flag, state)
            if o.Flag then Library.Elements[o.Flag] = Toggle end
            if state and o.CallOnStart ~= false and o.Callback then SafeCallback(o.Callback, true) end
            return Toggle
        end

        function Builders.Slider(parent, o)
            o = o or {}
            local min, max = o.Min or 0, o.Max or 100
            local inc = o.Increment or 1
            local suffix = o.Suffix or ""
            local value = Util.Clamp(o.Default or min, min, max)
            local card = Card(parent, 66, NextOrder())
            Register(card, o.Name)
            Label(card, { Text = o.Name or "Slider", TextSize = 14, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(0.42, -16, 0, 18), Truncate = true })
            local valueL = Label(card, { Text = "", TextSize = 13, Font = Theme.FontRegular, Color = Theme.SubText, Position = UDim2.fromOffset(16, 34), Size = UDim2.new(0.42, -16, 0, 16) })

            local trackF = Util.Create("Frame", {
                BackgroundColor3 = Theme.Track,
                Size = UDim2.new(0.55, -16, 0, 22),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -16, 0.5, 0),
                Parent = card,
            })
            Util.Round(trackF)
            local fill = Util.Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Size = UDim2.new(0, 0, 1, 0),
                Parent = trackF,
            })
            Util.Round(fill)
            local grad = Util.Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.AccentDeep),
                    ColorSequenceKeypoint.new(1, Theme.Accent),
                }),
                Parent = fill,
            })
            table.insert(GradientBindings, grad)
            local knob = Util.Create("Frame", {
                BackgroundColor3 = Theme.Knob,
                Size = UDim2.fromOffset(36, 22),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 18, 0.5, 0),
                ZIndex = 3,
                Parent = trackF,
            })
            Util.Round(knob)
            local kStroke = Util.Stroke(knob, Color3.fromRGB(255, 255, 255), 4, 0.88)

            local Slider = { Value = value, Type = "Slider" }
            local function Fmt(v)
                local s
                if inc < 1 then
                    local decimals = math.max(0, math.ceil(-math.log10(inc)))
                    s = string.format("%." .. decimals .. "f", v)
                else
                    s = tostring(math.floor(v + 0.5))
                end
                return s .. suffix
            end
            local function Render(t)
                local pct = (Slider.Value - min) / math.max(max - min, 1e-6)
                Util.Tween(knob, t or 0.14, { Position = UDim2.new(pct, 18 - pct * 36, 0.5, 0) }, Enum.EasingStyle.Quad)
                Util.Tween(fill, t or 0.14, { Size = UDim2.new(pct, 36 - pct * 36, 1, 0) }, Enum.EasingStyle.Quad)
                valueL.Text = Fmt(Slider.Value)
            end

            function Slider:Set(v, silent)
                v = Util.Clamp(Util.RoundTo(v, inc), min, max)
                local changed = v ~= Slider.Value
                Slider.Value = v
                SetFlag(o.Flag, v)
                Render()
                if changed and not silent then SafeCallback(o.Callback, v) end
            end

            local dragging = false
            local function FromInput(x)
                local abs = trackF.AbsolutePosition.X + 18
                local width = trackF.AbsoluteSize.X - 36
                local pct = Util.Clamp((x - abs) / math.max(width, 1), 0, 1)
                Slider:Set(min + (max - min) * pct)
            end
            local hit = Util.Create("TextButton", {
                BackgroundTransparency = 1,
                Text = "",
                Size = UDim2.new(1, 0, 1, 16),
                Position = UDim2.fromOffset(0, -8),
                ZIndex = 5,
                Parent = trackF,
            })
            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    Util.Tween(knob, 0.2, { Size = UDim2.fromOffset(42, 24) }, Enum.EasingStyle.Back)
                    Util.Tween(kStroke, 0.2, { Transparency = 0.7, Color = Theme.Accent })
                    FromInput(input.Position.X)
                end
            end)
            Track(UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    FromInput(input.Position.X)
                end
            end))
            Track(UserInputService.InputEnded:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                    dragging = false
                    Util.Spring(knob, { Size = UDim2.fromOffset(36, 22) }, 0.35)
                    Util.Tween(kStroke, 0.3, { Transparency = 0.88, Color = Color3.fromRGB(255, 255, 255) })
                end
            end))
            card.MouseEnter:Connect(function() Util.Tween(card, 0.18, { BackgroundColor3 = Theme.ElementHover }) end)
            card.MouseLeave:Connect(function() Util.Tween(card, 0.25, { BackgroundColor3 = Theme.Element }) end)

            Render(0)
            SetFlag(o.Flag, value)
            if o.Flag then Library.Elements[o.Flag] = Slider end
            return Slider
        end

        function Builders.Button(parent, o)
            o = o or {}
            local card = Card(parent, 46, NextOrder())
            Register(card, o.Name)
            Label(card, { Text = o.Name or "Botao", TextSize = 14, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -60, 1, 0), Truncate = true })
            local arrow = Icons.New(card, o.Icon or "chevron", 12, Theme.Muted, Theme.Element)
            arrow.AnchorPoint = Vector2.new(1, 0.5)
            arrow.Position = UDim2.new(1, -18, 0.5, 0)
            if not o.Icon then arrow.Rotation = -90 end
            local cl = Clicker(card)
            Hover(card, cl)
            cl.MouseButton1Down:Connect(function(x, y)
                Ripple(card, x, y)
                Util.Tween(card, 0.1, { BackgroundColor3 = Theme.ElementPress })
            end)
            cl.MouseButton1Up:Connect(function()
                Util.Tween(card, 0.25, { BackgroundColor3 = Theme.ElementHover })
            end)
            cl.MouseButton1Click:Connect(function()
                Util.Tween(arrow, 0.12, { Position = UDim2.new(1, -12, 0.5, 0) })
                task.delay(0.12, function() Util.Spring(arrow, { Position = UDim2.new(1, -18, 0.5, 0) }, 0.3) end)
                SafeCallback(o.Callback)
            end)
            return { Frame = card }
        end

        function Builders.Dropdown(parent, o)
            o = o or {}
            local options = o.Options or {}
            local current = o.Default or options[1]
            local open = false
            local card = Card(parent, 46, NextOrder())
            Register(card, o.Name)
            Label(card, { Text = o.Name or "Dropdown", TextSize = 14, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.5, -16, 0, 46), Truncate = true })
            local valueL = Label(card, { Text = tostring(current or "-"), TextSize = 13, Color = Theme.Accent, XAlign = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 0), Size = UDim2.new(0.5, -40, 0, 46), Truncate = true })
            BindAccent(valueL, "TextColor3")
            local chev = Icons.New(card, "chevron", 12, Theme.SubText, Theme.Element)
            chev.AnchorPoint = Vector2.new(0.5, 0.5)
            chev.Position = UDim2.new(1, -22, 0, 23)

            local list = Util.Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -16, 0, 0),
                Position = UDim2.fromOffset(8, 48),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = card,
            })
            Util.List(list, 4)

            local Dropdown = { Value = current, Type = "Dropdown", Options = options }
            local optButtons = {}

            local function Height()
                return 46 + (#Dropdown.Options * 34) + 8
            end

            local function RenderOptions()
                for opt, b in pairs(optButtons) do
                    local sel = opt == Dropdown.Value
                    Util.Tween(b, 0.2, { BackgroundTransparency = sel and 0 or 1, TextColor3 = sel and Theme.Accent or Theme.SubText })
                end
            end
            OnAccentChanged(RenderOptions)

            local function Build()
                for _, b in pairs(optButtons) do b:Destroy() end
                optButtons = {}
                for i, opt in ipairs(Dropdown.Options) do
                    local b = Util.Create("TextButton", {
                        BackgroundColor3 = Theme.ElementPress,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 30),
                        Text = "   " .. tostring(opt),
                        Font = Theme.Font,
                        TextSize = 13,
                        TextColor3 = Theme.SubText,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        LayoutOrder = i,
                        Parent = list,
                    })
                    Util.Corner(b, 8)
                    b.MouseButton1Click:Connect(function()
                        Dropdown:Set(opt)
                        Dropdown:Close()
                    end)
                    optButtons[opt] = b
                end
                RenderOptions()
            end

            function Dropdown:Open()
                open = true
                Util.Tween(card, 0.35, { Size = UDim2.new(1, 0, 0, Height()) })
                Util.Tween(chev, 0.35, { Rotation = 180 })
            end
            function Dropdown:Close()
                open = false
                Util.Tween(card, 0.3, { Size = UDim2.new(1, 0, 0, 46) })
                Util.Tween(chev, 0.3, { Rotation = 0 })
            end
            function Dropdown:Set(v, silent)
                Dropdown.Value = v
                valueL.Text = tostring(v)
                SetFlag(o.Flag, v)
                RenderOptions()
                if not silent then SafeCallback(o.Callback, v) end
            end
            function Dropdown:Refresh(newOptions, keep)
                Dropdown.Options = newOptions or {}
                Build()
                if not keep then
                    Dropdown:Set(Dropdown.Options[1], true)
                end
                if open then Util.Tween(card, 0.3, { Size = UDim2.new(1, 0, 0, Height()) }) end
            end

            local header = Util.Create("TextButton", {
                BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 46), ZIndex = 5, Parent = card,
            })
            Hover(card, header)
            header.MouseButton1Click:Connect(function()
                if open then Dropdown:Close() else Dropdown:Open() end
            end)
            Build()
            SetFlag(o.Flag, current)
            if o.Flag then Library.Elements[o.Flag] = Dropdown end
            return Dropdown
        end

        function Builders.Keybind(parent, o)
            o = o or {}
            local key = o.Default
            local card = Card(parent, 46, NextOrder())
            Register(card, o.Name)
            Label(card, { Text = o.Name or "Tecla", TextSize = 14, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -120, 1, 0), Truncate = true })
            local pill = Util.Create("Frame", {
                BackgroundColor3 = Theme.Track,
                Size = UDim2.fromOffset(70, 28),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Parent = card,
            })
            Util.Corner(pill, 8)
            local pStroke = Util.Stroke(pill, Theme.Stroke, 1, 0)
            local kl = Label(pill, { Text = KeyName(key), TextSize = 13, Font = Theme.FontBold, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
            local Keybind = { Value = key, Type = "Keybind" }
            local listening = false
            local function Resize()
                local w = TextWidth(kl.Text, 13, Theme.FontBold) + 26
                Util.Tween(pill, 0.25, { Size = UDim2.fromOffset(math.max(w, 44), 28) })
            end
            function Keybind:Set(k, silent)
                Keybind.Value = k
                kl.Text = KeyName(k)
                Resize()
                SetFlag(o.Flag, k)
                if not silent then SafeCallback(o.Changed, k) end
            end
            local cl = Clicker(card)
            Hover(card, cl)
            cl.MouseButton1Click:Connect(function()
                listening = true
                kl.Text = "..."
                Resize()
                Util.Tween(pStroke, 0.2, { Color = Theme.Accent })
            end)
            Track(UserInputService.InputBegan:Connect(function(input, gp)
                if listening then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        Util.Tween(pStroke, 0.2, { Color = Theme.Stroke })
                        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                            Keybind:Set(nil)
                        else
                            Keybind:Set(input.KeyCode)
                        end
                    end
                    return
                end
                if gp then return end
                if Keybind.Value and input.KeyCode == Keybind.Value then
                    SafeCallback(o.Callback, Keybind.Value)
                end
            end))
            Resize()
            SetFlag(o.Flag, key)
            if o.Flag then Library.Elements[o.Flag] = Keybind end
            return Keybind
        end

        function Builders.Input(parent, o)
            o = o or {}
            local card = Card(parent, 46, NextOrder())
            Register(card, o.Name)
            Label(card, { Text = o.Name or "Texto", TextSize = 14, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.45, -16, 1, 0), Truncate = true })
            local boxF = Util.Create("Frame", {
                BackgroundColor3 = Theme.Track,
                Size = UDim2.new(0.5, -12, 0, 30),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Parent = card,
            })
            Util.Corner(boxF, 8)
            local bStroke2 = Util.Stroke(boxF, Theme.Stroke, 1, 0)
            local box = Util.Create("TextBox", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.fromOffset(8, 0),
                Font = Theme.Font,
                TextSize = 13,
                Text = o.Default or "",
                PlaceholderText = o.Placeholder or "",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Text,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = boxF,
            })
            local Input = { Value = box.Text, Type = "Input" }
            function Input:Set(v, silent)
                box.Text = tostring(v or "")
                Input.Value = box.Text
                SetFlag(o.Flag, Input.Value)
                if not silent then SafeCallback(o.Callback, Input.Value) end
            end
            box.Focused:Connect(function() Util.Tween(bStroke2, 0.2, { Color = Theme.Accent }) end)
            box.FocusLost:Connect(function()
                Util.Tween(bStroke2, 0.2, { Color = Theme.Stroke })
                Input:Set(box.Text)
            end)
            SetFlag(o.Flag, Input.Value)
            if o.Flag then Library.Elements[o.Flag] = Input end
            return Input
        end

        function Builders.Paragraph(parent, o)
            o = o or {}
            local card = Card(parent, 0, NextOrder())
            card.AutomaticSize = Enum.AutomaticSize.Y
            Register(card, (o.Title or "") .. " " .. (o.Content or ""))
            Util.Padding(card, 14, 16, 14, 16)
            Util.List(card, 4)
            Label(card, { Text = o.Title or "", Font = Theme.FontBold, TextSize = 14, Size = UDim2.new(1, 0, 0, 18) })
            local c = Label(card, { Text = o.Content or "", Font = Theme.FontRegular, TextSize = 13, Color = Theme.SubText, Size = UDim2.new(1, 0, 0, 0), Wrapped = true, YAlign = Enum.TextYAlignment.Top })
            c.AutomaticSize = Enum.AutomaticSize.Y
            c.LayoutOrder = 2
            local P = {}
            function P:Set(t) c.Text = t end
            return P
        end

        function Builders.Label(parent, text)
            local l = Label(parent, { Text = text, TextSize = 13, Font = Theme.FontRegular, Color = Theme.SubText, Size = UDim2.new(1, 0, 0, 20), Wrapped = true })
            l.LayoutOrder = NextOrder()
            Register(l, text)
            local L = {}
            function L:Set(t) l.Text = t end
            return L
        end

        local function GreenCard(parent, height, order)
            local f = Util.Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Size = UDim2.new(1, 0, 0, height),
                LayoutOrder = order or 0,
                Parent = parent,
            })
            Util.Corner(f, 14)
            local st = Util.Stroke(f, Theme.Accent, 1, 0.35)
            BindAccent(st, "Color")
            local g = Util.Create("UIGradient", {
                Rotation = 0,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.AccentDeep),
                    ColorSequenceKeypoint.new(1, Theme.Accent),
                }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.25) }),
                Parent = f,
            })
            table.insert(GradientBindings, g)

            local shine = Util.Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 0.94,
                Size = UDim2.new(0, 60, 2, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(-0.3, 0, 0.5, 0),
                Rotation = 20,
                BorderSizePixel = 0,
                Parent = f,
            })
            f.ClipsDescendants = true
            task.spawn(function()
                while shine.Parent do
                    shine.Position = UDim2.new(-0.3, 0, 0.5, 0)
                    Util.Tween(shine, 2.6, { Position = UDim2.new(1.3, 0, 0.5, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                    task.wait(2.6 + math.random() * 4)
                end
            end)
            return f
        end

        function Builders.Stats(parent, left, right)
            local row = Util.Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 50),
                LayoutOrder = NextOrder(),
                Parent = parent,
            })
            Register(row, (left.Name or "") .. " " .. (right.Name or ""))
            local out = {}
            for i, d in ipairs({ left, right }) do
                local c = GreenCard(row, 50, i)
                c.Size = UDim2.new(0.5, -4, 1, 0)
                c.Position = UDim2.new(i == 1 and 0 or 0.5, i == 1 and 0 or 4, 0, 0)
                Label(c, { Text = d.Name or "", TextSize = 14, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 2 })
                local v = Label(c, { Text = tostring(d.Value or ""), Font = Theme.FontBold, TextSize = 15, XAlign = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 2 })
                out[i] = v
            end
            local S = {}
            function S:SetLeft(t) out[1].Text = tostring(t) end
            function S:SetRight(t) out[2].Text = tostring(t) end
            return S
        end

        function Builders.BigStat(parent, o)
            o = o or {}
            local c = GreenCard(parent, 108, NextOrder())
            Register(c, o.Name)
            Label(c, { Text = o.Name or "", Font = Theme.FontBold, TextSize = 16, Position = UDim2.fromOffset(22, 22), Size = UDim2.new(1, -44, 0, 20), ZIndex = 2 })
            local v = Label(c, { Text = tostring(o.Value or "0"), Font = Theme.Font, TextSize = 22, Position = UDim2.fromOffset(22, 60), Size = UDim2.new(0.6, 0, 0, 26), ZIndex = 2 })
            local d = Label(c, { Text = o.Delta or "", Font = Theme.Font, TextSize = 13, XAlign = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 64), Size = UDim2.new(0.4, 0, 0, 20), ZIndex = 2 })
            local B = {}
            local shown = tonumber(o.Value) or 0
            function B:Set(val, delta)
                local target = tonumber(val)
                if target then
                    local from = shown
                    shown = target
                    task.spawn(function()
                        for i = 1, 12 do
                            v.Text = Util.FormatNumber(Util.Lerp(from, target, i / 12))
                            task.wait(0.02)
                        end
                        v.Text = Util.FormatNumber(target)
                    end)
                else
                    v.Text = tostring(val)
                end
                if delta then d.Text = delta end
            end
            return B
        end

        function Tab:CreateSection(sectionName, sectionIcon)
            local header = Util.Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30),
                LayoutOrder = NextOrder(),
                Parent = page,
            })
            Register(header, sectionName, true)
            local hic = Icons.New(header, sectionIcon or "home", 13, Theme.Muted, Theme.Background)
            hic.Position = UDim2.fromOffset(4, 10)
            Label(header, { Text = sectionName, TextSize = 14, Color = Theme.SubText, Font = Theme.Font, Position = UDim2.fromOffset(26, 4), Size = UDim2.new(1, -26, 1, -4) })

            local Section = {}
            function Section:Toggle(o) return Builders.Toggle(page, o) end
            function Section:Slider(o) return Builders.Slider(page, o) end
            function Section:Button(o) return Builders.Button(page, o) end
            function Section:Dropdown(o) return Builders.Dropdown(page, o) end
            function Section:Keybind(o) return Builders.Keybind(page, o) end
            function Section:Input(o) return Builders.Input(page, o) end
            function Section:Paragraph(o) return Builders.Paragraph(page, o) end
            function Section:Label(t) return Builders.Label(page, t) end
            function Section:Stats(l, r) return Builders.Stats(page, l, r) end
            function Section:BigStat(o) return Builders.BigStat(page, o) end

            function Section:Grid()
                local grid = Util.Create("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    LayoutOrder = NextOrder(),
                    Parent = page,
                })
                Util.Create("UIGridLayout", {
                    CellSize = UDim2.new(0.5, -4, 0, 46),
                    CellPadding = UDim2.fromOffset(8, 8),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = grid,
                })
                local G = {}
                function G:Toggle(o) return Builders.Toggle(grid, o) end
                function G:Button(o) return Builders.Button(grid, o) end
                return G
            end
            return Section
        end

        table.insert(Library.Tabs, Tab)
        if #Library.Tabs == 1 then
            task.defer(function() Tab:Activate() end)
        end
        return Tab
    end

    setBtn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Library.Tabs) do
            if t.Name == "Config" then t:Activate() end
        end
        Util.Tween(setIcon, 0.5, { Rotation = setIcon.Rotation + 90 }, Enum.EasingStyle.Back)
    end)

    Library.Window = Window
    return Window
end

local function CanFS()
    return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

function Library:Serialize()
    local out = {}
    for flag, v in pairs(Library.Flags) do
        local t = typeof(v)
        if t == "EnumItem" then
            out[flag] = { __enum = tostring(v.EnumType), name = v.Name }
        elseif t == "Color3" then
            out[flag] = { __color = Util.ColorToTable(v) }
        elseif t == "Vector3" then
            out[flag] = { __v3 = { v.X, v.Y, v.Z } }
        elseif t == "boolean" or t == "number" or t == "string" then
            out[flag] = v
        end
    end
    return HttpService:JSONEncode(out)
end

function Library:SaveConfig()
    if not CanFS() then
        Library:Notify({ Title = "Config", Content = "Seu executor nao suporta salvar arquivos.", Type = "warn" })
        return false
    end
    pcall(function()
        if makefolder and isfolder and not isfolder(Library.ConfigFolder) then makefolder(Library.ConfigFolder) end
    end)
    local ok = pcall(function()
        writefile(Library.ConfigFolder .. "/" .. Library.ConfigFile, Library:Serialize())
    end)
    if ok then
        Library:Notify({ Title = "Config salva", Content = "Tudo guardado com sucesso.", Type = "success" })
    end
    return ok
end

function Library:LoadConfig(silentNotify)
    if not CanFS() then return false end
    local path = Library.ConfigFolder .. "/" .. Library.ConfigFile
    local ok, data = pcall(function()
        if not isfile(path) then return nil end
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then return false end
    for flag, v in pairs(data) do
        local el = Library.Elements[flag]
        if el and el.Set then
            local value = v
            if type(v) == "table" then
                if v.__enum and v.name then
                    local okE, e = pcall(function() return Enum.KeyCode[v.name] end)
                    value = okE and e or nil
                elseif v.__color then
                    value = Util.TableToColor(v.__color)
                elseif v.__v3 then
                    value = Vector3.new(v.__v3[1], v.__v3[2], v.__v3[3])
                end
            end
            pcall(function() el:Set(value) end)
        else
            if type(v) == "table" and v.__v3 then
                Library.Flags[flag] = Vector3.new(v.__v3[1], v.__v3[2], v.__v3[3])
            end
        end
    end
    if not silentNotify then
        Library:Notify({ Title = "Config carregada", Content = "Suas opcoes foram aplicadas.", Type = "success" })
    end
    return true
end

local Engine = {
    Ball = nil,
    LastScan = 0,
    ScanInterval = 1.5,
    BallName = "",
    Goals = {},
    MyGoal = nil,
    GoalForward = nil,
    GoalWidth = 24,
    GoalHeight = 9,
    GoalMode = "Auto",
    Stats = { Saves = 0, Shots = 0, Conceded = 0, Touches = 0, TopSpeed = 0 },
    BallSpeed = 0,
    BallDistance = 0,
    Shot = nil,
}

local KNOWN_BALL_NAMES = {
    ["ball"] = true, ["football"] = true, ["bola"] = true, ["soccerball"] = true,
    ["soccer ball"] = true, ["soccer"] = true, ["tps"] = true, ["matchball"] = true,
    ["gameball"] = true, ["futebol"] = true, ["fball"] = true,
}

local GOAL_WORDS = { "goal", "gol", "net", "rede", "trave", "baliza", "post" }

local function IsInCharacter(inst)
    for _, plr in ipairs(Players:GetPlayers()) do
        local c = plr.Character
        if c and inst:IsDescendantOf(c) then return true end
    end
    return false
end

local function ScoreBall(p)
    if not p:IsA("BasePart") then return -1 end
    local name = string.lower(p.Name)
    local score = 0
    if Engine.BallName ~= "" and name == string.lower(Engine.BallName) then
        score = score + 200
    end
    if KNOWN_BALL_NAMES[name] then score = score + 80 end
    if string.find(name, "ball", 1, true) or string.find(name, "bola", 1, true) then score = score + 30 end
    if p:IsA("Part") and p.Shape == Enum.PartType.Ball then score = score + 35 end
    local s = p.Size
    local maxS, minS = math.max(s.X, s.Y, s.Z), math.min(s.X, s.Y, s.Z)
    if maxS <= 6 and minS >= 0.8 and (maxS - minS) < 0.6 then score = score + 25 end
    if maxS > 12 then score = score - 100 end
    if not p.Anchored then score = score + 15 end
    if p.Transparency >= 1 then score = score - 20 end
    if IsInCharacter(p) then score = score - 60 end
    return score
end

function Engine.ScanBall()
    local best, bestScore = nil, 59
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = string.lower(d.Name)
            local quick = KNOWN_BALL_NAMES[n] or string.find(n, "ball", 1, true) or string.find(n, "bola", 1, true)
                or (Engine.BallName ~= "" and n == string.lower(Engine.BallName))
                or (d:IsA("Part") and d.Shape == Enum.PartType.Ball)
            if quick then
                local sc = ScoreBall(d)
                if sc > bestScore then
                    best, bestScore = d, sc
                end
            end
        end
    end
    Engine.Ball = best
    return best
end

function Engine.GetBall()
    local b = Engine.Ball
    if b and b.Parent and b:IsDescendantOf(Workspace) then
        return b
    end
    if tick() - Engine.LastScan > Engine.ScanInterval then
        Engine.LastScan = tick()
        return Engine.ScanBall()
    end
    return nil
end

Track(Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("BasePart") and ScoreBall(d) >= 60 then
        task.defer(function()
            if not Engine.Ball or not Engine.Ball.Parent or ScoreBall(d) > ScoreBall(Engine.Ball) then
                Engine.Ball = d
            end
        end)
    end
end))

function Engine.BallVelocity(ball)
    ball = ball or Engine.Ball
    if not ball then return Vector3.new() end
    local ok, v = pcall(function() return ball.AssemblyLinearVelocity end)
    if ok and v then return v end
    return ball.Velocity
end

local function HasGoalWord(name)
    name = string.lower(name)
    for _, w in ipairs(GOAL_WORDS) do
        if string.find(name, w, 1, true) then return true end
    end
    return false
end

function Engine.ScanGoals()
    local found = {}
    local seen = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if (d:IsA("Model") or d:IsA("BasePart")) and HasGoalWord(d.Name) and not IsInCharacter(d) then
            local root = d

            while root.Parent and root.Parent ~= Workspace and HasGoalWord(root.Parent.Name) do
                root = root.Parent
            end
            if not seen[root] then
                seen[root] = true
                local cf, size
                if root:IsA("Model") then
                    local ok, a, b = pcall(function() return root:GetBoundingBox() end)
                    if ok then cf, size = a, b end
                elseif root:IsA("BasePart") then
                    cf, size = root.CFrame, root.Size
                end
                if cf and size then
                    local width = math.max(size.X, size.Z)
                    if width >= 6 and width <= 90 and size.Y <= 40 then
                        table.insert(found, {
                            Center = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z),
                            Width = width,
                            Height = size.Y,
                            Model = root,
                        })
                    end
                end
            end
        end
    end

    local merged = {}
    for _, g in ipairs(found) do
        local joined = false
        for _, m in ipairs(merged) do
            if (Util.Flat(m.Center) - Util.Flat(g.Center)).Magnitude < 25 then
                m.Width = math.max(m.Width, g.Width)
                m.Height = math.max(m.Height, g.Height)
                joined = true
                break
            end
        end
        if not joined then table.insert(merged, g) end
    end

    if #merged > 2 then
        local bi, bj, bd = 1, 2, 0
        for i = 1, #merged do
            for j = i + 1, #merged do
                local dd = (Util.Flat(merged[i].Center) - Util.Flat(merged[j].Center)).Magnitude
                if dd > bd then bi, bj, bd = i, j, dd end
            end
        end
        merged = { merged[bi], merged[bj] }
    end
    Engine.Goals = merged
    return merged
end

function Engine.AutoAssignGoal()
    local root = Util.Root()
    if not root then return false end
    if #Engine.Goals == 0 then Engine.ScanGoals() end
    if #Engine.Goals == 0 then return false end
    local mine, other, best = nil, nil, math.huge
    for _, g in ipairs(Engine.Goals) do
        local d = (Util.Flat(g.Center) - Util.Flat(root.Position)).Magnitude
        if d < best then best, mine = d, g end
    end
    for _, g in ipairs(Engine.Goals) do
        if g ~= mine then other = g end
    end
    Engine.MyGoal = mine.Center
    Engine.GoalWidth = Util.Clamp(mine.Width, 8, 60)
    Engine.GoalHeight = Util.Clamp(mine.Height, 5, 25)
    if other then
        Engine.GoalForward = Util.SafeUnit(Util.Flat(other.Center - mine.Center))
    else
        local toCenter = Util.Flat(Vector3.new(0, 0, 0) - mine.Center)
        Engine.GoalForward = Util.SafeUnit(toCenter)
        if Engine.GoalForward.Magnitude < 0.5 then
            Engine.GoalForward = Util.SafeUnit(Util.Flat(root.CFrame.LookVector))
        end
    end
    return true
end

function Engine.SwapGoal()
    if #Engine.Goals < 2 or not Engine.MyGoal then return false end
    for _, g in ipairs(Engine.Goals) do
        if (g.Center - Engine.MyGoal).Magnitude > 5 then
            local old = Engine.MyGoal
            Engine.MyGoal = g.Center
            Engine.GoalWidth = Util.Clamp(g.Width, 8, 60)
            Engine.GoalHeight = Util.Clamp(g.Height, 5, 25)
            Engine.GoalForward = Util.SafeUnit(Util.Flat(old - g.Center))
            return true
        end
    end
    return false
end

function Engine.SetGoalHere()
    local root = Util.Root()
    local hum = Util.Humanoid()
    if not root then return false end
    local hip = (hum and hum.HipHeight or 2) + root.Size.Y / 2
    Engine.MyGoal = root.Position - Vector3.new(0, hip, 0)
    Engine.GoalForward = Util.SafeUnit(Util.Flat(root.CFrame.LookVector))
    Engine.GoalMode = "Manual"
    return true
end

function Engine.HasGoal()
    return Engine.MyGoal ~= nil and Engine.GoalForward ~= nil and Engine.GoalForward.Magnitude > 0.5
end

function Engine.Right()
    if not Engine.GoalForward then return Vector3.new(1, 0, 0) end
    return Util.SafeUnit(Engine.GoalForward:Cross(Vector3.new(0, 1, 0)))
end

function Engine.PredictPosition(pos, vel, t)
    local g = Workspace.Gravity
    local p = pos + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)

    local floor = Engine.MyGoal and Engine.MyGoal.Y or (pos.Y - 50)
    local radius = Engine.Ball and Engine.Ball.Size.Y / 2 or 1
    if p.Y < floor + radius then
        p = Vector3.new(p.X, floor + radius + (floor + radius - p.Y) * 0.35, p.Z)
    end
    return p
end

function Engine.Trajectory(steps, horizon)
    local ball = Engine.Ball
    if not ball then return {} end
    local pts = {}
    local v = Engine.BallVelocity(ball)
    for i = 1, steps do
        local t = (i / steps) * horizon
        pts[i] = Engine.PredictPosition(ball.Position, v, t)
    end
    return pts
end

function Engine.Intercept(depth, minSpeed, maxTime)
    local ball = Engine.Ball
    if not ball or not Engine.HasGoal() then return nil end
    local G, n = Engine.MyGoal, Engine.GoalForward
    local p = ball.Position
    local v = Engine.BallVelocity(ball)
    local d0 = (p - G):Dot(n) - (depth or 0)
    local vn = v:Dot(n)
    if vn > -(minSpeed or 8) then return nil end
    if d0 < -2 then return nil end
    local t = d0 / -vn
    if t < 0 or t > (maxTime or 3) then return nil end
    local hit = Engine.PredictPosition(p, v, t)
    local right = Engine.Right()
    local lateral = (hit - G):Dot(right)
    local height = hit.Y - G.Y
    local margin = 2.5
    return {
        Time = t,
        Point = hit,
        Lateral = lateral,
        Height = height,
        Speed = v.Magnitude,
        OnTarget = math.abs(lateral) <= Engine.GoalWidth / 2 + margin and height <= Engine.GoalHeight + margin,
        Velocity = v,
    }
end

function Engine.DistanceFromGoal(pos)
    if not Engine.HasGoal() then return math.huge end
    return (Util.Flat(pos) - Util.Flat(Engine.MyGoal)).Magnitude
end

function Engine.Update(dt)
    local ball = Engine.GetBall()
    local root = Util.Root()
    if ball then
        local v = Engine.BallVelocity(ball)
        Engine.BallSpeed = v.Magnitude
        if Engine.BallSpeed > Engine.Stats.TopSpeed and Engine.BallSpeed < 600 then
            Engine.Stats.TopSpeed = Engine.BallSpeed
        end
        if root then
            Engine.BallDistance = (ball.Position - root.Position).Magnitude
        end
    else
        Engine.BallSpeed = 0
        Engine.BallDistance = 0
    end
end

local GK = {
    AutoSave = false,
    AutoPosition = false,
    AutoDive = false,
    AutoReach = false,
    AutoClear = false,
    FaceBall = false,
    RushOut = false,
    LineLock = false,
    ShotAlert = true,
    Humanizer = true,

    MoveMode = "Legit (andar)",
    ReactionTime = 1.4,
    SaveRadius = 70,
    SaveDepth = 3,
    PositionDepth = 5,
    PositionFactor = 0.45,
    MaxAdvance = 14,
    RushDistance = 22,
    ReachRadius = 9,
    ClearRadius = 5,
    DiveHeight = 4.5,
    MinShotSpeed = 18,
    TweenSpeed = 60,
    HumanDelay = 0.08,
    SaveKey = nil,
    DiveKey = nil,
    ClearKey = nil,
    ClickOnSave = false,

    _lastReach = 0,
    _lastClear = 0,
    _shotId = 0,
    _savedShot = -1,
    _shotStart = 0,
    _tween = nil,
    _autoRotate = nil,
    _status = "Parado",
}

local function MoveTo(target, mode)
    local root, hum = Util.Root(), Util.Humanoid()
    if not root or not hum then return end
    mode = mode or GK.MoveMode
    target = Vector3.new(target.X, root.Position.Y, target.Z)
    if mode == "Teleporte" then
        local look = root.CFrame.LookVector
        root.CFrame = CFrame.new(target, target + Util.Flat(look) + Vector3.new(0, 0, 0.001))
    elseif mode == "Tween" then
        local dist = (target - root.Position).Magnitude
        if GK._tween then GK._tween:Cancel() end
        local tw = TweenService:Create(root, TweenInfo.new(math.max(dist / GK.TweenSpeed, 0.03), Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position),
        })
        GK._tween = tw
        tw:Play()
    else
        hum:MoveTo(target)
    end
end

local function StopMove()
    local root, hum = Util.Root(), Util.Humanoid()
    if hum and root then
        hum:MoveTo(root.Position)
    end
end

local function TouchBall(ball, radius)
    if not firetouchinterest or not ball then return false end
    local char = Util.Character()
    if not char then return false end
    local root = Util.Root()
    if not root or (ball.Position - root.Position).Magnitude > radius then return false end
    local parts = {}
    for _, n in ipairs({ "HumanoidRootPart", "LeftHand", "RightHand", "Left Arm", "Right Arm", "LeftFoot", "RightFoot", "Left Leg", "Right Leg", "Head" }) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then table.insert(parts, p) end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local h = tool:FindFirstChild("Handle")
            if h then table.insert(parts, h) end
        end
    end
    for _, p in ipairs(parts) do
        pcall(function()
            firetouchinterest(p, ball, 0)
            firetouchinterest(p, ball, 1)
        end)
    end
    Engine.Stats.Touches = Engine.Stats.Touches + 1
    return true
end
GK.TouchBall = TouchBall

local function Jump()
    local hum = Util.Humanoid()
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        hum.Jump = true
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end

function GK.IdealPosition(ball)
    local G, n, r = Engine.MyGoal, Engine.GoalForward, Engine.Right()
    local bp = ball.Position
    local lateralBall = (bp - G):Dot(r)
    local forwardBall = math.max((bp - G):Dot(n), 1)

    local angleLateral = (lateralBall / forwardBall) * GK.PositionDepth
    local lateral = Util.Lerp(lateralBall * GK.PositionFactor, angleLateral + lateralBall * 0.15, 0.5)
    local half = Engine.GoalWidth / 2 - 1.5
    lateral = Util.Clamp(lateral, -half, half)
    local depth = GK.PositionDepth

    if forwardBall > 60 then depth = depth + 2 end
    return G + n * depth + r * lateral
end

function GK.ClampLine(pos)
    if not GK.LineLock or not Engine.HasGoal() then return pos end
    local G, n, r = Engine.MyGoal, Engine.GoalForward, Engine.Right()
    local f = Util.Clamp((pos - G):Dot(n), 0.5, GK.MaxAdvance)
    local l = Util.Clamp((pos - G):Dot(r), -Engine.GoalWidth / 2 - 3, Engine.GoalWidth / 2 + 3)
    return Vector3.new(G.X, pos.Y, G.Z) + n * f + r * l
end

function GK.Step(dt)
    local ball = Engine.Ball
    local root, hum = Util.Root(), Util.Humanoid()
    if not ball or not root or not hum or hum.Health <= 0 then
        GK._status = ball and "Sem personagem" or "Procurando bola"
        return
    end
    if not Engine.HasGoal() then
        if Engine.GoalMode == "Auto" and (GK.AutoSave or GK.AutoPosition) then
            Engine.AutoAssignGoal()
        end
        if not Engine.HasGoal() then
            GK._status = "Defina seu gol"
            return
        end
    end

    local ballDist = (ball.Position - root.Position).Magnitude
    local info = Engine.Intercept(GK.SaveDepth, GK.MinShotSpeed, 3)

    if info and info.OnTarget and info.Speed >= GK.MinShotSpeed then
        if not Engine.Shot then
            GK._shotId = GK._shotId + 1
            Engine.Shot = { Id = GK._shotId, Start = tick(), Info = info, Saved = false }
            Engine.Stats.Shots = Engine.Stats.Shots + 1
            GK._shotStart = tick()
        else
            Engine.Shot.Info = info
        end
    elseif Engine.Shot then
        local v = Engine.BallVelocity(ball)
        local vn = v:Dot(Engine.GoalForward)
        local d0 = (ball.Position - Engine.MyGoal):Dot(Engine.GoalForward)
        local lateral = math.abs((ball.Position - Engine.MyGoal):Dot(Engine.Right()))
        if d0 < -0.5 and lateral < Engine.GoalWidth / 2 + 1 then
            Engine.Stats.Conceded = Engine.Stats.Conceded + 1
            Engine.Shot = nil
        elseif vn > 2 or ballDist < 4 or tick() - Engine.Shot.Start > 3.5 then
            if (vn > 2 or ballDist < 4) and not Engine.Shot.Saved then
                Engine.Stats.Saves = Engine.Stats.Saves + 1
                Engine.Shot.Saved = true
            end
            Engine.Shot = nil
        end
    end

    local saving = false
    if GK.AutoSave and info and info.OnTarget and info.Time <= GK.ReactionTime and ballDist <= GK.SaveRadius then
        local delayOk = true
        if GK.Humanizer and Engine.Shot then
            delayOk = (tick() - Engine.Shot.Start) >= GK.HumanDelay
        end
        if delayOk then
            saving = true
            local r = Engine.Right()
            local half = Engine.GoalWidth / 2 + 1
            local lat = Util.Clamp(info.Lateral, -half, half)
            local target = Engine.MyGoal + Engine.GoalForward * GK.SaveDepth + r * lat
            target = GK.ClampLine(target)
            MoveTo(target, GK.MoveMode)
            GK._status = string.format("Defendendo (%.2fs)", info.Time)

            if GK.AutoDive and info.Height >= GK.DiveHeight and info.Time < 0.55 then
                Jump()
            end
            if GK._savedShot ~= GK._shotId then
                GK._savedShot = GK._shotId
                if GK.SaveKey then Util.PressKey(GK.SaveKey, 0.08) end
                if GK.ClickOnSave then Util.Click(0) end
                if GK.DiveKey and math.abs(info.Lateral - (root.Position - Engine.MyGoal):Dot(r)) > 4 then
                    Util.PressKey(GK.DiveKey, 0.08)
                end
            end
        end
    end

    if not saving and GK.AutoPosition then
        local ballFromGoal = Engine.DistanceFromGoal(ball.Position)
        local target
        if GK.RushOut and ballFromGoal < GK.RushDistance and Engine.BallSpeed < 35 then
            target = ball.Position
            GK._status = "Saindo do gol"
        else
            target = GK.IdealPosition(ball)
            GK._status = "Posicionado"
        end
        target = GK.ClampLine(target)
        local flatDist = (Util.Flat(target) - Util.Flat(root.Position)).Magnitude
        if flatDist > 1.2 then
            MoveTo(target, GK.MoveMode == "Teleporte" and "Legit (andar)" or GK.MoveMode)
        end
    elseif not saving and not GK.AutoPosition then
        GK._status = GK.AutoSave and "Aguardando chute" or "Parado"
    end

    if GK.AutoReach and tick() - GK._lastReach > 0.06 then
        local should = ballDist <= GK.ReachRadius
        if should and (saving or Engine.Shot or ballDist <= GK.ReachRadius * 0.6) then
            GK._lastReach = tick()
            TouchBall(ball, GK.ReachRadius)
        end
    end

    if GK.AutoClear and ballDist <= GK.ClearRadius and tick() - GK._lastClear > 0.6 then
        GK._lastClear = tick()

        local look = root.Position + Engine.GoalForward * 10
        root.CFrame = CFrame.lookAt(root.Position, Vector3.new(look.X, root.Position.Y, look.Z))
        if GK.ClearKey then
            Util.PressKey(GK.ClearKey, 0.1)
        else
            Util.Click(0)
        end
    end

    if GK.FaceBall and not (GK.AutoClear and ballDist <= GK.ClearRadius) then
        local bp = ball.Position
        local flat = Vector3.new(bp.X, root.Position.Y, bp.Z)
        if (flat - root.Position).Magnitude > 0.5 then
            root.CFrame = CFrame.lookAt(root.Position, flat)
        end
    end
end

function GK.SetFaceBall(v)
    GK.FaceBall = v
    local hum = Util.Humanoid()
    if hum then
        if v then
            if GK._autoRotate == nil then GK._autoRotate = hum.AutoRotate end
            hum.AutoRotate = false
        else
            hum.AutoRotate = GK._autoRotate ~= false
            GK._autoRotate = nil
        end
    end
end

function GK.Stop()
    if GK._tween then GK._tween:Cancel() end
    StopMove()
end

OnUnload(function()
    GK.AutoSave, GK.AutoPosition = false, false
    GK.SetFaceBall(false)
    GK.Stop()
end)

local PlayerMods = {
    SpeedOn = false, Speed = 24,
    JumpOn = false, Jump = 60,
    InfJump = false,
    AutoSprint = false, SprintKey = Enum.KeyCode.LeftShift,
    AntiRagdoll = false,
    Noclip = false,
    AntiAFK = true,
    DefaultSpeed = 16,
    DefaultJump = 50,
    _sprintHeld = false,
}

local function CaptureDefaults()
    local hum = Util.Humanoid()
    if hum then
        if not PlayerMods.SpeedOn then PlayerMods.DefaultSpeed = hum.WalkSpeed end
        if not PlayerMods.JumpOn then
            PlayerMods.DefaultJump = hum.UseJumpPower and hum.JumpPower or 50
        end
    end
end

function PlayerMods.SetSpeed(on)
    PlayerMods.SpeedOn = on
    local hum = Util.Humanoid()
    if not on and hum then hum.WalkSpeed = PlayerMods.DefaultSpeed end
end

function PlayerMods.SetJump(on)
    PlayerMods.JumpOn = on
    local hum = Util.Humanoid()
    if not on and hum then
        hum.UseJumpPower = true
        hum.JumpPower = PlayerMods.DefaultJump
    end
end

function PlayerMods.SetSprint(on)
    PlayerMods.AutoSprint = on
    if not on and PlayerMods._sprintHeld then
        Util.HoldKey(PlayerMods.SprintKey, false)
        PlayerMods._sprintHeld = false
    end
end

function PlayerMods.SetAntiRagdoll(on)
    PlayerMods.AntiRagdoll = on
    local hum = Util.Humanoid()
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not on)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not on)
        end)
    end
end

function PlayerMods.Step()
    local hum = Util.Humanoid()
    if not hum then return end
    if PlayerMods.SpeedOn and hum.WalkSpeed ~= PlayerMods.Speed then
        hum.WalkSpeed = PlayerMods.Speed
    end
    if PlayerMods.JumpOn then
        hum.UseJumpPower = true
        if hum.JumpPower ~= PlayerMods.Jump then hum.JumpPower = PlayerMods.Jump end
    end
    if PlayerMods.AutoSprint then
        local moving = hum.MoveDirection.Magnitude > 0.1
        if moving and not PlayerMods._sprintHeld then
            Util.HoldKey(PlayerMods.SprintKey, true)
            PlayerMods._sprintHeld = true
        elseif not moving and PlayerMods._sprintHeld then
            Util.HoldKey(PlayerMods.SprintKey, false)
            PlayerMods._sprintHeld = false
        end
    end
    if PlayerMods.AntiRagdoll then
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.PlatformStanding then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            hum.PlatformStand = false
        end
    end
end

Track(UserInputService.JumpRequest:Connect(function()
    if PlayerMods.InfJump then
        local hum = Util.Humanoid()
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end
end))

Track(RunService.Stepped:Connect(function()
    if PlayerMods.Noclip then
        local c = Util.Character()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end
end))

Track(LocalPlayer.Idled:Connect(function()
    if PlayerMods.AntiAFK and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

Track(LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.3)
    CaptureDefaults()
    if PlayerMods.AntiRagdoll then PlayerMods.SetAntiRagdoll(true) end
    if GK.FaceBall then GK._autoRotate = nil; GK.SetFaceBall(true) end
end))
CaptureDefaults()

function PlayerMods.TeleportToBall()
    local ball, root = Engine.GetBall(), Util.Root()
    if not ball or not root then return false end
    local dir = Util.SafeUnit(Util.Flat(root.Position - ball.Position))
    if dir.Magnitude < 0.5 then dir = Vector3.new(0, 0, 1) end
    local pos = ball.Position + dir * 3 + Vector3.new(0, 2.5, 0)
    root.CFrame = CFrame.lookAt(pos, Vector3.new(ball.Position.X, pos.Y, ball.Position.Z))
    return true
end

function PlayerMods.TeleportToGoal()
    local root = Util.Root()
    if not root or not Engine.HasGoal() then return false end
    local pos = Engine.MyGoal + Engine.GoalForward * GK.PositionDepth + Vector3.new(0, 3.5, 0)
    root.CFrame = CFrame.lookAt(pos, pos + Engine.GoalForward)
    return true
end

OnUnload(function()
    PlayerMods.SetSpeed(false)
    PlayerMods.SetJump(false)
    PlayerMods.SetSprint(false)
    PlayerMods.SetAntiRagdoll(false)
    PlayerMods.Noclip = false
    PlayerMods.InfJump = false
end)

local Visuals = {
    BallESP = false,
    BallInfo = true,
    Trajectory = false,
    LandingMarker = false,
    PlayerESP = false,
    EnemiesOnly = false,
    PlayerNames = true,
    GoalOutline = false,
    BallCam = false,
    FOVOn = false,
    FOV = 80,
    Fullbright = false,
    NoFog = false,
    ShotHUD = true,
    ESPColor = Color3.fromRGB(40, 190, 110),
    _defaultFOV = Camera.FieldOfView,
    _lighting = nil,
    _fog = nil,
}

local VisualFolder = Instance.new("Folder")
VisualFolder.Name = "UH_Visuals_" .. math.random(100, 999)
VisualFolder.Parent = Workspace
OnUnload(function() VisualFolder:Destroy() end)

local function NewMarkerPart(size, color, shape, transparency)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Size = size
    p.Transparency = transparency or 0.2
    if shape then p.Shape = shape end
    p.Parent = VisualFolder
    return p
end

local ballHighlight, ballBillboard, ballInfoLabel
local function EnsureBallESP(ball)
    if not ballHighlight then
        ballHighlight = Instance.new("Highlight")
        ballHighlight.FillTransparency = 0.45
        ballHighlight.OutlineTransparency = 0
        ballHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        ballHighlight.Parent = Library.Gui
    end
    if not ballBillboard then
        ballBillboard = Instance.new("BillboardGui")
        ballBillboard.Size = UDim2.fromOffset(140, 40)
        ballBillboard.StudsOffset = Vector3.new(0, 3, 0)
        ballBillboard.AlwaysOnTop = true
        ballBillboard.Parent = Library.Gui
        local bg = Instance.new("Frame")
        bg.Size = UDim2.fromScale(1, 0.75)
        bg.AnchorPoint = Vector2.new(0.5, 0)
        bg.Position = UDim2.fromScale(0.5, 0)
        bg.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        bg.BackgroundTransparency = 0.25
        bg.Parent = ballBillboard
        Util.Round(bg)
        ballInfoLabel = Instance.new("TextLabel")
        ballInfoLabel.BackgroundTransparency = 1
        ballInfoLabel.Size = UDim2.fromScale(1, 1)
        ballInfoLabel.Font = Theme.FontBold
        ballInfoLabel.TextSize = 13
        ballInfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        ballInfoLabel.Parent = bg
    end
    ballHighlight.Adornee = ball
    ballHighlight.FillColor = Visuals.ESPColor
    ballHighlight.OutlineColor = Util.Lighten(Visuals.ESPColor, 0.3)
    ballHighlight.Enabled = true
    ballBillboard.Adornee = ball
    ballBillboard.Enabled = Visuals.BallInfo
end

local function HideBallESP()
    if ballHighlight then ballHighlight.Enabled = false end
    if ballBillboard then ballBillboard.Enabled = false end
end

local TRAJ_DOTS = 26
local trajDots = {}
local landing
local function EnsureTrajectory()
    if #trajDots == 0 then
        for i = 1, TRAJ_DOTS do
            local d = NewMarkerPart(Vector3.new(0.45, 0.45, 0.45), Visuals.ESPColor, Enum.PartType.Ball, 0.15 + i / TRAJ_DOTS * 0.6)
            d.Position = Vector3.new(0, -1000, 0)
            trajDots[i] = d
        end
    end
end
local function HideTrajectory()
    for _, d in ipairs(trajDots) do d.Position = Vector3.new(0, -1000, 0) end
end
local function EnsureLanding()
    if not landing then
        landing = NewMarkerPart(Vector3.new(0.3, 4, 4), Visuals.ESPColor, Enum.PartType.Cylinder, 0.35)
        landing.Position = Vector3.new(0, -1000, 0)
    end
end

local goalParts = {}
local function DrawGoal()
    for _, p in ipairs(goalParts) do p:Destroy() end
    goalParts = {}
    if not Visuals.GoalOutline or not Engine.HasGoal() then return end
    local G, n, r = Engine.MyGoal, Engine.GoalForward, Engine.Right()
    local w, h = Engine.GoalWidth, Engine.GoalHeight
    local function Bar(a, b, thick)
        local len = (b - a).Magnitude
        local p = NewMarkerPart(Vector3.new(thick, thick, len), Visuals.ESPColor, nil, 0.3)
        p.CFrame = CFrame.lookAt((a + b) / 2, b)
        table.insert(goalParts, p)
    end
    local L, R = G - r * (w / 2), G + r * (w / 2)
    local up = Vector3.new(0, h, 0)
    Bar(L, R, 0.25)
    Bar(L, L + up, 0.25)
    Bar(R, R + up, 0.25)
    Bar(L + up, R + up, 0.25)

    local fl, fr = L + n * GK.MaxAdvance, R + n * GK.MaxAdvance
    Bar(L, fl, 0.15)
    Bar(R, fr, 0.15)
    Bar(fl, fr, 0.15)
end
Visuals.DrawGoal = DrawGoal

local playerESP = {}
local function RemovePlayerESP(plr)
    local e = playerESP[plr]
    if e then
        if e.HL then e.HL:Destroy() end
        if e.BB then e.BB:Destroy() end
        playerESP[plr] = nil
    end
end

local function UpdatePlayerESP()
    local myRoot = Util.Root()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local show = Visuals.PlayerESP and char and char:FindFirstChild("HumanoidRootPart")
            if show and Visuals.EnemiesOnly and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
                show = false
            end
            if show then
                local e = playerESP[plr]
                if not e or not e.HL or not e.HL.Parent or e.Char ~= char then
                    RemovePlayerESP(plr)
                    e = { Char = char }
                    e.HL = Instance.new("Highlight")
                    e.HL.FillTransparency = 0.7
                    e.HL.OutlineTransparency = 0.1
                    e.HL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    e.HL.Adornee = char
                    e.HL.Parent = Library.Gui
                    e.BB = Instance.new("BillboardGui")
                    e.BB.Size = UDim2.fromOffset(160, 22)
                    e.BB.StudsOffset = Vector3.new(0, 3.4, 0)
                    e.BB.AlwaysOnTop = true
                    e.BB.Adornee = char:FindFirstChild("Head") or char.HumanoidRootPart
                    e.BB.Parent = Library.Gui
                    e.Label = Instance.new("TextLabel")
                    e.Label.BackgroundTransparency = 1
                    e.Label.Size = UDim2.fromScale(1, 1)
                    e.Label.Font = Theme.FontBold
                    e.Label.TextSize = 13
                    e.Label.TextStrokeTransparency = 0.4
                    e.Label.Parent = e.BB
                    playerESP[plr] = e
                end
                local col = plr.Team and plr.TeamColor.Color or Visuals.ESPColor
                e.HL.FillColor = col
                e.HL.OutlineColor = col
                e.BB.Enabled = Visuals.PlayerNames
                e.Label.TextColor3 = col
                local dist = myRoot and math.floor((char.HumanoidRootPart.Position - myRoot.Position).Magnitude) or 0
                e.Label.Text = string.format("%s  \xB7  %dm", plr.DisplayName, dist)
            else
                RemovePlayerESP(plr)
            end
        end
    end
end
Track(Players.PlayerRemoving:Connect(RemovePlayerESP))

function Visuals.SetBallCam(on)
    Visuals.BallCam = on
    if not on then
        local hum = Util.Humanoid()
        if hum then Camera.CameraSubject = hum end
    end
end

function Visuals.SetFOV(on)
    Visuals.FOVOn = on
    if not on then Camera.FieldOfView = Visuals._defaultFOV end
end

function Visuals.SetFullbright(on)
    Visuals.Fullbright = on
    if on then
        Visuals._lighting = Visuals._lighting or {
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
    elseif Visuals._lighting then
        for k, v in pairs(Visuals._lighting) do pcall(function() Lighting[k] = v end) end
        Visuals._lighting = nil
    end
end

function Visuals.SetNoFog(on)
    Visuals.NoFog = on
    if on then
        Visuals._fog = Visuals._fog or { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart }
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                a:SetAttribute("UH_Density", a.Density)
                a.Density = 0
            end
        end
    elseif Visuals._fog then
        Lighting.FogEnd = Visuals._fog.FogEnd
        Lighting.FogStart = Visuals._fog.FogStart
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") and a:GetAttribute("UH_Density") then
                a.Density = a:GetAttribute("UH_Density")
            end
        end
        Visuals._fog = nil
    end
end

function Visuals.FPSBoost()
    local count = 0
    pcall(function()
        Lighting.GlobalShadows = false
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and not d:IsDescendantOf(VisualFolder) then
            d.Material = Enum.Material.SmoothPlastic
            d.Reflectance = 0
            d.CastShadow = false
            count = count + 1
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 1
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
            d.Enabled = false
        end
    end
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") then e.Enabled = false end
    end
    return count
end

local ShotHUD
local function BuildShotHUD()
    ShotHUD = Util.Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 12),
        BackgroundTransparency = 0.1,
        Size = UDim2.fromOffset(230, 44),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -60),
        Parent = Library.Gui,
    })
    Util.Round(ShotHUD)
    local st = Util.Stroke(ShotHUD, Theme.Danger, 1.5, 0.2)
    ShotHUD:SetAttribute("Shown", false)
    local dot = Util.Create("Frame", {
        BackgroundColor3 = Theme.Danger,
        Size = UDim2.fromOffset(10, 10),
        Position = UDim2.fromOffset(18, 17),
        Parent = ShotHUD,
    })
    Util.Round(dot)
    Util.Create("TextLabel", {
        Name = "Text",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -44, 1, 0),
        Position = UDim2.fromOffset(38, 0),
        Font = Theme.FontBold,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "CHUTE!",
        Parent = ShotHUD,
    })
    task.spawn(function()
        while dot.Parent do
            Util.Tween(dot, 0.4, { BackgroundTransparency = 0.7 })
            task.wait(0.4)
            Util.Tween(dot, 0.4, { BackgroundTransparency = 0 })
            task.wait(0.4)
        end
    end)
    return st
end

local function UpdateShotHUD()
    if not ShotHUD then BuildShotHUD() end
    local shot = Engine.Shot
    local shouldShow = Visuals.ShotHUD and shot ~= nil and shot.Info ~= nil
    if shouldShow then
        local info = shot.Info
        ShotHUD.Text.Text = string.format("CHUTE  \xB7  %d st/s  \xB7  %.2fs", math.floor(info.Speed), math.max(info.Time - (tick() - shot.Start), 0))
        if not ShotHUD:GetAttribute("Shown") then
            ShotHUD:SetAttribute("Shown", true)
            Util.Spring(ShotHUD, { Position = UDim2.new(0.5, 0, 0, 90) }, 0.4)
        end
    elseif ShotHUD:GetAttribute("Shown") then
        ShotHUD:SetAttribute("Shown", false)
        Util.Tween(ShotHUD, 0.3, { Position = UDim2.new(0.5, 0, 0, -60) })
    end
end

function Visuals.Step()
    local ball = Engine.Ball
    if Visuals.BallESP and ball then
        EnsureBallESP(ball)
        if ballInfoLabel then
            ballInfoLabel.Text = string.format("%d st/s  \xB7  %dm", math.floor(Engine.BallSpeed), math.floor(Engine.BallDistance))
        end
    else
        HideBallESP()
    end

    if Visuals.Trajectory and ball and Engine.BallSpeed > 3 then
        EnsureTrajectory()
        local pts = Engine.Trajectory(TRAJ_DOTS, 1.6)
        for i, d in ipairs(trajDots) do
            if pts[i] then
                d.Position = pts[i]
                d.Color = Visuals.ESPColor
            end
        end
    elseif #trajDots > 0 then
        HideTrajectory()
    end

    if Visuals.LandingMarker then
        EnsureLanding()
        local info = Engine.Intercept(GK.SaveDepth, 6, 3)
        if info then
            landing.CFrame = CFrame.new(info.Point) * CFrame.Angles(0, 0, 0)
            local lookCF = CFrame.lookAt(info.Point, info.Point + Engine.GoalForward)
            landing.CFrame = lookCF * CFrame.Angles(0, math.rad(90), 0)
            landing.Color = info.OnTarget and Theme.Danger or Visuals.ESPColor
        else
            landing.Position = Vector3.new(0, -1000, 0)
        end
    elseif landing then
        landing.Position = Vector3.new(0, -1000, 0)
    end

    if Visuals.BallCam and ball then
        Camera.CameraSubject = ball
    end
    if Visuals.FOVOn then
        Camera.FieldOfView = Visuals.FOV
    end
    if Visuals.Fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    end
    if Visuals.NoFog then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
    end
    UpdateShotHUD()
end

local espTimer = 0
Track(RunService.Heartbeat:Connect(function(dt)
    espTimer = espTimer + dt
    if espTimer >= 0.2 then
        espTimer = 0
        pcall(UpdatePlayerESP)
    end
end))

OnUnload(function()
    Visuals.SetBallCam(false)
    Visuals.SetFOV(false)
    Visuals.SetFullbright(false)
    Visuals.SetNoFog(false)
    for plr in pairs(playerESP) do RemovePlayerESP(plr) end
end)

local Window = Library:CreateWindow({
    Title = "Ultimate Hub",
    Subtitle = "Futebol Proibido \xB7 Gen2",
    Badge = "updated",
})

local function Notify(title, content, kind)
    Library:Notify({ Title = title, Content = content, Type = kind or "info", Duration = 3.5 })
end

local HomeTab = Window:CreateTab("Home", "home")

local QuickStats = HomeTab:CreateSection("Quick Stats", "home")
local StatsBall = QuickStats:Stats({ Name = "Bola", Value = "0 st/s" }, { Name = "Distancia", Value = "0m" })
local StatsKeeper = QuickStats:Stats({ Name = "Defesas", Value = "0" }, { Name = "Chutes", Value = "0" })

local HomeMain = HomeTab:CreateSection("Main Controls", "home")
local FullKeeperToggle
FullKeeperToggle = HomeMain:Toggle({
    Name = "Modo Goleiro Completo",
    Flag = "FullKeeper",
    Default = false,
    Callback = function(v)
        local list = { "AutoSave", "AutoPosition", "AutoDive", "FaceBall", "LineLock" }
        for _, f in ipairs(list) do
            local el = Library.Elements[f]
            if el then el:Set(v) end
        end
        Notify("Goleiro", v and "Modo completo ligado. Bora fechar o gol!" or "Modo completo desligado.", v and "success" or "info")
    end,
})
HomeMain:Slider({
    Name = "Field of View",
    Min = 50, Max = 120, Default = 80, Increment = 1, Suffix = " \xB0",
    Flag = "FOVValue",
    Callback = function(v)
        Visuals.FOV = v
        if not Visuals.FOVOn then
            local el = Library.Elements["FOVOn"]
            if el then el:Set(true) end
        end
    end,
})
local StatusLabel = HomeMain:Paragraph({ Title = "Status do goleiro", Content = "Procurando bola..." })

local HomeMore = HomeTab:CreateSection("More Options", "home")
HomeMore:Button({
    Name = "Definir Meu Gol (fique na linha)",
    Callback = function()
        if Engine.SetGoalHere() then
            local el = Library.Elements["GoalMode"]
            if el then el:Set("Manual", true) end
            Visuals.DrawGoal()
            Notify("Gol definido", "Gol salvo onde voce esta, olhando pro campo.", "success")
        else
            Notify("Erro", "Personagem nao encontrado.", "error")
        end
    end,
})
HomeMore:Button({
    Name = "Show Notification",
    Callback = function()
        Notify("Ultimate Hub", "Notificacoes funcionando perfeitamente.", "success")
    end,
})
HomeMore:Button({
    Name = "Show Toast",
    Callback = function()
        Library:Toast("Ultimate Hub", "Tudo pronto pra defender", 2.5)
    end,
})
local BigSaves = HomeMore:BigStat({ Name = "Defesas na partida", Value = 0, Delta = "0%" })

local KeeperTab = Window:CreateTab("Goleiro", "glove")

local KMain = KeeperTab:CreateSection("Automatico", "shield")
local kg = KMain:Grid()
kg:Toggle({ Name = "Auto Save", Flag = "AutoSave", Callback = function(v) GK.AutoSave = v end })
kg:Toggle({ Name = "Auto Posicao", Flag = "AutoPosition", Callback = function(v)
    GK.AutoPosition = v
    if not v then GK.Stop() end
end })
kg:Toggle({ Name = "Auto Mergulho", Flag = "AutoDive", Callback = function(v) GK.AutoDive = v end })
kg:Toggle({ Name = "Auto Pegar", Flag = "AutoReach", Callback = function(v)
    GK.AutoReach = v
    if v and not firetouchinterest then
        Notify("Auto Pegar", "Seu executor nao tem firetouchinterest. Use Reach maior + Auto Save.", "warn")
    end
end })
kg:Toggle({ Name = "Auto Afastar", Flag = "AutoClear", Callback = function(v) GK.AutoClear = v end })
kg:Toggle({ Name = "Olhar pra Bola", Flag = "FaceBall", Callback = function(v) GK.SetFaceBall(v) end })
kg:Toggle({ Name = "Sair do Gol 1x1", Flag = "RushOut", Callback = function(v) GK.RushOut = v end })
kg:Toggle({ Name = "Trava na Area", Flag = "LineLock", Callback = function(v) GK.LineLock = v end })
kg:Toggle({ Name = "Humanizador", Flag = "Humanizer", Default = true, Callback = function(v) GK.Humanizer = v end })
kg:Toggle({ Name = "Alerta de Chute", Flag = "ShotHUD", Default = true, Callback = function(v) Visuals.ShotHUD = v end })

local KMove = KeeperTab:CreateSection("Movimento", "run")
KMove:Dropdown({
    Name = "Modo de Defesa",
    Options = { "Legit (andar)", "Tween", "Teleporte" },
    Default = "Legit (andar)",
    Flag = "MoveMode",
    Callback = function(v)
        GK.MoveMode = v
        if v == "Teleporte" then Notify("Atencao", "Teleporte e o mais forte, mas o mais facil de notarem.", "warn") end
    end,
})
KMove:Slider({ Name = "Velocidade do Tween", Min = 20, Max = 200, Default = 60, Suffix = " st/s", Flag = "TweenSpeed", Callback = function(v) GK.TweenSpeed = v end })
KMove:Slider({ Name = "Tempo de Reacao", Min = 0.2, Max = 3, Default = 1.4, Increment = 0.05, Suffix = "s", Flag = "ReactionTime", Callback = function(v) GK.ReactionTime = v end })
KMove:Slider({ Name = "Atraso Humano", Min = 0, Max = 0.5, Default = 0.08, Increment = 0.01, Suffix = "s", Flag = "HumanDelay", Callback = function(v) GK.HumanDelay = v end })

local KPos = KeeperTab:CreateSection("Posicionamento", "target")
KPos:Slider({ Name = "Distancia da Linha", Min = 0, Max = 20, Default = 5, Increment = 0.5, Suffix = " st", Flag = "PositionDepth", Callback = function(v) GK.PositionDepth = v end })
KPos:Slider({ Name = "Acompanhar Bola", Min = 0, Max = 1, Default = 0.45, Increment = 0.05, Flag = "PositionFactor", Callback = function(v) GK.PositionFactor = v end })
KPos:Slider({ Name = "Profundidade Defesa", Min = 0, Max = 12, Default = 3, Increment = 0.5, Suffix = " st", Flag = "SaveDepth", Callback = function(v) GK.SaveDepth = v end })
KPos:Slider({ Name = "Limite da Area", Min = 4, Max = 40, Default = 14, Suffix = " st", Flag = "MaxAdvance", Callback = function(v) GK.MaxAdvance = v; Visuals.DrawGoal() end })
KPos:Slider({ Name = "Distancia Sair do Gol", Min = 8, Max = 50, Default = 22, Suffix = " st", Flag = "RushDistance", Callback = function(v) GK.RushDistance = v end })

local KReach = KeeperTab:CreateSection("Alcance", "glove")
KReach:Slider({ Name = "Raio de Defesa", Min = 10, Max = 200, Default = 70, Suffix = " st", Flag = "SaveRadius", Callback = function(v) GK.SaveRadius = v end })
KReach:Slider({ Name = "Reach (Auto Pegar)", Min = 2, Max = 25, Default = 9, Increment = 0.5, Suffix = " st", Flag = "ReachRadius", Callback = function(v) GK.ReachRadius = v end })
KReach:Slider({ Name = "Raio Afastar", Min = 2, Max = 15, Default = 5, Increment = 0.5, Suffix = " st", Flag = "ClearRadius", Callback = function(v) GK.ClearRadius = v end })
KReach:Slider({ Name = "Altura p/ Mergulho", Min = 1, Max = 12, Default = 4.5, Increment = 0.5, Suffix = " st", Flag = "DiveHeight", Callback = function(v) GK.DiveHeight = v end })
KReach:Slider({ Name = "Velocidade Min. Chute", Min = 5, Max = 80, Default = 18, Suffix = " st/s", Flag = "MinShotSpeed", Callback = function(v) GK.MinShotSpeed = v end })

local KGoal = KeeperTab:CreateSection("Meu Gol", "goal")
KGoal:Dropdown({
    Name = "Deteccao do Gol",
    Options = { "Auto", "Manual" },
    Default = "Auto",
    Flag = "GoalMode",
    Callback = function(v)
        Engine.GoalMode = v
        if v == "Auto" then
            Engine.ScanGoals()
            if Engine.AutoAssignGoal() then
                Visuals.DrawGoal()
                Notify("Gol", "Gol detectado automaticamente (" .. #Engine.Goals .. " encontrados).", "success")
            else
                Notify("Gol", "Nao achei o gol. Use 'Definir Meu Gol'.", "warn")
            end
        end
    end,
})
KGoal:Button({
    Name = "Definir Meu Gol Aqui",
    Callback = function()
        if Engine.SetGoalHere() then
            local el = Library.Elements["GoalMode"]
            if el then el:Set("Manual", true) end
            Visuals.DrawGoal()
            Notify("Gol definido", "Gol salvo na sua posicao.", "success")
        end
    end,
})
KGoal:Button({
    Name = "Detectar Gols de Novo",
    Callback = function()
        local g = Engine.ScanGoals()
        local ok = Engine.AutoAssignGoal()
        Visuals.DrawGoal()
        Notify("Gols", ok and (#g .. " gol(s) encontrados. O mais perto virou o seu.") or "Nenhum gol encontrado.", ok and "success" or "warn")
    end,
})
KGoal:Button({
    Name = "Trocar de Lado",
    Callback = function()
        if Engine.SwapGoal() then
            Visuals.DrawGoal()
            Notify("Gol", "Lado trocado.", "success")
        else
            Notify("Gol", "Preciso de 2 gols detectados pra trocar.", "warn")
        end
    end,
})
KGoal:Slider({ Name = "Largura do Gol", Min = 8, Max = 60, Default = 24, Suffix = " st", Flag = "GoalWidth", Callback = function(v) Engine.GoalWidth = v; Visuals.DrawGoal() end })
KGoal:Slider({ Name = "Altura do Gol", Min = 4, Max = 25, Default = 9, Suffix = " st", Flag = "GoalHeight", Callback = function(v) Engine.GoalHeight = v; Visuals.DrawGoal() end })
KGoal:Button({ Name = "Teleportar pro Gol", Callback = function()
    if not PlayerMods.TeleportToGoal() then Notify("Gol", "Defina seu gol primeiro.", "warn") end
end })

local KKeys = KeeperTab:CreateSection("Teclas do Jogo", "keyboard")
KKeys:Paragraph({ Title = "Dica", Content = "Se o jogo tiver tecla de defesa/mergulho/chute, configure aqui. O hub aperta sozinho na hora certa." })
KKeys:Keybind({ Name = "Tecla de Defesa", Flag = "SaveKey", Default = nil, Changed = function(k) GK.SaveKey = k end })
KKeys:Keybind({ Name = "Tecla de Mergulho", Flag = "DiveKey", Default = nil, Changed = function(k) GK.DiveKey = k end })
KKeys:Keybind({ Name = "Tecla de Chute", Flag = "ClearKey", Default = nil, Changed = function(k) GK.ClearKey = k end })
KKeys:Toggle({ Name = "Clicar ao Defender", Flag = "ClickOnSave", Callback = function(v) GK.ClickOnSave = v end })
KKeys:Keybind({
    Name = "Atalho Auto Save",
    Flag = "AutoSaveBind",
    Default = Enum.KeyCode.G,
    Callback = function()
        local el = Library.Elements["AutoSave"]
        if el then
            el:Set(not el.Value)
            Notify("Auto Save", el.Value and "Ligado" or "Desligado", el.Value and "success" or "info")
        end
    end,
})
KKeys:Keybind({
    Name = "Atalho Auto Posicao",
    Flag = "AutoPosBind",
    Default = Enum.KeyCode.H,
    Callback = function()
        local el = Library.Elements["AutoPosition"]
        if el then
            el:Set(not el.Value)
            Notify("Auto Posicao", el.Value and "Ligado" or "Desligado", el.Value and "success" or "info")
        end
    end,
})

local KStats = KeeperTab:CreateSection("Estatisticas", "star")
local KStatsCards = KStats:Stats({ Name = "Sofridos", Value = "0" }, { Name = "Toques", Value = "0" })
KStats:Button({ Name = "Zerar Estatisticas", Icon = "trash", Callback = function()
    Engine.Stats.Saves, Engine.Stats.Shots, Engine.Stats.Conceded, Engine.Stats.Touches, Engine.Stats.TopSpeed = 0, 0, 0, 0, 0
    Notify("Estatisticas", "Zeradas.", "success")
end })

local PlayerTab = Window:CreateTab("Jogador", "user")

local PMove = PlayerTab:CreateSection("Movimento", "run")
PMove:Toggle({ Name = "Velocidade", Flag = "SpeedOn", Callback = function(v) PlayerMods.SetSpeed(v) end })
PMove:Slider({ Name = "WalkSpeed", Min = 16, Max = 80, Default = 24, Flag = "SpeedValue", Callback = function(v) PlayerMods.Speed = v end })
PMove:Toggle({ Name = "Pulo Alto", Flag = "JumpOn", Callback = function(v) PlayerMods.SetJump(v) end })
PMove:Slider({ Name = "JumpPower", Min = 50, Max = 200, Default = 60, Flag = "JumpValue", Callback = function(v) PlayerMods.Jump = v end })

local PExtra = PlayerTab:CreateSection("Extras", "bolt")
local pg = PExtra:Grid()
pg:Toggle({ Name = "Auto Sprint", Flag = "AutoSprint", Callback = function(v) PlayerMods.SetSprint(v) end })
pg:Toggle({ Name = "Pulo Infinito", Flag = "InfJump", Callback = function(v) PlayerMods.InfJump = v end })
pg:Toggle({ Name = "Anti Ragdoll", Flag = "AntiRagdoll", Callback = function(v) PlayerMods.SetAntiRagdoll(v) end })
pg:Toggle({ Name = "Noclip", Flag = "Noclip", Callback = function(v) PlayerMods.Noclip = v end })
pg:Toggle({ Name = "Anti AFK", Flag = "AntiAFK", Default = true, Callback = function(v) PlayerMods.AntiAFK = v end })
pg:Toggle({ Name = "Toque Auto", Flag = "AutoTouch", Callback = function(v) PlayerMods.AutoTouch = v end })
PExtra:Keybind({ Name = "Tecla de Sprint do Jogo", Flag = "SprintKey", Default = Enum.KeyCode.LeftShift, Changed = function(k)
    PlayerMods.SetSprint(false)
    PlayerMods.SprintKey = k or Enum.KeyCode.LeftShift
    local el = Library.Elements["AutoSprint"]
    if el and el.Value then PlayerMods.SetSprint(true) end
end })

local PTp = PlayerTab:CreateSection("Teleporte", "globe")
PTp:Button({ Name = "Ir ate a Bola", Callback = function()
    if not PlayerMods.TeleportToBall() then Notify("Bola", "Bola nao encontrada.", "warn") end
end })
PTp:Keybind({ Name = "Atalho Ir ate a Bola", Flag = "TpBallBind", Default = nil, Callback = function() PlayerMods.TeleportToBall() end })
PTp:Button({ Name = "Ir pro Meu Gol", Callback = function()
    if not PlayerMods.TeleportToGoal() then Notify("Gol", "Defina seu gol primeiro.", "warn") end
end })

local VisualTab = Window:CreateTab("Visual", "eye")

local VBall = VisualTab:CreateSection("Bola", "ball")
local vg = VBall:Grid()
vg:Toggle({ Name = "ESP Bola", Flag = "BallESP", Callback = function(v) Visuals.BallESP = v end })
vg:Toggle({ Name = "Info da Bola", Flag = "BallInfo", Default = true, Callback = function(v) Visuals.BallInfo = v end })
vg:Toggle({ Name = "Trajetoria", Flag = "Trajectory", Callback = function(v) Visuals.Trajectory = v end })
vg:Toggle({ Name = "Ponto de Impacto", Flag = "LandingMarker", Callback = function(v) Visuals.LandingMarker = v end })

local VPlayers = VisualTab:CreateSection("Jogadores", "user")
local vpg = VPlayers:Grid()
vpg:Toggle({ Name = "ESP Jogadores", Flag = "PlayerESP", Callback = function(v) Visuals.PlayerESP = v end })
vpg:Toggle({ Name = "Nomes", Flag = "PlayerNames", Default = true, Callback = function(v) Visuals.PlayerNames = v end })
vpg:Toggle({ Name = "So Inimigos", Flag = "EnemiesOnly", Callback = function(v) Visuals.EnemiesOnly = v end })
vpg:Toggle({ Name = "Contorno do Gol", Flag = "GoalOutline", Callback = function(v) Visuals.GoalOutline = v; Visuals.DrawGoal() end })
VPlayers:Dropdown({
    Name = "Cor do ESP",
    Options = { "Verde", "Azul", "Roxo", "Vermelho", "Laranja", "Rosa", "Ciano" },
    Default = "Verde",
    Flag = "ESPColor",
    Callback = function(v) Visuals.ESPColor = AccentPresets[v] or Visuals.ESPColor; Visuals.DrawGoal() end,
})

local VCam = VisualTab:CreateSection("Camera e Mundo", "camera")
VCam:Toggle({ Name = "Camera na Bola", Flag = "BallCam", Callback = function(v) Visuals.SetBallCam(v) end })
VCam:Toggle({ Name = "FOV Personalizado", Flag = "FOVOn", Callback = function(v) Visuals.SetFOV(v) end })
local vcg = VCam:Grid()
vcg:Toggle({ Name = "Fullbright", Flag = "Fullbright", Callback = function(v) Visuals.SetFullbright(v) end })
vcg:Toggle({ Name = "Sem Neblina", Flag = "NoFog", Callback = function(v) Visuals.SetNoFog(v) end })
VCam:Button({ Name = "FPS Boost", Icon = "bolt", Callback = function()
    local n = Visuals.FPSBoost()
    Notify("FPS Boost", Util.FormatNumber(n) .. " pecas otimizadas.", "success")
end })

local VLive = VisualTab:CreateSection("Ao Vivo", "star")
local BigSpeed = VLive:BigStat({ Name = "Chute mais forte", Value = 0, Delta = "st/s" })

local ConfigTab = Window:CreateTab("Config", "gear")

local CUI = ConfigTab:CreateSection("Interface", "brush")
CUI:Keybind({
    Name = "Abrir/Fechar Menu",
    Flag = "MenuKey",
    Default = Library.ToggleKey,
    Changed = function(k)
        Library.ToggleKey = k or Enum.KeyCode.RightShift
        Window:UpdatePillHint()
    end,
})
CUI:Dropdown({
    Name = "Cor de Destaque",
    Options = { "Verde", "Azul", "Roxo", "Vermelho", "Laranja", "Rosa", "Ciano" },
    Default = "Verde",
    Flag = "AccentColor",
    Callback = function(v) ApplyAccent(AccentPresets[v] or Theme.Accent) end,
})
CUI:Slider({
    Name = "Escala da UI",
    Min = 0.5, Max = 1.3, Default = 1, Increment = 0.05, Suffix = "x",
    Flag = "UIScaleMul",
    Callback = function(v)
        local base = Window.BaseScale / (Window._mul or 1)
        Window._mul = v
        Window.BaseScale = base * v
        Util.Tween(Window.Scale, 0.3, { Scale = Window.BaseScale })
    end,
})

local CGame = ConfigTab:CreateSection("Jogo", "ball")
CGame:Input({
    Name = "Nome da Bola",
    Placeholder = "auto",
    Flag = "BallName",
    Callback = function(v)
        Engine.BallName = v or ""
        Engine.Ball = nil
        local b = Engine.ScanBall()
        if v ~= "" then
            Notify("Bola", b and ("Bola encontrada: " .. b.Name) or "Nada com esse nome.", b and "success" or "warn")
        end
    end,
})
CGame:Button({ Name = "Procurar Bola Agora", Icon = "search", Callback = function()
    Engine.Ball = nil
    local b = Engine.ScanBall()
    Notify("Bola", b and ("Encontrada: " .. b:GetFullName()) or "Nao achei a bola.", b and "success" or "warn")
end })

local CCfg = ConfigTab:CreateSection("Configuracao", "save")
CCfg:Toggle({ Name = "Carregar Config ao Abrir", Flag = "AutoLoad", Default = true })
CCfg:Button({ Name = "Salvar Config", Icon = "check", Callback = function() Library:SaveConfig() end })
CCfg:Button({ Name = "Carregar Config", Callback = function() Library:LoadConfig() end })

local CServer = ConfigTab:CreateSection("Servidor", "globe")
CServer:Button({ Name = "Reentrar no Servidor", Callback = function()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end })
CServer:Button({ Name = "Descarregar Hub", Icon = "close", Callback = function()
    if getgenv and getgenv().UltimateHubUnload then getgenv().UltimateHubUnload() end
end })
CServer:Paragraph({ Title = "Ultimate Hub", Content = "Feito para Futebol Proibido. Use RShift (ou a pilula no topo) para mostrar/esconder." })

PlayerMods.AutoTouch = false
local lastAutoTouch = 0

Track(RunService.Heartbeat:Connect(function(dt)
    local ok, err = pcall(function()
        Engine.Update(dt)
        GK.Step(dt)
        PlayerMods.Step()
        if PlayerMods.AutoTouch and Engine.Ball and tick() - lastAutoTouch > 0.15 then
            lastAutoTouch = tick()
            GK.TouchBall(Engine.Ball, 6)
        end
    end)
    if not ok then warn("[UltimateHub] " .. tostring(err)) end
end))

Track(RunService.RenderStepped:Connect(function()
    pcall(Visuals.Step)
end))

task.spawn(function()
    local lastSaves = -1
    while Library.Gui and Library.Gui.Parent do
        pcall(function()
            StatsBall:SetLeft(math.floor(Engine.BallSpeed) .. " st/s")
            StatsBall:SetRight(Engine.Ball and (math.floor(Engine.BallDistance) .. "m") or "--")
            StatsKeeper:SetLeft(Engine.Stats.Saves)
            StatsKeeper:SetRight(Engine.Stats.Shots)
            KStatsCards:SetLeft(Engine.Stats.Conceded)
            KStatsCards:SetRight(Engine.Stats.Touches)
            if Engine.Stats.Saves ~= lastSaves then
                lastSaves = Engine.Stats.Saves
                local rate = Engine.Stats.Shots > 0 and (Engine.Stats.Saves / Engine.Stats.Shots * 100) or 0
                BigSaves:Set(Engine.Stats.Saves, string.format("%.1f%%", rate))
            end
            BigSpeed:Set(math.floor(Engine.Stats.TopSpeed), "st/s")
            local goalTxt = Engine.HasGoal() and ("Gol: " .. Engine.GoalMode) or "Gol: nao definido"
            local ballTxt = Engine.Ball and ("Bola: " .. Engine.Ball.Name) or "Bola: procurando"
            StatusLabel:Set(GK._status .. "  \xB7  " .. ballTxt .. "  \xB7  " .. goalTxt)
        end)
        task.wait(0.25)
    end
end)

local unloaded = false
local function Unload()
    if unloaded then return end
    unloaded = true
    for _, fn in ipairs(Cleanup) do pcall(fn) end
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    if getgenv then
        getgenv().UltimateHubLoaded = nil
        getgenv().UltimateHubUnload = nil
    end
end

if getgenv then
    getgenv().UltimateHubLoaded = true
    getgenv().UltimateHubUnload = Unload
end

task.spawn(function()
    Engine.ScanBall()
    Engine.ScanGoals()
    if Engine.GoalMode == "Auto" then Engine.AutoAssignGoal() end
    task.wait(0.4)
    if Library.Flags["AutoLoad"] ~= false then
        Library:LoadConfig(true)
    end
    Library:Toast("Ultimate Hub", "Futebol Proibido carregado", 3)
    task.wait(0.6)
    Library:Notify({
        Title = "Bem-vindo, " .. LocalPlayer.DisplayName,
        Content = (Engine.Ball and "Bola detectada. " or "Procurando bola... ") .. (#Engine.Goals > 0 and (#Engine.Goals .. " gol(s) achados.") or "Defina seu gol."),
        Type = "success",
        Duration = 5,
    })
end)
