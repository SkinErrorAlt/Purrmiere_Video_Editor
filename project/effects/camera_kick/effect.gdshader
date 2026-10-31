shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform int style : hint_range(0, 2) = 0;
uniform float at : hint_range(0.0, 600.0) = 0.0;
uniform float strength : hint_range(0.0, 200.0) = 30.0;
uniform float duration : hint_range(0.05, 3.0) = 0.35;
uniform float repeat : hint_range(0.0, 10.0) = 0.0;
uniform int count : hint_range(1, 100) = 1;
uniform float direction : hint_range(-180.0, 180.0) = 0.0;
uniform float rotation : hint_range(0.0, 15.0) = 1.5;
uniform float zoom : hint_range(0.0, 20.0) = 2.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float motion_blur : hint_range(0.0, 1.0) = 0.5;
uniform int edges : hint_range(0, 2) = 0;

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

float alpha_pulse(float u, float tp) {
	float x = u / max(tp, 0.0001);
	return x * exp(1.0 - x);
}

vec4 one_kick(float u, float k) {
	if (u < 0.0) {
		return vec4(0.0);
	}
	float d = max(duration, 0.02);
	float fade = 1.0 - smoothstep(0.65 * d, d, u);
	float s = float(seed) * 7.31 + k * 13.17;
	float side = hash11(s + 0.5) < 0.5 ? -1.0 : 1.0;
	vec2 dir = vec2(sin(radians(direction)), -cos(radians(direction)));
	if (style == 1) {
		float env = exp(-u / (d * 0.3)) * clamp(u * 120.0, 0.0, 1.0) * fade;
		float f = 22.0;
		vec2 n = vec2(grad_noise(u * f + s), grad_noise(u * f + s + 57.3));
		float nr = grad_noise(u * f * 0.8 + s + 113.9);
		return vec4(n * strength * env, rotation * nr * env, zoom * env);
	}
	if (style == 2) {
		float env = abs(sin(u * PI / (d * 0.25))) * exp(-u / (d * 0.22)) * fade;
		return vec4(dir * strength * env, rotation * side * env * 0.5, zoom * env);
	}
	float tp = d * 0.12;
	float env = (alpha_pulse(u, tp) - 0.18 * alpha_pulse(u, tp * 3.5)) / 0.88 * fade;
	return vec4(-dir * strength * env, rotation * side * env, zoom * env);
}

vec4 kick_state(float t) {
	float local = t - at;
	if (local < 0.0) {
		return vec4(0.0);
	}
	float k = 0.0;
	if (repeat > 0.001 && count > 1) {
		k = min(floor(local / repeat), float(count - 1));
		local -= k * repeat;
	}
	vec4 st = one_kick(local, k);
	if (k > 0.0) {
		st += one_kick(local + repeat, k - 1.0);
	}
	return st;
}

vec2 source_uv(vec2 uv, vec4 st, vec2 size) {
	vec2 p = (uv - 0.5) * size;
	p -= st.xy * px_scale;
	float ang = -radians(st.z);
	float cs = cos(ang);
	float sn = sin(ang);
	p = vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);
	p /= max(1.0 + st.w * 0.01, 0.05);
	return p / size + 0.5;
}

vec4 fetch(sampler2D tex, vec2 uv) {
	if (edges == 2) {
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
	float shutter = clamp(motion_blur, 0.0, 1.0) / 48.0;
	int n = shutter > 0.0 ? 8 : 1;
	vec4 sum = vec4(0.0);
	float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		float dt = n > 1 ? ((float(i) + jit) / float(n) - 0.5) * shutter : 0.0;
		sum += fetch(TEXTURE, source_uv(UV, kick_state(clip_time + dt), size));
	}
	COLOR = sum / float(n);
}
