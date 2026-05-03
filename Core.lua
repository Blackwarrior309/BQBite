BQBiss = BQBiss or {}
local BQ = BQBiss

BQ.STATUS_PRIO = "PRIO"
BQ.STATUS_VAMPIRE = "VAMPIRE"
BQ.STATUS_MC = "MC"
BQ.STATUS_DEAD = "DEAD"

BQ.STATUS_COLORS = {
    PRIO = "|cffffffff",
    VAMPIRE = "|cffff4040",
    MC = "|cffffcc00",
    DEAD = "|cff888888",
}

BQ.ROLE_DD = "DD"
BQ.ROLE_HEAL = "HEAL"
BQ.ROLE_TANK = "TANK"
BQ.ROLE_UNKNOWN = "UNKNOWN"

BQ.ROLE_COLORS = {
    DD = "|cff80ff80",
    HEAL = "|cff80c0ff",
    TANK = "|cffffcc00",
    UNKNOWN = "|cffbbbbbb",
}

BQ.MARKER_NAMES = {
    [1] = "Stern",
    [2] = "Kreis",
    [3] = "Raute",
    [4] = "Dreieck",
    [5] = "Mond",
    [6] = "Quadrat",
    [7] = "Kreuz",
    [8] = "Totenkopf",
}

BQ.SPELLS = {
    ESSENCE = {
        [70867] = true, [70879] = true, [71473] = true, [71525] = true,
        [71530] = true, [71531] = true, [71532] = true, [71533] = true,
    },
    BLOODTHIRST = {
        [70877] = true, [71474] = true,
    },
    MIND_CONTROL = {
        [70923] = true,
    },
    VAMPIRIC_BITE = {
        [71726] = true, [71727] = true, [71728] = true, [71729] = true,
        [71475] = true, [71476] = true, [71477] = true, [70946] = true,
    },
}

local defaults = {
    players = {},
    announceChannel = "LOCAL",
    localOnly = true,
    markersEnabled = true,
    markerTargets = {},
    started = false,
    auto = false,
    frame = nil,
    minimap = {
        angle = 225,
        hide = false,
    },
}

local function CopyDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                CopyDefaults(target[key], value)
            else
                target[key] = value
            end
        end
    end
end

