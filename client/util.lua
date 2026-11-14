Util = {}

local math_exp, math_min, math_max, math_sqrt, math_asin, math_atan = math.exp, math.min, math.max, math.sqrt, math.asin, math.atan

Clamp = function(value, min, max)
	return math_min(max, math_max(min, value))
end

Approach = function(current, target, rate, dt)
	return current + (target - current) * (1.0 - math_exp(-rate * dt))
end

Smoothstep = function(edge0, edge1, x)
	local t = Clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)

	return t * t * (3.0 - 2.0 * t)
end

Dot = function(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end

ToLocal = function(vec, right, forward, up)
	return vector3(Dot(vec, right), Dot(vec, forward), Dot(vec, up))
end

ToWorld = function(vec, right, forward, up)
	return right * vec.x + forward * vec.y + up * vec.z
end

Attitude = function(right, forward, up)
	local pitch = math_asin(Clamp(forward.z, -1.0, 1.0))
	local roll = math_atan(-right.z, up.z)

	return pitch, roll
end

Log = function(text, ...)
	if (Config.Debug) then
		print(("^3[SHATTERED_HELI] %s^0"):format(text):format(...))
	end
end

Merge = function(base, override)
	local merged = {}

	for key, value in pairs(base) do
		local custom = override[key]

		if (type(value) == 'table' and type(custom) == 'table') then
			merged[key] = Merge(value, custom)
		elseif (custom ~= nil) then
			merged[key] = custom
		else
			merged[key] = value
		end
	end

	return merged
end

local profiles = {}

for name, profile in pairs(Config.Profiles) do
	if (name ~= 'default') then
		profiles[joaat(name)] = Merge(Config.Profiles.default, profile)
	end
end

local blacklist = {}

for _, name in ipairs(Config.Blacklist) do
	blacklist[joaat(name)] = true
end

GetProfile = function(model)
	return profiles[model] or Config.Profiles.default
end

local Scale = function(ratio, exponent)
	local cfg = Config.Weight

	return Clamp(ratio ^ -exponent, cfg.Min, cfg.Max)
end

BuildTune = function(vehicle, profile)
	local cfg = Config.Weight
	local mass = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fMass')
	local inertia = GetVehicleHandlingVector(vehicle, 'CHandlingData', 'vecInertiaMultiplier')

	if (not cfg.Enabled or not mass or mass <= 0.0) then
		mass = cfg.Reference
	end

	if (not cfg.Enabled or not inertia or inertia.x <= 0.0 or inertia.y <= 0.0 or inertia.z <= 0.0) then
		inertia = vector3(1.0, 1.0, 1.0)
	end

	local ratio = mass / cfg.Reference
	local rate, response = Scale(ratio, cfg.RateExponent), Scale(ratio, cfg.ResponseExponent)

	return {
		mass = mass,
		inertia = inertia,
		weight = rate,
		pitchRate = profile.pitchRate * rate / inertia.x ^ cfg.InertiaRate,
		rollRate = profile.rollRate * rate / inertia.y ^ cfg.InertiaRate,
		yawRate = profile.yawRate * rate / inertia.z ^ cfg.InertiaRate,
		response = vector3(
			profile.response * response / inertia.x ^ cfg.InertiaResponse,
			profile.response * response / inertia.y ^ cfg.InertiaResponse,
			profile.response * response / inertia.z ^ cfg.InertiaResponse
		),
		collectiveResponse = profile.collectiveResponse * Scale(ratio, cfg.CollectiveExponent),
		collectiveGain = profile.collectiveGain * Scale(ratio, cfg.GainExponent),
	}
end

GetKind = function(vehicle)
	local model = GetEntityModel(vehicle)

	if (blacklist[model]) then
		return nil
	end

	if (IsThisModelAHeli(model)) then
		return 'heli'
	end

	if (Config.Plane.Enabled and IsThisModelAPlane(model)) then
		return 'plane'
	end

	return nil
end
