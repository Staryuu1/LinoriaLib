--[[
    UILib - Roblox UI library (dark theme, accent biru, sidebar + halaman + section)
    Gaya UI diambil dari "Feral GUI", ditulis ulang tanpa logika game.

    Pemakaian cepat:
        local Library = loadstring(readfile("UILib.lua"))()
        local Window  = Library:CreateMain({ Title = "My Hub", Desc = "v1.0" })
        local Page    = Window:CreatePage({ Name = "Main", Title = "Main Tab" })
        local Section = Page:CreateSection("Section 1")
        Section:CreateToggle({ Title = "Toggle", Desc = "deskripsi", Default = false }, function(v) end)
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService('HttpService')

local Library = {}
Library.__index = Library

-- ====================================================================
-- Theme: permukaan gelap dan aksen tipis mengikuti referensi Feral.
-- ====================================================================
local Theme = {
    Border       = Color3.fromRGB(40, 40, 40),
    Accent       = Color3.fromRGB(131, 181, 255),
    Text         = Color3.fromRGB(215, 215, 215),
    DescText     = Color3.fromRGB(185, 185, 185),
    Placeholder  = Color3.fromRGB(178, 178, 178),
    BGMain       = Color3.fromRGB(20, 20, 20),
    BG1          = Color3.fromRGB(27, 27, 27),
    BG2          = Color3.fromRGB(38, 38, 38),
    BG3          = Color3.fromRGB(24, 24, 24),
    Label        = Color3.fromRGB(30, 30, 30),
    SliderLine   = Color3.fromRGB(90, 130, 180),
    SliderHi     = Color3.fromRGB(59, 82, 115),
    Tween        = 0.25,
    Logo         = "rbxassetid://6248942117",
}
Library.Theme = Theme

local ICON = {
    Checkbox  = "rbxassetid://4552505888",
    Check     = "rbxassetid://4555411759",
    Arrow     = "rbxassetid://6954383209",
    Close     = "rbxassetid://3926305904",
}

-- ====================================================================
-- Helpers
-- ====================================================================
local function make(class, props, parent)
    local o = Instance.new(class)
    if o:IsA('GuiObject') then o.BorderSizePixel = 0 end
    if o:IsA('GuiButton') then o.AutoButtonColor = false end
    if o:IsA('TextLabel') or o:IsA('TextButton') or o:IsA('TextBox') then
        o.TextStrokeTransparency = 1
    end
    if o:IsA('ScrollingFrame') then
        o.ScrollBarImageColor3 = Color3.fromRGB(75, 75, 75)
    end
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end

local function corner(parent, r)
    return make("UICorner", { CornerRadius = UDim.new(0, r or 4) }, parent)
end

local function tween(obj, props, t)
    local tw = TweenService:Create(obj, TweenInfo.new(t or Theme.Tween), props)
    tw:Play()
    return tw
end

local function text(parent, props)
    local d = {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for k, v in pairs(props) do d[k] = v end
    return make("TextLabel", d, parent)
end

local function rgbTag(c)
    return ("rgb(%d,%d,%d)"):format(math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function safe(cb, ...)
    if type(cb) == "function" then
        local ok, err = pcall(cb, ...)
        if not ok then warn("[UILib] callback error:", err) end
    end
end

local function newGuiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    return CoreGui
end

-- Element holder: frame transparan + "Background1" (kotak BG1 bulat) di dalamnya
local function trackRow(section, holder, options)
    local row = { Holder = holder, Options = options }
    table.insert(section._controls, row)
    section._window:_Filter()
    return row
end

local function register(window, options, control, kind, validate, callback)
    if options.Flag then
        assert(type(options.Flag) == 'string' and options.Flag ~= '' and not window.Flags[options.Flag], 'Invalid or duplicate Flag')
        control.Flag, control.Kind, control.Validate = options.Flag, kind, validate
        control.Callback = callback
        window.Flags[options.Flag] = control
        table.insert(window.Controls, control)
    end
    return control
end

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function logoImage(value)
    assert(type(value) == 'string' or type(value) == 'number', 'Invalid logo')
    local image = tostring(value)
    if image:match('^%d+$') then return 'rbxassetid://' .. image end
    if image:match('^rbxassetid://%d+$') or image:match('^rbxasset://') then return image end
    if type(getcustomasset) == 'function' then
        local ok, asset = pcall(getcustomasset, image)
        if ok and type(asset) == 'string' then return asset end
    end
    error('Logo must be a Roblox image ID, asset URI, or local image supported by getcustomasset')
end

local function keycode(value)
    if type(value) ~= 'string' then return nil end
    local ok, key = pcall(function() return Enum.KeyCode[value] end)
    return ok and key or nil
end

function Library:_Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self._connections, connection)
    return connection
end

local function elementHolder(section, height, name, options)
    section._order = section._order + 1
    local holder = make("Frame", {
        Name = name or "Element",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height),
        LayoutOrder = section._order,
    }, section._frame)
    local bg = make("Frame", {
        Name = "Background1",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -10, 1, 0),
        BackgroundColor3 = Theme.BG1,
    }, holder)
    corner(bg)
    trackRow(section, holder, options)
    return holder, bg
end

-- ====================================================================
-- Window
-- ====================================================================
function Library:CreateMain(opts)
    opts = opts or {}
    local title = tostring(opts.Title or "UILib")
    local desc  = tostring(opts.Desc or "")

    local Window = setmetatable({ Pages = {}, Controls = {}, Flags = {}, _connections = {}, _order = 0,
        ConfigFolder = opts.ConfigFolder or 'Starhub/Feral', Logo = opts.Logo or Theme.Logo }, Library)

    local gui = make("ScreenGui", {
        Name = tostring(math.random(100000, 999999)),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, newGuiParent())
    Window.Gui = gui
    gui.Destroying:Connect(function()
        for _, connection in ipairs(Window._connections) do connection:Disconnect() end
        table.clear(Window._connections)
    end)

    -- Frame utama (transparan, dipakai untuk drag + posisi)
    local main = make("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 629, 0, 359),
        BackgroundTransparency = 1,
    }, gui)
    Window.Main = main
    Window.Scale = make('UIScale', { Scale = 1 }, main)
    local function fitScreen()
        local size = gui.AbsoluteSize
        local preferred = UserInputService.TouchEnabled and 0.8 or math.clamp(size.Y / 720, 1.15, 1.6)
        Window.Scale.Scale = math.min(preferred, math.max(0.1, (size.X - 24) / 629), math.max(0.1, (size.Y - 24) / 359))
        local scale = Window.Scale.Scale
        local halfWidth, halfHeight = 629 * scale / 2, 359 * scale / 2
        local position = main.Position
        local x = position.X.Scale * size.X + position.X.Offset
        local y = position.Y.Scale * size.Y + position.Y.Offset
        main.Position = UDim2.fromOffset(math.clamp(x, halfWidth, math.max(halfWidth, size.X - halfWidth)),
            math.clamp(y, halfHeight, math.max(halfHeight, size.Y - halfHeight)))
        if Window.HideButton then
            local buttonPosition = Window.HideButton.Position
            Window.HideButton.Position = UDim2.fromOffset(
                math.clamp(buttonPosition.X.Offset, 0, math.max(0, size.X - 44)),
                math.clamp(buttonPosition.Y.Offset, 0, math.max(0, size.Y - 44)))
        end
    end
    gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitScreen)
    task.defer(function() if gui.Parent then fitScreen() end end)

    local body = make("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BGMain,
        BorderSizePixel = 0,
    }, main)
    corner(body)
    make('UIStroke', { Color = Theme.Border, Thickness = 1 }, body)

    -- Top bar
    local top = make("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1 }, body)
    Window._logo = make("ImageLabel", {
        Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(0, 17, 0, 17),
        BackgroundTransparency = 1, Image = logoImage(Window.Logo), ScaleType = Enum.ScaleType.Fit,
    }, top)
    text(top, {
        Position = UDim2.new(0, 29, 0, 0), Size = UDim2.new(1, -224, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 13, RichText = true,
        Text = ('<font color="%s">%s</font> %s'):format(rgbTag(Theme.Accent), title, desc),
    })

    -- Drag lewat top bar
    do
        local dragging, startPos, startInput, dragInput
        top.InputBegan:Connect(function(i)
            if Window.Search and i.Position.X >= Window.Search.AbsolutePosition.X then return end
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, startInput, startPos = true, i.Position, main.Position
                dragInput = i
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        Window:_Connect(UserInputService.InputChanged, function(i)
            if dragging and (i == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
                and i.UserInputType == Enum.UserInputType.MouseMovement)) then
                local d = i.Position - startInput
                local scale = Window.Scale.Scale
                local size = gui.AbsoluteSize
                local x = startPos.X.Scale * size.X + startPos.X.Offset + d.X
                local y = startPos.Y.Scale * size.Y + startPos.Y.Offset + d.Y
                main.Position = UDim2.fromOffset(math.clamp(x, 629 * scale / 2, size.X - 629 * scale / 2),
                    math.clamp(y, 359 * scale / 2, size.Y - 359 * scale / 2))
            end
        end)
    end

    -- Area konten
    local content = make("Frame", {
        Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -30),
        BackgroundTransparency = 1, ClipsDescendants = true,
    }, body)

    -- Sidebar
    local side = make("Frame", {
        Name = "Sidebar", Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(0, 180, 0, 325),
        BackgroundColor3 = Theme.BG2,
    }, content)
    corner(side)
    make("Frame", {
        Name = "SidebarDivider", Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Theme.Border,
    }, side)
    local search = make('TextBox', {
        Name = 'Search', AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, 3), Size = UDim2.fromOffset(180, 19),
        BackgroundColor3 = Theme.BG1, Text = '', PlaceholderText = 'Search functions...',
        ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = Theme.Text, PlaceholderColor3 = Theme.Placeholder,
    }, top)
    corner(search)
    Window.Search = search
    local sideList = make("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -5, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, side)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, sideList)

    -- Holder halaman
    local pages = make("Frame", {
        Name = "Pages", Position = UDim2.new(0, 190, 0, 0), Size = UDim2.new(0, 435, 0, 325),
        BackgroundTransparency = 1, ClipsDescendants = true,
    }, content)

    Window._sideList, Window._pages = sideList, pages
    Window._searchResults = make('ScrollingFrame', {
        Name = 'SearchResults', Size = UDim2.fromScale(1, 1), Visible = false,
        BackgroundTransparency = 1, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, pages)
    make('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, Window._searchResults)
    Window._emptySearch = text(Window._searchResults, {
        Size = UDim2.new(1, 0, 0, 30), Text = 'No matching functions', Visible = false,
    })
    search:GetPropertyChangedSignal('Text'):Connect(function() Window:_Filter() end)

    -- Toggle UI (default RightShift)
    Window.ToggleKey = Enum.KeyCode.RightShift
    Window:_Connect(UserInputService.InputBegan, function(i, gp)
        if not gp and not UserInputService:GetFocusedTextBox() and i.KeyCode == Window.ToggleKey then Window:SetVisible(not main.Visible) end
    end)

    Window.HideButton = make('ImageButton', {
        Name = 'HideButton', Position = UDim2.fromOffset(12, 120), Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = Theme.BG2, Image = Window._logo.Image, ScaleType = Enum.ScaleType.Fit,
        Visible = UserInputService.TouchEnabled, ZIndex = 20,
    }, gui)
    corner(Window.HideButton, 12)
    local buttonStart, buttonPosition, buttonInput, buttonMoved
    Window.HideButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            buttonStart, buttonPosition, buttonInput, buttonMoved = input.Position, Window.HideButton.Position, input, false
        end
    end)
    Window:_Connect(UserInputService.InputChanged, function(input)
        if buttonInput and (input == buttonInput or (buttonInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement)) then
            local delta = input.Position - buttonStart
            buttonMoved = buttonMoved or delta.Magnitude > 6
            local size = gui.AbsoluteSize
            Window.HideButton.Position = UDim2.fromOffset(
                math.clamp(buttonPosition.X.Offset + delta.X, 0, math.max(0, size.X - 44)),
                math.clamp(buttonPosition.Y.Offset + delta.Y, 0, math.max(0, size.Y - 44)))
        end
    end)
    Window:_Connect(UserInputService.InputEnded, function(input)
        if input == buttonInput then buttonInput = nil end
    end)
    Window.HideButton.Activated:Connect(function()
        if not buttonMoved then Window:SetVisible(not main.Visible) end
    end)

    -- Notifikasi
    local notiHolder = make("Frame", {
        Name = "Notifications", AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -5, 1, -5), Size = UDim2.new(0, 350, 1, -10),
        BackgroundTransparency = 1,
    }, gui)
    make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 5),
    }, notiHolder)
    Window._notiHolder = notiHolder

    return Window
