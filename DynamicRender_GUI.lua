------------------------------------------------------------
-- 3) GUI
------------------------------------------------------------

-- Fonction utilitaire pour créer un slider
function DynamicRender.CreateSlider(parent, x, y, minVal, maxVal, currentVal, label, formatString, onChange)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetOrientation('HORIZONTAL')
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValue(currentVal)
    slider:SetWidth(250)
    slider:SetHeight(18)
    slider:SetPoint("TOPLEFT", x, y)
    slider:EnableMouse(true)

    -- Label du slider
    slider.Text = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slider.Text:SetPoint("BOTTOM", slider, "TOP", 0, 2)
    slider.Text:SetText(label)

    -- Texte de la valeur actuelle
    slider.ValueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slider.ValueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    slider.ValueText:SetText(formatString:format(currentVal, maxVal))

    -- Callback
    slider:SetScript("OnValueChanged", function(self, value)
        onChange(self, value)
        self.ValueText:SetText(formatString:format(value, maxVal))
    end)

    return slider
end


-- Ajoute le bouton dans l'UI
function DynamicRender.UpdateCVarsWindowContent()
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

    -- Bouton d'activation globale
    local enableCheck = CreateFrame("CheckButton", nil, content, "ChatConfigCheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 10, y)
    enableCheck:SetChecked(DYNAMIC_RENDER_ENABLED)
    enableCheck.Text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.Text:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
    enableCheck.Text:SetText("Activer DynamicRender")
    enableCheck:SetScript("OnClick", function(self)
        DYNAMIC_RENDER_ENABLED = self:GetChecked()
        DynamicRender.UpdateCVarsWindowContent()
    end)

    y = y - 32

    -- desiredFPS
    local desiredFPS = DynamicRender.GetCVarNumber("targetFPS") or 60
    DynamicRender.CreateSlider(content, 10, y, 30, 200, desiredFPS,
        "desiredFPS (targetFPS)", "|cff00ffff%d|r / %d",
        function(self, value)
            value = math.floor(value + 0.5)
            C_CVar.SetCVar("targetFPS", tostring(value))
        end
    )
    y = y - 38

    -- CHECK_INTERVAL
    DynamicRender.CreateSlider(content, 10, y, 0.1, 5.0, DynamicRender.CHECK_INTERVAL,
        "Intervalle de vérification (s)", "|cff00ffff%.2f|r s",
        function(self, value)
            value = math.floor(value * 100) / 100
            DynamicRender.CHECK_INTERVAL = value
        end
    )
    y = y - 38

    -- DESIRED_FPS_THRESHOLD
    DynamicRender.CreateSlider(content, 10, y, 1, 30, DynamicRender.DESIRED_FPS_THRESHOLD,
        "Seuil de FPS (DESIRED_FPS_THRESHOLD)", "|cff00ffff%d|r",
        function(self, value)
            value = math.floor(value + 0.5)
            DynamicRender.DESIRED_FPS_THRESHOLD = value
        end
    )

    y = y - 38

    for i, cvar in ipairs(DynamicRender.graphicCVars) do
        local val = DynamicRender.GetCVarNumber(cvar.name)
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
            -- Text du render scale en pourcentage
            fs:SetText(string.format("        |cff8888ff Prio:%d |r Echelle rendue %s %s %s%d|r / 100%%", cvar.priority or 0, cvar.min*100, bar, color, percent))
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
            -- texte des CVar
            fs:SetText(string.format("        |cff8888ff Prio:%d |r %s %s %s %s %s|r / %s", 
            cvar.priority or 0, cvar.nom, cvar.min,bar, color, val ~= nil and val or "N/A", maxVal))
        end

        -- Ajout des boutons pour modifier la priorité
        local btnDec = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btnDec:SetSize(18, 18)
        btnDec:SetPoint("TOPLEFT", 0, y)
        btnDec:SetText("-")
        btnDec:SetScript("OnClick", function()
            cvar.priority = math.max(1, (cvar.priority or 1) - 1)
            DynamicRender.UpdateCVarsWindowContent()
        end)
        local btnInc = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btnInc:SetSize(18, 18)
        btnInc:SetPoint("TOPLEFT", 18, y)
        btnInc:SetText("+")
        btnInc:SetScript("OnClick", function()
            cvar.priority = math.min(99, (cvar.priority or 1) + 1)
            DynamicRender.UpdateCVarsWindowContent()
        end)
        
        -- Ajout des boutons pour modifier la priorité
        local btnDec = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btnDec:SetSize(18, 18)
        btnDec:SetPoint("TOPLEFT", 340, y)
        btnDec:SetText("-")
        btnDec:SetScript("OnClick", function()
            cvar.min = math.max(0, (cvar.min or 1) - 1)
            DynamicRender.UpdateCVarsWindowContent()
        end)
        local btnInc = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btnInc:SetSize(18, 18)
        btnInc:SetPoint("TOPLEFT", 360, y)
        btnInc:SetText("+")
        btnInc:SetScript("OnClick", function()
            cvar.min = math.min(cvar.max, (cvar.min or 1) + 1)
            DynamicRender.UpdateCVarsWindowContent()
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

-- UI --
function DynamicRender.ShowCVarsWindow()
    if DynamicRenderCVarsFrame then
        DynamicRender.UpdateCVarsWindowContent()
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
        DynamicRender.UpdateCVarsWindowContent()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Valeurs actuelles des DynamicRender.graphicCVars")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    frame.content = content

    DynamicRender.UpdateCVarsWindowContent()
end

SLASH_DynamicRenderUI1 = "/drui"
SlashCmdList["DynamicRenderUI"] = DynamicRender.ShowCVarsWindow

DynamicRender.ShowCVarsWindow()