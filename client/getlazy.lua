local purchaseHistoryCache = {}

RegisterNUICallback("getRegisterData", function(_, cb)
    local registerConfig = require("config.register")
    cb({
        name = registerConfig.name,
        nationalities = registerConfig.nationalities,
        height = registerConfig.height,
        backstory = registerConfig.backstory,
        dob = registerConfig.dob
    })
end)

RegisterNUICallback("getCredits", function(_, cb)
    local credits = require("config.credits")
    cb(credits)
end)

RegisterNUICallback("getPurchaseHistory", function(_, cb)
    if not next(purchaseHistoryCache) then
        purchaseHistoryCache = lib.callback.await("um-ronin-multicharacter:getPurchaseHistory")
    end
    cb(purchaseHistoryCache)
end)
