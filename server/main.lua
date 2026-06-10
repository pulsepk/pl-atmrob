local lastRobberyTime  = 0
local resourceName     = 'pl-atmrob'
local atmRobberyState  = {}
local ropeRobberyState = {}

local function hasEnoughPolice()
    local jobs = {}
    for _, job in pairs(Config.Police.Job) do jobs[job] = true end
    local count = 0
    for _, pid in ipairs(GetPlayers()) do
        if jobs[GetJob(tonumber(pid))] then count = count + 1 end
    end
    return count >= Config.Police.required
end

local function checkCooldown()
    local timePassed = os.time() - lastRobberyTime

    if lastRobberyTime ~= 0 and timePassed < Config.CooldownTimer then
        return false, Config.CooldownTimer - timePassed
    end

    return true
end

local function normalizeCoords(coords)
    if type(coords) ~= 'vector3' and type(coords) ~= 'vector4' and type(coords) ~= 'table' then
        return nil
    end

    local x, y, z = coords.x, coords.y, coords.z
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
        return nil
    end

    return vector3(x, y, z)
end

local function getMethodItem(method)
    if method == 'hack' then return Config.HackingItem end
    if method == 'drill' then return Config.DrillItem end
    if method == 'rope' then return Config.RopeItem end
end

local function getNetEntity(netId)
    if type(netId) ~= 'number' then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil
    end

    return entity
end

local function logExploit(src, message)
    local Identifier = getPlayerIdentifier(src)
    local PlayerName = getPlayerName(src)
    print(('^1[Exploit Attempt]^0 %s (%s) %s'):format(PlayerName, Identifier, message))
end

local function isStateExpired(state)
    return not state or not state.time or os.time() - state.time > 300
end

