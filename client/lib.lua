-- Thin wrapper: pl_lib client exports → pl-atmrob globals.
local _lib = exports['pl_lib']

function Notify(message, ntype)
    _lib:Notify('ATM Robbery', message, ntype)
end

function LoadAnimDict(dict)
    _lib:LoadAnimDict(dict)
end

function EnsureModel(model)
    return _lib:EnsureModel(model)
end

function NetToEnt(netId)
    return _lib:NetToEnt(netId)
end

function TryRequestControl(entity, timeoutMs)
    return _lib:TryRequestControl(entity, timeoutMs)
end

-- Runs the hacking minigame. Uses Config.Hacking.Minigame if set, otherwise pl_lib autodetect.
function RunMinigame(callback, opts)
    opts = opts or {}
    if Config.Hacking.Minigame then
        opts.system = Config.Hacking.Minigame
    end
    _lib:DoMinigame(callback, opts)
end

-- Runs the drilling minigame. Always uses Config.Drilling.Minigame (defaults to 'M-drilling').
function RunDrillMinigame(callback)
    _lib:DoMinigame(callback, { system = Config.Drilling.Minigame })
end

-- Sends a police dispatch alert — pl_lib handles system routing automatically.
function SendDispatch()
    _lib:SendDispatch({
        title   = 'ATM Robbery',
        code    = '10-90',
        message = Locale('dispatch_message'),
        jobs    = Config.Police.Job,
        sprite  = 431,
        color   = 1,
        scale   = 1.0,
        radius  = 0,
        length  = 3,
    })
end
