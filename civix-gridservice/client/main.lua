local Civix = exports['civix-core']:GetCoreObject()

local Job = {
    dispatcher = 0,
    shift = false,
    suppliesCollected = false,
    route = {},
    routeIndex = 0,
    active = nil,
    activeObject = 0,
    activeObjectCoords = nil,
    activeObjectModel = nil,
    targetInteraction = nil,
    targetFallback = false,
    routeBlip = nil,
    serviceVehicle = 0,
    servicePlate = nil,
    minigameOpen = false,
    lastObjectScan = 0,
    profile = { xp = 0, level = 1, rank = 'Grid Apprentice' }
}

local ElectricalModelSet = {}
for _, model in ipairs(Config.ElectricalModels) do
    ElectricalModelSet[model] = true
end

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
    if type(job) ~= 'table' then return -1 end
    if type(job.grade) == 'table' then
        return tonumber(job.grade.level or job.grade.grade or 0) or 0
    end
    return tonumber(job.grade or 0) or 0
end

local function jobMatches(job, key)
    if type(job) ~= 'table' then return key == Config.JobName end
    local name = job.name or job.id or job.job or key
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
        data.charinfo and data.charinfo.jobs
    }

    for _, jobs in ipairs(candidates) do
        if type(jobs) == 'table' then
            for key, value in pairs(jobs) do
                if jobMatches(value, key) then return true end
            end
        end
    end

    return false
end

local function addInteraction(payload)
    local ok = pcall(function()
        exports['civix-interact']:AddInteraction(payload)
    end)
    if ok then return true end

    ok = pcall(function()
        exports['civix-interact']:addInteraction(payload)
    end)
    return ok
end

local function addLocalEntityInteraction(entity, payload)
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

local function trimPlate(plate)
    return (plate or ''):gsub('^%s*(.-)%s*$', '%1')
end

local function giveVehicleKeys(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    Job.servicePlate = plate

    local attempts = {
        function() exports['civix-vehiclekeys']:GiveKeys(plate) end,
        function() exports['civix-vehiclekeys']:AddKeys(plate) end,
        function() exports['civix-vehiclekeys']:SetOwner(plate) end,
        function() exports['civix-vehiclekeys']:GiveVehicleKeys(vehicle) end
    }

    for _, attempt in ipairs(attempts) do
        if pcall(attempt) then return end
    end

    TriggerEvent('civix-vehiclekeys:client:AddKeys', plate)
    TriggerServerEvent('civix-vehiclekeys:server:AcquireVehicleKeys', plate)
end

local function removeVehicleKeys(vehicle)
    local plate = Job.servicePlate
    if not plate and vehicle ~= 0 and DoesEntityExist(vehicle) then
        plate = trimPlate(GetVehicleNumberPlateText(vehicle))
    end
    if not plate then return end

    local attempts = {
        function() exports['civix-vehiclekeys']:RemoveKeys(plate) end,
        function() exports['civix-vehiclekeys']:RevokeKeys(plate) end,
        function() exports['civix-vehiclekeys']:RemoveVehicleKeys(plate) end
    }

    for _, attempt in ipairs(attempts) do
        if pcall(attempt) then break end
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

local function updateRouteBlip(coords, label)
    deleteRouteBlip()
    if not Config.Route.routeBlip or not coords then return end

    Job.routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(Job.routeBlip, 354)
    SetBlipColour(Job.routeBlip, 47)
    SetBlipScale(Job.routeBlip, 0.82)
    SetBlipRoute(Job.routeBlip, true)
    SetBlipRouteColour(Job.routeBlip, 47)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Grid service work order')
    EndTextCommandSetBlipName(Job.routeBlip)
end

local function updateHud(status)
    if not Job.shift then
        SendNUIMessage({ action = 'hud', visible = false })
        return
    end

    local target = Job.activeObjectCoords or (Job.active and Job.active.center)
    local distance = nil
    if target then
        distance = math.floor(#(GetEntityCoords(PlayerPedId()) - vector3(target.x, target.y, target.z)))
    end

    SendNUIMessage({
        action = 'hud',
        visible = true,
        stop = Job.routeIndex,
        total = #Job.route,
        district = Job.active and Job.active.district or 'Contractor yard',
        label = Job.active and Job.active.label or 'Return assigned utility truck',
        fault = Job.active and (Job.active.faultLabel or 'Diagnosis pending') or 'Route complete',
        distance = distance,
        status = status or (Job.activeObject ~= 0 and 'Electrical cabinet located' or 'Scan the highlighted work zone'),
        rank = Job.profile.rank,
        xp = Job.profile.xp
    })
end

local function clearCabinetTarget()
    if Job.targetInteraction then
        removeInteraction(Job.targetInteraction, Job.activeObject)
    end

    Job.activeObject = 0
    Job.activeObjectCoords = nil
    Job.activeObjectModel = nil
    Job.targetInteraction = nil
    Job.targetFallback = false
end

local function isObjectInsideActiveZone(entity)
    if not Job.active or entity == 0 or not DoesEntityExist(entity) then return false end
    if not ElectricalModelSet[GetEntityModel(entity)] then return false end

    local coords = GetEntityCoords(entity)
    local center = vector3(Job.active.center.x, Job.active.center.y, Job.active.center.z)
    return #(coords - center) <= Job.active.radius
end

local function findActualElectricalCabinet()
    if not Job.active then return 0 end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local center = vector3(Job.active.center.x, Job.active.center.y, Job.active.center.z)
    local bestEntity = 0
    local bestScore = math.huge

    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object) and ElectricalModelSet[GetEntityModel(object)] then
            local coords = GetEntityCoords(object)
            local zoneDistance = #(coords - center)
            if zoneDistance <= Job.active.radius then
                local playerDistance = #(coords - pedCoords)
                local score = playerDistance + (zoneDistance * 0.12)
                if score < bestScore then
                    bestEntity = object
                    bestScore = score
                end
            end
        end
    end

    return bestEntity
end

local function serviceVehicleNearby()
    if not Config.Vehicle.requiredAtWorksite then return true end
    if Job.serviceVehicle == 0 or not DoesEntityExist(Job.serviceVehicle) then return false end
    return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(Job.serviceVehicle)) <= Config.Vehicle.worksiteRadius