local function playerNearCoords(src, coords, distance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= distance
end

lib.callback.register('pl_atmrobbery:server:startRobbery', function(src, method, atmCoords, atmNetId)
    local coords = normalizeCoords(atmCoords)
    if not coords then
        logExploit(src, 'sent invalid ATM coords.')
        return false, 'invalid'
    end

    if method ~= 'hack' and method ~= 'drill' and method ~= 'rope' then
        logExploit(src, 'sent invalid robbery method.')
        return false, 'invalid'
    end

    if method == 'hack' and not Config.EnableHacking then return false, 'disabled' end
    if method == 'drill' and not Config.EnableDrilling then return false, 'disabled' end
    if method == 'rope' and not Config.EnableRopeRobbery then return false, 'disabled' end

    if not playerNearCoords(src, coords, 5.0) then
        logExploit(src, 'tried to start a robbery too far from ATM.')
        return false, 'too_far'
    end

    if not hasEnoughPolice() then
        return false, 'police'
    end

    local cooldownOk, remaining = checkCooldown()
    if not cooldownOk then
        return false, 'cooldown', remaining
    end

    local item = getMethodItem(method)
    if item and RemoveItem(src, item, 1) == false then
        return false, 'item'
    end

    lastRobberyTime = os.time()

    if method == 'rope' then
        ropeRobberyState[src] = {
            started = false,
            atmCoords = coords,
            atmNetId = atmNetId,
            time = os.time()
        }
    else
        atmRobberyState[src] = {
            minigamePassed = false,
            pickupcash = 0,
            method = method,
            atmCoords = coords,
            atmNetId = atmNetId,
            time = os.time()
        }
    end

    return true
end)

RegisterServerEvent('pl_atmrobbery:MinigameResult')
AddEventHandler('pl_atmrobbery:MinigameResult', function(success, method)
    local src = source

    local state = atmRobberyState[src]
    if not success then
        atmRobberyState[src] = nil
        return
    end

    if not state or state.method ~= method or (method ~= 'drill' and method ~= 'hack') then
        logExploit(src, 'sent minigame success without valid robbery state.')
        return
    end

    if isStateExpired(state) or not playerNearCoords(src, state.atmCoords, 5.0) then
        atmRobberyState[src] = nil
        logExploit(src, 'sent minigame success with expired or distant robbery state.')
        return
    end

    local minTime = method == 'hack' and (math.ceil(Config.Hacking.InitialHackDuration / 1000) + 3) or 5
    if os.time() - state.time < minTime then
        atmRobberyState[src] = nil
        logExploit(src, 'completed minigame impossibly fast.')
        return
    end

    state.minigamePassed = true
    atmRobberyState[src] = state
end)

RegisterNetEvent('pl_atmrobbery:server:completed')
AddEventHandler('pl_atmrobbery:server:completed', function(atmCoords)
    local src = source
    local state = atmRobberyState[src]

    if not Config.MoneyDrop then
        logExploit(src, 'tried to pick up cash while MoneyDrop is disabled.')
        return
    end

    if not state or not state.minigamePassed then
        logExploit(src, 'tried to rob ATM without completing the minigame.')
        return
    end

    if isStateExpired(state) or not playerNearCoords(src, state.atmCoords, 5.0) then
        atmRobberyState[src] = nil
        logExploit(src, 'triggered robbery too far from ATM or after state expired.')
        return
    end

    local method       = state.method or 'drill'
    local maxCashPiles = method == 'hack' and Config.Reward.hack_cash_pile or Config.Reward.drill_cash_pile

    state.pickupcash = state.pickupcash + 1
    AddPlayerMoney(src, Config.Reward.account, Config.Reward.cash_prop_value)

    TriggerClientEvent('pl_atmrobbery:notification', src, string.format(Locale('server_pickup_cash'), Config.Reward.cash_prop_value), 'success')

    if state.pickupcash >= maxCashPiles then
        atmRobberyState[src] = nil
    else
        atmRobberyState[src] = state
    end
end)

RegisterNetEvent('pl_atmrobbery:server:lootComplete')
AddEventHandler('pl_atmrobbery:server:lootComplete', function(atmCoords)
    local src = source
    local state = atmRobberyState[src]

    if Config.MoneyDrop then
        logExploit(src, 'tried to loot full ATM reward while MoneyDrop is enabled.')
        return
    end

    if not state or not state.minigamePassed then
        logExploit(src, 'tried to loot ATM without completing the minigame.')
        return
    end

    if isStateExpired(state) or not playerNearCoords(src, state.atmCoords, 5.0) then
        atmRobberyState[src] = nil
        logExploit(src, 'triggered loot too far from ATM or after state expired.')
        return
    end

    local method      = state.method or 'drill'
    local cashPiles   = method == 'hack' and Config.Reward.hack_cash_pile or Config.Reward.drill_cash_pile
    local totalReward = cashPiles * Config.Reward.cash_prop_value

    AddPlayerMoney(src, Config.Reward.account, totalReward)
    TriggerClientEvent('pl_atmrobbery:notification', src, string.format(Locale('server_pickup_cash'), totalReward), 'success')
    atmRobberyState[src] = nil
end)

RegisterNetEvent('pl_atmrobbery:rope_robbery_completed')
AddEventHandler('pl_atmrobbery:rope_robbery_completed', function(atmCoords)
    local src = source
    local state = ropeRobberyState[src]

    if not state or not state.started or not state.detached then
        logExploit(src, 'triggered rope robbery without valid completed state.')
        return
    end

    if isStateExpired(state) then
        ropeRobberyState[src] = nil
        logExploit(src, 'rope robbery expired.')
        return
    end

    local totalReward = Config.Reward.reward
    AddPlayerMoney(src, Config.Reward.account, totalReward)

    TriggerClientEvent('pl_atmrobbery:notification', src, string.format(Locale('server_pickup_cash'), totalReward), 'success')
    TriggerClientEvent('pl_atmrobbery:rope:requestCleanup', -1)

    ropeRobberyState[src] = nil
end)

lib.callback.register('pl_atmrobbery:rope:requestAttachVehicle', function(src, payload)
    if type(payload) ~= 'table' then return false, 'invalid' end
    if not payload.atmNetId or not payload.vehicleNetId then return false, 'invalid' end

    local state = ropeRobberyState[src]
    if not state or isStateExpired(state) then
        ropeRobberyState[src] = nil
        logExploit(src, 'tried to attach rope without valid robbery state.')
        return false, 'no_state'
    end

    -- Verify the ATM net ID matches what was registered at robbery start
    if payload.atmNetId ~= state.atmNetId then
        logExploit(src, 'tried to attach rope with a different ATM than robbery was started with.')
        return false, 'entity'
    end

    local atmEntity = getNetEntity(payload.atmNetId)
    local vehicleEntity = getNetEntity(payload.vehicleNetId)
    if not atmEntity or not vehicleEntity then
        if Config.DebugPrints then
            print(('[pl-atmrob] rope:requestAttachVehicle — entity lookup failed: atm=%s veh=%s'):format(tostring(atmEntity), tostring(vehicleEntity)))
        end
        return false, 'entity'
    end

    local atmCoords = GetEntityCoords(atmEntity)
    local vehicleCoords = GetEntityCoords(vehicleEntity)

    if Config.DebugPrints then
        print(('[pl-atmrob] rope:requestAttachVehicle — atmDrift=%.1f vehDist=%.1f playerDist=%.1f'):format(
            #(atmCoords - state.atmCoords),
            #(vehicleCoords - atmCoords),
            #(GetEntityCoords(GetPlayerPed(src)) - atmCoords)
        ))
    end

    if #(atmCoords - state.atmCoords) > 5.0 then
        logExploit(src, 'tried to attach rope — ATM drifted too far from original position.')
        return false, 'atm_moved'
    end

    if #(vehicleCoords - atmCoords) > 25.0 then
        logExploit(src, 'tried to attach rope — vehicle too far from ATM.')
        return false, 'too_far'
    end

    -- Player walked to the vehicle, so check against vehicle scan radius (20m) + target distance (3m) + buffer
    if not playerNearCoords(src, atmCoords, 30.0) then
        logExploit(src, 'tried to attach rope too far from ATM.')
        return false, 'too_far'
    end

    state.started = true
    state.atmNetId = payload.atmNetId
    state.vehicleNetId = payload.vehicleNetId
    state.initialAtmCoords = atmCoords
    state.initialVehicleCoords = vehicleCoords
    state.time = os.time()
    ropeRobberyState[src] = state

    TriggerClientEvent('pl_atmrobbery:rope:create', -1, {
        atmNetId = payload.atmNetId,
        vehicleNetId = payload.vehicleNetId,
        owner = src
    })

    return true
end)


RegisterNetEvent('pl_atmrobbery:rope:requestDetach', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    if not payload.atmNetId or not payload.vehicleNetId then return end

    local state = ropeRobberyState[src]
    if not state or not state.started or state.atmNetId ~= payload.atmNetId or state.vehicleNetId ~= payload.vehicleNetId then
        logExploit(src, 'tried to detach rope without valid state.')
        return
    end

    local atmEntity = getNetEntity(payload.atmNetId)
    local vehicleEntity = getNetEntity(payload.vehicleNetId)
    if not atmEntity or not vehicleEntity then
        logExploit(src, 'tried to detach rope with invalid entities.')
        return
    end

    local currentAtmCoords = GetEntityCoords(atmEntity)
    local currentVehicleCoords = GetEntityCoords(vehicleEntity)
    local atmDisplacement = #(currentAtmCoords - state.initialAtmCoords)
    local vehicleDistance = #(currentVehicleCoords - state.initialVehicleCoords)

    if vehicleDistance < Config.RopeRobbery.RequiredDistance and atmDisplacement < 3.0 then
        logExploit(src, 'tried to detach rope before moving the ATM or vehicle far enough.')
        return
    end

    state.detached = true
    state.detachedCoords = currentAtmCoords
    ropeRobberyState[src] = state

    TriggerClientEvent('pl_atmrobbery:rope:detachATM', -1, {
        atmNetId = payload.atmNetId,
        vehicleNetId = payload.vehicleNetId
    })
end)

local WaterMark = function()
    SetTimeout(1500, function()
        print('^1['..resourceName..'] ^2Thank you for Downloading the Script^0')
        print('^1['..resourceName..'] ^2If you encounter any issues please Join the discord https://discord.gg/c6gXmtEf3H to get support..^0')
        print('^1['..resourceName..'] ^2Enjoy a secret 20% OFF any script of your choice on https://pulsescripts.com/^0')
        print('^1['..resourceName..'] ^2Using the coupon code: SPECIAL20 (one-time use coupon, choose wisely)^0')
    end)
end

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        lib.versionCheck('pulsepk/pl-atmrob')
        if Config.DebugPrints then
            print('M-drilling' .. " Minigame → " .. (GetResourceState('M-drilling') == 'started' and "^2Found^7" or "^1Not Found^7"))
            print('')
        end
        if Config.WaterMark then
            WaterMark()
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    atmRobberyState[src] = nil
    ropeRobberyState[src] = nil
end)

