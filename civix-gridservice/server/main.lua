local Civix = exports['civix-core']:GetCoreObject()
local Sessions = {}

local ElectricalModelSet = {}
for _, model in ipairs(Config.ElectricalModels) do
    ElectricalModelSet[model] = true
end

local FaultKeys = {}
for key in pairs(Config.Faults) do
    FaultKeys[#FaultKeys + 1] = key
end

local function getPlayer(source)
    if Civix and Civix.Functions and Civix.Functions.GetPlayer then
        return Civix.Functions.GetPlayer(source)
    end
    return nil
end

local function getCitizenId(Player)
    local data = Player and Player.PlayerData or {}
    return data.citizenid or data.citizenId or data.identifier or tostring(data.source or 'unknown')
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

local function hasJobAccess(Player)
    if Config.AllowContractors then return true end
    if not Player or not Player.PlayerData then return false end

    local data = Player.PlayerData
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

local function itemCount(Player, source, item)
    if Player and Player.Functions and Player.Functions.GetItemByName then
        local found = Player.Functions.GetItemByName(item)
        if found then return tonumber(found.amount or found.count or 0) or 0 end
    end

    local attempts = {
        function() return exports['civix-inventory']:GetItemCount(source, item) end,
        function() return exports['civix-inventory']:Search(source, 'count', item) end,
        function() return exports['civix-inventory']:GetItem(source, item) end
    }

    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt)
        if ok and result ~= nil then
            if type(result) == 'number' then return result end
            if type(result) == 'table' then return tonumber(result.amount or result.count or 0) or 0 end
        end
    end

    return 0
end

local function addItem(Player, source, item, amount, metadata)
    if Player and Player.Functions and Player.Functions.AddItem then
        local ok, result = pcall(function()
            return Player.Functions.AddItem(item, amount, false, metadata or {}, 'civix-gridservice')
        end)
        if ok and result ~= false then return true end
    end

    local attempts = {
        function() return exports['civix-inventory']:AddItem(source, item, amount, metadata or {}) end,
        function() return exports['civix-inventory']:addItem(source, item, amount, metadata or {}) end
    }

    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt)
        if ok and result ~= false then return true end
    end

    return false
end

local function removeItem(Player, source, item, amount)
    if amount <= 0 then return true end

    if Player and Player.Functions and Player.Functions.RemoveItem then
        local ok, result = pcall(function()
            return Player.Functions.RemoveItem(item, amount, false, 'civix-gridservice')
        end)
        if ok and result ~= false then return true end
    end

    local attempts = {
        function() return exports['civix-inventory']:RemoveItem(source, item, amount) end,
        function() return exports['civix-inventory']:removeItem(source, item, amount) end
    }

    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt)
        if ok and result ~= false then return true end
    end

    return false
end

local function addBankMoney(Player, amount, reason)
    if not Player or amount <= 0 then return false end
    if Player.Functions and Player.Functions.AddMoney then
        local ok, result = pcall(function()
            return Player.Functions.AddMoney('bank', amount, reason or 'grid-service-contract')
        end)
        return ok and result ~= false
    end
    return false
end

local function shuffledCopy(input)
    local output = {}
    for i = 1, #input do output[i] = input[i] end
    for i = #output, 2, -1 do
        local j = math.random(i)
        output[i], output[j] = output[j], output[i]
    end
    return output
end

local function randomToken(source)
    return ('GRID-%s-%s-%s'):format(source, os.time(), math.random(100000, 999999))
end

local function progressionForXp(xp)
    local selected = Config.Progression[1]
    for _, rank in ipairs(Config.Progression) do
        if xp >= rank.xp then selected = rank end
    end
    return selected
end

local function loadProfile(citizenid)
    local row = MySQL.single.await('SELECT `xp`, `completed_repairs`, `failed_repairs`, `total_earnings` FROM `civix_gridservice_progress` WHERE `citizenid` = ?', { citizenid })
    if not row then
        MySQL.insert.await('INSERT INTO `civix_gridservice_progress` (`citizenid`, `xp`, `completed_repairs`, `failed_repairs`, `total_earnings`) VALUES (?, 0, 0, 0, 0)', { citizenid })
        row = { xp = 0, completed_repairs = 0, failed_repairs = 0, total_earnings = 0 }
    end

    row.xp = tonumber(row.xp) or 0
    local rank = progressionForXp(row.xp)
    row.level = rank.level
    row.rank = rank.label
    return row
