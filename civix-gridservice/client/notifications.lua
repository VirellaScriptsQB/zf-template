local function gridNotify(message, kind, duration)
    local ok = pcall(function()
        exports['civix-notify']:Notify(message, kind or 'primary', duration or 5000)
    end)
    if ok then return end
    TriggerEvent('civix-notify:client:Notify', message, kind or 'primary', duration or 5000)
end

RegisterNetEvent('civix-gridservice:client:routeBonus', function(payment, xpAwarded)
    gridNotify(('Full grid route completed: $%d route bonus | +%d XP'):format(payment or 0, xpAwarded or 0), 'success', 7500)
end)
