shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float star_size : hint_range(4.0, 80.0) = 20.0;
uniform float density : hint_range(0.0, 1.0) = 0.55;
uniform float band : hint_range(0.03, 0.4) = 0.12;
uniform float ragged : hint_range(0.0, 1.0) = 0.6;
uniform vec4 colour : source_color = vec4(1.0, 0.95, 0.82, 1.0);

float along(vec2 uv) {
	if (direction == 1) {
		return 1.0 - uv.x;
	} else if (direction == 2) {
		return uv.y;
	} else if (direction == 3) {
		return 1.0 - uv.y;
	}
	return uv.x;
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 q = tr_world(uv);
	float nz = (tr_fbm(q * 4.0) - 0.5) * ragged * 0.3;
	float soft = 0.02;
	float margin = band * 2.0 + soft + ragged * 0.15 + 0.01;
	float w = mix(-margin, 1.0 + margin, mix(p, tr_ease(p, 3), 0.4));
	float ev = along(uv) + nz;
	float rt = 1.0 - smoothstep(w - soft, w + soft, ev);
	vec4 base = mix(from_at(uv), to_at(uv), rt);
	float gap = abs(ev - w);
	float near = smoothstep(band * 2.0, band * 1.5, gap);
	if (near <= 0.0) {
		return base;
	}
	float glow = exp(-pow(gap / (band * 0.6), 2.0)) * 0.35;
	float cs = max(star_size * px_scale * 2.2, 2.0);
	vec2 pp = uv * frame_px / cs;
	vec2 own = floor(pp);
	float stars = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 k = own + vec2(float(i), float(j));
			float h = tr_hash(k + vec2(1.3, 7.9));
			if (h > density) {
				continue;
			}
			vec2 at = k + 0.2 + 0.6 * tr_hash2(k + vec2(4.4, 0.6));
			vec2 star_uv = at * cs / frame_px;
			float sd = along(star_uv) + nz;
			float pr = exp(-pow((sd - w) / band, 2.0));
			float h3 = tr_hash(k + vec2(8.2, 3.1));
			float tw = 0.45 + 0.55 * sin(p * 45.0 * (0.6 + h3) + h * 30.0);
			float radius = (0.25 + 0.2 * tr_hash(k + vec2(2.7, 5.3))) * (0.6 + 0.6 * pr);
			vec2 v = (pp - at) / radius;
			float core = exp(-dot(v, v) * 6.0);
			float rays = exp(-abs(v.x) * 12.0) * exp(-abs(v.y) * 1.4) + exp(-abs(v.y) * 12.0) * exp(-abs(v.x) * 1.4);
			vec2 vd = tr_rotate(v, TR_PI * 0.25);
			rays += 0.35 * (exp(-abs(vd.x) * 14.0) * exp(-abs(vd.y) * 3.0) + exp(-abs(vd.y) * 14.0) * exp(-abs(vd.x) * 3.0));
			stars += (core * 1.4 + rays) * pr * max(tw, 0.0);
		}
	}
	vec3 light = colour.rgb * colour.a * (stars + glow) * near;
	float a = max(base.a, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
	return vec4(clamp(base.rgb + light, vec3(0.0), vec3(a)), a);
}

void fragment() {
	COLOR = transition(UV);
}
