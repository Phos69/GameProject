shader_type canvas_item;
render_mode unshaded;

uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform sampler2D grass_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D path_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D asphalt_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D divider_texture : filter_linear_mipmap, repeat_enable;

uniform vec2 mask_uv_origin = vec2(0.0);
uniform vec2 mask_uv_size = vec2(1.0);
uniform vec2 texture_world_origin = vec2(0.0);
uniform vec2 world_size = vec2(1.0);
uniform float grass_repeat_world = 256.0;
uniform float path_repeat_world = 256.0;
uniform float asphalt_repeat_world = 256.0;
uniform float divider_repeat_world = 256.0;
uniform vec4 void_color : source_color = vec4(0.025, 0.035, 0.03, 1.0);


void fragment() {
	vec2 mask_uv = mask_uv_origin + UV * mask_uv_size;
	vec4 mask = texture(surface_mask, mask_uv);
	vec2 world_position = texture_world_origin + UV * world_size;
	vec4 grass = texture(
		grass_texture,
		world_position / max(grass_repeat_world, 1.0)
	);
	vec4 path = texture(
		path_texture,
		world_position / max(path_repeat_world, 1.0)
	);
	vec4 asphalt = texture(
		asphalt_texture,
		world_position / max(asphalt_repeat_world, 1.0)
	);
	float surface_weight = mask.r + mask.g + mask.b;
	vec4 surface = void_color;
	if (surface_weight > 0.001) {
		vec3 weights = mask.rgb / surface_weight;
		surface = grass * weights.r + path * weights.g + asphalt * weights.b;
		surface.a = 1.0;
	}
	vec4 divider = texture(
		divider_texture,
		world_position / max(divider_repeat_world, 1.0)
	);
	float divider_alpha = clamp(mask.a * divider.a, 0.0, 1.0);
	COLOR = mix(surface, vec4(divider.rgb, 1.0), divider_alpha);
}
