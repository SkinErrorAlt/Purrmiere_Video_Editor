shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 ink : source_color = vec4(0.1, 0.08, 0.14, 1.0);
uniform vec4 wall : source_color = vec4(0.82, 0.8, 0.76, 1.0);
uniform int background : hint_range(0, 2) = 0;
uniform float threshold : hint_range(0.0, 1.0) = 0.45;
uniform float overspray : hint_range(0.0, 40.0) = 8.0;
uniform float drips : hint_range(0.0, 1.0) = 0.5;
uniform float drip_len : hint_range(0.0, 300.0) = 60.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; } return s / 0.97; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }
vec2 TX(float px) { return vec2(px) * px_scale / max(tex_size, vec2(1.0)); }

float mask(sampler2D tx, vec2 uv) {
	vec4 c = texture(tx, uv);
	return smoothstep(threshold + 0.03, threshold - 0.03, lum(unp(c))) * c.a;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = mask(TEXTURE, UV);
	float bl = 0.0;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398;
		bl += mask(TEXTURE, UV + vec2(cos(an), sin(an)) * TX(overspray));
	}
	bl /= 8.0;
	vec2 P = PX(UV);
	float sp = step(1.0 - bl * 0.7, h12(floor(P)));
	float col = floor(P.x / 3.0);
	float hd = h12(vec2(col, 5.0));
	float dl = drip_len * (0.3 + 0.7 * h12(vec2(col, 9.0)));
	float dr = 0.0;
	if (hd > 1.0 - drips * 0.25) {
		for (int k = 1; k <= 6; k++) {
			float off = dl * float(k) / 6.0;
			float mk = mask(TEXTURE, UV - vec2(0.0, TX(off).y));
			dr = max(dr, step(0.5, mk) * (1.0 - float(k) / 7.0));
		}
		dr *= smoothstep(1.4, 0.6, abs(fract(P.x / 3.0) - 0.5) * 3.0);
	}
	float paint = clamp(max(m, max(sp * 0.9, step(0.3, dr))), 0.0, 1.0);
	vec3 bg = wall.rgb * (0.85 + 0.15 * fbm(P * 0.02) + 0.1 * (vn(P * 0.6) - 0.5));
	vec4 back = vec4(bg, 1.0);
	if (background == 1) {
		back = c;
	} else if (background == 2) {
		back = vec4(0.0);
	}
	COLOR = mix(back, vec4(ink.rgb, 1.0), paint * ink.a);
}
