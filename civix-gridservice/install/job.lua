Civix.Shared.Jobs = Civix.Shared.Jobs or {}

Civix.Shared.Jobs['gridservice'] = {
    label = 'Grid Service',
    type = 'utility',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Grid Apprentice', payment = 45 },
        ['1'] = { name = 'Junior Grid Technician', payment = 60 },
        ['2'] = { name = 'Grid Service Technician', payment = 78 },
        ['3'] = { name = 'Certified Grid Technician', payment = 96 },
        ['4'] = { name = 'Senior Grid Technician', payment = 118 },
        ['5'] = { name = 'Grid Operations Specialist', isboss = true, payment = 145 }
    }
}