end

local function saveRepairProgress(citizenid, xpAwarded, payment, failed)
    MySQL.update.await([[
        INSERT INTO `civix_gridservice_progress`
            (`citizenid`, `xp`, `completed_repairs`, `failed_repairs`, `total_earnings`)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `xp` = `xp` + VALUES(`xp`),
            `completed_repairs` = `completed_repairs` + VALUES(`completed_repairs`),
            `failed_repairs` = `failed_repairs` + VALUES(`failed_repairs`),
            `total_earnings` = `total_earnings` + VALUES(`total_earnings`),
            `updated_at` = CURRENT_TIMESTAMP
    ]], {
        citizenid,
        xpAwarded or 0,
        failed and 0 or 1,
        failed and 1 or 0,
        payment or 0
    })
end

local function buildRoute()
    local zones = shuffledCopy(Config.WorkZones)
    local count = math.random(Config.Route.minimumStops, Config.Route.maximumStops)
    count = math.min(count, #zones)

    local route = {}
    for index = 1, count do
        local zone = zones[index]
        local faultKey = FaultKeys[math.random(#FaultKeys)]
        route[index] = {
            id = zone.id,
            label = zone.label,
            district = zone.district,
            center = { x = zone.center.x, y = zone.center.y, z = zone.center.z },
            radius = zone.radius,
            faultKey = faultKey,
            failures = 0,
            complete = false
        }
    end

    return route
end

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function distanceBetween(a, b)
    local dx = (a.x or 0.0) - (b.x or 0.0)
    local dy = (a.y or 0.0) - (b.y or 0.0)
    local dz = (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function hasRequiredEquipment(Player, source, fault)
    for _, item in ipairs(Config.RequiredTools) do
        if itemCount(Player, source, item) < 1 then
            return false, item
        end
    end

    if itemCount(Player, source, fault.requiredItem) < fault.requiredAmount then
        return false, fault.requiredItem
    end

    return true
end

local function cleanupIssuedEquipment(source, session)
    if not session or not session.issued then return end
    local Player = getPlayer(source)
    if not Player then return end

    for item, issuedAmount in pairs(session.issued) do
        local consumed = session.consumed[item] or 0
        local remainingIssued = math.max(0, issuedAmount - consumed)
        local available = itemCount(Player, source, item)
        local removeAmount = math.min(remainingIssued, available)
        if removeAmount > 0 then removeItem(Player, source, item, removeAmount) end
    end
end

local function shiftSummary(session)
    return {
        repairs = session.repairs or 0,
        earnings = session.earnings or 0,
        xp = session.xpEarned or 0
    }
end

RegisterNetEvent('civix-gridservice:server:startShift', function()
    local source = source
    if Sessions[source] then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'You already have an active grid service shift.', true)
        return
    end

    local Player = getPlayer(source)
    if not Player or not hasJobAccess(Player) then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'Grid Service Technician access was not found in your job records.', false)
        return
    end

    local citizenid = getCitizenId(Player)
    local profile = loadProfile(citizenid)
    local route = buildRoute()

    Sessions[source] = {
        citizenid = citizenid,
        route = route,
        index = 1,
        startedAt = os.time(),
        suppliesCollected = false,
        vehicleIssued = false,
        vehicleReturned = false,
        routeBonusPaid = false,
        pending = nil,
        cooldownUntil = 0,
        issued = {},
        consumed = {},
        repairs = 0,
        earnings = 0,
        xpEarned = 0
    }

    TriggerClientEvent('civix-gridservice:client:shiftStarted', source, {
        route = route,
        profile = profile
    })
end)

RegisterNetEvent('civix-gridservice:server:collectSupplies', function()
    local source = source
    local session = Sessions[source]
    local Player = getPlayer(source)
    if not session or not Player then return end
    if session.suppliesCollected then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'Company equipment has already been issued for this shift.', true)
        return
    end

    local added = {}
    for item, amount in pairs(Config.SupplyLoadout) do
        local metadata = {
            companyIssued = true,
            department = 'gridservice',
            shiftStarted = session.startedAt
        }
        if not addItem(Player, source, item, amount, metadata) then
            for rollbackItem, rollbackAmount in pairs(added) do
                removeItem(Player, source, rollbackItem, rollbackAmount)
            end
            TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'Your inventory could not hold the complete grid service loadout.', true)
            return
        end
        added[item] = amount
    end

    session.suppliesCollected = true
    session.issued = added
    TriggerClientEvent('civix-gridservice:client:suppliesCollected', source)
end)

