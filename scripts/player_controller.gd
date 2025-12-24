extends CharacterBody3D
## First-Person Player Controller with Touch Controls
## Handles movement, looking, and GPS synchronization

signal player_moved(position: Vector3)

# Movement settings
@export var walk_speed: float = 4.0  # meters per second
@export var run_speed: float = 7.0
@export var mouse_sensitivity: float = 0.002
@export var touch_look_sensitivity: float = 0.003

# Jump and gravity
@export var jump_velocity: float = 4.5
@export var gravity_multiplier: float = 1.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Camera
@onready var camera: Camera3D = $Camera3D
@onready var camera_pivot: Node3D = $CameraPivot

# Touch control state
var touch_movement: Vector2 = Vector2.ZERO  # From virtual joystick
var touch_look_start: Dictionary = {}  # Track touch positions for look
var is_running: bool = false

# GPS sync
var gps_sync_enabled: bool = true
@onready var gps_manager = get_node_or_null("/root/GPSManager")


func _ready() -> void:
	# Capture mouse for desktop testing
	if OS.get_name() != "Android":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Connect to GPS updates if available
	if gps_manager:
		gps_manager.location_updated.connect(_on_gps_updated)


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * gravity_multiplier * delta

	# Get movement input
	var input_dir = _get_movement_input()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Calculate speed
	var current_speed = run_speed if is_running else walk_speed

	# Apply movement
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# Handle jump (desktop only)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

	# Emit position update
	if velocity.length() > 0.1:
		player_moved.emit(global_position)


func _get_movement_input() -> Vector2:
	# Combine keyboard and touch input
	var input = Vector2.ZERO

	# Keyboard input (for desktop testing)
	if Input.is_action_pressed("move_forward"):
		input.y -= 1
	if Input.is_action_pressed("move_back"):
		input.y += 1
	if Input.is_action_pressed("move_left"):
		input.x -= 1
	if Input.is_action_pressed("move_right"):
		input.x += 1

	# Touch joystick input (from touch_controls.gd)
	input += touch_movement

	return input.normalized() if input.length() > 1 else input


func _input(event: InputEvent) -> void:
	# Mouse look (desktop)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative * mouse_sensitivity)

	# Touch look (mobile) - right side of screen
	if event is InputEventScreenTouch:
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.5:
			if event.pressed:
				touch_look_start[event.index] = event.position
			else:
				touch_look_start.erase(event.index)

	if event is InputEventScreenDrag:
		if touch_look_start.has(event.index):
			var delta = event.relative * touch_look_sensitivity
			_rotate_camera(delta)

	# Toggle mouse capture (desktop)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rotate_camera(delta: Vector2) -> void:
	# Rotate player horizontally
	rotate_y(-delta.x)

	# Rotate camera vertically (clamped)
	if camera_pivot:
		camera_pivot.rotate_x(-delta.y)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2 + 0.1, PI/2 - 0.1)
	elif camera:
		camera.rotate_x(-delta.y)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2 + 0.1, PI/2 - 0.1)


## Called by touch_controls.gd to set joystick input
func set_touch_movement(movement: Vector2) -> void:
	touch_movement = movement


## Called by touch_controls.gd to set run state
func set_running(running: bool) -> void:
	is_running = running


## Sync player position with GPS
func _on_gps_updated(latitude: float, longitude: float) -> void:
	if not gps_sync_enabled:
		return

	if gps_manager and gps_manager.has_origin:
		var gps_pos = gps_manager.world_position
		# Only sync horizontal position, keep current Y (height)
		global_position.x = gps_pos.x
		global_position.z = gps_pos.z


## Enable/disable GPS sync
func set_gps_sync(enabled: bool) -> void:
	gps_sync_enabled = enabled


## Teleport player to GPS position
func sync_to_gps() -> void:
	if gps_manager and gps_manager.has_origin:
		var gps_pos = gps_manager.world_position
		global_position = Vector3(gps_pos.x, global_position.y, gps_pos.z)


## Get player's current GPS coordinates
func get_current_gps() -> Dictionary:
	if gps_manager:
		return gps_manager.meters_to_gps(global_position)
	return {"latitude": 0.0, "longitude": 0.0}
