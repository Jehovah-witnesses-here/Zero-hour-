extends Node3D
## Headless gameplay tests.
## Run: godot4 --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed, 1 = failures. Each test builds its own tiny world.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ZOMBIE_SCRIPT := preload("res://scripts/zombie.gd")
const BENCH_SCRIPT := preload("res://scripts/benchmark.gd")

var _passed: int = 0
var _failed: int = 0
var _current: String = ""
var _world: Node3D = null


func _ready() -> void:
	print("\n===== ZERO-HOUR TESTS =====")
	var tests: Array[String] = []
	var only := OS.get_environment("ZH_TEST")  # run one test: ZH_TEST=test_name
	for m in get_method_list():
		if m.name.begins_with("test_") and (only == "" or m.name == only):
			tests.append(m.name)
	tests.sort()
	for t in tests:
		_current = t
		_world = Node3D.new()
		add_child(_world)
		_make_floor()
		var before := _failed
		await call(t)
		print("%s %s" % ["PASS" if _failed == before else "FAIL", t])
		if _failed == before:
			_passed += 1
		_world.queue_free()
		await get_tree().process_frame
	print("===== %d passed, %d failed =====" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- helpers -----------------------------------------------------------------

func check(cond: bool, msg: String) -> void:
	if not cond:
		_failed += 1
		print("    x %s: %s" % [_current, msg])


func _make_floor() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	body.add_child(col)
	body.position.y = -0.5
	_world.add_child(body)


func _spawn_player(pos := Vector3.ZERO) -> CharacterBody3D:
	var p: CharacterBody3D = PLAYER_SCENE.instantiate()
	p.position = pos  # set before add_child so physics never sees it at the origin
	_world.add_child(p)
	return p


func _spawn_zombie(pos: Vector3) -> CharacterBody3D:
	var z := CharacterBody3D.new()
	z.set_script(ZOMBIE_SCRIPT)
	z.position = pos
	_world.add_child(z)
	return z


## Put a frozen zombie on the camera's aim line so `aim_height` (0.7 body, 1.62 head) is hit.
func _zombie_in_crosshair(p: CharacterBody3D, aim_height: float) -> CharacterBody3D:
	var cam: Transform3D = p.camera.global_transform
	var target: Vector3 = cam.origin - cam.basis.z * 6.0
	var z := _spawn_zombie(target - Vector3(0, aim_height, 0))
	z.set_physics_process(false)
	return z


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


# --- zombie ------------------------------------------------------------------

func test_zombie_body_shot_damage() -> void:
	var z := _spawn_zombie(Vector3(0, 0, -5))
	await _physics_frames(2)
	z.take_damage(25.0)
	check(is_equal_approx(z.health, 75.0), "health should be 75, got %s" % z.health)


func test_zombie_kill_is_immediate() -> void:
	# The shooter reads _is_dead right after take_damage() — death must not wait on the hit flash.
	var z := _spawn_zombie(Vector3(0, 0, -5))
	await _physics_frames(2)
	z.take_damage(100.0)
	check(z._is_dead, "zombie should be dead straight after lethal damage")


func test_zombie_died_emits_once() -> void:
	var z := _spawn_zombie(Vector3(0, 0, -5))
	await _physics_frames(2)
	var count := [0]
	z.died.connect(func(_p): count[0] += 1)
	z.take_damage(100.0)
	z.take_damage(100.0)
	await get_tree().create_timer(0.3).timeout
	check(count[0] == 1, "died should emit once, got %d" % count[0])


func test_zombie_flash_restores_colour() -> void:
	var z := _spawn_zombie(Vector3(0, 0, -5))
	await _physics_frames(2)
	var orig: Color = z._body_mat.albedo_color
	z.take_damage(10.0)
	await _physics_frames(1)
	z.take_damage(10.0)  # second hit mid-flash
	await get_tree().create_timer(0.4).timeout
	check(z._body_mat.albedo_color.is_equal_approx(orig), "colour stuck at %s" % z._body_mat.albedo_color)


func test_zombie_walks_to_player() -> void:
	var p := _spawn_player(Vector3(0, 1, 0))
	var z := _spawn_zombie(Vector3(0, 1, -10))
	await _physics_frames(5)
	var start := z.global_position.distance_to(p.global_position)
	await _physics_frames(60)
	var end := z.global_position.distance_to(p.global_position)
	check(end < start - 1.0, "zombie should close distance (%.2f -> %.2f)" % [start, end])


func test_zombie_attack_respects_cooldown() -> void:
	var p := _spawn_player(Vector3(0, 1, 0))
	_spawn_zombie(Vector3(0, 1, -1.2))
	await _physics_frames(30)  # 0.5 s: exactly one hit
	check(is_equal_approx(p.current_health, 90.0), "one hit expected, health %s" % p.current_health)


# --- player ------------------------------------------------------------------

func test_player_shot_hits_and_uses_ammo() -> void:
	var p := _spawn_player(Vector3(0, 1, 0))
	await _physics_frames(10)
	var z := _zombie_in_crosshair(p, 0.7)
	await _physics_frames(2)
	var hits := []
	p.shot_hit.connect(func(k): hits.append(k))
	p._shoot()
	check(p.ammo == 29, "ammo should be 29, got %d" % p.ammo)
	check(hits.size() == 1, "shot should hit zombie")
	check(z.health < z.max_health, "zombie should take damage")


func test_player_headshot_reports_kill() -> void:
	var p := _spawn_player(Vector3(0, 1, 0))
	await _physics_frames(10)
	_zombie_in_crosshair(p, 1.62)
	await _physics_frames(2)
	var hits := []
	p.shot_hit.connect(func(k): hits.append(k))
	p._shoot()
	check(hits == [true], "headshot should report a kill, got %s" % [hits])


func test_player_reload_refills() -> void:
	var p := _spawn_player(Vector3(0, 1, 0))
	await _physics_frames(2)
	p.ammo = 5
	p._start_reload()
	await get_tree().create_timer(p.RELOAD_TIME + 0.2).timeout
	check(p.ammo == p.MAG_SIZE, "mag should be full, got %d" % p.ammo)
	check(p.ammo_reserve == 90 - 25, "reserve should be 65, got %d" % p.ammo_reserve)


func test_player_dies_at_zero() -> void:
	var p := _spawn_player(Vector3(0, 1, 0))
	await _physics_frames(2)
	var died := [false]
	p.player_died.connect(func(): died[0] = true)
	p.take_damage(150.0)
	check(died[0] and p.current_health == 0.0, "player should die and clamp to 0")


# --- benchmark ---------------------------------------------------------------

func test_benchmark_summary_maths() -> void:
	# 99 frames at 10 ms + 1 frame at 100 ms
	var frames := PackedFloat32Array()
	for i in 99:
		frames.append(10.0)
	frames.append(100.0)
	var s: Dictionary = BENCH_SCRIPT.summarize(frames, PackedInt32Array([50, 150]))
	check(s.frames == 100, "frames %d" % s.frames)
	check(is_equal_approx(s.avg_fps, 1000.0 * 100 / 1090.0), "avg_fps %s" % s.avg_fps)
	check(is_equal_approx(s.p50_ms, 10.0), "p50 %s" % s.p50_ms)
	check(is_equal_approx(s.low1_fps, 10.0), "1%% low should be the 100 ms frame, got %s" % s.low1_fps)
	check(s.avg_draws == 100, "avg draws %d" % s.avg_draws)
	check(BENCH_SCRIPT.summarize(PackedFloat32Array(), PackedInt32Array()).frames == 0, "empty run")
