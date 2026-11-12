shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_enable;
uniform sampler2D mip1 : filter_linear, repeat_enable;
uniform sampler2D mip2 : filter_linear, repeat_enable;
uniform sampler2D mip3 : filter_linear, repeat_enable;
uniform sampler2D mip4 : filter_linear, repeat_enable;
uniform sampler2D mip5 : filter_linear, repeat_enable;
uniform float tilt = 0.0;
uniform float swivel = 0.0;
uniform float roll = 0.0;
uniform float distance = 1.3737387;
uniform float fov = 40.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float scale = 1.0;
uniform int edges = 0;
uniform int quality = 1;
uniform float fog_density = 0.0;
uniform float fog_start = 1.5;
uniform vec4 fog_colour : source_color = vec4(0.62, 0.67, 0.74, 1.0);

float focal() {
	return 0.5 / tan(radians(clamp(fov, 1.0, 175.0)) * 0.5);
}

vec3 plane_depth_rotate(vec3 v, float tilt_deg, float swivel_deg, float roll_deg) {
	float t = radians(tilt_deg);
	float s = radians(swivel_deg);
	float r = radians(roll_deg);
	vec3 a = vec3(v.x, cos(t) * v.y + sin(t) * v.z, -sin(t) * v.y + cos(t) * v.z);
	vec3 b = vec3(cos(s) * a.x - sin(s) * a.z, a.y, sin(s) * a.x + cos(s) * a.z);
	return vec3(cos(r) * b.x - sin(r) * b.y, sin(r) * b.x + cos(r) * b.y, b.z);
}

mat3 plane_turn() {
	return mat3(plane_depth_rotate(vec3(1.0, 0.0, 0.0), tilt, swivel, roll), plane_depth_rotate(vec3(0.0, 1.0, 0.0), tilt, swivel, roll), plane_depth_rotate(vec3(0.0, 0.0, 1.0), tilt, swivel, roll));
}

vec4 plane_at(vec2 uv, float a, mat3 rot, float f) {
	float dist = max(distance, 0.001);
	vec3 dir = vec3(vec2((uv.x - 0.5) * a, uv.y - 0.5) / f, 1.0);
	vec3 n = rot[2];
	vec3 o = vec3(offset.x * a, offset.y, 0.0);
	vec3 cam = vec3(0.0, 0.0, -dist);
	float num = dot(o - cam, n);
	float dn = dot(dir, n);
	float lam = abs(dn) >= 0.000001 ? num / dn : -1.0;
	vec3 l = cam + dir * lam - o;
	vec2 q = vec2(dot(l, rot[0]), dot(l, rot[1])) / max(scale, 0.0001);
	return vec4(q.x / a + 0.5, q.y + 0.5, lam, dn * sign(num));
}

vec2 fold(vec2 uv) {
	if (edges == 1) {
		return fract(uv);
	}
	if (edges == 2) {
		return 1.0 - abs(mod(uv, 2.0) - 1.0);
	}
	return clamp(uv, 0.0, 1.0);
}

vec4 read_level(sampler2D tex, vec2 uv) {
	if (edges == 1) {
		return textureLod(tex, uv, 0.0);
	}
	vec2 h = 0.5 / vec2(textureSize(tex, 0));
	return textureLod(tex, clamp(uv, h, 1.0 - h), 0.0);
}

vec4 level(int k, vec2 uv) {
	if (k <= 0) {
		return read_level(effect_tex, uv);
	} else if (k == 1) {
		return read_level(mip1, uv);
	} else if (k == 2) {
		return read_level(mip2, uv);
	} else if (k == 3) {
		return read_level(mip3, uv);
	} else if (k == 4) {
		return read_level(mip4, uv);
	}
	return read_level(mip5, uv);
}

vec4 trilinear(vec2 uv, float lod) {
	vec2 w = fold(uv);
	int l0 = int(floor(lod));
	float lf = lod - float(l0);
	vec4 c = level(l0, w);
	if (lf > 0.002 && l0 < 5) {
		c = mix(c, level(l0 + 1, w), lf);
	}
	return c;
}

