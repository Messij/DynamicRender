------------------------------------------------------------
-- 2) Utilitaires
------------------------------------------------------------

function DynamicRender.PrintDP(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88DynamicRender:|r "..tostring(msg))
end

function DynamicRender.CVarExists(name)
    -- Renvoie true si la CVar existe sur ce client
    local default = C_CVar.GetCVarDefault(name)
    return default ~= nil
end

function DynamicRender.GetCVarNumber(name)
    local v = C_CVar.GetCVar(name)
    return tonumber(v)
end

-- Option globale d'activation
local DYNAMIC_RENDER_ENABLED = true

function DynamicRender.SetCVarClamped(cvar, newVal)
    if not DynamicRender.CVarExists(cvar.name) then return end
    if newVal < cvar.min then newVal = cvar.min end
    if newVal > cvar.max then newVal = cvar.max end
    local cur = C_CVar.GetCVar(cvar.name)
    if tostring(newVal) ~= tostring(cur) then
        C_CVar.SetCVar(cvar.name, tostring(newVal))
        DynamicRender.PrintDP(("Modif : %s passe de %s à %s"):format(cvar.name, tostring(cur), tostring(newVal)))
        DynamicRender.UpdateCVarsWindowContent()
    end
end

function DynamicRender.GetBounds()
    local target = math.max(30, DynamicRender.GetCVarNumber("targetFPS")) or 60
    local low = math.max(10, target - DynamicRender.DESIRED_FPS_THRESHOLD)
    local high = target + DynamicRender.DESIRED_FPS_THRESHOLD
    return target, low, high
end

function DynamicRender.SortCVarsByPriority(desc)
    table.sort(DynamicRender.graphicCVars, function(a, b)
        if desc then
            return (a.priority or 0) > (b.priority or 0)
        else
            return (a.priority or 0) < (b.priority or 0)
        end
    end)
end



