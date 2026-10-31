shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float amount : hint_range(0.0, 200.0) = 16.0;
uniform float speed : hint_range(0.1, 30.0) = 5.0;
uniform float waves : hint_range(0.2, 8.0) = 1.5;
uniform float lean : hint_range(-1.0, 1.0) = 0.0;
uniform float bounce : hint_range(0.0, 1.0) = 0.3;
uniform int seed : hint_range(0, 9999) = 0;
uniform int scan : hint_range(0, 1) = 0;
uniform int edges : hint_range(0, 3) = 2;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float grad_noise(float x) {
	float i = floor(x);
	float f = x - i;
	float g0 = hash11(i) * 2.0 - 1.0;
	float g1 = hash11(i + 1.0) * 2.0 - 1.0;
	float u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(g0 * f, g1 * (f - 1.0), u) * 2.0;
}

float fbm(float x) {
	return clamp(grad_noise(x) * 0.7 + grad_noise(x * 2.03 + 17.1) * 0.3, -1.0, 1.0);
}

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 3) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return vec4(0.0);
		}
		return texture(tex, uv);
	}
	if (edges == 1) {
		return texture(tex, fract(uv));
	}
	vec2 m = mod(uv, 2.0);
	return texture(tex, clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 uv = scan == 1 ? UV.yx : UV;
	vec2 dims = scan == 1 ? size.yx : size;
	float s = float(seed) * 7.31;
	float row_time = clip_time * speed + uv.y * waves;
	float px = max(px_scale, 0.0001);
	float shift = amount * px * fbm(row_time + s);
	shift += lean * (uv.y - 0.5) * 0.3 * dims.x;
	float lift = clamp(bounce, 0.0, 1.0) * amount * 0.5 * px * fbm(row_time * 1.31 + s + 91.7);
	vec2 src = uv - vec2(shift, lift) / dims;
	if (edges == 2) {
		float mx = (amount * px + abs(lean) * 0.15 * dims.x) / dims.x;
		float my = clamp(bounce, 0.0, 1.0) * amount * 0.5 * px / dims.y;
		float z = min(1.0 + 2.0 * max(mx, my), 3.0);
		src = (src - 0.5) / z + 0.5;
	}
	COLOR = fetch(TEXTURE, scan == 1 ? src.yx : src);
}
