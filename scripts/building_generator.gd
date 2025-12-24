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

const WINDOW_COLOR = Color(0.15, 0.2, 0.3, 0.95)  # Dark blue glass
const WINDOW_FRAME_COLOR = Color(0.85, 0.85, 0.82)  # White window frames
const DOOR_COLOR = Color(0.3, 0.2, 0.12)  # Dark wood
const DOOR_FRAME_COLOR = Color(0.8, 0.78, 0.75)  # Light door frame
const TRIM_COLOR = Color(0.92, 0.92, 0.9)  # White trim
const FOUNDATION_COLOR = Color(0.4, 0.38, 0.35)  # Dark foundation


func _ready() -> void:
	_setup_materials()
	_create_buildings_container()
	print("[BuildingGen] Ready with detailed building generation")


func _setup_materials() -> void:
	# Window material - dark reflective glass
	var window_mat = StandardMaterial3D.new()
	window_mat.albedo_color = WINDOW_COLOR
	window_mat.metallic = 0.4
	window_mat.roughness = 0.05
	window_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["window"] = window_mat

	# Window frame material
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = WINDOW_FRAME_COLOR
	frame_mat.roughness = 0.7
	frame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["window_frame"] = frame_mat

	# Door material
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = DOOR_COLOR
	door_mat.roughness = 0.6
	door_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["door"] = door_mat

	# Door frame material
	var door_frame_mat = StandardMaterial3D.new()
	door_frame_mat.albedo_color = DOOR_FRAME_COLOR
	door_frame_mat.roughness = 0.7
	door_frame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["door_frame"] = door_frame_mat

	# Trim material
	var trim_mat = StandardMaterial3D.new()
	trim_mat.albedo_color = TRIM_COLOR
	trim_mat.roughness = 0.6
	trim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["trim"] = trim_mat

	# Foundation material
	var foundation_mat = StandardMaterial3D.new()
	foundation_mat.albedo_color = FOUNDATION_COLOR
	foundation_mat.roughness = 0.95
	foundation_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["foundation"] = foundation_mat

	# Roof material - darker shingles
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.22, 0.20, 0.18)
	roof_mat.roughness = 0.9
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["roof"] = roof_mat

	# Grass material
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.25, 0.4, 0.15)
	grass_mat.roughness = 1.0
	materials["grass"] = grass_mat

	# Road/asphalt material
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.15, 0.15, 0.15)
	road_mat.roughness = 0.85
	materials["road"] = road_mat

	# Sidewalk material
	var sidewalk_mat = StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.6, 0.58, 0.55)
	sidewalk_mat.roughness = 0.9
	materials["sidewalk"] = sidewalk_mat


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

	# Add foundation strip at bottom
	var foundation = _create_foundation(polygon_2d, 0.4)
	if foundation:
		var found_inst = MeshInstance3D.new()
		found_inst.mesh = foundation
		found_inst.material_override = materials["foundation"]
		building.add_child(found_inst)

	# Add windows to each floor with frames
	for floor_num in range(levels):
		var floor_height = floor_num * 3.0 + 1.2  # Start 1.2m up from floor
		var is_ground_floor = (floor_num == 0)

		# Window glass
		var windows = _create_windows_for_floor(polygon_2d, floor_height, 1.5, is_ground_floor)
		if windows:
			var win_inst = MeshInstance3D.new()
			win_inst.mesh = windows
			win_inst.material_override = materials["window"]
			building.add_child(win_inst)

		# Window frames
		var frames = _create_window_frames_for_floor(polygon_2d, floor_height, 1.5, is_ground_floor)
		if frames:
			var frame_inst = MeshInstance3D.new()
			frame_inst.mesh = frames
			frame_inst.material_override = materials["window_frame"]
			building.add_child(frame_inst)

	# Add door on ground floor with frame
	var door = _create_door(polygon_2d, 0.0)
	if door:
		var door_inst = MeshInstance3D.new()
		door_inst.mesh = door
		door_inst.material_override = materials["door"]
		building.add_child(door_inst)

	var door_frame = _create_door_frame(polygon_2d, 0.0)
	if door_frame:
		var frame_inst = MeshInstance3D.new()
		frame_inst.mesh = door_frame
		frame_inst.material_override = materials["door_frame"]
		building.add_child(frame_inst)

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


func _create_windows_for_floor(polygon: PackedVector2Array, floor_y: float, window_height: float, skip_door_wall: bool = false) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var window_width = 1.0
	var window_spacing = 2.8
	var inset = 0.06  # How much windows are inset from wall

	for i in range(polygon.size()):
		# Skip first wall on ground floor (where door is)
		if skip_door_wall and i == 0:
			continue
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


