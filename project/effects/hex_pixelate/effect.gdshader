shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(2.0, 200.0) = 20.0;
uniform float border : hint_range(0.0, 20.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int sampling : hint_range(0, 1) = 1;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

#define TAP(p) texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0)))

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float cell_px = max(size * px_scale, 2.0);
	vec2 p = UV * dims / cell_px;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 ga = mod(p, r) - h;
	vec2 gb = mod(p - h, r) - h;
	vec2 g = dot(ga, ga) < dot(gb, gb) ? ga : gb;
	vec2 centre = p - g;
	vec2 to_uv = cell_px / dims;
	vec2 cuv = centre * to_uv;
	vec4 sum = TAP(cuv);
	if (sampling == 1) {
		float rad = 0.32;
		sum += TAP(cuv + vec2(rad, 0.0) * to_uv);
		sum += TAP(cuv + vec2(rad * 0.5, rad * 0.8660254) * to_uv);
		sum += TAP(cuv + vec2(-rad * 0.5, rad * 0.8660254) * to_uv);
		sum += TAP(cuv + vec2(-rad, 0.0) * to_uv);
		sum += TAP(cuv + vec2(-rad * 0.5, -rad * 0.8660254) * to_uv);
		sum += TAP(cuv + vec2(rad * 0.5, -rad * 0.8660254) * to_uv);
		sum /= 7.0;
	}
	float a = sum.a;
	vec3 rgb = a > 0.0001 ? sum.rgb / a : vec3(0.0);
	if (border > 0.0) {
		vec2 ag = abs(g);
		float hex_d = max(ag.x, dot(ag, vec2(0.5, 0.8660254)));
		float edge_px = (0.5 - hex_d) * cell_px;
		float half_w = border * px_scale * 0.5;
		float cover = 1.0 - smoothstep(half_w - 0.5, half_w + 0.5, edge_px);
		rgb = mix(rgb, border_colour.rgb, cover * border_colour.a);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
