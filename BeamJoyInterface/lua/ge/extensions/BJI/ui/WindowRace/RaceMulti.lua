local mgr

-- Functie om te controleren of er voldoende spelers zijn
local function checkPlayerCount()
    -- Stel dat er minimaal 2 spelers nodig zijn om het menu te openen
    if #mgr.grid.participants >= 2 then
        -- Zet de status om het menu te openen
        mgr.state = mgr.STATES.GRID
    else
        -- Als er nog niet genoeg spelers zijn, toon je iets anders of verberg je het menu
        mgr.state = mgr.STATES.WAITING
    end
end

-- Functie om de header van de interface te tekenen
local function drawHeader(ctxt)
    mgr = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI)

    local line = LineBuilder()
        :text(mgr.raceName)
        :text(svar(BJILang.get("races.play.by"), { author = mgr.raceAuthor }))
    if mgr.settings.laps then
        line:text(svar("({1})",
            {
                mgr.settings.laps == 1 and
                svar(BJILang.get("races.settings.lap"), { lap = mgr.settings.laps }) or
                svar(BJILang.get("races.settings.laps"), { laps = mgr.settings.laps })
            }))
    end
    line:build()

    if mgr.record then
        local modelName = BJIVeh.getModelLabel(mgr.record.model)
        if modelName then
            LineBuilder()
                :text(svar(BJILang.get("races.play.record"), {
                    playerName = mgr.record.playerName,
                    model = modelName,
                    time = RaceDelay(mgr.record.time)
                }))
                :build()
        end
    end

    if mgr.race.startTime then
        local remaining = math.ceil((mgr.race.startTime - ctxt.now) / 1000)
        if remaining > 0 then
            LineBuilder()
                :text(svar(BJILang.get("races.play.gameStartsIn"),
                    { delay = PrettyDelay(remaining) }))
                :build()
        elseif remaining > -3 then
            LineBuilder()
                :text(BJILang.get("races.play.flashCountdownZero"))
                :build()
        else
            EmptyLine()
        end
    else
        EmptyLine()
    end

    if mgr.isRaceStarted() and not mgr.isRaceFinished() and not mgr.isSpec() then
        LineBuilder()
            :btnIcon({
                id = "forfeitRace",
                icon = ICONS.exit_to_app,
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJITx.scenario.RaceMultiUpdate(mgr.CLIENT_EVENTS.LEAVE)
                end,
            })
            :build()
    end

    if mgr.settings.respawnStrategy == mgr.RESPAWN_STRATEGIES.NO_RESPAWN then
        if mgr.dnf.process and mgr.dnf.targetTime then
            local remaining = math.ceil((mgr.dnf.targetTime - ctxt.now) / 1000)
            if remaining >= 0 and remaining < mgr.dnf.timeout then
                LineBuilder()
                    :text(svar(BJILang.get("races.play.eliminatedIn"),
                        { delay = PrettyDelay(math.abs(remaining)) }))
                    :build()
            else
                EmptyLine()
            end
        else
            EmptyLine()
        end
    end
end

