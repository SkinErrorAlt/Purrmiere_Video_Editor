shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float amplitude : hint_range(0.0, 200.0) = 12.0;
uniform float rotation : hint_range(0.0, 30.0) = 1.0;
uniform float zoom : hint_range(0.0, 50.0) = 2.0;
uniform float frequency : hint_range(0.1, 30.0) = 2.0;
uniform int octaves : hint_range(1, 4) = 2;
uniform int seed : hint_range(0, 9999) = 0;
uniform int edges : hint_range(0, 3) = 2;
uniform float motion_blur : hint_range(0.0, 1.0) = 0.5;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec2 grad_noise(float x) {
	float i = floor(x);
	float f = x - i;
	float g0 = hash11(i) * 2.0 - 1.0;
	float g1 = hash11(i + 1.0) * 2.0 - 1.0;
	float u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float du = 30.0 * f * f * (f - 1.0) * (f - 1.0);
	float a = g0 * f;
	float b = g1 * (f - 1.0);
	float v = a + u * (b - a);
	float dv = g0 + du * (b - a) + u * (g1 - g0);
	return vec2(v, dv) * 2.0;
}

vec2 fbm1(float x) {
	vec2 sum = vec2(0.0);
	float amp = 1.0;
	float norm = 0.0;
	float mul = 1.0;
	float fx = x;
	for (int i = 0; i < 4; i++) {
		if (i >= octaves) {
			break;
		}
		vec2 n = grad_noise(fx);
		sum += vec2(n.x, n.y * mul) * amp;
		norm += amp;
		amp *= 0.5;
		mul *= 2.0;
		fx = fx * 2.0 + 17.13;
	}
	return sum / max(norm, 0.0001);
}

vec2 source_uv(vec2 uv, vec4 sh, vec2 size, float cover) {
	vec2 p = (uv - 0.5) * size;
	p -= sh.xy * amplitude * px_scale;
	float ang = -radians(rotation) * sh.z;
	float cs = cos(ang);
	float sn = sin(ang);
	p = vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);
	float z = max((1.0 + zoom * 0.01 * sh.w) * cover, 0.05);
	p /= z;
	return p / size + 0.5;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float x = clip_time * frequency;
	float s = float(seed) * 7.31;
	vec2 nx = fbm1(x + s);
	vec2 ny = fbm1(x + s + 101.7);
	vec2 nr = fbm1(x + s + 211.3);
	vec2 nz = fbm1(x + s + 317.9);
	vec4 sh = clamp(vec4(nx.x, ny.x, nr.x, nz.x), -1.0, 1.0);
	vec4 vel = vec4(nx.y, ny.y, nr.y, nz.y) * frequency;
	float cover = 1.0;
	if (edges == 2) {
		float th = radians(clamp(rotation, 0.0, 30.0));
		float cr = max((size.x * cos(th) + size.y * sin(th)) / size.x, (size.x * sin(th) + size.y * cos(th)) / size.y);
		float ct = 1.0 + 2.83 * amplitude * px_scale / min(size.x, size.y);
		float cz = 1.0 / max(1.0 - zoom * 0.01, 0.1);
		cover = cr * ct * cz;
	}
	float shutter = clamp(motion_blur, 0.0, 1.0) / 24.0;
	int n = shutter > 0.0 ? 8 : 1;
	vec4 sum = vec4(0.0);
	for (int k = 0; k < 8; k++) {
		if (k >= n) {
			break;
		}
		float dt = n > 1 ? (float(k) / float(n - 1) - 0.5) * shutter : 0.0;
		vec4 shk = clamp(sh + vel * dt, -1.2, 1.2);
		vec2 uv = source_uv(UV, shk, size, cover);
		float valid = 1.0;
		if (edges == 0) {
			vec2 m = mod(uv, 2.0);
			uv = mix(m, 2.0 - m, step(vec2(1.0), m));
		} else if (edges == 1) {
			uv = fract(uv);
		} else if (edges == 3) {
			if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
				valid = 0.0;
			}
		}
		sum += texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * valid;
	}
	COLOR = sum / float(n);
}
