extends Node
## Game Manager - Core game state and coordination
## Autoloaded singleton that manages game flow

signal game_started
signal game_paused
signal game_resumed
signal buildings_ready
signal loading_started(message: String)
signal loading_complete

# Game state
enum GameState { LOADING, PLAYING, PAUSED, MENU }
var current_state: GameState = GameState.LOADING

# References (set after scene loads)
var player: CharacterBody3D = null
var building_generator: Node3D = null
var osm_fetcher: Node = null
var hud: Control = null

# GPS Manager (autoload)
@onready var gps_manager = get_node("/root/GPSManager")

# Loading state
var is_loading: bool = true
var loading_message: String = "Initializing..."

# Settings
var render_distance: float = 200.0  # meters
var last_load_position: Vector3 = Vector3.ZERO
var reload_threshold: float = 100.0  # meters before reloading buildings


func _ready() -> void:
	print("[GameManager] Initializing...")

	# Wait for scene to load
	await get_tree().process_frame

	# Find scene references
	_find_references()

	# Connect signals
	_connect_signals()

	# Start location tracking
	_start_game()


func _find_references() -> void:
	# These will be found after main scene loads
	player = get_tree().get_first_node_in_group("player")
	building_generator = get_tree().get_first_node_in_group("building_generator")

	# OSM fetcher may be a child of main
	var main = get_tree().current_scene
	if main:
		osm_fetcher = main.get_node_or_null("OSMFetcher")
		if not osm_fetcher:
			osm_fetcher = OSMFetcher.new()
			osm_fetcher.name = "OSMFetcher"
			main.add_child(osm_fetcher)


func _connect_signals() -> void:
	if gps_manager:
		gps_manager.location_updated.connect(_on_location_updated)
		gps_manager.location_error.connect(_on_location_error)

	if osm_fetcher:
		osm_fetcher.buildings_loaded.connect(_on_buildings_loaded)
		osm_fetcher.fetch_error.connect(_on_fetch_error)
		osm_fetcher.fetch_started.connect(func(): loading_started.emit("Downloading map data..."))


func _start_game() -> void:
	loading_started.emit("Waiting for GPS signal...")

	# If GPS manager is in simulation mode, start immediately
	if gps_manager and gps_manager.simulation_mode:
		print("[GameManager] Running in simulation mode")
		await get_tree().create_timer(0.5).timeout
		_load_buildings_at_location(gps_manager.simulated_lat, gps_manager.simulated_lon)


func _on_location_updated(latitude: float, longitude: float) -> void:
	if is_loading:
		# First location received - load buildings
		_load_buildings_at_location(latitude, longitude)
	else:
		# Check if we need to reload buildings
		var current_pos = gps_manager.world_position
		var distance = current_pos.distance_to(last_load_position)

		if distance > reload_threshold:
			print("[GameManager] Player moved ", distance, "m, reloading buildings...")
			_load_buildings_at_location(latitude, longitude)


func _load_buildings_at_location(latitude: float, longitude: float) -> void:
	if not osm_fetcher:
		push_error("[GameManager] OSM Fetcher not found!")
		return

	loading_started.emit("Downloading buildings...")
	osm_fetcher.fetch_buildings(latitude, longitude, render_distance)


func _on_buildings_loaded(buildings: Array) -> void:
	loading_started.emit("Generating 3D buildings...")

	if building_generator:
		await building_generator.generate_buildings(buildings)

		# Create ground if not exists
		if building_generator.get_node_or_null("Ground") == null:
			building_generator.create_ground(render_distance * 2)

	# Update last load position
	if gps_manager:
		last_load_position = gps_manager.world_position

	# Game is ready
	is_loading = false
	current_state = GameState.PLAYING
	loading_complete.emit()
	buildings_ready.emit()
	game_started.emit()

	print("[GameManager] Game started! ", buildings.size(), " buildings loaded.")


func _on_fetch_error(message: String) -> void:
	push_error("[GameManager] Fetch error: ", message)
	loading_started.emit("Error: " + message)

	# Try to continue with cached data
	if osm_fetcher and gps_manager:
		var cached = osm_fetcher.get_cached_buildings(
			gps_manager.current_latitude,
			gps_manager.current_longitude
		)
		if cached.size() > 0:
			_on_buildings_loaded(cached)
		else:
			# Create empty world
			is_loading = false
			current_state = GameState.PLAYING
			loading_complete.emit()


func _on_location_error(message: String) -> void:
	push_error("[GameManager] Location error: ", message)

	# Fall back to simulation mode
	if gps_manager:
		gps_manager.simulation_mode = true
		loading_started.emit("GPS unavailable, using simulation...")
		await get_tree().create_timer(1.0).timeout
		_load_buildings_at_location(gps_manager.simulated_lat, gps_manager.simulated_lon)


## Pause game
func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_paused.emit()


## Resume game
func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_resumed.emit()


## Toggle pause
func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()


## Check if game is currently loading
func is_game_loading() -> bool:
	return is_loading


## Get current game state
func get_state() -> GameState:
	return current_state


## Force reload buildings at current location
func reload_buildings() -> void:
	if gps_manager:
		_load_buildings_at_location(gps_manager.current_latitude, gps_manager.current_longitude)


## Get current time of day (for lighting)
func get_time_of_day() -> Dictionary:
	var time = Time.get_time_dict_from_system()
	var hour = time.hour
	var minute = time.minute

	# Calculate sun angle based on time
	# 6:00 = sunrise (0 degrees), 12:00 = noon (90 degrees), 18:00 = sunset (180 degrees)
	var day_progress = (hour - 6.0 + minute / 60.0) / 12.0
	day_progress = clamp(day_progress, 0.0, 1.0)

	var is_night = hour < 6 or hour >= 18

	return {
		"hour": hour,
		"minute": minute,
		"day_progress": day_progress,
		"is_night": is_night,
		"sun_angle": day_progress * 180.0
	}


# Reference to OSMFetcher class for creating instance
class OSMFetcher extends Node:
	pass