func _create_foundation(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var outset = 0.05  # Slightly wider than wall

	for i in range(polygon.size()):
		var curr = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]

		var wall_dir = (next - curr).normalized()
		var normal_2d = Vector2(wall_dir.y, -wall_dir.x)

		var curr_out = curr + normal_2d * outset
		var next_out = next + normal_2d * outset

		var p0 = Vector3(curr_out.x, 0, curr_out.y)
		var p1 = Vector3(next_out.x, 0, next_out.y)
		var p2 = Vector3(next_out.x, height, next_out.y)
		var p3 = Vector3(curr_out.x, height, curr_out.y)

		var normal = Vector3(normal_2d.x, 0, normal_2d.y)

		st.set_normal(normal)
		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)

		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
		st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

	return st.commit()


func _create_window_frames_for_floor(polygon: PackedVector2Array, floor_y: float, window_height: float, skip_door_wall: bool = false) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var window_width = 1.0
	var window_spacing = 2.8
	var frame_thickness = 0.08
	var inset = 0.04

	for i in range(polygon.size()):
		if skip_door_wall and i == 0:
			continue

		var curr = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]

		var wall_vec = next - curr
		var wall_length = wall_vec.length()
		var wall_dir = wall_vec.normalized()
		var normal_2d = Vector2(wall_dir.y, -wall_dir.x)
		var offset = normal_2d * inset

		var num_windows = int((wall_length - 1.0) / window_spacing)
		if num_windows < 1:
			continue

		var start_offset = (wall_length - (num_windows - 1) * window_spacing) / 2.0

		for w in range(num_windows):
			var pos_along = start_offset + w * window_spacing
			var center_2d = curr + wall_dir * pos_along + offset

			var half_w = window_width / 2.0 + frame_thickness
			var left_2d = center_2d - wall_dir * half_w
			var right_2d = center_2d + wall_dir * half_w

			var normal = Vector3(normal_2d.x, 0, normal_2d.y)

			# Top frame
			var t0 = Vector3(left_2d.x, floor_y + window_height, left_2d.y)
			var t1 = Vector3(right_2d.x, floor_y + window_height, right_2d.y)
			var t2 = Vector3(right_2d.x, floor_y + window_height + frame_thickness, right_2d.y)
			var t3 = Vector3(left_2d.x, floor_y + window_height + frame_thickness, left_2d.y)

			st.set_normal(normal)
			st.set_uv(Vector2(0, 0)); st.add_vertex(t0)
			st.set_uv(Vector2(1, 0)); st.add_vertex(t1)
			st.set_uv(Vector2(1, 1)); st.add_vertex(t2)
			st.set_uv(Vector2(0, 0)); st.add_vertex(t0)
			st.set_uv(Vector2(1, 1)); st.add_vertex(t2)
			st.set_uv(Vector2(0, 1)); st.add_vertex(t3)

			# Bottom frame (sill)
			var b0 = Vector3(left_2d.x, floor_y - frame_thickness, left_2d.y)
			var b1 = Vector3(right_2d.x, floor_y - frame_thickness, right_2d.y)
			var b2 = Vector3(right_2d.x, floor_y, right_2d.y)
			var b3 = Vector3(left_2d.x, floor_y, left_2d.y)

			st.set_uv(Vector2(0, 0)); st.add_vertex(b0)
			st.set_uv(Vector2(1, 0)); st.add_vertex(b1)
			st.set_uv(Vector2(1, 1)); st.add_vertex(b2)
			st.set_uv(Vector2(0, 0)); st.add_vertex(b0)
			st.set_uv(Vector2(1, 1)); st.add_vertex(b2)
			st.set_uv(Vector2(0, 1)); st.add_vertex(b3)

	return st.commit()


