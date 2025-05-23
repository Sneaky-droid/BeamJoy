local im = ui_imgui

local M = {
    _name = "BJIWindowsManager",
    _windows = {},
    _baseFlags = {
        WINDOW_FLAGS.NO_SCROLLBAR,
        WINDOW_FLAGS.NO_SCROLL_WITH_MOUSE,
        WINDOW_FLAGS.NO_FOCUS_ON_APPEARING,
    },
    _collapsed = {},
    loaded = false,
}

local function initWindows()
    -- MAIN
    M.register({
        name = "BJI",
        showConditionFn = function() return true end,
        draw = require("ge/extensions/BJI/ui/WindowBJI/DrawWindowBJI"),
        w = 300,
        h = 350,
    })

    -- USER SETTINGS
    M.register({
        name = "BJIUserSettings",
        showConditionFn = function()
            return BJIContext.UserSettings.open
        end,
        draw = require("ge/extensions/BJI/ui/WindowUserSettings/DrawWindowUserSettings"),
        w = 330,
        h = 330,
    })

    -- EVENTS (votes)
    M.register({
        name = "BJIEvents",
        showConditionFn = function()
            local votes = {}

            local showVoteKick = BJIVote.Kick.started()
            table.insert(votes, showVoteKick)

            local showVoteMap = BJIVote.Map.started()
            table.insert(votes, showVoteMap)

            local showRacePreparation = BJIVote.Race.started()
            table.insert(votes, showRacePreparation)

            local showSpeedPreparation = BJIVote.Speed.started()
            table.insert(votes, showSpeedPreparation)

            for i = 1, #votes do
                while votes[i] == false do
                    table.remove(votes, i)
                end
            end
            return #votes > 0
        end,
        draw = require("ge/extensions/BJI/ui/WindowEvents/DrawWindowEvents"),
        w = 480,
        h = 250,
    })

    -- VEHICLE SELECTOR
    M.register({
        name = "BJIVehicleSelector",
        showConditionFn = function()
            return BJIVehSelector.state and BJIPerm.canSpawnVehicle()
        end,
        draw = BJIVehSelector,
        w = 320,
        h = 420,
    })

    -- VEHICLE SELECTOR PREVIEW
    M.register({
        name = "BJIVehicleSelectorPreview",
        showConditionFn = function()
            return BJIVehSelectorPreview.preview
        end,
        draw = BJIVehSelectorPreview,
        w = BJIVehSelectorPreview.imageSize.x + BJIVehSelectorPreview.windowSizeOffset.x,
        h = BJIVehSelectorPreview.imageSize.y + BJIVehSelectorPreview.windowSizeOffset.y,
    })

    -- RACE SETTINGS
    M.register({
        name = "BJIRaceSettings",
        showConditionFn = function()
            return BJIContext.Scenario.RaceSettings and BJIScenario.isFreeroam() and
                (BJIPerm.hasPermission(BJIPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
                    BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) or
                    BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO))
        end,
        draw = require("ge/extensions/BJI/ui/WindowRaceSettings/DrawWindowRaceSettings"),
        w = 390,
        h = 220,
    })

    -- RACE
    M.register({
        name = "BJIRace",
        showConditionFn = function()
            if not BJICache.areBaseCachesFirstLoaded() then
                return false
            end
            local raceSolo = BJIScenario.is(BJIScenario.TYPES.RACE_SOLO)
            local raceMulti = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI)
            return raceSolo or (raceMulti and raceMulti.state)
        end,
        draw = require("ge/extensions/BJI/ui/WindowRace/DrawWindowRace"),
        w = 300,
        h = 280,
    })

    -- HUNTER SETTINGS
    M.register({
        name = "BJIHunterSettings",
        showConditionFn = function()
            return BJIContext.Scenario.HunterSettings and
                BJIScenario.isFreeroam() and
                (BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) or
                    BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO))
        end,
        draw = require("ge/extensions/BJI/ui/WindowHunterSettings/DrawWindowHunterSettings"),
        w = 350,
        h = 350,
    })

    -- HUNTER
    M.register({
        name = "BJIHunter",
        showConditionFn = function()
            return BJICache.areBaseCachesFirstLoaded() and
                BJIScenario.is(BJIScenario.TYPES.HUNTER)
        end,
        draw = require("ge/extensions/BJI/ui/WindowHunter/DrawWindowHunter"),
        w = 300,
        h = 280,
    })

    -- DELIVERY MULTI
    M.register({
        name = "BJIDeliveryMulti",
        showConditionFn = function()
            return BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI) and
                BJIScenario.is(BJIScenario.TYPES.DELIVERY_MULTI)
        end,
        draw = require("ge/extensions/BJI/ui/WindowDeliveryMulti/DrawWindowDeliveryMulti"),
        w = 350,
        h = 220,
    })

    -- TAG
    M.register({
        name = "BJITag",
        showConditionFn = function()
            return (BJIScenario.get(BJIScenario.TYPES.TAG_DUO) and
                    BJIScenario.is(BJIScenario.TYPES.TAG_DUO)) or
                (BJIScenario.get(BJIScenario.TYPES.TAG_SERVER) and
                    BJIScenario.is(BJIScenario.TYPES.TAG_SERVER))
        end,
        draw = require("ge/extensions/BJI/ui/WindowTag/DrawWindowTag"),
        w = 300,
        h = 250,
    })

    -- SPEED
    M.register({
        name = "BJISpeed",
        showConditionFn = function()
            return BJICache.areBaseCachesFirstLoaded() and
                BJIScenario.is(BJIScenario.TYPES.SPEED)
        end,
        draw = require("ge/extensions/BJI/ui/WindowSpeed/DrawWindowSpeed"),
        w = 350,
        h = 250,
    })

    -- DERBY SETTINGS
    M.register({
        name = "BJIDerbySettings",
        showConditionFn = function()
            return BJIContext.Scenario.DerbySettings and
                BJIScenario.isFreeroam() and
                BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO)
        end,
        draw = require("ge/extensions/BJI/ui/WindowDerbySettings/DrawWindowDerbySettings"),
        w = 300,
        h = 350,
    })

    -- DERBY
    M.register({
        name = "BJIDerby",
        showConditionFn = function()
            return BJICache.areBaseCachesFirstLoaded() and
                BJIScenario.is(BJIScenario.TYPES.DERBY)
        end,
        draw = require("ge/extensions/BJI/ui/WindowDerby/DrawWindowDerby"),
        w = 300,
        h = 280,
    })

    -- SCENARIO EDITOR
    M.register({
        name = "BJIScenarioEditor",
        showConditionFn = function()
            if not BJIScenario.isFreeroam() or
                BJIScenario.isServerScenarioInProgress() or
                BJIScenario.isPlayerScenarioInProgress() then
                return false
            end
            return BJIContext.Scenario.isEditorOpen()
        end,
        draw = function()
            if BJIContext.Scenario.RaceEdit then
                return require("ge/extensions/BJI/ui/WindowScenarioEditor/Race")
            elseif BJIContext.Scenario.EnergyStationsEdit then
                return require("ge/extensions/BJI/ui/WindowScenarioEditor/EnergyStations")
            elseif BJIContext.Scenario.GaragesEdit then
                return require("ge/extensions/BJI/ui/WindowScenarioEditor/Garages")
            elseif BJIContext.Scenario.DeliveryEdit then
                return require("ge/extensions/BJI/ui/WindowScenarioEditor/Deliveries")
            elseif BJIContext.Scenario.BusLinesEdit then
                return require("ge/extensions/BJI/ui/WindowScenarioEditor/BusLines")
            elseif BJIContext.Scenario.HunterEdit then
                return require("ge/extensions/BJI/ui/WindowScenarioEditor/Hunter")
            elseif BJIContext.Scenario.DerbyEdit then
                return require("ge/extensions/BJI/ui/WindowScenarioEditor/Derby")
            end
            return {}
        end,
        w = 450,
        h = 850,
    })

    -- STATIONS (ENERGY & GARAGES)
    M.register({
        name = "BJIStation",
        showConditionFn = function()
            return BJIPerm.canSpawnVehicle() and
                not BJIContext.Scenario.isEditorOpen() and
                BJIStations.station and
                not BJIContext.User.stationProcess
        end,
        draw = require("ge/extensions/BJI/ui/WindowStation/DrawWindowStation"),
        w = 280,
        h = 150,
    })

    -- BUS MISSION
    M.register({
        name = "BJIBusMissionPreparation",
        showConditionFn = function()
            return BJIScenario.is(BJIScenario.TYPES.BUS_MISSION) and
                BJIScenario.get(BJIScenario.TYPES.BUS_MISSION) and
                BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).state ==
                BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).STATES.PREPARATION
        end,
        draw = require("ge/extensions/BJI/ui/WindowBusMissionPreparation/DrawWindowBusMissionPreparation"),
        w = 430,
        h = 150,
    })

    -- FREEROAM SETTINGS
    M.register({
        name = "BJIFreeroamSettings",
        showConditionFn = function() return BJIContext.Scenario.FreeroamSettingsOpen end,
        draw = require("ge/extensions/BJI/ui/WindowFreeroamSettings/DrawWindowFreeroamSettings"),
        w = 460,
        h = 350,
    })

    -- SERVER
    M.register({
        name = "BJIServer",
        showConditionFn = function() return BJIContext.ServerEditorOpen end,
        draw = require("ge/extensions/BJI/ui/WindowServer/DrawWindowServer"),
        w = 470,
        h = 450,
    })

    -- ENVIRONMENT
    M.register({
        name = "BJIEnvironment",
        showConditionFn = function() return BJIContext.EnvironmentEditorOpen end,
        draw = require("ge/extensions/BJI/ui/WindowEnvironment/DrawWindowEnvironment"),
        w = 440,
        h = 640,
    })

    -- THEME
    M.register({
        name = "BJITheme",
        showConditionFn = function() return BJIContext.ThemeEditor end,
        draw = require("ge/extensions/BJI/ui/WindowTheme/DrawWindowTheme"),
        w = 350,
        h = 750,
    })

    -- DATABASE
    M.register({
        name = "BJIDatabase",
        showConditionFn = function() return BJIContext.DatabaseEditorOpen end,
        draw = require("ge/extensions/BJI/ui/WindowDatabase/DrawWindowDatabase"),
        w = 400,
        h = 250,
    })

    -- DEBUG
    M.register({
        name = "Debug",
        showConditionFn = function()
            return not not BJIDEBUG
        end,
        draw = {
            flags = {
                WINDOW_FLAGS.NO_COLLAPSE,
            },
            header = function(ctxt)
                LineBuilder()
                    :text("DEBUG")
                    :build()
            end,
            body = function(ctxt)
                local totalLines = 0
                local function display(obj, key)
                    local line = LineBuilder()
                        :text(key and svar("{1} ({2}) =", { key, type(key) }) or "")
                    if type(obj) == "table" then
                        line:text(svar("({1}, {2} child.ren)", {
                            type(obj),
                            tlength(obj)
                        }))
                        Indent(1)
                        local objs = {}
                        for k, v in pairs(obj) do
                            table.insert(objs, { k = k, v = v })
                        end
                        table.sort(objs, function(a, b)
                            return tostring(a.k) < tostring(b.k)
                        end)
                        for _, el in ipairs(objs) do
                            display(el.v, el.k)
                            if totalLines > 200 then
                                return
                            end
                        end
                        Indent(-1)
                    else
                        local val = type(obj) == "string" and
                            svar("\"{1}\"", { obj }) or
                            tostring(obj)
                        line:text(svar("{1} ({2})", { val, type(obj) }))
                    end
                    line:build()
                    totalLines = totalLines + 1
                end

                local data = BJIDEBUG
                if type(data) == "function" then
                    _, data = pcall(data, ctxt)
                end
                display(data)
                if totalLines > 200 then
                    LineBuilder():text("..."):build()
                end
            end,
            footer = function(ctxt)
                LineBuilder()
                    :btnIcon({
                        id = "emptyDebug",
                        icon = ICONS.exit_to_app,
                        style = BTN_PRESETS.ERROR,
                        onClick = function()
                            BJIDEBUG = nil
                        end
                    })
                    :build()
            end
        },
    })
