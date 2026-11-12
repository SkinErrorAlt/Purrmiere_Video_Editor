shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

void fragment() {
	vec2 tsz = floor(1.0 / max(fwidth(UV), vec2(1e-6)) + 0.5);
	vec2 csz = max(floor(tsz / 8.0), vec2(1.0));
	vec2 px = UV * tsz;
	vec2 cell = floor(px / csz);
	if (cell.x > 7.0 || cell.y > 7.0) {
		COLOR = vec4(0.0);
	} else {
		int age = int(cell.y) * 8 + int(cell.x);
		vec2 local = (px - cell * csz) / csz;
		vec2 fp = 1.0 / csz;
		bool ok = age == 0 || history_has(age);
		vec3 acc = vec3(0.0);
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 4; i++) {
				vec2 q = clamp(local + (vec2(float(i), float(j)) - 1.5) * 0.25 * fp, vec2(0.0), vec2(1.0));
				vec4 c = age == 0 ? texture(TEXTURE, q) : history_frame(age, q, vec4(0.0));
				acc += unpm(c);
			}
		}
		COLOR = vec4(acc / 16.0, ok ? 1.0 : 0.0);
	}
}
