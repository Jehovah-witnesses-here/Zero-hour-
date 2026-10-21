extends SceneTree

func _initialize() -> void:
	print("=== Mesh Test ===")
	var path = "res://assets/maps/rust/exported_maps/modern_warfare_2/mp_rust.obj"
	if not ResourceLoader.exists(path):
		print("ERROR: OBJ not found at " + path)
		quit(1)
		return

	var mesh = load(path)
	if not mesh is Mesh:
		print("ERROR: Resource is not a Mesh — type: " + str(typeof(mesh)))
		quit(1)
		return

	print("Surfaces: %d" % mesh.get_surface_count())

	var raw_faces = mesh.get_faces()
	print("get_faces() count: %d" % raw_faces.size())

	var shape = mesh.create_trimesh_shape()
	if not shape:
		print("ERROR: create_trimesh_shape() returned null")
		quit(1)
		return

	var shape_faces = shape.get_faces()
	print("Shape faces: %d" % shape_faces.size())
	print("=== PASS ===")
	quit(0)
