extends CharacterBody3D
## First-Person Player Controller with Touch Controls
## Movement is ALWAYS relative to where the camera is looking

signal player_moved(position: Vector3)

# Movement settings
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var touch_look_sensitivity: float = 0.004

# Gravity
@export var gravity_multiplier: float = 2.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Camera nodes
var camera: Camera3D = null
var camera_pivot: Node3D = null

# Camera rotation
var camera_rotation_x: float = 0.0  # Up/down (pitch)
var camera_rotation_y: float = 0.0  # Left/right (yaw)

# Touch control state
var touch_movement: Vector2 = Vector2.ZERO
var touch_look_active: Dictionary = {}
var is_running: bool = false

# GPS sync
var gps_sync_enabled: bool = false  # Disabled by default for demo mode


func _ready() -> void:
	# Get camera nodes
	camera_pivot = $CameraPivot
	camera = $CameraPivot/Camera3D

	if not camera:
		camera = $Camera3D

	# Add to player group for easy finding
	add_to_group("player")

	print("[Player] Ready - touch controls enabled")


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * gravity_multiplier * delta
	else:
		velocity.y = 0

	# Get input and calculate movement direction relative to camera
	var input_dir = _get_movement_input()

	# Get camera's forward and right vectors (ignore Y component for horizontal movement)
	var cam_basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x

	# Flatten to horizontal plane
	forward.y = 0
	forward = forward.normalized()
	right.y = 0
	right = right.normalized()

	# Calculate movement direction relative to where camera is looking
	var direction = (forward * -input_dir.y + right * input_dir.x).normalized()

	# Apply speed
	var current_speed = run_speed if is_running else walk_speed

	if direction.length() > 0.1:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Smooth stop
		velocity.x = move_toward(velocity.x, 0, current_speed * 0.5)
		velocity.z = move_toward(velocity.z, 0, current_speed * 0.5)

	move_and_slide()

	# Emit position update
	if velocity.length() > 0.1:
		player_moved.emit(global_position)


func _get_movement_input() -> Vector2:
	var input = Vector2.ZERO

	# Keyboard input (for testing on PC)
	if Input.is_action_pressed("move_forward"):
		input.y -= 1
	if Input.is_action_pressed("move_back"):
		input.y += 1
	if Input.is_action_pressed("move_left"):
		input.x -= 1
	if Input.is_action_pressed("move_right"):
		input.x += 1

	# Add touch joystick input
	input += touch_movement

	# Normalize if over 1
	if input.length() > 1.0:
		input = input.normalized()

	return input


func _input(event: InputEvent) -> void:
	# Touch look - right side of screen
	if event is InputEventScreenTouch:
		var screen_width = get_viewport().get_visible_rect().size.x

		# Right half of screen = look control
		if event.position.x > screen_width * 0.4:
			if event.pressed:
				touch_look_active[event.index] = event.position
			else:
				touch_look_active.erase(event.index)

	if event is InputEventScreenDrag:
		if touch_look_active.has(event.index):
			_handle_look(event.relative)

	# Mouse look for PC testing
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_handle_look(event.relative * 0.5)


func _handle_look(delta: Vector2) -> void:
	# Horizontal rotation (yaw) - rotate the whole player
	camera_rotation_y -= delta.x * touch_look_sensitivity

	# Vertical rotation (pitch) - rotate only the camera pivot
	camera_rotation_x -= delta.y * touch_look_sensitivity
	camera_rotation_x = clamp(camera_rotation_x, -1.4, 1.4)  # ~80 degrees up/down

	# Apply rotations
	rotation.y = camera_rotation_y

	if camera_pivot:
		camera_pivot.rotation.x = camera_rotation_x


## Called by touch_controls.gd to set joystick input
func set_touch_movement(movement: Vector2) -> void:
	touch_movement = movement


## Called by touch_controls.gd to set run state
func set_running(running: bool) -> void:
	is_running = running


## Enable/disable GPS sync
func set_gps_sync(enabled: bool) -> void:
	gps_sync_enabled = enabled


## Get player's current position
func get_position_string() -> String:
	return "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z]
