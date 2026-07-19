Civix.Shared.Jobs = Civix.Shared.Jobs or {}

Civix.Shared.Jobs['electrician'] = {
    label = 'Civix Grid Services',
    type = 'civilian',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Apprentice', payment = 45 },
        ['1'] = { name = 'Junior Technician', payment = 60 },
        ['2'] = { name = 'Service Electrician', payment = 78 },
        ['3'] = { name = 'Certified Electrician', payment = 96 },
        ['4'] = { name = 'Senior Electrician', payment = 120 },
        ['5'] = { name = 'Grid Specialist', isboss = true, payment = 145 },
    },
}