end

local function exists(name)
    return M._windows[name] ~= nil
end

--[[
data: object
<ul>
    <li>name: string</li>
    <li>draw: function(): nil</li>
    <li>showConditionFn: function() : boolean</li>
    <li>x: number NULLABLE</li>
    <li>y: number NULLABLE</li>
]]
local function register(data)
    if not data.draw or not data.showConditionFn then
        LogError("Window requires name, draw and showConditionFn")
        return
    end
    if M.exists(data.name) then
        -- already exists
        return
    end

    M._windows[data.name] = {
        show = false,
        name = data.name,
        draw = data.draw,
        showConditionFn = data.showConditionFn,
        w = data.w,
        h = data.h,
        x = data.x,
        y = data.y,
    }
    data.w = data.w or -1
    data.h = data.h or -1
    BJIContext.GUI.registerWindow(data.name, im.ImVec2(data.w, data.h))
end

local function renderTick(ctxt)
    if not BJICONNECTED or not BJICache.areBaseCachesFirstLoaded() or not BJIThemeLoaded then
        return
    end

    local function drawWrap(fn, w)
        -- apply min height (fixes moved out collapsed size issue)
        local size = im.GetWindowSize()
        if w.h and size.y < w.h * BJIContext.UserSettings.UIScale then
            im.SetWindowSize1(im.ImVec2(size.x, math.floor(w.h * BJIContext.UserSettings.UIScale)), im.Cond_Always)
        end
        local _, err = pcall(fn, ctxt)
        if err then
            LogError(err, M._name)
        end
    end

    InitDefaultStyles()
    for _, w in pairs(M._windows) do
        if (w.show and not w.showConditionFn()) or
            not M.loaded or
            not MPGameNetwork.launcherConnected() then
            w.show = false
            BJIContext.GUI.hideWindow(w.name)
        elseif not w.show and w.showConditionFn() then
            w.show = true
            BJIContext.GUI.showWindow(w.name)
        end

        local title = w.name and
            BJILang.get(svar("windows.{1}", { w.name }), w.name) or
            nil
        if w.show then
            local draw = w.draw
            if type(draw) == "function" then
                draw = draw()
            end

            if w.w and w.h then
                im.SetNextWindowSize(im.ImVec2(
                    math.floor(w.w * BJIContext.UserSettings.UIScale),
                    math.floor(w.h * BJIContext.UserSettings.UIScale)
                ))
            end
            if w.x and w.y then
                im.SetNextWindowPos(im.ImVec2(w.x, w.y))
            end

            local flagsToApply = tdeepcopy(M._baseFlags)
            local flags = draw.flags or {}
            if type(flags) == "function" then
                flags = flags(ctxt)
            end
            if type(flags) ~= "table" then
                flags = {}
            end
            for _, winFlag in pairs(flags) do
                if not tincludes(flagsToApply, winFlag, true) then
                    table.insert(flagsToApply, winFlag)
                end
            end

            if type(draw.menu) == "function" and
                not tincludes(flagsToApply, WINDOW_FLAGS.MENU_BAR, true) then
                table.insert(flagsToApply, WINDOW_FLAGS.MENU_BAR)
            end
            BJIContext.GUI.setupWindow(w.name)
            local alpha = BJIStyles[STYLE_COLS.WINDOW_BG] and BJIStyles[STYLE_COLS.WINDOW_BG].w or .5
            local window = WindowBuilder(w.name, im.flags(tunpack(flagsToApply)))
                :title(title)
                :opacity(alpha)

            if draw.menu then
                window = window:menu(function()
                    drawWrap(draw.menu, w)
                end)
            end

            if draw.header then
                window:header(function()
                    drawWrap(draw.header, w)
                end)
            end

            if draw.body then
                window:body(function()
                    drawWrap(draw.body, w)
                end)
            end

            if draw.footer then
                local lines = 1
                if draw.footerLines then
                    lines = draw.footerLines(ctxt)
                end
                window:footer(function()
                    drawWrap(draw.footer, w)
                end, lines)
            end

            if draw.onClose then
                window:onClose(function()
                    draw.onClose(ctxt)
                end)
            end
            window:build()
        elseif not title then
            LogError(svar("Invalid name for window {1}", { w.name }))
        end
    end
    ResetStyles()
end

local function isWindowOpen(name)
    return M._windows[name] and M._windows[name].show
end

local function onLoad()
    initWindows()
    M.loaded = true
end

local function onUnload()
    M.loaded = false
end

M.exists = exists
M.register = register
M.renderTick = renderTick

M.isWindowOpen = isWindowOpen

M.onLoad = onLoad
M.onUnload = onUnload

RegisterBJIManager(M)
return M