-- Functie om de race-informatie te tekenen
local function drawRace(ctxt)
    local wpPerLap = mgr.race.raceData.wpPerLap
    if mgr.isRaceOrCountdownStarted() and not mgr.isRaceFinished() then
        local time = mgr.race.timers.race and mgr.race.timers.race:get() or 0
        if mgr.race.timers.raceOffset then
            time = time + mgr.race.timers.raceOffset
        end
        LineBuilder()
            :icon({
                icon = ICONS.flag,
            })
            :text(RaceDelay(time))
            :build()

        if not mgr.isSpec() then
            time = mgr.race.timers.lap and mgr.race.timers.lap:get() or 0
            LineBuilder()
                :icon({
                    icon = ICONS.timer,
                })
                :text(RaceDelay(time))
                :build()

            local selfWp = 0
            for _, lb in ipairs(mgr.race.leaderboard) do
                if lb.playerID == BJIContext.User.playerID then
                    selfWp = lb.wp
                    break
                end
            end
            LineBuilder()
                :text(svar("{1}/{2}", {
                    svar(BJILang.get("races.play.WP"), { wp = selfWp }),
                    wpPerLap,
                }))
                :build()
        end

        EmptyLine()
    end

    LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })
        :build()
    local colWidths = {}
    if mgr.isSpec() then
        table.insert(colWidths, GetBtnIconSize())
    end
    local playerNameWidth = 0
    for _, lb in ipairs(mgr.race.leaderboard) do
        local target = BJIContext.Players[lb.playerID]
        local targetName = target and target.playerName or BJILang.get("common.unknown")
        local w = GetColumnTextWidth(targetName)
        if w > playerNameWidth then
            playerNameWidth = w
        end
    end
    table.insert(colWidths, playerNameWidth)
    if mgr.settings.laps and mgr.settings.laps > 1 then
        local lapsWidth = 0
        for l = 1, mgr.settings.laps do
            local label = svar(BJILang.get("races.play.Lap"), { lap = l })
            local w = GetColumnTextWidth(label)
            if w > lapsWidth then
                lapsWidth = w
            end
        end
        table.insert(colWidths, lapsWidth)
    end
    local cpWidth = 0
    for cp = 1, wpPerLap do
        local label = svar(BJILang.get("races.play.WP"), { wp = cp })
        local w = GetColumnTextWidth(label)
        if w > cpWidth then
            cpWidth = w
        end
    end
    table.insert(colWidths, cpWidth)
    table.insert(colWidths, -1)

    local firstPlayerCurrentWp = mgr.race.leaderboard[1].wp
    local firstPlayerLap = mgr.race.leaderboard[1].lap
    if firstPlayerCurrentWp > 0 then
        firstPlayerLap = firstPlayerLap - 1
    end
    firstPlayerCurrentWp = firstPlayerCurrentWp + (firstPlayerLap * wpPerLap)
    local cols = ColumnsBuilder("BJIRaceMultiLeaderboard", colWidths, true)
    for pos, lb in ipairs(mgr.race.leaderboard) do
        local target = BJIContext.Players[lb.playerID]
        local targetName = target and target.playerName or BJILang.get("common.unknown")
        local color = target.playerID == BJIContext.User.playerID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT

        local playerCurrentWP = lb.wp
        local playerLap = lb.lap
        if playerCurrentWP > 1 then
            playerLap = playerLap - 1
        end
        playerCurrentWP = playerCurrentWP + (playerLap * wpPerLap)

        local cells = {}
        if mgr.isSpec() then
            table.insert(cells, function()
                LineBuilder()
                    :btnIcon({
                        id = svar("watchPlayer{1}", { pos }),
                        icon = ICONS.visibility,
                        disabled = tincludes(mgr.race.finished, lb.playerID, true) or
                            tincludes(mgr.race.eliminated, lb.playerID, true) or
                            not target,
                        onClick = function()
                            BJIVeh.focus(lb.playerID)
                            BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                        end
                    })
                    :build()
            end)
        end
        table.insert(cells, function()
            LineBuilder()
                :text(targetName, color)
                :build()
        end)
        if mgr.settings.laps and mgr.settings.laps > 1 then
            table.insert(cells, function()
                LineBuilder()
                    :text(svar(BJILang.get("races.play.Lap"), { lap = lb.lap }), color)
                    :build()
            end)
        end
        table.insert(cells, function()
            LineBuilder()
                :text(svar(BJILang.get("races.play.WP"), { wp = lb.wp }), color)
                :build()
        end)
        table.insert(cells, function()
            if pos == 1 then
                LineBuilder()
                    :text(RaceDelay(lb.time or 0))
                    :build()
            else
                local diffVal = math.abs(lb.diff or 0)
                local line = LineBuilder()
                if playerCurrentWP < firstPlayerCurrentWp then
                    line:text(
                        svar(BJILang.get("races.play.wpDifference"),local mgr

-- Functie om te controleren of er voldoende spelers zijn
local function checkPlayerCount()
    -- Stel dat er minimaal 2 spelers nodig zijn om het menu te openen
    if #mgr.grid.participants >= 2 then
        -- Zet de status om het menu te openen
        mgr.state = mgr.STATES.GRID
    else
        -- Als er nog niet genoeg spelers zijn, toon je iets anders of verberg je het menu
        mgr.state = mgr.STATES.WAITING
    end
end

-- Functie om de header van de interface te tekenen
local function drawHeader(ctxt)
    mgr = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI)

    local line = LineBuilder()
        :text(mgr.raceName)
        :text(svar(BJILang.get("races.play.by"), { author = mgr.raceAuthor }))
    if mgr.settings.laps then
        line:text(svar("({1})",
            {
                mgr.settings.laps == 1 and
                svar(BJILang.get("races.settings.lap"), { lap = mgr.settings.laps }) or
                svar(BJILang.get("races.settings.laps"), { laps = mgr.settings.laps })
            }))
    end
    line:build()

    if mgr.record then
        local modelName = BJIVeh.getModelLabel(mgr.record.model)
        if modelName then
            LineBuilder()
                :text(svar(BJILang.get("races.play.record"), {
                    playerName = mgr.record.playerName,
                    model = modelName,
                    time = RaceDelay(mgr.record.time)
                }))
                :build()
        end
    end

    if mgr.race.startTime then
        local remaining = math.ceil((mgr.race.startTime - ctxt.now) / 1000)
        if remaining > 0 then
            LineBuilder()
                :text(svar(BJILang.get("races.play.gameStartsIn"),
                    { delay = PrettyDelay(remaining) }))
                :build()
        elseif remaining > -3 then
            LineBuilder()
                :text(BJILang.get("races.play.flashCountdownZero"))
                :build()
        else
            EmptyLine()
        end
    else
        EmptyLine()
    end

    if mgr.isRaceStarted() and not mgr.isRaceFinished() and not mgr.isSpec() then
        LineBuilder()
            :btnIcon({
                id = "forfeitRace",
                icon = ICONS.exit_to_app,
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJITx.scenario.RaceMultiUpdate(mgr.CLIENT_EVENTS.LEAVE)
                end,
            })
            :build()
    end

    if mgr.settings.respawnStrategy == mgr.RESPAWN_STRATEGIES.NO_RESPAWN then
        if mgr.dnf.process and mgr.dnf.targetTime then
            local remaining = math.ceil((mgr.dnf.targetTime - ctxt.now) / 1000)
            if remaining >= 0 and remaining < mgr.dnf.timeout then
                LineBuilder()
                    :text(svar(BJILang.get("races.play.eliminatedIn"),
                        { delay = PrettyDelay(math.abs(remaining)) }))
                    :build()
            else
                EmptyLine()
            end
        else
            EmptyLine()
        end
    end
end

-- Functie om de race-informatie te tekenen
local function drawRace(ctxt)
    local wpPerLap = mgr.race.raceData.wpPerLap
    if mgr.isRaceOrCountdownStarted() and not mgr.isRaceFinished() then
        local time = mgr.race.timers.race and mgr.race.timers.race:get() or 0
        if mgr.race.timers.raceOffset then
            time = time + mgr.race.timers.raceOffset
        end
        LineBuilder()
            :icon({
                icon = ICONS.flag,
            })
            :text(RaceDelay(time))
            :build()

        if not mgr.isSpec() then
            time = mgr.race.timers.lap and mgr.race.timers.lap:get() or 0
            LineBuilder()
                :icon({
                    icon = ICONS.timer,
                })
                :text(RaceDelay(time))
                :build()

            local selfWp = 0
            for _, lb in ipairs(mgr.race.leaderboard) do
                if lb.playerID == BJIContext.User.playerID then
                    selfWp = lb.wp
                    break
                end
            end
            LineBuilder()
                :text(svar("{1}/{2}", {
                    svar(BJILang.get("races.play.WP"), { wp = selfWp }),
                    wpPerLap,
                }))
                :build()
        end

        EmptyLine()
    end

    LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })
        :build()
    local colWidths = {}
    if mgr.isSpec() then
        table.insert(colWidths, GetBtnIconSize())
    end
    local playerNameWidth = 0
    for _, lb in ipairs(mgr.race.leaderboard) do
        local target = BJIContext.Players[lb.playerID]
        local targetName = target and target.playerName or BJILang.get("common.unknown")
        local w = GetColumnTextWidth(targetName)
        if w > playerNameWidth then
            playerNameWidth = w
        end
    end
    table.insert(colWidths, playerNameWidth)
    if mgr.settings.laps and mgr.settings.laps > 1 then
        local lapsWidth = 0
        for l = 1, mgr.settings.laps do
            local label = svar(BJILang.get("races.play.Lap"), { lap = l })
            local w = GetColumnTextWidth(label)
            if w > lapsWidth then
                lapsWidth = w
            end
        end
        table.insert(colWidths, lapsWidth)
    end
    local cpWidth = 0
    for cp = 1, wpPerLap do
        local label = svar(BJILang.get("races.play.WP"), { wp = cp })
        local w = GetColumnTextWidth(label)
        if w > cpWidth then
            cpWidth = w
        end
    end
    table.insert(colWidths, cpWidth)
    table.insert(colWidths, -1)

    local firstPlayerCurrentWp = mgr.race.leaderboard[1].wp
    local firstPlayerLap = mgr.race.leaderboard[1].lap
    if firstPlayerCurrentWp > 0 then
        firstPlayerLap = firstPlayerLap - 1
    end
    firstPlayerCurrentWp = firstPlayerCurrentWp + (firstPlayerLap * wpPerLap)
    local cols = ColumnsBuilder("BJIRaceMultiLeaderboard", colWidths, true)
    for pos, lb in ipairs(mgr.race.leaderboard) do
        local target = BJIContext.Players[lb.playerID]
        local targetName = target and target.playerName or BJILang.get("common.unknown")
        local color = target.playerID == BJIContext.User.playerID and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT

        local playerCurrentWP = lb.wp
        local playerLap = lb.lap
        if playerCurrentWP > 1 then
            playerLap = playerLap - 1
        end
        playerCurrentWP = playerCurrentWP + (playerLap * wpPerLap)

        local cells = {}
        if mgr.isSpec() then
            table.insert(cells, function()
                LineBuilder()
                    :btnIcon({
                        id = svar("watchPlayer{1}", { pos }),
                        icon = ICONS.visibility,
                        disabled = tincludes(mgr.race.finished, lb.playerID, true) or
                            tincludes(mgr.race.eliminated, lb.playerID, true) or
                            not target,
                        onClick = function()
                            BJIVeh.focus(lb.playerID)
                            BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                        end
                    })
                    :build()
            end)
        end
        table.insert(cells, function()
            LineBuilder()
                :text(targetName, color)
                :build()
        end)
        if mgr.settings.laps and mgr.settings.laps > 1 then
            table.insert(cells, function()
                LineBuilder()
                    :text(svar(BJILang.get("races.play.Lap"), { lap = lb.lap }), color)
                    :build()
            end)
        end
        table.insert(cells, function()
            LineBuilder()
                :text(svar(BJILang.get("races.play.WP"), { wp = lb.wp }), color)
                :build()
        end)
        table.insert(cells, function()
            if pos == 1 then
                LineBuilder()
                    :text(RaceDelay(lb.time or 0))
                    :build()
            else
                local diffVal = math.abs(lb.diff or 0)
                local line = LineBuilder()
                if playerCurrentWP < firstPlayerCurrentWp then
                    line:text(
                        svar(BJILang.get("races.play.wpDifference"),
                            { wpDifference = firstPlayerCurrentWp - playerCurrentWP }),
                        TEXT_COLORS.ERROR)
                        :text(BJILang.get("common.vSeparator"))
                end
                local diffColor = TEXT_COLORS.DEFAULT
                if diffVal > 0 then
                    diffColor = TEXT_COLORS.ERROR
                end
                line:text(svar("+{1}", { RaceDelay(diffVal) }), diffColor)
                    :build()
            end
        end)

        cols:addRow({
            cells = cells
        })
    end
    cols:build()
end

-- Functie om de grid-informatie te tekenen
local function drawGrid(ctxt)
    checkPlayerCount() -- Controleer of het menu geopend kan worden

    if mgr.state == mgr.STATES.GRID then
        LineBuilder()
            :text(svar(BJILang

                            { wpDifference = firstPlayerCurrentWp - playerCurrentWP }),
                        TEXT_COLORS.ERROR)
                        :text(BJILang.get("common.vSeparator"))
                end
                local diffColor = TEXT_COLORS.DEFAULT
                if diffVal > 0 then
                    diffColor = TEXT_COLORS.ERROR
                end
                line:text(svar("+{1}", { RaceDelay(diffVal) }), diffColor)
                    :build()
            end
        end)

        cols:addRow({
            cells = cells
        })
    end
    cols:build()
end

-- Functie om de grid-informatie te tekenen
local function drawGrid(ctxt)
    checkPlayerCount() -- Controleer of het menu geopend kan worden

    if mgr.state == mgr.STATES.GRID then
        LineBuilder()
            :text(svar(BJILang
