shader_type canvas_item;
render_mode blend_disabled;

uniform float ribbon_width : hint_range(2.0, 400.0) = 48.0;
uniform float ribbon_spacing : hint_range(0.0, 200.0) = 12.0;
uniform float shadow_darkness : hint_range(0.0, 1.0) = 0.75;
uniform float shadow_depth : hint_range(0.0, 1.0) = 0.75;
uniform float thread_length : hint_range(1.0, 400.0) = 200.0;
uniform float thread_density : hint_range(0.0, 1.0) = 0.5;
uniform float thread_intensity : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float threads(float along, float across, float ps, vec2 so) {
	float lane = floor(across / max(1.5 * ps, 0.5));
	if (hash12(vec2(lane, 7.7) + so) > thread_density) {
		return 0.0;
	}
	float seg_len = max(thread_length * ps, 1.0);
	float shift = hash12(vec2(lane, 19.3) + so) * seg_len;
	float u = (along + shift) / seg_len;
	float seg = floor(u);
	float f = fract(u);
	float on = step(0.45, hash12(vec2(lane, seg) + so));
	return on * sin(3.14159265 * f) * (0.5 + 0.5 * hash12(vec2(seg, lane) + so + 3.3));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float w = max(ribbon_width * ps, 1.0);
	float gap = max(ribbon_spacing * ps, 0.0);
	float period = w + gap;
	float sf = float(seed);
	vec2 so = vec2(mod(sf * 12.9898, 997.0), mod(sf * 78.233, 991.0));
	vec2 p = UV * dims;
	vec2 cell = floor(p / period);
	vec2 l = p - cell * period;
	bool in_h = l.y < w;
	bool in_v = l.x < w;
	float parity = mod(cell.x + cell.y, 2.0);
	float shade = 1.0 - shadow_darkness;
	bool horizontal = false;
	bool on_ribbon = false;
	if (in_h && in_v) {
		horizontal = parity < 0.5;
		on_ribbon = true;
	} else if (in_h) {
		horizontal = true;
		on_ribbon = true;
	} else if (in_v) {
		horizontal = false;
		on_ribbon = true;
	}
	if (on_ribbon) {
		float rise;
		float across_t;
		if (horizontal) {
			rise = cos(3.14159265 * ((p.x - 0.5 * w) / period - cell.y));
			across_t = l.y / w;
		} else {
			rise = -cos(3.14159265 * ((p.y - 0.5 * w) / period - cell.x));
			across_t = l.x / w;
		}
		float low = 0.5 - 0.5 * rise;
		shade = 1.0 - shadow_depth * 0.6 * low * low;
		shade *= mix(1.0, 0.6 + 0.4 * sin(3.14159265 * across_t), shadow_depth * 0.5);
		float t = horizontal ? threads(p.x, p.y, ps, so) : threads(p.y, p.x, ps, so + vec2(31.0, 17.0));
		shade *= 1.0 - thread_intensity * 0.35 * t;
	}
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb * clamp(shade, 0.0, 1.0), c.a);
}
