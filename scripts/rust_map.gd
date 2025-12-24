extends Node3D
## Rust Map Generator - MW2-style oil yard arena
## Based on the iconic Call of Duty map layout

signal map_generated

# Materials
var _metal_mat: StandardMaterial3D
var _rust_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D
var _sand_mat: StandardMaterial3D
var _pipe_mat: StandardMaterial3D
var _container_mats: Array[StandardMaterial3D] = []

# Map container
var _map_container: Node3D


func _ready() -> void:
	_setup_materials()
	print("[RustMap] Ready")


func _setup_materials() -> void:
	# Rusty metal (tower, derrick)
	_rust_mat = StandardMaterial3D.new()
	_rust_mat.albedo_color = Color(0.45, 0.3, 0.2)
	_rust_mat.metallic = 0.6
	_rust_mat.roughness = 0.8
	_rust_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Clean metal (pipes)
	_metal_mat = StandardMaterial3D.new()
	_metal_mat.albedo_color = Color(0.5, 0.48, 0.45)
	_metal_mat.metallic = 0.7
	_metal_mat.roughness = 0.5
	_metal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Pipe material (slightly different)
	_pipe_mat = StandardMaterial3D.new()
	_pipe_mat.albedo_color = Color(0.55, 0.5, 0.4)
	_pipe_mat.metallic = 0.5
	_pipe_mat.roughness = 0.6
	_pipe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Concrete
	_concrete_mat = StandardMaterial3D.new()
	_concrete_mat.albedo_color = Color(0.55, 0.52, 0.48)
	_concrete_mat.roughness = 0.95
	_concrete_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Desert sand ground
	_sand_mat = StandardMaterial3D.new()
	_sand_mat.albedo_color = Color(0.76, 0.65, 0.45)
	_sand_mat.roughness = 1.0

	# Container colors (various shipping container colors)
	var container_colors = [
		Color(0.6, 0.2, 0.15),  # Red/rust
		Color(0.2, 0.35, 0.5),  # Blue
		Color(0.25, 0.4, 0.25), # Green
		Color(0.5, 0.45, 0.35), # Tan
		Color(0.3, 0.3, 0.32),  # Gray
	]

	for color in container_colors:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.4
		mat.roughness = 0.7
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_container_mats.append(mat)


func generate_map() -> void:
	print("[RustMap] Generating Rust-style map...")

	# Clear old map
	if _map_container:
		_map_container.queue_free()
		await get_tree().process_frame

	_map_container = Node3D.new()
	_map_container.name = "RustMap"
	add_child(_map_container)

	# Create ground (desert sand)
	_create_ground()

	# Central oil tower (the iconic centerpiece)
	_create_oil_tower(Vector3(0, 0, 0))

	# Oil derrick in northwest
	_create_oil_derrick(Vector3(-18, 0, -15))

	# Elevated pipeline along north side
	_create_pipeline_system()

	# Containers for cover
	_create_containers()

	# Fuel depot area (south)
	_create_fuel_depot()

	# Small structures and barriers
	_create_barriers_and_cover()

	# Underground tunnels/passages
	_create_tunnel_entrances()

	print("[RustMap] Map generation complete!")
	map_generated.emit()


func _create_ground() -> void:
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(80, 80)

	var ground = MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = _sand_mat
	_map_container.add_child(ground)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(80, 0.1, 80)
	coll.shape = shape
	coll.position.y = -0.05
	body.add_child(coll)
	_map_container.add_child(body)


