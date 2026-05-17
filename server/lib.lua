-- Thin wrapper: pl_lib server exports → pl-atmrob globals.
local _lib = exports['pl_lib']

function getPlayer(src)           return _lib:GetPlayer(src)           end
function getPlayerName(src)       return _lib:GetPlayerName(src)       end
function getPlayerIdentifier(src) return _lib:GetPlayerIdentifier(src) end
function GetJob(src)              return _lib:GetJob(src)              end

function AddPlayerMoney(src, account, amount)
    _lib:AddPlayerMoney(src, account, amount)
end

function RemoveItem(src, item, amount)
    return _lib:RemoveItem(src, item, amount)
end
