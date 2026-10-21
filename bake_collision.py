"""
Parse mp_rust.obj and bake collision vertices into a binary file.
Output: packed float32 triples (x,y,z) per triangle vertex,
        already transformed: (v - OBJ_CENTER) * SCALE_FACTOR, then Z-up→Y-up rotation.

MW2 is Z-up. Godot is Y-up. The loader rotates the StaticBody3D -90° on X.
Pre-applying that rotation here: rot -90° X means x'=x, y'=z, z'=-y
"""
import struct

OBJ_PATH = "assets/maps/rust/exported_maps/modern_warfare_2/mp_rust.obj"
OUT_PATH = "assets/maps/rust/mp_rust_collision.bin"

CENTER = (868.0, 1006.0, -240.0)
SCALE  = 0.0254

def rot_x_neg90(x, y, z):
    return x, z, -y

verts = []
triangles = []

print("Parsing OBJ...")
with open(OBJ_PATH, "r") as f:
    for line in f:
        if line.startswith("v "):
            parts = line.split()
            verts.append((float(parts[1]), float(parts[2]), float(parts[3])))
        elif line.startswith("f "):
            parts = line.split()[1:]
            indices = [int(p.split("/")[0]) - 1 for p in parts]
            for i in range(1, len(indices) - 1):
                triangles.append((indices[0], indices[i], indices[i + 1]))

print(f"Vertices: {len(verts)}, Triangles: {len(triangles)}")

print("Baking and writing binary...")
cx, cy, cz = CENTER
buf = bytearray()
for i0, i1, i2 in triangles:
    for vi in (i0, i1, i2):
        ox, oy, oz = verts[vi]
        sx = (ox - cx) * SCALE
        sy = (oy - cy) * SCALE
        sz = (oz - cz) * SCALE
        rx, ry, rz = rot_x_neg90(sx, sy, sz)
        buf += struct.pack("<fff", rx, ry, rz)

with open(OUT_PATH, "wb") as f:
    f.write(buf)

n_verts = len(triangles) * 3
print(f"Written {n_verts} verts ({len(buf)/1024/1024:.1f} MB) → {OUT_PATH}")
