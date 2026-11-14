Flight = {}

local math_abs, math_rad, math_sqrt, math_max, math_min, math_atan, math_random = math.abs, math.rad, math.sqrt, math.max, math.min, math.atan, math.random

local WORLD_UP <const> = vector3(0.0, 0.0, 1.0)

local state
local ctx = {}
local rates = {}

Start = function(vehicle)
	local forward, right, up = GetEntityMatrix(vehicle)

	local profile = GetProfile(GetEntityModel(vehicle))

	state = {
		vehicle = vehicle,
		profile = profile,
		tune = BuildTune(vehicle, profile),
		vel = GetEntityVelocity(vehicle),
		ang = ToLocal(GetEntityRotationVelocity(vehicle), right, forward, up),
		collective = 0.0,
		rpm = GetIsVehicleEngineRunning(vehicle) and 1.0 or 0.0,
		vrs = 0.0,
		airTime = 0.0,
		peakSink = 0.0,
		shaking = false,
	}

	SetHeliTurbulenceScalar(vehicle, 0.0)
	Reset()

	Log('start %s mass %.0f weight %.2f', GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)), state.tune.mass, state.tune.weight)
end

Stop = function()
	if (not state) then return end

	if (state.shaking) then
		StopGameplayCamShaking(false)
	end

	if (DoesEntityExist(state.vehicle)) then
		SetHeliTurbulenceScalar(state.vehicle, 1.0)
	end

	state = nil
end

Active = function()
	return state ~= nil
end

UpdateRotor = function(vehicle, profile, dt, grounded, vUp, running, demand, available)
	local cfg = Config.Autorotation

	if (running) then
		local target = math_max(Config.Power.MinRpm, 1.0 - profile.droop * math_max(0.0, demand - available))

		if (state.rpm < target) then
			state.rpm = math_min(target, state.rpm + dt / profile.spoolTime)
		else
			state.rpm = Approach(state.rpm, target, profile.rpmResponse, dt)
		end
	elseif (cfg.Enabled and not grounded) then
		local rpm = state.rpm - cfg.Decay * dt
		rpm = rpm + cfg.Gain * math_max(0.0, -vUp) * dt
		rpm = rpm - cfg.CollectiveDrain * math_max(0.0, state.collective) * dt
		state.rpm = Clamp(rpm, 0.0, 1.05)
	else
		state.rpm = math_max(0.0, state.rpm - dt / profile.spoolTime)
	end

	if (not running or state.rpm < 1.0) then
		SetHeliBladesSpeed(vehicle, math_min(1.0, state.rpm))
	end

	if (running) then
		return state.rpm * state.rpm
	end

	if (state.rpm < cfg.MinRpm) then
		return 0.0
	end

	return state.rpm * state.rpm * cfg.LiftScale
end

local HardLanding = function(vehicle, excess, up)
	local cfg = Config.Landing
	local damage = excess * cfg.Damage * (1.0 + cfg.TiltFactor * (1.0 - math_max(0.0, up.z)))

	SetVehicleEngineHealth(vehicle, math_max(cfg.EngineFloor, GetVehicleEngineHealth(vehicle) - damage))
	SetVehicleBodyHealth(vehicle, math_max(0.0, GetVehicleBodyHealth(vehicle) - damage * cfg.BodyScale))
	SetHeliMainRotorHealth(vehicle, math_max(0.0, GetHeliMainRotorHealth(vehicle) - damage * cfg.RotorScale))
	SetHeliTailRotorHealth(vehicle, math_max(0.0, GetHeliTailRotorHealth(vehicle) - damage * cfg.TailScale))

	LandingShake(state, excess)

	Log('hard landing excess sink %.1f damage %.0f', excess, damage)
end

Sync = function()
	if (not state) then return end

	local forward, right, up = GetEntityMatrix(state.vehicle)
	state.vel = GetEntityVelocity(state.vehicle)
	state.ang = ToLocal(GetEntityRotationVelocity(state.vehicle), right, forward, up)
