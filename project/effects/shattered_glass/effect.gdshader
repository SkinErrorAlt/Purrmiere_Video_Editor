shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 impact = vec2(0.42, 0.45);
uniform float spread : hint_range(0.05, 1.5) = 0.7;
uniform int cracks : hint_range(4, 40) = 16;
uniform float rings : hint_range(0.0, 1.0) = 0.6;
uniform float shift : hint_range(0.0, 60.0) = 7.0;
uniform float crack_width : hint_range(0.0, 8.0) = 1.4;
uniform float shine : hint_range(0.0, 1.0) = 0.6;
uniform float tint : hint_range(0.0, 1.0) = 0.25;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float noise1(float x, float key) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float w = mod(i, 1024.0);
	return mix(hash12(vec2(w, key)), hash12(vec2(w + 1.0, key)), f);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 512.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

float straight_boundary(float k, float n, vec2 sk) {
	float kw = mod(k, n);
	return k + 0.5 + (hash12(vec2(kw, 1.0) + sk) - 0.5) * 0.6;
}

float boundary(float k, float n, float r, float ps, vec2 sk) {
	float wob = (noise1(r / (38.0 * ps), mod(k, n) * 7.3 + sk.x) - 0.5) * 9.0 * ps;
	return straight_boundary(k, n, sk) + wob / max(r, 1.0) / 6.2831853 * n;
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 sk = vec2(mod(float(seed), 997.0) * 0.917 + 3.0, mod(float(seed), 991.0) * 0.531 + 8.0);
	vec2 pix = UV * sz;
	vec2 d = pix - impact * sz;
	float r = length(d);
	float ang = r > 0.001 ? atan(d.y, d.x) : 0.0;
	float n = float(clamp(cracks, 4, 40));
	float x = (ang / 6.2831853 + 0.5) * n;
	float k0 = floor(x);
	float reach = max(spread, 0.01) * length(sz);
	float sector = k0 - 1.0;
	float crack_d = 1e6;
	for (int i = -1; i <= 2; i++) {
		float k = k0 + float(i);
		float b = boundary(k, n, r, ps, sk);
		if (x >= b) {
			sector = k;
		}
		float len_k = reach * (0.5 + 0.65 * hash12(vec2(mod(k, n), 4.0) + sk));
		float on = 1.0 - smoothstep(len_k * 0.8, len_k, r);
		float dpx = abs(x - b) / n * 6.2831853 * r;
		if (on > 0.001) {
			crack_d = min(crack_d, dpx / on);
		}
	}
	float sw = mod(sector, n);
	float b0 = straight_boundary(sector, n, sk);
	float b1 = straight_boundary(sector + 1.0, n, sk);
	float mid_ang = ((b0 + b1) * 0.5 / n - 0.5) * 6.2831853;
	float half_span = (b1 - b0) / n * 3.14159265;
	int ring_count = int(1.0 + clamp(rings, 0.0, 1.0) * 5.0);
	float ring_index = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= ring_count) {
			break;
		}
		vec3 h = hash32(vec2(sw, float(i) + 20.0) + sk);
		float ta = mid_ang + (h.z - 0.5) * half_span * 0.7;
		float proj = dot(d, vec2(cos(ta), sin(ta)));
		float rr = reach * pow((float(i) + 0.55 + (h.x - 0.5) * 0.5) / (float(ring_count) + 0.6), 1.35);
		if (proj > rr) {
			ring_index = float(i) + 1.0;
		}
		if (h.y < 0.35 + 0.65 * clamp(rings, 0.0, 1.0)) {
			crack_d = min(crack_d, abs(proj - rr));
		}
	}
	float inside = 1.0 - smoothstep(reach * 0.95, reach * 1.1, r);
	vec3 hs = hash32(vec2(sw * 7.0 + ring_index, ring_index * 3.0 + 1.0) + sk);
	vec2 off = ((hs.xy - 0.5) * 2.0 * max(shift, 0.0) * ps + (r > 0.001 ? d / r : vec2(0.0)) * max(shift, 0.0) * ps * 0.4) * inside;
	vec4 c = texture(TEXTURE, clamp((pix + off) / sz, vec2(0.0), vec2(1.0)));
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float t = clamp(tint, 0.0, 1.0) * inside;
	rgb = mix(rgb, rgb * vec3(0.93, 1.0, 1.05) * (0.8 + 0.4 * hs.z), t);
	float cw = max(crack_width, 0.0) * ps;
	float core = 1.0 - smoothstep(cw * 0.5, cw * 0.5 + 0.8, crack_d);
	core *= clamp(cw * 1.5, 0.0, 1.0);
	float halo = exp(-max(crack_d - cw * 0.5, 0.0) / (1.2 * ps + cw * 0.8)) * clamp(cw + 0.3, 0.0, 1.0);
	rgb *= 1.0 - 0.55 * core;
	rgb += (1.0 - rgb) * halo * clamp(shine, 0.0, 1.0) * 0.75 * (1.0 - core * 0.6);
	float crush = 1.0 - smoothstep(reach * 0.02, reach * 0.075, r);
	float tiny = 1.0 - abs(value_noise(d / (4.0 * ps) + sk) * 2.0 - 1.0);
	rgb = mix(rgb, vec3(0.92, 0.96, 1.0), crush * smoothstep(0.75, 0.95, tiny) * 0.8 + crush * 0.15);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
