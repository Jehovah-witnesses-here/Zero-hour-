extends Node3D
## Building Generator - Creates detailed 3D buildings
## Now with windows, doors, varied colors, and proper detail

signal buildings_generated(count: int)
signal generation_started
signal generation_complete

# Material library - different building styles
var materials: Dictionary = {}

# Container for buildings
var _buildings_container: Node3D = null

# Building color palettes
const RESIDENTIAL_COLORS = [
	Color(0.85, 0.82, 0.75),  # Cream
	Color(0.78, 0.70, 0.60),  # Tan
	Color(0.65, 0.55, 0.50),  # Brown
	Color(0.80, 0.75, 0.70),  # Light gray
	Color(0.70, 0.72, 0.68),  # Sage
	Color(0.75, 0.65, 0.60),  # Terracotta
]

const COMMERCIAL_COLORS = [
	Color(0.55, 0.55, 0.58),  # Gray concrete
	Color(0.50, 0.48, 0.45),  # Dark concrete
	Color(0.72, 0.70, 0.68),  # Light stone
	Color(0.45, 0.42, 0.40),  # Charcoal
]

const WINDOW_COLOR = Color(0.2, 0.25, 0.35, 0.9)  # Dark blue glass
const DOOR_COLOR = Color(0.25, 0.18, 0.12)  # Dark wood
const TRIM_COLOR = Color(0.9, 0.9, 0.88)  # White trim


func _ready() -> void:
	_setup_materials()
	_create_buildings_container()
	print("[BuildingGen] Ready with detailed building generation")


func _setup_materials() -> void:
	# Window material - dark reflective
	var window_mat = StandardMaterial3D.new()
	window_mat.albedo_color = WINDOW_COLOR
	window_mat.metallic = 0.3
	window_mat.roughness = 0.1
	window_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["window"] = window_mat

	# Door material
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = DOOR_COLOR
	door_mat.roughness = 0.7
	door_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["door"] = door_mat

	# Trim material
	var trim_mat = StandardMaterial3D.new()
	trim_mat.albedo_color = TRIM_COLOR
	trim_mat.roughness = 0.6
	trim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["trim"] = trim_mat

	# Roof material
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.25, 0.22, 0.20)
	roof_mat.roughness = 0.9
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["roof"] = roof_mat

	# Ground material
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.18, 0.20, 0.15)
	ground_mat.roughness = 1.0
	materials["ground"] = ground_mat


func _create_wall_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _create_buildings_container() -> void:
	_buildings_container = Node3D.new()
	_buildings_container.name = "Buildings"
	add_child(_buildings_container)


func generate_buildings(buildings_data: Array) -> void:
	generation_started.emit()
	print("[BuildingGen] Generating ", buildings_data.size(), " detailed buildings...")

	for child in _buildings_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	var count = 0
	for data in buildings_data:
		var building = _create_detailed_building(data)
		if building:
			_buildings_container.add_child(building)
			count += 1
		if count % 3 == 0:
			await get_tree().process_frame

	print("[BuildingGen] Created ", count, " detailed buildings")
	buildings_generated.emit(count)
	generation_complete.emit()


