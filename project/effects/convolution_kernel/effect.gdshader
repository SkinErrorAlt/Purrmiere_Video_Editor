shader_type canvas_item;
render_mode blend_disabled;

uniform vec3 top = vec3(0.0, -1.0, 0.0);
uniform vec3 middle = vec3(-1.0, 5.0, -1.0);
uniform vec3 bottom = vec3(0.0, -1.0, 0.0);
uniform float divisor : hint_range(0.01, 100.0) = 1.0;
uniform float offset : hint_range(-1.0, 1.0) = 0.0;
uniform float spread : hint_range(0.5, 10.0) = 1.0;
uniform bool use_absolute = false;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec2 s = vec2(spread * max(px_scale, 0.0001)) / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float k[9] = float[](top.x, top.y, top.z, middle.x, middle.y, middle.z, bottom.x, bottom.y, bottom.z);
	vec3 sum = vec3(0.0);
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 3; i++) {
			vec4 t = texture(TEXTURE, UV + vec2(float(i - 1), float(j - 1)) * s);
			vec3 v = t.a > 0.0001 ? t.rgb / t.a : vec3(0.0);
			sum += v * k[j * 3 + i];
		}
	}
	vec3 rgb = sum / max(divisor, 0.01) + offset;
	if (use_absolute) { rgb = abs(rgb); }
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}
