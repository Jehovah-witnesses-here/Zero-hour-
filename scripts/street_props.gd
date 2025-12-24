extends Node3D
## Street Props Generator - Creates lamp posts, trash cans, benches, etc.
## Adds life and detail to the environment

signal props_generated(count: int)

# Materials
var _lamp_mat: StandardMaterial3D
var _metal_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D
var _concrete_mat: StandardMaterial3D

# Props container
var _props_container: Node3D


func _ready() -> void:
	_setup_materials()
	_create_container()
	print("[StreetProps] Ready")


func _setup_materials() -> void:
	# Lamp post material (dark metal)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.15, 0.15, 0.18)
	_lamp_mat.metallic = 0.8
	_lamp_mat.roughness = 0.4
	_lamp_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Metal material (for trash cans, etc)
	_metal_mat = StandardMaterial3D.new()
	_metal_mat.albedo_color = Color(0.35, 0.38, 0.40)
	_metal_mat.metallic = 0.6
	_metal_mat.roughness = 0.5
	_metal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Wood material (for benches)
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = Color(0.4, 0.28, 0.18)
	_wood_mat.roughness = 0.8
	_wood_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Concrete material (for barriers, etc)
	_concrete_mat = StandardMaterial3D.new()
	_concrete_mat.albedo_color = Color(0.5, 0.48, 0.45)
	_concrete_mat.roughness = 0.95
	_concrete_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _create_container() -> void:
	_props_container = Node3D.new()
	_props_container.name = "StreetProps"
	add_child(_props_container)


func generate_props_around_buildings(buildings: Array) -> void:
	print("[StreetProps] Generating props for ", buildings.size(), " buildings...")

	# Clear old props
	for child in _props_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	var prop_count = 0

	for building_data in buildings:
		var polygon = building_data.get("polygon", [])
		if polygon.size() < 2:
			continue

		# Get building corners in world coords
		var base_lat = 51.5074
		var base_lon = -0.1278
		var meters_per_deg = 111000.0

		for i in range(polygon.size()):
			var point = polygon[i]
			var lat = point.get("lat", base_lat)
			var lon = point.get("lon", base_lon)
			var x = (lon - base_lon) * meters_per_deg
			var z = -(lat - base_lat) * meters_per_deg

			# 30% chance to place a prop near each corner
			if randf() < 0.3:
				var offset_x = (randf() - 0.5) * 4.0 + (3.0 if randf() > 0.5 else -3.0)
				var offset_z = (randf() - 0.5) * 4.0 + (3.0 if randf() > 0.5 else -3.0)
				var prop_pos = Vector3(x + offset_x, 0, z + offset_z)

				# Random prop type
				var prop_type = randi() % 4
				var prop: Node3D = null

				match prop_type:
					0:
						prop = _create_lamp_post(prop_pos)
					1:
						prop = _create_trash_can(prop_pos)
					2:
						prop = _create_bench(prop_pos)
					3:
						prop = _create_fire_hydrant(prop_pos)

				if prop:
					_props_container.add_child(prop)
					prop_count += 1

	# Add some street lamps along imaginary roads
	for i in range(20):
		var x = (randf() - 0.5) * 200.0
		var z = (randf() - 0.5) * 200.0
		var lamp = _create_lamp_post(Vector3(x, 0, z))
		_props_container.add_child(lamp)
		prop_count += 1

	print("[StreetProps] Created ", prop_count, " props")
	props_generated.emit(prop_count)


