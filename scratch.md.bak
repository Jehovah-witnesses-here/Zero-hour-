**Now:** T1 headless test harness built (tests/test_runner.tscn); fixed 3 zombie bugs + spawn fling
**Next:** T2 in-APK benchmark (frame times on Pixel 7 GPU), then GPU 1a measure, then ADS 2a
**Done:** Features 1-3, landscape UI, shoot-button bug, normal maps MTL, truck/heli/barrels; 2026-10-21 T1 tests

## How to test (phone only — never the PC without asking)
- Logic tests: `godot4 --headless --path . res://tests/test_runner.tscn` (exit 1 = fail).
  One test: `ZH_TEST=test_name godot4 ...`. "Parameter m is null" errors = headless dummy renderer noise.
- APK is built on this phone (Godot 4.2 + export templates in Termux). GitHub Actions only built
  v0.3/v0.4 (Dec 2025); map assets (556MB ripped MW2) are not in git so GitHub can't build Rust map.

## Layer plan (agreed 2026-10-21)
- T1 logic tests (done) · T2 in-APK benchmark run → frame-time CSV, read via adb
- 1 Engine/GPU: 1a measure · 1b draw distance/fog culling · 1c LOD + prop batching · 1d shadows/shaders · 1e res scale
- 2 Mechanics: 2a ADS · 2b recoil/spread/reload feel · 2c zombie pathing (nav mesh)
- 3 Survival loop: 3a points · 3b wall-buys · 3c doors · 3d round scaling (zombie HP/speed) · 3e game over/restart
- 4 Real-town (OSM) map port — later

## Found 2026-10-21
- Waves are DISABLED: game_manager.gd `_start_demo_mode` has `pass # _spawn_zombie_wave(5)` — no zombies in play.
- Fixed: zombie.take_damage awaited hit flash before death → kills never reported, died emitted twice
  (double points), colour stuck red on fast hits.
- Fixed: zombies add_child'ed at origin then moved → physics treats as moving platform, flings player.
- Wave spawn points hardcoded ±28-32m around origin; zombie HP never scales per round.
- Zombies walk straight at player (no navigation) — will snag on Rust map walls.
