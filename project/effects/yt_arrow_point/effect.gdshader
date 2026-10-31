shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tip = vec2(0.6, 0.45);
uniform float angle : hint_range(-180.0, 180.0) = -135.0;
uniform float arrow_length : hint_range(0.03, 0.8) = 0.22;
uniform float thickness : hint_range(0.005, 0.2) = 0.035;
uniform vec4 colour : source_color = vec4(1.0, 0.12, 0.1, 1.0);
uniform vec4 outline_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline : hint_range(0.0, 0.05) = 0.006;
uniform float nudge : hint_range(0.0, 0.1) = 0.02;
uniform float nudge_rate : hint_range(0.0, 8.0) = 2.0;
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.4;
uniform float clip_time;
uniform vec2 tex_size = vec2(1.0, 1.0);

float arrow(vec2 p, float len, float th) {
	float head = th * 2.6;
	float hl = min(head * 1.1, len * 0.6);
	vec2 q = vec2(p.x, abs(p.y));
	float shaft = max(max(hl - q.x, q.x - len), q.y - th * 0.5);
	vec2 a = vec2(0.0, 0.0);
	vec2 b = vec2(hl, head * 0.5);
	vec2 n = normalize(vec2(b.y, -b.x));
	float side = dot(q - a, -n);
	float tri = max(side, max(q.x - hl, -q.x));
	return min(shaft, tri);
}

vec4 over(vec4 u, vec3 col, float a) {
	return vec4(u.rgb * (1.0 - a) + col * a, u.a + a * (1.0 - u.a));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = clip_time - starts_at;
	if (t < 0.0) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		float slam = clamp(t / 0.18, 0.0, 1.0);
		float fly = (1.0 - slam * slam) * arrow_length * 1.5;
		float nd = nudge * max(0.0, sin(t * nudge_rate * 6.2831853)) * slam;
		float a = radians(angle);
		vec2 dir = vec2(cos(a), sin(a));
		vec2 p = (UV - tip) * vec2(asp, 1.0);
		p = vec2(dot(p, dir), dot(p, vec2(-dir.y, dir.x)));
		p.x -= fly + nd;
		float aa = 1.5 / sz.y;
		float d = arrow(p, arrow_length, thickness);
		float ds = arrow(p - vec2(0.004, 0.006), arrow_length, thickness) - outline;
		vec4 acc = over(c, vec3(0.0), (1.0 - smoothstep(-0.006, 0.012, ds)) * shadow * slam);
		acc = over(acc, outline_colour.rgb, (1.0 - smoothstep(-aa, aa, d - outline)) * outline_colour.a * step(0.0001, outline));
		acc = over(acc, colour.rgb, (1.0 - smoothstep(-aa, aa, d)) * colour.a);
		COLOR = acc;
	}
}
