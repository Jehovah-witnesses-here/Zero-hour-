extends Node3D
## Rust Map Generator - Accurate MW2 oil yard recreation
## Based on actual Call of Duty: Modern Warfare 2 Rust layout

signal map_generated

# Materials
var _metal_dark: StandardMaterial3D
var _metal_rust: StandardMaterial3D
var _metal_light: StandardMaterial3D
var _concrete: StandardMaterial3D
var _sand: StandardMaterial3D
var _pipe_orange: StandardMaterial3D
var _container_red: StandardMaterial3D
var _container_blue: StandardMaterial3D
var _container_green: StandardMaterial3D
var _generator_gray: StandardMaterial3D
var _wall_rust: StandardMaterial3D

var _map: Node3D


func _ready() -> void:
	_setup_materials()
	print("[RustMap] Ready - MW2 Rust recreation")


func _setup_materials() -> void:
	# Dark metal (tower frame)
	_metal_dark = StandardMaterial3D.new()
	_metal_dark.albedo_color = Color(0.25, 0.23, 0.22)
	_metal_dark.metallic = 0.7
	_metal_dark.roughness = 0.6
	_metal_dark.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Rusty metal
	_metal_rust = StandardMaterial3D.new()
	_metal_rust.albedo_color = Color(0.5, 0.32, 0.2)
	_metal_rust.metallic = 0.5
	_metal_rust.roughness = 0.8
	_metal_rust.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Light metal (pipes)
	_metal_light = StandardMaterial3D.new()
	_metal_light.albedo_color = Color(0.6, 0.58, 0.55)
	_metal_light.metallic = 0.6
	_metal_light.roughness = 0.5
	_metal_light.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Orange/yellow pipe
	_pipe_orange = StandardMaterial3D.new()
	_pipe_orange.albedo_color = Color(0.8, 0.5, 0.15)
	_pipe_orange.metallic = 0.4
	_metal_rust.roughness = 0.6
	_pipe_orange.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Concrete
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.55, 0.52, 0.48)
	_concrete.roughness = 0.95
	_concrete.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Sand ground
	_sand = StandardMaterial3D.new()
	_sand.albedo_color = Color(0.78, 0.68, 0.48)
	_sand.roughness = 1.0

	# Containers
	_container_red = StandardMaterial3D.new()
	_container_red.albedo_color = Color(0.6, 0.18, 0.12)
	_container_red.metallic = 0.3
	_container_red.roughness = 0.7
	_container_red.cull_mode = BaseMaterial3D.CULL_DISABLED

	_container_blue = StandardMaterial3D.new()
	_container_blue.albedo_color = Color(0.15, 0.25, 0.45)
	_container_blue.metallic = 0.3
	_container_blue.roughness = 0.7
	_container_blue.cull_mode = BaseMaterial3D.CULL_DISABLED

	_container_green = StandardMaterial3D.new()
	_container_green.albedo_color = Color(0.2, 0.35, 0.2)
	_container_green.metallic = 0.3
	_container_green.roughness = 0.7
	_container_green.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Generator gray
	_generator_gray = StandardMaterial3D.new()
	_generator_gray.albedo_color = Color(0.4, 0.42, 0.45)
	_generator_gray.metallic = 0.5
	_generator_gray.roughness = 0.6
	_generator_gray.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Rusty wall
	_wall_rust = StandardMaterial3D.new()
	_wall_rust.albedo_color = Color(0.55, 0.28, 0.18)
	_wall_rust.roughness = 0.9
	_wall_rust.cull_mode = BaseMaterial3D.CULL_DISABLED


