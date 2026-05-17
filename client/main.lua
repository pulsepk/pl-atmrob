local cashObjects = {}
local ropeAttachedATMs = {}
local robbedATMCoords = {}

local atmModels = {
    ["prop_atm_01"] = vector3(0.072237, 0.50293, 0.779063),
    ["prop_atm_02"] = vector3(0.01,0.11,0.92),
    ["prop_atm_03"] = vector3(-0.14,-0.01,0.88),
    ["prop_fleeca_atm"] = vector3(0.127, 0.017, 1.0)
}

function IsATMAlreadyRobbed(atmCoords)
    for _, robbedCoords in pairs(robbedATMCoords) do
        if #(atmCoords - robbedCoords) < 1.0 then
            return true
        end
    end
    return false
end

function MarkATMAsRobbed(atmCoords)
    table.insert(robbedATMCoords, atmCoords)
end

local _ropeModels = { prop_fleeca_atm = true, prop_atm_02 = true, prop_atm_03 = true }

local function canInteractGeneric(entity, action)
    for _, st in pairs(ropeAttachedATMs) do
        local atmEnt = NetToEnt(st.atmNetId)
        if atmEnt ~= 0 and atmEnt == entity then
            if action == 'rope' then return false end
            if action == 'hack' or action == 'drill' then
                if st.detached or st.ropeAttached then return false end
            end
        end
    end
    local coords = GetEntityCoords(entity)
    return not IsATMAlreadyRobbed(coords)
end

for _, model in ipairs(Config.AtmModels) do
    local options = {}
    if Config.EnableHacking then
        table.insert(options, {
            name        = 'hack_' .. model,
            label       = Locale('hack_atm_label'),
            icon        = 'fas fa-laptop-code',
            distance    = 2.0,
            item        = Config.HackingItem,
            event       = 'pl_atmrobbery_hack',
            canInteract = function(entity) return canInteractGeneric(entity, 'hack') end,
        })
    end
    if Config.EnableDrilling then
        table.insert(options, {
            name        = 'drill_' .. model,
            label       = Locale('drill_atm_label'),
            icon        = 'fas fa-tools',
            distance    = 2.0,
            item        = Config.DrillItem,
            event       = 'pl_atmrobbery_drill',
            canInteract = function(entity) return canInteractGeneric(entity, 'drill') end,
        })
    end
    if Config.EnableRopeRobbery and _ropeModels[model] then
        table.insert(options, {
            name        = 'rope_' .. model,
            label       = Locale('rope_atm_label'),
            icon        = 'fas fa-link',
            distance    = 2.0,
            item        = Config.RopeItem,
            event       = 'pl_atmrobbery_rope',
            canInteract = function(entity) return canInteractGeneric(entity, 'rope') end,
        })
    end
    if #options > 0 then
        exports['pl_lib']:AddModelTarget(model, options)
    end
end

function AddCashToTarget(cash, atmCoords)
    exports['pl_lib']:AddEntityTarget(cash, {
        name     = 'pickup_cash',
        label    = Locale('pick_up_cash'),
        icon     = 'fas fa-money-bill-wave',
        distance = 1.5,
        event    = 'pl_atmrobbery:pickupCash',
        args     = atmCoords,
    })
end

RegisterNetEvent('pl_atmrobbery:notification')
AddEventHandler('pl_atmrobbery:notification', function(message, ntype)
    Notify(message, ntype)
end)

local function TryStartRobbery(method, atmCoords, atmEntity)
    NetworkRegisterEntityAsNetworked(atmEntity)
    local atmNetId = NetworkGetNetworkIdFromEntity(atmEntity)
    if not atmNetId or atmNetId == 0 then
        TriggerEvent('pl_atmrobbery:notification', Locale('failed_robbery'), 'error')
        return false
    end

    local ok, reason = lib.callback.await('pl_atmrobbery:server:startRobbery', false, method, atmCoords, atmNetId)
    if ok then return true end

    if reason == 'police' then
        TriggerEvent('pl_atmrobbery:notification', Locale('not_enough_police'), 'error')
    elseif reason == 'cooldown' then
        TriggerEvent('pl_atmrobbery:notification', Locale('wait_robbery'), 'error')
    else
        TriggerEvent('pl_atmrobbery:notification', Locale('failed_robbery'), 'error')
    end

    return false
