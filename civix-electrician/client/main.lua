local Civix = exports['civix-core']:GetCoreObject()

local State = {
    dispatcher = 0,
    shift = false,
    supplies = false,
    route = {},
    index = 0,
    active = nil,
    activeObject = 0,
    interactionId = nil,
    fallback = false,
    resolving = false,
    routeBlip = nil,
    vehicle = 0,
    plate = nil,
    minigame = false,
    profile = nil,
}

local function trim(value)
    return value and value:match('^%s*(.-)%s*$') or nil
end

local function notify(message, kind, duration)
    kind, duration = kind or 'primary', duration or 5000
    if pcall(function() exports['civix-notify']:Notify(message, kind, duration) end) then return end
    if pcall(function() exports['civix-notify']:SendNotification(message, kind, duration) end) then return end
    TriggerEvent('civix-notify:client:Notify', message, kind, duration)
end

RegisterNetEvent('civix-electrician:client:notify', notify)

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(20) end
    return HasModelLoaded(hash) and hash or nil
end

local function playerData()
    if Civix and Civix.Functions and Civix.Functions.GetPlayerData then
        return Civix.Functions.GetPlayerData() or {}
    end
    local ok, data = pcall(function() return exports['civix-core']:GetPlayerData() end)
    return ok and data or {}
end

local function grade(job)
    if type(job) ~= 'table' then return -1 end
    if type(job.grade) == 'table' then return tonumber(job.grade.level or job.grade.grade or 0) or 0 end
    return tonumber(job.grade or 0) or 0
end

local function allowedJob(job, key)
    if type(job) ~= 'table' then return false end
    local name = job.name or job.id or job.job or key
    if not Config.AllowedJobs[name] then return false end
    if grade(job) < Config.MinimumGrade then return false end
    if Config.RequireDuty and job.onduty == false then return false end
    return true
end

local function hasAccess()
    if Config.AllowContractors then return true end
    local data = playerData()
    if Config.AllowPrimaryJob and allowedJob(data.job) then return true end
    if not Config.AllowMultiJob then return false end
    local lists = {
        data.jobs,
        data.multijobs,
        data.metadata and data.metadata.jobs,
        data.metadata and data.metadata.multijobs,
        data.charinfo and data.charinfo.jobs,
    }
    for _, list in ipairs(lists) do
        if type(list) == 'table' then
            for key, value in pairs(list) do
                if allowedJob(value, key) then return true end
                if type(value) ~= 'table' and type(key) == 'string' and Config.AllowedJobs[key] then return true end
            end
        end
    end
    return false
end

local function addInteraction(payload)
    if pcall(function() exports['civix-interact']:AddInteraction(payload) end) then return true end
    if pcall(function() exports['civix-interact']:addInteraction(payload) end) then return true end
    return false
end

local function addLocalEntity(entity, payload)
    if pcall(function() exports['civix-interact']:AddLocalEntityInteraction(entity, payload) end) then return true end
    if pcall(function() exports['civix-interact']:AddLocalEntity(entity, payload) end) then return true end
    if pcall(function() exports['civix-interact']:addLocalEntityInteraction(entity, payload) end) then return true end
    if pcall(function() exports['civix-interact']:AddLocalEntityInteraction({ entity = entity, id = payload.id, distance = payload.distance, interactDst = payload.interactDst, options = payload.options }) end) then return true end
    return false
end

local function removeInteraction(id, entity)
    if not id then return end
    pcall(function() exports['civix-interact']:RemoveInteraction(id) end)
    pcall(function() exports['civix-interact']:removeInteraction(id) end)
    if entity and entity ~= 0 then
        pcall(function() exports['civix-interact']:RemoveLocalEntityInteraction(entity, id) end)
        pcall(function() exports['civix-interact']:RemoveLocalEntity(entity, id) end)
    end
end

local function keyGive(vehicle)
    local plate = trim(GetVehicleNumberPlateText(vehicle))
    State.plate = plate
    local calls = {
        function() exports['civix-vehiclekeys']:GiveKeys(plate) end,
        function() exports['civix-vehiclekeys']:AddKeys(plate) end,
        function() exports['civix-vehiclekeys']:SetOwner(plate) end,
        function() exports['civix-vehiclekeys']:GiveVehicleKeys(vehicle) end,
    }
    for _, fn in ipairs(calls) do if pcall(fn) then break end end
    TriggerEvent('civix-vehiclekeys:client:SetOwner', plate)
    TriggerEvent('civix-vehiclekeys:client:AddKeys', plate)
    TriggerServerEvent('civix-vehiclekeys:server:AcquireVehicleKeys', plate)