func generate_map() -> void:
	print("[RustMap] Generating accurate Rust layout...")

	if _map:
		_map.queue_free()
		await get_tree().process_frame

	_map = Node3D.new()
	_map.name = "RustArena"
	add_child(_map)

	# Desert ground
	_create_ground()

	# === CENTRAL TOWER (the iconic centerpiece) ===
	_create_tower(Vector3(0, 0, 0))

	# === CONTROL ROOM (small building SE of tower) ===
	_create_control_room(Vector3(8, 0, 6))

	# === GENERATORS (around tower) ===
	_create_generators()

	# === PIPELINE (elevated north side) ===
	_create_pipeline()

	# === OIL DERRICK (northwest corner) ===
	_create_oil_derrick(Vector3(-18, 0, -16))

	# === LOADING DOCK (containers east side) ===
	_create_loading_dock()

	# === FUEL DEPOT (south) ===
	_create_fuel_area()

	# === MAINTENANCE AREA ===
	_create_maintenance()

	# === PERIMETER WALLS ===
	_create_perimeter()

	# === TOWER BASE MAZE (crawl spaces) ===
	_create_tower_maze()

	print("[RustMap] Map complete - 12 zones created")
	map_generated.emit()


func _create_ground() -> void:
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(70, 70)

	var ground = MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = _sand
	_map.add_child(ground)

	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(70, 0.1, 70)
	coll.shape = shape
	coll.position.y = -0.05
	body.add_child(coll)
	_map.add_child(body)


func _create_tower(pos: Vector3) -> void:
	var tower = Node3D.new()
	tower.name = "Tower"
	tower.position = pos
	_map.add_child(tower)

	# Tower is a SOLID industrial structure with corrugated metal walls
	# NOT an open lattice - it's a boxy structure with platforms inside
	var height = 14.0
	var width = 6.0
	var depth = 6.0

	# === MAIN STRUCTURE (corrugated metal walls) ===
	# Back wall (solid)
	_add_corrugated_wall(tower, Vector3(0, height/2, -depth/2), width, height, 0)
	# Left wall (solid)
	_add_corrugated_wall(tower, Vector3(-width/2, height/2, 0), depth, height, PI/2)
	# Right wall (partial - has opening)
	_add_corrugated_wall(tower, Vector3(width/2, height/2 + 2, 0), depth, height - 4, PI/2)
	# Front wall (partial - ground level open)
	_add_corrugated_wall(tower, Vector3(0, height/2 + 3, depth/2), width, height - 6, 0)

	# Corner posts (structural beams)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_add_vertical_beam(tower, Vector3(x * width/2, 0, z * depth/2), height, 0.15)

	# === WALKABLE PLATFORMS ===
	# Ground level floor
	_add_solid_platform(tower, 0.1, width - 0.5, depth - 0.5)

	# First platform (4m up)
	_add_solid_platform(tower, 4.0, width - 0.3, depth - 0.3)

	# Second platform (8m up)
	_add_solid_platform(tower, 8.0, width - 0.3, depth - 0.3)

	# Top platform (at top)
	_add_solid_platform(tower, height - 0.5, width + 1.0, depth + 1.0)

	# === DUST CHUTE (large diagonal walkable tube) ===
	# This is the iconic climbable chute on the outside
	_create_dust_chute(tower, width, depth, height)

	# === INTERNAL RAMPS between platforms ===
	_add_ramp(tower, Vector3(-2, 0.1, 0), Vector3(-2, 4.0, -2), 1.2)
	_add_ramp(tower, Vector3(2, 4.0, 0), Vector3(2, 8.0, 2), 1.2)

	# === LADDER (backup way up) ===
	_add_ladder(tower, Vector3(-width/2 + 0.3, 0, 0), height - 1)

	# === TOP RAILING ===
	_add_top_railing(tower, height - 0.5, width + 1.0, depth + 1.0)

	# Main collision for walls
	_add_tower_walls_collision(tower, width, depth, height)


func _add_corrugated_wall(parent: Node3D, pos: Vector3, width: float, height: float, rot_y: float) -> void:
	var wall = Node3D.new()
	wall.position = pos
	wall.rotation.y = rot_y
	parent.add_child(wall)

	# Main wall panel
	var mesh = BoxMesh.new()
	mesh.size = Vector3(width, height, 0.15)

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _metal_rust
	wall.add_child(inst)

	# Corrugation ridges (vertical lines)
	var num_ridges = int(width / 0.5)
	for i in range(num_ridges):
		var ridge_mesh = BoxMesh.new()
		ridge_mesh.size = Vector3(0.08, height, 0.05)

		var ridge = MeshInstance3D.new()
		ridge.mesh = ridge_mesh
		ridge.position.x = -width/2 + 0.25 + i * 0.5
		ridge.position.z = 0.1
		ridge.material_override = _metal_dark
		wall.add_child(ridge)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(width, height, 0.2)
	coll.shape = shape
	body.add_child(coll)
	wall.add_child(body)


