Config = {}

Config.Debug = false
Config.JobName = 'electrician'
Config.AllowPrimaryJob = true
Config.AllowMultiJob = true
Config.AllowContractors = true -- set false to require electrician in primary/multijob data
Config.MinimumGrade = 0
Config.RequireDuty = false
Config.RouteLength = { min = 4, max = 7 }
Config.InteractionDistance = 1.65
Config.RouteBlip = true
Config.DrawIndicators = true
Config.RequireServiceVehicle = true
Config.RequireActualObject = false -- when true the configured electrical-box prop must be found
Config.ObjectSearchRadius = 4.0
Config.FailCooldownSeconds = 8
Config.MinMinigameSeconds = 6
Config.MaxMinigameSeconds = 120
Config.BasePay = { min = 185, max = 285 }
Config.PerfectBonus = 85
Config.RouteBonus = 240
Config.XPPerRepair = 18
Config.XPRouteBonus = 40
Config.MaxFailuresPerStop = 3
Config.VehicleModel = 'utillitruck3'
Config.VehicleLivery = 0
Config.VehicleFuel = 100.0

Config.Dispatcher = {
    model = 's_m_m_dockwork_01',
    coords = vector4(728.32, 132.18, 80.96, 239.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

Config.VehicleSpawn = vector4(733.62, 127.14, 79.72, 239.0)
Config.VehicleReturn = vector3(733.62, 127.14, 79.72)

Config.ElectricalModels = {
    `prop_elecbox_01a`, `prop_elecbox_02a`, `prop_elecbox_03a`, `prop_elecbox_04a`,
    `prop_elecbox_05a`, `prop_elecbox_06a`, `prop_elecbox_07a`, `prop_elecbox_08`,
    `prop_elecbox_09`, `prop_elecbox_10`, `prop_elecbox_11`, `prop_elecbox_12`,
    `prop_elecbox_13`, `prop_elecbox_14`, `prop_elecbox_15`, `prop_elecbox_16`,
    `prop_elecbox_17`, `prop_elecbox_18`, `prop_elecbox_19`, `prop_elecbox_20`,
    `prop_elecbox_21`, `prop_elecbox_22`, `prop_elecbox_23`, `prop_elecbox_24`,
    `prop_elecbox_24b`, `prop_elecbox_25`, `prop_elecbox_26`, `prop_elecbox_27`,
    `prop_elecbox_28`, `prop_elecbox_29`, `prop_elecbox_30`, `prop_elecbox_31`,
    `prop_elecbox_32`, `prop_elecbox_33`, `prop_elecbox_34`, `prop_elecbox_35`,
    `prop_elecbox_36`, `prop_elecbox_37`, `prop_elecbox_38`, `prop_elecbox_39`,
    `prop_elecbox_40`, `prop_elecbox_41`, `prop_elecbox_42`, `prop_elecbox_43`,
    `prop_elecbox_44`, `prop_elecbox_45`, `prop_elecbox_46`, `prop_elecbox_47`,
    `prop_elecbox_48`, `prop_elecbox_49`, `prop_elecbox_50`, `prop_elecbox_51`,
    `prop_elecbox_52`, `prop_elecbox_53`, `prop_elecbox_54`, `prop_elecbox_55`,
    `prop_elecbox_56`, `prop_elecbox_57`, `prop_elecbox_58`, `prop_elecbox_59`,
    `prop_elecbox_60`, `prop_elecbox_61`, `prop_elecbox_62`, `prop_elecbox_63`,
    `prop_elecbox_64`, `prop_elecbox_65`, `prop_elecbox_66`, `prop_elecbox_67`,
    `prop_elecbox_68`, `prop_elecbox_69`, `prop_elecbox_70`, `prop_elecbox_71`,
    `prop_elecbox_72`, `prop_elecbox_73`, `prop_elecbox_74`, `prop_elecbox_75`,
    `prop_elecbox_76`, `prop_elecbox_77`, `prop_elecbox_78`, `prop_elecbox_79`,
    `prop_elecbox_80`, `prop_elecbox_81`, `prop_elecbox_82`, `prop_elecbox_83`,
    `prop_elecbox_84`, `prop_elecbox_85`, `prop_elecbox_86`, `prop_elecbox_87`,
    `prop_elecbox_88`, `prop_elecbox_89`, `prop_elecbox_90`, `prop_elecbox_91`,
    `prop_elecbox_92`, `prop_elecbox_93`, `prop_elecbox_94`, `prop_elecbox_95`,
    `prop_elecbox_96`, `prop_elecbox_97`, `prop_elecbox_98`, `prop_elecbox_99`,
    `prop_elecbox_100`, `prop_elecbox_101`, `prop_elecbox_102`, `prop_elecbox_103`,
    `prop_elecbox_104`, `prop_elecbox_105`, `prop_elecbox_106`, `prop_elecbox_107`,
    `prop_elecbox_108`, `prop_elecbox_109`, `prop_elecbox_110`, `prop_elecbox_111`,
    `prop_elecbox_112`, `prop_elecbox_113`, `prop_elecbox_114`, `prop_elecbox_115`,
    `prop_elecbox_116`, `prop_elecbox_117`, `prop_elecbox_118`, `prop_elecbox_119`,
    `prop_elecbox_120`, `prop_elecbox_121`, `prop_elecbox_122`, `prop_elecbox_123`,
    `prop_elecbox_124`, `prop_elecbox_125`, `prop_elecbox_126`, `prop_elecbox_127`,
    `prop_elecbox_128`, `prop_elecbox_129`, `prop_elecbox_130`, `prop_elecbox_131`,
    `prop_elecbox_132`, `prop_elecbox_133`, `prop_elecbox_134`, `prop_elecbox_135`,
    `prop_elecbox_136`, `prop_elecbox_137`, `prop_elecbox_138`, `prop_elecbox_139`,
    `prop_elecbox_140`, `prop_elecbox_141`, `prop_elecbox_142`, `prop_elecbox_143`,
    `prop_elecbox_144`, `prop_elecbox_145`, `prop_elecbox_146`, `prop_elecbox_147`,
    `prop_elecbox_148`, `prop_elecbox_149`, `prop_elecbox_150`,
    `prop_elecbox_01b`, `prop_elecbox_02b`, `prop_elecbox_03b`, `prop_elecbox_04b`,
    `prop_elecbox_05b`, `prop_elecbox_06b`, `prop_elecbox_07b`,
    `prop_streetlight_01`, `prop_streetlight_01b`, `prop_streetlight_03`,
}

-- These are interaction anchors. The client resolves the closest real electrical prop at each anchor.
Config.WorkLocations = {
    { label = 'Power Street service cabinet', coords = vector3(629.21, 125.67, 91.18), district = 'Vinewood' },
    { label = 'Alta Street distribution box', coords = vector3(235.42, -761.74, 30.82), district = 'Alta' },
    { label = 'Legion Square lighting cabinet', coords = vector3(184.17, -1003.62, 29.34), district = 'Downtown' },
    { label = 'Mission Row service panel', coords = vector3(424.78, -986.21, 30.71), district = 'Mission Row' },
    { label = 'Strawberry feeder cabinet', coords = vector3(296.49, -1514.70, 29.19), district = 'Strawberry' },
    { label = 'Davis utility controller', coords = vector3(166.31, -1718.04, 29.29), district = 'Davis' },
    { label = 'Rancho street-power cabinet', coords = vector3(492.66, -1912.46, 25.45), district = 'Rancho' },
    { label = 'Cypress Flats junction box', coords = vector3(842.06, -2114.63, 30.52), district = 'Cypress Flats' },
    { label = 'La Mesa industrial panel', coords = vector3(941.54, -1547.23, 30.73), district = 'La Mesa' },
    { label = 'El Burro Heights cabinet', coords = vector3(1215.83, -1388.02, 35.23), district = 'El Burro Heights' },
    { label = 'Mirror Park service box', coords = vector3(1113.35, -645.76, 56.82), district = 'Mirror Park' },
    { label = 'East Vinewood controller', coords = vector3(897.02, -170.03, 74.09), district = 'East Vinewood' },
    { label = 'Hawick electrical cabinet', coords = vector3(313.38, -213.37, 54.08), district = 'Hawick' },
    { label = 'Rockford Hills service panel', coords = vector3(-705.54, -151.12, 37.42), district = 'Rockford Hills' },
    { label = 'Little Seoul distribution box', coords = vector3(-679.82, -892.42, 24.50), district = 'Little Seoul' },
    { label = 'Vespucci utility cabinet', coords = vector3(-1166.14, -1160.04, 5.63), district = 'Vespucci' },
    { label = 'Del Perro promenade panel', coords = vector3(-1486.66, -649.21, 29.58), district = 'Del Perro' },
    { label = 'Morningwood service cabinet', coords = vector3(-1289.96, -273.24, 38.98), district = 'Morningwood' },
    { label = 'Richman feeder box', coords = vector3(-1532.05, 100.72, 56.77), district = 'Richman' },
    { label = 'West Vinewood street panel', coords = vector3(-564.36, 268.16, 83.02), district = 'West Vinewood' },
    { label = 'Chamberlain Hills cabinet', coords = vector3(-215.12, -1496.61, 31.31), district = 'Chamberlain Hills' },
    { label = 'Airport perimeter panel', coords = vector3(-1037.31, -2735.61, 20.17), district = 'LSIA' },
    { label = 'Port electrical controller', coords = vector3(797.17, -2989.47, 6.02), district = 'Port of Los Santos' },
    { label = 'Palomino freeway service box', coords = vector3(2582.81, 447.02, 108.46), district = 'Tataviam Mountains' },
}

Config.Faults = {
    burnt_connector = {
        label = 'Burnt terminal connector', item = 'electrical_connector', amount = 1,
        difficulty = 4, expectedVoltage = '118–122 V', payMultiplier = 1.05,
    },
    severed_wire = {
        label = 'Severed feeder conductor', item = 'copper_wire', amount = 2,
        difficulty = 5, expectedVoltage = '118–122 V', payMultiplier = 1.15,
    },
    blown_fuse = {
        label = 'Blown service fuse', item = 'service_fuse', amount = 1,
        difficulty = 3, expectedVoltage = '118–122 V', payMultiplier = 1.0,
    },
    failed_relay = {
        label = 'Failed control relay', item = 'control_relay', amount = 1,
        difficulty = 5, expectedVoltage = '24 V control / 120 V line', payMultiplier = 1.2,
    },
    corroded_terminal = {
        label = 'Corroded terminal block', item = 'terminal_block', amount = 1,
        difficulty = 4, expectedVoltage = '118–122 V', payMultiplier = 1.1,
    },
    ground_fault = {
        label = 'Ground-fault conductor damage', item = 'grounding_clamp', amount = 1,
        difficulty = 6, expectedVoltage = '0 V to ground after isolation', payMultiplier = 1.3,
    },
}

Config.SupplyLoadout = {
    electrician_toolkit = 1,
    digital_multimeter = 1,
    insulated_gloves = 1,
    lockout_tag = 4,
    electrical_connector = 4,
    copper_wire = 8,
    service_fuse = 4,
    control_relay = 3,
    terminal_block = 3,
    grounding_clamp = 3,
    electrical_tape = 6,
}

Config.Progression = {
    { level = 1, xp = 0, label = 'Apprentice' },
    { level = 2, xp = 180, label = 'Junior Technician' },
    { level = 3, xp = 450, label = 'Service Electrician' },
    { level = 4, xp = 850, label = 'Certified Electrician' },
    { level = 5, xp = 1400, label = 'Senior Electrician' },
    { level = 6, xp = 2200, label = 'Grid Specialist' },
}
