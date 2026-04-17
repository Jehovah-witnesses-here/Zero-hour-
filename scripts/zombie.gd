extends CharacterBody3D
## Zombie enemy - chases player, deals melee damage, takes raycast hits

signal died

var max_health: float = 100.0
var health: float = 100.0
var move_speed: float = 2.0
var attack_damage: float = 10.0
var attack_range: float = 1.8
var attack_cooldown: float = 1.5

var _player: CharacterBody3D = null
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _body_mat: StandardMaterial3D = null

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_build_visuals()
	add_to_group("zombies")
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")


func _build_visuals() -> void:
	var body_mesh = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.7
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.25, 0.38, 0.15)
	body_mesh.material_override = _body_mat
	add_child(body_mesh)

	var head_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.22
	head_mesh.mesh = sphere
	head_mesh.position.y = 1.62
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.58, 0.64, 0.40)
	head_mesh.material_override = head_mat
	add_child(head_mesh)

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.4
	col.shape = shape
	col.position.y = 0.7
	add_child(col)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_attack_timer = max(0.0, _attack_timer - delta)

	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		move_and_slide()
		return

	var dist = global_position.distance_to(_player.global_position)

	if dist <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			if _player.has_method("take_damage"):
				_player.take_damage(attack_damage)
	else:
		var dir = _player.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		var look_target = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
		if look_target.distance_to(global_position) > 0.1:
			look_at(look_target)

	move_and_slide()


func take_damage(amount: float) -> void:
	if _is_dead:
		return
	health -= amount
	if _body_mat:
		var orig = _body_mat.albedo_color
		_body_mat.albedo_color = Color(0.9, 0.1, 0.1)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and not _is_dead:
			_body_mat.albedo_color = orig
	if health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	died.emit()
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 2.0, 0.8)
	tween.tween_callback(queue_free)
