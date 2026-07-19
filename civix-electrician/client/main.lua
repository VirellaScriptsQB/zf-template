local Civix = exports['civix-core']:GetCoreObject()

local Job = {
    dispatcher = 0,
    shift = false,
    suppliesCollected = false,
    route = {},
    routeIndex = 0,
    active = nil,
    activeObject = 0,
    targetInteraction = nil,
    routeBlip = nil,
    serviceVehicle = 0,
    servicePlate = nil,
    minigameOpen = false,
    fallbackTarget = false,
}

local function notify(message, kind, duration)
    kind = kind or 'primary'
    duration = duration or 5000

    local ok = pcall(function()
        exports['civix-notify']:Notify(message, kind, duration)
    end)
    if ok then return end

    ok = pcall(function()
        exports['civix-notify']:SendNotification(message, kind, duration)
    end)
    if ok then return end

    TriggerEvent('civix-notify:client:Notify', message, kind, duration)
end

local function loadModel(model)
    model = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return nil end
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return nil end
        Wait(20)
    end
    return model
end

local function getPlayerData()
    if Civix and Civix.Functions and Civix.Functions.GetPlayerData then
        return Civix.Functions.GetPlayerData() or {}
    end
    local ok, data = pcall(function()
        return exports['civix-core']:GetPlayerData()
    end)
    return ok and data or {}
end

local function gradeValue(job)
    if not job then return -1 end
    if type(job.grade) == 'table' then
        return tonumber(job.grade.level or job.grade.grade or 0) or 0
    end
    return tonumber(job.grade or 0) or 0
end

local function jobMatches(job)
    if type(job) ~= 'table' then return false end
    local name = job.name or job.id or job.job
    if name ~= Config.JobName then return false end
    if gradeValue(job) < Config.MinimumGrade then return false end
    if Config.RequireDuty and job.onduty == false then return false end
    return true
end

local function hasJobAccess()
    if Config.AllowContractors then return true end
    local data = getPlayerData()

    if Config.AllowPrimaryJob and jobMatches(data.job) then return true end
    if not Config.AllowMultiJob then return false end

    local candidates = {
        data.jobs,
        data.multijobs,
        data.metadata and data.metadata.jobs,
        data.metadata and data.metadata.multijobs,
        data.charinfo and data.charinfo.jobs,
    }

    for _, list in ipairs(candidates) do
        if type(list) == 'table' then
            for key, value in pairs(list) do
                if type(value) == 'table' then
                    if not value.name and type(key) == 'string' then value.name = key end
                    if jobMatches(value) then return true end
                elseif type(key) == 'string' and key == Config.JobName then
                    return true
                end
            end
        end
    end

    return false
end

local function tryAddInteraction(payload)
    local ok = pcall(function()
        exports['civix-interact']:AddInteraction(payload)
    end)
    if ok then return true end

    ok = pcall(function()
        exports['civix-interact']:addInteraction(payload)
    end)
    return ok
end

local function tryAddLocalEntity(entity, payload)
    local ok = pcall(function()
        exports['civix-interact']:AddLocalEntityInteraction(entity, payload)
    end)
    if ok then return true end

    ok = pcall(function()
        exports['civix-interact']:AddLocalEntity(entity, payload)
    end)
    if ok then return true end

    ok = pcall(function()
        exports['civix-interact']:addLocalEntityInteraction(entity, payload)
    end)
    return ok
end

local function removeInteraction(id, entity)
    pcall(function() exports['civix-interact']:RemoveInteraction(id) end)
    pcall(function() exports['civix-interact']:removeInteraction(id) end)
    if entity and entity ~= 0 then
        pcall(function() exports['civix-interact']:RemoveLocalEntityInteraction(entity, id) end)
        pcall(function() exports['civix-interact']:RemoveLocalEntity(entity, id) end)
    end
end

