BQBiss = BQBiss or {}
local BQ = BQBiss

BQ.UI = BQ.UI or {}
local UI = BQ.UI

local ROW_COUNT = 20
local selectedName = nil
local pageStart = 1
local minimapButton = nil
local debugFrame = nil
local scrollBar = nil
local updatingScrollBar = false
local dragPlayerName = nil
local dragSourceIndex = nil

local function SetBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetText(text)
    return button
end

local function CreateLabel(parent, text, size)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    if size then
        label:SetFont("Fonts\\FRIZQT__.TTF", size)
    end
    return label
end

local function GetSelectedPlayer()
    if not selectedName then
        return nil
    end
    return BQ:FindPlayer(selectedName)
end

local function SelectPlayer(name)
    selectedName = name
    UI:Refresh()
end

local function ClampPage()
    local count = #(BQ:GetPlayers())
    local maxStart = math.max(1, count - ROW_COUNT + 1)
    if pageStart > maxStart then
        pageStart = maxStart
    end
    if pageStart < 1 then
        pageStart = 1
    end
end

local function GetMaxPageStart()
    local count = #(BQ:GetPlayers())
    return math.max(1, count - ROW_COUNT + 1)
end

local function SetPageStart(value)
    local maxStart = GetMaxPageStart()
    value = tonumber(value) or 1
    if value < 1 then
        value = 1
    elseif value > maxStart then
        value = maxStart
    end
    pageStart = value
    UI:Refresh()
end

local function UpdateScrollBar()
    if not scrollBar then
        return
    end
    local maxStart = GetMaxPageStart()
    if maxStart <= 1 then
        scrollBar:Hide()
        return
    end
    updatingScrollBar = true
    scrollBar:Show()
    scrollBar:SetMinMaxValues(1, maxStart)
    scrollBar:SetValue(pageStart)
    updatingScrollBar = false
end

local function StatusText(status)
    local color = BQ.STATUS_COLORS[status] or "|cffffffff"
    return color .. status .. "|r"
end

local function RoleText(role)
    role = role or BQ.ROLE_UNKNOWN
    local color = BQ.ROLE_COLORS[role] or "|cffbbbbbb"
    return color .. role .. "|r"
end

local function MetaText(player)
    local parts = {}
    if player.group then
        table.insert(parts, "G" .. tostring(player.group))
    end
    if player.classFile or player.class then
        table.insert(parts, player.classFile or player.class)
    end
    table.insert(parts, player.role or BQ.ROLE_UNKNOWN)
    return table.concat(parts, " ")
end

local function GetDebugName()
    if debugFrame and debugFrame.input then
        local value = debugFrame.input:GetText()
        if value and value ~= "" then
            return value
        end
    end
    return selectedName
end

local function GetRowUnderCursor()
    if not UI.rows then
        return nil
    end
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    for _, row in ipairs(UI.rows) do
        if row:IsShown() and row.playerIndex then
            local left = row:GetLeft()
            local right = row:GetRight()
            local top = row:GetTop()
            local bottom = row:GetBottom()
            if left and right and top and bottom and cursorX >= left and cursorX <= right and cursorY <= top and cursorY >= bottom then
                return row
            end
        end
    end
    return nil
end

local function ScrollBy(delta)
    SetPageStart(pageStart + delta)
end

local function UpdateMinimapButtonPosition()
    if not minimapButton then
        return
    end
    BQ:InitDB()
    local angle = BQ.db.minimap and BQ.db.minimap.angle or 225
    local radians = math.rad(angle)
    local radius = 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function UI:ShowMinimapButton()
    BQ:InitDB()
    BQ.db.minimap = BQ.db.minimap or { angle = 225, hide = false }
    BQ.db.minimap.hide = false
    if minimapButton then
        minimapButton:Show()
        UpdateMinimapButtonPosition()
    end
end