func _add_vertical_beam(parent: Node3D, pos: Vector3, height: float, radius: float) -> void:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos + Vector3(0, height/2, 0)
	inst.material_override = _metal_dark
	parent.add_child(inst)


func _add_solid_platform(parent: Node3D, height: float, width: float, depth: float) -> void:
	# Solid metal grating floor
	var mesh = BoxMesh.new()
	mesh.size = Vector3(width, 0.15, depth)

	var plat = MeshInstance3D.new()
	plat.mesh = mesh
	plat.position.y = height
	plat.material_override = _metal_light
	parent.add_child(plat)

	# Grating lines for detail
	for i in range(-int(depth/2), int(depth/2) + 1):
		var line_mesh = BoxMesh.new()
		line_mesh.size = Vector3(width, 0.02, 0.04)

		var line = MeshInstance3D.new()
		line.mesh = line_mesh
		line.position = Vector3(0, height + 0.08, i * 0.5)
		line.material_override = _metal_dark
		parent.add_child(line)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(width, 0.2, depth)
	coll.shape = shape
	coll.position.y = height
	body.add_child(coll)
	parent.add_child(body)


func _create_dust_chute(parent: Node3D, tower_w: float, tower_d: float, tower_h: float) -> void:
	# The dust chute is a large diagonal enclosed walkway/pipe
	# Goes from ground level on one side up to the second platform
	var chute = Node3D.new()
	chute.name = "DustChute"
	parent.add_child(chute)

	var start_pos = Vector3(tower_w/2 + 1.5, 0.5, 0)
	var end_pos = Vector3(tower_w/2 + 0.5, 8.0, 0)
	var chute_length = start_pos.distance_to(end_pos)
	var chute_width = 1.8
	var chute_height = 2.0

	# Chute floor (walkable ramp)
	var floor_mesh = BoxMesh.new()
	floor_mesh.size = Vector3(chute_width, 0.15, chute_length)

	var floor_inst = MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = _metal_light

	# Position and rotate the chute
	var center = (start_pos + end_pos) / 2
	floor_inst.position = center
	var angle = atan2(end_pos.y - start_pos.y, end_pos.distance_to(Vector3(start_pos.x, end_pos.y, start_pos.z)))
	floor_inst.rotation.x = -angle
	chute.add_child(floor_inst)

	# Chute walls (left and right)
	for side in [-1, 1]:
		var wall_mesh = BoxMesh.new()
		wall_mesh.size = Vector3(0.1, chute_height, chute_length)

		var wall_inst = MeshInstance3D.new()
		wall_inst.mesh = wall_mesh
		wall_inst.position = center + Vector3(side * chute_width/2, chute_height/2 * cos(angle), 0)
		wall_inst.rotation.x = -angle
		wall_inst.material_override = _pipe_orange
		chute.add_child(wall_inst)

	# Chute roof
	var roof_mesh = BoxMesh.new()
	roof_mesh.size = Vector3(chute_width, 0.1, chute_length)

	var roof_inst = MeshInstance3D.new()
	roof_inst.mesh = roof_mesh
	roof_inst.position = center + Vector3(0, chute_height * cos(angle), 0)
	roof_inst.rotation.x = -angle
	roof_inst.material_override = _pipe_orange
	chute.add_child(roof_inst)

	# Floor collision (walkable)
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(chute_width, 0.2, chute_length)
	coll.shape = shape
	coll.position = center
	coll.rotation.x = -angle
	body.add_child(coll)
	chute.add_child(body)