end

local function keyRemove(vehicle)
    local plate = State.plate or (vehicle ~= 0 and trim(GetVehicleNumberPlateText(vehicle)))
    if not plate then return end
    local calls = {
        function() exports['civix-vehiclekeys']:RemoveKeys(plate) end,
        function() exports['civix-vehiclekeys']:RevokeKeys(plate) end,
        function() exports['civix-vehiclekeys']:RemoveVehicleKeys(plate) end,
    }
    for _, fn in ipairs(calls) do if pcall(fn) then break end end
    TriggerEvent('civix-vehiclekeys:client:RemoveKeys', plate)
    TriggerServerEvent('civix-vehiclekeys:server:RemoveKeys', plate)
end

local function clearBlip()
    if State.routeBlip and DoesBlipExist(State.routeBlip) then RemoveBlip(State.routeBlip) end
    State.routeBlip = nil
end

local function clearCabinet()
    removeInteraction(State.interactionId, State.activeObject)
    State.interactionId = nil
    State.activeObject = 0
    State.fallback = false
    State.resolving = false
end

local function sendHud(status)
    if not State.shift then
        SendNUIMessage({ action = 'hud', visible = false })
        return
    end
    local distance
    if State.active and State.active.coords then
        local c = State.active.coords
        distance = math.floor(#(GetEntityCoords(PlayerPedId()) - vector3(c.x, c.y, c.z)))
    end
    SendNUIMessage({
        action = 'hud',
        visible = true,
        stop = State.index,
        total = #State.route,
        district = State.active and State.active.district or 'Contractor yard',
        label = State.active and State.active.label or 'Return utility truck',
        fault = State.active and (State.active.faultLabel or 'Diagnosis pending') or 'Route complete',
        distance = distance,
        status = status or (State.active and (State.active.resolved and 'Cabinet located' or 'Locate the marked service cabinet') or 'Return the assigned truck'),
        rank = State.profile and State.profile.rank or 'Apprentice',
        xp = State.profile and State.profile.xp or 0,
    })
end

local function setRouteBlip(coords, exact)
    clearBlip()
    if not Config.RouteBlip then return end
    State.routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(State.routeBlip, exact and 354 or 1)
    SetBlipColour(State.routeBlip, 47)
    SetBlipScale(State.routeBlip, exact and 0.82 or 0.70)
    SetBlipRoute(State.routeBlip, true)
    SetBlipRouteColour(State.routeBlip, 47)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(exact and 'Electrical service cabinet' or 'Electrical service area')
    EndTextCommandSetBlipName(State.routeBlip)
end

local function findCabinet(anchor)
    local best, bestDistance, bestModel = 0, Config.ObjectSearchRadius + 0.01, nil
    for _, model in ipairs(Config.ElectricalModels) do
        local object = GetClosestObjectOfType(anchor.x, anchor.y, anchor.z, Config.ObjectSearchRadius, model, false, false, false)
        if object and object ~= 0 and DoesEntityExist(object) then
            local d = #(GetEntityCoords(object) - anchor)
            if d < bestDistance then
                best, bestDistance, bestModel = object, d, model
            end
        end
    end
    return best, bestModel
end

local function serviceVehicleNearby()
    if not Config.RequireServiceVehicle then return true end
    return State.vehicle ~= 0 and DoesEntityExist(State.vehicle) and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(State.vehicle)) <= Config.ServiceVehicleRadius
end

local function repairAnimation(duration)
    local ped = PlayerPedId()
    if State.active and State.active.coords then
        local c = State.active.coords
        TaskTurnPedToFaceCoord(ped, c.x, c.y, c.z, 600)
        Wait(600)
    end
    RequestAnimDict('amb@world_human_vehicle_mechanic@male@base')
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded('amb@world_human_vehicle_mechanic@male@base') and GetGameTimer() < timeout do Wait(20) end
    if HasAnimDictLoaded('amb@world_human_vehicle_mechanic@male@base') then
        TaskPlayAnim(ped, 'amb@world_human_vehicle_mechanic@male@base', 'base', 3.0, 3.0, duration, 1, 0.0, false, false, false)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_WELDING', 0, true)
    end
    FreezeEntityPosition(ped, true)
    Wait(duration)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
end