function UI:HideMinimapButton()
    BQ:InitDB()
    BQ.db.minimap = BQ.db.minimap or { angle = 225, hide = false }
    BQ.db.minimap.hide = true
    if minimapButton then
        minimapButton:Hide()
    end
end

function UI:CreateMinimapButton()
    if minimapButton then
        return
    end

    BQ:InitDB()
    BQ.db.minimap = BQ.db.minimap or { angle = 225, hide = false }

    local button = CreateFrame("Button", "BQBissMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_BloodBoil")
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            UI:HideMinimapButton()
            BQ:Print("Minimap-Icon ausgeblendet. Mit /bq minimap wieder anzeigen.")
        else
            UI:Toggle()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px = px / scale
            py = py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            BQ.db.minimap.angle = angle
            UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateMinimapButtonPosition()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("BQBiss")
        GameTooltip:AddLine("Linksklick: Fenster öffnen", 1, 1, 1)
        GameTooltip:AddLine("Ziehen: verschieben", 1, 1, 1)
        GameTooltip:AddLine("Rechtsklick: Icon ausblenden", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    minimapButton = button
    UpdateMinimapButtonPosition()
    if BQ.db.minimap.hide then
        button:Hide()
    end
end

function UI:Create()
    if self.frame then
        return
    end

    BQ:InitDB()

    local frame = CreateFrame("Frame", "BQBissFrame", UIParent)
    frame:SetWidth(620)
    frame:SetHeight(700)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            ScrollBy(-1)
        elseif delta < 0 then
            ScrollBy(1)
        end
    end)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    SetBackdrop(frame)
    self.frame = frame

    local title = CreateLabel(frame, "BQBiss - Blood Queen Bite Planner", 14)
    title:SetPoint("TOP", frame, "TOP", 0, -18)

    local close = CreateButton(frame, "X", 24, 22)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -16)
    close:SetScript("OnClick", function() frame:Hide() end)

    local input = CreateFrame("EditBox", "BQBissNameInput", frame, "InputBoxTemplate")
    input:SetWidth(180)
    input:SetHeight(24)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -48)
    input:SetScript("OnEnterPressed", function(self)
        local player = BQ:AddPlayer(self:GetText())
        if player then
            SelectPlayer(player.name)
            self:SetText("")
        end
        self:ClearFocus()
    end)
    self.input = input

    local add = CreateButton(frame, "Hinzufügen", 100, 24)
    add:SetPoint("LEFT", input, "RIGHT", 10, 0)
    add:SetScript("OnClick", function()
        local player = BQ:AddPlayer(input:GetText())
        if player then
            SelectPlayer(player.name)
            input:SetText("")
        end
        input:ClearFocus()
    end)

    local channelLabel = CreateLabel(frame, "Kanal:")
    channelLabel:SetPoint("LEFT", add, "RIGHT", 16, 0)

    local channel = CreateFrame("Frame", "BQBissChannelDropDown", frame, "UIDropDownMenuTemplate")
    channel:SetPoint("LEFT", channelLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(channel, 90)
    UIDropDownMenu_Initialize(channel, function()
        local channels = { "LOCAL", "RAID", "PARTY", "SAY" }
        for _, value in ipairs(channels) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = value
            info.value = value
            info.checked = BQ:GetAnnounceChannel() == value
            info.func = function()
                BQ:SetAnnounceChannel(value)
                UIDropDownMenu_SetSelectedValue(channel, value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(channel, BQ:GetAnnounceChannel())
    self.channel = channel

    local headerName = CreateLabel(frame, "Priorität")
    headerName:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, -88)
    local headerStatus = CreateLabel(frame, "Status")
    headerStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 220, -88)
    local headerMeta = CreateLabel(frame, "Gruppe Klasse Rolle")
    headerMeta:SetPoint("TOPLEFT", frame, "TOPLEFT", 290, -88)
    local headerTimer = CreateLabel(frame, "Timer")
    headerTimer:SetPoint("TOPLEFT", frame, "TOPLEFT", 430, -88)
    local headerNext = CreateLabel(frame, "Ziel")
    headerNext:SetPoint("TOPLEFT", frame, "TOPLEFT", 482, -88)

    local bar = CreateFrame("Slider", "BQBissScrollBar", frame)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 588, -108)
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 140)
    bar:SetWidth(16)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(1, 1)
    bar:SetValueStep(1)
    bar:SetValue(1)
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    if bar:GetThumbTexture() then
        bar:GetThumbTexture():SetWidth(16)
        bar:GetThumbTexture():SetHeight(16)
    end
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    bar:SetScript("OnValueChanged", function(self, value)
        if updatingScrollBar then
            return
        end
        value = math.floor((tonumber(value) or 1) + 0.5)
        if value ~= pageStart then
            pageStart = value
            UI:Refresh()
        end
    end)
    scrollBar = bar

    self.rows = {}
    for i = 1, ROW_COUNT do
        local row = CreateFrame("Button", nil, frame)
        row:SetWidth(555)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -108 - ((i - 1) * 22))
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:RegisterForDrag("LeftButton")
        row:EnableMouseWheel(true)

        row.indexText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.indexText:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.indexText:SetWidth(28)
        row.indexText:SetJustifyH("LEFT")

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.nameText:SetPoint("LEFT", row.indexText, "RIGHT", 4, 0)
        row.nameText:SetWidth(150)
        row.nameText:SetJustifyH("LEFT")

        row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.statusText:SetPoint("LEFT", row.nameText, "RIGHT", 10, 0)
        row.statusText:SetWidth(62)
        row.statusText:SetJustifyH("LEFT")

        row.metaText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.metaText:SetPoint("LEFT", row.statusText, "RIGHT", 8, 0)
        row.metaText:SetWidth(132)
        row.metaText:SetJustifyH("LEFT")

        row.timerText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.timerText:SetPoint("LEFT", row.metaText, "RIGHT", 8, 0)
        row.timerText:SetWidth(48)
        row.timerText:SetJustifyH("LEFT")

        row.nextText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nextText:SetPoint("LEFT", row.timerText, "RIGHT", 4, 0)
        row.nextText:SetWidth(112)
        row.nextText:SetJustifyH("LEFT")

        row:SetScript("OnClick", function(self)
            if self.playerName then
                SelectPlayer(self.playerName)
            end
        end)

        row:SetScript("OnDragStart", function(self)
            if self.playerName and self.playerIndex then
                dragPlayerName = self.playerName
                dragSourceIndex = self.playerIndex
                SelectPlayer(self.playerName)
            end
        end)

        row:SetScript("OnDragStop", function()
            if dragPlayerName then
                local targetRow = GetRowUnderCursor()
                if targetRow and targetRow.playerIndex then
                    if BQ:MovePlayerToIndex(dragPlayerName, targetRow.playerIndex) then
                        SelectPlayer(dragPlayerName)
                    end
                elseif dragSourceIndex then
                    UI:Refresh()
                end
            end
            dragPlayerName = nil
            dragSourceIndex = nil
        end)

        row:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then
                ScrollBy(-1)
            elseif delta < 0 then
                ScrollBy(1)
            end
        end)

        self.rows[i] = row
    end

    local up = CreateButton(frame, "Hoch", 70, 24)
    up:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 132)
    up:SetScript("OnClick", function()
        local player = GetSelectedPlayer()
        if player and BQ:MovePlayer(player.name, -1) then
            SelectPlayer(player.name)
        end
    end)

    local down = CreateButton(frame, "Runter", 70, 24)
    down:SetPoint("LEFT", up, "RIGHT", 6, 0)
    down:SetScript("OnClick", function()
        local player = GetSelectedPlayer()
        if player and BQ:MovePlayer(player.name, 1) then
            SelectPlayer(player.name)
        end
    end)

    local remove = CreateButton(frame, "Entfernen", 82, 24)
    remove:SetPoint("LEFT", down, "RIGHT", 6, 0)
    remove:SetScript("OnClick", function()
        if selectedName and BQ:RemovePlayer(selectedName) then
            selectedName = nil
        end
    end)

    local prev = CreateButton(frame, "<", 28, 24)
    prev:SetPoint("LEFT", remove, "RIGHT", 8, 0)
    prev:SetScript("OnClick", function()
        pageStart = pageStart - ROW_COUNT
        ClampPage()
        UI:Refresh()
    end)
    self.prevButton = prev

    local nextPage = CreateButton(frame, ">", 28, 24)
    nextPage:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    nextPage:SetScript("OnClick", function()
        pageStart = pageStart + ROW_COUNT
        ClampPage()
        UI:Refresh()
    end)
    self.nextPageButton = nextPage

    local prio = CreateButton(frame, "PRIO", 58, 24)
    prio:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 100)
    prio:SetScript("OnClick", function()
        if selectedName then BQ:SetStatus(selectedName, BQ.STATUS_PRIO) end
    end)

    local vampire = CreateButton(frame, "VAMP", 58, 24)
    vampire:SetPoint("LEFT", prio, "RIGHT", 4, 0)
    vampire:SetScript("OnClick", function()
        if selectedName then BQ:SetStatus(selectedName, BQ.STATUS_VAMPIRE) end
    end)

    local dead = CreateButton(frame, "DEAD", 58, 24)
    dead:SetPoint("LEFT", vampire, "RIGHT", 4, 0)
    dead:SetScript("OnClick", function()
        if selectedName then BQ:SetStatus(selectedName, BQ.STATUS_DEAD) end
    end)

    local mc = CreateButton(frame, "MC", 42, 24)
    mc:SetPoint("LEFT", dead, "RIGHT", 4, 0)
    mc:SetScript("OnClick", function()
        if selectedName then BQ:SetStatus(selectedName, BQ.STATUS_MC) end
    end)

    local debug = CreateButton(frame, "Debug", 58, 24)
    debug:SetPoint("LEFT", mc, "RIGHT", 12, 0)
    debug:SetScript("OnClick", function() UI:ToggleDebug() end)

    local dd = CreateButton(frame, "DD", 42, 24)
    dd:SetPoint("LEFT", debug, "RIGHT", 6, 0)
    dd:SetScript("OnClick", function()
        if selectedName then BQ:SetRole(selectedName, BQ.ROLE_DD) end
    end)

    local heal = CreateButton(frame, "HEAL", 52, 24)
    heal:SetPoint("LEFT", dd, "RIGHT", 4, 0)
    heal:SetScript("OnClick", function()
        if selectedName then BQ:SetRole(selectedName, BQ.ROLE_HEAL) end
    end)

    local tank = CreateButton(frame, "TANK", 52, 24)
    tank:SetPoint("LEFT", heal, "RIGHT", 4, 0)
    tank:SetScript("OnClick", function()
        if selectedName then BQ:SetRole(selectedName, BQ.ROLE_TANK) end
    end)

    local unknown = CreateButton(frame, "UNK", 46, 24)
    unknown:SetPoint("LEFT", tank, "RIGHT", 4, 0)
    unknown:SetScript("OnClick", function()
        if selectedName then BQ:SetRole(selectedName, BQ.ROLE_UNKNOWN) end
    end)

    local start = CreateButton(frame, "Pull-Test", 100, 24)
    start:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 24)
    start:SetScript("OnClick", function()
        BQ:PreparePullTest()
    end)

    local reset = CreateButton(frame, "Reset", 76, 24)
    reset:SetPoint("LEFT", start, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function() BQ:Reset() end)

    local auto = CreateButton(frame, "Auto AUS", 86, 24)
    auto:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    auto:SetScript("OnClick", function()
        BQ:SetAuto(not BQ.db.auto)
        BQ:Print("Auto-Erkennung: " .. (BQ.db.auto and "AN" or "AUS"))
    end)
    self.autoButton = auto

    local localOnly = CreateButton(frame, "Nur Lokal", 82, 24)
    localOnly:SetPoint("LEFT", auto, "RIGHT", 8, 0)
    localOnly:SetScript("OnClick", function()
        BQ:SetLocalOnly(not BQ:IsLocalOnly())
        BQ:Print("Testmodus: " .. (BQ:IsLocalOnly() and "nur lokal" or "Chatkanäle erlaubt"))
    end)
    self.localOnlyButton = localOnly

    local next = CreateButton(frame, "Nächste Ansage", 126, 24)
    next:SetPoint("LEFT", localOnly, "RIGHT", 8, 0)
    next:SetScript("OnClick", function() BQ:AnnounceNext() end)

    local import = CreateButton(frame, "Raid Import", 90, 24)
    import:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 506, 132)
    import:SetScript("OnClick", function() BQ:ImportRaidMembers() end)
    self.importButton = import

    local markers = CreateButton(frame, "Marker AN", 82, 24)
    markers:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 414, 132)
    markers:SetScript("OnClick", function()
        BQ:SetMarkersEnabled(not BQ.db.markersEnabled)
        BQ:Print("Raidmarker: " .. (BQ.db.markersEnabled and "AN" or "AUS"))
    end)
    self.markersButton = markers

    local selected = CreateLabel(frame, "Auswahl: -")
    selected:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 74)
    selected:SetWidth(190)
    selected:SetJustifyH("LEFT")
    self.selectedLabel = selected

    local vampires = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vampires:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 56)
    vampires:SetWidth(555)
    vampires:SetJustifyH("LEFT")
    vampires:SetText("Aktive Vampire: -")
    self.vampires = vampires

    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("LEFT", selected, "RIGHT", 12, 0)
    summary:SetWidth(360)
    summary:SetJustifyH("LEFT")
    summary:SetText("Biss: keine gültige Zuordnung")
    self.summary = summary
