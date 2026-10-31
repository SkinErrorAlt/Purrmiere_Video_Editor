shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(0.72, 0.0, 0.02, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.6;
uniform float reach : hint_range(0.0, 1.0) = 0.35;
uniform int side : hint_range(0, 4) = 0;
uniform float raggedness : hint_range(0.0, 1.0) = 0.6;
uniform float veins : hint_range(0.0, 1.0) = 0.5;
uniform float darken : hint_range(0.0, 1.0) = 0.35;
uniform float hit : hint_range(0.0, 1.0) = 0.6;
uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float hit_fade : hint_range(0.05, 5.0) = 0.8;
uniform float creep : hint_range(0.0, 2.0) = 0.3;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 512.0);
	float a = hash12(w);
	float b = hash12(w + vec2(1.0, 0.0));
	float c = hash12(w + vec2(0.0, 1.0));
	float d = hash12(w + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += value_noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return sum / 0.96875;
}

float edge_distance(vec2 uv) {
	if (side == 1) {
		return uv.x * 1.5 + (uv.y - 0.5) * (uv.y - 0.5) * 0.9;
	}
	if (side == 2) {
		return (1.0 - uv.x) * 1.5 + (uv.y - 0.5) * (uv.y - 0.5) * 0.9;
	}
	if (side == 3) {
		return uv.y * 1.5 + (uv.x - 0.5) * (uv.x - 0.5) * 0.9;
	}
	if (side == 4) {
		return (1.0 - uv.y) * 1.5 + (uv.x - 0.5) * (uv.x - 0.5) * 0.9;
	}
	vec2 q = abs(uv - 0.5) * 2.0;
	vec2 q4 = q * q * q * q;
	return 1.0 - pow(q4.x + q4.y, 0.25);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float aspect = size.x / size.y;
	vec2 sk = vec2(mod(float(seed), 997.0) * 0.713 + 4.0, mod(float(seed), 991.0) * 0.377 + 9.0);
	float dt = clip_time - starts_at;
	float hf = dt >= 0.0 ? clamp(dt / max(hit_fade, 0.01), 0.0, 1.0) : 1.0;
	float hit_env = (1.0 - hf) * (1.0 - hf);
	float hit_now = clamp(hit, 0.0, 1.0) * hit_env;
	float total = clamp(amount + hit_now, 0.0, 1.5);
	float r = max(reach, 0.0) * (1.0 + 0.7 * hit_now);
	vec2 np = vec2(UV.x * aspect, UV.y) * 3.2 + sk;
	float drift = clip_time * creep * 0.25;
	float n = fbm(np + vec2(drift, -drift * 0.7));
	float d = edge_distance(UV) + (n - 0.5) * clamp(raggedness, 0.0, 1.0) * max(r, 0.05) * 1.4;
	float m = 1.0 - smoothstep(0.0, max(r, 0.001), d);
	m = pow(clamp(m, 0.0, 1.0), 1.4);
	float ridge = 1.0 - abs(fbm(np * 1.7 - vec2(drift * 0.5, drift) + 31.0) * 2.0 - 1.0);
	float vein = smoothstep(0.86, 0.97, ridge) * smoothstep(0.02, 0.5, m + 0.15 * (1.0 - smoothstep(0.0, r * 1.6 + 0.001, d)));
	float blood = clamp(m * total + vein * clamp(veins, 0.0, 1.0) * total * 0.8, 0.0, 1.0);
	vec3 under = rgb * (1.0 - clamp(darken, 0.0, 1.0) * blood);
	float lu = dot(under, vec3(0.2126, 0.7152, 0.0722));
	under = mix(under, vec3(lu), blood * 0.6);
	vec3 red = colour.rgb * (0.4 + 1.3 * lu);
	vec3 outc = mix(under, red, blood * colour.a);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
