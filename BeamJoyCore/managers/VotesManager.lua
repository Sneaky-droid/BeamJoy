local M = {}

-- KICK
M.Kick = {
    creatorID = nil, -- playerID
    targetID = nil,  -- playerID
    endsAt = nil,    -- OSTime
    voters = {},     -- list of playerIDs
}

local function kickStarted()
    return M.Kick.targetID ~= nil
end

local function getKickTotalPlayers()
    return BJCPlayers.getCount(BJCPerm.Data.VoteKick, true) - 1 -- minus target
end

local function getKickThreshold()
    if not kickStarted() then
        return 0
    end
    local thresholdRatio = BJCConfig.Data.VoteKick.ThresholdRatio
    return math.ceil(getKickTotalPlayers() * thresholdRatio)
end

function M.Kick.start(creatorID, targetID)
    if kickStarted() then
        error({ key = "rx.errors.invalidData" })
    elseif BJCPerm.isStaff(creatorID) then
        error({ key = "rx.errors.insufficientPermissions" })
    elseif getKickTotalPlayers() < 2 then
        error({ key = "rx.errors.invalidData" })
    end

    M.Kick.creatorID = creatorID
    M.Kick.targetID = targetID
    M.Kick.endsAt = GetCurrentTime() + BJCConfig.Data.VoteKick.Timeout
    M.Kick.voters = { creatorID }
    BJCAsync.programTask(M.Kick.endVote, M.Kick.endsAt, "BJCVoteKick")

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

local function kickReset()
    BJCAsync.removeTask("BJCVoteKick")
    M.Kick.creatorID = nil
    M.Kick.targetID = nil
    M.Kick.endsAt = nil
    M.Kick.voters = {}
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

