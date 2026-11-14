local math_rad, math_sqrt, math_acos, math_min, math_max = math.rad, math.sqrt, math.acos, math.min, math.max

local blend = 0.0

Reset = function()
	blend = 0.0
end

local Limit = function(rate, angle, max, gain)
	if (angle > max) then
		return math.min(rate, (max - angle) * gain)
	elseif (angle < -max) then
		return math.max(rate, (-max - angle) * gain)
	end

	return rate
end

Angular = function(target, ctx)
	local cfg, preset = Config.Assists, ctx.preset

	if (not ctx.input.hold) then
		local idle = ctx.input.cyclicIdle
		blend = Approach(blend, idle and 1.0 or 0.0, idle and cfg.StabilityFadeIn or cfg.StabilityFadeOut, ctx.dt)
	end

	local level = ctx.level

	if (preset.stability and blend > 0.0) then
		local axisX, axisY = -level.y, level.x
		local length = math_sqrt(axisX * axisX + axisY * axisY)

		if (length < 0.001 and level.z < 0.0) then
			axisX, axisY, length = 0.0, 1.0, 1.0
		end

		if (length >= 0.001) then
			local rate = math_min(math_acos(Clamp(level.z, -1.0, 1.0)) * cfg.Stability, cfg.StabilityMaxRate) * blend
			target.x = target.x + axisX / length * rate
			target.y = target.y + axisY / length * rate
		end
	end

	if (preset.turnCoordination) then
		local factor = Smoothstep(2.0, cfg.TurnCoordinationSpeed, ctx.speed) * math_max(0.0, level.z)
		target.z = target.z + level.x * cfg.TurnCoordination * factor
	end

	if (preset.envelope) then
		target.x = Limit(target.x, ctx.pitch, math_rad(ctx.profile.maxPitch), cfg.Envelope)
		target.y = Limit(target.y, ctx.roll, math_rad(ctx.profile.maxRoll), cfg.Envelope)
	end

	return target
end

Linear = function(accel, vel, ctx)
	local cfg, preset, input = Config.Assists, ctx.preset, ctx.input

	if (not preset.autoHover or input.collective ~= 0.0 or blend <= 0.0) then
		return accel
	end

	local horizontal = math_sqrt(vel.x * vel.x + vel.y * vel.y)
	if (horizontal > cfg.HoverSpeed) then
		return accel
	end

	local fade = (1.0 - horizontal / cfg.HoverSpeed) * blend

	return accel - vector3(vel.x * cfg.HoverDamping * fade, vel.y * cfg.HoverDamping * fade, vel.z * cfg.HoverVertical * blend)
end
