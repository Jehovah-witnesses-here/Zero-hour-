extends Node
## Game Manager - Core game state and coordination
## Handles initialization, mode selection, and game flow

signal game_started
signal game_paused
signal game_resumed
signal buildings_ready
signal loading_started(message: String)
signal loading_complete
signal loading_failed(message: String)
signal mode_changed(mode: int)
signal wave_started(wave_number: int, zombie_count: int)
signal wave_complete(wave_number: int)
signal score_changed(score: int)

# Game modes from design doc
enum GameMode { NONE, SURVIVAL, EXCLUSION_ZONE }
enum MapType { DEMO, CUSTOM, REAL_WORLD }
enum GameState { MENU, LOADING, PLAYING, PAUSED }

# Current state
var current_state: GameState = GameState.MENU
var current_mode: GameMode = GameMode.NONE
var current_map_type: MapType = MapType.DEMO

# References
var player: CharacterBody3D = null
var building_generator: Node3D = null
var osm_fetcher: Node = null
var street_props: Node3D = null
var rust_map: Node3D = null

# GPS Manager (autoload)
@onready var gps_manager = get_node_or_null("/root/GPSManager")

# Loading settings
var initialization_timeout: float = 10.0  # seconds before fallback
var is_loading: bool = false
var loading_message: String = ""

# Map settings
var render_distance: float = 200.0

var _zombie_count: int = 0
var _wave_number: int = 0
var _zombie_script: GDScript = null

var _has_started: bool = false
var score: int = 0


func _ready() -> void:
	print("[GameManager] Initialized")

	# Connect to scene tree changes
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	# Check if main scene was loaded
	if node.name == "Main" and not _has_started:
		# GameManager is an autoload: re-arm when this game scene closes so the next one starts
		node.tree_exited.connect(func(): _has_started = false, CONNECT_ONE_SHOT)
		_try_start_game()


func _try_start_game() -> void:
	if _has_started:
		return

	# Wait for scene setup
	await get_tree().process_frame
	await get_tree().process_frame

	_find_references()

	if player and building_generator:
		_has_started = true
		print("[GameManager] Starting game...")
		# The lobby only sets current_map_type; starting the right mode happens here,
		# because the lobby node is freed by the scene change before it could.
		if current_map_type == MapType.REAL_WORLD:
			start_real_world_mode()
		else:
			_start_demo_mode()


func _find_references() -> void:
	player = get_tree().get_first_node_in_group("player")
	building_generator = get_tree().get_first_node_in_group("building_generator")
	street_props = get_tree().get_first_node_in_group("street_props")
	rust_map = get_tree().get_first_node_in_group("rust_map")

	var main = get_tree().current_scene
	if main:
		osm_fetcher = main.get_node_or_null("OSMFetcher")


## Start demo mode with a pre-built test map (no GPS needed)
func _start_demo_mode() -> void:
	print("[GameManager] Starting DEMO mode - Rust Map...")
	loading_started.emit("Loading Rust map...")

	current_map_type = MapType.DEMO
	current_mode = GameMode.SURVIVAL
	current_state = GameState.LOADING
	is_loading = true

	await get_tree().create_timer(0.5).timeout

	# Generate Rust-style map (MW2 oil yard)
	if rust_map:
		rust_map.generate_map()
	elif building_generator:
		# Fallback to old demo if rust_map not found
		var demo_buildings = _create_demo_buildings()
		await building_generator.generate_buildings(demo_buildings)
		building_generator.create_ground(500.0)
		if street_props:
			street_props.generate_demo_props()

	# Position player at map spawn point
	if player:
		var rust_map = get_tree().get_first_node_in_group("rust_map")
		if rust_map and rust_map.has_method("get_player_spawn"):
			player.global_position = rust_map.get_player_spawn()
		else:
			player.global_position = Vector3(0, 3, 0)

	# Done loading
	is_loading = false
	current_state = GameState.PLAYING
	loading_complete.emit()
	buildings_ready.emit()
	game_started.emit()

	print("[GameManager] Demo mode ready! Walk around with the joystick.")

	# Zombie waves disabled for map testing
	pass # _spawn_zombie_wave(5)


