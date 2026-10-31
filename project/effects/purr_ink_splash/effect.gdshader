shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.09, 1.0);
uniform int splashes : hint_range(1, 8) = 4;
uniform float rim : hint_range(0.0, 0.2) = 0.04;
uniform float ragged : hint_range(0.0, 1.0) = 0.5;
uniform float droplets : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	vec2 p = HN(UV);
	float asp = tex_size.x / max(tex_size.y, 1.0);
	float sd = float(seed) * 0.913;
	float d = 9.0;
	for (int i = 0; i < 8; i++) {
		if (i >= splashes) {
			break;
		}
		vec2 h = h22(vec2(float(i) * 3.7 + sd, sd + 1.3));
		vec2 cen = vec2(h.x * asp, h.y);
		float st = h12(vec2(float(i), sd)) * 0.35;
		float s = clamp((pg - st) / (1.0 - st), 0.0, 1.0);
		float r = s * s * (asp + 1.0) * 0.95;
		vec2 q = p - cen;
		float an = atan(q.y, q.x);
		float rag = (fbm(vec2(an * 2.5, float(i) * 9.1 + sd)) - 0.5) * ragged * 0.6 + (vn(q * 14.0 + sd) - 0.5) * ragged * 0.12;
		d = min(d, length(q) - r * (1.0 + rag));
	}
	vec2 dg = p * 28.0 + sd;
	vec2 di = floor(dg);
	vec2 dh = h22(di);
	float dr = (0.08 + dh.x * 0.25) * droplets * smoothstep(0.0, 0.3, pg) * step(0.82, dh.y);
	float dd = (length(fract(dg) - 0.5 - (dh - 0.5) * 0.4) - dr) / 28.0;
	float ad = d - pg * 0.25;
	d = min(d, max(dd, ad));
	float aa = 1.5 / max(tex_size.y, 1.0) * px_scale;
	float rw = rim * (1.0 - pg * 0.6);
	float hole = smoothstep(aa, -aa, d + rw);
	float k = smoothstep(aa, -aa, d) * (1.0 - hole);
	vec4 o = mix(c, vec4(ink.rgb, 1.0) * ink.a, k * ink.a);
	COLOR = pg <= 0.0 ? c : o * (1.0 - hole) * (1.0 - smoothstep(0.95, 1.0, pg));
}