end

Update = function(dt, input, preset, owner)
	local vehicle, profile, tune = state.vehicle, state.profile, state.tune
	local g = Config.Gravity

	local forward, right, up = GetEntityMatrix(vehicle)
	local actualVel = GetEntityVelocity(vehicle)
	local actualAng = ToLocal(GetEntityRotationVelocity(vehicle), right, forward, up)
	local grounded = not IsEntityInAir(vehicle)

	local excess = TrackLanding(state, vehicle, dt, grounded, owner, Config.Landing.MaxHeight)
	if (excess) then
		HardLanding(vehicle, excess, up)
	end

	Resync(state, vehicle, actualVel, actualAng)

	local pitch, roll = Attitude(right, forward, up)
	local localVel = ToLocal(state.vel, right, forward, up)
	local horizontal = math_sqrt(state.vel.x * state.vel.x + state.vel.y * state.vel.y)
	local speed = #state.vel
	local running = GetIsVehicleEngineRunning(vehicle)

	state.collective = Approach(state.collective, input.collective, tune.collectiveResponse, dt)

	local power = Config.Power
	local engine = Clamp(GetVehicleEngineHealth(vehicle) / 1000.0, 0.0, 1.0)
	local available = profile.power * (power.MinPower + (1.0 - power.MinPower) * engine)
	local demand = math_max(0.0, profile.hoverLift + state.collective * tune.collectiveGain)

	local liftFactor = UpdateRotor(vehicle, profile, dt, grounded, localVel.z, running, demand, available)

	local health = Clamp(GetHeliMainRotorHealth(vehicle) / 1000.0, 0.0, 1.0)
	local healthFactor = Config.Damage.MinLift + (1.0 - Config.Damage.MinLift) * health
	local tailDead = GetHeliTailRotorHealth(vehicle) <= Config.Damage.TailRotorDead

	local etl = 1.0 + profile.etl.bonus * Smoothstep(profile.etl.start, profile.etl.full, horizontal)

	local vrs = profile.vrs
	local vrsTarget = 0.0
	if (not grounded and liftFactor > 0.5) then
		vrsTarget = Smoothstep(vrs.sinkStart, vrs.sinkFull, -state.vel.z)
			* (1.0 - Smoothstep(vrs.speed * 0.5, vrs.speed, horizontal))
			* Clamp(0.5 + state.collective, 0.0, 1.0)
	end
	state.vrs = Approach(state.vrs, vrsTarget, vrs.response, dt)

	local inflow = Clamp((math_max(0.0, -localVel.z) - math_max(0.0, state.vel.z)) * profile.inflow.gain, -profile.inflow.max, profile.inflow.max) * (1.0 - state.vrs)

	local groundEffect = 0.0
	local ge = profile.groundEffect
	local altitude = GetEntityHeightAboveGround(vehicle)
	if (altitude < ge.height) then
		groundEffect = ge.bonus * (1.0 - Smoothstep(0.0, ge.height, altitude)) * (1.0 - Smoothstep(ge.speed * 0.5, ge.speed, horizontal))
	end

	local compensation = 1.0
	if (up.z > 0.0) then
		compensation = 1.0 + profile.tiltCompensation * (1.0 / math_max(up.z, 0.5) - 1.0)
	end

	local lift = g * demand * etl * (1.0 + inflow) * (1.0 + groundEffect) * compensation * (1.0 - vrs.loss * state.vrs) * liftFactor * healthFactor

	if (not owner or (grounded and (state.collective < Config.LiftoffCollective or up.z * lift <= g))) then
		state.vel, state.ang = actualVel, actualAng
		SetShake(state, 0.0)
		return
	end

	local authority = Smoothstep(profile.authority.start, profile.authority.full, horizontal)
	local cyclic = 1.0 + (profile.cyclicAtSpeed - 1.0) * authority
	local pedal = 1.0 + (profile.yawAtSpeed - 1.0) * authority

	local tx = -input.pitch * math_rad(tune.pitchRate) * cyclic
	local ty = input.roll * math_rad(tune.rollRate) * cyclic
	local tz = -input.yaw * math_rad(tune.yawRate) * pedal

	tx = tx + math_rad(profile.blowback) * Smoothstep(profile.vne * 0.7, profile.vne, localVel.y)

	if (tailDead) then
		tz = Config.Damage.TailSpin * (0.4 + math_max(0.0, state.collective)) * liftFactor
	else
		tz = tz - math_rad(profile.torqueYaw) * math_max(0.0, state.collective) * (1.0 - Smoothstep(5.0, 20.0, horizontal)) * liftFactor
	end

	local planar = math_sqrt(localVel.x * localVel.x + localVel.y * localVel.y)
	if (planar > 1.0) then
		local slip = math_atan(localVel.x, math_abs(localVel.y))
		local factor = Smoothstep(0.0, profile.weathervaneSpeed, planar) * (1.0 + profile.weathervaneGrowth * authority)
		tz = tz - slip * profile.weathervane * factor
	end

	if (state.vrs > 0.01) then
		local buffet = vrs.buffet * state.vrs
		tx = tx + (math_random() * 2.0 - 1.0) * buffet
		ty = ty + (math_random() * 2.0 - 1.0) * buffet
	end

	ctx.input, ctx.preset, ctx.profile = input, preset, profile
	ctx.pitch, ctx.roll, ctx.speed, ctx.dt = pitch, roll, speed, dt
	ctx.level = vector3(right.z, forward.z, up.z)

	rates.x, rates.y, rates.z = tx, ty, tz
	Angular(rates, ctx)

	state.ang = vector3(
		Approach(state.ang.x, rates.x, tune.response.x, dt),
		Approach(state.ang.y, rates.y, tune.response.y, dt),
		Approach(state.ang.z, rates.z, tune.response.z, dt)
	)

	local drag = profile.drag
	local speedScale = 1.0 + (profile.speed - 1.0) * Smoothstep(profile.speedBlend.start, profile.speedBlend.full, horizontal)
	local quadScale, linearScale = 1.0 / (speedScale * speedScale), profile.linearDrag / speedScale
	local localDrag = vector3(
		-drag.side * localVel.x * math_abs(localVel.x) - localVel.x * profile.linearDrag,
		-drag.forward * quadScale * localVel.y * math_abs(localVel.y) - localVel.y * linearScale,
		-drag.vertical * quadScale * localVel.z * math_abs(localVel.z) - localVel.z * linearScale
	)

	local accel = up * lift - WORLD_UP * g + ToWorld(localDrag, right, forward, up)

	if (speed > 1.0) then
		local along = Dot(up, state.vel) * lift / speed
		local load = math_sqrt(math_max(0.0, lift * lift - along * along)) / g - 1.0

		if (load > 0.0) then
			local bleed = profile.inducedDrag * load * g * Smoothstep(5.0, 25.0, horizontal)
			accel = accel - state.vel * (bleed / speed)
		end
	end

	accel = Linear(accel, state.vel, ctx)

	state.vel = state.vel + accel * dt

	SetEntityVelocity(vehicle, state.vel.x, state.vel.y, state.vel.z)

	local worldAng = ToWorld(state.ang, right, forward, up)
	SetEntityAngularVelocity(vehicle, worldAng.x, worldAng.y, worldAng.z)

	local over = speed - profile.vne
	if (over > 0.0) then
		SetHeliMainRotorHealth(vehicle, math_max(0.0, GetHeliMainRotorHealth(vehicle) - over * Config.Damage.Overspeed * dt))
	end

	local feel = Config.Feel
	local overspeed = Smoothstep(profile.vne * 0.95, profile.vne * 1.15, speed)
	local droop = running and Clamp((demand - available) / 0.3, 0.0, 1.0) or 0.0

	SetShake(state, math_max(state.vrs * feel.Vrs, overspeed * feel.Overspeed, droop * feel.Droop))
end