func _create_detailed_building(data: Dictionary) -> Node3D:
	var polygon_data = data.get("polygon", [])
	if polygon_data.size() < 3:
		return null

	var height = data.get("height", 9.0)
	var building_name = str(data.get("name", "Building"))
	var building_type = data.get("building_type", "residential")
	var levels = data.get("levels", int(height / 3.0))

	# Convert coordinates
	var polygon_2d = _convert_polygon(polygon_data)
	if polygon_2d.size() < 3:
		return null

	# Fix winding order
	if _is_clockwise(polygon_2d):
		polygon_2d.reverse()

	# Choose colors based on building type
	var wall_color: Color
	if building_type == "commercial" or building_name.begins_with("The "):
		wall_color = COMMERCIAL_COLORS[randi() % COMMERCIAL_COLORS.size()]
	else:
		wall_color = RESIDENTIAL_COLORS[randi() % RESIDENTIAL_COLORS.size()]

	var wall_material = _create_wall_material(wall_color)

	# Create building node
	var building = Node3D.new()
	building.name = building_name

	# Main walls
	var walls = _create_walls_mesh(polygon_2d, height)
	if walls:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = walls
		mesh_inst.material_override = wall_material
		building.add_child(mesh_inst)

	# Add windows to each floor
	for floor_num in range(levels):
		var floor_height = floor_num * 3.0 + 1.0  # Start 1m up
		var windows = _create_windows_for_floor(polygon_2d, floor_height, 2.0)
		if windows:
			var win_inst = MeshInstance3D.new()
			win_inst.mesh = windows
			win_inst.material_override = materials["window"]
			building.add_child(win_inst)

	# Add door on ground floor
	var door = _create_door(polygon_2d, 0.0)
	if door:
		var door_inst = MeshInstance3D.new()
		door_inst.mesh = door
		door_inst.material_override = materials["door"]
		building.add_child(door_inst)

	# Add roof
	var roof = _create_roof_mesh(polygon_2d, height)
	if roof:
		var roof_inst = MeshInstance3D.new()
		roof_inst.mesh = roof
		roof_inst.material_override = materials["roof"]
		building.add_child(roof_inst)

	# Add trim at top
	var trim = _create_trim(polygon_2d, height)
	if trim:
		var trim_inst = MeshInstance3D.new()
		trim_inst.mesh = trim
		trim_inst.material_override = materials["trim"]
		building.add_child(trim_inst)

	# Collision
	var collision = _create_collision(polygon_2d, height)
	if collision:
		building.add_child(collision)

	return building


func _convert_polygon(polygon_data: Array) -> PackedVector2Array:
	var result = PackedVector2Array()
	var base_lat = 51.5074
	var base_lon = -0.1278
	var meters_per_deg = 111000.0

	for point in polygon_data:
		var lat = point.get("lat", base_lat)
		var lon = point.get("lon", base_lon)
		var x = (lon - base_lon) * meters_per_deg
		var z = -(lat - base_lat) * meters_per_deg
		result.append(Vector2(x, z))

	return result


func _is_clockwise(polygon: PackedVector2Array) -> bool:
	var sum = 0.0
	for i in range(polygon.size()):
		var current = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]
		sum += (next.x - current.x) * (next.y + current.y)
	return sum > 0


func _create_walls_mesh(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(polygon.size()):
		var curr = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]

		var p0 = Vector3(curr.x, 0, curr.y)
		var p1 = Vector3(next.x, 0, next.y)
		var p2 = Vector3(next.x, height, next.y)
		var p3 = Vector3(curr.x, height, curr.y)

		var edge = p1 - p0
		var normal = Vector3(edge.z, 0, -edge.x).normalized()

		# Wall quad
		st.set_normal(normal)
		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)

		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
		st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

	return st.commit()


func _create_windows_for_floor(polygon: PackedVector2Array, floor_y: float, window_height: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var window_width = 1.2
	var window_spacing = 2.5
	var inset = 0.05  # How much windows are inset from wall

	for i in range(polygon.size()):
		var curr = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]

		var wall_vec = next - curr
		var wall_length = wall_vec.length()
		var wall_dir = wall_vec.normalized()

		# Calculate normal (pointing outward, then inset slightly)
		var normal_2d = Vector2(wall_dir.y, -wall_dir.x)
		var offset = normal_2d * inset

		# How many windows fit on this wall
		var num_windows = int((wall_length - 1.0) / window_spacing)
		if num_windows < 1:
			continue

		var start_offset = (wall_length - (num_windows - 1) * window_spacing) / 2.0

		for w in range(num_windows):
			var pos_along = start_offset + w * window_spacing
			var center_2d = curr + wall_dir * pos_along + offset

			var half_w = window_width / 2.0
			var left_2d = center_2d - wall_dir * half_w
			var right_2d = center_2d + wall_dir * half_w

			var p0 = Vector3(left_2d.x, floor_y, left_2d.y)
			var p1 = Vector3(right_2d.x, floor_y, right_2d.y)
			var p2 = Vector3(right_2d.x, floor_y + window_height, right_2d.y)
			var p3 = Vector3(left_2d.x, floor_y + window_height, left_2d.y)

			var normal = Vector3(normal_2d.x, 0, normal_2d.y)

			st.set_normal(normal)
			st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
			st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
			st.set_uv(Vector2(1, 0)); st.add_vertex(p2)

			st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
			st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
			st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

	return st.commit()