end

function Library:SetToggleKey(key) self.ToggleKey = key end
function Library:Destroy() self.Gui:Destroy() end
function Library:SetVisible(visible) self.Main.Visible = not not visible end
function Library:SetHideButton(visible) self.HideButton.Visible = not not visible end

function Library:SetLogo(image)
    local ok, resolved = pcall(logoImage, image)
    if not ok then return false, resolved end
    self.Logo, self._logo.Image = tostring(image), resolved
    self.HideButton.Image = resolved
    return true
end

function Library:_Filter()
    local query = self.Search.Text:lower():match('^%s*(.-)%s*$')
    local searching, matches = query ~= '', 0
    self._searchResults.Visible = searching
    for _, page in ipairs(self.Pages) do
        page._frame.Visible = not searching and self._selectedPage == page
        for _, section in ipairs(page.Sections) do
            local count = 0
            for _, row in ipairs(section._controls) do
                local options = row.Options
                local caption = page.Name .. ' ' .. page.Title .. ' ' .. section.Name .. ' '
                    .. tostring(options.Title or '') .. ' ' .. tostring(options.Desc or '')
                    row.Holder.Visible = searching and caption:lower():find(query, 1, true) ~= nil or not searching and not section._collapsed
                if row.Holder.Visible then count = count + 1 end
            end
            section._frame.Parent = searching and self._searchResults or page._list
            section._frame.Visible = not searching or count > 0
            section._heading.Text = searching and (page.Name .. ' / ' .. section.Name) or section.Name
            matches = matches + count
        end
    end
    self._emptySearch.Visible = searching and matches == 0