func _add_ramp(parent: Node3D, start: Vector3, end: Vector3, width: float) -> void:
	var dir = end - start
	var length = dir.length()
	var center = (start + end) / 2

	var mesh = BoxMesh.new()
	mesh.size = Vector3(width, 0.12, length)

	var ramp = MeshInstance3D.new()
	ramp.mesh = mesh
	ramp.position = center
	ramp.material_override = _metal_light

	# Calculate rotation to align with slope
	var horizontal_dist = Vector2(end.x - start.x, end.z - start.z).length()
	var angle = atan2(end.y - start.y, horizontal_dist)
	ramp.rotation.x = -angle

	# Rotate around Y to face direction
	var y_angle = atan2(end.x - start.x, end.z - start.z)
	ramp.rotation.y = y_angle

	parent.add_child(ramp)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(width, 0.15, length)
	coll.shape = shape
	coll.position = center
	coll.rotation = ramp.rotation
	body.add_child(coll)
	parent.add_child(body)


func _add_top_railing(parent: Node3D, height: float, width: float, depth: float) -> void:
	var rail_h = 1.0
	var hw = width / 2
	var hd = depth / 2

	# Corner posts
	var corners = [
		Vector3(-hw, height, -hd),
		Vector3(hw, height, -hd),
		Vector3(hw, height, hd),
		Vector3(-hw, height, hd),
	]

	for corner in corners:
		var post_mesh = CylinderMesh.new()
		post_mesh.top_radius = 0.04
		post_mesh.bottom_radius = 0.04
		post_mesh.height = rail_h

		var post = MeshInstance3D.new()
		post.mesh = post_mesh
		post.position = corner + Vector3(0, rail_h/2, 0)
		post.material_override = _metal_light
		parent.add_child(post)

	# Top rails connecting corners
	for i in range(4):
		var start = corners[i] + Vector3(0, rail_h, 0)
		var end = corners[(i + 1) % 4] + Vector3(0, rail_h, 0)
		_add_beam(parent, start, end, 0.03, _metal_light)


func _add_tower_walls_collision(parent: Node3D, width: float, depth: float, height: float) -> void:
	var body = StaticBody3D.new()

	# Back wall collision
	var back_coll = CollisionShape3D.new()
	var back_shape = BoxShape3D.new()
	back_shape.size = Vector3(width, height, 0.2)
	back_coll.shape = back_shape
	back_coll.position = Vector3(0, height/2, -depth/2)
	body.add_child(back_coll)

	# Left wall collision
	var left_coll = CollisionShape3D.new()
	var left_shape = BoxShape3D.new()
	left_shape.size = Vector3(0.2, height, depth)
	left_coll.shape = left_shape
	left_coll.position = Vector3(-width/2, height/2, 0)
	body.add_child(left_coll)

	parent.add_child(body)


func _add_beam(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: StandardMaterial3D) -> void:
	var dir = end - start
	var length = dir.length()
	var center = (start + end) / 2

	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = center

	if dir.normalized() != Vector3.UP and dir.normalized() != Vector3.DOWN:
		inst.look_at(inst.global_position + dir, Vector3.UP)
		inst.rotate_object_local(Vector3.RIGHT, PI/2)

	parent.add_child(inst)


func _add_horizontal_ring(parent: Node3D, height: float, width: float) -> void:
	var half = width / 2
	var corners = [
		Vector3(-half, height, -half),
		Vector3(half, height, -half),
		Vector3(half, height, half),
		Vector3(-half, height, half),
	]
	for i in range(4):
		_add_beam(parent, corners[i], corners[(i+1) % 4], 0.08, _metal_dark)


