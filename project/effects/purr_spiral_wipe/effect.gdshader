shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int arms : hint_range(1, 6) = 1;
uniform float turns : hint_range(0.0, 6.0) = 1.5;
uniform float edge : hint_range(0.0, 30.0) = 5.0;
uniform vec4 edge_colour : source_color = vec4(1.0, 0.85, 0.95, 1.0);
uniform bool reverse = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 q = (UV - centre) * vec2(asp, 1.0);
	float r = length(q);
	float maxr = length(vec2(asp, 1.0) * 0.5 + abs(centre - 0.5) * vec2(asp, 1.0));
	float a = atan(q.y, q.x) / 6.28318 + 0.5;
	if (reverse) {
		a = 1.0 - a;
	}
	float an = fract(a * float(arms) + r / maxr * turns);
	float v = (an + r / maxr) * 0.5;
	float d = (v - pg) / max(fwidth(v), 0.00001) * 0.5;
	float hole = smoothstep(1.0, -1.0, d) * step(0.0001, pg);
	float e = smoothstep(1.0, -1.0, d - edge * px_scale * 0.5) * (1.0 - hole) * step(0.0001, pg) * step(0.01, edge) * (1.0 - smoothstep(0.95, 1.0, pg));
	vec4 o = mix(c, vec4(edge_colour.rgb, 1.0) * edge_colour.a, e * edge_colour.a);
	COLOR = pg <= 0.0 ? c : o * (1.0 - hole);
}