end

RegisterNetEvent('pl_atmrobbery_drill')
AddEventHandler('pl_atmrobbery_drill', function(data)
    if not data then return end
    local entity = data.entity
    local atmModel = GetEntityModel(entity)

    if entity and DoesEntityExist(entity) then
        local atmCoords = GetEntityCoords(entity)
        if not IsPedHeadingTowardsPosition(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 10.0) then
            TaskTurnPedToFaceCoord(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 1500)
        end

        if TryStartRobbery('drill', atmCoords, entity) then
            Wait(1000)
            if Config.Police.notify then
                SendDispatch()
            end
            if GetResourceState('M-drilling') ~= 'started' then
                print("^1[ATM Robbery]^0 Drilling minigame resource not found or not started: M-drilling")
            end
            TriggerEvent("Drilling:Start", function(success)
                if success then
                    TriggerServerEvent('pl_atmrobbery:MinigameResult', true, 'drill')
                    if not Config.MoneyDrop then
                        LootATM(atmCoords)
                    else
                        TriggerEvent('pl_atmrobbery_drill:success', entity, atmCoords, atmModel)
                    end
                else
                    TriggerServerEvent('pl_atmrobbery:MinigameResult', false, 'drill')
                end
            end)
        end
    end
end)

RegisterNetEvent('pl_atmrobbery_hack')
AddEventHandler('pl_atmrobbery_hack', function(data)
    if not data then return end
    local entity = data.entity
    local atmModel = GetEntityModel(entity)

    if entity and DoesEntityExist(entity) then
        local atmCoords = GetEntityCoords(entity)
        if not IsPedHeadingTowardsPosition(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 10.0) then
            TaskTurnPedToFaceCoord(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 1500)
        end

        if TryStartRobbery('hack', atmCoords, entity) then
            Wait(1000)
            if Config.Police.notify then
                SendDispatch()
            end
            lib.progressBar({
                duration = Config.Hacking.InitialHackDuration,
                label = 'Initializing Hack',
                useWhileDead = false,
                canCancel = false,
                disable = { car = true, move = true, combat = true },
                anim = { dict = 'missheist_jewel@hacking', clip = 'hack_loop' }
            })
            TriggerEvent('pl_atmrobbery:StartMinigame', entity, atmCoords, atmModel)
        end
    end
end)

function LootATM(atmCoords)
    lib.progressBar({
        duration = Config.Hacking.LootAtmDuration,
        label = 'Collecting Cash',
        useWhileDead = false,
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'oddjobs@shop_robbery@rob_till', clip = 'loop' }
    })
    TriggerServerEvent('pl_atmrobbery:server:lootComplete', atmCoords)
end

RegisterNetEvent('pl_atmrobbery:StartMinigame', function(entity, atmCoords, atmModel)
    local function handleResult(success)
        if success then
            TriggerServerEvent('pl_atmrobbery:MinigameResult', true, 'hack')
            if Config.MoneyDrop then
                TriggerEvent("pl_atmrobbery:spitCash", entity, atmCoords, atmModel)
            else
                LootATM(atmCoords)
            end
        else
            TriggerServerEvent('pl_atmrobbery:MinigameResult', false)
            TriggerEvent('pl_atmrobbery:notification', Locale('failed_robbery'), 'error')
        end
    end

    RunMinigame(handleResult)
end)

RegisterNetEvent("pl_atmrobbery:pickupCash")
AddEventHandler("pl_atmrobbery:pickupCash", function(data)
    if not data then return end
    local entity    = data.entity
    local atmCoords = data.args
    local playerPed = PlayerPedId()

    LoadAnimDict("pickup_object")
    TaskPlayAnim(playerPed, "pickup_object", "pickup_low", 8.0, -8.0, -1, 48, 0, false, false, false)
    Wait(1000)

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        TriggerServerEvent('pl_atmrobbery:server:completed', atmCoords)
    end
    ClearPedTasks(playerPed)
end)

