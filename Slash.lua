BQBiss = BQBiss or {}
local BQ = BQBiss

local function Help()
    BQ:Print("/bq - UI öffnen/schließen")
    BQ:Print("/bq pull - Pull-Test vorbereiten, nur lokal und Auto AN")
    BQ:Print("/bq start - Planung starten und ansagen")
    BQ:Print("/bq reset - Status zurücksetzen")
    BQ:Print("/bq next - nächste Ansage")
    BQ:Print("/bq wrong NAME - falschen Biss als Vampir markieren")
    BQ:Print("/bq import - Raidmitglieder importieren")
    BQ:Print("/bq role NAME dd|heal|tank|unknown - Rolle setzen")
    BQ:Print("/bq markers on|off - Raidmarker schalten")
    BQ:Print("/bq local on|off - Chatansagen sperren oder erlauben")
    BQ:Print("/bq channel local|raid|party|say - Ansagekanal setzen")
    BQ:Print("/bq minimap - Minimap-Icon anzeigen")
    BQ:Print("/bq debug - Debug-Fenster öffnen")
end

SLASH_BQBISS1 = "/bq"
SlashCmdList["BQBISS"] = function(msg)
    msg = msg or ""
    local command, rest = string.match(msg, "^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" then
        if BQ.UI and BQ.UI.Toggle then
            BQ.UI:Toggle()
        end
    elseif command == "pull" then
        BQ:PreparePullTest()
    elseif command == "start" then
        BQ:StartAndAnnounce()
    elseif command == "reset" then
        BQ:Reset()
        BQ:Print("Zurückgesetzt.")
    elseif command == "next" then
        BQ:AnnounceNext()
    elseif command == "wrong" then
        if rest and rest ~= "" then
            BQ:WrongBite(rest)
            BQ:Print(BQ:GetNextMessage())
        else
            BQ:Print("Syntax: /bq wrong NAME")
        end
    elseif command == "import" then
        BQ:ImportRaidMembers()
    elseif command == "role" then
        local name, role = string.match(rest or "", "^(.-)%s+(%S+)$")
        if name and role and BQ:SetRole(name, role) then
            BQ:Print("Rolle gesetzt: " .. name .. " -> " .. string.upper(role))
        else
            BQ:Print("Syntax: /bq role NAME dd|heal|tank|unknown")
        end
    elseif command == "markers" then
        local value = string.lower(rest or "")
        if value == "on" or value == "an" then
            BQ:SetMarkersEnabled(true)
            BQ:Print("Raidmarker: AN")
        elseif value == "off" or value == "aus" then
            BQ:SetMarkersEnabled(false)
            BQ:Print("Raidmarker: AUS")
        else
            BQ:Print("Raidmarker: " .. (BQ.db and BQ.db.markersEnabled and "AN" or "AUS"))
        end
    elseif command == "local" then
        local value = string.lower(rest or "")
        if value == "on" or value == "an" then
            BQ:SetLocalOnly(true)
        elseif value == "off" or value == "aus" then
            BQ:SetLocalOnly(false)
        else
            BQ:Print("Syntax: /bq local on|off")
            return
        end
        BQ:Print("Testmodus: " .. (BQ:IsLocalOnly() and "nur lokal" or "Chatkanäle erlaubt"))
    elseif command == "channel" then
        if rest and rest ~= "" then
            BQ:SetAnnounceChannel(rest)
            BQ:Print("Ansagekanal: " .. BQ:GetAnnounceChannel())
        else
            BQ:Print("Ansagekanal: " .. BQ:GetAnnounceChannel())
        end
    elseif command == "minimap" then
        if BQ.UI and BQ.UI.ShowMinimapButton then
            BQ.UI:ShowMinimapButton()
            BQ:Print("Minimap-Icon angezeigt.")
        end
    elseif command == "debug" then
        if BQ.UI and BQ.UI.ToggleDebug then
            BQ.UI:ToggleDebug()
        end
    else
        Help()
    end
end

