shader_type canvas_item;
render_mode blend_disabled;

uniform float radius : hint_range(1.0, 16.0) = 4.0;
uniform int levels : hint_range(2, 32) = 8;
uniform float keep_edges : hint_range(0.0, 1.0) = 0.4;
uniform vec2 tex_size;
uniform float px_scale;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float step_px = max(radius * max(px_scale, 0.0001), 1.0);
	int n = clamp(levels, 2, 32);
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 off = vec2(float(x), float(y)) * step_px * 0.5 / size;
			vec4 s = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
			vec3 sr = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			sum += sr;
			total += 1.0;
		}
	}
	vec3 smooth_rgb = sum / max(total, 0.0001);
	vec3 stepped = floor(smooth_rgb * float(n) + 0.5) / float(n);
	rgb = mix(stepped, rgb, keep_edges * 0.5);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