local function inspectCabinet()
    if not State.shift or not State.active or State.minigame then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then notify('Exit the vehicle before opening the cabinet.', 'error'); return end
    if not serviceVehicleNearby() then notify(('Bring the utility truck within %d metres.'):format(Config.ServiceVehicleRadius), 'error'); return end
    if State.activeObject == 0 or not DoesEntityExist(State.activeObject) then notify('The assigned cabinet is no longer streamed. Move closer and try again.', 'error'); return end
    sendHud('Testing line voltage and applying lockout/tagout')
    repairAnimation(3800)
    TriggerServerEvent('civix-electrician:server:beginStop', State.index)
end

RegisterNetEvent('civix-electrician:client:inspect', inspectCabinet)

local function registerCabinet(entity)
    clearCabinet()
    State.activeObject = entity
    local id = ('civix-electrician-cabinet-%d'):format(State.index)
    State.interactionId = id
    local option = {
        name = id,
        id = id,
        label = 'Inspect electrical cabinet',
        icon = 'fas fa-bolt',
        distance = Config.InteractionDistance,
        canInteract = function() return State.shift and State.active ~= nil and not State.minigame end,
        action = inspectCabinet,
        onSelect = inspectCabinet,
        event = 'civix-electrician:client:inspect',
    }
    local added = addLocalEntity(entity, { id = id, distance = 7.0, interactDst = Config.InteractionDistance, options = { option } })
    State.fallback = not added
end

local function resolveCurrentStop()
    if State.resolving or not State.active or State.active.resolved then return end
    State.resolving = true
    local anchor = vector3(State.active.anchor.x, State.active.anchor.y, State.active.anchor.z)
    local entity, model = findCabinet(anchor)
    if entity ~= 0 then
        local c = GetEntityCoords(entity)
        State.active.coords = { x = c.x, y = c.y, z = c.z }
        State.active.resolved = true
        registerCabinet(entity)
        setRouteBlip(c, true)
        TriggerServerEvent('civix-electrician:server:resolveStop', State.index, { x = c.x, y = c.y, z = c.z }, model)
        sendHud('Actual cabinet located. Park safely and inspect it.')
        notify('Service cabinet located. Park the utility truck nearby.', 'success')
    else
        TriggerServerEvent('civix-electrician:server:rerollStop', State.index)
    end
    State.resolving = false
end

local function activateStop(index)
    clearCabinet()
    State.index = index
    State.active = State.route[index]
    if not State.active then
        clearBlip()
        SetNewWaypoint(Config.VehicleReturn.x, Config.VehicleReturn.y)
        sendHud('Route complete. Return the assigned utility truck.')
        notify('All repairs are complete. Return the utility truck for the route bonus.', 'success', 7000)
        return
    end
    State.active.anchor = State.active.anchor or State.active.coords
    State.active.coords = State.active.anchor
    State.active.resolved = false
    setRouteBlip(State.active.anchor, false)
    sendHud('Drive to the marked service area')
end

local function spawnVehicle()
    if not State.shift then notify('Start a shift first.', 'error'); return end
    if State.vehicle ~= 0 and DoesEntityExist(State.vehicle) then notify('Your utility truck is already active.', 'error'); return end
    if IsAnyVehicleNearPoint(Config.VehicleSpawn.x, Config.VehicleSpawn.y, Config.VehicleSpawn.z, 3.0) then notify('The utility bay is blocked.', 'error'); return end
    local model = loadModel(Config.VehicleModel)
    if not model then notify('The configured utility truck could not be loaded.', 'error'); return end
    local function finish(vehicle)
        if not vehicle or vehicle == 0 then notify('Unable to create the utility truck.', 'error'); return end
        State.vehicle = vehicle
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDirtLevel(vehicle, 0.0)
        SetVehicleFuelLevel(vehicle, Config.VehicleFuel)
        SetVehicleLivery(vehicle, Config.VehicleLivery)
        SetVehicleNumberPlateText(vehicle, ('CIVX%03d'):format(math.random(100, 999)))
        keyGive(vehicle)
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent('civix-electrician:server:vehicleAssigned', netId, State.plate)
        SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
        SetModelAsNoLongerNeeded(model)
        notify('Utility truck assigned and vehicle keys issued.', 'success')
    end
    if Civix and Civix.Functions and Civix.Functions.SpawnVehicle then
        Civix.Functions.SpawnVehicle(Config.VehicleModel, finish, Config.VehicleSpawn, true)
    else
        finish(CreateVehicle(model, Config.VehicleSpawn.x, Config.VehicleSpawn.y, Config.VehicleSpawn.z, Config.VehicleSpawn.w, true, false))
    end
