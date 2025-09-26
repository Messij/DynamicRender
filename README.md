# DynamicRender

DynamicRender est un addon pour World of Warcraft destine a conserver un framerate cible en ajustant automatiquement une selection de CVars graphiques. Il verifie `GetFramerate()` toutes les `DynamicRender.CHECK_INTERVAL` secondes et compare le resultat a `targetFPS` pour savoir s'il faut reduire ou augmenter la qualite.

## Fonctionnalites
- Surveillance continue du framerate et ajustements progressifs de CVars pour rester proche de `targetFPS`.
- Priorisation des CVars: les parametres a priorite haute sont modifies avant les autres lors d'une baisse de FPS, et l'ordre est inverse quand les performances remontent.
- Fenetre de configuration accessible via `/drui` affichant les valeurs courantes, un bouton d'activation globale et des curseurs pour regler l'intervalle de controle et le seuil de tolerance.
- Ajustement manuel des priorites et des valeurs minimales directement depuis la fenetre via des boutons +/-.
- Visualisation instantanee des valeurs par des barres ASCII ainsi que l'affichage du framerate actuel.

## CVars geres
Par defaut, l'addon gere les reglages suivants:
- `RenderScale` (Echelle rendue) : 0.75 -> 1.0 par pas de 0.05
- `graphicsShadowQuality` (Qualite des ombres) : 1 -> 5
- `graphicsParticleDensity` (Densite de particules) : 1 -> 5
- `graphicsSSAO` (Occlusion ambiante) : 1 -> 4
- `graphicsDepthEffects` (Effets de profondeur) : 1 -> 3
- `graphicsComputeEffects` (Effets de calcul) : 1 -> 4
- `graphicsOutlineMode` (Contours) : 1 -> 2
- `graphicsSpellDensity` (Densite des sorts) : 1 -> 2
- `graphicsProjectedTextures` (Textures projetees) : 1 -> 1
- `graphicsViewDistance` (Distance d'affichage) : 1 -> 9
- `graphicsGroundClutter` (Detail au sol) : 1 -> 9
- `textureFilteringMode` (Filtrage anisotrope) : 1 -> 5
- `sunShafts` (Rayons de soleil) : 1 -> 2

Chaque entree definit un minimum, un maximum, un pas d'increment et une priorite. Le comportement peut etre ajuste dans `DynamicRender_Main.lua`.

## Installation
1. Copier le dossier `DynamicRender` dans `World of Warcraft/_retail_/Interface/AddOns/` si ce n'est pas deja fait.
2. Verifier que `DynamicRender.toc` apparait dans la liste des addons au lanceur et activer DynamicRender pour les personnages desires.

## Utilisation rapide
- Une fois en jeu, saisir `/drui` pour afficher la fenetre de suivi et de configuration.
- Utiliser la case "Activer DynamicRender" pour geler les ajustements sans desactiver l'addon.
- Modifier `targetFPS`, l'intervalle de verification (`DynamicRender.CHECK_INTERVAL`) et le seuil (`DynamicRender.DESIRED_FPS_THRESHOLD`) avec les sliders.
- Ajuster au besoin les priorites et les minimums de chaque CVar via les boutons +/- afin de privilegier certains reglages.

## Sauvegarde et donnees
- Le fichier TOC declare la SavedVariable `DynamicRenderDB` (pas encore exploitee).
- Les reglages modifies par l'addon sont ecrits via `C_CVar.SetCVar`; World of Warcraft s'occupe de persister ces valeurs par personnage.

## Feuille de route
Le bloc `-- To Do` en tete de `DynamicRender_Main.lua` recense plusieurs ameliorations prevues, notamment:
- Ajout de profils et de limites configurables par l'interface.
- Affichage des changements dans le chat ou une fenetre dediee.
- Gestion multi-contenu (combat, exploration, etc.).

Contributions, rapports de bug et suggestions sont les bienvenus. Ouvrez un ticket ou modifiez le code directement si vous distribuez une version personnalisee.