RegisterNetEvent('civix-gridservice:server:vehicleIssued', function(plate)
    local source = source
    local session = Sessions[source]
    if not session then return end
    session.vehicleIssued = true
    session.vehicleReturned = false
    session.vehiclePlate = tostring(plate or '')
end)

RegisterNetEvent('civix-gridservice:server:vehicleReturned', function()
    local source = source
    local session = Sessions[source]
    local Player = getPlayer(source)
    if not session or not Player then return end

    session.vehicleIssued = false
    session.vehicleReturned = true
    session.vehiclePlate = nil

    if session.index > #session.route and not session.routeBonusPaid then
        session.routeBonusPaid = true
        local payment = Config.Rewards.routeBonus
        local xpAwarded = Config.Rewards.xpRouteBonus
        addBankMoney(Player, payment, 'grid-service-route-bonus')
        saveRepairProgress(session.citizenid, xpAwarded, payment, false)
        session.earnings = session.earnings + payment
        session.xpEarned = session.xpEarned + xpAwarded
        TriggerClientEvent('civix-gridservice:client:routeBonus', source, payment, xpAwarded, loadProfile(session.citizenid))
    end
end)

RegisterNetEvent('civix-gridservice:server:beginStop', function(payload)
    local source = source
    local session = Sessions[source]
    local Player = getPlayer(source)
    if not session or not Player or type(payload) ~= 'table' then return end
    if session.pending then return end
    if os.time() < (session.cooldownUntil or 0) then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'The cabinet safety reset is still active.', true)
        return
    end
    if not session.suppliesCollected then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'Collect the company grid service equipment before starting repairs.', true)
        return
    end
    if Config.Vehicle.requiredAtWorksite and not session.vehicleIssued then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'An assigned utility truck is required for field repairs.', true)
        return
    end

    local routeIndex = tonumber(payload.routeIndex)
    if routeIndex ~= session.index then return end

    local stop = session.route[session.index]
    if not stop or stop.complete then return end

    local model = tonumber(payload.model)
    local cabinetCoords = payload.coords
    if not model or not ElectricalModelSet[model] or type(cabinetCoords) ~= 'table' then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'The selected object is not a configured electrical cabinet.', true)
        return
    end

    if distanceBetween(cabinetCoords, stop.center) > stop.radius then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'The selected cabinet is outside the assigned work zone.', true)
        return
    end

    local coords = playerCoords(source)
    if coords and distanceBetween(coords, cabinetCoords) > Config.Security.serverDistanceTolerance then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'Move closer to the electrical cabinet before beginning the repair.', true)
        return
    end

    local fault = Config.Faults[stop.faultKey]
    local equipped, missingItem = hasRequiredEquipment(Player, source, fault)
    if not equipped then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, ('Required grid service item missing: %s'):format(missingItem), true)
        return
    end

    local token = randomToken(source)
    session.pending = {
        token = token,
        startedAt = os.time(),
        stopIndex = session.index,
        cabinetCoords = cabinetCoords,
        cabinetModel = model,
        faultKey = stop.faultKey
    }

    TriggerClientEvent('civix-gridservice:client:openWiring', source, {
        token = token,
        faultLabel = fault.label,
        expectedVoltage = fault.expectedVoltage,
        difficulty = fault.difficulty
    })
end)

