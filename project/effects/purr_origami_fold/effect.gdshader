shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform int panels : hint_range(2, 20) = 6;
uniform float shade : hint_range(0.0, 1.0) = 0.6;
uniform float bulge : hint_range(0.0, 0.5) = 0.12;
uniform int direction : hint_range(0, 3) = 0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	float pg = PG();
	vec2 uv = UV;
	if (direction == 1) { uv.x = 1.0 - uv.x; }
	if (direction == 2) { uv = uv.yx; }
	if (direction == 3) { uv = vec2(1.0 - uv.y, uv.x); }
	float w = max(1.0 - pg, 0.0001);
	float n = float(panels);
	float u = uv.x / w * n;
	float i = floor(u);
	float f = fract(u);
	float face = mod(i, 2.0);
	float tri = face < 0.5 ? f : 1.0 - f;
	float sy = 1.0 + pg * bulge * tri * 2.0;
	vec2 s = vec2(uv.x / w, 0.5 + (uv.y - 0.5) / sy);
	if (direction == 1) { s.x = 1.0 - s.x; }
	if (direction == 2) { s = s.yx; }
	if (direction == 3) { s = vec2(s.y, 1.0 - s.x); }
	vec4 c = texture(TEXTURE, s);
	float inside = step(uv.x, w) * step(0.0, s.y) * step(s.y, 1.0) * step(0.0, s.x) * step(s.x, 1.0);
	float lit = face < 0.5 ? 1.0 + pg * shade * 0.25 * (1.0 - f) : 1.0 - pg * shade * (0.5 + 0.3 * f);
	vec4 o = vec4(clamp(c.rgb * lit, vec3(0.0), vec3(c.a)), c.a) * inside;
	COLOR = pg <= 0.0 ? texture(TEXTURE, UV) : o;
}