## Create demo buildings for testing (no GPS/OSM needed)
func _create_demo_buildings() -> Array:
	var buildings = []

	# Create a small town layout for testing
	# Each building is a simple rectangle with lat/lon style coordinates
	# Using meters directly since we're in demo mode

	var building_layouts = [
		# Main street buildings (left side)
		{"x": -20, "z": -30, "w": 15, "d": 10, "h": 9, "name": "The Grocery Store"},
		{"x": -20, "z": -15, "w": 12, "d": 12, "h": 6, "name": "The Bakery"},
		{"x": -20, "z": 5, "w": 18, "d": 12, "h": 12, "name": "Apartments"},
		{"x": -20, "z": 25, "w": 14, "d": 10, "h": 6, "name": "The Hardware Store"},

		# Main street buildings (right side)
		{"x": 20, "z": -30, "w": 16, "d": 12, "h": 9, "name": "Police Station"},
		{"x": 20, "z": -10, "w": 10, "d": 10, "h": 6, "name": "The Pharmacy"},
		{"x": 20, "z": 10, "w": 20, "d": 15, "h": 15, "name": "Office Building"},
		{"x": 20, "z": 35, "w": 12, "d": 10, "h": 6, "name": "Gas Station"},

		# Side street houses
		{"x": -50, "z": -20, "w": 8, "d": 10, "h": 6, "name": "House"},
		{"x": -50, "z": 0, "w": 10, "d": 8, "h": 6, "name": "House"},
		{"x": -50, "z": 20, "w": 9, "d": 9, "h": 6, "name": "House"},
		{"x": 50, "z": -20, "w": 8, "d": 10, "h": 6, "name": "House"},
		{"x": 50, "z": 0, "w": 10, "d": 8, "h": 6, "name": "House"},
		{"x": 50, "z": 20, "w": 9, "d": 9, "h": 6, "name": "House"},

		# Church
		{"x": 0, "z": -60, "w": 15, "d": 25, "h": 18, "name": "Church"},

		# Warehouse area
		{"x": -60, "z": 50, "w": 25, "d": 20, "h": 8, "name": "Warehouse"},
		{"x": -30, "z": 55, "w": 15, "d": 15, "h": 6, "name": "Storage"},
	]

	for layout in building_layouts:
		var building = _create_building_data(
			layout.x, layout.z,
			layout.w, layout.d, layout.h,
			layout.name
		)
		buildings.append(building)

	print("[GameManager] Created ", buildings.size(), " demo buildings")
	return buildings


## Create building data in the format expected by building_generator
func _create_building_data(x: float, z: float, width: float, depth: float, height: float, bname: String) -> Dictionary:
	# Create polygon corners (rectangle)
	# Using a fake lat/lon that will be converted to these meter positions
	var half_w = width / 2.0
	var half_d = depth / 2.0

	# Fake GPS coordinates that map to our meter positions
	# The building generator will convert these back
	var base_lat = 51.5074  # Fake origin
	var base_lon = -0.1278
	var meters_per_deg = 111000.0

	var lat = base_lat + (z / meters_per_deg)
	var lon = base_lon + (x / meters_per_deg)
	var lat_offset = depth / meters_per_deg / 2.0
	var lon_offset = width / meters_per_deg / 2.0

	var polygon = [
		{"lat": lat - lat_offset, "lon": lon - lon_offset},
		{"lat": lat - lat_offset, "lon": lon + lon_offset},
		{"lat": lat + lat_offset, "lon": lon + lon_offset},
		{"lat": lat + lat_offset, "lon": lon - lon_offset},
	]

	return {
		"id": randi(),
		"polygon": polygon,
		"tags": {"building": "yes", "name": bname},
		"type": "building",
		"name": bname,
		"building_type": "commercial",
		"levels": int(height / 3.0),
		"height": height
	}


## Try to start real-world GPS mode
func start_real_world_mode() -> void:
	if not gps_manager:
		loading_failed.emit("GPS not available")
		return

	print("[GameManager] Attempting real-world mode...")
	loading_started.emit("Requesting GPS permission...")

	current_map_type = MapType.REAL_WORLD
	current_state = GameState.LOADING
	is_loading = true

	# Connect GPS signals
	if not gps_manager.location_updated.is_connected(_on_gps_location):
		gps_manager.location_updated.connect(_on_gps_location)
	if not gps_manager.location_error.is_connected(_on_gps_error):
		gps_manager.location_error.connect(_on_gps_error)

	# Start timeout timer
	var timeout_timer = get_tree().create_timer(initialization_timeout)
	timeout_timer.timeout.connect(_on_initialization_timeout)

	# Request GPS
	if gps_manager.has_method("_request_android_permission"):
		gps_manager._request_android_permission()


