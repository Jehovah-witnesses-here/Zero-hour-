extends CharacterBody3D
## First-Person Player Controller with Touch Controls
## Movement is ALWAYS relative to where the camera is looking

signal player_moved(position: Vector3)
signal health_changed(current: float, maximum: float)
signal player_died
signal shot_hit(is_kill: bool)
signal ammo_changed(current: int, reserve: int)

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

# Ammo
var ammo: int = 30
var ammo_reserve: int = 90
const MAG_SIZE: int = 30
var _reloading: bool = false
var _reload_timer: float = 0.0
const RELOAD_TIME: float = 2.5

# Coyote time — allows jump within 0.15s of leaving the floor
var _coyote_time: float = 0.0

# Mantle / auto-climb
const MANTLE_MAX_HEIGHT: float = 1.5
const MANTLE_REACH: float = 0.9
const MANTLE_DURATION: float = 0.35
var _mantling: bool = false
var _mantle_start: Vector3 = Vector3.ZERO
var _mantle_target: Vector3 = Vector3.ZERO
var _mantle_timer: float = 0.0

# Ladder
const LADDER_SPEED: float = 3.5
var _on_ladder: bool = false
var _near_ladder: bool = false


func _ready() -> void:
	camera_pivot = $CameraPivot
	camera = $CameraPivot/Camera3D
	if not camera:
		camera = $Camera3D
	add_to_group("player")
	# Prevent getting snagged on trimesh seams and pipe joints
	floor_block_on_wall = false
	wall_min_slide_angle = deg_to_rad(20.0)
	safe_margin = 0.04
	_create_gun()
	print("[Player] Ready - touch controls enabled")


func _create_gun() -> void:
	if not camera:
		return

	var gun_root = Node3D.new()
	gun_root.position = Vector3(0.18, -0.18, -0.35)
	camera.add_child(gun_root)

	# Barrel
	var barrel = MeshInstance3D.new()
	var barrel_mesh = BoxMesh.new()
	barrel_mesh.size = Vector3(0.04, 0.04, 0.22)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.0, -0.05)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.15)
	barrel.material_override = mat
	gun_root.add_child(barrel)

	# Body
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.06, 0.1, 0.14)
	body.mesh = body_mesh
	body.position = Vector3(0.0, -0.03, 0.08)
	body.material_override = mat
	gun_root.add_child(body)

	# Handle
	var handle = MeshInstance3D.new()
	var handle_mesh = BoxMesh.new()
	handle_mesh.size = Vector3(0.05, 0.1, 0.05)
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, -0.1, 0.1)
	var handle_mat = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.25, 0.15, 0.1)
	handle.material_override = handle_mat
	gun_root.add_child(handle)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Mantle animation — override all other movement
	if _mantling:
		_mantle_timer += delta
		var t = min(_mantle_timer / MANTLE_DURATION, 1.0)
		global_position = _mantle_start.lerp(_mantle_target, ease(t, -2.0))
		if t >= 1.0:
			_mantling = false
			velocity = Vector3.ZERO
		return

	# Ladder mode — vertical movement, no gravity
	if _on_ladder:
		var input_dir = _get_movement_input()
		velocity.y = -input_dir.y * LADDER_SPEED
		velocity.x = 0.0
		velocity.z = 0.0
		if Input.is_action_just_pressed("jump"):
			_on_ladder = false
			velocity.y = jump_velocity
		move_and_slide()
		return

	if is_on_floor():
		_coyote_time = 0.15
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		_coyote_time = max(0.0, _coyote_time - delta)
		velocity.y -= gravity * gravity_multiplier * delta

	var cam_basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis

	# Jump / mantle (CoD style: jump toward ledge to mantle)
	if Input.is_action_just_pressed("jump"):
		if _near_ladder and not _on_ladder:
			_on_ladder = true
			velocity = Vector3.ZERO
		else:
			var move_dir = (-cam_basis.z * Vector3(1, 0, 1)).normalized()
			if not _try_mantle(move_dir):
				if _coyote_time > 0.0:
					velocity.y = jump_velocity
					_coyote_time = 0.0

	var input_dir = _get_movement_input()
	var forward = -cam_basis.z
	var right = cam_basis.x
	forward.y = 0.0
	forward = forward.normalized()
	right.y = 0.0
	right = right.normalized()

	var direction = (forward * -input_dir.y + right * input_dir.x).normalized()
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


