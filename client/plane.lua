local math_abs, math_rad, math_sqrt, math_max, math_atan, math_sin, math_cos, math_random = math.abs, math.rad, math.sqrt, math.max, math.atan, math.sin, math.cos, math.random

local WORLD_UP <const> = vector3(0.0, 0.0, 1.0)
local GEAR_RETRACTED <const> = 4

local profiles = {}

for name, profile in pairs(Config.Planes) do
	if (name ~= 'default') then
		profiles[joaat(name)] = Merge(Config.Planes.default, profile)
	end
end

local state
local ctx = {}
local rates = {}

local LiftCoefficient = function(alpha, crit, stallLift)
	local angle = math_abs(alpha)
	local cl

	if (angle <= crit) then
		cl = angle / crit
	else
		cl = (stallLift + (1.0 - stallLift) * (1.0 - Smoothstep(crit, crit * 1.4, angle))) * math_max(0.0, math_cos(angle)) / math_cos(crit)
	end

	return alpha < 0.0 and -cl or cl
end

local LiftDirection = function(right, direction, up)
	local x = right.y * direction.z - right.z * direction.y
	local y = right.z * direction.x - right.x * direction.z
	local z = right.x * direction.y - right.y * direction.x
	local length = math_sqrt(x * x + y * y + z * z)

	if (length < 0.01) then
		return up
	end

	return vector3(x / length, y / length, z / length)
end

