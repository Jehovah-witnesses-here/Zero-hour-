extends CharacterBody3D
## First-Person Player Controller with Touch Controls
## Movement is ALWAYS relative to where the camera is looking

signal player_moved(position: Vector3)
signal health_changed(current: float, maximum: float)
signal player_died

# Movement settings
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var touch_look_sensitivity: float = 0.007
@export var jump_velocity: float = 5.0

# Gravity
@export var gravity_multiplier: float = 2.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Health
var max_health: float = 100.0
var current_health: float = 100.0
var _is_dead: bool = false

# Camera nodes
var camera: Camera3D = null
var camera_pivot: Node3D = null

# Camera rotation
var camera_rotation_x: float = 0.0
var camera_rotation_y: float = 0.0

# Touch control state
var touch_movement: Vector2 = Vector2.ZERO
var touch_look_active: Dictionary = {}
var _shoot_tap: Dictionary = {}
var is_running: bool = false

# GPS sync
var gps_sync_enabled: bool = false


func _ready() -> void:
	camera_pivot = $CameraPivot
	camera = $CameraPivot/Camera3D
	if not camera:
		camera = $Camera3D
	add_to_group("player")
	print("[Player] Ready - touch controls enabled")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * gravity_multiplier * delta
	else:
		velocity.y = 0.0

	# Jump (keyboard)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = _get_movement_input()

	var cam_basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	forward.y = 0.0
	forward = forward.normalized()
	right.y = 0.0
	right = right.normalized()

	# input_dir.y negative = forward, positive = backward
	var direction = (forward * input_dir.y + right * input_dir.x).normalized()
	var current_speed = run_speed if is_running else walk_speed

	if direction.length() > 0.1:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed * 0.5)
		velocity.z = move_toward(velocity.z, 0.0, current_speed * 0.5)

	move_and_slide()

	if velocity.length() > 0.1:
		player_moved.emit(global_position)


func _get_movement_input() -> Vector2:
	var input = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input.y -= 1.0
	if Input.is_action_pressed("move_back"):
		input.y += 1.0
	if Input.is_action_pressed("move_left"):
		input.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input.x += 1.0
	input += touch_movement
	if input.length() > 1.0:
		input = input.normalized()
	return input


func _input(event: InputEvent) -> void:
	if _is_dead:
		return

	var screen_width = get_viewport().get_visible_rect().size.x

	if event is InputEventScreenTouch:
		if event.position.x > screen_width * 0.4:
			if event.pressed:
				touch_look_active[event.index] = event.position
				_shoot_tap[event.index] = event.position
			else:
				touch_look_active.erase(event.index)
				if _shoot_tap.has(event.index):
					var start_pos: Vector2 = _shoot_tap[event.index]
					if event.position.distance_to(start_pos) < 20.0:
						_shoot()
					_shoot_tap.erase(event.index)

	if event is InputEventScreenDrag:
		if touch_look_active.has(event.index):
			_shoot_tap.erase(event.index)
			_handle_look(event.relative)

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_handle_look(event.relative * 0.5)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_shoot()


func _handle_look(delta: Vector2) -> void:
	camera_rotation_y -= delta.x * touch_look_sensitivity
	camera_rotation_x -= delta.y * touch_look_sensitivity
	camera_rotation_x = clamp(camera_rotation_x, -1.4, 1.4)
	rotation.y = camera_rotation_y
	if camera_pivot:
		camera_pivot.rotation.x = camera_rotation_x


func _shoot() -> void:
	if not camera:
		return
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z * 150.0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("zombies"):
		result.collider.take_damage(25.0)


func take_damage(amount: float) -> void:
	if _is_dead:
		return
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	player_died.emit()
	print("[Player] Player died!")


func do_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity


func set_touch_movement(movement: Vector2) -> void:
	touch_movement = movement


func set_running(running: bool) -> void:
	is_running = running


func set_gps_sync(enabled: bool) -> void:
	gps_sync_enabled = enabled


func get_position_string() -> String:
	return "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z]