end

local function playInspectionAnimation(duration)
    local ped = PlayerPedId()
    if Job.activeObjectCoords then
        TaskTurnPedToFaceCoord(ped, Job.activeObjectCoords.x, Job.activeObjectCoords.y, Job.activeObjectCoords.z, 700)
        Wait(650)
    end

    RequestAnimDict('amb@world_human_vehicle_mechanic@male@base')
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded('amb@world_human_vehicle_mechanic@male@base') and GetGameTimer() < timeout do
        Wait(20)
    end

    FreezeEntityPosition(ped, true)
    if HasAnimDictLoaded('amb@world_human_vehicle_mechanic@male@base') then
        TaskPlayAnim(ped, 'amb@world_human_vehicle_mechanic@male@base', 'base', 3.0, 3.0, duration, 1, 0.0, false, false, false)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_WELDING', 0, true)
    end

    Wait(duration)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
end

local function beginInspection()
    if not Job.shift or not Job.active or Job.minigameOpen then return end
    if Job.activeObject == 0 or not DoesEntityExist(Job.activeObject) then
        notify('The assigned electrical cabinet is no longer streamed. Move through the work zone to locate another cabinet.', 'error')
        clearCabinetTarget()
        return
    end
    if not isObjectInsideActiveZone(Job.activeObject) then
        notify('This cabinet is outside the assigned grid-service zone.', 'error')
        clearCabinetTarget()
        return
    end
    if not serviceVehicleNearby() then
        notify(('Bring the assigned utility truck within %d metres of the cabinet.'):format(Config.Vehicle.worksiteRadius), 'error')
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        notify('Exit the vehicle before inspecting the electrical cabinet.', 'error')
        return
    end

    updateHud('Applying lockout tag and testing incoming voltage')
    playInspectionAnimation(4300)

    local coords = GetEntityCoords(Job.activeObject)
    TriggerServerEvent('civix-gridservice:server:beginStop', {
        routeIndex = Job.routeIndex,
        model = GetEntityModel(Job.activeObject),
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })
end

