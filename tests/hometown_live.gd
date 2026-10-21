extends Node
## Live check of the Hometown flow (real network): postcode lookup -> OSM download -> buildings.
## Run: godot4 --headless --path . res://tests/hometown_live.tscn  (exit 0 = buildings loaded)

const QUERY := "SW1A 1AA"
const LIMIT_SEC := 60.0


func _ready() -> void:
	GameManager.current_map_type = GameManager.MapType.REAL_WORLD
	GameManager.hometown_query = QUERY
	GameManager.buildings_ready.connect(func():
		printerr("[LIVE] PASS: real-world map loaded for ", QUERY)
		get_tree().quit(0))
	GameManager.loading_started.connect(func(msg): print("[LIVE] step: ", msg))
	# Fallback resets map type to DEMO, so REAL_WORLD here means the town really loaded
	GameManager.loading_complete.connect(func():
		var ok: bool = GameManager.current_map_type == GameManager.MapType.REAL_WORLD
		var town = get_tree().get_first_node_in_group("buildings")
		printerr("[LIVE] ", "PASS" if ok else "FAIL", ": loading_complete, map_type=",
			GameManager.current_map_type, " building_gen_children=",
			GameManager.building_generator.get_child_count() if GameManager.building_generator else -1)
		var f := FileAccess.open("user://live_result.txt", FileAccess.WRITE)
		f.store_line("PASS" if ok else "FAIL")
		f.close()
		get_tree().quit(0 if ok else 1))
	GameManager.loading_failed.connect(func(reason):
		printerr("[LIVE] FAIL: ", reason)
		get_tree().quit(1))
	get_tree().create_timer(LIMIT_SEC).timeout.connect(func():
		printerr("[LIVE] FAIL: no result in ", LIMIT_SEC, "s")
		get_tree().quit(1))
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
