**Now:** T1 headless test harness built (tests/test_runner.tscn); fixed 3 zombie bugs + spawn fling
**Next:** user runs APK BENCHMARK on Pixel → read Download/zerohour_bench_*.csv → batch 2 textures (VRAM+mips)
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

## GPU audit 2026-10-21 (Sonnet, spot-checked by me: textures, effects, map_Kd all CONFIRMED)
Fix order (measure with T2 before AND after each):
1. HIGH textures: 363 TGA all compress/mode=0 + mipmaps off (uncompressed in VRAM). Map uses only 45 unique
   map_Kd (mp_rust.mtl). → VRAM Compressed + mipmaps; prune ~318 unused TGAs (496MB folder; shrinks APK too).
2. HIGH main.tscn effects: ssao :34, ssil :38, glow :41, auto_exposure :58 all on — full-screen passes, worst on Mali.
3. HIGH resolution: 1920x1080, no scaling_3d, msaa_3d=1 (project.godot:74). → scale ~0.67, MSAA off/FXAA.
4. MED sun shadow: shadow on, max_distance 150 (main.tscn:72,75) → ~50.
5. MED props: rust_props.gd new mesh+material per instance, ~170 rock spheres, _tex() :10 no cache, 0 MultiMesh.
   Camera far=500 (player.tscn:37), no visibility_range anywhere. Map = 1 MeshInstance (68 surfaces, no culling).

## T2 benchmark + GPU batch 1 (2026-10-21, f609cfe)
- Menu BENCHMARK button (or `godot4 --path . -- --bench`, auto-quits). Runs "old" (pre-pass settings) then
  "new" (scene defaults), 3s warmup + 30s 2-turn spin each. CSV → Download/zerohour_bench_<profile>_*.csv.
- Headless proves the path only (dummy renderer = 145fps, 0 draws). Real numbers need the phone.
- Godot warns SSAO + SSIL only work on Forward+ → they never ran on Mobile; audit overstated them.
- Batch 1 defaults: glow/auto-exposure off, shadow 50m, far 250, MSAA off, scale 0.75.
