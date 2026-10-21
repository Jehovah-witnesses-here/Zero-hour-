extends Node3D
## Loads the exported MW2 Rust OBJ map.
## MW2 uses Z-up; OBJ is Y-up; Godot is Y-up.
## The exporter wrote MW2 coords directly into OBJ without axis remapping,
## so we rotate -90° on X to make Z stand upright as Godot Y.

const MAP_PATH = "res://assets/maps/rust/exported_maps/modern_warfare_2/mp_rust.obj"
const SCALE_FACTOR = 0.0254
const OBJ_CENTER = Vector3(868.0, 1006.0, -240.0)


func _ready() -> void:
	add_to_group("rust_map")
	_load_visual_mesh()
	_spawn_ladder_trigger()
	_spawn_props()


func _spawn_props() -> void:
	var props = Node3D.new()
	props.set_script(load("res://scripts/rust_props.gd"))
	add_child(props)


## Called by GameManager — mesh already loaded in _ready(), nothing to do.
func generate_map() -> void:
	pass


func _load_visual_mesh() -> void:
	if not ResourceLoader.exists(MAP_PATH):
		push_error("[RustMap] OBJ not found: " + MAP_PATH)
		return
	var mesh = load(MAP_PATH)
	if not mesh is Mesh:
		push_error("[RustMap] Not a Mesh: " + MAP_PATH)
		return

	# Visual mesh — scaled+rotated container
	var container = Node3D.new()
	container.scale = Vector3.ONE * SCALE_FACTOR
	container.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -OBJ_CENTER
	container.add_child(mi)
	add_child(container)

	# Flat floor so player lands immediately
	_add_floor_body()

	var raw_count = mesh.get_faces().size()
	print("[RustMap] Visual loaded — %d surfaces, %d raw verts — baking collision..." % [
		mesh.get_surface_count(), raw_count
	])
	_build_trimesh_collision(mesh)


func _add_floor_body() -> void:
	var shape = BoxShape3D.new()
	shape.size = Vector3(300.0, 1.0, 300.0)
	var col = CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, -0.5, 0.0)
	var body = StaticBody3D.new()
	body.add_child(col)
	add_child(body)


func _build_trimesh_collision(_mesh: Mesh) -> void:
	# Load pre-baked collision vertices from binary file.
	# get_faces() returns 0 on Android (GPU strips CPU-side mesh data).
	# bake_collision.py generates this file: packed float32 x,y,z triples,
	# already transformed (centered, scaled, Z-up→Y-up rotated).
	const BIN_PATH = "res://assets/maps/rust/mp_rust_collision.bin"

	var f = FileAccess.open(BIN_PATH, FileAccess.READ)
	if not f:
		push_error("[RustMap] Collision binary not found: " + BIN_PATH)
		_show_debug_overlay("ERROR: collision .bin missing!")
		return

	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	var floats: PackedFloat32Array = bytes.to_float32_array()
	var n = floats.size() / 3
	_show_debug_overlay("Bin loaded: %d verts" % (n * 3))

	if n == 0:
		push_error("[RustMap] Collision binary is empty")
		_show_debug_overlay("ERROR: collision .bin empty!")
		return

	var faces = PackedVector3Array()
	faces.resize(n)
	for i in n:
		faces[i] = Vector3(floats[i * 3], floats[i * 3 + 1], floats[i * 3 + 2])

	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)

	var col = CollisionShape3D.new()
	col.shape = shape

	var body = StaticBody3D.new()
	body.add_child(col)
	add_child(body)

	_show_debug_overlay("Collision OK — %d verts" % faces.size())
	print("[RustMap] Trimesh collision active — %d verts" % faces.size())


func _show_debug_overlay(msg: String) -> void:
	var cl = get_tree().root.get_node_or_null("_RustMapDebug")
	if not cl:
		cl = CanvasLayer.new()
		cl.name = "_RustMapDebug"
		cl.layer = 100
		var lbl = Label.new()
		lbl.name = "Lbl"
		lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
		lbl.position = Vector2(0, 60)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(1, 1, 0))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(lbl)
		get_tree().root.add_child(cl)
	cl.get_node("Lbl").text = "[RustMap] " + msg


func get_player_spawn() -> Vector3:
	return Vector3(0.0, 3.0, 0.0)


func _spawn_ladder_trigger() -> void:
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 18.0, 1.5)

	var col = CollisionShape3D.new()
	col.shape = shape

	var area = Area3D.new()
	area.add_child(col)
	area.position = Vector3(0.0, 10.0, 0.0)
	area.body_entered.connect(_on_ladder_entered)
	area.body_exited.connect(_on_ladder_exited)
	add_child(area)


func _on_ladder_entered(body: Node3D) -> void:
	if body.has_method("enter_ladder"):
		body.enter_ladder()


func _on_ladder_exited(body: Node3D) -> void:
	if body.has_method("exit_ladder"):
		body.exit_ladder()
