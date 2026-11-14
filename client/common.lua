local math_max, math_min = math.max, math.min

SetShake = function(state, amplitude)
	local cfg = Config.Feel

	if (cfg.Enabled and amplitude > cfg.ShakeThreshold) then
		amplitude = math_min(amplitude, cfg.MaxShake)

		if (state.shaking) then
			SetGameplayCamShakeAmplitude(amplitude)
		else
			ShakeGameplayCam(cfg.Shake, amplitude)
			state.shaking = true
		end
	elseif (state.shaking) then
		StopGameplayCamShaking(false)
		state.shaking = false
	end
end

LandingShake = function(state, excess)
	if (not Config.Feel.Enabled) then return end

	ShakeGameplayCam('JOLT_SHAKE', math_min(1.0, excess * Config.Feel.Landing))
	state.shaking = false
end

Resync = function(state, vehicle, actualVel, actualAng)
	if (HasEntityCollidedWithAnything(vehicle) or #(actualVel - state.vel) > Config.ResyncVelocity) then
		state.vel = actualVel
		state.ang = actualAng
	end
end

TrackLanding = function(state, vehicle, dt, grounded, owner, maxHeight)
	local cfg = Config.Landing
	local excess

	if (grounded) then
		if (owner and state.airTime >= cfg.MinAirTime and GetEntityHeightAboveGround(vehicle) < maxHeight) then
			local over = state.peakSink - cfg.SafeSink
			if (over > 0.0) then
				excess = over
			end
		end
		state.airTime, state.peakSink = 0.0, 0.0
	else
		state.airTime = state.airTime + dt
		state.peakSink = math_max(-state.vel.z, state.peakSink - cfg.SinkDecay * dt)
	end

	return excess
end