function M.Kick.endVote()
    if #M.Kick.voters >= getKickThreshold() then
        local ctxt = {}
        BJCInitContext(ctxt)
        local targetName = BJCPlayers.Players[M.Kick.targetID].playerName
        BJCPlayers.kick(ctxt, M.Kick.targetID,
            svar(BJCLang.getServerMessage(M.Kick.targetID, "voteKick.beenVoteKick"),
                { votersAmount = #M.Kick.voters }))
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.INFO, "voteKick.playerKicked", { playerName = targetName })
    end
    kickReset()
end

function M.Kick.vote(senderID)
    if not kickStarted() then
        error({ key = "rx.errors.invalidData" })
    elseif M.Kick.targetID == senderID then
        error({ key = "rx.errors.invalidData" })
    end

    local pos = tpos(M.Kick.voters, senderID)
    if pos then
        table.remove(M.Kick.voters, pos)
    else
        table.insert(M.Kick.voters, senderID)
    end

    if #M.Kick.voters == 0 then
        kickReset()
    else
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    end
end

function M.Kick.stop()
    if kickStarted() then
        kickReset()
    end
end

function M.Kick.onPlayerDisconnect(playerID)
    if not kickStarted() then
        return
    end

    if M.Kick.targetID == playerID or
        getKickTotalPlayers() < 2 then
        kickReset()
        return
    end

    local pos = tpos(M.Kick.voters, playerID)
    if pos then
        table.remove(M.Kick.voters, pos)
        if #M.Kick.voters == 0 then
            kickReset()
        end
    end
end

-- MAP
M.Map = {
    creatorID = nil, -- playerID
    targetMap = nil, -- map object
    endsAt = nil,    -- OSTime

    voters = {},     -- list of playerIDs
}

local function mapStarted()
    return M.Map.targetMap ~= nil
end

local function getMapTotalPlayers()
    return tlength(BJCPlayers.Players)
end

local function getMapThreshold()
    if not mapStarted() then
        return 0
    end
    local thresholdRatio = BJCConfig.Data.VoteMap.ThresholdRatio
    return math.max(math.ceil(getMapTotalPlayers() * thresholdRatio), 2)
end

function M.Map.start(senderID, mapName)
    if mapStarted() then
        error({ key = "rx.errors.invalidData" })
    end

    if not BJCMaps.Data[mapName] then
        error({ key = "rx.errors.invalidData" })
    elseif mapName == BJCCore.getMap() then
        error({ key = "rx.errors.invalidData" })
    end

    local countPotentialVoters = getMapTotalPlayers()
    if countPotentialVoters == 1 then
        -- only 1 player can vote, allowing direct map switch
        BJCCore.setMap(mapName)
    elseif countPotentialVoters > 1 then
        M.Map.creatorID = senderID
        M.Map.targetMap = mapName
        M.Map.endsAt = GetCurrentTime() + BJCConfig.Data.VoteMap.Timeout
        M.Map.voters = { senderID }
        BJCAsync.programTask(M.Map.endVote, M.Map.endsAt, "BJCVoteMap")

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    else
        error({ key = "rx.errors.insufficientPermissions" })
    end
end

local function mapReset()
    BJCAsync.removeTask("BJCVoteMap")
    M.Map.creatorID = nil
    M.Map.targetMap = nil
    M.Map.endsAt = nil
    M.Map.voters = {}
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

function M.Map.endVote()
    if #M.Map.voters >= getMapThreshold() then
        BJCCore.setMap(M.Map.targetMap)
    end
    mapReset()
end

function M.Map.vote(senderID)
    if not mapStarted() then
        error({ key = "rx.errors.invalidData" })
    end

    local pos = tpos(M.Map.voters, senderID)
    if pos then
        table.remove(M.Map.voters, pos)
    else
        table.insert(M.Map.voters, senderID)
    end

    if #M.Map.voters == 0 then
        mapReset()
    else
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    end
end

function M.Map.stop()
    if mapStarted() then
        mapReset()
    end
end

function M.Map.onPlayerDisconnect(playerID)
    if not mapStarted() then
        return
    end

    local pos = tpos(M.Map.voters, playerID)
    if pos then
        table.remove(M.Map.voters, pos)
        if #M.Map.voters == 0 then
            mapReset()
        end
    end
end

-- RACE
M.Race = {
    creatorID = nil,
    endsAt = nil,
    isVote = false,
    raceID = nil,
    raceName = nil,
    places = nil,
    record = {},
    settings = { -- race settings
        laps = nil,
        model = nil,
        config = nil,
        respawnStrategy = nil,
    },
    time = {
        label = nil, -- time preset label
        ToD = nil,
    },
    weather = {
        label = nil, -- weather preset label
        keys = nil,
    },

    voters = {}, -- list of playerIDs
}

local function raceStarted()
    return M.Race.endsAt ~= nil
end

local function raceReset()
    BJCAsync.removeTask("BJCVoteRaceTimeout")
    M.Race.creatorID = nil
    M.Race.endsAt = nil
    M.Race.isVote = false
    M.Race.raceID = nil
    M.Race.raceName = nil
    M.Race.settings = {
        laps = nil,
        model = nil,
        config = nil,
        respawnStrategy = nil,
    }
    M.Race.time = {
        label = nil,
        ToD = nil,
    }
    M.Race.weather = {
        label = nil,
        keys = nil,
    }
    M.Race.voters = {}
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

local function getRaceThreshold()
    return math.ceil(
        tlength(BJCPlayers.Players) * BJCConfig.Data.Race.VoteThresholdRatio
    )
end

local function raceVoteTimeout()
    if not raceStarted() then
        return
    end

    if M.Race.isVote then
        if tlength(M.Race.voters) >= getRaceThreshold() then
            BJCScenario.RaceManager.start(M.Race.raceID, M.Race.settings, M.Race.time, M.Race.weather)
        end
    else
        BJCScenario.RaceManager.start(M.Race.raceID, M.Race.settings, M.Race.time, M.Race.weather)
    end
    raceReset()
end

local function raceValidateSettings(race, settings)
    if race.loopable and (type(settings.laps) ~= "number" or settings.laps <= 0) then
        error({ key = "rx.errors.invalidData" })
    end

    local RS = BJCScenario.RaceManager.RESPAWN_STRATEGIES

    if not race.hasStand and tincludes({ RS.STAND }, settings.respawnStrategy) then
        error({ key = "rx.errors.invalidData" })
    elseif settings.respawnStrategy and not tincludes(RS, settings.respawnStrategy) then
        error({ key = "rx.errors.invalidData" })
    end

    if settings.config and not settings.model then
        error({ key = "rx.errors.invalidData" })
    end
end

function M.Race.start(creatorID, isVote, raceID, settings)
    local race
    if raceStarted() then
        error({ key = "rx.errors.invalidData" })
    elseif MP.GetPlayerCount() < BJCScenario.RaceManager.MINIMUM_PARTICIPANTS then
        error({ key = "rx.errors.insufficientPlayers" })
    else
        race = BJCScenario.getRace(raceID)
        if not race then
            error({ key = "rx.errors.invalidData" })
        end
        raceValidateSettings(race, settings)
    end

    M.Race.creatorID = creatorID
    M.Race.isVote = isVote
    if M.Race.isVote then
        M.Race.endsAt = GetCurrentTime() + BJCConfig.Data.Race.VoteTimeout
    else
        M.Race.endsAt = GetCurrentTime() + BJCConfig.Data.Race.PreparationTimeout
    end
    M.Race.raceID = raceID
    M.Race.raceName = race.name
    M.Race.places = #race.startPositions
    M.Race.record = race.record
    local laps = nil
    if race.loopable then
        laps = settings.laps or 1
    end
    M.Race.settings = {
        laps = laps,
        model = settings.model,
        config = settings.config,
        respawnStrategy = settings.respawnStrategy,
    }
    M.Race.time = {
        label = settings.time.label and settings.time.label or nil,
        ToD = settings.time.ToD or nil,
    }
    M.Race.weather = {
        label = settings.weather.label and settings.weather.label or nil,
        keys = settings.weather.keys or nil,
    }
    M.Race.voters = { creatorID }

    BJCAsync.programTask(raceVoteTimeout, M.Race.endsAt, "BJCVoteRaceTimeout")
end

function M.Race.vote(playerID)
    if not raceStarted() then
        error({ key = "rx.errors.invalidData" })
    end

    if M.Race.isVote then
        local pos = tpos(M.Race.voters, playerID)
        if pos then
            table.remove(M.Race.voters, pos)
        else
            table.insert(M.Race.voters, playerID)
        end
        if #M.Race.voters == 0 then
            raceReset()
        end
    elseif playerID == M.Race.creatorID then
        raceReset()
    else
        error({ key = "rx.errors.insufficientPermissions" })
    end
end

function M.Race.stop()
    if raceStarted() then
        raceReset()
    end
end

function M.Race.onPlayerDisconnect(playerID)
    if not raceStarted() then
        return
    end

    if M.Race.creatorID == playerID then
        raceReset()
    elseif tpos(M.Race.voters, playerID) then
        table.remove(M.Race.voters, tpos(M.Race.voters, playerID))
        if #M.Race.voters == 0 then
            raceReset()
        end
    end
end

-- SPEED
M.Speed = {
    isVote = false,
    creatorID = nil,
    endsAt = nil,
    participants = {},
}

local function speedStarted()
    return M.Speed.endsAt ~= nil
end

local function resetSpeed()
    BJCAsync.removeTask("BJCVoteSpeed")
    M.Speed.isVote = false
    M.Speed.creatorID = nil
    M.Speed.endsAt = nil
    M.Speed.participants = {}
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

local function speedVoteTimeout()
    if not speedStarted() then
        return
    end

    if tlength(M.Speed.participants) >= 1 then -- DEBUG
        BJCScenario.SpeedManager.start(M.Speed.participants, M.Speed.isVote)
    end
    resetSpeed()
end

local function getSpeedTotalPlayers()
    local total = 0
    for playerID, player in pairs(BJCPlayers.Players) do
        local group = BJCGroups.Data[player.group]
        if group and group.vehicleCap ~= 0 then
            total = total + 1
        end
    end
    return total
end

function M.Speed.start(senderID, isVote)
    if speedStarted() then
        error({ key = "rx.errors.invalidData" })
    elseif getSpeedTotalPlayers() < 1 then -- DEBUG 2
        error({ key = "rx.errors.insufficientPlayers" })
    elseif not isVote and
        not BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    M.Speed.creatorID = senderID
    M.Speed.isVote = isVote
    M.Speed.participants = {}
    if isVote then
        M.Speed.endsAt = GetCurrentTime() + BJCConfig.Data.Speed.VoteTimeout
    else
        M.Speed.endsAt = GetCurrentTime() + BJCConfig.Data.Speed.PreparationTimeout
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)

    BJCAsync.programTask(speedVoteTimeout, M.Speed.endsAt, "BJCVoteSpeed")
end

function M.Speed.join(senderID, gameVehID)
    M.Speed.participants[senderID] = gameVehID ~= -1 and gameVehID or nil
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
end

function M.Speed.onPlayerDisconnect(playerID)
    if speedStarted() and M.Speed.participants[playerID] then
        M.Speed.participants[playerID] = nil
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.VOTE)
    end