local function Trim(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function NormalizeName(name)
    name = Trim(name)
    if name == "" then
        return nil
    end
    local base, realm = string.match(name, "^([^%-]+)%-(.+)$")
    if base and realm then
        return string.upper(string.sub(base, 1, 1)) .. string.lower(string.sub(base, 2)) .. "-" .. realm
    end
    return string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
end

function BQ:InitDB()
    BQBissDB = BQBissDB or {}
    CopyDefaults(BQBissDB, defaults)
    self.db = BQBissDB
    if self.db.localOnly == nil then
        self.db.localOnly = true
    end
    for _, player in ipairs(self.db.players) do
        self:EnsurePlayerDefaults(player)
    end
end

function BQ:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc41f3bBQBiss|r: " .. tostring(message))
    end
end

function BQ:GetPlayers()
    self:InitDB()
    return self.db.players
end

function BQ:EnsurePlayerDefaults(player)
    if not player then
        return
    end
    player.status = player.status or self.STATUS_PRIO
    player.role = player.role or self.ROLE_UNKNOWN
end

function BQ:FindPlayer(name)
    local normalized = NormalizeName(name)
    if not normalized then
        return nil
    end
    local players = self:GetPlayers()
    local lower = string.lower(normalized)
    for index, player in ipairs(players) do
        if string.lower(player.name) == lower then
            return player, index
        end
    end
    return nil
end

function BQ:AddPlayer(name)
    local normalized = NormalizeName(name)
    if not normalized then
        return nil
    end
    local player = self:FindPlayer(normalized)
    if player then
        return player
    end
    player = { name = normalized, status = self.STATUS_PRIO, role = self.ROLE_UNKNOWN }
    table.insert(self:GetPlayers(), player)
    self:Refresh()
    return player
end

function BQ:RemovePlayer(name)
    local _, index = self:FindPlayer(name)
    if index then
        table.remove(self:GetPlayers(), index)
        self:RefreshRaidMarkers()
        self:Refresh()
        return true
    end
    return false
end

function BQ:MovePlayer(name, delta)
    local players = self:GetPlayers()
    local _, index = self:FindPlayer(name)
    if not index then
        return false
    end
    local newIndex = index + delta
    if newIndex < 1 or newIndex > #players then
        return false
    end
    players[index], players[newIndex] = players[newIndex], players[index]
    self:RefreshRaidMarkers()
    self:Refresh()
    return true
end

function BQ:MovePlayerToIndex(name, targetIndex)
    local players = self:GetPlayers()
    local _, index = self:FindPlayer(name)
    targetIndex = tonumber(targetIndex)
    if not index or not targetIndex then
        return false
    end
    if targetIndex < 1 then
        targetIndex = 1
    elseif targetIndex > #players then
        targetIndex = #players
    end
    if index == targetIndex then
        return false
    end
    local player = table.remove(players, index)
    table.insert(players, targetIndex, player)
    self:RefreshRaidMarkers()
    self:Refresh()
    return true
end

function BQ:SetStatus(name, status)
    if status ~= self.STATUS_PRIO and status ~= self.STATUS_VAMPIRE and status ~= self.STATUS_MC and status ~= self.STATUS_DEAD then
        return false
    end
    local player = self:FindPlayer(name)
    if not player then
        player = self:AddPlayer(name)
    end
    if not player then
        return false
    end
    self:EnsurePlayerDefaults(player)
    player.status = status
    if status == self.STATUS_MC or status == self.STATUS_DEAD or status == self.STATUS_PRIO then
        self:ClearDebugBiteTimer(player.name)
    end
    self:RefreshRaidMarkers()
    self:Refresh()
    return true
end

function BQ:IsValidRole(role)
    role = string.upper(tostring(role or ""))
    return role == self.ROLE_DD or role == self.ROLE_HEAL or role == self.ROLE_TANK or role == self.ROLE_UNKNOWN
end

function BQ:SetRole(name, role)
    role = string.upper(tostring(role or self.ROLE_UNKNOWN))
    if not self:IsValidRole(role) then
        return false
    end
    local player = self:FindPlayer(name)
    if not player then
        return false
    end
    player.role = role
    if role == self.ROLE_HEAL or role == self.ROLE_TANK then
        self:SinkHealersAndTanks()
    end
    self:RefreshRaidMarkers()
    self:Refresh()
    return true
end

function BQ:SinkHealersAndTanks()
    local players = self:GetPlayers()
    local front = {}
    local healers = {}
    local tanks = {}
    for _, player in ipairs(players) do
        self:EnsurePlayerDefaults(player)
        if player.role == self.ROLE_TANK then
            table.insert(tanks, player)
        elseif player.role == self.ROLE_HEAL then
            table.insert(healers, player)
        else
            table.insert(front, player)
        end
    end
    for i = #players, 1, -1 do
        table.remove(players, i)
    end
    for _, player in ipairs(front) do
        table.insert(players, player)
    end
    for _, player in ipairs(healers) do
        table.insert(players, player)
    end
    for _, player in ipairs(tanks) do
        table.insert(players, player)
    end
end

function BQ:Reset()
    self:ClearRaidMarkers()
    for _, player in ipairs(self:GetPlayers()) do
        player.status = self.STATUS_PRIO
    end
    self.db.started = false
    self.debugTimers = nil
    self.debugTimer = nil
    self:Refresh()
end

function BQ:Start()
    self.db.started = true
    self.db.auto = true
    self:Refresh()
end

function BQ:StartAndAnnounce()
    self:Start()
    self:Print("Planung gestartet.")
    return self:AnnounceRound(true)
end

function BQ:PreparePullTest()
    self:InitDB()
    if self.SetLocalOnly then
        self:SetLocalOnly(true)
    else
        self.db.localOnly = true
        self.db.announceChannel = "LOCAL"
    end
    self.db.started = true
    self.db.auto = true
    self:RefreshRaidMarkers()
    self:Refresh()
    self:Print("Pull-Test bereit: nur lokal, Auto AN. Erste Essenz startet den Timer.")
    return true
end

function BQ:SetAuto(enabled)
    self.db.auto = enabled and true or false
    self:Refresh()
end

function BQ:GetBiters()
    local biters = {}
    for _, player in ipairs(self:GetPlayers()) do
        if player.status == self.STATUS_VAMPIRE then
            table.insert(biters, player)
        end
    end
    return biters
end

function BQ:GetTargets(limit)
    local targets = {}
    for _, player in ipairs(self:GetPlayers()) do
        if player.status == self.STATUS_PRIO then
            table.insert(targets, player)
            if limit and #targets >= limit then
                break
            end
        end
    end
    return targets
end

function BQ:CalculateAssignments()
    local biters = self:GetBiters()
    local targets = self:GetTargets(#biters)
    local assignments = {}
    for index, biter in ipairs(biters) do
        local target = targets[index]
        if target then
            table.insert(assignments, { biter = biter.name, target = target.name })
        end
    end
    return assignments
end

function BQ:GetPlayerGroup(name)
    local player = self:FindPlayer(name)
    if player and player.group then
        return player.group
    end
    return nil
end

function BQ:FormatPlayerForAnnounce(name, includeGroup)
    local player = self:FindPlayer(name)
    local text = player and player.name or tostring(name or "-")
    if includeGroup and player and player.group then
        text = text .. " G" .. tostring(player.group)
    end
    return text
end

function BQ:GetMarkerName(index)
    return self.MARKER_NAMES[index] or tostring(index)
end

function BQ:GetRoundSignature(assignments)
    if not assignments or #assignments == 0 then
        return "none"
    end
    local parts = {}
    for _, assignment in ipairs(assignments) do
        table.insert(parts, assignment.biter .. ">" .. assignment.target)
    end
    return table.concat(parts, "|")
end

function BQ:FormatRoundMessage(index, assignment)
    local marker = self:GetMarkerName(index)
    local biter = self:FormatPlayerForAnnounce(assignment.biter, false)
    local target = self:FormatPlayerForAnnounce(assignment.target, true)
    return marker .. ": " .. biter .. " -> " .. target
end

function BQ:GetRoundMessages(assignments)
    assignments = assignments or self:CalculateAssignments()
    local messages = {}
    if not assignments or #assignments == 0 then
        table.insert(messages, "Biss: keine gültige Zuordnung")
        return messages
    end
    for index, assignment in ipairs(assignments) do
        table.insert(messages, self:FormatRoundMessage(index, assignment))
    end
    return messages
end

function BQ:AnnounceRound(force)
    local assignments = self:CalculateAssignments()
    local signature = self:GetRoundSignature(assignments)
    if not force and self.roundAnnouncementSignature == signature then
        self:RefreshRaidMarkers()
        return table.concat(self:GetRoundMessages(assignments), "\n")
    end
    self.roundAnnouncementSignature = signature
    self:RefreshRaidMarkers()
    local messages = self:GetRoundMessages(assignments)
    self:AnnounceLines(messages)
    return table.concat(messages, "\n")
end

function BQ:GetAssignmentForBiter(name)
    local player = self:FindPlayer(name)
    if not player or player.status ~= self.STATUS_VAMPIRE then
        return nil
    end
    for _, assignment in ipairs(self:CalculateAssignments()) do
        if assignment.biter == player.name then
            return assignment
        end
    end
    return { biter = player.name, target = nil }
end

function BQ:GetMessageForBiter(name)
    local assignment = self:GetAssignmentForBiter(name)
    if not assignment then
        return "Biss: " .. tostring(name) .. " -> keine gültige Zuordnung"
    end
    if not assignment.target then
        return "Biss: " .. assignment.biter .. " -> kein gültiges Ziel"
    end
    return "Biss: " .. self:FormatPlayerForAnnounce(assignment.biter, false) .. " -> " .. self:FormatPlayerForAnnounce(assignment.target, true)
end

function BQ:FormatAssignments(assignments)
    local messages = self:GetRoundMessages(assignments)
    if not messages or #messages == 0 then
        return "Biss: keine gültige Zuordnung"
    end
    return table.concat(messages, " / ")
end

function BQ:GetNextMessages()
    return self:GetRoundMessages(self:CalculateAssignments())
end

function BQ:GetNextMessage()
    return self:FormatAssignments(self:CalculateAssignments())
end

function BQ:WrongBite(name)
    if not self:SetStatus(name, self.STATUS_VAMPIRE) then
        self:Print("Spieler nicht gefunden: " .. tostring(name))
        return false
    end
    self:Print("Falscher Biss korrigiert: " .. tostring(name) .. " ist jetzt VAMPIRE.")
    return true
end

function BQ:UpdateRaidPlayer(name, className, classFile, group, raidIndex)
    local player = self:FindPlayer(name)
    if not player then
        player = self:AddPlayer(name)
    end
    if not player then
        return nil
    end
    self:EnsurePlayerDefaults(player)
    player.class = className
    player.classFile = classFile
    player.group = tonumber(group)
    player.raidIndex = tonumber(raidIndex)
    return player
end

function BQ:ImportRaidMembers()
    self:InitDB()
    if not GetNumRaidMembers or not GetRaidRosterInfo or GetNumRaidMembers() == 0 then
        self:Print("Raid-Import: kein Raid gefunden.")
        return 0
    end

    local existing = {}
    for _, player in ipairs(self:GetPlayers()) do
        existing[string.lower(player.name)] = player
    end

    local imported = {}
    local count = GetNumRaidMembers()
    for index = 1, count do
        local name, _, subgroup, _, className, classFile = GetRaidRosterInfo(index)
        name = self:CleanPlayerName(name)
        if name then
            local player = self:UpdateRaidPlayer(name, className, classFile, subgroup, index)
            if player then
                imported[string.lower(player.name)] = true
            end
        end
    end

    local players = self:GetPlayers()
    for index = #players, 1, -1 do
        if not imported[string.lower(players[index].name)] then
            self:ClearDebugBiteTimer(players[index].name)
            table.remove(players, index)
        end
    end

    self:SinkHealersAndTanks()
    self:RefreshRaidMarkers()
    self:Refresh()
    self:Print("Raid-Import: " .. count .. " Spieler übernommen.")
    return count
end

function BQ:FindRaidUnit(name)
    local player = self:FindPlayer(name)
    local wanted = player and player.name or self:CleanPlayerName(name)
    if not wanted then
        return nil
    end
    local lower = string.lower(wanted)
    if UnitName and UnitName("player") and string.lower(self:CleanPlayerName(UnitName("player")) or "") == lower then
        return "player"
    end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for index = 1, GetNumRaidMembers() do
            local unit = "raid" .. index
            local unitName = UnitName and UnitName(unit)
            if unitName and string.lower(self:CleanPlayerName(unitName) or "") == lower then
                return unit
            end
        end
    end
    return nil
end

function BQ:SetMarkersEnabled(enabled)
    self:InitDB()
    self.db.markersEnabled = enabled and true or false
    if not self.db.markersEnabled then
        self:ClearRaidMarkers()
    else
        self:RefreshRaidMarkers()
    end
    self:Refresh()
end

function BQ:ClearRaidMarkers()
    self:InitDB()
    local markerTargets = self.db.markerTargets or {}
    for name, marker in pairs(markerTargets) do
        local unit = self:FindRaidUnit(name)
        if unit and GetRaidTargetIndex and SetRaidTarget and GetRaidTargetIndex(unit) == marker then
            SetRaidTarget(unit, 0)
        end
    end
    self.db.markerTargets = {}
end

function BQ:RefreshRaidMarkers()
    self:InitDB()
    if not self.db.markersEnabled then
        return
    end
    if not SetRaidTarget or not GetRaidTargetIndex then
        return
    end

    local assignments = self:CalculateAssignments()
    local current = {}
    for index, assignment in ipairs(assignments) do
        if index <= 8 and assignment.target then
            current[assignment.target] = index
        end
    end

    local markerTargets = self.db.markerTargets or {}
    for name, marker in pairs(markerTargets) do
        if current[name] ~= marker then
            local unit = self:FindRaidUnit(name)
            if unit and GetRaidTargetIndex(unit) == marker then
                SetRaidTarget(unit, 0)
            end
            markerTargets[name] = nil
        end
    end

    for name, marker in pairs(current) do
        local unit = self:FindRaidUnit(name)
        if unit then
            SetRaidTarget(unit, marker)
            markerTargets[name] = marker
        end
    end
    self.db.markerTargets = markerTargets
end

function BQ:Refresh()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

function BQ:DebugLog(message)
    self.debugLines = self.debugLines or {}
    table.insert(self.debugLines, 1, tostring(message))
    while #self.debugLines > 8 do
        table.remove(self.debugLines)
    end
    if self.UI and self.UI.RefreshDebug then
        self.UI:RefreshDebug()
    end
end

function BQ:SetDebugBiteTimer(name, seconds)
    name = self:CleanPlayerName(name)
    if not name then
        return false
    end
    local player = self:FindPlayer(name)
    if player then
        name = player.name
    end
    seconds = tonumber(seconds) or 60
    if seconds < 1 then
        seconds = 1
    end
    self.debugTimers = self.debugTimers or {}
    self.debugTimers[name] = (GetTime and GetTime() or 0) + seconds
    self.debugTimer = { biter = name, expires = self.debugTimers[name] }
    self:DebugLog("Timer: " .. name .. " muss in " .. seconds .. "s beißen.")
    self:Refresh()
    return true
end

function BQ:GetBiteTimerInfo(name)
    local player = self:FindPlayer(name)
    local key = player and player.name or self:CleanPlayerName(name)
    if not key or not self.debugTimers then
        return nil
    end
    local expires = self.debugTimers[key]
    if not expires then
        return nil
    end
    local now = GetTime and GetTime() or 0
    local remaining = math.ceil(expires - now)
    if remaining < 0 then
        remaining = 0
    end
    return remaining, expires
end

function BQ:GetBiteTimerLabel(name)
    local remaining = self:GetBiteTimerInfo(name)
    if not remaining then
        return ""
    end
    return remaining .. "s"
end

function BQ:GetBiteTimerLines(limit)
    if (not self.debugTimers or not next(self.debugTimers)) and self.debugTimer and self.debugTimer.biter then
        self.debugTimers = {}
        self.debugTimers[self.debugTimer.biter] = self.debugTimer.expires
    end
    local lines = {}
    local entries = {}
    if not self.debugTimers then
        return lines
    end
    for name, expires in pairs(self.debugTimers) do
        local player = self:FindPlayer(name)
        if player and player.status == self.STATUS_VAMPIRE then
            local remaining = self:GetBiteTimerInfo(player.name)
            table.insert(entries, { name = player.name, expires = expires, remaining = remaining or 0 })
        else
            self.debugTimers[name] = nil
        end
    end
    table.sort(entries, function(a, b)
        if a.expires == b.expires then
            return a.name < b.name
        end
        return a.expires < b.expires
    end)
    for index, entry in ipairs(entries) do
        if limit and index > limit then
            break
        end
        local assignment = self:GetAssignmentForBiter(entry.name)
        local target = assignment and assignment.target and assignment.target or "kein Ziel"
        table.insert(lines, entry.remaining .. "s  " .. entry.name .. " -> " .. target)
    end
    return lines
end

function BQ:ClearDebugBiteTimer(name)
    name = self:CleanPlayerName(name)
    if not name then
        return
    end
    local player = self:FindPlayer(name)
    if self.debugTimers then
        self.debugTimers[name] = nil
        if player then
            self.debugTimers[player.name] = nil
        end
    end
    if self.debugTimer and self.debugTimer.biter == name then
        self.debugTimer = nil
    end
end

function BQ:GetNextDebugBiter()
    local timers = self.debugTimers
    if not timers then
        return nil
    end
    local nextName, nextExpires
    for name, expires in pairs(timers) do
        local player = self:FindPlayer(name)
        if player and player.status == self.STATUS_VAMPIRE then
            if not nextExpires or expires < nextExpires then
                nextName = player.name
                nextExpires = expires
            end
        else
            timers[name] = nil
        end
    end
    return nextName, nextExpires
end

function BQ:GetDebugTimerText()
    if (not self.debugTimers or not next(self.debugTimers)) and self.debugTimer and self.debugTimer.biter then
        self.debugTimers = {}
        self.debugTimers[self.debugTimer.biter] = self.debugTimer.expires
    end
    local nextName, nextExpires = self:GetNextDebugBiter()
    if not nextName then
        return "Timer: -"
    end
    local now = GetTime and GetTime() or 0
    local remaining = math.ceil((nextExpires or now) - now)
    if remaining < 0 then
        remaining = 0
    end
    local lines = { "Nächster Timer: " .. nextName .. " in " .. remaining .. "s" }
    local timerLines = self:GetBiteTimerLines(8)
    for _, line in ipairs(timerLines) do
        table.insert(lines, line)
    end
    return table.concat(lines, "\n")
end

function BQ:CompleteDebugBite(name)
    local assignments = self:CalculateAssignments()
    if not assignments or #assignments == 0 then
        self:DebugLog("Biss geklappt: keine ausstehenden Bisse.")
        return false
    end

    local lastTarget
    local messages = {}
    for _, assignment in ipairs(assignments) do
        if assignment.target then
            table.insert(messages, assignment.biter .. " -> " .. assignment.target)
            lastTarget = assignment.target
        end
    end
    if #messages == 0 then
        self:DebugLog("Biss geklappt: keine Ziele für ausstehende Bisse.")
        return false
    end

    for _, assignment in ipairs(assignments) do
        if assignment.target then
            self:SetStatus(assignment.target, self.STATUS_VAMPIRE)
        end
    end
    for _, assignment in ipairs(assignments) do
        if assignment.target then
            self:SetDebugBiteTimer(assignment.biter, 60)
            self:SetDebugBiteTimer(assignment.target, 60)
        end
    end
    self:DebugLog("Alle ausstehenden Bisse geklappt: " .. table.concat(messages, " / ") .. ".")
    return lastTarget
end

function BQ:HandleVampiricBite(sourceName, destName)
    return self:HandleActualBite(sourceName, destName)
end

function BQ:HandleActualBite(sourceName, destName)
    sourceName = self:CleanPlayerName(sourceName)
    destName = self:CleanPlayerName(destName)
    if not sourceName or not destName then
        return
    end
    local assignment = self:GetAssignmentForBiter(sourceName)
    if assignment and assignment.target and string.lower(assignment.target) ~= string.lower(destName) then
        self:Announce(self:FormatPlayerForAnnounce(destName, true) .. " wurde gebissen, " .. self:FormatPlayerForAnnounce(assignment.target, true) .. " noch frei")
        self:DebugLog("Falschbiss: " .. sourceName .. " biss " .. destName .. ", geplant war " .. assignment.target .. ".")
    end
    self:SetStatus(sourceName, self.STATUS_VAMPIRE)
    self:SetStatus(destName, self.STATUS_VAMPIRE)
    self:SetDebugBiteTimer(sourceName, 60)
    self:SetDebugBiteTimer(destName, 60)
    self:DebugLog("Biss erkannt: " .. sourceName .. " -> " .. destName .. ". Beide Timer 60s.")
    if self.db and self.db.started and self.db.auto then
        self:AnnounceRound()
    end
end

function BQ:CleanPlayerName(name)
    if not name then
        return nil
    end
    local clean = string.gsub(tostring(name), "%-.*$", "")
    clean = string.gsub(clean, "^%s+", "")
    clean = string.gsub(clean, "%s+$", "")
    if clean == "" then
        return nil
    end
    return clean
end

function BQ:HandleEssence(name)
    name = self:CleanPlayerName(name)
    if not name then
        return
    end
    self:SetStatus(name, self.STATUS_VAMPIRE)
    self:SetDebugBiteTimer(name, 60)
    self:DebugLog("Essenz erkannt: " .. name .. " ist VAMPIRE.")
    if self.db and self.db.started and self.db.auto then
        self:AnnounceRound()
    end
end

function BQ:HandleBloodthirst(name)
    name = self:CleanPlayerName(name)
    if not name then
        return
    end
    self:SetStatus(name, self.STATUS_VAMPIRE)
    local message = self:GetMessageForBiter(name)
    self:DebugLog("Blutdurst erkannt: " .. message)
    self:Announce(message)
end

function BQ:HandleMindControl(name)
    name = self:CleanPlayerName(name)
    if not name then
        return
    end
    self:SetStatus(name, self.STATUS_MC)
    self:DebugLog("Übernahme erkannt: " .. name .. " ist MC.")
end

function BQ:HandleDeath(name)
    name = self:CleanPlayerName(name)
    if not name or not self:FindPlayer(name) then
        return
    end
    self:SetStatus(name, self.STATUS_DEAD)
    self:DebugLog("Tod erkannt: " .. name .. " ist DEAD.")
end

function BQ:SimulateEssence(name)
    self:HandleEssence(name)
    self:SetDebugBiteTimer(name, 60)
end

function BQ:SimulateBloodthirst(name)
    self:HandleBloodthirst(name)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == "BQBiss" then
        BQ:InitDB()
    end
end)