vec4 picture_mean() {
	vec4 s = vec4(0.0);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			s += textureLod(mip5, (vec2(float(i), float(j)) + 0.5) / 4.0, 0.0);
		}
	}
	return s / 16.0;
}

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	float a = full.x / max(full.y, 1.0);
	mat3 rot = plane_turn();
	float f = focal();
	vec4 c0 = plane_at(UV, a, rot, f);
	bool hit = c0.w > 0.0 && c0.z > 0.0;
	float hn = length(rot[2].xy);
	float hcov = hit ? 1.0 : 0.0;
	if (hn > 1e-6) {
		hcov = clamp(0.5 + c0.w * f * full.y / hn, 0.0, 1.0);
	}
	vec4 sky = vec4(0.0);
	if (edges != 0) {
		float k = clamp(fog_density * 8.0, 0.0, 1.0);
		sky = vec4(fog_colour.rgb * k, k);
	}
	if (!hit) {
		COLOR = sky;
	} else {
		vec2 px = 1.0 / full;
		vec4 cx = plane_at(UV + vec2(px.x, 0.0), a, rot, f);
		vec4 cy = plane_at(UV + vec2(0.0, px.y), a, rot, f);
		bool okx = cx.w > 0.0 && cx.z > 0.0;
		bool oky = cy.w > 0.0 && cy.z > 0.0;
		vec2 jx = okx ? (cx.xy - c0.xy) * full : vec2(1e6, 0.0);
		vec2 jy = oky ? (cy.xy - c0.xy) * full : vec2(0.0, 1e6);
		float m00 = jx.x * jx.x + jy.x * jy.x;
		float m01 = jx.x * jx.y + jy.x * jy.y;
		float m11 = jx.y * jx.y + jy.y * jy.y;
		float e = 0.5 * (m00 + m11);
		float g = sqrt(0.25 * (m00 - m11) * (m00 - m11) + m01 * m01);
		float s1 = sqrt(e + g);
		float s2 = sqrt(max(e - g, 0.0));
		vec2 v = abs(m01) > 1e-12 ? normalize(vec2(m01, e + g - m00)) : (m00 >= m11 ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
		int cap = quality <= 0 ? 4 : (quality == 1 ? 12 : 24);
		int n = 1;
		if (s1 > 1.0) {
			n = clamp(int(ceil(s1 / max(s2, 1.0) - 0.01)), 1, cap);
		}
		float foot = max(s1 / float(n), s2);
		float raw = log2(max(foot, 1e-6));
		float lod = raw < 0.02 ? 0.0 : min(raw, 5.0);
		vec2 tp = c0.xy * full;
		vec4 col = vec4(0.0);
		if (n == 1) {
			col = trilinear(c0.xy, lod);
		} else {
			for (int i = 0; i < 24; i++) {
				if (i >= n) {
					break;
				}
				float o = (float(i) + 0.5) / float(n) - 0.5;
				col += trilinear((tp + v * (s1 * o)) / full, lod);
			}
			col /= float(n);
		}
		float far = smoothstep(5.0, 6.5, raw);
		if (far > 0.0) {
			col = mix(col, picture_mean(), far);
		}
		if (edges == 0) {
			float gu = max(length(vec2(jx.x, jy.x)), 1e-6);
			float gv = max(length(vec2(jx.y, jy.y)), 1e-6);
			float su = min(c0.x, 1.0 - c0.x) * full.x / gu;
			float sv = min(c0.y, 1.0 - c0.y) * full.y / gv;
			col *= clamp(0.501 + su, 0.0, 1.0) * clamp(0.501 + sv, 0.0, 1.0);
		}
		if (fog_density > 0.0) {
			float ff = 1.0 - exp(-fog_density * max(c0.z - fog_start, 0.0));
			col.rgb = mix(col.rgb, fog_colour.rgb * col.a, ff);
		}
		COLOR = mix(sky, col, hcov);
	}
}
