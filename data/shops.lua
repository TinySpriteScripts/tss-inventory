-- Prices are per item: buyPrice is paid by the player; sellPrice is paid to the player.
-- Shop buy/sell toggles apply to all products. Product toggles can disable either direction.
local products = {
    bar = {
        beer = { buyPrice = 7, sellPrice = 3, amount = 50 },
        vodka = { buyPrice = 70000, sellPrice = 35000, amount = 50 },
        whiskey = { buyPrice = 10, sellPrice = 5, amount = 50 },
    },
    blackmarket = {
        radioscanner = { buyPrice = 850, sellPrice = 425, amount = 5 },
    },
    casino = {
        casinochips = { buyPrice = 1, sellPrice = 1, amount = 999999 },
    },
    coffeeplace = {
        coffee = { buyPrice = 5, sellPrice = 2, amount = 500 },
        lighter = { buyPrice = 2, sellPrice = 1, amount = 50 },
    },
    electronics = {
        binoculars = { buyPrice = 50, sellPrice = 25, amount = 50 },
        fitbit = { buyPrice = 400, sellPrice = 200, amount = 150 },
        phone = { buyPrice = 850, sellPrice = 425, amount = 50 },
        radio = { buyPrice = 250, sellPrice = 125, amount = 50 },
        screwdriverset = { buyPrice = 350, sellPrice = 175, amount = 50 },
    },
    gearshop = {
        diving_gear = { buyPrice = 2500, sellPrice = 1250, amount = 10 },
        jerry_can = { buyPrice = 200, sellPrice = 100, amount = 50 },
    },
    hardware = {
        advancedrepairkit = { buyPrice = 500, sellPrice = 250, amount = 50 },
        binoculars = { buyPrice = 50, sellPrice = 25, amount = 50 },
        cleaningkit = { buyPrice = 150, sellPrice = 75, amount = 150 },
        firework1 = { buyPrice = 50, sellPrice = 25, amount = 50 },
        firework2 = { buyPrice = 50, sellPrice = 25, amount = 50 },
        firework3 = { buyPrice = 50, sellPrice = 25, amount = 50 },
        firework4 = { buyPrice = 50, sellPrice = 25, amount = 50 },
        fitbit = { buyPrice = 400, sellPrice = 200, amount = 150 },
        lockpick = { buyPrice = 200, sellPrice = 100, amount = 50 },
        phone = { buyPrice = 850, sellPrice = 425, amount = 50 },
        radio = { buyPrice = 250, sellPrice = 125, amount = 50 },
        repairkit = { buyPrice = 250, sellPrice = 125, amount = 50 },
        screwdriverset = { buyPrice = 350, sellPrice = 175, amount = 50 },
        weapon_bat = { buyPrice = 500, sellPrice = 250, amount = 50 },
        weapon_hammer = { buyPrice = 250, sellPrice = 125, amount = 250 },
        weapon_wrench = { buyPrice = 250, sellPrice = 125, amount = 250 },
    },
    leisureshop = {
        binoculars = { buyPrice = 50, sellPrice = 25, amount = 50 },
        diving_gear = { buyPrice = 2500, sellPrice = 1250, amount = 10 },
        parachute = { buyPrice = 2500, sellPrice = 1250, amount = 10 },
    },
    normal = {
        bandage = { buyPrice = 100, sellPrice = 50, amount = 50 },
        beer = { buyPrice = 7, sellPrice = 3, amount = 50 },
        lighter = { buyPrice = 2, sellPrice = 1, amount = 50 },
        rolling_paper = { buyPrice = 2, sellPrice = 1, amount = 5000 },
        sandwich = { buyPrice = 2, sellPrice = 1, amount = 50 },
        vodka = { buyPrice = 70000, sellPrice = 35000, amount = 50 },
        whiskey = { buyPrice = 10, sellPrice = 5, amount = 50 },
    },
    weapons = {
        weapon_bat = { buyPrice = 250, sellPrice = 125, amount = 250 },
        weapon_hatchet = { buyPrice = 250, sellPrice = 125, amount = 250 },
        weapon_knife = { buyPrice = 250, sellPrice = 125, amount = 250 },
        weapon_pistol = { buyPrice = 2500, sellPrice = 1250, amount = 5 },
        weapon_snspistol = { buyPrice = 1500, sellPrice = 750, amount = 5 },
        weapon_vintagepistol = { buyPrice = 4000, sellPrice = 2000, amount = 5 },
    },
    weedshop = {
        empty_weed_bag = { buyPrice = 2, sellPrice = 1, amount = 1000 },
        joint = { buyPrice = 10, sellPrice = 5, amount = 1000 },
        rolling_paper = { buyPrice = 2, sellPrice = 1, amount = 1000 },
        weapon_poolcue = { buyPrice = 100, sellPrice = 50, amount = 1000 },
        weed_nutrition = { buyPrice = 20, sellPrice = 10, amount = 1000 },
    },
}

