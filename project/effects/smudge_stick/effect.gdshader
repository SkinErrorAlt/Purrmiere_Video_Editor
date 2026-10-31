shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke_length : hint_range(1.0, 40.0) = 18.0;
uniform float highlight_area : hint_range(0.0, 20.0) = 4.0;
uniform float intensity : hint_range(0.0, 10.0) = 3.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float a = texture(TEXTURE, UV).a;
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps;
	float len = max(stroke_length, 1.0);
	vec2 cell = floor(pix / max(len * 0.7, 1.0));
	float ang = radians(angle) + (hash12(cell + so) - 0.5) * 0.5;
	vec2 dir = vec2(cos(ang), -sin(ang));
	vec2 su = dir * len * ps / dims;
	vec3 wl = vec3(0.2126, 0.7152, 0.0722);
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int i = -4; i <= 4; i++) {
		vec4 s = texture(TEXTURE, UV + su * float(i) / 8.0);
		vec3 rgb = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
		float w = exp(-dot(rgb, wl) * 6.0) * (1.0 - abs(float(i)) / 5.0);
		sum += s * w;
		total += w;
	}
	vec4 avg = sum / max(total, 0.0001);
	vec3 rgb = avg.a > 0.0001 ? avg.rgb / avg.a : vec3(0.0);
	float line = floor(dot(pix, vec2(-dir.y, dir.x)) / 1.5);
	rgb *= 1.0 + (hash12(vec2(line, cell.x * 7.0 + cell.y) + so) - 0.5) * 0.2;
	rgb = clamp((rgb - 0.5) * 1.08 + 0.5, 0.0, 1.0);
	float t = 1.0 - highlight_area / 20.0 * 0.55;
	float hl = smoothstep(t - 0.12, t + 0.05, dot(rgb, wl));
	rgb = mix(rgb, mix(rgb, vec3(1.0), 0.6), hl * clamp(0.25 + intensity * 0.075, 0.0, 1.0));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
