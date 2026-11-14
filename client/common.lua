local math_max, math_min = math.max, math.min

SetShake = function(state, amplitude)
	if (amplitude > 0.03) then
		amplitude = math_min(amplitude, 1.5)

		if (state.shaking) then
			SetGameplayCamShakeAmplitude(amplitude)
		else
			ShakeGameplayCam('SKY_DIVING_SHAKE', amplitude)
			state.shaking = true
		end
	elseif (state.shaking) then
		StopGameplayCamShaking(false)
		state.shaking = false
	end
end

LandingShake = function(state, excess)
	ShakeGameplayCam('JOLT_SHAKE', math_min(1.0, excess * 0.15))
	state.shaking = false
end

Resync = function(state, vehicle, actualVel, actualAng)
	if (HasEntityCollidedWithAnything(vehicle) or #(actualVel - state.vel) > 10.0) then
		state.vel = actualVel
		state.ang = actualAng
	end
end

TrackLanding = function(state, vehicle, dt, grounded, owner, maxHeight)
	local excess

	if (grounded) then
		if (owner and state.airTime >= 0.75 and GetEntityHeightAboveGround(vehicle) < maxHeight) then
			local over = state.peakSink - 3.5
			if (over > 0.0) then
				excess = over
			end
		end
		state.airTime, state.peakSink = 0.0, 0.0
	else
		state.airTime = state.airTime + dt
		state.peakSink = math_max(-state.vel.z, state.peakSink - 15.0 * dt)
	end

	return excess
end
