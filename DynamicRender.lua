-- DynamicRender.lua
-- To Do
-- - Ajouter option pour activer/désactiver l'addon
-- - Ajouter option pour choisir les CVars à ajuster
-- - Ajouter option pour régler l'intervalle de vérification
-- - Ajouter option pour régler le seuil de fps
-- - Ajouter option pour régler le pas d'ajustement des CVars
-- - Ajouter option pour régler les limites min/max des CVars
-- - Ajouter option pour afficher les changements dans l'interface
-- - Ajouter option pour sauvegarder/restaurer les réglages initiaux
-- - Ajouter option pour régler la priorité des CVars à ajuster
-- - Ajouter option pour régler le mode d'ajustement (progressif ou direct)
-- - Ajouter option pour régler le mode d'affichage des messages (chat, fenêtre, etc.)
-- - Ajouter option pour régler le mode d'ajustement en fonction du type de contenu (combat, exploration, etc.)
-- + Ajouter option pour afficher les valeur actuelles des graphicCVars dans l'interface
-- + Ajouter option pour afficher les statistiques de performance (fps, latence, etc.) dans l'interface
-- - Ajouter un score graphique en additionnant tout les parametres actuelles
-- - Utiliser le nom des variable localiser dans la langue du jeu
-- - Ajouter un systeme de profil pour sauvegarder differente configuration
-- + Ajouter un system de priorité pour chaque CVar
--   + Permet de regler les priorité dans la UI


-- Incréments / limites
local CHECK_INTERVAL = 1.0        -- Vérifier toutes les 2s
local SCALE_STEP     = 0.05       -- Pas pour RenderScale (5%)
local SCALE_MIN      = 0.60       -- Min RenderScale
local SCALE_MAX      = 1.0       -- Max RenderScale
local DESIRED_FPS_THRESHOLD = 5   -- seuil haut et bas de fps par rapport à targetFPS

-- Liste des réglages graphiques surveillés et ajustés
local graphicCVars = {
    { name = "RenderScale",              min = SCALE_MIN, max = SCALE_MAX, step = SCALE_STEP, float = true, priority = 10 },  -- Échelle de résolution interne (1.0 = 100% natif)

    { name = "graphicsShadowQuality",    min = 0,   max = 5,   step = 1,    float = false, priority = 9 }, -- Qualité des ombres (0 = off, 5 = très haute)
    --{ name = "graphicsLiquidDetail",     min = 0,   max = 3,   step = 1,    float = false, priority = 1 }, -- Qualité de l’eau (0 = basse, 3 = ultra)
    { name = "graphicsParticleDensity",  min = 0,   max = 5,   step = 1,    float = false, priority = 8 }, -- Densité des particules (sorts, fumée, explosions)
    { name = "graphicsSSAO",             min = 0,   max = 4,   step = 1,    float = false, priority = 7 }, -- Ambient Occlusion (ombres douces, 0 = off, 3 = ultra)
    { name = "graphicsDepthEffects",     min = 0,   max = 3,   step = 1,    float = false, priority = 6 }, -- Effets de profondeur (brouillard volumétrique, etc.)
    { name = "graphicsComputeEffects",   min = 0,   max = 4,   step = 1,    float = false, priority = 5 }, -- Effet des opér. de calcul
    { name = "graphicsOutlineMode",      min = 0,   max = 2,   step = 1,    float = false, priority = 4 }, -- Mode contours des objets (0 = off, 3 = stylisé)
    ---{ name = "graphicsTextureResolution",min = 0,   max = 2,   step = 1,    float = false }, -- Résolution des textures (0 = basse, 2 = haute) / impossible, bloque l'image pendant plusieur seconde
    { name = "graphicsSpellDensity",     min = 0,   max = 2,   step = 1,    float = false, priority = 3 }, -- Densité des sorts visuels (0 = faible, 2 = tout)
    { name = "graphicsProjectedTextures",min = 0,   max = 1,   step = 1,    float = false, priority = 2 }, -- Textures projetées (ex. : flammes au sol) (0/1)

    { name = "graphicsViewDistance",     min = 0,   max = 9,  step = 1,    float = false, priority = 1 }, -- Distance d’affichage globale (0 = faible, 9 = max)
    --{ name = "graphicsEnvironmentDetail",min = 0,   max = 9,  step = 1,    float = false }, -- Détails du décor (rochers, arbres, structures) / cache-affihce certains element du decors a chaque modification (arbres, tres desagreable)
    { name = "graphicsGroundClutter",    min = 0,   max = 9,  step = 1,    float = false, priority = 1 }, -- Densité d’herbes et petits objets au sol

    { name = "textureFilteringMode", min = 0,   max = 5,  step = 1,    float = false, priority = 1 }, -- Filtrage anisotrope (0 = bilinéaire, 16 = max qualité)

    { name = "sunShafts",        min = 0,   max = 2,   step = 1,    float = false, priority = 1 }, -- Rayons de soleil ("god rays") (0 = off, 2 = max)
}