func _create_oil_tower(pos: Vector3) -> void:
	var tower = Node3D.new()
	tower.name = "OilTower"
	tower.position = pos
	_map_container.add_child(tower)

	var tower_height = 18.0
	var base_size = 4.0

	# Four corner legs
	for x in [-1, 1]:
		for z in [-1, 1]:
			var leg = _create_beam(
				Vector3(x * base_size/2, 0, z * base_size/2),
				Vector3(x * 1.0, tower_height, z * 1.0),
				0.15
			)
			tower.add_child(leg)

	# Cross bracing on each side
	for height in [3.0, 7.0, 11.0, 15.0]:
		# X braces
		for z in [-1, 1]:
			var brace1 = _create_beam(
				Vector3(-base_size/2 * (1 - height/tower_height*0.7), height, z * base_size/2 * (1 - height/tower_height*0.7)),
				Vector3(base_size/2 * (1 - (height+2)/tower_height*0.7), height + 2, z * base_size/2 * (1 - (height+2)/tower_height*0.7)),
				0.08
			)
			tower.add_child(brace1)

		# Z braces
		for x in [-1, 1]:
			var brace2 = _create_beam(
				Vector3(x * base_size/2 * (1 - height/tower_height*0.7), height, -base_size/2 * (1 - height/tower_height*0.7)),
				Vector3(x * base_size/2 * (1 - (height+2)/tower_height*0.7), height + 2, base_size/2 * (1 - (height+2)/tower_height*0.7)),
				0.08
			)
			tower.add_child(brace2)

	# Horizontal rings at different levels
	for height in [4.0, 8.0, 12.0, 16.0]:
		var ring_size = base_size * (1 - height/tower_height * 0.7)
		_create_platform_ring(tower, height, ring_size)

	# Platforms
	_create_platform(tower, 5.0, 3.0)   # Lower platform
	_create_platform(tower, 10.0, 2.5)  # Middle platform
	_create_platform(tower, 15.0, 2.0)  # Upper platform
	_create_platform(tower, 17.5, 1.5)  # Top platform

	# Ladder
	_create_ladder(tower, Vector3(1.5, 0, 0), 17.0)

	# Tower collision (simplified)
	var body = StaticBody3D.new()
	for x in [-1, 1]:
		for z in [-1, 1]:
			var coll = CollisionShape3D.new()
			var shape = CylinderShape3D.new()
			shape.radius = 0.2
			shape.height = tower_height
			coll.shape = shape
			coll.position = Vector3(x * 1.5, tower_height/2, z * 1.5)
			body.add_child(coll)
	tower.add_child(body)


func _create_beam(start: Vector3, end: Vector3, radius: float) -> MeshInstance3D:
	var direction = end - start
	var length = direction.length()
	var center = (start + end) / 2

	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _rust_mat
	inst.position = center

	# Rotate to align with direction
	if direction.normalized() != Vector3.UP and direction.normalized() != Vector3.DOWN:
		inst.look_at(inst.position + direction, Vector3.UP)
		inst.rotate_object_local(Vector3.RIGHT, PI/2)

	return inst


func _create_platform_ring(parent: Node3D, height: float, size: float) -> void:
	var half = size / 2
	var corners = [
		Vector3(-half, height, -half),
		Vector3(half, height, -half),
		Vector3(half, height, half),
		Vector3(-half, height, half),
	]

	for i in range(4):
		var start = corners[i]
		var end = corners[(i + 1) % 4]
		var beam = _create_beam(start, end, 0.06)
		parent.add_child(beam)


func _create_platform(parent: Node3D, height: float, size: float) -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size, 0.15, size)

	var plat = MeshInstance3D.new()
	plat.mesh = mesh
	plat.position.y = height
	plat.material_override = _metal_mat
	parent.add_child(plat)

	# Platform collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(size, 0.15, size)
	coll.shape = shape
	coll.position.y = height
	body.add_child(coll)
	parent.add_child(body)


func _create_ladder(parent: Node3D, pos: Vector3, height: float) -> void:
	# Ladder rails
	for x_off in [-0.2, 0.2]:
		var rail_mesh = CylinderMesh.new()
		rail_mesh.top_radius = 0.03
		rail_mesh.bottom_radius = 0.03
		rail_mesh.height = height

		var rail = MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.position = pos + Vector3(x_off, height/2, 0)
		rail.material_override = _metal_mat
		parent.add_child(rail)

	# Rungs
	for h in range(0, int(height), 1):
		var rung_mesh = CylinderMesh.new()
		rung_mesh.top_radius = 0.02
		rung_mesh.bottom_radius = 0.02
		rung_mesh.height = 0.4

		var rung = MeshInstance3D.new()
		rung.mesh = rung_mesh
		rung.position = pos + Vector3(0, h + 0.5, 0)
		rung.rotation.z = PI/2
		rung.material_override = _metal_mat
		parent.add_child(rung)