end

function Library:ExportConfig()
    local values = {}
    for _, control in ipairs(self.Controls) do
        local value = control:Get()
        values[control.Flag] = { Kind = control.Kind, Value = control.Kind == 'Keybind' and value.Name or value }
    end
    return HttpService:JSONEncode({ Version = 1, Values = values, Logo = self.Logo, ToggleKey = self.ToggleKey.Name,
        HideButton = self.HideButton.Visible })
end

function Library:ImportConfig(json)
    if type(json) ~= 'string' then return false, 'Invalid config' end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok or type(data) ~= 'table' or data.Version ~= 1 or type(data.Values) ~= 'table' then
        return false, 'Invalid config format'
    end
    local key = keycode(data.ToggleKey)
    if not key or key == Enum.KeyCode.Unknown then return false, 'Invalid menu key' end
    local validLogo, resolvedLogo = pcall(logoImage, data.Logo)
    if not validLogo then return false, resolvedLogo end
    if type(data.HideButton) ~= 'boolean' then return false, 'Invalid Hide Button setting' end
    local changes = {}
    for _, control in ipairs(self.Controls) do
        local item = data.Values[control.Flag]
        if item ~= nil then
            if type(item) ~= 'table' or item.Kind ~= control.Kind then return false, 'Invalid type: ' .. control.Flag end
            local value = item.Value
            if control.Kind == 'Keybind' then value = keycode(value) end
            if not control.Validate(value) then return false, 'Invalid value: ' .. control.Flag end
            table.insert(changes, { Control = control, Value = value, Before = control:Get() })
        end
    end
    self.Logo, self._logo.Image, self.ToggleKey = data.Logo, resolvedLogo, key
    self.HideButton.Image, self.HideButton.Visible = resolvedLogo, data.HideButton
    for _, change in ipairs(changes) do change.Control:Set(change.Value, true) end
    for _, change in ipairs(changes) do
        local changed = change.Before ~= change.Value
        if type(change.Value) == 'table' then
            changed = false
            for name, value in pairs(change.Before) do
                if value ~= change.Value[name] then changed = true end
            end
            for name, value in pairs(change.Value) do
                if value ~= change.Before[name] then changed = true end
            end
        end
        if changed and change.Control.Kind == 'MultiDropdown' then
            local names = {}
            for name in pairs(change.Before) do names[name] = true end
            for name in pairs(change.Value) do names[name] = true end
            for name in pairs(names) do
                if not not change.Before[name] ~= not not change.Value[name] then
                    safe(change.Control.Callback, name, not not change.Value[name])
                end
            end
        elseif changed and change.Control.Kind ~= 'Keybind' then
            safe(change.Control.Callback, change.Control:Get())
        end
    end
    return true
