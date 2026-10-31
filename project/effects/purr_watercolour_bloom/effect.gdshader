shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int timing : hint_range(0, 2) = 0;
uniform float auto_len : hint_range(0.05, 10.0) = 1.0;
uniform vec4 pigment : source_color = vec4(0.3, 0.45, 0.75, 1.0);
uniform int blooms : hint_range(1, 10) = 5;
uniform float rim : hint_range(0.0, 0.2) = 0.04;
uniform float feather : hint_range(0.0, 0.2) = 0.03;
uniform float ragged : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float clip_duration = 10.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 HN(vec2 uv) { return vec2(uv.x * tex_size.x / max(tex_size.y, 1.0), uv.y); }
float PG() { if (timing == 1) { return 1.0 - clamp(clip_time / max(auto_len, 0.01), 0.0, 1.0); } if (timing == 2) { return clamp((clip_time - clip_duration + auto_len) / max(auto_len, 0.01), 0.0, 1.0); } return progress; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pg = PG();
	float asp = tex_size.x / max(tex_size.y, 1.0);
	vec2 p = HN(UV);
	float sd = float(seed) * 0.711;
	float d = 9.0;
	for (int i = 0; i < 10; i++) {
		if (i >= blooms) {
			break;
		}
		vec2 h = h22(vec2(float(i) * 2.9 + sd, sd + 0.7));
		float st = h12(vec2(float(i), sd + 4.0)) * 0.4;
		float s = clamp((pg - st) / (1.0 - st), 0.0, 1.0);
		float r = s * s * (asp + 1.0) * 0.9;
		vec2 q = p - vec2(h.x * asp, h.y);
		float an = atan(q.y, q.x);
		float rag = (fbm(vec2(an * 1.5, float(i) * 4.0 + sd) + length(q) * 3.0) - 0.5) * ragged * 0.5;
		d = min(d, length(q) - r * (1.0 + rag));
	}
	float f = max(feather, 0.002);
	float hole = smoothstep(f, -f, d + rim) * step(0.0001, pg);
	float gran = 0.75 + 0.5 * vn(PX(UV) * 0.4);
	float ring = smoothstep(rim + f, rim * 0.3, abs(d + rim * 0.5)) * step(0.0001, pg) * (1.0 - smoothstep(0.9, 1.0, pg));
	vec4 o = c * (1.0 - hole);
	vec3 pc = pigment.rgb * gran;
	float pa = clamp(ring * pigment.a * 0.85, 0.0, 1.0);
	o = vec4(pc * pa, pa) + o * (1.0 - pa);
	COLOR = pg <= 0.0 ? c : o;
}