func _create_door(polygon: PackedVector2Array, floor_y: float) -> ArrayMesh:
	if polygon.size() < 2:
		return null

	# Put door on first wall segment
	var curr = polygon[0]
	var next = polygon[1]

	var wall_vec = next - curr
	var wall_length = wall_vec.length()
	var wall_dir = wall_vec.normalized()
	var normal_2d = Vector2(wall_dir.y, -wall_dir.x)
	var offset = normal_2d * 0.02

	# Door dimensions
	var door_width = 1.0
	var door_height = 2.2

	# Center door on wall
	var center_2d = curr + wall_dir * (wall_length / 2.0) + offset
	var left_2d = center_2d - wall_dir * (door_width / 2.0)
	var right_2d = center_2d + wall_dir * (door_width / 2.0)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var p0 = Vector3(left_2d.x, floor_y, left_2d.y)
	var p1 = Vector3(right_2d.x, floor_y, right_2d.y)
	var p2 = Vector3(right_2d.x, floor_y + door_height, right_2d.y)
	var p3 = Vector3(left_2d.x, floor_y + door_height, left_2d.y)

	var normal = Vector3(normal_2d.x, 0, normal_2d.y)

	st.set_normal(normal)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p2)

	st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

	return st.commit()


func _create_trim(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var trim_height = 0.3
	var trim_depth = 0.1

	for i in range(polygon.size()):
		var curr = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]

		var wall_dir = (next - curr).normalized()
		var normal_2d = Vector2(wall_dir.y, -wall_dir.x)

		# Outer edge of trim
		var curr_out = curr + normal_2d * trim_depth
		var next_out = next + normal_2d * trim_depth

		# Front face of trim
		var p0 = Vector3(curr_out.x, height, curr_out.y)
		var p1 = Vector3(next_out.x, height, next_out.y)
		var p2 = Vector3(next_out.x, height + trim_height, next_out.y)
		var p3 = Vector3(curr_out.x, height + trim_height, curr_out.y)

		var normal = Vector3(normal_2d.x, 0, normal_2d.y)

		st.set_normal(normal)
		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)

		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
		st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

	return st.commit()


func _create_roof_mesh(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var indices = Geometry2D.triangulate_polygon(polygon)
	if indices.size() == 0:
		if polygon.size() == 4:
			indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
		else:
			return null

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for idx in indices:
		var point = polygon[idx]
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(point.x * 0.1, point.y * 0.1))
		st.add_vertex(Vector3(point.x, height, point.y))

	return st.commit()


func _create_collision(polygon: PackedVector2Array, height: float) -> StaticBody3D:
	var body = StaticBody3D.new()
	var points = PackedVector3Array()

	for point in polygon:
		points.append(Vector3(point.x, 0, point.y))
		points.append(Vector3(point.x, height, point.y))

	var shape = ConvexPolygonShape3D.new()
	shape.points = points

	var coll = CollisionShape3D.new()
	coll.shape = shape
	body.add_child(coll)

	return body


func create_ground(size: float = 500.0) -> void:
	var old = get_node_or_null("Ground")
	if old:
		old.queue_free()

	# Create textured ground
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh.subdivide_width = 10
	mesh.subdivide_depth = 10

	var inst = MeshInstance3D.new()
	inst.name = "Ground"
	inst.mesh = mesh
	inst.material_override = materials["ground"]
	add_child(inst)

	# Collision
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(size, 0.1, size)
	shape.shape = box
	shape.position.y = -0.05
	body.add_child(shape)
	add_child(body)


func clear_buildings() -> void:
	for child in _buildings_container.get_children():
		child.queue_free()


func get_building_count() -> int:
	return _buildings_container.get_child_count()
