--[[
    LyxGuard - Events Blacklist
    Server events that should never be triggered by clients
    Based on Icarus + custom additions
]]

return {
    -- ESX Ambulance exploits
    ["esx_ambulancejob:revive"] = "Ambulance - Revive",
    ["esx_ambulancejob:setDeathStatus"] = "Ambulance - Death Status",
    
    -- ESX Jail exploits
    ["esx_jail:sendToJail"] = "Jail - Send",
    ["esx_jail:unjailQuest"] = "Jail - Unjail",
    ["esx_jailer:sendToJail"] = "Jailer - Send",
    ["esx_jailer:unjailTime"] = "Jailer - Unjail",
    ["esx-qalle-jail:jailPlayer"] = "Qalle Jail - Send",
    
    -- ESX Police exploits
    ["esx_policejob:handcuff"] = "Police - Handcuff",
    ["esx_policejob:drag"] = "Police - Drag",
    ["esx_policejob:putInVehicle"] = "Police - Put In Vehicle",
    
    -- ESX DMV exploits
    ["esx_dmvschool:addLicense"] = "DMV - Add License",
    ["dmv:success"] = "DMV - Success",
    
    -- ESX Billing exploits
    ["esx_billing:sendBill"] = "Billing - Send Bill",
    
    -- Money exploits
    ["esx:addMoney"] = "ESX - Add Money",
    ["esx:removeMoney"] = "ESX - Remove Money",
    ["esx:setMoney"] = "ESX - Set Money",
    ["esx:addAccountMoney"] = "ESX - Add Account Money",
    
    -- Job exploits
    ["esx:setJob"] = "ESX - Set Job",
    ["esx:setJobGrade"] = "ESX - Set Job Grade",
    
    -- Drug exploits
    ["esx_drugs:startHarvestWeed"] = "Drugs - Harvest Weed",
    ["esx_drugs:startTransformWeed"] = "Drugs - Transform Weed",
    ["esx_drugs:startSellWeed"] = "Drugs - Sell Weed",
    ["esx_drugs:startHarvestCoke"] = "Drugs - Harvest Coke",
    ["esx_drugs:startSellCoke"] = "Drugs - Sell Coke",
    
    -- Trainer/Menu events
    ["mellotrainer:adminTempBan"] = "MelloTrainer - Ban",
    ["mellotrainer:adminKick"] = "MelloTrainer - Kick",
    
    -- LegacyFuel exploits
    ["LegacyFuel:PayFuel"] = "LegacyFuel - Pay",
    
    -- Common cheat menu events
    ["baseevents:onPlayerKilled"] = "Base Events - Kill",
    ["esx:weaponPickedUp"] = "ESX - Weapon Pickup",
}
