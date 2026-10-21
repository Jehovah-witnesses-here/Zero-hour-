extends Node
## Benchmark run: loads the normal map, spins the camera for a fixed time and records
## every frame. Runs once per profile so one APK gives before/after numbers.
## Results go to Download/zerohour_bench_<profile>_<time>.csv (readable from Termux)
## with user:// as fallback, plus an on-screen summary and "[BENCH]" log lines.
## Start from the main menu BENCHMARK button, or run with `-- --bench`.

const WARMUP_SEC := 3.0
const RUN_SEC := 30.0
const TURNS := 2.0  # full camera turns per run

## "old" = settings before the 2026-10-21 GPU pass, "new" = current scene defaults.
const PROFILES := {
	"old": {"ssao": true, "ssil": true, "glow": true, "auto_exposure": true,
		"shadow_dist": 150.0, "scale": 1.0, "msaa": Viewport.MSAA_2X, "far": 500.0},
	"new": {},
}
const PROFILE_ORDER := ["old", "new"]

var active: bool = false
var _phase: String = ""  # "", "warmup", "run", "done"
var _t: float = 0.0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _draw_calls: PackedInt32Array = PackedInt32Array()
var _player: Node = null
var _start_yaw: float = 0.0
var _profile_idx: int = 0
var _defaults: Dictionary = {}
var _results: Array[Dictionary] = []


func _ready() -> void:
	if "--bench" in OS.get_cmdline_user_args():
		start.call_deferred()


func start() -> void:
	active = true
	_phase = ""
	_profile_idx = 0
	_results.clear()
	if not GameManager.game_started.is_connected(_on_game_started):
		GameManager.game_started.connect(_on_game_started)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_game_started() -> void:
	if not active:
		return
	_player = get_tree().get_first_node_in_group("player")
	_start_yaw = _player.camera_rotation_y if _player else 0.0
	_defaults = _read_settings()
	_begin_profile()


func _begin_profile() -> void:
	var prof: Dictionary = _defaults.duplicate()
	prof.merge(PROFILES[PROFILE_ORDER[_profile_idx]], true)
	_apply_settings(prof)
	_frames.clear()
	_draw_calls.clear()
	_phase = "warmup"
	_t = 0.0


func _process(delta: float) -> void:
	if _phase == "" or _phase == "done":
		return
	_t += delta
	if _player and is_instance_valid(_player):
		var progress: float = clamp(_t / (WARMUP_SEC + RUN_SEC), 0.0, 1.0)
		_player.camera_rotation_y = _start_yaw + progress * TURNS * TAU
		_player.rotation.y = _player.camera_rotation_y
	if _phase == "warmup":
		if _t >= WARMUP_SEC:
			_phase = "run"
		return
	_frames.append(delta * 1000.0)
	_draw_calls.append(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if _t >= WARMUP_SEC + RUN_SEC:
		_finish_profile()


func _finish_profile() -> void:
	var summary := summarize(_frames, _draw_calls)
	summary["profile"] = PROFILE_ORDER[_profile_idx]
	summary["vram_mb"] = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	summary["device"] = OS.get_model_name()
	var path := _write_csv(summary)
	print("[BENCH] profile=%s avg_fps=%.1f p50_ms=%.1f p95_ms=%.1f p99_ms=%.1f low1_fps=%.1f draws=%d vram_mb=%.0f frames=%d file=%s" % [
		summary.profile, summary.avg_fps, summary.p50_ms, summary.p95_ms, summary.p99_ms,
		summary.low1_fps, summary.avg_draws, summary.vram_mb, summary.frames, path])
	_results.append(summary)
	_profile_idx += 1
	if _profile_idx < PROFILE_ORDER.size():
		_begin_profile()
		return
	_phase = "done"
	active = false
	_apply_settings(_defaults)
	var text := ""
	for r in _results:
		text += "%s: %.1f fps avg, %.1f fps 1%%-low, p95 %.1f ms, %d draws, %.0f MB VRAM\n" % [
			r.profile, r.avg_fps, r.low1_fps, r.p95_ms, r.avg_draws, r.vram_mb]
	_show_overlay(text + "Saved to Download/")


func _env_node() -> WorldEnvironment:
	return get_tree().current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment


func _sun() -> DirectionalLight3D:
	return get_tree().current_scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D


func _read_settings() -> Dictionary:
	var we := _env_node()
	var env: Environment = we.environment if we else null
	var attrs = we.camera_attributes if we else null
	var sun := _sun()
	var cam: Camera3D = _player.camera if _player else null
	return {
		"ssao": env.ssao_enabled if env else false,
		"ssil": env.ssil_enabled if env else false,
		"glow": env.glow_enabled if env else false,
		"auto_exposure": attrs.auto_exposure_enabled if attrs else false,
		"shadow_dist": sun.directional_shadow_max_distance if sun else 0.0,
		"scale": get_viewport().scaling_3d_scale,
		"msaa": get_viewport().msaa_3d,
		"far": cam.far if cam else 0.0,
	}


func _apply_settings(s: Dictionary) -> void:
	var we := _env_node()
	if we and we.environment:
		we.environment.ssao_enabled = s.ssao
		we.environment.ssil_enabled = s.ssil
		we.environment.glow_enabled = s.glow
	if we and we.camera_attributes:
		we.camera_attributes.auto_exposure_enabled = s.auto_exposure
	var sun := _sun()
	if sun:
		sun.directional_shadow_max_distance = s.shadow_dist
	get_viewport().scaling_3d_scale = s.scale
	get_viewport().msaa_3d = s.msaa
	if _player and _player.camera:
		_player.camera.far = s.far


## Pure maths so the headless tests can check it.
static func summarize(frames: PackedFloat32Array, draws: PackedInt32Array) -> Dictionary:
	var sorted := Array(frames)
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		return {"frames": 0, "avg_fps": 0.0, "p50_ms": 0.0, "p95_ms": 0.0, "p99_ms": 0.0,
			"low1_fps": 0.0, "avg_draws": 0}
	var total := 0.0
	for f in sorted:
		total += f
	# 1% low = average fps over the slowest 1% of frames
	var worst := maxi(1, n / 100)
	var worst_total := 0.0
	for i in range(n - worst, n):
		worst_total += sorted[i]
	var draw_total := 0
	for d in draws:
		draw_total += d
	return {
		"frames": n,
		"avg_fps": 1000.0 * n / total,
		"p50_ms": sorted[int(n * 0.50)],
		"p95_ms": sorted[mini(n - 1, int(n * 0.95))],
		"p99_ms": sorted[mini(n - 1, int(n * 0.99))],
		"low1_fps": 1000.0 * worst / worst_total,
		"avg_draws": draw_total / maxi(1, draws.size()),
	}


func _write_csv(summary: Dictionary) -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file_name := "zerohour_bench_%s_%s.csv" % [summary.profile, stamp]
	for dir in [OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "user://"]:
		if dir == "":
			continue
		var path: String = dir.path_join(file_name)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			continue
		f.store_line("# " + JSON.stringify(summary))
		f.store_line("frame,ms,draw_calls")
		for i in _frames.size():
			f.store_line("%d,%.3f,%d" % [i, _frames[i], _draw_calls[i]])
		f.close()
		return ProjectSettings.globalize_path(path)
	return "(not saved)"


func _show_overlay(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var label := Label.new()
	label.text = "BENCHMARK DONE\n" + text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.position = Vector2(40, 40)
	layer.add_child(label)
	get_tree().root.add_child(layer)