func _add_cross_bracing(parent: Node3D, h1: float, h2: float, w1: float, w2: float) -> void:
	# X-brace on each of the 4 faces
	for face in range(4):
		var angle = face * PI / 2
		var cos_a = cos(angle)
		var sin_a = sin(angle)

		# Two corners at bottom
		var b1 = Vector3(cos_a * w1/2, h1, sin_a * w1/2)
		var b2 = Vector3(cos_a * w1/2 + sin_a * w1, h1, sin_a * w1/2 - cos_a * w1)
		# Fix: simpler approach - just do adjacent corners
		if face == 0:
			b1 = Vector3(-w1/2, h1, -w1/2)
			b2 = Vector3(w1/2, h1, -w1/2)
			var t1 = Vector3(-w2/2, h2, -w2/2)
			var t2 = Vector3(w2/2, h2, -w2/2)
			_add_beam(parent, b1, t2, 0.05, _metal_dark)
			_add_beam(parent, b2, t1, 0.05, _metal_dark)
		elif face == 1:
			b1 = Vector3(w1/2, h1, -w1/2)
			b2 = Vector3(w1/2, h1, w1/2)
			var t1 = Vector3(w2/2, h2, -w2/2)
			var t2 = Vector3(w2/2, h2, w2/2)
			_add_beam(parent, b1, t2, 0.05, _metal_dark)
			_add_beam(parent, b2, t1, 0.05, _metal_dark)
		elif face == 2:
			b1 = Vector3(w1/2, h1, w1/2)
			b2 = Vector3(-w1/2, h1, w1/2)
			var t1 = Vector3(w2/2, h2, w2/2)
			var t2 = Vector3(-w2/2, h2, w2/2)
			_add_beam(parent, b1, t2, 0.05, _metal_dark)
			_add_beam(parent, b2, t1, 0.05, _metal_dark)
		else:
			b1 = Vector3(-w1/2, h1, w1/2)
			b2 = Vector3(-w1/2, h1, -w1/2)
			var t1 = Vector3(-w2/2, h2, w2/2)
			var t2 = Vector3(-w2/2, h2, -w2/2)
			_add_beam(parent, b1, t2, 0.05, _metal_dark)
			_add_beam(parent, b2, t1, 0.05, _metal_dark)


func _add_platform(parent: Node3D, height: float, size: float, mat: StandardMaterial3D) -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size, 0.1, size)

	var plat = MeshInstance3D.new()
	plat.mesh = mesh
	plat.position.y = height
	plat.material_override = mat
	parent.add_child(plat)

	# Grating pattern (simple visual detail)
	for i in range(-2, 3):
		var line_mesh = BoxMesh.new()
		line_mesh.size = Vector3(size, 0.02, 0.05)
		var line = MeshInstance3D.new()
		line.mesh = line_mesh
		line.position = Vector3(0, height + 0.06, i * size/5)
		line.material_override = _metal_light
		parent.add_child(line)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(size, 0.15, size)
	coll.shape = shape
	coll.position.y = height
	body.add_child(coll)
	parent.add_child(body)


func _add_pipe(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: StandardMaterial3D) -> void:
	_add_beam(parent, start, end, radius, mat)

	# Add collision for pipe
	var dir = end - start
	var length = dir.length()
	var center = (start + end) / 2

	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = length
	coll.shape = shape
	coll.position = center

	if dir.normalized() != Vector3.UP:
		var inst = MeshInstance3D.new()  # dummy for rotation calc
		inst.position = center
		inst.look_at(inst.position + dir, Vector3.UP)
		inst.rotate_object_local(Vector3.RIGHT, PI/2)
		coll.rotation = inst.rotation

	body.add_child(coll)
	parent.add_child(body)


func _add_ladder(parent: Node3D, pos: Vector3, height: float) -> void:
	# Rails
	for x in [-0.2, 0.2]:
		var rail_mesh = CylinderMesh.new()
		rail_mesh.top_radius = 0.03
		rail_mesh.bottom_radius = 0.03
		rail_mesh.height = height

		var rail = MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.position = pos + Vector3(x, height/2, 0)
		rail.material_override = _metal_light
		parent.add_child(rail)

	# Rungs
	for h in range(1, int(height), 1):
		var rung_mesh = CylinderMesh.new()
		rung_mesh.top_radius = 0.025
		rung_mesh.bottom_radius = 0.025
		rung_mesh.height = 0.4

		var rung = MeshInstance3D.new()
		rung.mesh = rung_mesh
		rung.position = pos + Vector3(0, h, 0)
		rung.rotation.z = PI/2
		rung.material_override = _metal_light
		parent.add_child(rung)