local function giveVehicleKeys(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local plate = string.gsub(GetVehicleNumberPlateText(vehicle), '^%s*(.-)%s*$', '%1')
    Job.servicePlate = plate

    local attempts = {
        function() exports['civix-vehiclekeys']:GiveKeys(plate) end,
        function() exports['civix-vehiclekeys']:AddKeys(plate) end,
        function() exports['civix-vehiclekeys']:SetOwner(plate) end,
        function() exports['civix-vehiclekeys']:GiveVehicleKeys(vehicle) end,
    }

    for _, call in ipairs(attempts) do
        local ok = pcall(call)
        if ok then return end
    end

    TriggerEvent('civix-vehiclekeys:client:AddKeys', plate)
    TriggerServerEvent('civix-vehiclekeys:server:AcquireVehicleKeys', plate)
end

local function removeVehicleKeys(vehicle)
    local plate = Job.servicePlate
    if not plate and vehicle ~= 0 and DoesEntityExist(vehicle) then
        plate = string.gsub(GetVehicleNumberPlateText(vehicle), '^%s*(.-)%s*$', '%1')
    end
    if not plate then return end

    local attempts = {
        function() exports['civix-vehiclekeys']:RemoveKeys(plate) end,
        function() exports['civix-vehiclekeys']:RevokeKeys(plate) end,
        function() exports['civix-vehiclekeys']:RemoveVehicleKeys(plate) end,
    }
    for _, call in ipairs(attempts) do
        if pcall(call) then break end
    end

    TriggerEvent('civix-vehiclekeys:client:RemoveKeys', plate)
    TriggerServerEvent('civix-vehiclekeys:server:RemoveKeys', plate)
end

local function deleteRouteBlip()
    if Job.routeBlip and DoesBlipExist(Job.routeBlip) then
        RemoveBlip(Job.routeBlip)
    end
    Job.routeBlip = nil
end

local function updateHud(status)
    if not Job.shift then
        SendNUIMessage({ action = 'hud', visible = false })
        return
    end

    local location = Job.active
    local distance = nil
    if location then
        distance = math.floor(#(GetEntityCoords(PlayerPedId()) - vector3(location.coords.x, location.coords.y, location.coords.z)))
    end

    SendNUIMessage({
        action = 'hud',
        visible = true,
        stop = Job.routeIndex,
        total = #Job.route,
        district = location and location.district or 'Awaiting dispatch',
        label = location and location.label or 'Return to contractor yard',
        fault = location and (location.faultLabel or 'Inspect to diagnose') or 'Route complete',
        distance = distance,
        status = status or (location and 'Travel to service cabinet' or 'Return service vehicle'),
    })
end

local function findElectricalObject(coords)
    local bestEntity, bestDistance = 0, Config.ObjectSearchRadius + 0.01
    for _, model in ipairs(Config.ElectricalModels) do
        local object = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.ObjectSearchRadius, model, false, false, false)
        if object and object ~= 0 and DoesEntityExist(object) then
            local distance = #(GetEntityCoords(object) - coords)
            if distance < bestDistance then
                bestEntity, bestDistance = object, distance
            end
        end
    end
    return bestEntity
end

local function createRouteBlip(location)
    deleteRouteBlip()
    if not Config.RouteBlip or not location then return end

    Job.routeBlip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
    SetBlipSprite(Job.routeBlip, 354)
    SetBlipColour(Job.routeBlip, 47)
    SetBlipScale(Job.routeBlip, 0.82)
    SetBlipRoute(Job.routeBlip, true)
    SetBlipRouteColour(Job.routeBlip, 47)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Electrical work order %d/%d'):format(Job.routeIndex, #Job.route))
    EndTextCommandSetBlipName(Job.routeBlip)
end

local function playRepairAnimation(duration)
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, Job.active.coords.x, Job.active.coords.y, Job.active.coords.z, 750)
    Wait(700)
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

local function isServiceVehicleNearby()
    if not Config.RequireServiceVehicle then return true end
    if Job.serviceVehicle == 0 or not DoesEntityExist(Job.serviceVehicle) then return false end
    return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(Job.serviceVehicle)) <= 45.0
end

local function openWiringMinigame(data)
    if Job.minigameOpen then return end
    Job.minigameOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMinigame',
        fault = data.faultLabel,
        expectedVoltage = data.expectedVoltage,
        difficulty = data.difficulty,
        token = data.token,
        timeLimit = Config.MaxMinigameSeconds,
    })
end