end

local function configPath(window, name)
    assert(type(name) == 'string' and #name > 0 and #name <= 64 and name:match('^[%w_%- ]+$')
        and name:find('%S'), 'Invalid config name')
    local folder = window.ConfigFolder
    assert(type(folder) == 'string' and folder:match('^[%w_/%-]+$') and not folder:match('^/')
        and not folder:match('/$') and not folder:find('//', 1, true), 'Invalid config folder')
    return folder .. '/' .. name .. '.json'
end

function Library:SaveConfig(name)
    local ok, err = pcall(function()
        local path = configPath(self, name)
        assert(type(writefile) == 'function' and type(makefolder) == 'function' and type(isfolder) == 'function', 'Config file API unavailable')
        local folder = ''
        for part in self.ConfigFolder:gmatch('[^/]+') do
            folder = folder == '' and part or folder .. '/' .. part
            if not isfolder(folder) then makefolder(folder) end
        end
        writefile(path, self:ExportConfig())
    end)
    if not ok then return false, tostring(err) end
    return true
end

function Library:LoadConfig(name)
    local ok, json = pcall(function()
        local path = configPath(self, name)
        assert(type(readfile) == 'function', 'Config file API unavailable')
        return readfile(path)
    end)
    if not ok then return false, tostring(json) end
    return self:ImportConfig(json)
end

function Library:ListConfigs()
    local ok, result = pcall(function()
        configPath(self, 'check')
        assert(type(listfiles) == 'function' and type(isfolder) == 'function', 'Config file API unavailable')
        local names = {}
        if not isfolder(self.ConfigFolder) then return names end
        for _, path in ipairs(listfiles(self.ConfigFolder)) do
            local name = path:gsub('\\', '/'):match('([^/]+)%.json$')
            if name and #name <= 64 and name:find('%S') and name:match('^[%w_%- ]+$') then table.insert(names, name) end
        end
        table.sort(names)
        return names
    end)
    if not ok then return nil, tostring(result) end
    return result
end