end

local function requestVehicleReturn()
    if State.vehicle == 0 or not DoesEntityExist(State.vehicle) then notify('There is no assigned utility truck.', 'error'); return end
    if #(GetEntityCoords(State.vehicle) - Config.VehicleReturn) > Config.VehicleReturnRadius then notify('Park the assigned truck in the return bay.', 'error'); return end
    TriggerServerEvent('civix-electrician:server:returnVehicle', NetworkGetNetworkIdFromEntity(State.vehicle), State.plate)
end

local function startShift()
    if State.shift then notify('You are already on shift.', 'error'); return end
    if not hasAccess() then notify('No electrician role exists in your primary or multijob records.', 'error'); return end
    TriggerServerEvent('civix-electrician:server:startShift')
end

local function collectSupplies()
    if not State.shift then notify('Start a shift first.', 'error'); return end
    TriggerServerEvent('civix-electrician:server:collectSupplies')
end

local function endShift()
    if State.vehicle ~= 0 and DoesEntityExist(State.vehicle) then notify('Return the utility truck before ending shift.', 'error'); return end
    TriggerServerEvent('civix-electrician:server:endShift')
end

local function createDispatcher()
    if State.dispatcher ~= 0 and DoesEntityExist(State.dispatcher) then return end
    local model = loadModel(Config.Dispatcher.model)
    if not model then return end
    local c = Config.Dispatcher.coords
    State.dispatcher = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(State.dispatcher, true)
    SetBlockingOfNonTemporaryEvents(State.dispatcher, true)
    FreezeEntityPosition(State.dispatcher, true)
    TaskStartScenarioInPlace(State.dispatcher, Config.Dispatcher.scenario, 0, true)
    SetModelAsNoLongerNeeded(model)
    local options = {
        { name = 'civix-electrician-start', label = 'Start field-service shift', icon = 'fas fa-clipboard-check', action = startShift, onSelect = startShift, canInteract = function() return not State.shift end },
        { name = 'civix-electrician-supplies', label = 'Collect company supplies', icon = 'fas fa-toolbox', action = collectSupplies, onSelect = collectSupplies, canInteract = function() return State.shift and not State.supplies end },
        { name = 'civix-electrician-truck', label = 'Request utility truck', icon = 'fas fa-truck', action = spawnVehicle, onSelect = spawnVehicle, canInteract = function() return State.shift and (State.vehicle == 0 or not DoesEntityExist(State.vehicle)) end },
        { name = 'civix-electrician-return', label = 'Return utility truck', icon = 'fas fa-warehouse', action = requestVehicleReturn, onSelect = requestVehicleReturn, canInteract = function() return State.shift and State.vehicle ~= 0 and DoesEntityExist(State.vehicle) end },
        { name = 'civix-electrician-end', label = 'End field-service shift', icon = 'fas fa-stop-circle', action = endShift, onSelect = endShift, canInteract = function() return State.shift end },
    }
    if not addLocalEntity(State.dispatcher, { id = 'civix-electrician-dispatcher', distance = 8.0, interactDst = 2.0, options = options }) then
        addInteraction({ id = 'civix-electrician-dispatcher', coords = vector3(c.x, c.y, c.z), distance = 8.0, interactDst = 2.0, options = options })
    end
end

