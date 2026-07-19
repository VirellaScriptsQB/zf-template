Config = {}

Config.Debug = false
Config.JobName = 'gridservice'
Config.JobLabel = 'Grid Service Technician'
Config.AllowPrimaryJob = true
Config.AllowMultiJob = true
Config.AllowContractors = true
Config.MinimumGrade = 0
Config.RequireDuty = false

Config.Dispatcher = {
    model = 's_m_m_dockwork_01',
    coords = vector4(728.32, 132.18, 80.96, 239.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

Config.Vehicle = {
    model = 'utillitruck3',
    spawn = vector4(733.62, 127.14, 79.72, 239.0),
    returnPoint = vector3(733.62, 127.14, 79.72),
    returnRadius = 9.0,
    requiredAtWorksite = true,
    worksiteRadius = 45.0,
    fuel = 100.0,
    livery = 0,
    platePrefix = 'GRID'
}

Config.Route = {
    minimumStops = 4,
    maximumStops = 7,
    routeBlip = true,
    drawZoneIndicator = true,
    drawCabinetIndicator = true,
    scanDistance = 90.0,
    rescanInterval = 3500,
    interactionDistance = 1.75,
    actualObjectRequired = true
}

Config.Security = {
    minimumMinigameSeconds = 6,
    maximumMinigameSeconds = 120,
    maximumMistakes = 8,
    maximumStopFailures = 3,
    failCooldownSeconds = 8,
    serverDistanceTolerance = 8.0
}

Config.Rewards = {
    basePayMinimum = 185,
    basePayMaximum = 285,
    perfectBonus = 85,
    routeBonus = 240,
    xpPerRepair = 18,
    xpRouteBonus = 40
}

Config.ElectricalModels = {
    `prop_elecbox_01a`, `prop_elecbox_01b`,
    `prop_elecbox_02a`, `prop_elecbox_02b`,
    `prop_elecbox_03a`, `prop_elecbox_03b`,
    `prop_elecbox_04a`, `prop_elecbox_04b`,
    `prop_elecbox_05a`, `prop_elecbox_05b`,
    `prop_elecbox_06a`, `prop_elecbox_06b`,
    `prop_elecbox_07a`, `prop_elecbox_07b`,
    `prop_elecbox_08`, `prop_elecbox_09`, `prop_elecbox_10`,
    `prop_elecbox_11`, `prop_elecbox_12`, `prop_elecbox_13`,
    `prop_elecbox_14`, `prop_elecbox_15`, `prop_elecbox_16`,
    `prop_elecbox_17`, `prop_elecbox_18`, `prop_elecbox_19`,
    `prop_elecbox_20`, `prop_elecbox_21`, `prop_elecbox_22`,
    `prop_elecbox_23`, `prop_elecbox_24`, `prop_elecbox_24b`,
    `prop_elecbox_25`, `prop_elecbox_26`, `prop_elecbox_27`,
    `prop_elecbox_28`, `prop_elecbox_29`, `prop_elecbox_30`,
    `prop_elecbox_31`, `prop_elecbox_32`, `prop_elecbox_33`,
    `prop_elecbox_34`, `prop_elecbox_35`, `prop_elecbox_36`,
    `prop_elecbox_37`, `prop_elecbox_38`, `prop_elecbox_39`
}

-- The route sends players to real map areas. The client scans the streamed world
-- and binds civix-interact to an actual electrical cabinet inside each zone.
Config.WorkZones = {
    { id = 'power_street', label = 'Power Street distribution zone', district = 'East Vinewood', center = vector3(629.21, 125.67, 91.18), radius = 75.0 },
    { id = 'alta', label = 'Alta municipal feeder zone', district = 'Alta', center = vector3(235.42, -761.74, 30.82), radius = 85.0 },
    { id = 'legion', label = 'Legion Square lighting grid', district = 'Downtown', center = vector3(184.17, -1003.62, 29.34), radius = 90.0 },
    { id = 'mission_row', label = 'Mission Row service grid', district = 'Mission Row', center = vector3(424.78, -986.21, 30.71), radius = 90.0 },
    { id = 'strawberry', label = 'Strawberry feeder grid', district = 'Strawberry', center = vector3(296.49, -1514.70, 29.19), radius = 100.0 },
    { id = 'davis', label = 'Davis utility controller zone', district = 'Davis', center = vector3(166.31, -1718.04, 29.29), radius = 95.0 },
    { id = 'rancho', label = 'Rancho street-power grid', district = 'Rancho', center = vector3(492.66, -1912.46, 25.45), radius = 100.0 },
    { id = 'cypress', label = 'Cypress Flats industrial grid', district = 'Cypress Flats', center = vector3(842.06, -2114.63, 30.52), radius = 110.0 },
    { id = 'lamesa', label = 'La Mesa service grid', district = 'La Mesa', center = vector3(941.54, -1547.23, 30.73), radius = 105.0 },
    { id = 'elburro', label = 'El Burro Heights feeder zone', district = 'El Burro Heights', center = vector3(1215.83, -1388.02, 35.23), radius = 110.0 },
    { id = 'mirrorpark', label = 'Mirror Park utility grid', district = 'Mirror Park', center = vector3(1113.35, -645.76, 56.82), radius = 95.0 },
    { id = 'hawick', label = 'Hawick service cabinet zone', district = 'Hawick', center = vector3(313.38, -213.37, 54.08), radius = 90.0 },
    { id = 'rockford', label = 'Rockford Hills feeder zone', district = 'Rockford Hills', center = vector3(-705.54, -151.12, 37.42), radius = 100.0 },
    { id = 'littleseoul', label = 'Little Seoul distribution zone', district = 'Little Seoul', center = vector3(-679.82, -892.42, 24.50), radius = 95.0 },
    { id = 'vespucci', label = 'Vespucci utility grid', district = 'Vespucci', center = vector3(-1166.14, -1160.04, 5.63), radius = 105.0 },
    { id = 'delperro', label = 'Del Perro promenade grid', district = 'Del Perro', center = vector3(-1486.66, -649.21, 29.58), radius = 105.0 },
    { id = 'westvinewood', label = 'West Vinewood street grid', district = 'West Vinewood', center = vector3(-564.36, 268.16, 83.02), radius = 95.0 },
    { id = 'airport', label = 'LSIA perimeter service grid', district = 'LSIA', center = vector3(-1037.31, -2735.61, 20.17), radius = 130.0 },
    { id = 'port', label = 'Port electrical controller zone', district = 'Port of Los Santos', center = vector3(797.17, -2989.47, 6.02), radius = 135.0 }
}

Config.Faults = {
    burnt_connector = {
        label = 'Burnt terminal connector',
        requiredItem = 'grid_connector',
        requiredAmount = 1,
        difficulty = 4,
        expectedVoltage = '118–122 V',
        payMultiplier = 1.05
    },
    severed_wire = {
        label = 'Severed feeder conductor',
        requiredItem = 'grid_wire',
        requiredAmount = 2,
        difficulty = 5,
        expectedVoltage = '118–122 V',
        payMultiplier = 1.15
    },
    blown_fuse = {
        label = 'Blown service fuse',
        requiredItem = 'grid_service_fuse',
        requiredAmount = 1,
        difficulty = 3,
        expectedVoltage = '118–122 V',
        payMultiplier = 1.00
    },
    failed_relay = {
        label = 'Failed lighting control relay',
        requiredItem = 'grid_control_relay',
        requiredAmount = 1,
        difficulty = 5,
        expectedVoltage = '24 V control / 120 V line',
        payMultiplier = 1.20
    },
    corroded_terminal = {
        label = 'Corroded terminal block',
        requiredItem = 'grid_terminal_block',
        requiredAmount = 1,
        difficulty = 4,
        expectedVoltage = '118–122 V',
        payMultiplier = 1.10
    },
    ground_fault = {
        label = 'Ground-fault conductor damage',
        requiredItem = 'grid_grounding_clamp',
        requiredAmount = 1,
        difficulty = 6,
        expectedVoltage = '0 V after isolation',
        payMultiplier = 1.30
    }
}

Config.RequiredTools = {
    'grid_toolkit',
    'grid_multimeter',
    'grid_gloves',
    'grid_lockout_tag'
}

Config.SupplyLoadout = {
    grid_toolkit = 1,
    grid_multimeter = 1,
    grid_gloves = 1,
    grid_lockout_tag = 7,
    grid_connector = 5,
    grid_wire = 12,
    grid_service_fuse = 5,
    grid_control_relay = 4,
    grid_terminal_block = 4,
    grid_grounding_clamp = 3,
    grid_electrical_tape = 8
}

Config.Progression = {
    { level = 1, xp = 0, label = 'Grid Apprentice' },
    { level = 2, xp = 180, label = 'Junior Grid Technician' },
    { level = 3, xp = 450, label = 'Grid Service Technician' },
    { level = 4, xp = 850, label = 'Certified Grid Technician' },
    { level = 5, xp = 1400, label = 'Senior Grid Technician' },
    { level = 6, xp = 2200, label = 'Grid Operations Specialist' }
}
