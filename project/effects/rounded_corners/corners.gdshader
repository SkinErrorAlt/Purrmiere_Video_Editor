shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float radius : hint_range(0.0, 1000.0) = 40.0;
uniform float feather : hint_range(0.0, 100.0) = 0.0;
uniform float border : hint_range(0.0, 200.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shadow : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_size : hint_range(1.0, 300.0) = 30.0;
uniform bool top_left = true;
uniform bool top_right = true;
uniform bool bottom_right = true;
uniform bool bottom_left = true;

float sd_round_box(vec2 p, vec2 b, vec4 r) {
	vec2 rs = p.x > 0.0 ? r.xy : r.zw;
	float rr = p.y > 0.0 ? rs.x : rs.y;
	vec2 q = abs(p) - b + rr;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - rr;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 p = (UV - 0.5) * size;
	vec2 b = size * 0.5;
	float r = clamp(radius * ps, 0.0, min(b.x, b.y));
	vec4 radii = vec4(bottom_right ? r : 0.0, top_right ? r : 0.0, bottom_left ? r : 0.0, top_left ? r : 0.0);
	float d = sd_round_box(p, b, radii);
	float fw = max(feather * ps, 1.0);
	float m = clamp((0.5 - d) / fw, 0.0, 1.0);
	if (feather > 0.0) {
		m = m * m * (3.0 - 2.0 * m);
	}
	float sh = clamp(shadow, 0.0, 1.0) * (1.0 - smoothstep(0.0, max(shadow_size * ps, 1.0), -d));
	rgb *= 1.0 - sh;
	float bpx = border * ps;
	float bm = bpx > 0.0 ? clamp(bpx + d + 0.5, 0.0, 1.0) : 0.0;
	float bk = bm * border_colour.a;
	rgb = mix(rgb, border_colour.rgb, bk);
	float oa = clamp((bk + a * (1.0 - bk)) * m, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * oa, oa);
}
