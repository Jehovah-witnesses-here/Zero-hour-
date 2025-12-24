extends Node
## GPS Manager - Handles real-world location tracking
## Converts GPS coordinates to game-world meters

signal location_updated(latitude: float, longitude: float)
signal location_error(message: String)
signal permission_granted
signal permission_denied

# Current GPS position
var current_latitude: float = 0.0
var current_longitude: float = 0.0
var origin_latitude: float = 0.0
var origin_longitude: float = 0.0
var has_origin: bool = false

# Position in game-world meters (relative to origin)
var world_position: Vector3 = Vector3.ZERO

# Earth radius in meters for coordinate conversion
const EARTH_RADIUS: float = 6378137.0

# Android location singleton
var _location_singleton = null
var _is_android: bool = false
var _has_permission: bool = false

# Simulated movement for testing (when no GPS available)
var simulation_mode: bool = false
var simulated_lat: float = 51.5074  # Default: London
var simulated_lon: float = -0.1278


func _ready() -> void:
	_is_android = OS.get_name() == "Android"

	if _is_android:
		_setup_android_location()
	else:
		# Enable simulation mode for non-Android platforms
		simulation_mode = true
		print("[GPS] Running in simulation mode (not on Android)")
		_set_origin(simulated_lat, simulated_lon)


func _setup_android_location() -> void:
	# Check if we have the location plugin
	if Engine.has_singleton("WbLocationPlugin"):
		_location_singleton = Engine.get_singleton("WbLocationPlugin")
		_location_singleton.connect("on_location_update", _on_location_update)
		_location_singleton.connect("on_location_error", _on_location_error)
		print("[GPS] Android location plugin found")
	else:
		# Fallback: Use Android's native location via JavaClass
		print("[GPS] Using native Android location API")
		_request_android_permission()


func _request_android_permission() -> void:
	if not _is_android:
		return

	var permissions = ["android.permission.ACCESS_FINE_LOCATION",
					   "android.permission.ACCESS_COARSE_LOCATION"]

	# Request permissions
	OS.request_permissions()

	# Check after a delay
	await get_tree().create_timer(1.0).timeout
	_check_permission_status()


func _check_permission_status() -> void:
	if OS.get_granted_permissions().has("android.permission.ACCESS_FINE_LOCATION"):
		_has_permission = true
		permission_granted.emit()
		_start_location_updates()
	else:
		_has_permission = false
		permission_denied.emit()
		location_error.emit("Location permission denied")


func _start_location_updates() -> void:
	if _location_singleton:
		_location_singleton.start_location_updates()
	else:
		# Start polling location using native API
		_poll_native_location()


func _poll_native_location() -> void:
	# This is a simplified approach - in production you'd use a proper Android plugin
	# For now, we'll use Input.get_accelerometer() as a placeholder
	# and rely on the location plugin for actual GPS

	if simulation_mode:
		return

	# Create timer for polling
	var timer = Timer.new()
	timer.wait_time = 2.0  # Poll every 2 seconds
	timer.timeout.connect(_request_native_location)
	add_child(timer)
	timer.start()


func _request_native_location() -> void:
	# Placeholder for native location request
	# In a real implementation, you'd call Android's LocationManager
	pass


func _on_location_update(latitude: float, longitude: float, accuracy: float) -> void:
	current_latitude = latitude
	current_longitude = longitude

	if not has_origin:
		_set_origin(latitude, longitude)

	_update_world_position()
	location_updated.emit(latitude, longitude)


func _on_location_error(error: String) -> void:
	location_error.emit(error)
	print("[GPS] Error: ", error)


func _set_origin(lat: float, lon: float) -> void:
	origin_latitude = lat
	origin_longitude = lon
	has_origin = true
	print("[GPS] Origin set to: ", lat, ", ", lon)


func _update_world_position() -> void:
	world_position = gps_to_meters(current_latitude, current_longitude)


## Convert GPS coordinates to local game meters (relative to origin)
func gps_to_meters(lat: float, lon: float) -> Vector3:
	if not has_origin:
		return Vector3.ZERO

	# Convert lat/lon difference to meters using Mercator projection
	var lat_diff = lat - origin_latitude
	var lon_diff = lon - origin_longitude

	# Meters per degree (approximate, varies with latitude)
	var meters_per_lat_degree = 111132.92 - 559.82 * cos(2 * deg_to_rad(origin_latitude)) + 1.175 * cos(4 * deg_to_rad(origin_latitude))
	var meters_per_lon_degree = 111412.84 * cos(deg_to_rad(origin_latitude)) - 93.5 * cos(3 * deg_to_rad(origin_latitude))

	var x = lon_diff * meters_per_lon_degree  # East-West
	var z = lat_diff * meters_per_lat_degree  # North-South (negative because Z is forward in Godot)

	return Vector3(x, 0, -z)


## Convert local game meters back to GPS coordinates
func meters_to_gps(position: Vector3) -> Dictionary:
	if not has_origin:
		return {"latitude": 0.0, "longitude": 0.0}

	var meters_per_lat_degree = 111132.92 - 559.82 * cos(2 * deg_to_rad(origin_latitude))
	var meters_per_lon_degree = 111412.84 * cos(deg_to_rad(origin_latitude))

	var lat = origin_latitude + (-position.z / meters_per_lat_degree)
	var lon = origin_longitude + (position.x / meters_per_lon_degree)

	return {"latitude": lat, "longitude": lon}


## Simulate walking in a direction (for testing without GPS)
func simulate_walk(direction: Vector3, speed: float = 1.4) -> void:  # 1.4 m/s = walking speed
	if not simulation_mode:
		return

	var delta = get_process_delta_time()
	var movement = direction.normalized() * speed * delta

	# Convert movement back to GPS delta
	var gps = meters_to_gps(world_position + movement)
	simulated_lat = gps.latitude
	simulated_lon = gps.longitude

	_on_location_update(simulated_lat, simulated_lon, 5.0)


## Get current GPS as string (for UI display)
func get_gps_string() -> String:
	return "%.6f, %.6f" % [current_latitude, current_longitude]


## Check if GPS is available and working
func is_available() -> bool:
	return has_origin or simulation_mode
