extends Node3D
## Building Generator - Extrudes 2D building footprints into 3D meshes
## Takes OSM polygon data and creates walkable 3D buildings

signal buildings_generated(count: int)
signal generation_started
signal generation_complete

# Materials for buildings
var building_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var ground_material: StandardMaterial3D

# Building container
var _buildings_container: Node3D = null

# Reference to GPS manager for coordinate conversion
@onready var gps_manager = get_node("/root/GPSManager")


func _ready() -> void:
	_setup_materials()
	_create_buildings_container()


func _setup_materials() -> void:
	# Wall material - concrete gray
	building_material = StandardMaterial3D.new()
	building_material.albedo_color = Color(0.6, 0.58, 0.55)  # Concrete gray
	building_material.roughness = 0.9
	building_material.metallic = 0.0

	# Roof material - darker
	roof_material = StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.35, 0.33, 0.3)  # Dark roof
	roof_material.roughness = 0.85

	# Ground material
	ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.25, 0.28, 0.22)  # Asphalt/grass mix
	ground_material.roughness = 1.0


func _create_buildings_container() -> void:
	_buildings_container = Node3D.new()
	_buildings_container.name = "Buildings"
	add_child(_buildings_container)


## Generate buildings from OSM data
func generate_buildings(buildings_data: Array) -> void:
	generation_started.emit()

	# Clear existing buildings
	for child in _buildings_container.get_children():
		child.queue_free()

	await get_tree().process_frame  # Let queue_free complete

	var count = 0
	for building_data in buildings_data:
		var building = _create_building(building_data)
		if building:
			_buildings_container.add_child(building)
			count += 1

		# Yield occasionally to prevent freezing
		if count % 10 == 0:
			await get_tree().process_frame

	print("[BuildingGen] Generated ", count, " buildings")
	buildings_generated.emit(count)
	generation_complete.emit()


## Create a single building mesh from polygon data
func _create_building(data: Dictionary) -> Node3D:
	var polygon = data.get("polygon", [])
	if polygon.size() < 3:
		return null

	var height = data.get("height", 9.0)  # Default 3 stories
	var building_name = data.get("name", "Building_%d" % data.get("id", 0))

	# Convert GPS polygon to local meters
	var local_polygon: PackedVector2Array = PackedVector2Array()
	for point in polygon:
		var local_pos = gps_manager.gps_to_meters(point.lat, point.lon)
		local_polygon.append(Vector2(local_pos.x, local_pos.z))

	# Create building node
	var building_node = Node3D.new()
	building_node.name = building_name

	# Create walls (extruded polygon)
	var wall_mesh = _create_walls(local_polygon, height)
	if wall_mesh:
		var wall_instance = MeshInstance3D.new()
		wall_instance.mesh = wall_mesh
		wall_instance.material_override = building_material
		building_node.add_child(wall_instance)

		# Add collision
		var collision_shape = _create_collision(local_polygon, height)
		if collision_shape:
			var static_body = StaticBody3D.new()
			static_body.add_child(collision_shape)
			building_node.add_child(static_body)

	# Create roof
	var roof_mesh = _create_roof(local_polygon, height)
	if roof_mesh:
		var roof_instance = MeshInstance3D.new()
		roof_instance.mesh = roof_mesh
		roof_instance.material_override = roof_material
		building_node.add_child(roof_instance)

	return building_node


## Create wall mesh by extruding polygon
func _create_walls(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	if polygon.size() < 3:
		return null

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var vertex_count = polygon.size()

	# Create walls for each edge
	for i in range(vertex_count):
		var current = polygon[i]
		var next = polygon[(i + 1) % vertex_count]

		# Four corners of the wall quad
		var bl = Vector3(current.x, 0, current.y)       # Bottom-left
		var br = Vector3(next.x, 0, next.y)             # Bottom-right
		var tl = Vector3(current.x, height, current.y)  # Top-left
		var tr = Vector3(next.x, height, next.y)        # Top-right

		# Calculate normal (pointing outward)
		var edge = br - bl
		var normal = Vector3(-edge.z, 0, edge.x).normalized()

		# First triangle (bl, br, tr)
		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(0, 1))
		surface_tool.add_vertex(bl)
		surface_tool.set_uv(Vector2(1, 1))
		surface_tool.add_vertex(br)
		surface_tool.set_uv(Vector2(1, 0))
		surface_tool.add_vertex(tr)

		# Second triangle (bl, tr, tl)
		surface_tool.set_uv(Vector2(0, 1))
		surface_tool.add_vertex(bl)
		surface_tool.set_uv(Vector2(1, 0))
		surface_tool.add_vertex(tr)
		surface_tool.set_uv(Vector2(0, 0))
		surface_tool.add_vertex(tl)

	surface_tool.generate_tangents()
	return surface_tool.commit()


## Create flat roof mesh
func _create_roof(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	if polygon.size() < 3:
		return null

	# Triangulate the polygon for the roof
	var triangles = Geometry2D.triangulate_polygon(polygon)
	if triangles.size() == 0:
		return null

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var normal = Vector3.UP

	for i in range(0, triangles.size(), 3):
		for j in range(3):
			var idx = triangles[i + j]
			var point = polygon[idx]
			surface_tool.set_normal(normal)
			surface_tool.set_uv(Vector2(point.x * 0.1, point.y * 0.1))
			surface_tool.add_vertex(Vector3(point.x, height, point.y))

	surface_tool.generate_tangents()
	return surface_tool.commit()


## Create collision shape for building
func _create_collision(polygon: PackedVector2Array, height: float) -> CollisionShape3D:
	if polygon.size() < 3:
		return null

	# Create a convex hull collision shape
	var points: PackedVector3Array = PackedVector3Array()

	# Bottom vertices
	for point in polygon:
		points.append(Vector3(point.x, 0, point.y))

	# Top vertices
	for point in polygon:
		points.append(Vector3(point.x, height, point.y))

	var shape = ConvexPolygonShape3D.new()
	shape.points = points

	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape

	return collision_shape


## Create ground plane
func create_ground(size: float = 500.0) -> void:
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(size, size)

	var ground_instance = MeshInstance3D.new()
	ground_instance.name = "Ground"
	ground_instance.mesh = ground_mesh
	ground_instance.material_override = ground_material

	# Ground collision
	var ground_body = StaticBody3D.new()
	var ground_collision = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(size, 0.1, size)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.05
	ground_body.add_child(ground_collision)

	add_child(ground_instance)
	add_child(ground_body)


## Clear all generated buildings
func clear_buildings() -> void:
	for child in _buildings_container.get_children():
		child.queue_free()


## Get building count
func get_building_count() -> int:
	return _buildings_container.get_child_count()