local function getModelNameFromHash(hash)
    for modelName, _ in pairs(atmModels) do
        if GetHashKey(modelName) == hash then
            return modelName
        end
    end
    return nil
end

local function SpawnCashPiles(cashModel, count, atmEntity, atmCoords, atmModel)
    if not EnsureModel(cashModel) then return end

    local atmForward   = GetEntityForwardVector(atmEntity)
    local atmHeading   = GetEntityHeading(atmEntity)
    local atmModelName = getModelNameFromHash(atmModel)
    local dropOffset   = atmModels[atmModelName] or vector3(0, 0, 0.5)
    local dropPosition = atmCoords + dropOffset

    for i = 1, count do
        Wait(150)
        local cash = CreateObject(GetHashKey(cashModel), dropPosition.x, dropPosition.y, dropPosition.z, true, true, true)
        SetEntityHeading(cash, atmHeading)

        if atmModelName ~= "prop_atm_01" then
            SetEntityNoCollisionEntity(cash, atmEntity, false)
            SetEntityNoCollisionEntity(atmEntity, cash, false)
        end

        SetEntityVelocity(cash, atmForward.x * 2, atmForward.y * 2, 0.2)
        AddCashToTarget(cash, atmCoords)
        table.insert(cashObjects, cash)
    end
end

RegisterNetEvent("pl_atmrobbery_drill:success")
AddEventHandler("pl_atmrobbery_drill:success", function(atmEntity, atmCoords, atmModel)
    SpawnCashPiles("hei_prop_heist_cash_pile", Config.Reward.drill_cash_pile, atmEntity, atmCoords, atmModel)
end)

RegisterNetEvent("pl_atmrobbery:spitCash")
AddEventHandler("pl_atmrobbery:spitCash", function(atmEntity, atmCoords, atmModel)
    SpawnCashPiles("prop_anim_cash_pile_01", Config.Reward.hack_cash_pile, atmEntity, atmCoords, atmModel)
end)

local function BuildAtmAttachmentPoint(atmEntity)
    local atmCoords = GetEntityCoords(atmEntity)
    local atmForward = GetEntityForwardVector(atmEntity)
    return atmCoords + (atmForward * 0.5) + vector3(0, 0, 0.5)
end

local function GetVehicleAttachPoint(vehicle)
    return GetOffsetFromEntityInWorldCoords(vehicle, 0, -2.0, 0.5)
end

RegisterNetEvent('pl_atmrobbery:rope:create', function(payload)
    if type(payload) ~= 'table' or not payload.atmNetId or not payload.vehicleNetId then return end
    local atmEntity = NetToEnt(payload.atmNetId)
    local vehicle = NetToEnt(payload.vehicleNetId)
    if atmEntity == 0 or vehicle == 0 then return end

    -- Prevent duplicate ropes
    if ropeAttachedATMs[payload.atmNetId] and ropeAttachedATMs[payload.atmNetId].rope then
        return
    end

    local atmAttachmentPoint = BuildAtmAttachmentPoint(atmEntity)
    local vehicleBack = GetVehicleAttachPoint(vehicle)
    local ropeLength = #(atmAttachmentPoint - vehicleBack)

    Utils.EnsureRopeTexturesLoaded()

    local rope = AddRope(
        atmAttachmentPoint.x, atmAttachmentPoint.y, atmAttachmentPoint.z,
        0.0, 0.0, 0.0,
        ropeLength,
        0,
        ropeLength,
        ropeLength * 0.8,
        1.0,
        false,
        true,
        false,
        1.0,
        true
    )

    if not DoesRopeExist(rope) then
        Utils.CleanupRopeTexturesIfUnused()
        return
    end

    AttachEntitiesToRope(
        rope, atmEntity, vehicle,
        atmAttachmentPoint.x, atmAttachmentPoint.y, atmAttachmentPoint.z - 0.2,
        vehicleBack.x, vehicleBack.y, vehicleBack.z - 0.2,
        ropeLength, false, false, "", ""
    )

    ropeAttachedATMs[payload.atmNetId] = ropeAttachedATMs[payload.atmNetId] or {}
    local st = ropeAttachedATMs[payload.atmNetId]
    st.atmNetId = payload.atmNetId
    st.vehicleNetId = payload.vehicleNetId
    st.rope = rope
    st.ropeAttached = true
    st.detached = st.detached or false
    st.atmAttachmentPoint = atmAttachmentPoint
    st.vehicleAttachmentPoint = vehicleBack
end)

