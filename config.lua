Config = {}

Config.Debug = false

Config.FreeLookKey = 'LMENU'

Config.Controls = {
	sensitivity = 0.5,
	pitchSens = 1.0,
	rollSens = 1.0,
	yawSens = 1.0,
	mouseX = 'roll',
	isolation = 0.4,
	invertY = false,
}

Config.Assist = { stability = false, envelope = false, turnCoordination = false, autoHover = false }

Config.Blacklist = {
	'skylift',
	'blimp',
	'blimp2',
	'blimp3',
}

Config.Gravity = 9.81
Config.ResyncVelocity = 10.0
Config.ControlRequestInterval = 250
Config.LiftoffCollective = 0.05

Config.Input = {
	MouseRate = 0.5,
	MouseSmoothing = 16.0,
	KeySmoothing = 4.0,
	Expo = 1.5,
	GamepadDeadzone = 0.12,
}

Config.Assists = {
	Stability = 1.2,
	StabilityMaxRate = 1.5,
	StabilityDeadzone = 0.15,
	StabilityFadeIn = 1.5,
	StabilityFadeOut = 10.0,
	Envelope = 4.0,
	TurnCoordination = 0.8,
	TurnCoordinationSpeed = 20.0,
	HoverDamping = 1.4,
	HoverVertical = 1.5,
	HoverSpeed = 10.0,
}

Config.Weight = {
	Enabled = true,
	Reference = 4000.0,
	RateExponent = 0.6,
	ResponseExponent = 0.5,
	CollectiveExponent = 0.4,
	GainExponent = 0.15,
	InertiaRate = 0.3,
	InertiaResponse = 0.5,
	Min = 0.4,
	Max = 1.4,
}

Config.Power = {
	MinPower = 0.55,
	MinRpm = 0.75,
}

Config.Damage = {
	MinLift = 0.45,
	TailSpin = 2.2,
	TailRotorDead = 50.0,
	Overspeed = 6.0,
}

Config.Landing = {
	SafeSink = 3.5,
	MinAirTime = 0.75,
	MaxHeight = 4.0,
	SinkDecay = 15.0,
	Damage = 40.0,
	TiltFactor = 1.5,
	EngineFloor = 50.0,
	BodyScale = 1.0,
	RotorScale = 0.6,
	TailScale = 0.4,
}

Config.Autorotation = {
	Enabled = true,
	Decay = 0.12,
	Gain = 0.035,
	CollectiveDrain = 0.25,
	MinRpm = 0.25,
	LiftScale = 0.75,
}

Config.Feel = {
	Enabled = true,
	Shake = 'SKY_DIVING_SHAKE',
	ShakeThreshold = 0.03,
	MaxShake = 1.5,
	Vrs = 1.5,
	Overspeed = 1.0,
	Droop = 0.4,
	Landing = 0.15,
}

Config.Plane = {
	Enabled = true,
	AnimateSurfaces = true,
	TakeoverHeight = 1.5,
	RotateStart = 0.4,
	RotateFull = 0.8,
	GroundPitch = 0.5,
	LandingHeight = 8.0,
	VtolNozzle = 0.5,
	MinPower = 0.5,
	Overspeed = 4.0,
	BodyFloor = 100.0,
	StallShake = 1.2,
	OverspeedShake = 1.0,
}

local Jet = {
	pitchRate = 125.0,
	rollRate = 220.0,
	response = { pitch = 7.0, roll = 7.0, yaw = 4.0 },
	stallSpeed = 28.0,
	cornerSpeed = 88.0,
	trimSpeed = 95.0,
	topSpeed = 125.0,
	vne = 160.0,
	highSpeedAuthority = 0.8,
	maxG = 10.0,
	thrust = 13.0,
	cruiseThrottle = 0.5,
}

