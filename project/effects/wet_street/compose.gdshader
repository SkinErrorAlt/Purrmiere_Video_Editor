shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform float horizon : hint_range(0.05, 0.95) = 0.62;
uniform float strength : hint_range(0.0, 3.0) = 1.2;
uniform float ripples : hint_range(0.0, 1.0) = 0.6;
uniform float ripple_size : hint_range(0.0, 1.0) = 0.5;
uniform float wetness : hint_range(0.0, 1.0) = 0.5;
uniform float scene : hint_range(0.0, 1.0) = 0.25;
uniform float speed : hint_range(0.0, 3.0) = 0.2;
uniform int seed : hint_range(0, 9999) = 3;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = vnoise(p) * 0.55;
	s += vnoise(p * 2.13 + vec2(5.2, 1.3)) * 0.28;
	s += vnoise(p * 4.37 + vec2(1.7, 9.2)) * 0.17;
	return s;
}

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

vec3 smooth_sample(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 inv = 1.0 / size;
	vec2 p = uv * size - 0.5;
	vec2 fxy = fract(p);
	p -= fxy;
	vec4 xc = cubic(fxy.x);
	vec4 yc = cubic(fxy.y);
	vec4 c = p.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 off = c + vec4(xc.yw, yc.yw) / s;
	off *= inv.xxyy;
	vec3 s0 = texture(tex, off.xz).rgb;
	vec3 s1 = texture(tex, off.yz).rgb;
	vec3 s2 = texture(tex, off.xw).rgb;
	vec3 s3 = texture(tex, off.yw).rgb;
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	vec3 r = mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
	return r * r;
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec3 rgb = o.a > 0.0001 ? o.rgb / o.a : vec3(0.0);
	float h = clamp(horizon, 0.05, 0.95);
	float d = UV.y - h;
	if (d <= 0.0) {
		COLOR = o;
	} else {
		vec2 size = vec2(textureSize(effect_tex, 0));
		float aspect = size.x / max(size.y, 1.0);
		float f = clamp(d / max(1.0 - h, 0.02), 0.0, 1.0);
		float z = 1.0 / (f + 0.04);
		vec2 so = vec2(mod(float(seed) * 12.9898, 97.0), mod(float(seed) * 78.233, 89.0));
		float t = clip_time * speed;
		float sc = mix(3.0, 0.6, clamp(ripple_size, 0.0, 1.0));
		vec2 plane = vec2((UV.x - 0.5) * aspect * z, z);
		float wob = fbm(vec2(plane.x * 1.6, plane.y * 6.0) * sc + so + vec2(t * 0.3, t));
		float wob2 = fbm(vec2(plane.x * 4.0, plane.y * 15.0) * sc + so.yx + vec2(-t * 0.5, t * 1.7));
		float shift = ((wob - 0.5) * 0.9 + (wob2 - 0.5) * 0.5) * ripples * 0.028 / sqrt(z);
		float ys = h - d;
		vec2 ruv = vec2(UV.x + shift, ys);
		vec3 refl = smooth_sample(TEXTURE, ruv);
		float glint = fbm(vec2(plane.x * 3.6, plane.y * 15.0) * sc + so * 1.7 + vec2(t * 0.2, t * 2.3));
		float gaps = smoothstep(0.28, 0.62, glint);
		float broken = mix(1.0, gaps * 1.7, clamp(ripples, 0.0, 1.0));
		float fresnel = mix(1.0, 0.3, pow(f, 0.8));
		float feather = smoothstep(0.0, 0.006, d);
		float lum = dot(rgb, LUMA);
		float dark_ground = 1.0 - smoothstep(0.25, 0.9, lum) * 0.75;
		float w = clamp(wetness, 0.0, 1.0) * smoothstep(0.0, 0.05, d);
		vec3 wet = rgb * (1.0 - w * 0.45);
		float wl = dot(wet, LUMA);
		wet = max(mix(vec3(wl), wet, 1.0 + w * 0.3), vec3(0.0));
		vec3 mirror = vec3(0.0);
		float stepy = 0.004 + 0.012 * f;
		for (int i = 0; i < 5; i++) {
			float k = float(i) - 2.0;
			vec2 muv = vec2(UV.x + shift * 0.7, clamp(ys - k * stepy, 0.0, h - 0.5 / size.y));
			vec4 m = texture(effect_tex, muv);
			mirror += (m.a > 0.0001 ? m.rgb / m.a : vec3(0.0)) * (3.0 - abs(k));
		}
		mirror /= 9.0;
		vec3 add = refl * strength * broken * fresnel * dark_ground;
		add += mirror * scene * w * fresnel * dark_ground * 0.6;
		vec3 base = clamp(wet, 0.0, 1.0);
		vec3 room = max(1.0 - base, vec3(0.001));
		vec3 outc = base + room * (1.0 - exp(-max(add * feather, vec3(0.0)) / room));
		COLOR = vec4(outc * o.a, o.a);
	}
}
