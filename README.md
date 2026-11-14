# shattered_flight

Realistic flight controls for all helicopters and planes in FiveM. Made by [Shattered](https://www.shattered.se/).
Made to feel like Wardogs/Battlefield flight controls.

## Features

- Helicopter physics with collective, cyclic and pedals, rotor RPM, power limits, ground effect, vortex ring state and autorotation
- Plane physics with lift, stall, drag, thrust and G-limits
- Mouse, keyboard and gamepad support
- Hold-to-free-look camera (default `Left Alt`)
- Cycle camera distance like GTA's own camera (default `V`)
- Per-aircraft tuning profiles

## Installation

1. Download the resource and put the `shattered_flight` folder in your server's `resources` folder.
2. Add this line to your `server.cfg`:
   ```
   ensure shattered_flight
   ```
3. Restart your server.

No dependencies needed.

## Configuration

Everything you need is in `config.lua`:

| Option | What it does |
| --- | --- |
| `Debug` | Prints debug info to the F8 console |
| `FreeLookKey` | Key to hold for free-look camera |
| `CameraKey` | Key to cycle camera distance (near, mid, far, first person) |
| `Controls` | Mouse sensitivity, invert Y, and whether mouse X controls roll or yaw |
| `Assist` | Turn the flight assists on or off |
| `Blacklist` | Vehicle models that keep GTA's default handling |
| `EnablePlanes` | Use the custom physics for planes too |
| `AnimateSurfaces` | Move the plane's control surfaces with your input |
| `Planes` / `Profiles` | Tuning per plane / helicopter model |

Players can rebind the free-look and camera keys in **Settings → Key Bindings → FiveM**.

## Support

Need help? Join our [Discord](https://discord.gg/KfXAmc3qmh).