RegisterNetEvent('civix-electrician:client:shiftStarted', function(route, profile)
    State.shift, State.supplies, State.route, State.profile = true, false, route or {}, profile or {}
    activateStop(1)
    notify(('Field-service route issued: %d repairs.'):format(#State.route), 'success', 6500)
end)

RegisterNetEvent('civix-electrician:client:suppliesCollected', function()
    State.supplies = true
    notify('Company tools and repair materials were issued.', 'success')
end)

RegisterNetEvent('civix-electrician:client:replaceStop', function(index, location)
    if not State.shift or index ~= State.index then return end
    State.route[index] = location
    State.active = location
    State.active.anchor = location.anchor or location.coords
    State.active.coords = State.active.anchor
    State.active.resolved = false
    clearCabinet()
    setRouteBlip(State.active.anchor, false)
    sendHud('Alternate service area assigned')
end)

RegisterNetEvent('civix-electrician:client:openWiring', function(data)
    if not State.shift or not State.active or State.minigame then return end
    State.active.faultLabel = data.faultLabel
    State.minigame = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMinigame', token = data.token, fault = data.faultLabel, expectedVoltage = data.expectedVoltage, difficulty = data.difficulty, timeLimit = Config.MaxMinigameSeconds })
    sendHud('Circuit isolated. Complete the conductor repair.')
end)

RegisterNetEvent('civix-electrician:client:stopComplete', function(data)
    State.minigame = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    if data.profile then State.profile = data.profile end
    repairAnimation(2200)
    notify(('Repair complete: $%d deposited | +%d XP'):format(data.pay or 0, data.xp or 0), 'success', 6500)
    activateStop(data.nextIndex or (State.index + 1))
end)

RegisterNetEvent('civix-electrician:client:stopFailed', function(message, retry)
    State.minigame = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    sendHud(retry and 'Safety reset active. Reinspect when ready.' or 'Work order failed')
    notify(message or 'The repair failed.', 'error', 6000)
end)

RegisterNetEvent('civix-electrician:client:vehicleReturnApproved', function()
    if State.vehicle ~= 0 and DoesEntityExist(State.vehicle) then
        keyRemove(State.vehicle)
        SetEntityAsMissionEntity(State.vehicle, true, true)
        DeleteVehicle(State.vehicle)
    end
    State.vehicle, State.plate = 0, nil
    notify('Utility truck returned.', 'success')
end)

local function resetState(summary)
    clearCabinet()
    clearBlip()
    State.shift, State.supplies, State.route, State.index, State.active = false, false, {}, 0, nil
    State.minigame = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    sendHud()
    if summary then notify(('Shift closed: %d repairs | $%d earned | %d XP'):format(summary.repairs or 0, summary.earnings or 0, summary.xp or 0), 'success', 7500) end
end

RegisterNetEvent('civix-electrician:client:shiftEnded', resetState)
RegisterNetEvent('civix-electrician:client:forceCleanup', function()
    if State.vehicle ~= 0 and DoesEntityExist(State.vehicle) then keyRemove(State.vehicle); DeleteVehicle(State.vehicle) end
    State.vehicle, State.plate = 0, nil
    resetState(nil)
end)

RegisterNUICallback('wiringResult', function(data, cb)
    if not State.minigame then cb({ ok = false }); return end
    State.minigame = false
    SetNuiFocus(false, false)
    TriggerServerEvent('civix-electrician:server:finishStop', {
        token = data.token,
        success = data.success == true,
        score = tonumber(data.score) or 0,
        mistakes = tonumber(data.mistakes) or 0,
        elapsed = tonumber(data.elapsed) or 0,
    })
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    if State.minigame then
        State.minigame = false
        SetNuiFocus(false, false)
        TriggerServerEvent('civix-electrician:server:finishStop', { success = false, score = 0, mistakes = 99, elapsed = 0 })
    end
    cb({ ok = true })
end)

RegisterCommand('electriciancancel', function() if State.shift then TriggerServerEvent('civix-electrician:server:cancelShift') end end, false)
RegisterCommand('electricianui', function() State.minigame = false; SetNuiFocus(false, false); SendNUIMessage({ action = 'closeMinigame' }) end, false)

CreateThread(function()
    createDispatcher()
    while true do
        local sleep = 1000
        if State.shift and State.active then
            local pedCoords = GetEntityCoords(PlayerPedId())
            local target = State.active.resolved and vector3(State.active.coords.x, State.active.coords.y, State.active.coords.z) or vector3(State.active.anchor.x, State.active.anchor.y, State.active.anchor.z)
            local distance = #(pedCoords - target)
            if not State.active.resolved and distance <= 120.0 then resolveCurrentStop() end
            if distance < 80.0 then
                sleep = 0
                if Config.DrawIndicators then
                    DrawMarker(2, target.x, target.y, target.z + 1.25, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.25, 0.25, 0.25, 255, 190, 48, 210, false, true, 2, false, nil, nil, false)
                    if State.active.resolved then DrawMarker(0, target.x, target.y, target.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 255, 190, 48, 140, false, true, 2, false, nil, nil, false) end
                end
                if State.fallback and distance <= Config.InteractionDistance and not State.minigame then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to inspect the electrical cabinet')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then inspectCabinet() end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if State.shift then sendHud() end
        if State.vehicle ~= 0 and not DoesEntityExist(State.vehicle) then State.vehicle, State.plate = 0, nil end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    clearCabinet()
    clearBlip()
    if State.dispatcher ~= 0 and DoesEntityExist(State.dispatcher) then DeletePed(State.dispatcher) end
    if State.vehicle ~= 0 and DoesEntityExist(State.vehicle) then keyRemove(State.vehicle); DeleteVehicle(State.vehicle) end
end)