end

-- COMMON
function M.getCache()
    local map = M.Map.targetMap and BJCMaps.Data[M.Map.targetMap] or {}
    return {
        Kick = {
            threshold = getKickThreshold(),
            creatorID = M.Kick.creatorID,
            targetID = M.Kick.targetID,
            endsAt = M.Kick.endsAt,
            voters = M.Kick.voters,
        },
        Map = {
            threshold = getMapThreshold(),
            creatorID = M.Map.creatorID,
            mapLabel = map.label,
            mapCustom = map.custom,
            endsAt = M.Map.endsAt,
            voters = M.Map.voters,
        },
        Race = {
            threshold = getRaceThreshold(),
            creatorID = M.Race.creatorID,
            endsAt = M.Race.endsAt,
            isVote = M.Race.isVote,
            raceName = M.Race.raceName,
            places = M.Race.places,
            record = M.Race.record,
            timeLabel = M.Race.time.label,
            weatherLabel = M.Race.weather.label,
            laps = M.Race.settings.laps,
            model = M.Race.settings.model,
            specificConfig = not not M.Race.settings.config,
            respawnStrategy = M.Race.settings.respawnStrategy,
            voters = M.Race.voters,
        },
        Speed = {
            creatorID = M.Speed.creatorID,
            isVote = M.Speed.isVote,
            endsAt = M.Speed.endsAt,
            participants = M.Speed.participants,
        },
    }, M.getCacheHash()
end

function M.getCacheHash()
    return Hash({
        M.Kick, M.Map, M.Race
    })
end

function M.onPlayerDisconnect(playerID)
    if kickStarted() then
        M.Kick.onPlayerDisconnect(playerID)
    end

    if mapStarted() then
        M.Map.onPlayerDisconnect(playerID)
    end

    if raceStarted() then
        M.Race.onPlayerDisconnect(playerID)
    end

    if speedStarted() then
        M.Speed.onPlayerDisconnect(playerID)
    end
end

RegisterBJCManager(M)
return M