func _try_mantle(move_dir: Vector3) -> bool:
	var space = get_world_3d().direct_space_state
	var feet = global_position
	# Ray at chest height forward — must hit a wall
	var chest = feet + Vector3.UP * 0.8
	var q1 = PhysicsRayQueryParameters3D.create(chest, chest + move_dir * MANTLE_REACH)
	q1.exclude = [self]
	var wall = space.intersect_ray(q1)
	if not wall:
		return false
	# Ray above head — must be clear
	var crown = feet + Vector3.UP * 1.85
	var q2 = PhysicsRayQueryParameters3D.create(crown, crown + move_dir * MANTLE_REACH)
	q2.exclude = [self]
	if space.intersect_ray(q2):
		return false
	# Downward ray from above the wall to find ledge surface
	var above = wall.position + Vector3.UP * (MANTLE_MAX_HEIGHT + 0.3)
	var q3 = PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * (MANTLE_MAX_HEIGHT + 0.5))
	q3.exclude = [self]
	var ledge = space.intersect_ray(q3)
	if not ledge:
		return false
	var climb = ledge.position.y - feet.y
	if climb < 0.35 or climb > MANTLE_MAX_HEIGHT:
		return false
	# Start mantle
	_mantling = true
	_mantle_timer = 0.0
	_mantle_start = global_position
	_mantle_target = Vector3(
		global_position.x + move_dir.x * 0.6,
		ledge.position.y + 0.9,
		global_position.z + move_dir.z * 0.6
	)
	return true


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
		var screen_height = get_viewport().get_visible_rect().size.y
		var in_button_zone = event.position.x > screen_width * 0.78 and event.position.y > screen_height * 0.65
		if event.position.x > screen_width * 0.4 and not in_button_zone:
			if event.pressed:
				touch_look_active[event.index] = event.position
			else:
				touch_look_active.erase(event.index)

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
	if not camera or _reloading:
		return
	if ammo <= 0:
		_start_reload()
		return
	ammo -= 1
	ammo_changed.emit(ammo, ammo_reserve)
	if ammo == 0:
		_start_reload()
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z * 150.0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	if result:
		var is_kill := false
		if result.collider.is_in_group("zombie_heads"):
			var zombie = result.collider.get_meta("zombie")
			zombie.take_damage(100.0)
			is_kill = zombie._is_dead
		elif result.collider.is_in_group("zombies"):
			result.collider.take_damage(25.0)
			is_kill = result.collider._is_dead
		shot_hit.emit(is_kill)


func _start_reload() -> void:
	if _reloading or ammo_reserve <= 0 or ammo == MAG_SIZE:
		return
	_reloading = true
	_reload_timer = RELOAD_TIME


func _process(delta: float) -> void:
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			var needed = MAG_SIZE - ammo
			var take = min(needed, ammo_reserve)
			ammo += take
			ammo_reserve -= take
			ammo_changed.emit(ammo, ammo_reserve)
	if Input.is_action_just_pressed("reload"):
		_start_reload()


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
	if not camera_pivot:
		return
	var fwd = (-camera_pivot.global_transform.basis.z * Vector3(1, 0, 1)).normalized()
	if _try_mantle(fwd):
		return
	if _coyote_time > 0.0:
		velocity.y = jump_velocity
		_coyote_time = 0.0


func set_touch_movement(movement: Vector2) -> void:
	touch_movement = movement


func set_running(running: bool) -> void:
	is_running = running


func set_gps_sync(enabled: bool) -> void:
	gps_sync_enabled = enabled


func enter_ladder() -> void:
	_near_ladder = true


func exit_ladder() -> void:
	_near_ladder = false
	_on_ladder = false


func get_position_string() -> String:
	return "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z]
