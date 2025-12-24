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

# GPS Manager (autoload)
@onready var gps_manager = get_node_or_null("/root/GPSManager")

# Loading settings
var initialization_timeout: float = 10.0  # seconds before fallback
var is_loading: bool = false
var loading_message: String = ""

# Map settings
var render_distance: float = 200.0


func _ready() -> void:
	print("[GameManager] Starting ZERO-HOUR...")

	# Wait for scene to fully load
	await get_tree().process_frame
	await get_tree().process_frame

	_find_references()

	# Start in demo mode immediately - no waiting for GPS
	_start_demo_mode()


func _find_references() -> void:
	player = get_tree().get_first_node_in_group("player")
	building_generator = get_tree().get_first_node_in_group("building_generator")

	var main = get_tree().current_scene
	if main:
		osm_fetcher = main.get_node_or_null("OSMFetcher")


## Start demo mode with a pre-built test map (no GPS needed)
func _start_demo_mode() -> void:
	print("[GameManager] Starting DEMO mode...")
	loading_started.emit("Loading demo map...")

	current_map_type = MapType.DEMO
	current_mode = GameMode.SURVIVAL
	current_state = GameState.LOADING
	is_loading = true

	await get_tree().create_timer(0.5).timeout

	# Generate demo buildings
	if building_generator:
		var demo_buildings = _create_demo_buildings()
		await building_generator.generate_buildings(demo_buildings)
		building_generator.create_ground(500.0)

	# Position player
	if player:
		player.global_position = Vector3(0, 2, 0)

	# Done loading
	is_loading = false
	current_state = GameState.PLAYING
	loading_complete.emit()
	buildings_ready.emit()
	game_started.emit()

	print("[GameManager] Demo mode ready! Walk around with the joystick.")


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
		player.global_position = Vector3(0, 2, 0)

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
