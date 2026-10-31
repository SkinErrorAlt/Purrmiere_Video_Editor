shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float horizon : hint_range(0.05, 0.95) = 0.55;
uniform float ripple_size : hint_range(0.01, 0.5) = 0.08;
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform float perspective : hint_range(0.0, 1.0) = 0.75;
uniform float speed : hint_range(0.0, 3.0) = 0.5;
uniform vec4 water_colour : source_color = vec4(0.07, 0.2, 0.27, 1.0);
uniform float water_amount : hint_range(0.0, 1.0) = 0.3;
uniform float brightness : hint_range(0.0, 1.5) = 0.82;
uniform float blur : hint_range(0.0, 40.0) = 3.0;
uniform bool keep_under = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 vnoise_d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	float v = a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
	vec2 g = du * vec2(b - a + (a - b - c + d) * u.y, c - a + (a - b - c + d) * u.x);
	return vec3(v, g);
}

vec2 slope(vec2 w, float t, float lod) {
	vec2 g = vec2(0.0);
	vec3 n = vnoise_d(w + vec2(t * 0.35, t * 0.9));
	g += n.yz;
	vec3 m = vnoise_d(w * vec2(2.1, 1.7) + vec2(-t * 0.6, t * 1.3) + vec2(13.1, 7.7));
	g += m.yz * 0.55 * 2.0 * lod;
	vec3 k = vnoise_d(w * vec2(4.3, 3.1) + vec2(t * 1.1, t * 1.9) + vec2(3.3, 21.9));
	g += k.yz * 0.3 * 4.0 * lod * lod;
	g += vec2(cos(w.y * 1.7 + w.x * 0.4 + t * 2.1), 0.3 * sin(w.x * 1.3 - t * 1.7)) * 0.35;
	return g;
}

void fragment() {
	vec4 orig = texture(TEXTURE, UV);
	float h = clamp(horizon, 0.05, 0.95);
	float d = UV.y - h;
	if (d <= 0.0) {
		COLOR = orig;
	} else {
		vec2 size = max(tex_size, vec2(1.0));
		float aspect = size.x / size.y;
		float f = clamp(d / max(1.0 - h, 0.02), 0.0, 1.0);
		float z = mix(2.0 - f, 1.0 / max(f, 0.015), clamp(perspective, 0.0, 1.0));
		vec2 plane = vec2((UV.x - 0.5) * aspect * z, z);
		vec2 w = plane / max(ripple_size, 0.005);
		float t = clip_time * speed;
		float wave_px = max(ripple_size, 0.005) / z * size.y;
		float lod = smoothstep(3.0, 14.0, wave_px);
		vec2 g = slope(w, t, lod) * smoothstep(1.5, 5.0, wave_px);
		float amp = clamp(strength, 0.0, 1.0) * 0.03 * max(ripple_size, 0.005) / 0.08 / z;
		vec2 off = vec2(g.x * amp, g.y * amp * 0.6 / z);
		float sy = h - d + off.y;
		sy = min(sy, h - 0.5 / size.y);
		vec2 suv = vec2(UV.x + off.x, sy);
		float r = blur * px_scale * (0.25 + f);
		vec4 refl = vec4(0.0);
		if (r < 0.5) {
			refl = texture(TEXTURE, clamp(suv, vec2(0.0), vec2(1.0)));
		} else {
			float wsum = 0.0;
			for (int i = 0; i < 10; i++) {
				float fi = float(i);
				float rr = i == 0 ? 0.0 : sqrt(fi / 9.0) * r;
				float an = fi * 2.39996323;
				vec2 o = vec2(cos(an) * 1.6, sin(an) * 0.6) * rr / size;
				vec2 p = suv + o;
				p.y = min(p.y, h - 0.5 / size.y);
				refl += texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0)));
				wsum += 1.0;
			}
			refl /= wsum;
		}
		float inside = smoothstep(-0.02, 0.0, sy);
		float ra = refl.a;
		vec3 rc = ra > 0.0001 ? refl.rgb / ra : vec3(0.0);
		rc *= brightness * (1.0 + clamp(g.y, -2.0, 2.0) * 0.06 * clamp(strength, 0.0, 1.0) * lod);
		float fres = clamp(water_amount, 0.0, 1.0) * (0.55 + 0.45 * f);
		float wl = dot(rc, LUMA);
		vec3 wc = water_colour.rgb * (0.75 + 0.5 * wl);
		vec3 col = mix(rc, wc, fres);
		col = mix(water_colour.rgb * 0.8, col, inside);
		float wa = mix(1.0, ra, inside);
		wa = max(wa, fres * water_colour.a);
		vec4 water = vec4(clamp(col, 0.0, 1.0) * wa, wa);
		float edge = smoothstep(0.0, 1.0 / size.y, d);
		if (keep_under) {
			water = mix(orig, water, 0.7);
		}
		COLOR = mix(orig, water, edge);
	}
}