RegisterNetEvent('pl_atmrobbery:rope:detachATM', function(payload)
    local atmEntity = NetToEnt(payload.atmNetId)
    local vehicle = NetToEnt(payload.vehicleNetId)
    if atmEntity == 0 then return end

    TryRequestControl(atmEntity, 500)

    local atmCoords = GetEntityCoords(atmEntity)

    DetachEntity(atmEntity, true, true)
    SetEntityDynamic(atmEntity, true)
    SetEntityHasGravity(atmEntity, true)
    SetEntityCollision(atmEntity, true, true)

    FreezeEntityPosition(atmEntity, true)
    Wait(250)
    FreezeEntityPosition(atmEntity, false)

    if vehicle ~= 0 then
        local vehicleCoords = GetEntityCoords(vehicle)
        local pullDirection = vehicleCoords - atmCoords
        local pullForce = 8.0

        SetEntityVelocity(atmEntity,
            pullDirection.x * pullForce,
            pullDirection.y * pullForce,
            -5.0
        )
    end

    SetEntityAngularVelocity(atmEntity, 3.0, 3.0, 10.0)

    ropeAttachedATMs[payload.atmNetId] = ropeAttachedATMs[payload.atmNetId] or {}
    ropeAttachedATMs[payload.atmNetId].detached = true
    ropeAttachedATMs[payload.atmNetId].ropeAttached = false

    local atmCoordsNow = GetEntityCoords(atmEntity)
    RemoveGlobalATMOptions(atmEntity)
    AddDetachedATMTarget(atmEntity, atmCoordsNow, GetEntityModel(atmEntity))

    TriggerEvent('pl_atmrobbery:notification', Locale('atm_detached'), 'success')
end)

RegisterNetEvent('pl_atmrobbery:rope:cleanup', function(payload)
    if type(payload) ~= 'table' or not payload.atmNetId then return end
    local st = ropeAttachedATMs[payload.atmNetId]
    if st and st.rope and DoesRopeExist(st.rope) then
        DeleteRope(st.rope)
    end
    ropeAttachedATMs[payload.atmNetId] = nil
    Utils.CleanupRopeTexturesIfUnused()
end)

RegisterNetEvent('pl_atmrobbery_rope')
AddEventHandler('pl_atmrobbery_rope', function(data)
    if not data then return end
    local entity = data.entity
    local atmModel = GetEntityModel(entity)

    if entity and DoesEntityExist(entity) then
        local atmCoords = GetEntityCoords(entity)
        if not IsPedHeadingTowardsPosition(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 10.0) then
            TaskTurnPedToFaceCoord(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 1500)
        end

        if TryStartRobbery('rope', atmCoords, entity) then
            Wait(1000)
            if Config.Police.notify then
                SendDispatch()
            end
            StartRopeAttachment(entity, atmCoords, atmModel)
        end
    end
end)

function StartRopeAttachment(atmEntity, atmCoords, atmModel)
    NetworkRegisterEntityAsNetworked(atmEntity)
    local atmNetId = NetworkGetNetworkIdFromEntity(atmEntity)

    SetEntityDynamic(atmEntity, true)
    SetEntityHasGravity(atmEntity, false)
    SetEntityCollision(atmEntity, true, true)

    lib.progressBar({
        duration = 3000,
        label = 'Attaching Rope to ATM',
        useWhileDead = false,
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
    })

    ropeAttachedATMs[atmNetId] = {
        atmNetId = atmNetId,
        initialAtmCoords = atmCoords,
        model = atmModel,
        ropeAttached = false,
        detached = false
    }

    TriggerEvent('pl_atmrobbery:notification', Locale('rope_attached'), 'success')
    AddVehicleRopeTarget(atmNetId, atmEntity)
end

