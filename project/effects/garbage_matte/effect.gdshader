shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform vec2 point_1 = vec2(0.06, 0.06);
uniform vec2 point_2 = vec2(0.5, 0.04);
uniform vec2 point_3 = vec2(0.94, 0.06);
uniform vec2 point_4 = vec2(0.96, 0.5);
uniform vec2 point_5 = vec2(0.94, 0.94);
uniform vec2 point_6 = vec2(0.5, 0.96);
uniform vec2 point_7 = vec2(0.06, 0.94);
uniform vec2 point_8 = vec2(0.04, 0.5);
uniform float feather : hint_range(0.0, 200.0) = 2.0;
uniform bool invert = false;
uniform bool show_shape = false;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 v[8] = vec2[8](point_1 * size, point_2 * size, point_3 * size, point_4 * size, point_5 * size, point_6 * size, point_7 * size, point_8 * size);
	vec2 p = UV * size;
	float d = dot(p - v[0], p - v[0]);
	float sg = 1.0;
	for (int i = 0; i < 8; i++) {
		int j = (i + 7) % 8;
		vec2 e = v[j] - v[i];
		vec2 w = p - v[i];
		vec2 b = w - e * clamp(dot(w, e) / max(dot(e, e), 0.000001), 0.0, 1.0);
		d = min(d, dot(b, b));
		bool c1 = p.y >= v[i].y;
		bool c2 = p.y < v[j].y;
		bool c3 = e.x * w.y > e.y * w.x;
		if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) {
			sg = -sg;
		}
	}
	float sd = sg * sqrt(d);
	float f = max(feather * max(px_scale, 0.0001), 1.0);
	float m = 1.0 - smoothstep(-f * 0.5, f * 0.5, sd);
	if (invert) {
		m = 1.0 - m;
	}
	vec4 c = texture(TEXTURE, UV);
	vec4 o = c * m;
	if (show_shape) {
		float line = 1.0 - smoothstep(0.5, 1.5, abs(sd));
		vec4 ink = vec4(1.0, 0.25, 0.6, 1.0) * line;
		o = ink + c * (1.0 - line) * mix(0.35, 1.0, m);
	}
	COLOR = o;
}
