shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D picture : filter_linear, repeat_enable, hint_default_transparent;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float light_angle : hint_range(-180.0, 180.0) = 135.0;
uniform int placement : hint_range(0, 1) = 0;
uniform float tile_scale : hint_range(0.05, 8.0) = 1.0;
uniform vec2 tex_size;
uniform float px_scale;

float lum(vec2 p) {
	vec4 t = texture(picture, p);
	return dot(t.rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 tsz = max(vec2(textureSize(picture, 0)), vec2(1.0));
	vec2 uv = placement == 0 ? UV * tex_size / (tsz * tile_scale * max(px_scale, 0.0001)) : UV;
	vec2 e = 1.0 / tsz;
	float gx = lum(uv + vec2(e.x, 0.0)) - lum(uv - vec2(e.x, 0.0));
	float gy = lum(uv + vec2(0.0, e.y)) - lum(uv - vec2(0.0, e.y));
	float a = radians(light_angle);
	float shade = (gx * cos(a) - gy * sin(a)) * contrast;
	COLOR = vec4(clamp(rgb + shade, 0.0, 1.0) * c.a, c.a);
}