function AddVehicleRopeTarget(atmNetId, atmEntity)
    local vehicles = GetGamePool('CVehicle')
    local atmCoords = GetEntityCoords(atmEntity)
    local nearbyVehicles = {}

    for _, vehicle in pairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            if #(atmCoords - vehicleCoords) <= 20.0 then
                table.insert(nearbyVehicles, vehicle)
            end
        end
    end

    for _, vehicle in pairs(nearbyVehicles) do
        exports['pl_lib']:AddEntityTarget(vehicle, {
            name     = 'attach_rope_' .. atmNetId,
            label    = Locale('attach_rope_to_vehicle'),
            icon     = 'fas fa-link',
            distance = 3.0,
            event    = 'pl_atmrobbery_attach_vehicle_rope',
            args     = { atmNetId = atmNetId },
        })
    end

    ropeAttachedATMs[atmNetId].targetedVehicles = nearbyVehicles
end

function RemoveVehicleRopeTargetByNetId(atmNetId)
    local st = ropeAttachedATMs[atmNetId]
    if st and st.targetedVehicles then
        for _, vehicle in pairs(st.targetedVehicles) do
            if DoesEntityExist(vehicle) then
                exports['pl_lib']:RemoveEntityTarget(vehicle)
            end
        end
        st.targetedVehicles = nil
    end
end

RegisterNetEvent('pl_atmrobbery_attach_vehicle_rope')
AddEventHandler('pl_atmrobbery_attach_vehicle_rope', function(data)
    if not data then return end
    local vehicle  = data.entity
    local atmNetId = data.args and data.args.atmNetId

    if not vehicle or not atmNetId then return end
    if not DoesEntityExist(vehicle) then return end

    local st = ropeAttachedATMs[atmNetId]
    if not st or st.ropeAttached then
        TriggerEvent('pl_atmrobbery:notification', 'Rope already attached or ATM not ready.', 'error')
        return
    end

    NetworkRegisterEntityAsNetworked(vehicle)
    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)

    st.ropeAttached = true
    st.vehicleNetId = vehicleNetId

    TriggerServerEvent('pl_atmrobbery:rope:requestAttachVehicle', {
        atmNetId = atmNetId,
        vehicleNetId = vehicleNetId
    })

    TriggerEvent('pl_atmrobbery:notification', Locale('rope_vehicle_attached'), 'success')
    RemoveVehicleRopeTargetByNetId(atmNetId)

    MonitorVehicleMovement(atmNetId)
end)

function MonitorVehicleMovement(atmNetId)
    CreateThread(function()
        local st = ropeAttachedATMs[atmNetId]
        if not st or not st.vehicleNetId then return end

        local atmEntity = NetToEnt(atmNetId)
        local vehicle = NetToEnt(st.vehicleNetId)
        if atmEntity == 0 or vehicle == 0 then return end

        local initialVehicleCoords = GetEntityCoords(vehicle)
        local initialAtmCoords = GetEntityCoords(atmEntity)

        while ropeAttachedATMs[atmNetId] and ropeAttachedATMs[atmNetId].ropeAttached and not ropeAttachedATMs[atmNetId].detached do
            Wait(100)

            atmEntity = NetToEnt(atmNetId)
            vehicle = NetToEnt(st.vehicleNetId)
            if atmEntity == 0 or vehicle == 0 then break end

            local currentVehicleCoords = GetEntityCoords(vehicle)
            local currentAtmCoords = GetEntityCoords(atmEntity)

            local vehicleDistance = #(currentVehicleCoords - initialVehicleCoords)
            local atmDisplacement = #(currentAtmCoords - initialAtmCoords)

            local ropeLength = #(currentVehicleCoords - currentAtmCoords)
            if ropeLength > Config.RopeRobbery.TautRopeLength then
                local vehicleVelocity = GetEntityVelocity(vehicle)
                local dragForce = Config.RopeRobbery.DragForce
                SetEntityVelocity(vehicle, vehicleVelocity.x * (1 - dragForce), vehicleVelocity.y * (1 - dragForce), vehicleVelocity.z)

                if atmDisplacement < 2.0 then
                    local pullDirection = currentVehicleCoords - currentAtmCoords
                    local pullForce = Config.RopeRobbery.ResistanceForce * 0.1
                    local atmVelocity = GetEntityVelocity(atmEntity)
                    SetEntityVelocity(atmEntity,
                        atmVelocity.x + pullDirection.x * pullForce,
                        atmVelocity.y + pullDirection.y * pullForce,
                        atmVelocity.z
                    )
                end
            end

            if vehicleDistance >= Config.RopeRobbery.RequiredDistance or atmDisplacement >= 3.0 then
                TriggerServerEvent('pl_atmrobbery:rope:requestDetach', {
                    atmNetId = atmNetId,
                    vehicleNetId = st.vehicleNetId
                })
                break
            end

            if ropeLength > Config.RopeRobbery.MaxRopeLength then
                TriggerEvent('pl_atmrobbery:notification', Locale('rope_robbery_failed'), 'error')
                break
            end
        end
    end)