local function registerCabinetTarget(entity)
    clearCabinetTarget()
    if entity == 0 or not DoesEntityExist(entity) then return false end

    Job.activeObject = entity
    Job.activeObjectCoords = GetEntityCoords(entity)
    Job.activeObjectModel = GetEntityModel(entity)

    local id = ('civix-gridservice-cabinet-%s-%s'):format(Job.routeIndex, Job.active.id)
    Job.targetInteraction = id

    local option = {
        name = id,
        id = id,
        label = 'Inspect grid service cabinet',
        icon = 'fas fa-bolt',
        distance = Config.Route.interactionDistance,
        canInteract = function()
            return Job.shift and Job.active ~= nil and not Job.minigameOpen
        end,
        action = beginInspection,
        onSelect = beginInspection,
        event = 'civix-gridservice:client:inspect'
    }

    local added = addLocalEntityInteraction(entity, {
        id = id,
        distance = 8.0,
        interactDst = Config.Route.interactionDistance,
        options = { option }
    })

    Job.targetFallback = not added
    updateRouteBlip(Job.activeObjectCoords, ('Grid cabinet %d/%d'):format(Job.routeIndex, #Job.route))
    updateHud('Actual electrical cabinet located')
    return true
end

local function scanForCabinet(force)
    if not Job.shift or not Job.active or Job.activeObject ~= 0 then return end

    local now = GetGameTimer()
    if not force and now - Job.lastObjectScan < Config.Route.rescanInterval then return end
    Job.lastObjectScan = now

    local center = vector3(Job.active.center.x, Job.active.center.y, Job.active.center.z)
    if #(GetEntityCoords(PlayerPedId()) - center) > Config.Route.scanDistance then return end

    local entity = findActualElectricalCabinet()
    if entity ~= 0 then
        registerCabinetTarget(entity)
    else
        updateHud('Drive slowly through the zone while the grid cabinet scanner searches')
    end
end

local function activateStop(index)
    clearCabinetTarget()
    Job.routeIndex = index
    Job.active = Job.route[index]
    Job.lastObjectScan = 0

    if not Job.active then
        deleteRouteBlip()
        updateHud('Route complete. Return the utility truck to the contractor yard.')
        SetNewWaypoint(Config.Vehicle.returnPoint.x, Config.Vehicle.returnPoint.y)
        notify('All grid service repairs are complete. Return the assigned utility truck.', 'success', 7000)
        return
    end

    updateRouteBlip(Job.active.center, ('Grid service zone %d/%d'):format(index, #Job.route))
    updateHud('Travel to the highlighted work zone')
end

local function spawnServiceVehicle()
    if not Job.shift then
        notify('Start a grid service shift before requesting a vehicle.', 'error')
        return
    end
    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        notify('Your assigned utility truck is already active.', 'error')
        return
    end
    if IsAnyVehicleNearPoint(Config.Vehicle.spawn.x, Config.Vehicle.spawn.y, Config.Vehicle.spawn.z, 3.0) then
        notify('The utility vehicle bay is blocked.', 'error')
        return
    end

    local model = loadModel(Config.Vehicle.model)
    if not model then
        notify('The configured utility truck could not be loaded.', 'error')
        return
    end

    local function finish(vehicle)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            notify('Unable to create the assigned utility truck.', 'error')
            return
        end

        Job.serviceVehicle = vehicle
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleEngineOn(vehicle, false, true, false)
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDirtLevel(vehicle, 0.0)
        SetVehicleFuelLevel(vehicle, Config.Vehicle.fuel)
        SetVehicleLivery(vehicle, Config.Vehicle.livery)

        local plate = ('%s%03d'):format(Config.Vehicle.platePrefix, math.random(100, 999))
        SetVehicleNumberPlateText(vehicle, plate)
        giveVehicleKeys(vehicle)
        SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
        SetModelAsNoLongerNeeded(model)
        TriggerServerEvent('civix-gridservice:server:vehicleIssued', trimPlate(plate))
        notify('Grid service utility truck assigned. Vehicle keys were issued.', 'success')
    end

    if Civix and Civix.Functions and Civix.Functions.SpawnVehicle then
        Civix.Functions.SpawnVehicle(Config.Vehicle.model, finish, Config.Vehicle.spawn, true)
    else
        local vehicle = CreateVehicle(model, Config.Vehicle.spawn.x, Config.Vehicle.spawn.y, Config.Vehicle.spawn.z, Config.Vehicle.spawn.w, true, false)
        finish(vehicle)
    end
end

local function returnServiceVehicle()
    if Job.serviceVehicle == 0 or not DoesEntityExist(Job.serviceVehicle) then
        notify('There is no assigned utility truck to return.', 'error')
        return
    end

    if #(GetEntityCoords(Job.serviceVehicle) - Config.Vehicle.returnPoint) > Config.Vehicle.returnRadius then
        notify('Park the assigned utility truck inside the marked return bay.', 'error')
        return
    end

    removeVehicleKeys(Job.serviceVehicle)
    SetEntityAsMissionEntity(Job.serviceVehicle, true, true)
    DeleteVehicle(Job.serviceVehicle)
    Job.serviceVehicle = 0
    Job.servicePlate = nil
    TriggerServerEvent('civix-gridservice:server:vehicleReturned')
    notify('Grid service utility truck returned.', 'success')
end

local function startShift()
    if Job.shift then
        notify('You are already working a grid service shift.', 'error')
        return
    end
    if not hasJobAccess() then
        notify('Grid Service Technician is not present in your primary or multijob records.', 'error')
        return
    end
    TriggerServerEvent('civix-gridservice:server:startShift')
end

local function collectSupplies()
    if not Job.shift then
        notify('Start a shift before collecting company equipment.', 'error')
        return
    end
    TriggerServerEvent('civix-gridservice:server:collectSupplies')
end

local function endShift()
    if not Job.shift then return end
    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        notify('Return the assigned utility truck before ending the shift.', 'error')
        return
    end
    TriggerServerEvent('civix-gridservice:server:endShift')
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
        { name = 'civix-gridservice-start', label = 'Start grid service shift', icon = 'fas fa-clipboard-check', action = startShift, onSelect = startShift, canInteract = function() return not Job.shift end },
        { name = 'civix-gridservice-supplies', label = 'Collect grid service equipment', icon = 'fas fa-toolbox', action = collectSupplies, onSelect = collectSupplies, canInteract = function() return Job.shift and not Job.suppliesCollected end },
        { name = 'civix-gridservice-vehicle', label = 'Request utility truck', icon = 'fas fa-truck', action = spawnServiceVehicle, onSelect = spawnServiceVehicle, canInteract = function() return Job.shift and (Job.serviceVehicle == 0 or not DoesEntityExist(Job.serviceVehicle)) end },
        { name = 'civix-gridservice-return', label = 'Return utility truck', icon = 'fas fa-warehouse', action = returnServiceVehicle, onSelect = returnServiceVehicle, canInteract = function() return Job.shift and Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) end },
        { name = 'civix-gridservice-end', label = 'End grid service shift', icon = 'fas fa-stop-circle', action = endShift, onSelect = endShift, canInteract = function() return Job.shift end }
    }

    local added = addLocalEntityInteraction(Job.dispatcher, {
        id = 'civix-gridservice-dispatcher',
        distance = 8.0,
        interactDst = 2.0,
        options = options
    })

    if not added then
        addInteraction({
            id = 'civix-gridservice-dispatcher',
            coords = vector3(c.x, c.y, c.z),
            distance = 8.0,
            interactDst = 2.0,
            options = options
        })
    end
end

RegisterNetEvent('civix-gridservice:client:inspect', beginInspection)

RegisterNetEvent('civix-gridservice:client:shiftStarted', function(data)
    Job.shift = true
    Job.suppliesCollected = false
    Job.route = data.route or {}
    Job.profile = data.profile or Job.profile
    activateStop(1)
    notify(('Grid service shift started. %d repair zones were assigned.'):format(#Job.route), 'success', 7000)
end)

RegisterNetEvent('civix-gridservice:client:suppliesCollected', function()
    Job.suppliesCollected = true
    notify('Grid service equipment was loaded into your inventory.', 'success')
end)

RegisterNetEvent('civix-gridservice:client:openWiring', function(data)
    if not Job.shift or not Job.active then return end

    Job.active.faultLabel = data.faultLabel
    Job.minigameOpen = true
    updateHud('Circuit isolated. Connect each conductor to the matching terminal.')
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMinigame',
        fault = data.faultLabel,
        expectedVoltage = data.expectedVoltage,
        difficulty = data.difficulty,
        token = data.token,
        timeLimit = Config.Security.maximumMinigameSeconds
    })
end)

RegisterNetEvent('civix-gridservice:client:stopComplete', function(data)
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    playInspectionAnimation(2200)

    Job.profile = data.profile or Job.profile
    notify(('Grid repair complete: $%d deposited | +%d XP'):format(data.pay or 0, data.xpAwarded or 0), 'success', 6500)
    activateStop(data.nextIndex or (Job.routeIndex + 1))
end)

RegisterNetEvent('civix-gridservice:client:stopFailed', function(message, retryAllowed)
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
    updateHud(retryAllowed and 'Safety reset active. Reinspect the cabinet after the cooldown.' or 'This work order has failed.')
    notify(message or 'The grid repair failed validation.', 'error', 6500)
end)

RegisterNetEvent('civix-gridservice:client:shiftEnded', function(summary)
    clearCabinetTarget()
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
        notify(('Grid service shift closed: %d repairs | $%d earned | %d XP'):format(summary.repairs or 0, summary.earnings or 0, summary.xp or 0), 'success', 8000)
    end
end)

RegisterNetEvent('civix-gridservice:client:forceCleanup', function()
    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        removeVehicleKeys(Job.serviceVehicle)
        DeleteVehicle(Job.serviceVehicle)
    end

    Job.serviceVehicle = 0
    Job.servicePlate = nil
    clearCabinetTarget()
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
end)

RegisterNUICallback('wiringResult', function(data, cb)
    if not Job.minigameOpen then
        cb({ ok = false })
        return
    end

    Job.minigameOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('civix-gridservice:server:finishStop', {
        token = data.token,
        success = data.success == true,
        score = tonumber(data.score) or 0,
        mistakes = tonumber(data.mistakes) or 0,
        elapsed = tonumber(data.elapsed) or 0
    })
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    if Job.minigameOpen then
        Job.minigameOpen = false
        SetNuiFocus(false, false)
        TriggerServerEvent('civix-gridservice:server:finishStop', {
            success = false,
            score = 0,
            mistakes = 99,
            elapsed = 0
        })
    end
    cb({ ok = true })
end)

RegisterCommand('gridservicecancel', function()
    if Job.shift then
        TriggerServerEvent('civix-gridservice:server:cancelShift')
    end
end, false)

RegisterCommand('gridserviceui', function()
    Job.minigameOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMinigame' })
end, false)

CreateThread(function()
    SendNUIMessage({ action = 'hud', visible = false })
    SendNUIMessage({ action = 'closeMinigame' })
    createDispatcher()

    while true do
        local sleep = 1000

        if Job.shift and Job.active then
            local pedCoords = GetEntityCoords(PlayerPedId())
            local center = vector3(Job.active.center.x, Job.active.center.y, Job.active.center.z)
            local zoneDistance = #(pedCoords - center)

            if zoneDistance <= Config.Route.scanDistance then
                sleep = 0
                scanForCabinet(false)

                if Config.Route.drawZoneIndicator and Job.activeObject == 0 then
                    DrawMarker(1, center.x, center.y, center.z - 1.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Job.active.radius * 2.0, Job.active.radius * 2.0, 1.2, 255, 190, 48, 24, false, false, 2, false, nil, nil, false)
                    DrawMarker(2, center.x, center.y, center.z + 1.25, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.28, 0.28, 0.28, 255, 190, 48, 210, false, true, 2, false, nil, nil, false)
                end

                if Job.activeObject ~= 0 and DoesEntityExist(Job.activeObject) then
                    Job.activeObjectCoords = GetEntityCoords(Job.activeObject)
                    local distance = #(pedCoords - Job.activeObjectCoords)

                    if Config.Route.drawCabinetIndicator and distance <= 35.0 then
                        DrawMarker(2, Job.activeObjectCoords.x, Job.activeObjectCoords.y, Job.activeObjectCoords.z + 1.25, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.24, 0.24, 0.24, 255, 190, 48, 220, false, true, 2, false, nil, nil, false)
                    end

                    if Job.targetFallback and distance <= Config.Route.interactionDistance and not Job.minigameOpen then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to inspect the grid service cabinet')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustReleased(0, 38) then
                            beginInspection()
                        end
                    end
                elseif Job.activeObject ~= 0 then
                    clearCabinetTarget()
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(750)
        if Job.shift then updateHud() end
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
    clearCabinetTarget()
    deleteRouteBlip()

    if Job.dispatcher ~= 0 and DoesEntityExist(Job.dispatcher) then
        DeletePed(Job.dispatcher)
    end

    if Job.serviceVehicle ~= 0 and DoesEntityExist(Job.serviceVehicle) then
        removeVehicleKeys(Job.serviceVehicle)
        DeleteVehicle(Job.serviceVehicle)
    end
end)