local function clearTarget()
    if Job.targetInteraction then
        removeInteraction(Job.targetInteraction, Job.activeObject)
    end
    Job.targetInteraction = nil
    Job.activeObject = 0
    Job.fallbackTarget = false
end

local function beginInspection()
    if not Job.shift or not Job.active or Job.minigameOpen then return end
    if not isServiceVehicleNearby() then
        notify('Bring the assigned utility truck within 45 metres of the cabinet.', 'error')
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        notify('Exit the vehicle before inspecting the electrical cabinet.', 'error')
        return
    end

    updateHud('Inspecting cabinet and testing incoming voltage')
    playRepairAnimation(4200)
    TriggerServerEvent('civix-electrician:server:beginStop', Job.routeIndex)
end

local function registerTarget(location)
    clearTarget()
    Job.activeObject = findElectricalObject(vector3(location.coords.x, location.coords.y, location.coords.z))
    if Config.RequireActualObject and Job.activeObject == 0 then
        notify('No configured electrical-box prop was found at this service anchor.', 'error')
        return
    end

    local id = ('civix-electrician-box-%s-%s'):format(Job.routeIndex, location.id or Job.routeIndex)
    Job.targetInteraction = id

    local option = {
        name = id,
        id = id,
        label = 'Inspect electrical cabinet',
        icon = 'fas fa-bolt',
        distance = Config.InteractionDistance,
        canInteract = function()
            return Job.shift and Job.active ~= nil and not Job.minigameOpen
        end,
        action = beginInspection,
        onSelect = beginInspection,
        event = 'civix-electrician:client:inspect',
    }

    local added = false
    if Job.activeObject ~= 0 then
        added = tryAddLocalEntity(Job.activeObject, {
            id = id,
            distance = 7.0,
            interactDst = Config.InteractionDistance,
            options = { option },
        })
    end

    if not added then
        added = tryAddInteraction({
            id = id,
            coords = vector3(location.coords.x, location.coords.y, location.coords.z),
            distance = 7.0,
            interactDst = Config.InteractionDistance,
            options = { option },
        })
    end

    Job.fallbackTarget = not added
end

local function activateStop(index)
    Job.routeIndex = index
    Job.active = Job.route[index]
    if not Job.active then
        clearTarget()
        deleteRouteBlip()
        updateHud('Route complete. Return to the contractor yard.')
        SetNewWaypoint(Config.VehicleReturn.x, Config.VehicleReturn.y)
        notify('All assigned repairs are complete. Return the utility truck.', 'success', 7000)
        return
    end

    createRouteBlip(Job.active)
    registerTarget(Job.active)
    updateHud('Travel to service cabinet')
end

local function spawnServiceVehicle()
    if not Job.shift then
        notify('Start an electrician shift before requesting a vehicle.', 'error')
        return
    end
    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        notify('Your assigned utility truck is already active.', 'error')
        return
    end
    if IsAnyVehicleNearPoint(Config.VehicleSpawn.x, Config.VehicleSpawn.y, Config.VehicleSpawn.z, 3.0) then
        notify('The utility vehicle bay is blocked.', 'error')
        return
    end

    local model = loadModel(Config.VehicleModel)
    if not model then
        notify('The configured utility vehicle model could not be loaded.', 'error')
        return
    end

    local function finish(vehicle)
        if not vehicle or vehicle == 0 then
            notify('Unable to create the utility truck.', 'error')
            return
        end
        Job.serviceVehicle = vehicle
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleEngineOn(vehicle, false, true, false)
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDirtLevel(vehicle, 0.0)
        SetVehicleFuelLevel(vehicle, Config.VehicleFuel)
        SetVehicleLivery(vehicle, Config.VehicleLivery)
        local plate = ('CIVX%03d'):format(math.random(100, 999))
        SetVehicleNumberPlateText(vehicle, plate)
        giveVehicleKeys(vehicle)
        SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
        SetModelAsNoLongerNeeded(model)
        notify('Utility truck assigned. Keys have been issued.', 'success')
    end

    if Civix and Civix.Functions and Civix.Functions.SpawnVehicle then
        Civix.Functions.SpawnVehicle(Config.VehicleModel, finish, Config.VehicleSpawn, true)
    else
        local vehicle = CreateVehicle(model, Config.VehicleSpawn.x, Config.VehicleSpawn.y, Config.VehicleSpawn.z, Config.VehicleSpawn.w, true, false)
        finish(vehicle)
    end
