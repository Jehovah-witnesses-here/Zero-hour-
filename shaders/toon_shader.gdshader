shader_type spatial;
render_mode ambient_light_disabled;

// Borderlands-style cel/toon shader
// Creates hard shadow bands and bold colors

group_uniforms colors;
uniform vec3 base_color : source_color = vec3(0.6, 0.58, 0.55);
uniform vec3 shadow_color : source_color = vec3(0.2, 0.18, 0.15);
uniform vec3 highlight_color : source_color = vec3(0.9, 0.88, 0.85);

group_uniforms shading;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_smoothness : hint_range(0.0, 0.2) = 0.02;
uniform float highlight_threshold : hint_range(0.5, 1.0) = 0.9;
uniform float highlight_smoothness : hint_range(0.0, 0.2) = 0.02;

group_uniforms outline;
uniform float outline_thickness : hint_range(0.0, 0.1) = 0.02;
uniform vec3 outline_color : source_color = vec3(0.0, 0.0, 0.0);

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Get light direction (assuming main directional light)
	vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));
	vec3 normal = normalize(world_normal);

	// Calculate basic NdotL
	float NdotL = dot(normal, light_dir);

	// Create hard shadow bands (cel-shading)
	float shadow = smoothstep(shadow_threshold - shadow_smoothness, shadow_threshold + shadow_smoothness, NdotL);
	float highlight = smoothstep(highlight_threshold - highlight_smoothness, highlight_threshold + highlight_smoothness, NdotL);

	// Mix colors based on lighting bands
	vec3 final_color = mix(shadow_color, base_color, shadow);
	final_color = mix(final_color, highlight_color, highlight);

	ALBEDO = final_color;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
