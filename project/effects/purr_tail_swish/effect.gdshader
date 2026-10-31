shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec4 fur : source_color = vec4(0.95, 0.6, 0.25, 1.0);
uniform float tail : hint_range(0.0, 0.4) = 0.1;
uniform float curl : hint_range(0.0, 1.0) = 0.5;
uniform float fluff : hint_range(0.0, 1.0) = 0.6;
uniform float stripes : hint_range(0.0, 1.0) = 0.4;
uniform bool reverse = false;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float x = reverse ? 1.0 - UV.x : UV.x;
	float y = UV.y;
	float pos = mix(-tail - 0.35 * curl, 1.0 + tail + 0.35 * curl, pg);
	float front = pos + curl * 0.3 * sin(y * 4.5 + pg * 4.0) * (0.5 + 0.5 * y);
	vec2 P = PX(UV);
	float fz = (fbm(vec2(P.y * 0.08, P.x * 0.01)) - 0.5) * fluff * tail * 0.6;
	float d = (x - front) * asp;
	float hole = smoothstep(0.002, -0.002, d + tail * 0.5);
	float band = smoothstep(tail * 0.5 + 0.003 + fz, tail * 0.5 + fz, abs(d)) * step(0.0005, tail);
	float tb = 0.75 + 0.25 * smoothstep(0.0, tail * 0.5 + 0.0001, tail * 0.5 - abs(d));
	float sv = smoothstep(0.55, 0.75, sin((y * 18.0 + x * 4.0 - d * 30.0)) * 0.5 + 0.5) * stripes;
	vec3 fc = fur.rgb * tb * (1.0 - sv * 0.45) * (0.9 + 0.2 * vn(P * vec2(0.6, 0.05)));
	vec4 o = c * (1.0 - hole);
	o = mix(o, vec4(fc, 1.0) * fur.a, band * fur.a * step(0.0001, pg) * step(pg, 0.9999));
	COLOR = pg <= 0.0 ? c : o;
}