end

function UI:Refresh()
    if not self.frame then
        return
    end

    BQ:InitDB()
    local players = BQ:GetPlayers()
    ClampPage()
    local assignments = BQ:CalculateAssignments()
    local targetByBiter = {}
    for _, assignment in ipairs(assignments) do
        targetByBiter[assignment.biter] = assignment.target
    end

    local selectedExists = false
    for i = 1, ROW_COUNT do
        local row = self.rows[i]
        local playerIndex = pageStart + i - 1
        local player = players[playerIndex]
        if player then
            row.playerName = player.name
            row.playerIndex = playerIndex
            row.indexText:SetText(playerIndex .. ".")
            local prefix = player.name == dragPlayerName and "|cffffff00" or (player.name == selectedName and "|cff33ff99" or "")
            row.nameText:SetText(prefix .. player.name .. (prefix ~= "" and "|r" or ""))
            row.statusText:SetText(StatusText(player.status))
            row.metaText:SetText(MetaText(player))
            row.timerText:SetText(BQ:GetBiteTimerLabel(player.name))
            if targetByBiter[player.name] then
                row.nextText:SetText(targetByBiter[player.name])
            else
                row.nextText:SetText("")
            end
            row:Show()
            if player.name == selectedName then
                selectedExists = true
            end
        else
            row.playerName = nil
            row.playerIndex = nil
            row.indexText:SetText("")
            row.nameText:SetText("")
            row.statusText:SetText("")
            row.metaText:SetText("")
            row.timerText:SetText("")
            row.nextText:SetText("")
            row:Show()
        end
    end

    if selectedName and not selectedExists then
        selectedName = nil
    end

    local selectedPlayer = selectedName and BQ:FindPlayer(selectedName)
    self.selectedLabel:SetText("Auswahl: " .. (selectedName or "-") .. (selectedPlayer and (" (" .. RoleText(selectedPlayer.role) .. ")") or ""))
    local vampireNames = {}
    for _, player in ipairs(BQ:GetBiters()) do
        table.insert(vampireNames, player.name)
    end
    self.vampires:SetText("Aktive Vampire: " .. (#vampireNames > 0 and table.concat(vampireNames, ", ") or "-"))
    self.summary:SetText(BQ:GetNextMessage())
    self.autoButton:SetText(BQ.db.auto and "Auto AN" or "Auto AUS")
    if self.localOnlyButton then
        self.localOnlyButton:SetText(BQ:IsLocalOnly() and "Nur Lokal" or "Chat AN")
    end
    if self.markersButton then
        self.markersButton:SetText(BQ.db.markersEnabled and "Marker AN" or "Marker AUS")
    end
    if self.prevButton then
        self.prevButton:SetText(pageStart > 1 and "<" or "-")
    end
    if self.nextPageButton then
        self.nextPageButton:SetText((pageStart + ROW_COUNT <= #players) and ">" or "-")
    end
    if self.channel then
        UIDropDownMenu_SetSelectedValue(self.channel, BQ:GetAnnounceChannel())
    end
    UpdateScrollBar()
    self:RefreshDebug()
    if not self.frame.updateAttached then
        self.frame.updateAttached = true
        self.frame:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = (frame.elapsed or 0) + elapsed
            if frame.elapsed >= 0.5 then
                frame.elapsed = 0
                UI:Refresh()
            end
        end)
    end
end

function UI:Show()
    self:Create()
    self.frame:Show()
    self:Refresh()
end

function UI:Toggle()
    self:Create()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Show()
    end
end

function UI:CreateDebug()
    if debugFrame then
        return
    end

    local frame = CreateFrame("Frame", "BQBissDebugFrame", UIParent)
    frame:SetWidth(430)
    frame:SetHeight(410)
    frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    SetBackdrop(frame)
    debugFrame = frame

    local title = CreateLabel(frame, "BQBiss Debug", 13)
    title:SetPoint("TOP", frame, "TOP", 0, -18)

    local close = CreateButton(frame, "X", 24, 22)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -16)
    close:SetScript("OnClick", function() frame:Hide() end)

    local menu = CreateButton(frame, "BQ Menü", 76, 22)
    menu:SetPoint("RIGHT", close, "LEFT", -6, 0)
    menu:SetScript("OnClick", function()
        UI:Show()
    end)

    local input = CreateFrame("EditBox", "BQBissDebugNameInput", frame, "InputBoxTemplate")
    input:SetWidth(190)
    input:SetHeight(24)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -48)
    frame.input = input

    local useSelected = CreateButton(frame, "Auswahl", 76, 24)
    useSelected:SetPoint("LEFT", input, "RIGHT", 10, 0)
    useSelected:SetScript("OnClick", function()
        if selectedName then
            input:SetText(selectedName)
        end
    end)

    local essence = CreateButton(frame, "Essenz", 82, 24)
    essence:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -82)
    essence:SetScript("OnClick", function()
        local name = GetDebugName()
        if name then
            BQ:SimulateEssence(name)
        else
            BQ:Print("Debug: Kein Spieler ausgewählt.")
        end
    end)

    local thirst = CreateButton(frame, "Blutdurst", 92, 24)
    thirst:SetPoint("LEFT", essence, "RIGHT", 8, 0)
    thirst:SetScript("OnClick", function()
        local name = GetDebugName()
        if name then
            BQ:SimulateBloodthirst(name)
        else
            BQ:Print("Debug: Kein Spieler ausgewählt.")
        end
    end)

    local next = CreateButton(frame, "Nächste", 82, 24)
    next:SetPoint("LEFT", thirst, "RIGHT", 8, 0)
    next:SetScript("OnClick", function() BQ:AnnounceNext() end)

    local auto = CreateButton(frame, "Auto", 70, 24)
    auto:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -112)
    auto:SetScript("OnClick", function()
        BQ:SetAuto(not BQ.db.auto)
        BQ:DebugLog("Auto-Erkennung: " .. (BQ.db.auto and "AN" or "AUS"))
    end)
    frame.autoButton = auto

    local timer10 = CreateButton(frame, "Timer 10s", 82, 24)
    timer10:SetPoint("LEFT", auto, "RIGHT", 8, 0)
    timer10:SetScript("OnClick", function()
        local name = GetDebugName()
        if name then
            BQ:SetDebugBiteTimer(name, 10)
        else
            BQ:Print("Debug: Kein Spieler ausgewählt.")
        end
    end)

    local timer60 = CreateButton(frame, "Timer 60s", 82, 24)
    timer60:SetPoint("LEFT", timer10, "RIGHT", 8, 0)
    timer60:SetScript("OnClick", function()
        local name = GetDebugName()
        if name then
            BQ:SetDebugBiteTimer(name, 60)
        else
            BQ:Print("Debug: Kein Spieler ausgewählt.")
        end
    end)

    local clearTimer = CreateButton(frame, "Timer weg", 82, 24)
    clearTimer:SetPoint("LEFT", timer60, "RIGHT", 8, 0)
    clearTimer:SetScript("OnClick", function()
        local name = GetDebugName()
        if name then
            BQ:ClearDebugBiteTimer(name)
            BQ:DebugLog("Timer gelöscht: " .. tostring(name))
            BQ:Refresh()
        else
            BQ:Print("Debug: Kein Spieler ausgewählt.")
        end
    end)

    local done = CreateButton(frame, "Alle Bisse OK", 118, 24)
    done:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -142)
    done:SetScript("OnClick", function()
        local nextBiter = BQ:CompleteDebugBite(GetDebugName())
        if nextBiter and frame.input then
            frame.input:SetText(nextBiter)
        end
    end)

    local nextDue = CreateButton(frame, "Nächster fällig", 118, 24)
    nextDue:SetPoint("LEFT", done, "RIGHT", 8, 0)
    nextDue:SetScript("OnClick", function()
        local name = BQ:GetNextDebugBiter()
        if name and frame.input then
            frame.input:SetText(name)
        else
            BQ:Print("Debug: Kein Timer aktiv.")
        end
    end)

    local timersLabel = CreateLabel(frame, "Aktive Biss-Timer")
    timersLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -174)

    local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -194)
    timerText:SetWidth(374)
    timerText:SetHeight(90)
    timerText:SetJustifyH("LEFT")
    timerText:SetJustifyV("TOP")
    timerText:SetText("Timer: -")
    frame.timerText = timerText

    local logLabel = CreateLabel(frame, "Debug-Log")
    logLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -292)

    local log = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    log:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -312)
    log:SetWidth(374)
    log:SetHeight(76)
    log:SetJustifyH("LEFT")
    log:SetJustifyV("TOP")
    log:SetText("")
    frame.log = log

    frame:SetScript("OnUpdate", function(_, elapsed)
        frame.elapsed = (frame.elapsed or 0) + elapsed
        if frame.elapsed >= 0.2 then
            frame.elapsed = 0
            UI:RefreshDebug()
        end
    end)
end

function UI:RefreshDebug()
    if not debugFrame then
        return
    end
    if debugFrame.autoButton then
        debugFrame.autoButton:SetText(BQ.db and BQ.db.auto and "Auto AN" or "Auto AUS")
    end
    if debugFrame.timerText then
        debugFrame.timerText:SetText(BQ:GetDebugTimerText())
    end
    if debugFrame.log then
        debugFrame.log:SetText(table.concat(BQ.debugLines or {}, "\n"))
    end
end

function UI:ShowDebug()
    self:CreateDebug()
    debugFrame:Show()
    self:RefreshDebug()
end

function UI:ToggleDebug()
    self:CreateDebug()
    if debugFrame:IsShown() then
        debugFrame:Hide()
    else
        self:ShowDebug()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addon)
    if addon == "BQBiss" then
        BQ:InitDB()
        UI:CreateMinimapButton()
    end
end)

