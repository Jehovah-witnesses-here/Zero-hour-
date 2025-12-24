extends Node3D
## Building Generator - Creates 3D buildings from polygon data
## Fixed: Double-sided walls, correct normals, proper 4-wall rendering

signal buildings_generated(count: int)
signal generation_started
signal generation_complete

# Materials
var wall_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var ground_material: StandardMaterial3D

# Container for all buildings
var _buildings_container: Node3D = null

# Demo mode - skip GPS coordinate conversion
var demo_mode: bool = true


func _ready() -> void:
	_setup_materials()
	_create_buildings_container()
	print("[BuildingGen] Ready - demo mode enabled")


func _setup_materials() -> void:
	# Wall material - DOUBLE SIDED so all walls visible
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.6, 0.58, 0.55)
	wall_material.roughness = 0.85
	wall_material.metallic = 0.0
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # CRITICAL: Show both sides

	# Roof material - also double sided
	roof_material = StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.35, 0.32, 0.30)
	roof_material.roughness = 0.9
	roof_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Ground material
	ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.25, 0.30, 0.20)
	ground_material.roughness = 1.0


func _create_buildings_container() -> void:
	_buildings_container = Node3D.new()
	_buildings_container.name = "Buildings"
	add_child(_buildings_container)


## Generate all buildings from data array
func generate_buildings(buildings_data: Array) -> void:
	generation_started.emit()
	print("[BuildingGen] Generating ", buildings_data.size(), " buildings...")

	# Clear existing
	for child in _buildings_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	var count = 0
	for data in buildings_data:
		var building = _create_building(data)
		if building:
			_buildings_container.add_child(building)
			count += 1

		if count % 5 == 0:
			await get_tree().process_frame

	print("[BuildingGen] Created ", count, " buildings successfully")
	buildings_generated.emit(count)
	generation_complete.emit()


## Create a single building from polygon data
func _create_building(data: Dictionary) -> Node3D:
	var polygon_data = data.get("polygon", [])
	if polygon_data.size() < 3:
		return null

	var height = data.get("height", 9.0)
	var building_name = str(data.get("name", "Building"))

	# Convert GPS-style coordinates to meters
	var polygon_2d: PackedVector2Array = PackedVector2Array()

	var base_lat = 51.5074
	var base_lon = -0.1278
	var meters_per_deg = 111000.0

	for point in polygon_data:
		var lat = point.get("lat", base_lat)
		var lon = point.get("lon", base_lon)

		var x = (lon - base_lon) * meters_per_deg
		var z = -(lat - base_lat) * meters_per_deg  # Negative for correct orientation

		polygon_2d.append(Vector2(x, z))

	if polygon_2d.size() < 3:
		return null

	# Ensure counter-clockwise winding for correct outward normals
	if _is_clockwise(polygon_2d):
		polygon_2d.reverse()

	# Create building node
	var building_node = Node3D.new()
	building_node.name = building_name

	# Create walls (all 4 sides)
	var wall_mesh = _create_walls_mesh(polygon_2d, height)
	if wall_mesh:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = wall_mesh
		mesh_instance.material_override = wall_material
		building_node.add_child(mesh_instance)

	# Create roof
	var roof_mesh = _create_roof_mesh(polygon_2d, height)
	if roof_mesh:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = roof_mesh
		mesh_instance.material_override = roof_material
		building_node.add_child(mesh_instance)

	# Create floor
	var floor_mesh = _create_roof_mesh(polygon_2d, 0.01)
	if floor_mesh:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = floor_mesh
		mesh_instance.material_override = wall_material
		building_node.add_child(mesh_instance)

	# Create collision
	var collision = _create_collision(polygon_2d, height)
	if collision:
		building_node.add_child(collision)

	return building_node


## Check if polygon winds clockwise
func _is_clockwise(polygon: PackedVector2Array) -> bool:
	var sum = 0.0
	for i in range(polygon.size()):
		var current = polygon[i]
		var next = polygon[(i + 1) % polygon.size()]
		sum += (next.x - current.x) * (next.y + current.y)
	return sum > 0


## Create wall mesh - ensures ALL walls are created
func _create_walls_mesh(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var num_vertices = polygon.size()

	# Create a wall quad for EACH edge
	for i in range(num_vertices):
		var current = polygon[i]
		var next = polygon[(i + 1) % num_vertices]

		# Four corners of this wall
		var p0 = Vector3(current.x, 0, current.y)       # bottom-left
		var p1 = Vector3(next.x, 0, next.y)             # bottom-right
		var p2 = Vector3(next.x, height, next.y)        # top-right
		var p3 = Vector3(current.x, height, current.y)  # top-left

		# Calculate outward normal
		var edge = p1 - p0
		var normal = Vector3(edge.z, 0, -edge.x).normalized()

		# Triangle 1: p0, p1, p2
		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(0, 1))
		surface_tool.add_vertex(p0)

		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(1, 1))
		surface_tool.add_vertex(p1)

		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(1, 0))
		surface_tool.add_vertex(p2)

		# Triangle 2: p0, p2, p3
		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(0, 1))
		surface_tool.add_vertex(p0)

		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(1, 0))
		surface_tool.add_vertex(p2)

		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(0, 0))
		surface_tool.add_vertex(p3)

	return surface_tool.commit()


## Create roof mesh
func _create_roof_mesh(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	# Triangulate the polygon
	var indices = Geometry2D.triangulate_polygon(polygon)
	if indices.size() == 0:
		# Fallback for simple quad
		if polygon.size() == 4:
			indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
		else:
			return null

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var normal = Vector3.UP

	for idx in indices:
		var point = polygon[idx]
		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(point.x * 0.1, point.y * 0.1))
		surface_tool.add_vertex(Vector3(point.x, height, point.y))

	return surface_tool.commit()


## Create collision shape
func _create_collision(polygon: PackedVector2Array, height: float) -> StaticBody3D:
	var static_body = StaticBody3D.new()

	# Create collision points
	var points: PackedVector3Array = PackedVector3Array()
	for point in polygon:
		points.append(Vector3(point.x, 0, point.y))
		points.append(Vector3(point.x, height, point.y))

	var shape = ConvexPolygonShape3D.new()
	shape.points = points

	var collision = CollisionShape3D.new()
	collision.shape = shape
	static_body.add_child(collision)

	return static_body


## Create ground plane
func create_ground(size: float = 500.0) -> void:
	# Remove existing ground
	var old = get_node_or_null("Ground")
	if old:
		old.queue_free()

	var mesh = PlaneMesh.new()
	mesh.size = Vector2(size, size)

	var instance = MeshInstance3D.new()
	instance.name = "Ground"
	instance.mesh = mesh
	instance.material_override = ground_material
	add_child(instance)

	# Ground collision
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(size, 0.1, size)
	shape.shape = box
	shape.position.y = -0.05
	body.add_child(shape)
	add_child(body)

	print("[BuildingGen] Ground: ", size, "x", size, "m")


func clear_buildings() -> void:
	for child in _buildings_container.get_children():
		child.queue_free()


func get_building_count() -> int:
	return _buildings_container.get_child_count()
