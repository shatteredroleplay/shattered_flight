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
	return Clamp(ratio ^ -exponent, 0.4, 1.4)
end

BuildTune = function(vehicle, profile)
	local mass = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fMass')
	local inertia = GetVehicleHandlingVector(vehicle, 'CHandlingData', 'vecInertiaMultiplier')

	if (not mass or mass <= 0.0) then
		mass = 4000.0
	end

	if (not inertia or inertia.x <= 0.0 or inertia.y <= 0.0 or inertia.z <= 0.0) then
		inertia = vector3(1.0, 1.0, 1.0)
	end

	local ratio = mass / 4000.0
	local rate, response = Scale(ratio, 0.6), Scale(ratio, 0.5)

	return {
		mass = mass,
		inertia = inertia,
		weight = rate,
		pitchRate = profile.pitchRate * rate / inertia.x ^ 0.3,
		rollRate = profile.rollRate * rate / inertia.y ^ 0.3,
		yawRate = profile.yawRate * rate / inertia.z ^ 0.3,
		response = vector3(
			profile.response * response / inertia.x ^ 0.5,
			profile.response * response / inertia.y ^ 0.5,
			profile.response * response / inertia.z ^ 0.5
		),
		collectiveResponse = profile.collectiveResponse * Scale(ratio, 0.4),
		collectiveGain = profile.collectiveGain * Scale(ratio, 0.15),
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

	if (Config.EnablePlanes and IsThisModelAPlane(model)) then
		return 'plane'
	end

	return nil
end
