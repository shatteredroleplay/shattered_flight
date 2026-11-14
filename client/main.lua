local freeLook = false

RegisterCommand('+shattered_heli_look', function()
	freeLook = true
end, false)

RegisterCommand('-shattered_heli_look', function()
	freeLook = false
end, false)

RegisterKeyMapping('+shattered_heli_look', 'Helikopter: fri kamera (håll)', 'keyboard', Config.FreeLookKey)

local GetPilotVehicle = function()
	local ped = PlayerPedId()
	if (IsEntityDead(ped)) then return 0 end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if (vehicle == 0 or IsEntityDead(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped) then
		return 0
	end

	local kind = GetKind(vehicle)
	if (not kind) then
		return 0
	end

	return vehicle, kind
end

local ScriptCamActive = function()
	return GetRenderingCam() ~= -1
end

local current = 0
local currentKind
local lastRequest = 0

local Release = function()
	if (current == 0) then return end

	if (currentKind == 'plane') then
		PlaneStop()
	else
		Stop()
	end

	InputReset()
	current, currentKind = 0, nil
end

CreateThread(function()
	while true do
		local vehicle, kind = GetPilotVehicle()
		local plane = kind == 'plane'

		if (vehicle == 0) then
			Release()
			Wait(500)
		elseif (ScriptCamActive()) then
			Release()
			Wait(100)
		else
			if (current ~= vehicle) then
				Release()

				if (plane) then
					PlaneStart(vehicle)
				else
					Start(vehicle)
				end

				current, currentKind = vehicle, kind
			end

			local owner = NetworkHasControlOfEntity(vehicle)
			if (not owner) then
				local now = GetGameTimer()
				if (now - lastRequest >= Config.ControlRequestInterval) then
					NetworkRequestControlOfEntity(vehicle)
					lastRequest = now
				end

				if (plane) then
					PlaneSync()
				else
					Sync()
				end
			end

			local dt = Clamp(GetFrameTime(), 0.0, 0.1)
			local look = freeLook or not IsUsingKeyboard(0)

			if (plane) then
				local animate = Config.Plane.AnimateSurfaces

				if (animate) then
					DisablePlaneControls(look)
				else
					DisableControls(look, PlaneFlying() and 2 or 4)
				end

				local input = Read(dt, look, freeLook)

				if (animate) then
					FeedSurfaces(input)
				end

				PlaneUpdate(dt, input, Config.Assist, owner)
			else
				DisableControls(look)
				Update(dt, Read(dt, look, freeLook), Config.Assist, owner)
			end

			Wait(0)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if (resource == GetCurrentResourceName()) then
		Release()
	end
end)
