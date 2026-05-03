BQBiss = BQBiss or {}
local BQ = BQBiss

local lastBloodthirst = {}
local lastBite = {}

local function ReadCombatLog(...)
    local timestamp, subEvent = ...
    local sourceName, destName, spellId
    local argCount = select("#", ...)

    if argCount >= 12 and type((select(12, ...))) == "number" then
        sourceName = select(5, ...)
        destName = select(9, ...)
        spellId = select(12, ...)
    else
        sourceName = select(4, ...)
        destName = select(7, ...)
        spellId = select(9, ...)
    end

    return timestamp, subEvent, sourceName, destName, spellId
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_HEALTH")
frame:SetScript("OnEvent", function(_, event, ...)
    BQ:InitDB()

    if event == "UNIT_HEALTH" then
        local unit = ...
        if not unit then return end
        if unit ~= "player" and not string.match(unit, "^raid%d+$") and not string.match(unit, "^party%d+$") then
            return
        end
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
            return
        end
        local name = UnitName and UnitName(unit)
        if not name then return end
        local player = BQ:FindPlayer(BQ:CleanPlayerName(name))
        if player and player.status == BQ.STATUS_DEAD then
            BQ:HandleResurrect(name)
        end
        return
    end

    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        return
    end
    if not BQ.db.started or not BQ.db.auto then
        return
    end

    local _, subEvent, sourceName, destName, spellId = ReadCombatLog(...)
    if subEvent == "SPELL_AURA_APPLIED" then
        if BQ.SPELLS.ESSENCE[spellId] then
            BQ:HandleEssence(destName)
        elseif BQ.SPELLS.BLOODTHIRST[spellId] then
            local cleanName = BQ:CleanPlayerName(destName)
            local now = GetTime and GetTime() or 0
            if cleanName and (not lastBloodthirst[cleanName] or now == 0 or now - lastBloodthirst[cleanName] >= 2) then
                lastBloodthirst[cleanName] = now
                BQ:HandleBloodthirst(cleanName)
            end
        elseif BQ.SPELLS.MIND_CONTROL[spellId] then
            BQ:HandleMindControl(destName)
        end
    elseif subEvent == "SPELL_AURA_REMOVED" then
        if BQ.SPELLS.MIND_CONTROL[spellId] then
            BQ:HandleMindControlRemoved(destName)
        end
    end
    if subEvent == "UNIT_DIED" then
        BQ:HandleDeath(destName)
    end
    if BQ.SPELLS.VAMPIRIC_BITE[spellId] then
        local cleanSource = BQ:CleanPlayerName(sourceName)
        local cleanDest = BQ:CleanPlayerName(destName)
        local key = tostring(cleanSource or "") .. ">" .. tostring(cleanDest or "")
        local now = GetTime and GetTime() or 0
        if cleanSource and cleanDest and (not lastBite[key] or now == 0 or now - lastBite[key] >= 2) then
            lastBite[key] = now
            BQ:HandleActualBite(cleanSource, cleanDest)
        end
    end
end)
