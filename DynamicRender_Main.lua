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
-- + Ajouter option pour afficher les valeur actuelles des DynamicRender.graphicCVars dans l'interface
-- + Ajouter option pour afficher les statistiques de performance (fps, latence, etc.) dans l'interface
-- - Ajouter un score graphique en additionnant tout les parametres actuelles
-- - Utiliser le nom des variable localiser dans la langue du jeu
-- - Ajouter un systeme de profil pour sauvegarder differente configuration
-- + Ajouter un system de priorité pour chaque CVar
--   + Permet de regler les priorité dans la UI

DynamicRender = {}  -- namespace global pour ton addon

-- Incréments / limites
DynamicRender.CHECK_INTERVAL = 1.0        -- Vérifier toutes les 2s
local SCALE_STEP     = 0.05       -- Pas pour RenderScale (5%)
local SCALE_MIN      = 0.75       -- Min RenderScale
local SCALE_MAX      = 1.0       -- Max RenderScale
DynamicRender.DESIRED_FPS_THRESHOLD = 10   -- seuil haut et bas de fps par rapport à targetFPS

-- Liste des réglages graphiques surveillés et ajustés
DynamicRender.graphicCVars = {
    { name = "RenderScale",              nom = "Echelle rendue", min = SCALE_MIN, max = SCALE_MAX, step = SCALE_STEP, float = true, priority = 8 },  -- Échelle de résolution interne (1.0 = 100% natif)
    { name = "graphicsShadowQuality",    nom = "Qualité ombres", min = 1,   max = 5,   step = 1,    float = false, priority = 9 }, -- Qualité des ombres (0 = off, 5 = très haute)
  --{ name = "graphicsLiquidDetail",     nom = "Qualité de l’eau", min = 1,   max = 3,   step = 1,    float = false, priority = 1 }, -- Qualité de l’eau (0 = basse, 3 = ultra)
    { name = "graphicsParticleDensity",  nom = "Densité particules", min = 1,   max = 5,   step = 1,    float = false, priority = 8 }, -- Densité des particules (sorts, fumée, explosions)
    { name = "graphicsSSAO",             nom = "Occlusion Ambient", min = 1,   max = 4,   step = 1,    float = false, priority = 7 }, -- Ambient Occlusion (ombres douces, 0 = off, 3 = ultra)
    { name = "graphicsDepthEffects",     nom = "Effets profondeur", min = 1,   max = 3,   step = 1,    float = false, priority = 6 }, -- Effets de profondeur (brouillard volumétrique, etc.)
    { name = "graphicsComputeEffects",   nom = "Effets Opé calcul", min = 1,   max = 4,   step = 1,    float = false, priority = 5 }, -- Effet des opér. de calcul
    { name = "graphicsOutlineMode",      nom = "Mode contours", min = 1,   max = 2,   step = 1,    float = false, priority = 4 }, -- Mode contours des objets (0 = off, 3 = stylisé)
  --{ name = "graphicsTextureResolution",nom = "Résolution textures", min = 1,   max = 2,   step = 1,    float = false }, -- Résolution des textures (0 = basse, 2 = haute) / impossible, bloque l'image pendant plusieur seconde
    { name = "graphicsSpellDensity",     nom = "Densité sorts", min = 1,   max = 2,   step = 1,    float = false, priority = 3 }, -- Densité des sorts visuels (0 = faible, 2 = tout)
    { name = "graphicsProjectedTextures",nom = "Textures projetées", min = 1,   max = 1,   step = 1,    float = false, priority = 2 }, -- Textures projetées (ex. : flammes au sol) (0/1)
    { name = "graphicsViewDistance",     nom = "Distance affichage", min = 1,   max = 9,  step = 1,    float = false, priority = 1 }, -- Distance d’affichage globale (0 = faible, 9 = max)
  --{ name = "graphicsEnvironmentDetail",nom = "Détails environnement", min = 1,   max = 9,  step = 1,    float = false }, -- Détails du décor (rochers, arbres, structures) / cache-affihce certains element du decors a chaque modification (arbres, tres desagreable)
    { name = "graphicsGroundClutter",    nom = "Densité au sol", min = 1,   max = 9,  step = 1,    float = false, priority = 1 }, -- Densité d’herbes et petits objets au sol
    { name = "textureFilteringMode",     nom = "Filtrage anisotrope", min = 1,   max = 5,  step = 1,    float = false, priority = 1 }, -- Filtrage anisotrope (0 = bilinéaire, 16 = max qualité)
    { name = "sunShafts",                nom = "Rayons de soleil", min = 1,   max = 2,   step = 1,    float = false, priority = 1 }, -- Rayons de soleil ("god rays") (0 = off, 2 = max)
}


------------------------------------------------------------
-- 1) Surveillance FPS et ajustements
------------------------------------------------------------
local frame = CreateFrame("Frame")
local elapsedSinceLastCheck = 0

frame:SetScript("OnUpdate", function(self, elapsed)
    if not DYNAMIC_RENDER_ENABLED then return end -- Ajout ici
    elapsedSinceLastCheck = elapsedSinceLastCheck + elapsed
    if elapsedSinceLastCheck < DynamicRender.CHECK_INTERVAL then return end
    elapsedSinceLastCheck = 0

    local fps = GetFramerate()
    local target, FPS_LOW, FPS_HIGH = DynamicRender.GetBounds()

    if fps < FPS_LOW then
        -- BAISSE (rouge) : priorité décroissante
        DynamicRender.SortCVarsByPriority(true)
        for _, cvar in ipairs(DynamicRender.graphicCVars) do
            local val = DynamicRender.GetCVarNumber(cvar.name)
            if val then
                local newVal = cvar.float and (val - cvar.step) or (val - cvar.step)
                if newVal >= cvar.min then
                    DynamicRender.SetCVarClamped(cvar, newVal)
                    --DynamicRender.PrintDP(("FPS %.1f < %d → |cffff0000 graphismes - |r (cible %d, %s)"):format(fps, FPS_LOW, target, cvar.name))
                    break -- Une seule modification par tick
                end
            end
        end

    elseif fps > FPS_HIGH then
        -- HAUSSE (vert) : priorité croissante
        DynamicRender.SortCVarsByPriority(false)
        for _, cvar in ipairs(DynamicRender.graphicCVars) do
            local val = DynamicRender.GetCVarNumber(cvar.name)
            if val then
                local newVal = cvar.float and (val + cvar.step) or (val + cvar.step)
                if newVal <= cvar.max then
                    DynamicRender.SetCVarClamped(cvar, newVal)
                    --DynamicRender.PrintDP(("FPS %.1f > %d → |cff00ff00 graphismes + |r (cible %d, %s)"):format(fps, FPS_HIGH, target, cvar.name))
                    break -- Une seule modification par tick
                end
            end
        end
    end
end)

