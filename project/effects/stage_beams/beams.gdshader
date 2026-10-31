shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform int count : hint_range(1, 12) = 6;
uniform int palette = 0;
uniform vec4 colour_a : source_color = vec4(0.25, 0.55, 1.0, 1.0);
uniform vec4 colour_b : source_color = vec4(1.0, 0.25, 0.75, 1.0);
uniform float width : hint_range(1.0, 30.0) = 8.0;
uniform float speed : hint_range(0.0, 3.0) = 0.45;
uniform float range : hint_range(0.0, 80.0) = 32.0;
uniform float haze : hint_range(0.0, 1.0) = 0.6;
uniform int sources = 0;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform float darken : hint_range(0.0, 1.0) = 0.35;
uniform int seed = 3;

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

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k * k * (3.0 - 2.0 * k);
}

void fragment() {
	vec4 o = texture(TEXTURE, UV);
	vec2 size = max(tex_size, vec2(1.0));
	float aspect = size.x / size.y;
	vec2 uv = UV;
	if (sources == 1) {
		uv.y = 1.0 - uv.y;
	}
	vec2 p = vec2(uv.x * aspect, uv.y);
	float t = clip_time;
	vec2 sd = vec2(float(seed % 911) * 3.17, float(seed % 613) * 1.93);
	float fog = vnoise(p * 2.2 + sd + vec2(t * 0.11, -t * 0.05)) * 0.55 + vnoise(p * 5.3 + sd * 1.7 + vec2(-t * 0.19, t * 0.08)) * 0.3 + vnoise(p * 11.0 + sd * 0.3 + vec2(t * 0.3, t * 0.1)) * 0.15;
	float hz = mix(1.0, 0.3 + 1.4 * fog, clamp(haze, 0.0, 1.0));
	float body = 0.25 + 0.75 * clamp(haze, 0.0, 1.0);
	int n = clamp(count, 1, 12);
	float half_w = tan(radians(clamp(width, 1.0, 30.0)) * 0.5);
	float r0 = 0.009;
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		if (i >= n) {
			break;
		}
		float fi = float(i);
		float h1 = hash12(vec2(fi * 7.31, 3.7) + sd);
		float h2 = hash12(vec2(fi * 2.17, 11.3) + sd);
		float sx = (fi + 0.5) / float(n);
		vec2 s = vec2(sx * aspect, 0.012);
		float base = (0.5 - sx) * radians(50.0);
		float w = speed * (0.75 + 0.5 * h1) * 1.3;
		float th = base + radians(range) * sin(t * w + h2 * 6.2831853);
		vec2 dir = vec2(sin(th), cos(th));
		vec2 v = p - s;
		float a = dot(v, dir);
		float q = v.x * dir.y - v.y * dir.x;
		float bw = r0 + max(a, 0.0) * half_w;
		float prof = exp(-q * q / (bw * bw) * 1.6);
		float front = smoothstep(-r0, r0 * 0.5, a);
		float dens = pow(r0 / bw, 0.55);
		float fade = exp(-max(a, 0.0) / 1.4);
		float beam = prof * front * dens * fade * hz * body * 1.2;
		float dl = length(v);
		float lamp = exp(-dl * dl / (r0 * r0 * 2.5)) * 1.6 + exp(-dl / 0.035) * 0.35 * (0.4 + 0.6 * clamp(dot(normalize(v + vec2(0.0, 0.0001)), dir) * 0.5 + 0.5, 0.0, 1.0));
		vec3 col = colour_a.rgb;
		if (palette == 0) {
			col = hue(fi / float(n) + 0.03 * t + h1 * 0.08);
		} else if (palette == 1) {
			col = (i % 2 == 0) ? colour_a.rgb : colour_b.rgb;
		}
		sum += col * beam + mix(col, vec3(1.0), 0.6) * lamp;
	}
	vec3 light = 1.0 - exp(-sum * intensity * 1.3);
	light += (hash12(FRAGCOORD.xy + fract(t) * 97.0) - 0.5) / 255.0 * step(0.002, max(light.r, max(light.g, light.b)));
	light = max(light, vec3(0.0));
	vec3 base_c = o.rgb * (1.0 - clamp(darken, 0.0, 1.0));
	vec3 rgb = base_c + light * (vec3(o.a) - base_c);
	COLOR = vec4(clamp(rgb, 0.0, o.a), o.a);
}
