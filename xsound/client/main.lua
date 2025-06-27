globalOptionsCache = {}
isPlayerCloseToMusic = false
disableMusic = false

function getDefaultInfo()
    return {
        volume = 1.0,
        url = "",
        id = "",
        position = nil,
        distance = 30, -- ou plus
        playing = false,
        paused = false,
        loop = false,
        isDynamic = false,
        timeStamp = 0,
        maxDuration = 0,
        destroyOnFinish = true,
    }
end

function UpdatePlayerPositionInNUI()
    local ped = PlayerPedId()
    local pos
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        pos = GetEntityCoords(vehicle)
    else
        pos = GetEntityCoords(ped)
    end

    SendNUIMessage({
        status = "position",
        x = pos.x,
        y = pos.y,
        z = pos.z
    })
end

function CheckForCloseMusic()
    local ped = PlayerPedId()
    local playerPos
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        playerPos = GetEntityCoords(vehicle)
    else
        playerPos = GetEntityCoords(ped)
    end
    isPlayerCloseToMusic = false
    for k, v in pairs(soundInfo) do
        if v.position ~= nil and v.isDynamic then
            if #(v.position - playerPos) < v.distance + config.distanceBeforeUpdatingPos then
                isPlayerCloseToMusic = true
                break
            end
        end
    end
end

-- updating position on html side so we can count how much volume the sound needs.
CreateThread(function()
    local refresh = config.RefreshTime or 10
    while true do
        Wait(refresh)
        if not disableMusic and isPlayerCloseToMusic then
            local ped = PlayerPedId()
            local pos
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                pos = GetEntityCoords(vehicle)
            else
                pos = GetEntityCoords(ped)
            end

            -- update position NUI
            SendNUIMessage({
                status = "position",
                x = pos.x,
                y = pos.y,
                z = pos.z
            })
        end
    end
end)

-- checking if player is close to sound so we can switch bool value to true.
CreateThread(function()
    while true do
        Wait(500)
        CheckForCloseMusic()
    end
end)

-- updating timeStamp
CreateThread(function()
    Wait(1100)

    while true do
        Wait(1000)
        for k, v in pairs(soundInfo) do
            if v.playing or v.wasSilented then
                if getInfo(v.id).timeStamp ~= nil and getInfo(v.id).maxDuration ~= nil then
                    if getInfo(v.id).timeStamp < getInfo(v.id).maxDuration then
                        getInfo(v.id).timeStamp = getInfo(v.id).timeStamp + 1
                    end
                end
            end
        end
    end
end)

function PlayMusicFromCache(data)
    local musicCache = soundInfo[data.id]
    if musicCache then
        musicCache.SkipEvents = true

        PlayUrlPos(data.id, data.url, data.volume, data.position, data.loop)
        onPlayStartSilent(data.id, function()
            if getInfo(data.id).maxDuration then
                setTimeStamp(data.id, data.timeStamp or 0)
            end
            Distance(data.id, data.distance)
        end)
    end
end

-- If player is far away from music we will just delete it.
CreateThread(function()
    local destroyedMusicList = {}
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local playerPos
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            playerPos = GetEntityCoords(vehicle)
        else
            playerPos = GetEntityCoords(ped)
        end
        for k, v in pairs(soundInfo) do
            if v.position ~= nil and v.isDynamic then
                if #(v.position - playerPos) < (v.distance + config.distanceBeforeUpdatingPos) then
                    if destroyedMusicList[v.id] then
                        destroyedMusicList[v.id] = nil
                        v.wasSilented = true
                        PlayMusicFromCache(v)
                    end
                else
                    if not destroyedMusicList[v.id] then
                        destroyedMusicList[v.id] = true
                        v.wasSilented = false
                        DestroySilent(v.id)
                    end
                end
            end
        end
    end
end)

-- Met à jour dynamiquement la position du son si le joueur est dans un véhicule
CreateThread(function()
    while true do
        Wait(10)
        for k, v in pairs(soundInfo) do
            if v.isDynamic and v.playing and v.vehicleNetId then
                local vehicle = NetworkGetEntityFromNetworkId(v.vehicleNetId)
                if vehicle and DoesEntityExist(vehicle) then
                    v.position = GetEntityCoords(vehicle)
                end
            end
        end
    end
end)