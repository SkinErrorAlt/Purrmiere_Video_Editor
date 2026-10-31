shader_type canvas_item;
render_mode blend_disabled;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) { break; }
		sum += value_noise(p) * amp;
		total += amp;
		p *= 2.0;
		amp *= 0.5;
	}
	return total > 0.0 ? sum / total : 0.0;
}

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float block_height : hint_range(1.0, 200.0) = 24.0;
uniform float shift : hint_range(0.0, 300.0) = 60.0;
uniform float colour_split : hint_range(0.0, 60.0) = 10.0;
uniform float burst : hint_range(0.0, 30.0) = 6.0;
uniform float block_noise : hint_range(0.0, 1.0) = 0.2;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float seed = floor(time * max(burst, 0.001));
	float bh = max(block_height * max(px_scale, 0.0001), 1.0);
	float slice = floor(UV.y * size.y / bh);
	float pick = hash12(vec2(slice, seed));
	float active = step(1.0 - amount * 0.5, pick);
	float dx = (hash12(vec2(slice, seed + 3.0)) - 0.5) * 2.0 * shift * max(px_scale, 0.0001) / size.x * active;
	vec2 uv = clamp(UV + vec2(dx, 0.0), vec2(0.0), vec2(1.0));
	float split = colour_split * max(px_scale, 0.0001) / size.x * active;
	vec4 cr = texture(TEXTURE, clamp(uv + vec2(split, 0.0), vec2(0.0), vec2(1.0)));
	vec4 cg = texture(TEXTURE, uv);
	vec4 cb = texture(TEXTURE, clamp(uv - vec2(split, 0.0), vec2(0.0), vec2(1.0)));
	float a = cg.a;
	vec3 rgb = vec3(cr.a > 0.0001 ? cr.r / cr.a : 0.0, cg.a > 0.0001 ? cg.g / cg.a : 0.0, cb.a > 0.0001 ? cb.b / cb.a : 0.0);
	float cell = hash12(vec2(floor(UV.x * size.x / bh), slice) + seed * 17.0);
	if (cell > 1.0 - block_noise * 0.15 * amount) {
		rgb = vec3(hash12(vec2(slice, cell) + seed));
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