func generate_demo_props() -> void:
	"""Generate props for demo town layout"""
	print("[StreetProps] Generating demo props...")

	# Clear old props
	for child in _props_container.get_children():
		child.queue_free()

	var prop_count = 0

	# Street lamps along roads
	var lamp_positions = [
		Vector3(-25, 0, 0), Vector3(-25, 0, 30), Vector3(-25, 0, 60),
		Vector3(25, 0, 0), Vector3(25, 0, 30), Vector3(25, 0, 60),
		Vector3(-25, 0, -30), Vector3(25, 0, -30),
		Vector3(0, 0, 40), Vector3(50, 0, 40),
	]

	for pos in lamp_positions:
		var lamp = _create_lamp_post(pos)
		_props_container.add_child(lamp)
		prop_count += 1

	# Trash cans near buildings
	var trash_positions = [
		Vector3(-18, 0, 12), Vector3(32, 0, 15), Vector3(-45, 0, 45),
		Vector3(55, 0, 55), Vector3(10, 0, -25),
	]

	for pos in trash_positions:
		var trash = _create_trash_can(pos)
		_props_container.add_child(trash)
		prop_count += 1

	# Benches
	var bench_positions = [
		Vector3(0, 0, 10), Vector3(-30, 0, -10), Vector3(40, 0, 30),
	]

	for pos in bench_positions:
		var bench = _create_bench(pos)
		_props_container.add_child(bench)
		prop_count += 1

	# Fire hydrants
	var hydrant_positions = [
		Vector3(-22, 0, 5), Vector3(22, 0, 35), Vector3(-40, 0, 60),
	]

	for pos in hydrant_positions:
		var hydrant = _create_fire_hydrant(pos)
		_props_container.add_child(hydrant)
		prop_count += 1

	# Random debris/barriers
	for i in range(5):
		var x = (randf() - 0.5) * 100.0
		var z = (randf() - 0.5) * 100.0
		var barrier = _create_barrier(Vector3(x, 0, z))
		_props_container.add_child(barrier)
		prop_count += 1

	print("[StreetProps] Created ", prop_count, " demo props")
	props_generated.emit(prop_count)


func _create_lamp_post(pos: Vector3) -> Node3D:
	var lamp = Node3D.new()
	lamp.name = "LampPost"
	lamp.position = pos

	# Pole
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.12
	pole_mesh.height = 5.0

	var pole = MeshInstance3D.new()
	pole.mesh = pole_mesh
	pole.position.y = 2.5
	pole.material_override = _lamp_mat
	lamp.add_child(pole)

	# Arm
	var arm_mesh = BoxMesh.new()
	arm_mesh.size = Vector3(1.2, 0.1, 0.1)

	var arm = MeshInstance3D.new()
	arm.mesh = arm_mesh
	arm.position = Vector3(0.5, 4.8, 0)
	arm.material_override = _lamp_mat
	lamp.add_child(arm)

	# Light housing
	var housing_mesh = BoxMesh.new()
	housing_mesh.size = Vector3(0.4, 0.15, 0.25)

	var housing = MeshInstance3D.new()
	housing.mesh = housing_mesh
	housing.position = Vector3(1.0, 4.65, 0)
	housing.material_override = _metal_mat
	lamp.add_child(housing)

	# Light source (subtle)
	var light = OmniLight3D.new()
	light.position = Vector3(1.0, 4.5, 0)
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 0.3
	light.omni_range = 8.0
	light.shadow_enabled = false  # Performance
	lamp.add_child(light)

	# Base
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.2
	base_mesh.bottom_radius = 0.25
	base_mesh.height = 0.3

	var base = MeshInstance3D.new()
	base.mesh = base_mesh
	base.position.y = 0.15
	base.material_override = _concrete_mat
	lamp.add_child(base)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.15
	shape.height = 5.0
	coll.shape = shape
	coll.position.y = 2.5
	body.add_child(coll)
	lamp.add_child(body)

	return lamp


func _create_trash_can(pos: Vector3) -> Node3D:
	var trash = Node3D.new()
	trash.name = "TrashCan"
	trash.position = pos

	# Main can body
	var can_mesh = CylinderMesh.new()
	can_mesh.top_radius = 0.35
	can_mesh.bottom_radius = 0.30
	can_mesh.height = 0.9

	var can = MeshInstance3D.new()
	can.mesh = can_mesh
	can.position.y = 0.45
	can.material_override = _metal_mat
	trash.add_child(can)

	# Lid
	var lid_mesh = CylinderMesh.new()
	lid_mesh.top_radius = 0.38
	lid_mesh.bottom_radius = 0.38
	lid_mesh.height = 0.08

	var lid = MeshInstance3D.new()
	lid.mesh = lid_mesh
	lid.position.y = 0.94
	lid.material_override = _metal_mat
	trash.add_child(lid)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 1.0
	coll.shape = shape
	coll.position.y = 0.5
	body.add_child(coll)
	trash.add_child(body)

	return trash