end

local function returnServiceVehicle()
    if Job.serviceVehicle == 0 or not DoesEntityExist(Job.serviceVehicle) then
        notify('There is no assigned utility truck to return.', 'error')
        return
    end
    if #(GetEntityCoords(Job.serviceVehicle) - Config.VehicleReturn) > 8.0 then
        notify('Park the assigned utility truck in the return bay.', 'error')
        return
    end

    removeVehicleKeys(Job.serviceVehicle)
    SetEntityAsMissionEntity(Job.serviceVehicle, true, true)
    DeleteVehicle(Job.serviceVehicle)
    Job.serviceVehicle = 0
    Job.servicePlate = nil
    TriggerServerEvent('civix-electrician:server:vehicleReturned')
    notify('Utility truck returned.', 'success')
end

local function startShift()
    if Job.shift then
        notify('You are already on an electrician shift.', 'error')
        return
    end
    if not hasJobAccess() then
        notify('You do not have electrician access in your primary or multijob records.', 'error')
        return
    end
    TriggerServerEvent('civix-electrician:server:startShift')
end

local function collectSupplies()
    if not Job.shift then
        notify('Start a shift before collecting company supplies.', 'error')
        return
    end
    TriggerServerEvent('civix-electrician:server:collectSupplies')
end

local function endShift()
    if not Job.shift then return end
    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        notify('Return the assigned utility truck before ending your shift.', 'error')
        return
    end
    TriggerServerEvent('civix-electrician:server:endShift')
end

local function createDispatcher()
    if Job.dispatcher ~= 0 and DoesEntityExist(Job.dispatcher) then return end
    local model = loadModel(Config.Dispatcher.model)
    if not model then return end

    local c = Config.Dispatcher.coords
    Job.dispatcher = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(Job.dispatcher, true)
    SetBlockingOfNonTemporaryEvents(Job.dispatcher, true)
    FreezeEntityPosition(Job.dispatcher, true)
    TaskStartScenarioInPlace(Job.dispatcher, Config.Dispatcher.scenario, 0, true)
    SetModelAsNoLongerNeeded(model)

    local options = {
        { name = 'civix-electrician-start', label = 'Start field-service shift', icon = 'fas fa-clipboard-check', action = startShift, onSelect = startShift, canInteract = function() return not Job.shift end },
        { name = 'civix-electrician-supplies', label = 'Collect service supplies', icon = 'fas fa-toolbox', action = collectSupplies, onSelect = collectSupplies, canInteract = function() return Job.shift and not Job.suppliesCollected end },
        { name = 'civix-electrician-vehicle', label = 'Request utility truck', icon = 'fas fa-truck', action = spawnServiceVehicle, onSelect = spawnServiceVehicle, canInteract = function() return Job.shift and (Job.serviceVehicle == 0 or not DoesEntityExist(Job.serviceVehicle)) end },
        { name = 'civix-electrician-return', label = 'Return utility truck', icon = 'fas fa-warehouse', action = returnServiceVehicle, onSelect = returnServiceVehicle, canInteract = function() return Job.shift and Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) end },
        { name = 'civix-electrician-end', label = 'End field-service shift', icon = 'fas fa-stop-circle', action = endShift, onSelect = endShift, canInteract = function() return Job.shift end },
    }

    local added = tryAddLocalEntity(Job.dispatcher, {
        id = 'civix-electrician-dispatcher',
        distance = 8.0,
        interactDst = 2.0,
        options = options,
    })

    if not added then
        tryAddInteraction({
            id = 'civix-electrician-dispatcher',
            coords = vector3(c.x, c.y, c.z),
            distance = 8.0,
            interactDst = 2.0,
            options = options,
        })
    end
end

RegisterNetEvent('civix-electrician:client:inspect', beginInspection)