func _add_railing(parent: Node3D, height: float, size: float) -> void:
	var rail_h = 1.0
	var half = size / 2

	# Corner posts
	for x in [-1, 1]:
		for z in [-1, 1]:
			var post_mesh = CylinderMesh.new()
			post_mesh.top_radius = 0.03
			post_mesh.bottom_radius = 0.03
			post_mesh.height = rail_h

			var post = MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = Vector3(x * half, height + rail_h/2, z * half)
			post.material_override = _metal_light
			parent.add_child(post)

	# Top rails
	var corners = [
		Vector3(-half, height + rail_h, -half),
		Vector3(half, height + rail_h, -half),
		Vector3(half, height + rail_h, half),
		Vector3(-half, height + rail_h, half),
	]
	for i in range(4):
		_add_beam(parent, corners[i], corners[(i+1) % 4], 0.025, _metal_light)


func _add_tower_collision(parent: Node3D, base_w: float, top_w: float, height: float) -> void:
	var body = StaticBody3D.new()
	for x in [-1, 1]:
		for z in [-1, 1]:
			var coll = CollisionShape3D.new()
			var shape = CapsuleShape3D.new()
			shape.radius = 0.15
			shape.height = height
			coll.shape = shape
			coll.position = Vector3(x * (base_w + top_w)/4, height/2, z * (base_w + top_w)/4)
			body.add_child(coll)
	parent.add_child(body)


func _create_control_room(pos: Vector3) -> void:
	var room = Node3D.new()
	room.name = "ControlRoom"
	room.position = pos
	_map.add_child(room)

	# Small metal shack/building
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(4, 3, 3)

	var base = MeshInstance3D.new()
	base.mesh = base_mesh
	base.position.y = 1.5
	base.material_override = _metal_rust
	room.add_child(base)

	# Roof (slightly slanted)
	var roof_mesh = BoxMesh.new()
	roof_mesh.size = Vector3(4.5, 0.2, 3.5)

	var roof = MeshInstance3D.new()
	roof.mesh = roof_mesh
	roof.position.y = 3.1
	roof.material_override = _metal_dark
	room.add_child(roof)

	# Door opening
	var door_mesh = BoxMesh.new()
	door_mesh.size = Vector3(1, 2.2, 0.1)

	var door = MeshInstance3D.new()
	door.mesh = door_mesh
	door.position = Vector3(0, 1.1, -1.55)
	door.material_override = _metal_dark
	room.add_child(door)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 3, 3)
	coll.shape = shape
	coll.position.y = 1.5
	body.add_child(coll)
	room.add_child(body)


func _create_generators() -> void:
	# Generator units around the tower
	var gen_positions = [
		Vector3(6, 0, -3),
		Vector3(-6, 0, 2),
		Vector3(4, 0, -8),
	]

	for pos in gen_positions:
		_create_generator(pos)


func _create_generator(pos: Vector3) -> void:
	var gen = Node3D.new()
	gen.name = "Generator"
	gen.position = pos
	gen.rotation.y = randf() * PI
	_map.add_child(gen)

	# Main unit body
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(2.5, 1.8, 1.5)

	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh
	body_inst.position.y = 0.9
	body_inst.material_override = _generator_gray
	gen.add_child(body_inst)

	# Top vent/exhaust
	var vent_mesh = CylinderMesh.new()
	vent_mesh.top_radius = 0.2
	vent_mesh.bottom_radius = 0.25
	vent_mesh.height = 0.5

	var vent = MeshInstance3D.new()
	vent.mesh = vent_mesh
	vent.position = Vector3(0.8, 2.05, 0)
	vent.material_override = _metal_dark
	gen.add_child(vent)

	# Collision
	var coll_body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.5, 1.8, 1.5)
	coll.shape = shape
	coll.position.y = 0.9
	coll_body.add_child(coll)
	gen.add_child(coll_body)


func _create_pipeline() -> void:
	# Elevated pipeline along north side connecting tower to oil derrick
	var pipe_h = 4.0

	# Main horizontal run
	_create_pipe_section(Vector3(-22, pipe_h, -18), Vector3(5, pipe_h, -18), 0.5)

	# Branch to tower middle platform
	_create_pipe_section(Vector3(-5, pipe_h, -18), Vector3(-2, 9, -2), 0.4)

	# Supports
	for x in [-18, -10, -2, 5]:
		_create_pipe_support(Vector3(x, 0, -18), pipe_h)


