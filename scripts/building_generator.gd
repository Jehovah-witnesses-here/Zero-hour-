extends Node3D
## Building Generator - Extrudes 2D building footprints into 3D meshes
## Supports both GPS-based and direct meter-based building creation

signal buildings_generated(count: int)
signal generation_started
signal generation_complete

# Materials for buildings
var building_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var ground_material: StandardMaterial3D

# Building container
var _buildings_container: Node3D = null

# Demo mode flag - when true, skip GPS conversion
var demo_mode: bool = false

# Reference to GPS manager for coordinate conversion (optional)
var gps_manager = null


func _ready() -> void:
	_setup_materials()
	_create_buildings_container()

	# Try to get GPS manager, but don't require it
	await get_tree().process_frame
	gps_manager = get_node_or_null("/root/GPSManager")

	# If no GPS manager or no origin, use demo mode
	if not gps_manager or not gps_manager.has_origin:
		demo_mode = true
		print("[BuildingGen] Running in demo mode (no GPS)")


func _setup_materials() -> void:
	# Wall material - concrete gray with some variation
	building_material = StandardMaterial3D.new()
	building_material.albedo_color = Color(0.55, 0.53, 0.50)
	building_material.roughness = 0.85
	building_material.metallic = 0.0

	# Roof material - darker
	roof_material = StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.3, 0.28, 0.25)
	roof_material.roughness = 0.9

	# Ground material - asphalt/grass
	ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.2, 0.25, 0.18)
	ground_material.roughness = 1.0


func _create_buildings_container() -> void:
	_buildings_container = Node3D.new()
	_buildings_container.name = "Buildings"
	add_child(_buildings_container)


## Generate buildings from data array
func generate_buildings(buildings_data: Array) -> void:
	generation_started.emit()
	print("[BuildingGen] Generating ", buildings_data.size(), " buildings...")

	# Clear existing buildings
	for child in _buildings_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	var count = 0
	for building_data in buildings_data:
		var building = _create_building(building_data)
		if building:
			_buildings_container.add_child(building)
			count += 1

		# Yield occasionally to prevent freezing
		if count % 5 == 0:
			await get_tree().process_frame

	print("[BuildingGen] Generated ", count, " buildings successfully")
	buildings_generated.emit(count)
	generation_complete.emit()


## Create a single building mesh from data
func _create_building(data: Dictionary) -> Node3D:
	var polygon = data.get("polygon", [])
	if polygon.size() < 3:
		return null

	var height = data.get("height", 9.0)
	var building_name = data.get("name", "Building_%d" % data.get("id", randi()))

	# Convert polygon to local 2D coordinates
	var local_polygon: PackedVector2Array = PackedVector2Array()

	for point in polygon:
		var local_pos: Vector3

		if demo_mode or not gps_manager or not gps_manager.has_origin:
			# Demo mode: convert fake GPS back to meters directly
			var base_lat = 51.5074
			var base_lon = -0.1278
			var meters_per_deg = 111000.0

			var lat = point.get("lat", base_lat)
			var lon = point.get("lon", base_lon)

			var x = (lon - base_lon) * meters_per_deg
			var z = (lat - base_lat) * meters_per_deg

			local_pos = Vector3(x, 0, -z)
		else:
			# Real GPS mode
			local_pos = gps_manager.gps_to_meters(point.lat, point.lon)

		local_polygon.append(Vector2(local_pos.x, local_pos.z))

	if local_polygon.size() < 3:
		return null

	# Create building node
	var building_node = Node3D.new()
	building_node.name = building_name

	# Create walls
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

	for i in range(vertex_count):
		var current = polygon[i]
		var next = polygon[(i + 1) % vertex_count]

		var bl = Vector3(current.x, 0, current.y)
		var br = Vector3(next.x, 0, next.y)
		var tl = Vector3(current.x, height, current.y)
		var tr = Vector3(next.x, height, next.y)

		var edge = br - bl
		var normal = Vector3(-edge.z, 0, edge.x).normalized()

		# First triangle
		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(0, 1))
		surface_tool.add_vertex(bl)
		surface_tool.set_uv(Vector2(1, 1))
		surface_tool.add_vertex(br)
		surface_tool.set_uv(Vector2(1, 0))
		surface_tool.add_vertex(tr)

		# Second triangle
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

	var points: PackedVector3Array = PackedVector3Array()

	for point in polygon:
		points.append(Vector3(point.x, 0, point.y))
		points.append(Vector3(point.x, height, point.y))

	var shape = ConvexPolygonShape3D.new()
	shape.points = points

	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape

	return collision_shape


## Create ground plane
func create_ground(size: float = 500.0) -> void:
	# Remove old ground if exists
	var old_ground = get_node_or_null("Ground")
	if old_ground:
		old_ground.queue_free()
		await get_tree().process_frame

	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(size, size)

	var ground_instance = MeshInstance3D.new()
	ground_instance.name = "Ground"
	ground_instance.mesh = ground_mesh
	ground_instance.material_override = ground_material

	# Ground collision
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundBody"
	var ground_collision = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(size, 0.1, size)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.05
	ground_body.add_child(ground_collision)

	add_child(ground_instance)
	add_child(ground_body)

	print("[BuildingGen] Ground created: ", size, "x", size, " meters")


## Clear all buildings
func clear_buildings() -> void:
	for child in _buildings_container.get_children():
		child.queue_free()


## Get building count
func get_building_count() -> int:
	return _buildings_container.get_child_count()


## Set demo mode
func set_demo_mode(enabled: bool) -> void:
	demo_mode = enabled
