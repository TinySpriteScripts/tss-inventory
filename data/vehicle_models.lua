-- Standalone model/class reference. Add custom models here or set class on a model override.
TSSVehicleModelClasses = {}

local modelsByClass = {
    [0] = {
        'blista', 'blista2', 'blista3', 'boor', 'brioso', 'brioso2', 'brioso3', 'club',
        'dilettante', 'dilettante2', 'issi2', 'issi3', 'issi4', 'issi5', 'issi6', 'issi7',
        'kanjo', 'panto', 'prairie', 'rhapsody', 'weevil',
    },
    [1] = {
        'asea', 'asterope', 'asterope2', 'astron', 'baller7', 'cinquemila', 'cog55', 'cognoscenti',
        'comet7', 'deity', 'emperor', 'eudora', 'fugitive', 'glendale', 'glendale2', 'impaler5',
        'ingot', 'intruder', 'iwagen', 'jubilee', 'oracle', 'premier', 'primo', 'primo2',
        'regina', 'rhinehart', 'schafter2', 'stafford', 'stanier', 'stratum', 'stretch', 'superd',
        'surge', 'tailgater', 'tailgater2', 'warrener', 'warrener2', 'washington',
    },
    [2] = {
        'aleutian', 'baller', 'baller2', 'baller3', 'baller4', 'baller5', 'baller6', 'baller8',
        'bjxl', 'castigator', 'cavalcade', 'cavalcade2', 'cavalcade3', 'contender', 'dorado', 'dubsta',
        'dubsta2', 'fq2', 'granger', 'granger2', 'gresley', 'habanero', 'huntley', 'landstalker',
        'landstalker2', 'novak', 'patriot', 'patriot2', 'patriot3', 'radi', 'rebla', 'rocoto',
        'seminole', 'seminole2', 'serrano', 'toros', 'vivanite', 'xls',
    },
    [3] = {
        'broadway', 'champion', 'cogcabrio', 'exemplar', 'f620', 'felon', 'felon2', 'fr36',
        'futo', 'jackal', 'kanjosj', 'oracle2', 'postlude', 'previon', 'sentinel', 'sentinel2',
        'sentinel3', 'tahoma', 'windsor', 'windsor2', 'zion', 'zion2',
    },
    [4] = {
        'blade', 'brigham', 'buccaneer', 'buccaneer2', 'buffalo4', 'buffalo5', 'chino', 'chino2',
        'clique', 'clique2', 'coquette3', 'deviant', 'dominator', 'dominator2', 'dominator3', 'dominator4',
        'dominator7', 'dominator8', 'dominator9', 'dukes', 'dukes2', 'dukes3', 'ellie', 'faction',
        'faction2', 'faction3', 'gauntlet', 'gauntlet2', 'gauntlet3', 'gauntlet4', 'gauntlet5', 'greenwood',
        'hermes', 'hotknife', 'hustler', 'impaler', 'impaler2', 'impaler3', 'impaler4', 'impaler6',
        'imperator', 'imperator2', 'imperator3', 'lurcher', 'manana', 'manana2', 'nightshade', 'phoenix',
        'picador', 'ratloader2', 'ruiner', 'ruiner2', 'ruiner4', 'sabregt', 'sabregt2', 'slamvan',
        'slamvan2', 'slamvan3', 'stalion', 'stalion2', 'tampa', 'tampa2', 'tulip', 'tulip2',
        'vamos', 'vigero', 'vigero2', 'vigero3', 'virgo', 'virgo2', 'virgo3', 'voodoo',
        'weevil2', 'yosemite', 'yosemite2',
    },
    [5] = {
        'ardent', 'btype', 'btype2', 'btype3', 'casco', 'cheburek', 'coquette2', 'deluxo',
        'driftnebula', 'dynasty', 'envisage', 'fagaloa', 'feltzer3', 'gt500', 'infernus2', 'jb700',
        'jb7002', 'mamba', 'michelli', 'monroe', 'nebula', 'peyote', 'peyote2', 'peyote3',
        'pigalle', 'rapidgt3', 'retinue', 'retinue2', 'savestra', 'stinger', 'stingergt', 'stromberg',
        'swinger', 'toreador', 'torero', 'tornado', 'tornado2', 'tornado5', 'turismo2', 'viseris',
        'z190', 'zion3', 'ztype',
    },
    [6] = {
        'alpha', 'banshee', 'bestiagts', 'buffalo', 'buffalo2', 'calico', 'carbonizzare', 'cheetah2',
        'comet2', 'comet3', 'comet4', 'comet5', 'comet6', 'coquette', 'coquette4', 'coquette5',
        'corsita', 'coureur', 'cypher', 'drafter', 'driftcypher', 'driftsentinel', 'driftvorschlag', 'elegy',
        'elegy2', 'euros', 'eurosX32', 'everon2', 'feltzer2', 'flashgt', 'furoregt', 'futo2',
        'gauntlet6', 'gb200', 'growler', 'imorgon', 'issi8', 'italigto', 'italirsx', 'jester',
        'jester2', 'jester3', 'jester4', 'jugular', 'khamelion', 'komoda', 'kuruma', 'kuruma2',
        'locust', 'lynx', 'massacro', 'massacro2', 'neo', 'neon', 'ninef', 'ninef2',
        'niobe', 'omnis', 'omnisegt', 'panthere', 'paragon', 'paragon3', 'pariah', 'penumbra',
        'penumbra2', 'pipistrello', 'r300', 'rapidgt', 'rapidgt2', 'raptor', 'remus', 'revolter',
        'rt3000', 'ruston', 'schafter3', 'schafter4', 'schlagen', 'schwarzer', 'sentinel4', 'seven70',
        'sm722', 'specter', 'stingertt', 'streiter', 'sugoi', 'sultan', 'sultan2', 'sultan3',
        'sultanrs', 'surano', 'tenf', 'tenf2', 'tropos', 'vectre', 'verlierer2', 'visione',
        'vorschlaghammer', 'vstr', 'zr350',
    },
    [7] = {
        'adder', 'autarch', 'banshee2', 'bullet', 'cheetah', 'cyclone', 'deveste', 'emerus',
        'entity2', 'entity3', 'entityxf', 'fmj', 'furia', 'gp1', 'ignus', 'infernus',
        'italigtb', 'italigtb2', 'krieger', 'le7b', 'lm87', 'nero', 'nero2', 'osiris',
        'penetrator', 'pfister811', 'prototipo', 'reaper', 's80', 'sc1', 'sheava', 't20',
        'taipan', 'tempesta', 'tezeract', 'thrax', 'tigon', 'torero2', 'turismo3', 'turismor',
        'tyrant', 'tyrus', 'vacca', 'vagner', 'virtue', 'voltic', 'voltic2', 'xa21',
        'zeno', 'zentorno', 'zorrusso',
    },
    [8] = {
        'akuma', 'avarus', 'bagger', 'bati', 'bati2', 'bf400', 'carbonrs', 'chimera',
        'cliffhanger', 'daemon', 'daemon2', 'deathbike', 'deathbike2', 'deathbike3', 'defiler', 'diablous',
        'diablous2', 'double', 'enduro', 'esskey', 'faggio', 'faggio2', 'faggio3', 'fcr',
        'fcr2', 'gargoyle', 'hakuchou', 'hakuchou2', 'hexer', 'innovation', 'lectro', 'manchez',
        'manchez2', 'manchez3', 'nemesis', 'nightblade', 'oppressor', 'pcj', 'pizzaboy', 'powersurge',
        'ratbike', 'reever', 'ruffian', 'sanchez', 'sanchez2', 'sanctus', 'shinobi', 'shotaro',
        'sovereign', 'stryder', 'thrust', 'vader', 'vindicator', 'vortex', 'wolfsbane', 'zombiea',
        'zombieb',
    },
    [9] = {
        'bfinjection', 'bifta', 'blazer', 'blazer2', 'blazer3', 'blazer4', 'blazer5', 'brawler',
        'caracara', 'caracara2', 'draugur', 'dubsta3', 'dune', 'everon', 'freecrawler', 'hellion',
        'kalahari', 'kamacho', 'l35', 'mesa', 'mesa3', 'monstrociti', 'outlaw', 'rancherxl',
        'ratel', 'rebel2', 'riata', 'sandking', 'sandking2', 'terminus', 'trophytruck', 'trophytruck2',
        'vagrant', 'verus', 'winky', 'yosemite3', 'yosemite4',
    },
    [10] = {
        'bulldozer', 'cutter', 'dump', 'flatbed', 'guardian', 'handler', 'mixer', 'mixer2',
        'rubble', 'tiptruck', 'tiptruck2',
    },
    [11] = {
        'airtug', 'caddy2', 'caddy3', 'docktug', 'forklift', 'mower', 'ripley', 'sadler',
        'scrap', 'slamtruck', 'towtruck', 'towtruck2', 'tractor', 'tractor2', 'tractor3', 'trailers5',
        'tvtrailer2', 'utillitruck', 'utillitruck2', 'utillitruck3',
    },
    [12] = {
        'bison', 'bobcatxl', 'boxville', 'boxville2', 'boxville3', 'boxville4', 'boxville5', 'boxville6',
        'burrito3', 'gburrito2', 'journey', 'journey2', 'minivan', 'minivan2', 'moonbeam', 'moonbeam2',
        'mule2', 'mule3', 'paradise', 'pony', 'pony2', 'rumpo', 'rumpo3', 'speedo',
        'speedo4', 'speedo5', 'surfer', 'surfer3', 'taco', 'youga', 'youga2', 'youga3',
        'youga4',
    },
    [13] = {
        'bmx', 'cruiser', 'fixter', 'inductor', 'inductor2', 'scorcher', 'tribike', 'tribike2',
        'tribike3',
    },
    [14] = {
        'avisa', 'dinghy', 'dinghy2', 'dinghy3', 'dinghy4', 'jetmax', 'longfin', 'marquis',
        'patrolboat', 'seashark', 'seashark3', 'speeder', 'speeder2', 'squalo', 'submersible', 'submersible2',
        'suntrap', 'toro', 'toro2', 'tropic', 'tropic2', 'tug',
    },
    [15] = {
        'akula', 'annihilator', 'annihilator2', 'buzzard', 'buzzard2', 'cargobob', 'cargobob2', 'cargobob3',
        'conada', 'conada2', 'frogger', 'frogger2', 'havok', 'hunter', 'maverick', 'savage',
        'seasparrow', 'seasparrow2', 'seasparrow3', 'skylift', 'supervolito', 'supervolito2', 'swift', 'swift2',
        'valkyrie', 'volatus',
    },
    [16] = {
        'alkonost', 'alphaz1', 'avenger', 'avenger2', 'besra', 'blimp', 'blimp2', 'blimp3',
        'bombushka', 'cargoplane', 'cuban800', 'dodo', 'duster', 'howard', 'hydra', 'jet',
        'lazer', 'luxor', 'luxor2', 'mammatus', 'microlight', 'miljet', 'mogul', 'molotok',
        'nimbus', 'nokota', 'pyro', 'raiju', 'rogue', 'seabreeze', 'shamal', 'starling',
        'streamer216', 'strikeforce', 'stunt', 'titan', 'tula', 'velum', 'velum2', 'vestra',
        'volatol',
    },
    [17] = {
        'airbus', 'brickade', 'brickade2', 'bus', 'cablecar', 'coach', 'freight', 'metrotrain',
        'pbus2', 'rallytruck', 'rentalbus', 'taxi', 'tourbus', 'trash', 'trash2', 'wastelander',
    },
    [18] = {
        'ambulance', 'fbi', 'fbi2', 'firetruk', 'lguard', 'pbus', 'poldominator10', 'poldorado',
        'polgauntlet', 'polgreenwood', 'police', 'police2', 'police3', 'police4', 'police5', 'policeb',
        'policeold1', 'policeold2', 'policet', 'policet3', 'polimpaler5', 'polimpaler6', 'polmav', 'pranger',
        'predator', 'riot', 'riot2', 'seashark2', 'sheriff', 'sheriff2',
    },
    [19] = {
        'apc', 'barracks', 'barracks2', 'barracks3', 'barrage', 'chernobog', 'crusader', 'halftrack',
        'khanjali', 'kosatka', 'minitank', 'rhino', 'scarab', 'terbyte', 'thruster', 'trailerlarge',
        'trailersmall2', 'vetir',
    },
    [20] = {
        'benson', 'benson2', 'biff', 'cerberus', 'hauler', 'hauler2', 'mule', 'mule4',
        'mule5', 'packer', 'phantom', 'phantom2', 'phantom3', 'phantom4', 'pounder', 'pounder2',
        'stockade',
    },
    [21] = {
    },
    [22] = {
        'formula', 'formula2', 'openwheel1', 'openwheel2',
    },
}

for vehicleClass, modelNames in pairs(modelsByClass) do
    for _, modelName in ipairs(modelNames) do TSSVehicleModelClasses[joaat(modelName)] = vehicleClass end
end