func _create_pipe_section(start: Vector3, end: Vector3, radius: float) -> void:
	var dir = end - start
	var length = dir.length()
	var center = (start + end) / 2

	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _metal_light
	inst.position = center

	if dir.normalized() != Vector3.UP and dir.normalized() != Vector3.DOWN:
		inst.look_at(inst.global_position + dir, Vector3.UP)
		inst.rotate_object_local(Vector3.RIGHT, PI/2)

	_map.add_child(inst)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = radius
	shape.height = length
	coll.shape = shape
	coll.position = center
	coll.rotation = inst.rotation
	body.add_child(coll)
	_map.add_child(body)


func _create_pipe_support(pos: Vector3, height: float) -> void:
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.2
	mesh.height = height

	var support = MeshInstance3D.new()
	support.mesh = mesh
	support.position = pos + Vector3(0, height/2, 0)
	support.material_override = _metal_rust
	_map.add_child(support)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.2
	shape.height = height
	coll.shape = shape
	coll.position = pos + Vector3(0, height/2, 0)
	body.add_child(coll)
	_map.add_child(body)


func _create_oil_derrick(pos: Vector3) -> void:
	var derrick = Node3D.new()
	derrick.name = "OilDerrick"
	derrick.position = pos
	_map.add_child(derrick)

	# Pumpjack base platform
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(5, 0.4, 3)

	var base = MeshInstance3D.new()
	base.mesh = base_mesh
	base.position.y = 0.2
	base.material_override = _concrete
	derrick.add_child(base)

	# Motor housing
	var motor_mesh = BoxMesh.new()
	motor_mesh.size = Vector3(1.5, 1.2, 1.2)

	var motor = MeshInstance3D.new()
	motor.mesh = motor_mesh
	motor.position = Vector3(-1.5, 1.0, 0)
	motor.material_override = _metal_rust
	derrick.add_child(motor)

	# Walking beam (the rocking arm)
	var beam_mesh = BoxMesh.new()
	beam_mesh.size = Vector3(4.5, 0.25, 0.3)

	var beam = MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.position = Vector3(0.5, 2.8, 0)
	beam.rotation.z = -0.1
	beam.material_override = _metal_dark
	derrick.add_child(beam)

	# Samson post (A-frame support)
	_add_beam(derrick, Vector3(-1, 0.4, -0.5), Vector3(-0.5, 3.2, 0), 0.1, _metal_dark)
	_add_beam(derrick, Vector3(-1, 0.4, 0.5), Vector3(-0.5, 3.2, 0), 0.1, _metal_dark)

	# Horsehead
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(0.6, 0.8, 0.3)

	var head = MeshInstance3D.new()
	head.mesh = head_mesh
	head.position = Vector3(2.5, 2.5, 0)
	head.material_override = _metal_dark
	derrick.add_child(head)

	# Counterweight
	var counter_mesh = BoxMesh.new()
	counter_mesh.size = Vector3(0.8, 0.6, 0.5)

	var counter = MeshInstance3D.new()
	counter.mesh = counter_mesh
	counter.position = Vector3(-1.2, 2.0, 0)
	counter.material_override = _metal_rust
	derrick.add_child(counter)

	# Raised platform for sniping
	var platform_mesh = BoxMesh.new()
	platform_mesh.size = Vector3(3, 0.15, 2)

	var platform = MeshInstance3D.new()
	platform.mesh = platform_mesh
	platform.position = Vector3(0, 3.5, -2)
	platform.material_override = _metal_dark
	derrick.add_child(platform)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(5, 4, 4)
	coll.shape = shape
	coll.position.y = 2
	body.add_child(coll)
	derrick.add_child(body)


func _create_loading_dock() -> void:
	# Shipping containers on east side
	_create_container(Vector3(18, 0, 5), 0.0, _container_red)
	_create_container(Vector3(20, 0, -3), 0.2, _container_blue)
	_create_container(Vector3(16, 2.6, 5), 0.0, _container_green)  # Stacked
	_create_container(Vector3(22, 0, 10), -0.3, _container_red)
	_create_container(Vector3(15, 0, -10), 0.5, _container_blue)