func _create_bench(pos: Vector3) -> Node3D:
	var bench = Node3D.new()
	bench.name = "Bench"
	bench.position = pos
	bench.rotation.y = randf() * TAU  # Random rotation

	# Seat
	var seat_mesh = BoxMesh.new()
	seat_mesh.size = Vector3(1.5, 0.08, 0.45)

	var seat = MeshInstance3D.new()
	seat.mesh = seat_mesh
	seat.position.y = 0.45
	seat.material_override = _wood_mat
	bench.add_child(seat)

	# Back
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(1.5, 0.5, 0.06)

	var back = MeshInstance3D.new()
	back.mesh = back_mesh
	back.position = Vector3(0, 0.75, -0.2)
	back.rotation.x = -0.15
	back.material_override = _wood_mat
	bench.add_child(back)

	# Legs (metal)
	var leg_mesh = BoxMesh.new()
	leg_mesh.size = Vector3(0.06, 0.45, 0.35)

	for x_offset in [-0.6, 0.6]:
		var leg = MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.position = Vector3(x_offset, 0.225, 0)
		leg.material_override = _lamp_mat
		bench.add_child(leg)

	# Armrests
	var arm_mesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.06, 0.06, 0.35)

	for x_offset in [-0.7, 0.7]:
		var arm = MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.position = Vector3(x_offset, 0.52, 0)
		arm.material_override = _lamp_mat
		bench.add_child(arm)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.6, 1.0, 0.5)
	coll.shape = shape
	coll.position.y = 0.5
	body.add_child(coll)
	bench.add_child(body)

	return bench


func _create_fire_hydrant(pos: Vector3) -> Node3D:
	var hydrant = Node3D.new()
	hydrant.name = "FireHydrant"
	hydrant.position = pos

	# Red material
	var red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(0.7, 0.15, 0.1)
	red_mat.roughness = 0.6
	red_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Main body
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.15
	body_mesh.bottom_radius = 0.18
	body_mesh.height = 0.6

	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh
	body_inst.position.y = 0.3
	body_inst.material_override = red_mat
	hydrant.add_child(body_inst)

	# Top cap
	var cap_mesh = SphereMesh.new()
	cap_mesh.radius = 0.12
	cap_mesh.height = 0.2

	var cap = MeshInstance3D.new()
	cap.mesh = cap_mesh
	cap.position.y = 0.65
	cap.material_override = red_mat
	hydrant.add_child(cap)

	# Side nozzles
	var nozzle_mesh = CylinderMesh.new()
	nozzle_mesh.top_radius = 0.05
	nozzle_mesh.bottom_radius = 0.06
	nozzle_mesh.height = 0.15

	for angle in [0.0, PI]:
		var nozzle = MeshInstance3D.new()
		nozzle.mesh = nozzle_mesh
		nozzle.position = Vector3(sin(angle) * 0.18, 0.45, cos(angle) * 0.18)
		nozzle.rotation.z = PI / 2.0 * sign(sin(angle) + 0.01)
		nozzle.material_override = red_mat
		hydrant.add_child(nozzle)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.2
	shape.height = 0.7
	coll.shape = shape
	coll.position.y = 0.35
	body.add_child(coll)
	hydrant.add_child(body)

	return hydrant


func _create_barrier(pos: Vector3) -> Node3D:
	var barrier = Node3D.new()
	barrier.name = "Barrier"
	barrier.position = pos
	barrier.rotation.y = randf() * TAU

	# Jersey barrier style
	var barrier_mesh = BoxMesh.new()
	barrier_mesh.size = Vector3(2.0, 0.8, 0.5)

	var barrier_inst = MeshInstance3D.new()
	barrier_inst.mesh = barrier_mesh
	barrier_inst.position.y = 0.4
	barrier_inst.material_override = _concrete_mat
	barrier.add_child(barrier_inst)

	# Collision
	var body = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 0.8, 0.5)
	coll.shape = shape
	coll.position.y = 0.4
	body.add_child(coll)
	barrier.add_child(body)

	return barrier


func clear_props() -> void:
	for child in _props_container.get_children():
		child.queue_free()