------------------------------------------------------------
-- 2) Utilitaires
------------------------------------------------------------
local function PrintDP(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88DynamicRender:|r "..tostring(msg))
end

local function CVarExists(name)
    -- Renvoie true si la CVar existe sur ce client
    local default = C_CVar.GetCVarDefault(name)
    return default ~= nil
end

local function GetCVarNumber(name)
    local v = C_CVar.GetCVar(name)
    return tonumber(v)
end

local function UpdateCVarsWindowContent()
    if not DynamicRenderCVarsFrame or not DynamicRenderCVarsFrame:IsShown() then return end

    -- Supprime l'ancien content frame
    if DynamicRenderCVarsFrame.content then
        DynamicRenderCVarsFrame.content:Hide()
        DynamicRenderCVarsFrame.content:SetParent(nil)
        DynamicRenderCVarsFrame.content = nil
    end

    -- Recrée le content frame
    local scrollFrame
    for _, child in ipairs({DynamicRenderCVarsFrame:GetChildren()}) do
        if child:GetObjectType() == "ScrollFrame" then
            scrollFrame = child
            break
        end
    end
    if not scrollFrame then return end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    DynamicRenderCVarsFrame.content = content

    local y = -10

    -- Slider interactif pour desiredFPS
    local desiredFPS = GetCVarNumber("targetFPS") or 60
    local fpsSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    fpsSlider:SetOrientation('HORIZONTAL')
    fpsSlider:SetMinMaxValues(30, 200)
    fpsSlider:SetValue(desiredFPS)
    fpsSlider:SetWidth(250)
    fpsSlider:SetHeight(18)
    fpsSlider:SetPoint("TOPLEFT", 10, y)
    fpsSlider:EnableMouse(true)

    fpsSlider.Text = fpsSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fpsSlider.Text:SetPoint("BOTTOM", fpsSlider, "TOP", 0, 2)
    fpsSlider.Text:SetText("desiredFPS (targetFPS)")

    fpsSlider.ValueText = fpsSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fpsSlider.ValueText:SetPoint("LEFT", fpsSlider, "RIGHT", 10, 0)
    fpsSlider.ValueText:SetText(string.format("|cff00ffff%d|r / 200", desiredFPS))

    fpsSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        C_CVar.SetCVar("targetFPS", tostring(value))
        self.ValueText:SetText(string.format("|cff00ffff%d|r / 200", value))
    end)

    y = y - 38

    -- Slider pour CHECK_INTERVAL
    local intervalSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    intervalSlider:SetOrientation('HORIZONTAL')
    intervalSlider:SetMinMaxValues(0.1, 5.0)
    intervalSlider:SetValue(CHECK_INTERVAL)
    intervalSlider:SetWidth(250)
    intervalSlider:SetHeight(18)
    intervalSlider:SetPoint("TOPLEFT", 10, y)
    intervalSlider:EnableMouse(true)

    intervalSlider.Text = intervalSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    intervalSlider.Text:SetPoint("BOTTOM", intervalSlider, "TOP", 0, 2)
    intervalSlider.Text:SetText("Intervalle de vérification (s)")

    intervalSlider.ValueText = intervalSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    intervalSlider.ValueText:SetPoint("LEFT", intervalSlider, "RIGHT", 10, 0)
    intervalSlider.ValueText:SetText(string.format("|cff00ffff%.2f|r s", CHECK_INTERVAL))

    intervalSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 100) / 100
        CHECK_INTERVAL = value
        self.ValueText:SetText(string.format("|cff00ffff%.2f|r s", value))
    end)

    y = y - 38

    for i, cvar in ipairs(graphicCVars) do
        local val = GetCVarNumber(cvar.name)
        local minVal = cvar.min
        local maxVal = cvar.max

        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 10, y)

        local color = "|cffdddddd" -- gris par défaut
        if val ~= nil then
            if val <= minVal then
                color = "|cffff4444" -- rouge si min
            elseif val >= maxVal then
                color = "|cff44ff44" -- vert si max
            end
        end

        if cvar.name == "RenderScale" then
            local barLength = 10
            local percent = val and math.floor(val * 100 + 0.5) or 0
            local pos = val and math.floor(((val - minVal) / (maxVal - minVal)) * barLength + 0.5) or 0
            local bar = ""
            for j = 0, barLength do
                if j == pos then
                    bar = bar .. "|cff00ff00+|r"
                else
                    bar = bar .. "-"
                end
            end
            fs:SetText(string.format("RenderScale|cff8888ff(P:%d)|r : %s %s%d%%|r / 100%%", cvar.priority or 0, bar, color, percent))
        else
            local barLength = cvar.max
            local pos = val and math.floor(((val - minVal) / (maxVal - minVal)) * barLength + 0.5) or 0
            local bar = ""
            for j = 0, barLength do
                if j == pos then
                    bar = bar .. "|cff00ff00+|r"
                else
                    bar = bar .. "-"
                end
            end
            fs:SetText(string.format("%s|cff8888ff(P:%d)|r : %s %s%s|r / %s", cvar.name, cvar.priority or 0, bar, color, val ~= nil and val or "N/A", maxVal))
        end

        -- Ajout des boutons pour modifier la priorité
        local btnDec = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btnDec:SetSize(18, 18)
        btnDec:SetPoint("TOPLEFT", 320, y)
        btnDec:SetText("-")
        btnDec:SetScript("OnClick", function()
            cvar.priority = math.max(1, (cvar.priority or 1) - 1)
            UpdateCVarsWindowContent()
        end)

        local btnInc = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btnInc:SetSize(18, 18)
        btnInc:SetPoint("TOPLEFT", 340, y)
        btnInc:SetText("+")
        btnInc:SetScript("OnClick", function()
            cvar.priority = math.min(99, (cvar.priority or 1) + 1)
            UpdateCVarsWindowContent()
        end)

        y = y - 22
    end

    -- Affiche les FPS courants
    local currentFPS = GetFramerate()
    local fpsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fpsText:SetPoint("TOPLEFT", 10, y)
    fpsText:SetText(string.format("FPS actuel : |cff00ff00%.1f|r", currentFPS))

    y = y - 28

    content:SetHeight(-y + 10)
