local CONTROLS <const> = { 87, 88, 89, 90, 106, 107, 108, 109, 110, 111, 112, 122 }
local LOOK_LR <const>, LOOK_UD <const> = 1, 2
local LOOK_BEHIND <const> = 79
local THROTTLE_UP <const>, THROTTLE_DOWN <const> = 87, 88
local YAW_LEFT <const>, YAW_RIGHT <const> = 89, 90
local ROLL_LR <const>, PITCH_UD <const> = 107, 110
local MOUSE_OVERRIDE <const>, FLY_MOUSE_OVERRIDE <const> = 106, 122

local math_abs, math_max = math.abs, math.max

local smooth = { pitch = 0.0, roll = 0.0, yaw = 0.0, keys = 0.0 }
local lastCyclic = 0
local result = {}

InputReset = function()
	smooth.pitch, smooth.roll, smooth.yaw, smooth.keys = 0.0, 0.0, 0.0, 0.0
end

DisableControls = function(allowLook, keep)
	for i = (keep or 0) + 1, #CONTROLS do
		DisableControlAction(0, CONTROLS[i], true)
	end

	DisableControlAction(0, LOOK_BEHIND, true)

	if (not allowLook) then
		DisableControlAction(0, LOOK_LR, true)
		DisableControlAction(0, LOOK_UD, true)
	end
end

DisablePlaneControls = function(allowLook)
	DisableControlAction(0, MOUSE_OVERRIDE, true)
	DisableControlAction(0, FLY_MOUSE_OVERRIDE, true)
	DisableControlAction(0, LOOK_BEHIND, true)

	if (not allowLook) then
		DisableControlAction(0, LOOK_LR, true)
		DisableControlAction(0, LOOK_UD, true)
	end
end

FeedSurfaces = function(input)
	if (not IsUsingKeyboard(0)) then return end

	SetControlNormal(0, ROLL_LR, input.roll)
	SetControlNormal(0, PITCH_UD, -input.pitch)
end

Deadzone = function(value)
	local dz = Config.Input.GamepadDeadzone
	if (math_abs(value) < dz) then
		return 0.0
	end

	return (value - (value > 0 and dz or -dz)) / (1.0 - dz)
end

Expo = function(value)
	local curved = math_abs(value) ^ Config.Input.Expo

	return value < 0.0 and -curved or curved
end

Isolate = function(x, y)
	local isolation = Config.Controls.isolation
	local ax, ay = math_abs(x), math_abs(y)
	if (isolation <= 0.0 or ax == ay) then
		return x, y
	end

	if (ax > ay) then
		return x, y * (1.0 - isolation * (1.0 - ay / ax))
	end

	return x * (1.0 - isolation * (1.0 - ax / ay)), y
end

ReadMouse = function(dt, cfg, invert)
	local mx, my = GetDisabledControlNormal(0, LOOK_LR), GetDisabledControlNormal(0, LOOK_UD)
	mx, my = Isolate(mx, my)

	local scale = cfg.MouseRate * Config.Controls.sensitivity / math_max(dt, 0.001)
	local horizontal = Clamp(mx * scale, -1.0, 1.0)
	local pitch = Clamp(-my * scale * invert * Config.Controls.pitchSens, -1.0, 1.0)

	if (Config.Controls.mouseX == 'yaw') then
		return pitch, 0.0, Clamp(horizontal * Config.Controls.yawSens, -1.0, 1.0), mx ~= 0.0 or my ~= 0.0
	end

	return pitch, Clamp(horizontal * Config.Controls.rollSens, -1.0, 1.0), 0.0, mx ~= 0.0 or my ~= 0.0
end

Read = function(dt, mouseToCamera, hold)
	local cfg = Config.Input
	local keyboard = IsUsingKeyboard(0)
	local now = GetGameTimer()
	local invert = Config.Controls.invertY and -1.0 or 1.0
	local keys = GetDisabledControlNormal(0, YAW_RIGHT) - GetDisabledControlNormal(0, YAW_LEFT)

	local pitch, roll, yaw = 0.0, 0.0, 0.0

	if (keyboard) then
		smooth.keys = Approach(smooth.keys, keys, cfg.KeySmoothing, dt)

		if (not mouseToCamera) then
			local moved
			pitch, roll, yaw, moved = ReadMouse(dt, cfg, invert)
			if (moved and (pitch ~= 0.0 or roll ~= 0.0)) then
				lastCyclic = now
			end
		end

		if (Config.Controls.mouseX == 'yaw') then
			roll = smooth.keys * Config.Controls.rollSens
			if (keys ~= 0.0) then
				lastCyclic = now
			end
		else
			yaw = smooth.keys
		end

		smooth.pitch = Approach(smooth.pitch, pitch, cfg.MouseSmoothing, dt)
		smooth.roll = Approach(smooth.roll, roll, cfg.MouseSmoothing, dt)
		smooth.yaw = Approach(smooth.yaw, yaw, cfg.MouseSmoothing, dt)
	else
		pitch = Expo(Deadzone(-GetDisabledControlNormal(0, PITCH_UD))) * invert * Config.Controls.pitchSens
		roll = Expo(Deadzone(GetDisabledControlNormal(0, ROLL_LR))) * Config.Controls.rollSens
		smooth.keys = Approach(smooth.keys, keys, cfg.KeySmoothing, dt)

		if (pitch ~= 0.0 or roll ~= 0.0) then
			lastCyclic = now
		end

		smooth.pitch, smooth.roll, smooth.yaw = Clamp(pitch, -1.0, 1.0), Clamp(roll, -1.0, 1.0), smooth.keys
	end

	result.pitch, result.roll, result.yaw = smooth.pitch, smooth.roll, smooth.yaw
	result.collective = GetDisabledControlNormal(0, THROTTLE_UP) - GetDisabledControlNormal(0, THROTTLE_DOWN)
	result.hold = hold and keyboard
	result.cyclicIdle = now - lastCyclic > 150 and math_abs(smooth.pitch) + math_abs(smooth.roll) < Config.Assists.StabilityDeadzone

	return result
end
