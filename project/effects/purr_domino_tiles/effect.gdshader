shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform int strips : hint_range(2, 40) = 12;
uniform int direction : hint_range(0, 3) = 0;
uniform float overlap : hint_range(0.0, 1.0) = 0.6;
uniform float shade : hint_range(0.0, 1.0) = 0.6;
uniform float clip_time;
uniform float clip_duration = 10.0;

float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	float pg = PG();
	vec2 uv = UV;
	if (direction == 1) { uv.x = 1.0 - uv.x; }
	if (direction == 2) { uv = uv.yx; }
	if (direction == 3) { uv = vec2(1.0 - uv.y, uv.x); }
	float n = float(strips);
	float i = floor(uv.x * n);
	float st = i / n * overlap;
	float s = clamp((pg - st) / max(1.0 - overlap, 0.05), 0.0, 1.0);
	float ang = s * 1.5708;
	float k = cos(ang);
	float y = 1.0 - (1.0 - uv.y) / max(k, 0.0001);
	vec2 src = vec2(uv.x, y);
	if (direction == 1) { src.x = 1.0 - src.x; }
	if (direction == 2) { src = src.yx; }
	if (direction == 3) { src = vec2(src.y, 1.0 - src.x); }
	vec4 c = texture(TEXTURE, src);
	float inside = step(0.0, y) * step(s, 0.999);
	vec4 o = vec4(c.rgb * (1.0 - sin(ang) * shade), c.a) * inside;
	COLOR = pg <= 0.0 ? texture(TEXTURE, UV) : o;
}