func _create_oil_derrick(pos: Vector3) -> void:
	var derrick = Node3D.new()
	derrick.name = "OilDerrick"
	derrick.position = pos
	_map_container.add_child(derrick)

	# Pump base
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(3, 0.5, 2)

	var base = MeshInstance3D.new()
	base.mesh = base_mesh
	base.position.y = 0.25
	base.material_override = _concrete_mat
	derrick.add_child(base)

	# Pump body
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(1.5, 2, 1.2)

	var pump_body = MeshInstance3D.new()
	pump_body.mesh = body_mesh
	pump_body.position = Vector3(-0.5, 1.5, 0)
	pump_body.material_override = _rust_mat
	derrick.add_child(pump_body)

	# Walking beam (the bobbing arm)
	var beam_mesh = BoxMesh.new()
	beam_mesh.size = Vector3(5, 0.3, 0.4)

	var beam = MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.position = Vector3(1, 3, 0)
	beam.rotation.z = -0.15  # Slight tilt
	beam.material_override = _rust_mat
	derrick.add_child(beam)

	# Horse head (the curved end)
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(0.8, 1.2, 0.4)

	var head = MeshInstance3D.new()
	head.mesh = head_mesh
	head.position = Vector3(3.2, 2.5, 0)
	head.material_override = _rust_mat
	derrick.add_child(head)

	# Support A-frame
	for x_off in [-0.4, 0.4]:
		var support = _create_beam(
			Vector3(-0.5 + x_off, 0.5, 0),
			Vector3(-0.5, 3.5, 0),
			0.1
		)
		derrick.add_child(support)

	# Collision
	var coll_body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6, 4, 2)
	coll.shape = shape
	coll.position = Vector3(0.5, 2, 0)
	coll_body.add_child(coll)
	derrick.add_child(coll_body)


func _create_pipeline_system() -> void:
	# Main elevated pipeline along north side
	var pipe_height = 3.5

	# Long horizontal pipe
	_create_pipe(Vector3(-25, pipe_height, -20), Vector3(25, pipe_height, -20), 0.6)

	# Connecting pipes to tower
	_create_pipe(Vector3(0, pipe_height, -20), Vector3(0, 8, -5), 0.5)

	# Pipe to derrick
	_create_pipe(Vector3(-18, pipe_height, -20), Vector3(-18, 2, -15), 0.4)

	# Support pillars for elevated pipe
	for x in [-20, -10, 0, 10, 20]:
		_create_pipe_support(Vector3(x, 0, -20), pipe_height)


func _create_pipe(start: Vector3, end: Vector3, radius: float) -> void:
	var direction = end - start
	var length = direction.length()
	var center = (start + end) / 2

	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _pipe_mat
	inst.position = center

	if direction.normalized() != Vector3.UP and direction.normalized() != Vector3.DOWN:
		inst.look_at(inst.position + direction, Vector3.UP)
		inst.rotate_object_local(Vector3.RIGHT, PI/2)

	_map_container.add_child(inst)

	# Pipe collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = length
	coll.shape = shape
	coll.position = center
	if direction.normalized() != Vector3.UP:
		coll.rotation = inst.rotation
	body.add_child(coll)
	_map_container.add_child(body)


func _create_pipe_support(pos: Vector3, height: float) -> void:
	# Vertical support beam
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.2
	mesh.height = height

	var support = MeshInstance3D.new()
	support.mesh = mesh
	support.position = pos + Vector3(0, height/2, 0)
	support.material_override = _rust_mat
	_map_container.add_child(support)


func _create_containers() -> void:
	# Shipping containers for cover - positioned around the map
	var container_positions = [
		# East side
		{"pos": Vector3(20, 0, 5), "rot": 0.0},
		{"pos": Vector3(22, 0, -5), "rot": 0.2},
		{"pos": Vector3(18, 2.5, 5), "rot": 0.0},  # Stacked

		# West side
		{"pos": Vector3(-22, 0, 8), "rot": -0.1},
		{"pos": Vector3(-20, 0, -8), "rot": 0.3},

		# South corners
		{"pos": Vector3(15, 0, 18), "rot": 0.5},
		{"pos": Vector3(-15, 0, 20), "rot": -0.4},

		# Near tower
		{"pos": Vector3(8, 0, 5), "rot": 0.8},
		{"pos": Vector3(-8, 0, -6), "rot": 0.0},
	]

	for data in container_positions:
		_create_container(data.pos, data.rot)


func _create_container(pos: Vector3, rotation_y: float) -> void:
	var container = Node3D.new()
	container.position = pos
	container.rotation.y = rotation_y
	_map_container.add_child(container)

	# Container body
	var mesh = BoxMesh.new()
	mesh.size = Vector3(6, 2.5, 2.4)

	var body_mesh = MeshInstance3D.new()
	body_mesh.mesh = mesh
	body_mesh.position.y = 1.25
	body_mesh.material_override = _container_mats[randi() % _container_mats.size()]
	container.add_child(body_mesh)

	# Container ridges (for detail)
	for i in range(-2, 3):
		var ridge_mesh = BoxMesh.new()
		ridge_mesh.size = Vector3(0.08, 2.3, 2.5)

		var ridge = MeshInstance3D.new()
		ridge.mesh = ridge_mesh
		ridge.position = Vector3(i * 1.2, 1.25, 0)
		ridge.material_override = _metal_mat
		container.add_child(ridge)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6, 2.5, 2.4)
	coll.shape = shape
	coll.position.y = 1.25
	body.add_child(coll)
	container.add_child(body)