func _create_container(pos: Vector3, rot_y: float, mat: StandardMaterial3D) -> void:
	var container = Node3D.new()
	container.position = pos
	container.rotation.y = rot_y
	_map.add_child(container)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(6, 2.6, 2.4)

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position.y = 1.3
	inst.material_override = mat
	container.add_child(inst)

	# Corrugation detail
	for i in range(-2, 3):
		var ridge = BoxMesh.new()
		ridge.size = Vector3(0.05, 2.4, 2.5)

		var r = MeshInstance3D.new()
		r.mesh = ridge
		r.position = Vector3(i * 1.3, 1.3, 0)
		r.material_override = _metal_dark
		container.add_child(r)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6, 2.6, 2.4)
	coll.shape = shape
	coll.position.y = 1.3
	body.add_child(coll)
	container.add_child(body)


func _create_fuel_area() -> void:
	# Fuel tanks in south area
	for i in range(3):
		var tank = Node3D.new()
		tank.position = Vector3(-5 + i * 5, 0, 18)
		_map.add_child(tank)

		var mesh = CylinderMesh.new()
		mesh.top_radius = 1.2
		mesh.bottom_radius = 1.2
		mesh.height = 2.8

		var inst = MeshInstance3D.new()
		inst.mesh = mesh
		inst.position.y = 1.4
		inst.material_override = _metal_rust
		tank.add_child(inst)

		var body = StaticBody3D.new()
		var coll = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = 1.2
		shape.height = 2.8
		coll.shape = shape
		coll.position.y = 1.4
		body.add_child(coll)
		tank.add_child(body)


func _create_maintenance() -> void:
	# Small maintenance shed
	var shed = Node3D.new()
	shed.name = "Maintenance"
	shed.position = Vector3(-15, 0, 8)
	_map.add_child(shed)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(4, 2.5, 3)

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position.y = 1.25
	inst.material_override = _metal_rust
	shed.add_child(inst)

	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 2.5, 3)
	coll.shape = shape
	coll.position.y = 1.25
	body.add_child(coll)
	shed.add_child(body)


func _create_perimeter() -> void:
	# Rusty walls around parts of the perimeter
	_create_wall(Vector3(-25, 0, 0), 50, 3, 0.15, 0)  # West wall
	_create_wall(Vector3(0, 0, -25), 50, 3, 0.15, PI/2)  # North wall
	_create_wall(Vector3(25, 0, 0), 30, 3, 0.15, 0)  # East wall partial
	_create_wall(Vector3(0, 0, 25), 40, 3, 0.15, PI/2)  # South wall


func _create_wall(pos: Vector3, length: float, height: float, thickness: float, rot_y: float) -> void:
	var wall = Node3D.new()
	wall.position = pos
	wall.rotation.y = rot_y
	_map.add_child(wall)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(thickness, height, length)

	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position.y = height / 2
	inst.material_override = _wall_rust
	wall.add_child(inst)

	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(thickness, height, length)
	coll.shape = shape
	coll.position.y = height / 2
	body.add_child(coll)
	wall.add_child(body)


func _create_tower_maze() -> void:
	# Low walls/barriers creating crawl spaces under tower
	var barriers = [
		{"pos": Vector3(2, 0, 1.5), "size": Vector3(3, 1.2, 0.3)},
		{"pos": Vector3(-2, 0, -1.5), "size": Vector3(3, 1.2, 0.3)},
		{"pos": Vector3(1.5, 0, -2), "size": Vector3(0.3, 1.2, 2.5)},
		{"pos": Vector3(-1.5, 0, 2), "size": Vector3(0.3, 1.2, 2.5)},
	]

	for b in barriers:
		var mesh = BoxMesh.new()
		mesh.size = b.size

		var inst = MeshInstance3D.new()
		inst.mesh = mesh
		inst.position = b.pos + Vector3(0, b.size.y / 2, 0)
		inst.material_override = _concrete
		_map.add_child(inst)

		var body = StaticBody3D.new()
		var coll = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = b.size
		coll.shape = shape
		coll.position = b.pos + Vector3(0, b.size.y / 2, 0)
		body.add_child(coll)
		_map.add_child(body)


func clear_map() -> void:
	if _map:
		_map.queue_free()
		_map = null