function Library:Notify(opts)
    opts = opts or {}
    local frame = make("Frame", {
        BackgroundTransparency = 1, ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    }, self._notiHolder)
    local box = make("Frame", {
        Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(1, 0, 1, 6),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.BG3,
    }, frame)
    corner(box)
    local head = make("Frame", { Position = UDim2.new(0, 0, 0, 5), Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1 }, box)
    local logo = make("ImageLabel", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 25, 0, 25),
        BackgroundTransparency = 1, Image = self._logo.Image, ScaleType = Enum.ScaleType.Fit }, head)
    corner(logo, 99)
    text(head, {
        Position = UDim2.new(0, 40, 0, 0), Size = UDim2.new(1, -70, 1, 0),
        Font = Enum.Font.GothamBold, RichText = true,
        Text = ('<font color="%s">%s</font>'):format(rgbTag(Theme.Accent), tostring(opts.Title or "Notification")),
    })
    if opts.Desc then
        text(box, {
            Position = UDim2.new(0, 10, 0, 35), Size = UDim2.new(1, -15, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, RichText = true,
            Font = Enum.Font.GothamBold, Text = tostring(opts.Desc),
        })
    end
    local close = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4),
        Size = UDim2.new(0, 22, 0, 22), BackgroundTransparency = 1, Text = "" }, box)
    make("ImageLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Image = ICON.Close, ImageRectOffset = Vector2.new(284, 4), ImageRectSize = Vector2.new(24, 24),
        ImageColor3 = Color3.new(1, 1, 1) }, close)

    tween(box, { Position = UDim2.new(0, 0, 0, 0) })
    local gone = false
    local function dismiss()
        if gone then return end
        gone = true
        tween(box, { Position = UDim2.new(1, 0, 0, 0) })
        task.wait(Theme.Tween)
        frame:Destroy()
    end
    close.MouseButton1Click:Connect(dismiss)
    task.delay(opts.ShowTime or 5, dismiss)
end