Config.Planes = {
	default = {
		pitchRate = 110.0,
		rollRate = 180.0,
		yawRate = 30.0,
		response = { pitch = 6.0, roll = 6.0, yaw = 4.0 },
		maxPitch = 60.0,
		maxRoll = 75.0,
		stallSpeed = 26.0,
		cornerSpeed = 78.0,
		trimSpeed = 75.0,
		topSpeed = 95.0,
		vne = 125.0,
		highSpeedAuthority = 0.75,
		stallAngle = 16.0,
		stallLift = 0.55,
		stallDrag = 0.015,
		stallBuffet = 1.0,
		stallRollLoss = 0.6,
		maxG = 9.0,
		thrust = 9.0,
		thrustFade = 0.3,
		cruiseThrottle = 0.6,
		throttleResponse = 1.5,
		airbrake = 1.5,
		gearDrag = 0.5,
		inducedDrag = 0.09,
		sideForce = 0.02,
		pitchStability = 3.5,
		yawStability = 3.0,
	},

	lazer = Jet,
	hydra = Jet,
	besra = Jet,
	strikeforce = Jet,
	raiju = Jet,
}

Config.Profiles = {
	default = {
		pitchRate = 100.0,
		rollRate = 120.0,
		yawRate = 70.0,
		response = 3.5,
		maxPitch = 55.0,
		maxRoll = 65.0,
		hoverLift = 0.97,
		collectiveGain = 0.85,
		collectiveResponse = 3.0,
		power = 1.55,
		droop = 0.25,
		rpmResponse = 2.0,
		drag = { forward = 0.0015, side = 0.015, vertical = 0.03 },
		linearDrag = 0.015,
		inducedDrag = 0.35,
		speed = 1.8,
		speedBlend = { start = 10.0, full = 40.0 },
		vne = 100.0,
		blowback = 4.0,
		etl = { bonus = 0.1, start = 8.0, full = 22.0 },
		inflow = { gain = 0.018, max = 0.3 },
		groundEffect = { bonus = 0.07, height = 7.0, speed = 12.0 },
		vrs = { sinkStart = 5.0, sinkFull = 9.0, speed = 10.0, loss = 0.4, buffet = 1.2, response = 2.0 },
		tiltCompensation = 0.1,
		authority = { start = 15.0, full = 55.0 },
		cyclicAtSpeed = 0.8,
		yawAtSpeed = 0.35,
		torqueYaw = 10.0,
		weathervane = 0.9,
		weathervaneSpeed = 15.0,
		weathervaneGrowth = 1.0,
		spoolTime = 6.0,
	},

	havok = { power = 1.6, vne = 85.0, drag = { forward = 0.002, side = 0.02, vertical = 0.035 } },
	buzzard = { power = 1.65, vne = 100.0, yawAtSpeed = 0.45 },
	buzzard2 = { power = 1.65, vne = 100.0, yawAtSpeed = 0.45 },
	valkyrie = { maxPitch = 45.0, maxRoll = 55.0, power = 1.5 },
	savage = { maxPitch = 45.0, maxRoll = 55.0, power = 1.6, vne = 105.0 },
	hunter = { maxPitch = 45.0, maxRoll = 55.0, power = 1.6, vne = 105.0 },
	akula = { maxPitch = 45.0, maxRoll = 55.0, power = 1.6, vne = 105.0 },
	annihilator = { maxPitch = 45.0, maxRoll = 55.0, power = 1.5 },
	annihilator2 = { maxPitch = 45.0, maxRoll = 55.0, power = 1.5 },
	cargobob = { maxPitch = 35.0, maxRoll = 40.0, spoolTime = 10.0, power = 1.35, vne = 85.0, torqueYaw = 0.0 },
	cargobob2 = { maxPitch = 35.0, maxRoll = 40.0, spoolTime = 10.0, power = 1.35, vne = 85.0, torqueYaw = 0.0 },
	cargobob3 = { maxPitch = 35.0, maxRoll = 40.0, spoolTime = 10.0, power = 1.35, vne = 85.0, torqueYaw = 0.0 },
	cargobob4 = { maxPitch = 35.0, maxRoll = 40.0, spoolTime = 10.0, power = 1.35, vne = 85.0, torqueYaw = 0.0 },
}