RegisterNetEvent('civix-electrician:client:shiftStarted', function(route)
    Job.shift = true
    Job.suppliesCollected = false
    Job.route = route or {}
    activateStop(1)
    notify(('Field-service shift started. %d electrical repairs assigned.'):format(#Job.route), 'success', 7000)
end)

RegisterNetEvent('civix-electrician:client:suppliesCollected', function()
    Job.suppliesCollected = true
    notify('Company supplies loaded into your inventory.', 'success')
end)

RegisterNetEvent('civix-electrician:client:openWiring', function(data)
    if not Job.shift or not Job.active then return end
    Job.active.faultLabel = data.faultLabel
    updateHud('Circuit isolated. Complete the wiring repair.')
    openWiringMinigame(data)
end)

RegisterNetEvent('civix-electrician:client:stopComplete', function(data)
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    playRepairAnimation(2600)
    notify(('Repair complete: $%d deposited | +%d XP'):format(data.pay or 0, data.xp or 0), 'success', 6500)
    clearTarget()
    activateStop((data.nextIndex or Job.routeIndex + 1))
end)

RegisterNetEvent('civix-electrician:client:stopFailed', function(message, retryAllowed)
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    updateHud(retryAllowed and 'Repair failed. Reinspect after the safety reset.' or 'Work order failed')
    notify(message or 'The repair failed validation.', 'error', 6500)
end)

RegisterNetEvent('civix-electrician:client:shiftEnded', function(summary)
    clearTarget()
    deleteRouteBlip()
    Job.shift = false
    Job.suppliesCollected = false
    Job.route = {}
    Job.routeIndex = 0
    Job.active = nil
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    updateHud()
    if summary then
        notify(('Shift closed: %d repairs | $%d earned | %d XP'):format(summary.repairs or 0, summary.earnings or 0, summary.xp or 0), 'success', 8000)
    else
        notify('Electrician shift ended.', 'primary')
    end
end)

RegisterNetEvent('civix-electrician:client:forceCleanup', function()
    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        removeVehicleKeys(Job.serviceVehicle)
        DeleteVehicle(Job.serviceVehicle)
    end
    Job.serviceVehicle = 0
    Job.servicePlate = nil
    clearTarget()
    deleteRouteBlip()
    Job.shift = false
    Job.route = {}
    Job.active = nil
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    updateHud()
end)

RegisterNUICallback('wiringResult', function(data, cb)
    if not Job.minigameOpen then cb({ ok = false }); return end
    Job.minigameOpen = false
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
    if Job.minigameOpen then
        Job.minigameOpen = false
        SetNuiFocus(false, false)
        TriggerServerEvent('civix-electrician:server:finishStop', { success = false, score = 0, mistakes = 99, elapsed = 0 })
    end
    cb({ ok = true })
end)

RegisterCommand('electriciancancel', function()
    if Job.shift then TriggerServerEvent('civix-electrician:server:cancelShift') end
end, false)

RegisterCommand('electricianui', function()
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
end, false)

CreateThread(function()
    createDispatcher()
    while true do
        local sleep = 1000
        if Job.shift and Job.active then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local target = vector3(Job.active.coords.x, Job.active.coords.y, Job.active.coords.z)
            local distance = #(coords - target)

            if distance < 80.0 then
                sleep = 0
                if Config.DrawIndicators then
                    DrawMarker(2, target.x, target.y, target.z + 1.15, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.24, 0.24, 0.24, 255, 190, 48, 205, false, true, 2, false, nil, nil, false)
                    DrawMarker(0, target.x, target.y, target.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.17, 0.17, 0.17, 255, 190, 48, 130, false, true, 2, false, nil, nil, false)
                end
                if Job.fallbackTarget and distance <= Config.InteractionDistance and not Job.minigameOpen then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to inspect the electrical cabinet')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then beginInspection() end
                end
            end

            updateHud()
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if Job.serviceVehicle ~= 0 and not DoesEntityExist(Job.serviceVehicle) then
            Job.serviceVehicle = 0
            Job.servicePlate = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    clearTarget()
    deleteRouteBlip()
    if Job.dispatcher ~= 0 and DoesEntityExist(Job.dispatcher) then DeletePed(Job.dispatcher) end
    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        removeVehicleKeys(Job.serviceVehicle)
        DeleteVehicle(Job.serviceVehicle)
    end
end)
