
Config = {}

Config.DebugPrints = true -- Set to true to enable debug prints in console

Config.Locale = 'en' -- 'en', 'fr', 'de', 'es', 'it', 'pt', 'tr' -- Language

Config.WaterMark = true -- Set to false to disable watermark

-- Item names for hacking and drilling
Config.HackingItem = 'pl_hackingdevice'  -- Default item name for hacking
Config.DrillItem = 'pl_drill'  -- Default item name for drilling
Config.RopeItem = 'pl_rope'  -- Item name required for rope robbery

-- Enable or disable ATM robbery actions (hacking and drilling)
Config.EnableHacking = true  -- Set to true to enable ATM hacking
Config.EnableDrilling = true  -- Set to true to enable ATM drilling
Config.EnableRopeRobbery = true  -- Set to true to enable rope-based ATM robbery

-- Rope robbery settings
Config.RopeRobbery = {
    DragForce = 0.2,  -- Drag multiplier applied to vehicle when rope is taut (0.0 = no drag, 1.0 = full drag)
    ResistanceForce = 0.05,  -- Resistance force applied to ATM when being pulled
    RequiredDistance = 4.0,  -- Distance needed to pull ATM loose
    MaxRopeLength = 25.0,  -- Maximum rope length before it breaks
    TautRopeLength = 8.0,  -- Distance at which rope becomes taut and applies drag
}

-- If you disable this the cash will not be dropped on the ground and will be added to your inventory directly
Config.MoneyDrop = true

Config.AtmModels = {'prop_fleeca_atm', 'prop_atm_01', 'prop_atm_02', 'prop_atm_03'}

Config.Hacking = {
    -- Override the minigame for this script only. nil = use PLLib.Minigame autodetect.
    -- Supported: 'ox_lib', 'M-drilling', 'utk_fingerprint', 'ps-ui-circle', 'ps-ui-maze', 'ps-ui-scrambler'
    Minigame            = nil,
    InitialHackDuration = 2000,  -- 2 seconds
    LootAtmDuration     = 20000, -- 20 seconds
}

Config.Shop = {
    Enable = true,
    id = "atmitems", -- Shop identifier
    name = "ATM Robbery Shop", -- Display name
    coords = vec3(-59.34, -1207.93, 28.30),
    heading = 135.09,
    pedModel = "a_m_m_og_boss_01", -- Change to any ped model
    blip = {
        enabled = true,
        sprite = 59, -- Shop blip icon
        color = 2,  -- Green
        scale = 0.8
    },
    items = {
        { name = 'pl_hackingdevice', amount = 50, price =50},    
        { name = 'pl_drill', amount = 50, price = 100 },     
        { name = 'pl_rope', amount = 50, price = 20 }     
    }
}

Config.CooldownTimer = 60 -- default 10 minutes | 60 = 1 minute

Config.Reward = {
    -- The account type where the reward is credited. Can be:
    -- 'bank' for bank account, 'cash' for cash in hand, or 'dirty' for dirty money.
    account = 'dirty',  
    -- The value of each cash pile (in game currency).
    -- This determines how much each cash pile is worth when dropped during the robbery.
    cash_prop_value = 100,  
    -- The total reward value for completing the robbery.
    -- This value is used when 'MoneyDrop' is false and determines the total reward.
    reward = 1000,  
    -- The number of cash piles that will be dropped during the hack action.
    -- This is how many piles the player will pick up when they hack the ATM.
    hack_cash_pile = 10,  
    -- The number of cash piles that will be dropped during the drill action.
    -- This is how many piles the player will pick up when they drill the ATM.
    drill_cash_pile = 5,  
}


Config.Police = {
    notify = true,
    required = 0,
    Job = {'police'},
}