RegisterNetEvent('civix-gridservice:server:finishStop', function(result)
    local source = source
    local session = Sessions[source]
    local Player = getPlayer(source)
    if not session or not Player or not session.pending or type(result) ~= 'table' then return end

    local pending = session.pending
    session.pending = nil

    local stop = session.route[pending.stopIndex]
    local fault = stop and Config.Faults[pending.faultKey]
    if not stop or not fault or pending.stopIndex ~= session.index then return end

    local elapsedServer = os.time() - pending.startedAt
    local validToken = result.token == pending.token
    local success = result.success == true
        and validToken
        and elapsedServer >= Config.Security.minimumMinigameSeconds
        and elapsedServer <= Config.Security.maximumMinigameSeconds
        and (tonumber(result.mistakes) or 99) <= Config.Security.maximumMistakes

    local coords = playerCoords(source)
    if coords and distanceBetween(coords, pending.cabinetCoords) > Config.Security.serverDistanceTolerance then
        success = false
    end

    if success then
        if itemCount(Player, source, fault.requiredItem) < fault.requiredAmount
            or itemCount(Player, source, 'grid_lockout_tag') < 1
            or itemCount(Player, source, 'grid_electrical_tape') < 1 then
            success = false
        end
    end

    if not success then
        stop.failures = (stop.failures or 0) + 1
        session.cooldownUntil = os.time() + Config.Security.failCooldownSeconds
        saveRepairProgress(session.citizenid, 0, 0, true)

        local retryAllowed = stop.failures < Config.Security.maximumStopFailures
        local nextIndex = nil
        if not retryAllowed then
            session.index = session.index + 1
            nextIndex = session.index
        end

        TriggerClientEvent('civix-gridservice:client:stopFailed', source,
            retryAllowed and 'The wiring test failed. Wait for the cabinet safety reset and inspect it again.' or 'This work order was failed after three unsafe repair attempts.',
            retryAllowed,
            nextIndex
        )
        return
    end

    if not removeItem(Player, source, fault.requiredItem, fault.requiredAmount) then return end
    removeItem(Player, source, 'grid_lockout_tag', 1)
    removeItem(Player, source, 'grid_electrical_tape', 1)

    session.consumed[fault.requiredItem] = (session.consumed[fault.requiredItem] or 0) + fault.requiredAmount
    session.consumed.grid_lockout_tag = (session.consumed.grid_lockout_tag or 0) + 1
    session.consumed.grid_electrical_tape = (session.consumed.grid_electrical_tape or 0) + 1

    local base = math.random(Config.Rewards.basePayMinimum, Config.Rewards.basePayMaximum)
    local payment = math.floor(base * fault.payMultiplier)
    local score = math.max(0, math.min(100, tonumber(result.score) or 0))
    if score >= 95 and (tonumber(result.mistakes) or 0) == 0 then
        payment = payment + Config.Rewards.perfectBonus
    end

    local xpAwarded = Config.Rewards.xpPerRepair
    addBankMoney(Player, payment, 'grid-service-repair')
    saveRepairProgress(session.citizenid, xpAwarded, payment, false)

    stop.complete = true
    session.repairs = session.repairs + 1
    session.earnings = session.earnings + payment
    session.xpEarned = session.xpEarned + xpAwarded
    session.index = session.index + 1
    session.cooldownUntil = 0

    TriggerClientEvent('civix-gridservice:client:stopComplete', source, {
        pay = payment,
        xpAwarded = xpAwarded,
        nextIndex = session.index,
        profile = loadProfile(session.citizenid)
    })
end)

RegisterNetEvent('civix-gridservice:server:endShift', function()
    local source = source
    local session = Sessions[source]
    if not session then return end
    if session.vehicleIssued then
        TriggerClientEvent('civix-gridservice:client:stopFailed', source, 'Return the assigned utility truck before ending the shift.', true)
        return
    end

    cleanupIssuedEquipment(source, session)
    local summary = shiftSummary(session)
    Sessions[source] = nil
    TriggerClientEvent('civix-gridservice:client:shiftEnded', source, summary)
end)

RegisterNetEvent('civix-gridservice:server:cancelShift', function()
    local source = source
    local session = Sessions[source]
    if not session then return end

    cleanupIssuedEquipment(source, session)
    Sessions[source] = nil
    TriggerClientEvent('civix-gridservice:client:forceCleanup', source)
end)

AddEventHandler('playerDropped', function()
    local source = source
    local session = Sessions[source]
    if session then cleanupIssuedEquipment(source, session) end
    Sessions[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for source, session in pairs(Sessions) do
        cleanupIssuedEquipment(source, session)
        TriggerClientEvent('civix-gridservice:client:forceCleanup', source)
    end
    Sessions = {}
end)