-- Shop locations.
local locations = {
    ["247supermarket"] = {
        label = "24/7 Supermarket",
        pedModel = "mp_m_shopkeep_01",
        stock = products.normal,
        blip = { sprite = 628, colour = 2 },
        coords = {
            vector4(-3039.91, 584.26, 6.91, 16.79),
            vector4(-3243.27, 1000.10, 11.83, 358.73),
            vector4(1728.28, 6416.03, 34.04, 242.45),
            vector4(1697.96, 4923.04, 41.06, 326.61),
            vector4(1959.60, 3740.93, 31.34, 296.84),
            vector4(549.16, 2670.35, 41.16, 92.53),
            vector4(2677.41, 3279.80, 54.24, 334.16),
            vector4(2556.19, 380.89, 107.62, 355.58),
            vector4(372.82, 327.30, 102.57, 255.46),
            vector4(161.21, 6642.32, 30.61, 223.57),
            vector4(24.50, -1346.19, 28.50, 266.78), -- Legion Square
        },
    },
    ammunation = {
        label = "Ammunation",
        pedModel = "s_m_m_ammucountry",
        stock = products.weapons,
        blip = { sprite = 567, colour = 1 },
        coords = {
            vector4(808.94, -2158.99, 28.62, 330.26),
            vector4(-660.98, -933.60, 20.83, 154.74),
            vector4(1693.16, 3761.94, 33.71, 189.83),
            vector4(-330.72, 6085.81, 30.45, 190.52),
            vector4(253.41, -51.67, 68.94, 28.88),
            vector4(23.69, -1105.95, 28.80, 124.58),
            vector4(2566.81, 292.54, 107.73, 320.09),
            vector4(-1118.19, 2700.50, 17.55, 185.31),
            vector4(841.31, -1035.28, 27.19, 334.27),
            vector4(-1304.44, -395.68, 35.70, 41.85),
        },
    },
    beancoffee = {
        label = "Bean Machine Coffee",
        pedModel = "A_F_Y_Hipster_02",
        stock = products.coffeeplace,
        blip = { sprite = 52, colour = 31 },
        coords = {
            vector4(-628.97, 238.27, 80.90, 1.28),
            vector4(126.55, -1028.12, 28.36, 343.00),
        },
    },
    casino = {
        label = "Diamond Casino",
        pedModel = "U_F_M_CasinoShop_01",
        stock = products.casino,
        coords = {
            vector4(990.08, 30.35, 70.47, 94.81),
            vector4(990.96, 31.80, 70.47, 19.59),
        },
    },
    casino2 = {
        label = "Casino Bar",
        pedModel = "S_M_M_HighSec_01",
        stock = products.bar,
        blip = { sprite = 52, colour = 0 },
        coords = {
            vector4(979.44, 25.40, 70.46, 0.75),
        },
    },
    delvecchioliquor = {
        label = "Del Vecchio Liquor",
        pedModel = "cs_nervousron",
        stock = products.normal,
        blip = { sprite = 52, colour = 2 },
        coords = {
            vector4(-160.54, 6320.85, 30.59, 317.79),
        },
    },
    digitalden = {
        label = "Digital Den",
        pedModel = "S_M_M_LifeInvad_01",
        stock = products.electronics,
        blip = { sprite = 619, colour = 7 },
        coords = {
            vector4(391.76, -832.79, 28.29, 223.77),
            vector4(1136.99, -473.13, 65.53, 254.85),
            vector4(-509.55, 278.63, 82.31, 176.65),
            vector4(-656.27, -854.73, 23.50, 359.39),
            vector4(-1088.29, -254.30, 36.76, 252.70),
        },
    },
    hardware = {
        label = "Hardware Store",
        pedModel = "s_m_m_autoshop_02",
        stock = products.hardware,
        blip = { sprite = 402, colour = 5 },
        coords = {
            vector4(46.52, -1749.55, 28.64, 50.82),
            vector4(2747.76, 3472.90, 54.67, 243.88),
            vector4(-421.65, 6135.97, 30.88, 232.98),
        },
    },
    leisureshop = {
        label = "Leisure Shop",
        pedModel = "mp_m_boatstaff_01",
        stock = products.leisureshop,
        blip = { sprite = 52, colour = 2 },
        coords = {
            vector4(-1505.67, 1512.29, 114.29, 244.94),
        },
    },
    lostmc = {
        label = "Lost MC",
        pedModel = "G_F_Y_Lost_01",
        stock = products.coffeeplace,
        coords = {
            vector4(999.59, -131.58, 73.06, 12.95),
        },
    },
    ltdgasoline = {
        label = "LTD Gasoline",
        pedModel = "s_m_m_autoshop_02",
        stock = products.normal,
        blip = { sprite = 628, colour = 5 },
        coords = {
            vector4(-47.42, -1758.67, 28.42, 47.26),
            vector4(-706.17, -914.64, 18.22, 88.77),
            vector4(-1819.53, 793.49, 137.09, 131.46),
            vector4(1164.82, -323.66, 68.21, 106.86),
        },
    },
    robsliquor = {
        label = "Rob's Liqour",
        pedModel = "cs_nervousron",
        stock = products.bar,
        blip = { sprite = 628, colour = 31 },
        coords = {
            vector4(-1221.38, -907.89, 11.33, 27.51),
            vector4(-1486.82, -377.48, 39.16, 130.89),
            vector4(-2966.41, 391.62, 14.04, 87.82),
            vector4(1165.15, 2710.78, 37.16, 177.96),
            vector4(1134.30, -983.26, 45.42, 276.30),
        },
    },
    seaworld = {
        label = "Sea World",
        pedModel = "mp_m_boatstaff_01",
        stock = products.gearshop,
        blip = { sprite = 52, colour = 3 },
        coords = {
            vector4(-1686.48, -1072.53, 12.15, 49.85),
        },
    },
    weedshop = {
        label = "Smoke on the Water",
        pedModel = "mp_f_weed_01",
        stock = products.weedshop,
        blip = { sprite = 496, colour = 2 },
        coords = {
            vector4(-1173.12, -1572.71, 3.66, 123.56),
        },
    },
}

-- Build one shop definition per location.
TSSShops = {}
for groupName, definition in pairs(locations) do
    for locationIndex, coordinates in ipairs(definition.coords) do
        local shopId = groupName .. '_' .. locationIndex
        TSSShops[shopId] = {
            label = definition.label,
            coords = coordinates,
            pedModel = definition.pedModel,
            blip = definition.blip,
            distance = 3.0,
            account = 'cash',
            size = { x = 8 },
            buy = true,
            sell = true,
            stock = definition.stock,
        }
    end
end
