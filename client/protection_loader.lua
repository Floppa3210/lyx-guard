--[[
    LyxGuard - Protection Loader
    Loads and manages all protection modules with main loop
]]

local ProtectionLoader = {}

-- All loaded protections
local Protections = {}
local IsInitialized = false
local IsRunning = true

-- Detection callback - sends to server
local function OnDetection(protectionName, details, action)
    print(('[^1LyxGuard^7] Detection: %s - %s (Action: %s)'):format(protectionName, details or '', action or 'WARN'))
    
    -- Send to server for processing
    TriggerServerEvent('lyxguard:detection', {
        type = protectionName,
        details = details,
        action = action,
        timestamp = os.time()
    })
end

-- Register a protection module
function ProtectionLoader.Register(name, protection)
    if not protection then 
        print(('[^3LyxGuard^7] Failed to register protection: %s'):format(name))
        return 
    end
    
    -- Set detection callback
    protection.OnDetection = OnDetection
    
    -- Store protection
    Protections[name] = protection
    
    -- Initialize if config available
    if protection.Init and Config then
        protection.Init(Config)
    end
    
    print(('[^2LyxGuard^7] Protection registered: %s'):format(name))
end

-- Get a protection by name
function ProtectionLoader.Get(name)
    return Protections[name]
end

-- Get all protections
function ProtectionLoader.GetAll()
    return Protections
end

-- Enable/disable a protection
function ProtectionLoader.SetEnabled(name, enabled)
    if Protections[name] then
        Protections[name].Enabled = enabled
        print(('[^2LyxGuard^7] Protection %s: %s'):format(name, enabled and 'ENABLED' or 'DISABLED'))
    end
end

-- Stop all protections
function ProtectionLoader.Stop()
    IsRunning = false
end

-- Main protection loop
CreateThread(function()
    -- Wait for resources to load
    Wait(3000)
    
    print('^2[LyxGuard]^7 Protection Loader starting...')
    
    -- Load protection modules
    -- They are loaded by fxmanifest and register themselves via return
    -- We need to manually require them here since Lua doesn't auto-register
    
    local moduleNames = {
        'anti_godmode', 'anti_health', 'anti_armor', 'anti_teleport',
        'anti_speed', 'anti_magicbullet', 'anti_weapon', 'anti_explosion',
        'anti_vehicle', 'anti_noclip', 'anti_entity', 'anti_aimbot', 'anti_tazer'
    }
    
    -- Note: FiveM loads all files in the order specified in fxmanifest
    -- The protection modules return themselves, so we need to capture them
    
    IsInitialized = true
    print(('[^2LyxGuard^7] Protection Loader initialized with %d protections'):format(#moduleNames))
    
    -- Main loop
    while IsRunning do
        Wait(100) -- Fast check loop
        
        -- Run all enabled protections
        for name, protection in pairs(Protections) do
            if protection.Enabled and protection.Run then
                local success, err = pcall(protection.Run)
                if not success then
                    print(('[^1LyxGuard^7] Error in %s: %s'):format(name, tostring(err)))
                end
            end
        end
    end
end)

-- Export for protection modules to register themselves
exports('RegisterProtection', ProtectionLoader.Register)
exports('GetProtection', ProtectionLoader.Get)
exports('SetProtectionEnabled', ProtectionLoader.SetEnabled)

return ProtectionLoader