end

function RemoveGlobalATMOptions(atmEntity)
    exports['pl_lib']:RemoveEntityTarget(atmEntity)
end

function AddDetachedATMTarget(atmEntity, atmCoords, atmModel)
    exports['pl_lib']:AddEntityTarget(atmEntity, {
        name     = 'rob_detached',
        label    = Locale('rob_detached_atm'),
        icon     = 'fas fa-money-bill-wave',
        distance = 1.5,
        event    = 'pl_atmrobbery_rob_detached',
        args     = { coords = atmCoords, model = atmModel },
    })
end

RegisterNetEvent('pl_atmrobbery_rob_detached')
AddEventHandler('pl_atmrobbery_rob_detached', function(data)
    if not data then return end
    local entity    = data.entity
    local atmCoords = data.args and data.args.coords
    local atmModel  = data.args and data.args.model

    if not entity or not DoesEntityExist(entity) then return end

    local atmNetId         = NetworkGetNetworkIdFromEntity(entity)
    local st               = ropeAttachedATMs[atmNetId]
    local initialAtmCoords = st and st.initialAtmCoords

    if st and st.rope and DoesRopeExist(st.rope) then
        DeleteRope(st.rope)
    end

    ropeAttachedATMs[atmNetId] = nil
    Utils.CleanupRopeTexturesIfUnused()

    exports['pl_lib']:RemoveEntityTarget(entity)

    local currentAtmCoords = GetEntityCoords(entity)
    if initialAtmCoords then
        MarkATMAsRobbed(initialAtmCoords)
    end

    TriggerServerEvent('pl_atmrobbery:rope_robbery_completed', currentAtmCoords)
end)

RegisterNetEvent('pl_atmrobbery:rope:requestCleanup', function()
    ForceDeleteRopes()
end)

function DeleteCashObjects()
    for _, cash in pairs(cashObjects) do
        exports['pl_lib']:RemoveEntityTarget(cash)
        DeleteEntity(cash)
    end
    cashObjects = {}
end

CreateThread(function()
    while true do
        Wait(5000)
        local atmEntities = {}
        for _, model in ipairs(Config.AtmModels) do
            local entities = GetGamePool('CObject')
            for _, entity in pairs(entities) do
                if DoesEntityExist(entity) and GetEntityModel(entity) == GetHashKey(model) then
                    table.insert(atmEntities, entity)
                end
            end
        end

        for _, entity in pairs(atmEntities) do
            if DoesEntityExist(entity) then
                local coords = GetEntityCoords(entity)
                if IsATMAlreadyRobbed(coords) then
                    DeleteEntity(entity)
                end
            end
        end
    end
end)

function ForceDeleteRopes()
    for atmNetId, st in pairs(ropeAttachedATMs) do
        if st.rope and DoesRopeExist(st.rope) then
            DeleteRope(st.rope)
        end
    end
    ropeAttachedATMs = {}
    Utils.CleanupRopeTexturesIfUnused()
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeleteCashObjects()
        for atmNetId, st in pairs(ropeAttachedATMs) do
            if st.rope and DoesRopeExist(st.rope) then
                DeleteRope(st.rope)
            end
        end
        ropeAttachedATMs = {}
        Utils.CleanupRopeTexturesIfUnused()
    end
end)
