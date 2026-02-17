--[[
    LyxGuard - Protection Registrar
    Runs after all protection modules load and registers them
    
    NOTA: Los módulos de protección definen una tabla 'Protection' local
    que se devuelve. Este archivo captura esas tablas.
]]

-- Wait for all modules to load and PlayerState to be available
CreateThread(function()
    Wait(4000) -- Wait longer to ensure all modules loaded
    
    -- Check if player is immune (from main.lua PlayerState)
    if PlayerState and PlayerState.immune then
        print('^3[LyxGuard]^7 Player is immune - protection loader disabled')
        return
    end
    
    -- Try to get the protection loader
    local registerFn = nil
    if exports['lyx-guard'] then
        local success, fn = pcall(function()
            return exports['lyx-guard'].RegisterProtection
        end)
        if success and fn then
            registerFn = exports['lyx-guard'].RegisterProtection
        end
    end
    
    if not registerFn then
        print('^1[LyxGuard]^7 Could not find RegisterProtection export!')
        return
    end
    
    print('^2[LyxGuard]^7 Protection registrar starting - modules should be auto-loaded...')
    
    -- Count protections in loader
    local count = 0
    if exports['lyx-guard'].GetProtection then
        local protections = {
            'anti_godmode', 'anti_health', 'anti_armor', 'anti_teleport',
            'anti_speed', 'anti_magicbullet', 'anti_weapon', 'anti_explosion',
            'anti_vehicle', 'anti_noclip', 'anti_entity', 'anti_aimbot', 'anti_tazer'
        }
        for _, name in ipairs(protections) do
            local prot = exports['lyx-guard']:GetProtection(name)
            if prot then
                count = count + 1
            end
        end
    end
    
    if count > 0 then
        print(('[^2LyxGuard^7] %d protections registered and running'):format(count))
    else
        print('^3[LyxGuard]^7 No protections registered - modules may need manual registration')
    end
end)
