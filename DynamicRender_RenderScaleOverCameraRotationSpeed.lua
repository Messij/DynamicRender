-- RenderScale over Camera Rotation Speed
-- Ajuste la résolution en fonction de la vitesse de la caméra

local lastX, lastY, lastZ
local lastTime = 0
local CAMERA_SPEED_LIMIT = 5

--local function GetCameraLinearSpeed()
--    local x, y, z = GetCameraPosition()
--    local now = GetTime()
--
--    if lastX then
--        local dx = x - lastX
--        local dy = y - lastY
--        local dz = z - lastZ
--        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
--        local dt = now - lastTime
--        if dt > 0 then
--            return dist / dt  -- unités par seconde
--        end
--    end
--
--    lastX, lastY, lastZ = x, y, z
--    lastTime = now
--    return 0
--end

local lastYaw, lastPitch
local lastRotTime = 0
local CAMERA_ROTATIONSPEED_LIMIT = 5

local function GetCameraRotationSpeed()
    local yaw = GetCVar("cameraYaw")
    local pitch = GetCVar("cameraPitch")
    local now = GetTime()

    if lastYaw then
        local dyaw = math.abs(yaw - lastYaw)
        local dpitch = math.abs(pitch - lastPitch)
        -- normaliser pour éviter le saut si on passe de 2π → 0
        if dyaw > math.pi then dyaw = 2*math.pi - dyaw end
        if dpitch > math.pi then dpitch = 2*math.pi - dpitch end

        local dtheta = math.sqrt(dyaw*dyaw + dpitch*dpitch)
        local dt = now - lastRotTime
        if dt > 0 then
            return dtheta / dt  -- radians par seconde
        end
    end

    lastYaw, lastPitch = yaw, pitch
    lastRotTime = now
    return 0
end

 -- TICK --
local DR2Frame = CreateFrame("Frame")
DR2Frame:SetScript("OnUpdate", function(self, elapsed)
    --local CameraLinearSpeed = GetCameraLinearSpeed()
    --DEFAULT_CHAT_FRAME:AddMessage(("Vitesse linéaire: %.2f u/s"):format(CameraLinearSpeed))
    local CameraRotationSpeed = GetCameraRotationSpeed()
    DEFAULT_CHAT_FRAME:AddMessage(("Vitesse rotative: %.2f rad/s"):format(CameraRotationSpeed))

    if CameraRotationSpeed > CAMERA_ROTATIONSPEED_LIMIT then
        C_CVar.SetCVar("RenderScale", 0.5)
    else
        C_CVar.SetCVar("RenderScale", 1.0)
    end
end)

