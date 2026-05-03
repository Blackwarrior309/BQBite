BQBiss = BQBiss or {}
local BQ = BQBiss

local validChannels = {
    LOCAL = true,
    RAID = true,
    PARTY = true,
    SAY = true,
}

local function SanitizeChatMessage(message)
    message = tostring(message or "")
    message = string.gsub(message, "|", "/")
    return message
end

function BQ:SetAnnounceChannel(channel)
    channel = string.upper(tostring(channel or "LOCAL"))
    if not validChannels[channel] then
        channel = "LOCAL"
    end
    self:InitDB()
    self.db.announceChannel = channel
    self:Refresh()
end

function BQ:SetLocalOnly(enabled)
    self:InitDB()
    self.db.localOnly = enabled and true or false
    if self.db.localOnly then
        self.db.announceChannel = "LOCAL"
    end
    self:Refresh()
end

function BQ:IsLocalOnly()
    self:InitDB()
    return self.db.localOnly ~= false
end

function BQ:GetAnnounceChannel()
    self:InitDB()
    if self:IsLocalOnly() then
        return "LOCAL"
    end
    return self.db.announceChannel or "LOCAL"
end

function BQ:CanSendToChannel(channel)
    if channel == "RAID" then
        return GetNumRaidMembers and GetNumRaidMembers() > 0
    elseif channel == "PARTY" then
        return (GetNumPartyMembers and GetNumPartyMembers() > 0) or (GetNumRaidMembers and GetNumRaidMembers() > 0)
    elseif channel == "SAY" then
        return true
    end
    return false
end

function BQ:Announce(message)
    local channel = self:GetAnnounceChannel()
    if not self:IsLocalOnly() and channel ~= "LOCAL" and self:CanSendToChannel(channel) then
        SendChatMessage(SanitizeChatMessage(message), channel)
    else
        self:Print(message)
        if not self:IsLocalOnly() and channel ~= "LOCAL" then
            self:Print("Kanal " .. channel .. " nicht verfügbar, lokal ausgegeben.")
        end
    end
end

function BQ:AnnounceLines(messages)
    if not messages or #messages == 0 then
        self:Announce("Biss: keine gültige Zuordnung")
        return
    end
    for _, message in ipairs(messages) do
        self:Announce(message)
    end
end

function BQ:AnnounceNext()
    local messages = self:GetNextMessages()
    self:AnnounceLines(messages)
    return table.concat(messages, "\n")
end

