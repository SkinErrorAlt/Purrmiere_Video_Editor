shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int size : hint_range(0, 1) = 0;
uniform int channels : hint_range(0, 1) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float spread : hint_range(1.0, 4.0) = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void s2(inout vec4 a, inout vec4 b) {
	vec4 t = a;
	a = min(t, b);
	b = max(t, b);
}

vec4 med3(vec4 a, vec4 b, vec4 c) {
	return max(min(a, b), min(max(a, b), c));
}

vec4 med5(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e) {
	vec4 f = max(min(a, b), min(c, d));
	vec4 g = min(max(a, b), max(c, d));
	return med3(e, f, g);
}

vec4 med9(vec4 v0, vec4 v1, vec4 v2, vec4 v3, vec4 v4, vec4 v5, vec4 v6, vec4 v7, vec4 v8) {
	s2(v0, v3);
	s2(v1, v4);
	s2(v2, v5);
	s2(v0, v1);
	s2(v0, v2);
	s2(v4, v5);
	s2(v3, v5);
	s2(v1, v2);
	s2(v3, v4);
	s2(v1, v3);
	s2(v1, v6);
	s2(v4, v6);
	s2(v2, v6);
	s2(v2, v3);
	s2(v4, v7);
	s2(v2, v4);
	s2(v3, v7);
	s2(v4, v8);
	s2(v3, v8);
	s2(v3, v4);
	return v4;
}

vec4 pack(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	if (channels == 1) {
		return vec4(dot(rgb, LUMA), c.a, 0.0, 0.0);
	}
	return vec4(rgb, c.a);
}

void fragment() {
	vec2 px = vec2(max(spread * px_scale, 0.25)) / max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec4 m;
	if (size == 1) {
		vec4 rows[5];
		for (int j = 0; j < 5; j++) {
			float y = float(j - 2);
			vec4 t0 = pack(texture(TEXTURE, clamp(UV + px * vec2(-2.0, y), vec2(0.0), vec2(1.0))));
			vec4 t1 = pack(texture(TEXTURE, clamp(UV + px * vec2(-1.0, y), vec2(0.0), vec2(1.0))));
			vec4 t2 = pack(texture(TEXTURE, clamp(UV + px * vec2(0.0, y), vec2(0.0), vec2(1.0))));
			vec4 t3 = pack(texture(TEXTURE, clamp(UV + px * vec2(1.0, y), vec2(0.0), vec2(1.0))));
			vec4 t4 = pack(texture(TEXTURE, clamp(UV + px * vec2(2.0, y), vec2(0.0), vec2(1.0))));
			rows[j] = med5(t0, t1, t2, t3, t4);
		}
		m = med5(rows[0], rows[1], rows[2], rows[3], rows[4]);
	} else {
		vec4 t[9];
		for (int j = 0; j < 3; j++) {
			for (int i = 0; i < 3; i++) {
				vec2 off = vec2(float(i - 1), float(j - 1));
				t[j * 3 + i] = pack(texture(TEXTURE, clamp(UV + px * off, vec2(0.0), vec2(1.0))));
			}
		}
		m = med9(t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8]);
	}
	vec3 mrgb;
	float ma;
	if (channels == 1) {
		mrgb = rgb + vec3(m.x - dot(rgb, LUMA));
		ma = a;
	} else {
		mrgb = m.rgb;
		ma = m.a;
	}
	float s = clamp(strength, 0.0, 1.0);
	vec3 orgb = clamp(mix(rgb, mrgb, s), 0.0, 1.0);
	float oa = clamp(mix(a, ma, s), 0.0, 1.0);
	COLOR = vec4(orgb * oa, oa);
}
