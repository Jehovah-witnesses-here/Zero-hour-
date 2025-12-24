shader_type canvas_item;

// Post-process outline shader for Borderlands-style black edges
// Apply this to a ColorRect covering the screen

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_linear_mipmap;

uniform vec3 outline_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float outline_thickness : hint_range(0.5, 5.0) = 1.5;
uniform float depth_threshold : hint_range(0.0, 1.0) = 0.1;
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.4;

// Edge detection using Sobel operator
float sobel_depth(sampler2D tex, vec2 uv, vec2 pixel_size) {
	float tl = texture(tex, uv + vec2(-1, -1) * pixel_size * outline_thickness).r;
	float t  = texture(tex, uv + vec2( 0, -1) * pixel_size * outline_thickness).r;
	float tr = texture(tex, uv + vec2( 1, -1) * pixel_size * outline_thickness).r;
	float l  = texture(tex, uv + vec2(-1,  0) * pixel_size * outline_thickness).r;
	float r  = texture(tex, uv + vec2( 1,  0) * pixel_size * outline_thickness).r;
	float bl = texture(tex, uv + vec2(-1,  1) * pixel_size * outline_thickness).r;
	float b  = texture(tex, uv + vec2( 0,  1) * pixel_size * outline_thickness).r;
	float br = texture(tex, uv + vec2( 1,  1) * pixel_size * outline_thickness).r;

	float gx = tl + 2.0*l + bl - tr - 2.0*r - br;
	float gy = tl + 2.0*t + tr - bl - 2.0*b - br;

	return sqrt(gx*gx + gy*gy);
}

float sobel_normal(sampler2D tex, vec2 uv, vec2 pixel_size) {
	vec3 tl = texture(tex, uv + vec2(-1, -1) * pixel_size * outline_thickness).rgb;
	vec3 t  = texture(tex, uv + vec2( 0, -1) * pixel_size * outline_thickness).rgb;
	vec3 tr = texture(tex, uv + vec2( 1, -1) * pixel_size * outline_thickness).rgb;
	vec3 l  = texture(tex, uv + vec2(-1,  0) * pixel_size * outline_thickness).rgb;
	vec3 r  = texture(tex, uv + vec2( 1,  0) * pixel_size * outline_thickness).rgb;
	vec3 bl = texture(tex, uv + vec2(-1,  1) * pixel_size * outline_thickness).rgb;
	vec3 b  = texture(tex, uv + vec2( 0,  1) * pixel_size * outline_thickness).rgb;
	vec3 br = texture(tex, uv + vec2( 1,  1) * pixel_size * outline_thickness).rgb;

	vec3 gx = tl + 2.0*l + bl - tr - 2.0*r - br;
	vec3 gy = tl + 2.0*t + tr - bl - 2.0*b - br;

	return length(gx) + length(gy);
}

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));

	// Get original color
	vec4 original = texture(screen_texture, SCREEN_UV);

	// Edge detection
	float depth_edge = sobel_depth(depth_texture, SCREEN_UV, pixel_size);
	float normal_edge = sobel_normal(normal_texture, SCREEN_UV, pixel_size);

	// Combine edges
	float edge = 0.0;
	if (depth_edge > depth_threshold) edge = 1.0;
	if (normal_edge > normal_threshold) edge = 1.0;

	// Apply outline
	vec3 final_color = mix(original.rgb, outline_color, edge);

	COLOR = vec4(final_color, 1.0);
}