local TrackDrift = function(dt, actualVel, actualAng)
	local drift = state.drift

	drift.vel = math_max(drift.vel, #(actualVel - state.vel))
	drift.ang = math_max(drift.ang, #(actualAng - state.ang))
	drift.time = drift.time + dt

	if (drift.time >= 1.0) then
		Log('plane native drift vel %.2f ang %.2f speed %.0f', drift.vel, drift.ang, #state.vel)
		drift.vel, drift.ang, drift.time = 0.0, 0.0, 0.0
	end
end

local HardLanding = function(vehicle, excess)
	local cfg = Config.Landing
	local damage = excess * cfg.Damage

	SetVehicleEngineHealth(vehicle, math_max(cfg.EngineFloor, GetVehicleEngineHealth(vehicle) - damage))
	SetVehicleBodyHealth(vehicle, math_max(0.0, GetVehicleBodyHealth(vehicle) - damage * cfg.BodyScale))

	LandingShake(state, excess)

	Log('plane hard landing excess sink %.1f damage %.0f', excess, damage)
end

PlaneStart = function(vehicle)
	local forward, right, up = GetEntityMatrix(vehicle)
	local profile = profiles[GetEntityModel(vehicle)] or Config.Planes.default
	local crit = math_rad(profile.stallAngle)

	state = {
		vehicle = vehicle,
		profile = profile,
		crit = crit,
		incidence = crit * (profile.stallSpeed / profile.trimSpeed) ^ 2,
		parasitic = profile.thrust * (1.0 - profile.thrustFade) / (profile.topSpeed * profile.topSpeed),
		vel = GetEntityVelocity(vehicle),
		ang = ToLocal(GetEntityRotationVelocity(vehicle), right, forward, up),
		throttle = 0.0,
		flying = false,
		airTime = 0.0,
		peakSink = 0.0,
		shaking = false,
		drift = { vel = 0.0, ang = 0.0, time = 0.0 },
	}

	SetPlaneTurbulenceMultiplier(vehicle, 0.0)
	Reset()

	Log('start plane %s stall %.0f top %.0f', GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)), profile.stallSpeed, profile.topSpeed)
end

PlaneStop = function()
	if (not state) then return end

	if (state.shaking) then
		StopGameplayCamShaking(false)
	end

	if (DoesEntityExist(state.vehicle)) then
		SetPlaneTurbulenceMultiplier(state.vehicle, 1.0)
	end

	state = nil
end

PlaneFlying = function()
	return state ~= nil and state.flying
end

PlaneSync = function()
	if (not state) then return end

	local forward, right, up = GetEntityMatrix(state.vehicle)
	state.vel = GetEntityVelocity(state.vehicle)
	state.ang = ToLocal(GetEntityRotationVelocity(state.vehicle), right, forward, up)
end

PlaneUpdate = function(dt, input, preset, owner)
	local vehicle, profile = state.vehicle, state.profile
	local cfg = Config.Plane
	local g = Config.Gravity

	local forward, right, up = GetEntityMatrix(vehicle)
	local actualVel = GetEntityVelocity(vehicle)
	local actualAng = ToLocal(GetEntityRotationVelocity(vehicle), right, forward, up)
	local grounded = not IsEntityInAir(vehicle) or IsEntityInWater(vehicle)

	local excess = TrackLanding(state, vehicle, dt, grounded, owner, cfg.LandingHeight)
	if (excess) then
		HardLanding(vehicle, excess)
	end

	local hovering = GetVehicleFlightNozzlePosition(vehicle) > cfg.VtolNozzle

	if (grounded or hovering) then
		state.flying = false
	elseif (not state.flying and GetEntityHeightAboveGround(vehicle) > cfg.TakeoverHeight) then
		state.flying = true
	end

	local cruise = profile.cruiseThrottle
	local lever = 0.0
	if (GetIsVehicleEngineRunning(vehicle)) then
		lever = input.collective >= 0.0 and cruise + (1.0 - cruise) * input.collective or cruise * (1.0 + input.collective)
	end
	state.throttle = Approach(state.throttle, lever, profile.throttleResponse, dt)

	if (not owner or not state.flying) then
		state.vel, state.ang = actualVel, actualAng
		SetShake(state, 0.0)

		if (owner and not hovering and input.pitch ~= 0.0) then
			local stall = profile.stallSpeed
			local authority = Smoothstep(stall * cfg.RotateStart, stall * cfg.RotateFull, #actualVel)

			if (authority > 0.0) then
				local target = -input.pitch * math_rad(profile.pitchRate) * cfg.GroundPitch * authority
				state.ang = vector3(Approach(actualAng.x, target, profile.response.pitch, dt), actualAng.y, actualAng.z)

				local worldAng = ToWorld(state.ang, right, forward, up)
				SetEntityAngularVelocity(vehicle, worldAng.x, worldAng.y, worldAng.z)
			end
		end

		return
	end

	if (Config.Debug) then
		TrackDrift(dt, actualVel, actualAng)
	end

	Resync(state, vehicle, actualVel, actualAng)

	local pitch, roll = Attitude(right, forward, up)
	local localVel = ToLocal(state.vel, right, forward, up)
	local speed = #state.vel
	local direction = speed > 1.0 and state.vel / speed or forward

	local alpha, slip = 0.0, 0.0
	if (speed > 1.0) then
		alpha = math_atan(-localVel.z, localVel.y)
		slip = math_atan(localVel.x, math_abs(localVel.y))
	end

	local ratio = speed / profile.stallSpeed
	local flow = Smoothstep(profile.stallSpeed * 0.3, profile.stallSpeed * 1.2, speed)
	local effective = alpha + state.incidence
	local stalled = Smoothstep(state.crit, state.crit * 1.4, math_abs(effective))
	local lift = Clamp(g * ratio * ratio * LiftCoefficient(effective, state.crit, profile.stallLift), -profile.maxG * g * 0.5, profile.maxG * g)

	local authority = flow * (1.0 + (profile.highSpeedAuthority - 1.0) * Smoothstep(profile.cornerSpeed, profile.topSpeed, speed))

	local tx = -input.pitch * math_rad(profile.pitchRate) * authority
	local ty = input.roll * math_rad(profile.rollRate) * authority * (1.0 - profile.stallRollLoss * stalled)
	local tz = -input.yaw * math_rad(profile.yawRate) * authority

	tx = tx - Clamp(alpha, -1.0, 1.0) * profile.pitchStability * flow
	tz = tz - slip * profile.yawStability * flow

	if (stalled > 0.01) then
		local buffet = profile.stallBuffet * stalled * flow
		tx = tx + (math_random() * 2.0 - 1.0) * buffet * 0.5
		ty = ty + (math_random() * 2.0 - 1.0) * buffet
	end

	ctx.input, ctx.preset, ctx.profile = input, preset, profile
	ctx.pitch, ctx.roll, ctx.speed, ctx.dt = pitch, roll, speed, dt
	ctx.level = vector3(right.z, forward.z, up.z)

	rates.x, rates.y, rates.z = tx, ty, tz
	Angular(rates, ctx)

	local response = profile.response
	state.ang = vector3(
		Approach(state.ang.x, rates.x, response.pitch, dt),
		Approach(state.ang.y, rates.y, response.roll, dt),
		Approach(state.ang.z, rates.z, response.yaw, dt)
	)

	local parasitic = state.parasitic
	if (GetLandingGearState(vehicle) ~= GEAR_RETRACTED) then
		parasitic = parasitic * (1.0 + profile.gearDrag)
	end
	if (input.collective < 0.0) then
		parasitic = parasitic * (1.0 - profile.airbrake * input.collective)
	end

	local sine = math_sin(effective)
	local drag = parasitic * speed * speed
		+ profile.inducedDrag * lift * lift / (g * math_max(ratio * ratio, 0.25))
		+ profile.stallDrag * speed * speed * sine * sine * stalled

	local engine = Clamp(GetVehicleEngineHealth(vehicle) / 1000.0, 0.0, 1.0)
	local thrust = state.throttle * profile.thrust
		* (cfg.MinPower + (1.0 - cfg.MinPower) * engine)
		* (1.0 - profile.thrustFade * Clamp(speed / profile.topSpeed, 0.0, 1.2))

	local accel = LiftDirection(right, direction, up) * lift
		+ forward * thrust
		- right * (localVel.x * speed * profile.sideForce)
		- direction * drag
		- WORLD_UP * g

	state.vel = state.vel + accel * dt

	SetEntityVelocity(vehicle, state.vel.x, state.vel.y, state.vel.z)

	local worldAng = ToWorld(state.ang, right, forward, up)
	SetEntityAngularVelocity(vehicle, worldAng.x, worldAng.y, worldAng.z)

	local over = speed - profile.vne
	if (over > 0.0) then
		local body = GetVehicleBodyHealth(vehicle)
		if (body > cfg.BodyFloor) then
			SetVehicleBodyHealth(vehicle, math_max(cfg.BodyFloor, body - over * cfg.Overspeed * dt))
		end
	end

	local buffet = Smoothstep(state.crit * 0.8, state.crit * 1.1, math_abs(effective)) * Smoothstep(10.0, profile.stallSpeed, speed)
	local overspeed = Smoothstep(profile.vne * 0.95, profile.vne * 1.15, speed)

	SetShake(state, math_max(buffet * cfg.StallShake, overspeed * cfg.OverspeedShake))
end