func _on_gps_location(latitude: float, longitude: float) -> void:
	if current_state != GameState.LOADING:
		return

	print("[GameManager] GPS acquired: ", latitude, ", ", longitude)
	loading_started.emit("Downloading map data...")

	# Fetch OSM data
	if osm_fetcher:
		if not osm_fetcher.buildings_loaded.is_connected(_on_osm_buildings):
			osm_fetcher.buildings_loaded.connect(_on_osm_buildings)
		if not osm_fetcher.fetch_error.is_connected(_on_osm_error):
			osm_fetcher.fetch_error.connect(_on_osm_error)
		osm_fetcher.fetch_buildings(latitude, longitude, render_distance)


func _on_osm_buildings(buildings: Array) -> void:
	print("[GameManager] Received ", buildings.size(), " buildings from OSM")
	loading_started.emit("Generating 3D world...")

	if building_generator:
		await building_generator.generate_buildings(buildings)
		building_generator.create_ground(render_distance * 2)

	if player and gps_manager:
		player.global_position = Vector3(0, 3, 0)

	is_loading = false
	current_state = GameState.PLAYING
	loading_complete.emit()
	buildings_ready.emit()
	game_started.emit()


func _on_gps_error(message: String) -> void:
	print("[GameManager] GPS error: ", message)
	_fallback_to_demo("GPS error: " + message)


func _on_osm_error(message: String) -> void:
	print("[GameManager] OSM error: ", message)
	_fallback_to_demo("Map download failed: " + message)


func _on_initialization_timeout() -> void:
	if current_state == GameState.LOADING and is_loading:
		print("[GameManager] Initialization timeout, falling back to demo")
		_fallback_to_demo("Connection timeout - using demo map")


func _fallback_to_demo(reason: String) -> void:
	print("[GameManager] Fallback to demo: ", reason)
	loading_failed.emit(reason + "\nLoading demo map instead...")
	await get_tree().create_timer(2.0).timeout
	_start_demo_mode()


## Pause/Resume
func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_paused.emit()


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_resumed.emit()


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()


## Get time of day for lighting
func get_time_of_day() -> Dictionary:
	var time = Time.get_time_dict_from_system()
	var hour = time.hour
	var minute = time.minute
	var day_progress = (hour - 6.0 + minute / 60.0) / 12.0
	day_progress = clamp(day_progress, 0.0, 1.0)

	return {
		"hour": hour,
		"minute": minute,
		"day_progress": day_progress,
		"is_night": hour < 6 or hour >= 18,
		"sun_angle": day_progress * 180.0
	}


## Check game state
func is_game_loading() -> bool:
	return is_loading


func get_state() -> GameState:
	return current_state


func get_mode() -> GameMode:
	return current_mode


func get_map_type() -> MapType:
	return current_map_type


func _spawn_zombie_wave(count: int) -> void:
	if not _zombie_script:
		_zombie_script = load("res://scripts/zombie.gd")
	if not _zombie_script:
		push_error("[GameManager] Could not load zombie.gd")
		return

	_zombie_count = count
	_wave_number += 1
	wave_started.emit(_wave_number, count)
	print("[GameManager] Wave %d — spawning %d zombies" % [_wave_number, count])

	var spawn_positions = [
		Vector3(28, 1, 28), Vector3(-28, 1, 28), Vector3(28, 1, -28), Vector3(-28, 1, -28),
		Vector3(0, 1, 32), Vector3(32, 1, 0), Vector3(-32, 1, 0), Vector3(0, 1, -32),
	]

	var scene_root = get_tree().current_scene
	for i in count:
		var zombie = CharacterBody3D.new()
		zombie.set_script(_zombie_script)
		var base_pos = spawn_positions[i % spawn_positions.size()]
		# Set position before add_child — spawning at the origin first lets the
		# physics engine treat the zombie as a moving platform and fling the player
		zombie.position = Vector3(
			base_pos.x + randf_range(-2.0, 2.0),
			base_pos.y,
			base_pos.z + randf_range(-2.0, 2.0)
		)
		scene_root.add_child(zombie)
		zombie.died.connect(_on_zombie_died)


func _on_zombie_died(points: int) -> void:
	score += points
	score_changed.emit(score)
	_zombie_count -= 1
	if _zombie_count <= 0:
		wave_complete.emit(_wave_number)
		print("[GameManager] Wave %d complete!" % _wave_number)
		await get_tree().create_timer(4.0).timeout
		_spawn_zombie_wave(5 + _wave_number * 3)