-- ====================================================================
-- Page
-- ====================================================================
function Library:CreatePage(opts)
    opts = opts or {}
    local name  = tostring(opts.Name or "Page")
    local title = tostring(opts.Title or name)

    local Page = { _window = self, Name = name, Title = title, Sections = {} }
    self._order = self._order + 1

    -- Tombol di sidebar
    local btnHolder = make("Frame", { Name = name .. "_Control", Size = UDim2.new(1, -10, 0, 25),
        BackgroundTransparency = 1, LayoutOrder = self._order }, self._sideList)
    local line = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.new(0, 14, 1, 0), BackgroundTransparency = 1 }, btnHolder)
    local indicator = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -10, 0, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
    }, line)
    corner(indicator)
    text(btnHolder, { Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -20, 1, 0),
        Font = Enum.Font.GothamBold, Text = name })
    local btn = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, btnHolder)

    -- Frame halaman
    local frame = make("Frame", {
        Name = "Page_" .. name, Size = UDim2.new(1, 0, 1, 0), Visible = false,
        BackgroundColor3 = Theme.BG1,
    }, self._pages)
    corner(frame)
    text(frame, { Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, 0, 0, 25),
        Font = Enum.Font.GothamBold, TextSize = 13, Text = title })
    local list = make("ScrollingFrame", {
        Position = UDim2.new(0, 5, 0, 30), Size = UDim2.new(1, -10, 1, -30),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, frame)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, list)

    Page._list, Page._frame, Page._indicator = list, frame, indicator

    local window = self
    function Page:Select()
        window._selectedPage = Page
        window.Search.Text = ''
        for _, p in ipairs(window.Pages) do
            p._frame.Visible = (p == Page)
            tween(p._indicator, {
                Size = (p == Page) and UDim2.new(1, -10, 1, -10) or UDim2.new(1, -10, 0, 0),
            })
        end
    end
    btn.MouseButton1Click:Connect(function() Page:Select() end)

    table.insert(self.Pages, Page)
    if #self.Pages == 1 then Page:Select() end

    function Page:CreateSection(sectionName, sectionOptions)
        sectionName = tostring(sectionName)
        local startCollapsed = sectionOptions == true
            or type(sectionOptions) == 'table' and sectionOptions.Collapsed == true
        local sec = { _order = 0, Name = sectionName, _controls = {}, _window = window, _collapsed = startCollapsed }

        local box = make("Frame", {
            Name = sectionName .. "_Section", Size = UDim2.new(1, -5, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.BG3, LayoutOrder = #Page.Sections + 1,
        }, list)
        corner(box)
        local topsec = make("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
            LayoutOrder = 0 }, box)
        sec._heading = text(topsec, { Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Accent, Text = sectionName })
        local underline = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
            Size = UDim2.new(1, -10, 0, 1), BorderSizePixel = 0, BackgroundColor3 = Theme.Accent }, topsec)
        make("UIGradient", { Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.51, 0.02), NumberSequenceKeypoint.new(1, 1) }) }, underline)

        make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, box)
        make('UIPadding', { PaddingBottom = UDim.new(0, 5) }, box)
        sec._frame = box
        table.insert(Page.Sections, sec)
        
        -- Click the heading to collapse or expand this section.
        local arrow = make("ImageLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, -1),
            Size = UDim2.new(0, 12, 0, 12), BackgroundTransparency = 1, Image = ICON.Arrow,
            ImageColor3 = Theme.Text, Rotation = sec._collapsed and 0 or 90 }, topsec)
        local headingButton = make("TextButton", { Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Text = "" }, topsec)
        function sec:SetCollapsed(value)
            value = not not value
            if sec._collapsed == value then return end
            sec._collapsed = value
            tween(arrow, { Rotation = value and 0 or 90 }, 0.15)
            window:_Filter()
            if window.SectionChanged then safe(window.SectionChanged) end
        end
        function sec:IsCollapsed() return sec._collapsed end
        headingButton.MouseButton1Click:Connect(function() sec:SetCollapsed(not sec._collapsed) end)
        local sectionFlag = 'UI_Section_' .. name .. '_' .. sectionName
        if not window.Flags[sectionFlag] then
            register(window, { Flag = sectionFlag }, {
                Get = function() return sec._collapsed end,
                Set = function(_, value) sec:SetCollapsed(value) end,
            }, 'Toggle', function(value) return type(value) == 'boolean' end, nil)
        end
        -- ---------------------------------------------------- Toggle
        function sec:CreateToggle(o, callback)
            o = o or {}
            local hasDesc = o.Desc ~= nil
            local _, bg = elementHolder(sec, hasDesc and 34 or 24, "Toggle", o)
            text(bg, { Position = UDim2.new(0, 10, 0, hasDesc and 3 or 0),
                Size = UDim2.new(1, -40, 0, hasDesc and 16 or 24), Text = tostring(o.Title), RichText = true })
            if hasDesc then
                text(bg, { Position = UDim2.new(0, 10, 0, 18), Size = UDim2.new(1, -40, 0, 14),
                    Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Theme.DescText, Text = o.Desc, RichText = true })
            end
            local cbox = make("ImageLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0),
                Size = UDim2.new(0, 19, 0, 19), BackgroundTransparency = 1,
                Image = ICON.Checkbox, ImageColor3 = Theme.Accent }, bg)
            local check = make("ImageLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
                Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1,
                Image = ICON.Check, ImageColor3 = Theme.Text }, cbox)
            local click = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, bg)

            local state = o.Default and true or false
            local obj = {}
            local function apply(v, fire)
                state = v
                tween(check, {
                    Size = v and UDim2.new(1, -4, 1, -4) or UDim2.new(0, 0, 0, 0),
                    Position = v and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 0, 1, 0),
                    AnchorPoint = v and Vector2.new(0.5, 0.5) or Vector2.new(0, 1),
                })
                if fire then safe(callback, v) end
            end
            click.MouseButton1Click:Connect(function() apply(not state, true) end)
            apply(state, state) -- jalankan callback kalau Default = true

            function obj:Set(v, silent) apply(not not v, not silent) end
            function obj:Get() return state end
            return register(window, o, obj, 'Toggle', function(v) return type(v) == 'boolean' end, callback)
        end

        -- ---------------------------------------------------- Button
        function sec:CreateButton(o, callback)
            o = o or {}
            sec._order = sec._order + 1
            local holder = make("Frame", { Name = "Button", Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1, LayoutOrder = sec._order }, box)
            trackRow(sec, holder, o)
            local bg = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, -10, 1, 0), BackgroundColor3 = Theme.BG2 }, holder)
            corner(bg)
            text(bg, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -10, 1, 0), Text = tostring(o.Title) })
            local click = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, bg)
            click.MouseButton1Down:Connect(function() tween(bg, { BackgroundColor3 = Theme.BG1 }, 0.08) end)
            click.MouseButton1Up:Connect(function() tween(bg, { BackgroundColor3 = Theme.BG2 }, 0.15) end)
            click.MouseButton1Click:Connect(function() safe(callback) end)
        end

        -- ---------------------------------------------------- Label
        function sec:CreateLabel(o)
            o = o or {}
            sec._order = sec._order + 1
            local holder = make("Frame", { Name = "Label", Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                LayoutOrder = sec._order }, box)
            local row = trackRow(sec, holder, o)
            local bg = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
                Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Label }, holder)
            corner(bg)
            make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
                PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, bg)
            local lbl = text(bg, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Text = tostring(o.Title) })
            return {
                SetText  = function(_, t)
                    lbl.Text = t
                    row.Options = { Title = t, Desc = o.Desc }
                    window:_Filter()
                end,
                SetColor = function(_, c) lbl.TextColor3 = c end,
            }
        end

        -- ---------------------------------------------------- Slider
        function sec:CreateSlider(o, callback)
            o = o or {}
            local min, max = tonumber(o.Min) or 0, tonumber(o.Max) or 100
            local precise = o.Precise
            local _, bg = elementHolder(sec, 38, "Slider", o)
            text(bg, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -90, 0, 24), Text = tostring(o.Title) })

            local valBg = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5),
                Size = UDim2.new(0, 64, 0, 19), BackgroundColor3 = Theme.BG2 }, bg)
            corner(valBg)
            local valBox = make("TextBox", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
                Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.Text, Text = "",
                ClearTextOnFocus = false }, valBg)

            local bar = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -6),
                Size = UDim2.new(1, -20, 0, 4), BackgroundColor3 = Theme.BG2 }, bg)
            corner(bar, 99)
            local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0,
                BackgroundColor3 = Theme.SliderLine }, bar)
            corner(fill, 99)
            local hit = make("TextButton", { Size = UDim2.new(1, 0, 1, 12), Position = UDim2.new(0, 0, 0, -6),
                BackgroundTransparency = 1, Text = "" }, bar)

            local value = min
            local function set(v, fire)
                v = math.clamp(tonumber(v) or min, min, max)
                if precise then v = math.floor(v * 10 + 0.5) / 10 else v = math.floor(v + 0.5) end
                value = v
                valBox.Text = tostring(v)
                fill.Size = UDim2.new((v - min) / math.max(max - min, 1e-9), 0, 1, 0)
                if fire then safe(callback, v) end
            end
            local function fromMouse(x)
                local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                set(min + (max - min) * a, true)
            end

            local dragging, dragInput = false, nil
            hit.MouseEnter:Connect(function() tween(fill, { BackgroundColor3 = Theme.SliderHi }, 0.5) end)
            hit.MouseLeave:Connect(function()
                if not dragging then tween(fill, { BackgroundColor3 = Theme.SliderLine }, 0.5) end
            end)
            hit.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragInput = i
                    fromMouse(i.Position.X)
                end
            end)
            window:_Connect(UserInputService.InputChanged, function(i)
                if dragging and (i == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
                    and i.UserInputType == Enum.UserInputType.MouseMovement)) then
                    fromMouse(i.Position.X)
                end
            end)
            window:_Connect(UserInputService.InputEnded, function(i)
                if dragging and i == dragInput then
                    dragging = false
                    dragInput = nil
                    tween(fill, { BackgroundColor3 = Theme.SliderLine }, 0.5)
                end
            end)
            valBox.FocusLost:Connect(function() set(valBox.Text, true) end)

            set(o.Default or min, o.Default ~= nil)
            return register(window, o, {
                Set = function(_, v, silent) set(v, not silent) end,
                Get = function() return value end,
            }, 'Slider', function(v) return finite(v) and v >= min and v <= max end, callback)
        end

        -- ---------------------------------------------------- Textbox
        function sec:CreateBox(o, callback)
            o = o or {}
            local _, bg = elementHolder(sec, 50, "Box", o)
            text(bg, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -10, 0.5, 0), Text = tostring(o.Title) })
            local inputBg = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0, 34),
                Size = UDim2.new(1, -10, 0, 22), BackgroundColor3 = Theme.BG2, ClipsDescendants = true }, bg)
            corner(inputBg)
            local tb = make("TextBox", { Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -5, 1, 0),
                BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Text,
                PlaceholderColor3 = Theme.Placeholder, PlaceholderText = tostring(o.Placeholder or ""),
                Text = "", ClearTextOnFocus = false }, inputBg)
            local lineBar = make("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
                BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0 }, inputBg)
            tb.Focused:Connect(function() tween(lineBar, { BackgroundTransparency = 0 }, 0.5) end)
            tb.FocusLost:Connect(function()
                tween(lineBar, { BackgroundTransparency = 1 }, 0.5)
                if o.Number and not tonumber(tb.Text) then
                    tb.Text = ""
                    return
                end
                if tb.Text ~= "" then safe(callback, tb.Text) end
            end)
            if o.Default then tb.Text = tostring(o.Default); safe(callback, tb.Text) end
            return register(window, o, {
                Set = function(_, v, silent)
                    tb.Text = tostring(v)
                    if not silent then safe(callback, tb.Text) end
                end,
                Get = function() return tb.Text end,
            }, 'Box', function(v) return type(v) == 'string' and (not o.Number or finite(tonumber(v))) end, callback)
        end

        -- ---------------------------------------------------- Dropdown (single / multi)
        function sec:CreateDropdown(o, callback)
            o = o or {}
            local dtitle = tostring(o.Title)
            local items = o.List or {}
            local multi = o.Multi
            sec._order = sec._order + 1
            local holder = make("Frame", { Name = "Dropdown", Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1, LayoutOrder = sec._order }, box)
            trackRow(sec, holder, o)
            local bg = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(1, -10, 1, 0), BackgroundColor3 = Theme.BG1, ClipsDescendants = true }, holder)
            corner(bg)
            local head = make("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.BG2 }, bg)
            corner(head)
            local lbl = text(head, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -40, 1, 0),
                ClipsDescendants = true, Text = dtitle .. ": " })
            local arrow = make("ImageLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.new(0, 12, 0, 12), BackgroundTransparency = 1, Image = ICON.Arrow,
                ImageColor3 = Theme.Text }, head)
            local hbtn = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, head)

            local scroll = make("ScrollingFrame", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 1, -30),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
                CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, bg)
            make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
            make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, scroll)

            local selected = multi and {} or nil
            local open = false
            local resizeToken = 0
            scroll.Visible = false
            local function resize()
                resizeToken = resizeToken + 1
                local token = resizeToken
                local height = open and (30 + math.min(#items, 6) * 22) or 24
                if open then scroll.Visible = true end
                local animation = tween(holder, { Size = UDim2.new(1, 0, 0, height) }, 0.15)
                animation.Completed:Connect(function()
                    -- Snap to the final state so an interrupted tween cannot leave rows peeking out.
                    if token ~= resizeToken then return end
                    holder.Size = UDim2.new(1, 0, 0, height)
                    scroll.Visible = open
                end)
            end

            local function refreshLabel()
                if multi then
                    local t = {}
                    for _, n in ipairs(items) do if selected[n] then table.insert(t, n) end end
                    lbl.Text = dtitle .. ": " .. table.concat(t, ", ")
                else
                    lbl.Text = dtitle .. ": " .. tostring(selected or "")
                end
            end

            local rows = {}
            local function build()
                for _, r in ipairs(rows) do r.row:Destroy() end
                rows = {}
                for i, name in ipairs(items) do
                    local row = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
                        LayoutOrder = i }, scroll)
                    local dot = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0),
                        Size = UDim2.new(0, 4, 1, -10), BorderSizePixel = 0,
                        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1 }, row)
                    corner(dot)
                    text(row, { Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -20, 1, 0),
                        Font = Enum.Font.GothamBold, Text = tostring(name) })
                    local b = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, row)
                    local function mark()
                        local on = multi and selected[name] or (not multi and selected == name)
                        dot.BackgroundTransparency = on and 0 or 1
                    end
                    mark()
                    b.MouseButton1Click:Connect(function()
                        if multi then
                            selected[name] = not selected[name]
                            safe(callback, name, selected[name])
                        else
                            selected = name
                            for _, r in ipairs(rows) do r.mark() end
                            safe(callback, name)
                        end
                        mark(); refreshLabel()
                    end)
                    table.insert(rows, { row = row, mark = mark })
                end
            end
            build()

            if multi then
                if type(o.Default) == "table" then
                    for _, n in ipairs(o.Default) do selected[n] = true end
                    build()
                end
            elseif o.Default ~= nil then
                selected = tostring(o.Default)
                build()
                safe(callback, selected)
            end
            refreshLabel()

            hbtn.MouseButton1Click:Connect(function()
                open = not open
                resize()
                tween(arrow, { Rotation = open and 90 or 0 }, 0.15)
            end)

            local function valid(v)
                if not multi then return v == nil or table.find(items, v) ~= nil end
                if type(v) ~= 'table' then return false end
                for name, enabled in pairs(v) do
                    if not table.find(items, name) or type(enabled) ~= 'boolean' then return false end
                end
                return true
            end
            return register(window, o, {
                Set = function(_, v, silent)
                    assert(valid(v), 'Invalid dropdown selection')
                    local before = selected
                    selected = multi and table.clone(v) or v
                    for _, row in ipairs(rows) do row.mark() end
                    refreshLabel()
                    if not silent then
                        if multi then
                            for _, name in ipairs(items) do
                                if not not before[name] ~= not not selected[name] then
                                    safe(callback, name, not not selected[name])
                                end
                            end
                        else safe(callback, selected) end
                    end
                end,
                Refresh = function(_, newList)
                    items = newList or {}
                    selected = multi and {} or nil
                    build(); refreshLabel()
                    resize()
                end,
                Get = function() return multi and table.clone(selected) or selected end,
            }, multi and 'MultiDropdown' or 'Dropdown', valid, callback)
        end

        -- ---------------------------------------------------- Keybind
        function sec:CreateKeybind(o, callback)
            o = o or {}
            local _, bg = elementHolder(sec, 28, "Keybind", o)
            text(bg, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -170, 1, 0), Text = tostring(o.Title) })
            local kb = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0),
                Size = UDim2.new(0, 100, 0, 22), BackgroundColor3 = Theme.BG2 }, bg)
            corner(kb)
            local key = o.Default or Enum.KeyCode.E
            local btn = make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
                Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, Text = key.Name }, kb)
            local listening = false
            btn.MouseButton1Click:Connect(function()
                if listening then return end
                listening = true
                btn.Text = "..."
                local c; c = window:_Connect(UserInputService.InputBegan, function(i)
                    if i.KeyCode ~= Enum.KeyCode.Unknown then
                        key = i.KeyCode
                        btn.Text = key.Name
                        task.defer(function() listening = false end)
                        c:Disconnect()
                    end
                end)
            end)
            window:_Connect(UserInputService.InputBegan, function(i, gp)
                if not gp and not listening and not UserInputService:GetFocusedTextBox() and i.KeyCode == key then safe(callback, key) end
            end)
            return register(window, o, { Get = function() return key end,
                Set = function(_, k) key = k; btn.Text = k.Name end,
            }, 'Keybind', function(v) return typeof(v) == 'EnumItem' and v.EnumType == Enum.KeyCode and v ~= Enum.KeyCode.Unknown end, callback)
        end

        return sec
    end

    return Page
end

return Library
