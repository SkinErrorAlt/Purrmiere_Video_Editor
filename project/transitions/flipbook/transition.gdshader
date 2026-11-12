shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float fps : hint_range(2.0, 24.0) = 8.0;
uniform float drift : hint_range(0.0, 1.0) = 0.55;
uniform float jitter : hint_range(0.0, 1.0) = 0.45;
uniform float curl : hint_range(0.02, 0.4) = 0.12;
uniform float back : hint_range(0.0, 1.0) = 0.5;
uniform bool flip_left = false;
uniform float lean : hint_range(0.0, 0.5) = 0.2;

vec4 fb_page(vec2 uv, float idx, float n, float amt) {
	float tt = clamp(idx / max(n - 1.0, 1.0), 0.0, 1.2);
	float ko = clamp(tt, 0.0, 1.0) - 0.5;
	vec2 j = (tr_hash2(vec2(idx, 9.1) + seed) - 0.5) * 0.016 * jitter * amt;
	float ja = (tr_hash(vec2(idx, 3.4) + seed) - 0.5) * 0.012 * jitter * amt;
	float zoom = 1.0 + ko * 0.22 * drift * amt;
	vec2 pan = vec2(0.1, 0.055) * ko * drift * amt;
	vec2 ar = vec2(tr_ratio(), 1.0);
	vec2 d = (uv - vec2(0.5)) * ar;
	float cs = cos(ja);
	float sn = sin(ja);
	vec2 r2 = vec2(cs * d.x - sn * d.y, sn * d.x + cs * d.y) / max(zoom, 0.2);
	vec2 su = clamp(vec2(0.5) + r2 / ar + j + pan, vec2(0.0), vec2(1.0));
	return tt < 0.5 ? from_clamped(su) : to_clamped(su);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	if (p >= 1.0) {
		return to_at(uv);
	}
	float dur = duration > 0.01 ? duration : 1.2;
	float n = clamp(floor(max(fps, 2.0) * dur + 0.5), 2.0, 48.0);
	float t = p * n;
	float idx = floor(t);
	float f = fract(t);
	float ff = smoothstep(0.0, 1.0, clamp(f / 0.6, 0.0, 1.0));
	float jit = jitter * smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.93, 1.0, p));
	vec2 o = flip_left ? vec2(1.0 - uv.x, uv.y) : uv;
	float skew = (o.y - 0.5) * lean * (1.0 - ff);
	float hinge = 1.0 - ff + skew;
	float c = max(curl, 0.02);
	vec4 below = fb_page(uv, idx + 1.0, n, jit);
	if (o.x > hinge + c) {
		float shade = smoothstep(c * 2.4, 0.0, o.x - hinge - c) * 0.45;
		below.rgb *= 1.0 - shade;
		return below;
	}
	if (o.x > hinge) {
		float u = (o.x - hinge) / c;
		float bendy = sqrt(max(1.0 - u * u, 0.0));
		float src_x = hinge - (asin(clamp(u, 0.0, 1.0)) / 1.5707963) * c;
		vec2 suv = flip_left ? vec2(1.0 - clamp(src_x, 0.0, 1.0), uv.y) : vec2(clamp(src_x, 0.0, 1.0), uv.y);
		vec4 face = fb_page(suv, idx, n, jit);
		float light = mix(0.35, 1.0, bendy);
		face.rgb = mix(face.rgb * light, vec3(0.92, 0.9, 0.86) * mix(0.4, 1.0, bendy), back * 0.85);
		return face;
	}
	vec4 top = fb_page(uv, idx, n, jit);
	float near = smoothstep(c * 1.6, 0.0, hinge - o.x) * 0.3;
	top.rgb *= 1.0 - near;
	return top;
}

void fragment() {
	COLOR = transition(UV);
}
