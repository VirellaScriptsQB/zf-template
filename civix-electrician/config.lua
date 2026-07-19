Config = {}

Config.Debug = false
Config.JobName = 'electrician'
Config.AllowedJobs = { electrician = true, cityworks = true }
Config.AllowPrimaryJob = true
Config.AllowMultiJob = true
Config.AllowContractors = true -- false = electrician/cityworks must exist in primary or multijob data
Config.MinimumGrade = 0
Config.RequireDuty = false

Config.RouteLength = { min = 4, max = 7 }
Config.InteractionDistance = 1.8
Config.ObjectSearchRadius = 65.0 -- broad anchor search; the client locks onto a real streamed cabinet
Config.RequireActualObject = true
Config.RequireServiceVehicle = true
Config.ServiceVehicleRadius = 45.0
Config.RouteBlip = true
Config.DrawIndicators = true
Config.MinMinigameSeconds = 5
Config.MaxMinigameSeconds = 90
Config.MaxFailuresPerStop = 3
Config.BasePay = { min = 185, max = 285 }
Config.PerfectBonus = 85
Config.RouteBonus = 240
Config.XPPerRepair = 18
Config.XPRouteBonus = 40

Config.Dispatcher = {
    model = 's_m_m_dockwork_01',
    coords = vector4(728.32, 132.18, 80.96, 239.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

Config.VehicleModel = 'utillitruck3'
Config.VehicleSpawn = vector4(733.62, 127.14, 79.72, 239.0)
Config.VehicleReturn = vector3(733.62, 127.14, 79.72)
Config.VehicleReturnRadius = 9.0
Config.VehicleFuel = 100.0
Config.VehicleLivery = 0

-- Real GTA V electrical cabinet models only. No job props are spawned.
Config.ElectricalModels = {
    `prop_elecbox_01a`, `prop_elecbox_01b`, `prop_elecbox_02a`, `prop_elecbox_02b`,
    `prop_elecbox_03a`, `prop_elecbox_04a`, `prop_elecbox_05a`, `prop_elecbox_06a`,
    `prop_elecbox_07a`, `prop_elecbox_08`, `prop_elecbox_09`, `prop_elecbox_10`,
    `prop_elecbox_11`, `prop_elecbox_12`, `prop_elecbox_13`, `prop_elecbox_14`,
    `prop_elecbox_15`, `prop_elecbox_16`, `prop_elecbox_17`, `prop_elecbox_18`,
    `prop_elecbox_19`, `prop_elecbox_20`, `prop_elecbox_21`, `prop_elecbox_22`,
    `prop_elecbox_23`, `prop_elecbox_24`, `prop_elecbox_24b`, `prop_elecbox_25`,
    `prop_elecbox_26`, `prop_elecbox_27`, `prop_elecbox_28`, `prop_elecbox_29`,
    `prop_elecbox_30`, `prop_elecbox_31`, `prop_elecbox_32`, `prop_elecbox_33`,
    `prop_elecbox_34`, `prop_elecbox_35`, `prop_elecbox_36`, `prop_elecbox_37`,
    `prop_elecbox_38`, `prop_elecbox_39`, `prop_elecbox_40`, `prop_elecbox_41`,
    `prop_elecbox_42`, `prop_elecbox_43`, `prop_elecbox_44`, `prop_elecbox_45`,
    `prop_elecbox_46`, `prop_elecbox_47`, `prop_elecbox_48`, `prop_elecbox_49`,
    `prop_elecbox_50`, `prop_elecbox_51`, `prop_elecbox_52`, `prop_elecbox_53`,
    `prop_elecbox_54`, `prop_elecbox_55`, `prop_elecbox_56`, `prop_elecbox_57`,
    `prop_elecbox_58`, `prop_elecbox_59`, `prop_elecbox_60`, `prop_elecbox_61`,
    `prop_elecbox_62`, `prop_elecbox_63`, `prop_elecbox_64`, `prop_elecbox_65`,
}

-- District anchors. On arrival the closest real model above is resolved and targeted.
Config.WorkLocations = {
    { label = 'Vinewood feeder cabinet', coords = vector3(629.21, 125.67, 91.18), district = 'Vinewood' },
    { label = 'Alta distribution cabinet', coords = vector3(235.42, -761.74, 30.82), district = 'Alta' },
    { label = 'Legion lighting controller', coords = vector3(184.17, -1003.62, 29.34), district = 'Downtown' },
    { label = 'Mission Row service panel', coords = vector3(424.78, -986.21, 30.71), district = 'Mission Row' },
    { label = 'Strawberry feeder cabinet', coords = vector3(296.49, -1514.70, 29.19), district = 'Strawberry' },
    { label = 'Davis utility controller', coords = vector3(166.31, -1718.04, 29.29), district = 'Davis' },
    { label = 'Rancho power cabinet', coords = vector3(492.66, -1912.46, 25.45), district = 'Rancho' },
    { label = 'Cypress industrial panel', coords = vector3(842.06, -2114.63, 30.52), district = 'Cypress Flats' },
    { label = 'La Mesa service cabinet', coords = vector3(941.54, -1547.23, 30.73), district = 'La Mesa' },
    { label = 'El Burro controller', coords = vector3(1215.83, -1388.02, 35.23), district = 'El Burro Heights' },
    { label = 'Mirror Park service box', coords = vector3(1113.35, -645.76, 56.82), district = 'Mirror Park' },
    { label = 'East Vinewood controller', coords = vector3(897.02, -170.03, 74.09), district = 'East Vinewood' },
    { label = 'Hawick street cabinet', coords = vector3(313.38, -213.37, 54.08), district = 'Hawick' },
    { label = 'Rockford service panel', coords = vector3(-705.54, -151.12, 37.42), district = 'Rockford Hills' },
    { label = 'Little Seoul distribution box', coords = vector3(-679.82, -892.42, 24.50), district = 'Little Seoul' },
    { label = 'Vespucci utility cabinet', coords = vector3(-1166.14, -1160.04, 5.63), district = 'Vespucci' },
    { label = 'Del Perro service panel', coords = vector3(-1486.66, -649.21, 29.58), district = 'Del Perro' },
    { label = 'Morningwood cabinet', coords = vector3(-1289.96, -273.24, 38.98), district = 'Morningwood' },
    { label = 'West Vinewood panel', coords = vector3(-564.36, 268.16, 83.02), district = 'West Vinewood' },
    { label = 'Chamberlain cabinet', coords = vector3(-215.12, -1496.61, 31.31), district = 'Chamberlain Hills' },
    { label = 'LSIA perimeter panel', coords = vector3(-1037.31, -2735.61, 20.17), district = 'LSIA' },
    { label = 'Port power controller', coords = vector3(797.17, -2989.47, 6.02), district = 'Port of Los Santos' },
}

Config.Faults = {
    burnt_connector = { label = 'Burnt terminal connector', item = 'electrical_connector', amount = 1, difficulty = 4, expectedVoltage = '118–122 V', payMultiplier = 1.05 },
    severed_wire = { label = 'Severed feeder conductor', item = 'copper_wire', amount = 2, difficulty = 5, expectedVoltage = '118–122 V', payMultiplier = 1.15 },
    blown_fuse = { label = 'Blown service fuse', item = 'service_fuse', amount = 1, difficulty = 3, expectedVoltage = '118–122 V', payMultiplier = 1.00 },
    failed_relay = { label = 'Failed control relay', item = 'control_relay', amount = 1, difficulty = 5, expectedVoltage = '24 V control / 120 V line', payMultiplier = 1.20 },
    corroded_terminal = { label = 'Corroded terminal block', item = 'terminal_block', amount = 1, difficulty = 4, expectedVoltage = '118–122 V', payMultiplier = 1.10 },
    ground_fault = { label = 'Ground-fault conductor damage', item = 'grounding_clamp', amount = 1, difficulty = 6, expectedVoltage = '0 V after isolation', payMultiplier = 1.30 },
}

Config.SupplyLoadout = {
    electrician_toolkit = 1,
    digital_multimeter = 1,
    insulated_gloves = 1,
    lockout_tag = 8,
    electrical_connector = 5,
    copper_wire = 14,
    service_fuse = 5,
    control_relay = 4,
    terminal_block = 4,
    grounding_clamp = 4,
    electrical_tape = 10,
}

Config.Progression = {
    { level = 1, xp = 0, label = 'Apprentice' },
    { level = 2, xp = 180, label = 'Junior Technician' },
    { level = 3, xp = 450, label = 'Service Electrician' },
    { level = 4, xp = 850, label = 'Certified Electrician' },
    { level = 5, xp = 1400, label = 'Senior Electrician' },
    { level = 6, xp = 2200, label = 'Grid Specialist' },
}