func _create_fuel_depot() -> void:
	# South area with fuel tanks and barriers
	var depot = Node3D.new()
	depot.name = "FuelDepot"
	depot.position = Vector3(0, 0, 22)
	_map_container.add_child(depot)

	# Fuel tanks
	for i in range(3):
		var tank_mesh = CylinderMesh.new()
		tank_mesh.top_radius = 1.5
		tank_mesh.bottom_radius = 1.5
		tank_mesh.height = 3.5

		var tank = MeshInstance3D.new()
		tank.mesh = tank_mesh
		tank.position = Vector3(-6 + i * 6, 1.75, 0)
		tank.material_override = _rust_mat
		depot.add_child(tank)

		# Tank collision
		var body = StaticBody3D.new()
		var coll = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = 1.5
		shape.height = 3.5
		coll.shape = shape
		coll.position = Vector3(-6 + i * 6, 1.75, 0)
		body.add_child(coll)
		depot.add_child(body)

	# Small building/shack
	var shack_mesh = BoxMesh.new()
	shack_mesh.size = Vector3(4, 3, 3)

	var shack = MeshInstance3D.new()
	shack.mesh = shack_mesh
	shack.position = Vector3(12, 1.5, 2)
	shack.material_override = _concrete_mat
	depot.add_child(shack)

	var shack_body = StaticBody3D.new()
	var shack_coll = CollisionShape3D.new()
	var shack_shape = BoxShape3D.new()
	shack_shape.size = Vector3(4, 3, 3)
	shack_coll.shape = shack_shape
	shack_coll.position = Vector3(12, 1.5, 2)
	shack_body.add_child(shack_coll)
	depot.add_child(shack_body)


func _create_barriers_and_cover() -> void:
	# Jersey barriers and small cover pieces
	var barrier_positions = [
		Vector3(5, 0, 12),
		Vector3(-5, 0, 10),
		Vector3(10, 0, -10),
		Vector3(-12, 0, 5),
		Vector3(3, 0, -15),
		Vector3(-8, 0, -18),
	]

	for pos in barrier_positions:
		_create_jersey_barrier(pos, randf() * TAU)

	# Concrete blocks
	var block_positions = [
		Vector3(12, 0, 0),
		Vector3(-10, 0, 12),
		Vector3(0, 0, 8),
	]

	for pos in block_positions:
		_create_concrete_block(pos)


func _create_jersey_barrier(pos: Vector3, rot: float) -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(3.5, 0.9, 0.6)

	var barrier = MeshInstance3D.new()
	barrier.mesh = mesh
	barrier.position = pos + Vector3(0, 0.45, 0)
	barrier.rotation.y = rot
	barrier.material_override = _concrete_mat
	_map_container.add_child(barrier)

	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.5, 0.9, 0.6)
	coll.shape = shape
	coll.position = pos + Vector3(0, 0.45, 0)
	coll.rotation.y = rot
	body.add_child(coll)
	_map_container.add_child(body)


func _create_concrete_block(pos: Vector3) -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.5, 1.0, 1.5)

	var block = MeshInstance3D.new()
	block.mesh = mesh
	block.position = pos + Vector3(0, 0.5, 0)
	block.material_override = _concrete_mat
	_map_container.add_child(block)

	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 1.0, 1.5)
	coll.shape = shape
	coll.position = pos + Vector3(0, 0.5, 0)
	body.add_child(coll)
	_map_container.add_child(body)


func _create_tunnel_entrances() -> void:
	# Small tunnel/cover areas near the tower base
	var tunnel_positions = [
		Vector3(3, 0, 2),
		Vector3(-3, 0, -2),
	]

	for pos in tunnel_positions:
		var tunnel_mesh = BoxMesh.new()
		tunnel_mesh.size = Vector3(2, 1.2, 3)

		var tunnel = MeshInstance3D.new()
		tunnel.mesh = tunnel_mesh
		tunnel.position = pos + Vector3(0, 0.6, 0)
		tunnel.material_override = _concrete_mat
		_map_container.add_child(tunnel)

		var body = StaticBody3D.new()
		var coll = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(2, 1.2, 3)
		coll.shape = shape
		coll.position = pos + Vector3(0, 0.6, 0)
		body.add_child(coll)
		_map_container.add_child(body)


func clear_map() -> void:
	if _map_container:
		_map_container.queue_free()
		_map_container = null