func _create_door_frame(polygon: PackedVector2Array, floor_y: float) -> ArrayMesh:
	if polygon.size() < 2:
		return null

	var curr = polygon[0]
	var next = polygon[1]

	var wall_vec = next - curr
	var wall_length = wall_vec.length()
	var wall_dir = wall_vec.normalized()
	var normal_2d = Vector2(wall_dir.y, -wall_dir.x)
	var offset = normal_2d * 0.01

	var door_width = 1.0
	var door_height = 2.2
	var frame_width = 0.12

	var center_2d = curr + wall_dir * (wall_length / 2.0) + offset

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal = Vector3(normal_2d.x, 0, normal_2d.y)

	# Left frame
	var ll = center_2d - wall_dir * (door_width / 2.0 + frame_width)
	var lr = center_2d - wall_dir * (door_width / 2.0)

	var l0 = Vector3(ll.x, floor_y, ll.y)
	var l1 = Vector3(lr.x, floor_y, lr.y)
	var l2 = Vector3(lr.x, floor_y + door_height + frame_width, lr.y)
	var l3 = Vector3(ll.x, floor_y + door_height + frame_width, ll.y)

	st.set_normal(normal)
	st.set_uv(Vector2(0, 1)); st.add_vertex(l0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(l1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(l2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(l0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(l2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(l3)

	# Right frame
	var rl = center_2d + wall_dir * (door_width / 2.0)
	var rr = center_2d + wall_dir * (door_width / 2.0 + frame_width)

	var r0 = Vector3(rl.x, floor_y, rl.y)
	var r1 = Vector3(rr.x, floor_y, rr.y)
	var r2 = Vector3(rr.x, floor_y + door_height + frame_width, rr.y)
	var r3 = Vector3(rl.x, floor_y + door_height + frame_width, rl.y)

	st.set_uv(Vector2(0, 1)); st.add_vertex(r0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(r1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(r2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(r0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(r2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(r3)

	# Top frame
	var tl = center_2d - wall_dir * (door_width / 2.0 + frame_width)
	var tr = center_2d + wall_dir * (door_width / 2.0 + frame_width)

	var t0 = Vector3(tl.x, floor_y + door_height, tl.y)
	var t1 = Vector3(tr.x, floor_y + door_height, tr.y)
	var t2 = Vector3(tr.x, floor_y + door_height + frame_width, tr.y)
	var t3 = Vector3(tl.x, floor_y + door_height + frame_width, tl.y)

	st.set_uv(Vector2(0, 1)); st.add_vertex(t0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(t1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(t2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(t0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(t2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(t3)

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

	var ground_container = Node3D.new()
	ground_container.name = "Ground"
	add_child(ground_container)

	# Main grass ground
	var grass_mesh = PlaneMesh.new()
	grass_mesh.size = Vector2(size, size)
	grass_mesh.subdivide_width = 4
	grass_mesh.subdivide_depth = 4

	var grass_inst = MeshInstance3D.new()
	grass_inst.name = "Grass"
	grass_inst.mesh = grass_mesh
	grass_inst.position.y = -0.01
	grass_inst.material_override = materials["grass"]
	ground_container.add_child(grass_inst)

	# Create roads (main streets)
	_create_road(ground_container, Vector3(0, 0, 0), Vector3(0, 0, 1), size, 8.0)  # North-South main road
	_create_road(ground_container, Vector3(0, 0, 0), Vector3(1, 0, 0), size, 8.0)  # East-West main road

	# Create sidewalks along roads
	_create_sidewalk(ground_container, Vector3(5, 0, 0), Vector3(0, 0, 1), size, 2.0)
	_create_sidewalk(ground_container, Vector3(-5, 0, 0), Vector3(0, 0, 1), size, 2.0)
	_create_sidewalk(ground_container, Vector3(0, 0, 5), Vector3(1, 0, 0), size, 2.0)
	_create_sidewalk(ground_container, Vector3(0, 0, -5), Vector3(1, 0, 0), size, 2.0)

	# Ground collision
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(size, 0.1, size)
	shape.shape = box
	shape.position.y = -0.05
	body.add_child(shape)
	ground_container.add_child(body)


func _create_road(parent: Node3D, center: Vector3, direction: Vector3, length: float, width: float) -> void:
	var road_mesh = PlaneMesh.new()

	if direction.z != 0:  # North-South road
		road_mesh.size = Vector2(width, length)
	else:  # East-West road
		road_mesh.size = Vector2(length, width)

	var road_inst = MeshInstance3D.new()
	road_inst.mesh = road_mesh
	road_inst.position = center
	road_inst.position.y = 0.01
	road_inst.material_override = materials["road"]
	parent.add_child(road_inst)

	# Road markings (center line)
	_create_road_markings(parent, center, direction, length)


func _create_road_markings(parent: Node3D, center: Vector3, direction: Vector3, length: float) -> void:
	var marking_mat = StandardMaterial3D.new()
	marking_mat.albedo_color = Color(0.9, 0.85, 0.2)  # Yellow center line
	marking_mat.roughness = 0.7

	var dash_length = 3.0
	var gap_length = 3.0
	var num_dashes = int(length / (dash_length + gap_length))

	for i in range(-num_dashes / 2, num_dashes / 2):
		var dash_mesh = PlaneMesh.new()

		if direction.z != 0:
			dash_mesh.size = Vector2(0.15, dash_length)
		else:
			dash_mesh.size = Vector2(dash_length, 0.15)

		var dash = MeshInstance3D.new()
		dash.mesh = dash_mesh
		dash.position = center + direction * (i * (dash_length + gap_length))
		dash.position.y = 0.02
		dash.material_override = marking_mat
		parent.add_child(dash)


func _create_sidewalk(parent: Node3D, offset: Vector3, direction: Vector3, length: float, width: float) -> void:
	var walk_mesh = PlaneMesh.new()

	if direction.z != 0:  # Along Z axis
		walk_mesh.size = Vector2(width, length)
	else:  # Along X axis
		walk_mesh.size = Vector2(length, width)

	var walk_inst = MeshInstance3D.new()
	walk_inst.mesh = walk_mesh
	walk_inst.position = offset
	walk_inst.position.y = 0.05  # Slightly raised
	walk_inst.material_override = materials["sidewalk"]
	parent.add_child(walk_inst)


func clear_buildings() -> void:
	for child in _buildings_container.get_children():
		child.queue_free()


func get_building_count() -> int:
	return _buildings_container.get_child_count()
