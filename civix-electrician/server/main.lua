local Civix = exports['civix-core']:GetCoreObject()
local Sessions = {}
local AllowedModels = {}
local FaultKeys = {}

for _, model in ipairs(Config.ElectricalModels) do AllowedModels[model] = true end
for key in pairs(Config.Faults) do FaultKeys[#FaultKeys + 1] = key end

local function notify(src, message, kind, duration)
    TriggerClientEvent('civix-electrician:client:notify', src, message, kind or 'primary', duration or 5000)
end

local function getPlayer(src)
    if Civix and Civix.Functions and Civix.Functions.GetPlayer then return Civix.Functions.GetPlayer(src) end
    local ok, player = pcall(function() return exports['civix-core']:GetPlayer(src) end)
    return ok and player or nil
end

local function playerData(player)
    return player and (player.PlayerData or player.Functions and player.Functions.GetPlayerData and player.Functions.GetPlayerData()) or {}
end

local function citizenId(player)
    local data = playerData(player)
    return data.citizenid or data.citizenId or data.identifier
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

local function hasAccess(player)
    if Config.AllowContractors then return true end
    local data = playerData(player)
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

local function itemCount(player, item)
    if player and player.Functions and player.Functions.GetItemByName then
        local found = player.Functions.GetItemByName(item)
        if found then return tonumber(found.amount or found.count or 0) or 0 end
    end
    local src = playerData(player).source
    local ok, count = pcall(function() return exports['civix-inventory']:GetItemCount(src, item) end)
    return ok and (tonumber(count) or 0) or 0
end

local function addItem(player, item, amount, reason)
    if player and player.Functions and player.Functions.AddItem then
        return player.Functions.AddItem(item, amount, false, false, reason or 'electrician-company-supply') == true
    end
    local src = playerData(player).source
    local ok, result = pcall(function() return exports['civix-inventory']:AddItem(src, item, amount, false, false, reason) end)
    return ok and result ~= false
end

local function removeItem(player, item, amount, reason)
    if amount <= 0 then return true end
    if player and player.Functions and player.Functions.RemoveItem then
        return player.Functions.RemoveItem(item, amount, false, reason or 'electrician-consumption') == true
    end
    local src = playerData(player).source
    local ok, result = pcall(function() return exports['civix-inventory']:RemoveItem(src, item, amount, false, reason) end)
    return ok and result ~= false
end

local function addMoney(player, amount, reason)
    if player and player.Functions and player.Functions.AddMoney then
        return player.Functions.AddMoney('bank', amount, reason or 'electrician-field-service')
    end
    return false
end

local function distanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if ped == 0 then return 99999.0 end
    local p = GetEntityCoords(ped)
    return #(p - vector3(coords.x, coords.y, coords.z))
end

local function rankForXp(xp)
    local current = Config.Progression[1]
    for _, rank in ipairs(Config.Progression) do
        if xp >= rank.xp then current = rank else break end
    end
    return current.level, current.label
end

local function getProfile(cid)
    local row = MySQL.single.await('SELECT xp, level, repairs, failed_repairs, earnings, best_score FROM civix_electrician_progress WHERE citizenid = ?', { cid })
    if not row then
        MySQL.insert.await('INSERT INTO civix_electrician_progress (citizenid) VALUES (?)', { cid })
        row = { xp = 0, level = 1, repairs = 0, failed_repairs = 0, earnings = 0, best_score = 0 }
    end
    row.xp = tonumber(row.xp) or 0
    row.level, row.rank = rankForXp(row.xp)
    return row
end

local function saveProgress(cid, xpGain, pay, success, score)
    local profile = getProfile(cid)
    local xp = profile.xp + (xpGain or 0)
    local level = rankForXp(xp)
    MySQL.update.await([[
        UPDATE civix_electrician_progress
        SET xp = ?, level = ?, repairs = repairs + ?, failed_repairs = failed_repairs + ?,
            earnings = earnings + ?, best_score = GREATEST(best_score, ?), updated_at = CURRENT_TIMESTAMP
        WHERE citizenid = ?
    ]], { xp, level, success and 1 or 0, success and 0 or 1, pay or 0, score or 0, cid })
    return getProfile(cid)
end

local function randomToken(src)
    return ('%s:%s:%s:%s'):format(src, os.time(), math.random(100000, 999999), math.random(100000, 999999))
end

local function copyLocation(index)
    local source = Config.WorkLocations[index]
    return {
        id = index,
        label = source.label,
        district = source.district,
        anchor = { x = source.coords.x, y = source.coords.y, z = source.coords.z },
        coords = { x = source.coords.x, y = source.coords.y, z = source.coords.z },
    }
end

local function buildRoute()
    local pool = {}
    for i = 1, #Config.WorkLocations do pool[i] = i end
    for i = #pool, 2, -1 do local j = math.random(i); pool[i], pool[j] = pool[j], pool[i] end
    local count = math.min(#pool, math.random(Config.RouteLength.min, Config.RouteLength.max))
    local route = {}
    for i = 1, count do route[i] = copyLocation(pool[i]) end
    return route
end

local function returnCompanyItems(src, session)
    if not session or not session.supplies then return end
    local player = getPlayer(src)
    if not player then return end
    session.consumed = session.consumed or {}
    for item, issued in pairs(Config.SupplyLoadout) do
        local remaining = math.max(0, issued - (session.consumed[item] or 0))
        if remaining > 0 then removeItem(player, item, math.min(remaining, itemCount(player, item)), 'electrician-supply-return') end
    end
end

local function endSession(src, summary, cleanupVehicle)
    local session = Sessions[src]
    if not session then return end
    returnCompanyItems(src, session)
    Sessions[src] = nil
    if cleanupVehicle then TriggerClientEvent('civix-electrician:client:forceCleanup', src) end
    TriggerClientEvent('civix-electrician:client:shiftEnded', src, summary)
end

RegisterNetEvent('civix-electrician:server:startShift', function()
    local src = source
    if Sessions[src] then notify(src, 'You already have an active electrician shift.', 'error'); return end
    local player = getPlayer(src)
    if not player or not hasAccess(player) then notify(src, 'You are not authorised for this contractor route.', 'error'); return end
    local cid = citizenId(player)
    if not cid then notify(src, 'Character identifier unavailable.', 'error'); return end
    local route = buildRoute()
    local profile = getProfile(cid)
    Sessions[src] = {
        citizenid = cid,
        route = route,
        index = 1,
        supplies = false,
        issued = {},
        consumed = {},
        resolved = {},
        failures = {},
        completed = 0,
        earnings = 0,
        xp = 0,
        vehicleNetId = nil,
        plate = nil,
        returned = false,
        startedAt = os.time(),
        profile = profile,
    }
    TriggerClientEvent('civix-electrician:client:shiftStarted', src, route, profile)
end)

RegisterNetEvent('civix-electrician:server:collectSupplies', function()
    local src = source
    local session = Sessions[src]
    local player = getPlayer(src)
    if not session or not player then return end
    if session.supplies then notify(src, 'Company supplies have already been issued.', 'error'); return end
    local added = {}
    for item, amount in pairs(Config.SupplyLoadout) do
        if not addItem(player, item, amount, 'electrician-company-supply') then
            for rollbackItem, rollbackAmount in pairs(added) do removeItem(player, rollbackItem, rollbackAmount, 'electrician-supply-rollback') end
            notify(src, 'Not enough inventory capacity for the company loadout.', 'error', 6500)
            return
        end
        added[item] = amount
    end
    session.supplies, session.issued = true, added
    TriggerClientEvent('civix-electrician:client:suppliesCollected', src)
end)

RegisterNetEvent('civix-electrician:server:vehicleAssigned', function(netId, plate)
    local session = Sessions[source]
    if not session then return end
    session.vehicleNetId = tonumber(netId)
    session.plate = tostring(plate or '')
    session.returned = false
end)

RegisterNetEvent('civix-electrician:server:resolveStop', function(index, coords, model)
    local src = source
    local session = Sessions[src]
    if not session or tonumber(index) ~= session.index or type(coords) ~= 'table' then return end
    model = tonumber(model)
    if not model or not AllowedModels[model] then return end
    local location = session.route[session.index]
    if not location then return end
    local anchor = location.anchor
    if #(vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0) - vector3(anchor.x, anchor.y, anchor.z)) > Config.ObjectSearchRadius + 5.0 then return end
    session.resolved[session.index] = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0, model = model }
end)

RegisterNetEvent('civix-electrician:server:rerollStop', function(index)
    local src = source
    local session = Sessions[src]
    if not session or tonumber(index) ~= session.index then return end
    session.rerolls = (session.rerolls or 0) + 1
    if session.rerolls > 8 then
        notify(src, 'No streamed electrical cabinet was found in the available service areas. Route cancelled safely.', 'error', 8000)
        endSession(src, { repairs = session.completed, earnings = session.earnings, xp = session.xp }, true)
        return
    end
    local used = {}
    for _, entry in ipairs(session.route) do used[entry.id] = true end
    local choices = {}
    for i = 1, #Config.WorkLocations do if not used[i] then choices[#choices + 1] = i end end
    if #choices == 0 then for i = 1, #Config.WorkLocations do choices[#choices + 1] = i end end
    local replacement = copyLocation(choices[math.random(#choices)])
    session.route[session.index] = replacement
    session.resolved[session.index] = nil
    TriggerClientEvent('civix-electrician:client:replaceStop', src, session.index, replacement)
end)

RegisterNetEvent('civix-electrician:server:beginStop', function(index)
    local src = source
    local session = Sessions[src]
    local player = getPlayer(src)
    if not session or not player or tonumber(index) ~= session.index then return end
    if not session.supplies then notify(src, 'Collect company supplies before opening a work order.', 'error'); return end
    local resolved = session.resolved[session.index]
    if not resolved then notify(src, 'The actual cabinet has not been verified yet.', 'error'); return end
    if distanceTo(src, resolved) > 4.0 then notify(src, 'Move closer to the assigned electrical cabinet.', 'error'); return end
    if Config.RequireServiceVehicle then
        local entity = session.vehicleNetId and NetworkGetEntityFromNetworkId(session.vehicleNetId) or 0
        if entity == 0 or not DoesEntityExist(entity) then notify(src, 'Assigned utility truck could not be verified.', 'error'); return end
        local playerPed = GetPlayerPed(src)
        if #(GetEntityCoords(playerPed) - GetEntityCoords(entity)) > Config.ServiceVehicleRadius + 2.0 then notify(src, 'Bring the utility truck closer to the cabinet.', 'error'); return end
    end
    for _, item in ipairs({ 'electrician_toolkit', 'digital_multimeter', 'insulated_gloves', 'lockout_tag' }) do
        if itemCount(player, item) < 1 then notify(src, ('Required safety item missing: %s'):format(item), 'error'); return end
    end
    local faultKey = FaultKeys[math.random(#FaultKeys)]
    local fault = Config.Faults[faultKey]
    if itemCount(player, fault.item) < fault.amount or itemCount(player, 'electrical_tape') < 1 then
        notify(src, ('Required repair materials missing: %dx %s and electrical tape.'):format(fault.amount, fault.item), 'error', 6500)
        return
    end
    if not removeItem(player, 'lockout_tag', 1, 'electrician-lockout') then notify(src, 'Unable to apply the lockout tag.', 'error'); return end
    session.consumed.lockout_tag = (session.consumed.lockout_tag or 0) + 1
    session.challenge = {
        token = randomToken(src),
        faultKey = faultKey,
        openedAt = os.time(),
        startedMs = GetGameTimer(),
    }
    TriggerClientEvent('civix-electrician:client:openWiring', src, {
        token = session.challenge.token,
        faultLabel = fault.label,
        expectedVoltage = fault.expectedVoltage,
        difficulty = fault.difficulty,
    })
end)

RegisterNetEvent('civix-electrician:server:finishStop', function(data)
    local src = source
    local session = Sessions[src]
    local player = getPlayer(src)
    if not session or not player or type(data) ~= 'table' then return end
    local challenge = session.challenge
    if not challenge or data.token ~= challenge.token then notify(src, 'Invalid or expired work-order token.', 'error'); return end
    session.challenge = nil
    local resolved = session.resolved[session.index]
    if not resolved or distanceTo(src, resolved) > 5.0 then notify(src, 'Repair validation failed: cabinet distance mismatch.', 'error'); return end
    local elapsedServer = os.time() - challenge.openedAt
    local success = data.success == true and elapsedServer >= Config.MinMinigameSeconds and elapsedServer <= Config.MaxMinigameSeconds + 5
    local score = math.max(0, math.min(100, math.floor(tonumber(data.score) or 0)))
    local mistakes = math.max(0, math.floor(tonumber(data.mistakes) or 0))
    session.failures[session.index] = session.failures[session.index] or 0
    if not success then
        session.failures[session.index] = session.failures[session.index] + 1
        saveProgress(session.citizenid, 0, 0, false, score)
        local retry = session.failures[session.index] < Config.MaxFailuresPerStop
        if retry then
            TriggerClientEvent('civix-electrician:client:stopFailed', src, 'Wiring test failed. The cabinet was safely reset for another attempt.', true)
        else
            session.index = session.index + 1
            TriggerClientEvent('civix-electrician:client:stopFailed', src, 'Maximum safe attempts reached. This work order was closed without payment.', false)
            TriggerClientEvent('civix-electrician:client:stopComplete', src, { pay = 0, xp = 0, nextIndex = session.index, profile = getProfile(session.citizenid) })
        end
        return
    end
    local fault = Config.Faults[challenge.faultKey]
    if itemCount(player, fault.item) < fault.amount or itemCount(player, 'electrical_tape') < 1 then
        TriggerClientEvent('civix-electrician:client:stopFailed', src, 'Repair materials were removed before completion.', true)
        return
    end
    if not removeItem(player, fault.item, fault.amount, 'electrician-repair-part') or not removeItem(player, 'electrical_tape', 1, 'electrician-repair-tape') then
        TriggerClientEvent('civix-electrician:client:stopFailed', src, 'Inventory transaction failed. Nothing was paid.', true)
        return
    end
    session.consumed[fault.item] = (session.consumed[fault.item] or 0) + fault.amount
    session.consumed.electrical_tape = (session.consumed.electrical_tape or 0) + 1
    local pay = math.floor(math.random(Config.BasePay.min, Config.BasePay.max) * fault.payMultiplier)
    if score >= 90 and mistakes == 0 then pay = pay + Config.PerfectBonus end
    addMoney(player, pay, 'electrician-field-service')
    session.completed = session.completed + 1
    session.earnings = session.earnings + pay
    session.xp = session.xp + Config.XPPerRepair
    session.index = session.index + 1
    local profile = saveProgress(session.citizenid, Config.XPPerRepair, pay, true, score)
    session.profile = profile
    TriggerClientEvent('civix-electrician:client:stopComplete', src, { pay = pay, xp = Config.XPPerRepair, nextIndex = session.index, profile = profile })
end)

RegisterNetEvent('civix-electrician:server:returnVehicle', function(netId, plate)
    local src = source
    local session = Sessions[src]
    local player = getPlayer(src)
    if not session or not player then return end
    if tostring(plate or '') ~= tostring(session.plate or '') then notify(src, 'Assigned utility-truck plate mismatch.', 'error'); return end
    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if entity == 0 or not DoesEntityExist(entity) then notify(src, 'Utility truck could not be verified.', 'error'); return end
    if #(GetEntityCoords(entity) - Config.VehicleReturn) > Config.VehicleReturnRadius + 2.0 then notify(src, 'Park the utility truck inside the return bay.', 'error'); return end
    session.returned = true
    TriggerClientEvent('civix-electrician:client:vehicleReturnApproved', src)
    local routeComplete = session.index > #session.route
    if routeComplete then
        addMoney(player, Config.RouteBonus, 'electrician-route-bonus')
        session.earnings = session.earnings + Config.RouteBonus
        session.xp = session.xp + Config.XPRouteBonus
        session.profile = saveProgress(session.citizenid, Config.XPRouteBonus, Config.RouteBonus, true, 0)
    end
    local summary = { repairs = session.completed, earnings = session.earnings, xp = session.xp }
    endSession(src, summary, false)
end)

RegisterNetEvent('civix-electrician:server:endShift', function()
    local src = source
    local session = Sessions[src]
    if not session then return end
    if session.vehicleNetId and not session.returned then notify(src, 'Return the assigned utility truck before ending shift.', 'error'); return end
    endSession(src, { repairs = session.completed, earnings = session.earnings, xp = session.xp }, false)
end)

RegisterNetEvent('civix-electrician:server:cancelShift', function()
    local src = source
    local session = Sessions[src]
    if not session then return end
    endSession(src, { repairs = session.completed, earnings = session.earnings, xp = session.xp }, true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local session = Sessions[src]
    if session then returnCompanyItems(src, session); Sessions[src] = nil end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, session in pairs(Sessions) do returnCompanyItems(src, session) end
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS civix_electrician_progress (
            citizenid VARCHAR(64) NOT NULL,
            xp INT NOT NULL DEFAULT 0,
            level INT NOT NULL DEFAULT 1,
            repairs INT NOT NULL DEFAULT 0,
            failed_repairs INT NOT NULL DEFAULT 0,
            earnings INT NOT NULL DEFAULT 0,
            best_score INT NOT NULL DEFAULT 0,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end)