end

local function SetCVarClamped(cvar, newVal)
    if not CVarExists(cvar.name) then return end
    if newVal < cvar.min then newVal = cvar.min end
    if newVal > cvar.max then newVal = cvar.max end
    local cur = C_CVar.GetCVar(cvar.name)
    if tostring(newVal) ~= tostring(cur) then
        C_CVar.SetCVar(cvar.name, tostring(newVal))
        PrintDP(("Modif : %s passe de %s à %s"):format(cvar.name, tostring(cur), tostring(newVal)))
        UpdateCVarsWindowContent()
    end
end

local function GetBounds()
    local target = math.max(30, GetCVarNumber("targetFPS")) or 60
    local low = math.max(10, target - DESIRED_FPS_THRESHOLD)
    local high = target + DESIRED_FPS_THRESHOLD
    return target, low, high
end

local function SortCVarsByPriority(desc)
    table.sort(graphicCVars, function(a, b)
        if desc then
            return (a.priority or 0) > (b.priority or 0)
        else
            return (a.priority or 0) < (b.priority or 0)
        end
    end)
end

------------------------------------------------------------
-- 3) Surveillance FPS et ajustements
------------------------------------------------------------
local frame = CreateFrame("Frame")
local elapsedSinceLastCheck = 0

frame:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceLastCheck = elapsedSinceLastCheck + elapsed
    if elapsedSinceLastCheck < CHECK_INTERVAL then return end
    elapsedSinceLastCheck = 0

    local fps = GetFramerate()
    local target, FPS_LOW, FPS_HIGH = GetBounds()

    if fps < FPS_LOW then
        -- BAISSE (rouge) : priorité décroissante
        SortCVarsByPriority(true)
        for _, cvar in ipairs(graphicCVars) do
            local val = GetCVarNumber(cvar.name)
            if val then
                local newVal = cvar.float and (val - cvar.step) or (val - cvar.step)
                if newVal >= cvar.min then
                    SetCVarClamped(cvar, newVal)
                    PrintDP(("FPS %.1f < %d → |cffff0000 graphismes - |r (cible %d, %s)")
                        :format(fps, FPS_LOW, target, cvar.name))
                    break -- Une seule modification par tick
                end
            end
        end

    elseif fps > FPS_HIGH then
        -- HAUSSE (vert) : priorité croissante
        SortCVarsByPriority(false)
        for _, cvar in ipairs(graphicCVars) do
            local val = GetCVarNumber(cvar.name)
            if val then
                local newVal = cvar.float and (val + cvar.step) or (val + cvar.step)
                if newVal <= cvar.max then
                    SetCVarClamped(cvar, newVal)
                    PrintDP(("FPS %.1f > %d → |cff00ff00 graphismes + |r (cible %d, %s)")
                        :format(fps, FPS_HIGH, target, cvar.name))
                    break -- Une seule modification par tick
                end
            end
        end
    end
end)

-- UI --
local function ShowCVarsWindow()
    if DynamicRenderCVarsFrame then
        UpdateCVarsWindowContent()
        DynamicRenderCVarsFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "DynamicRenderCVarsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(400, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", -250, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Permet de redimensionner la fenêtre à la main
    frame:SetResizable(true)
    frame.minResize = {300, 300}
    frame.maxResize = {800, 800}

    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function(self, button)
        frame:StopMovingOrSizing()
        UpdateCVarsWindowContent()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Valeurs actuelles des graphicCVars")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    frame.content = content

    UpdateCVarsWindowContent()
end

SLASH_DynamicRenderUI1 = "/dp-ui"
SlashCmdList["DynamicRenderUI"] = ShowCVarsWindow

ShowCVarsWindow()
