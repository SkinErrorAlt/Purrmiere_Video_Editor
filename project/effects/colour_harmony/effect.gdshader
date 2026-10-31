shader_type canvas_item;
render_mode blend_disabled;

uniform int scheme : hint_range(0, 4) = 0;
uniform float base_hue : hint_range(0.0, 360.0) = 30.0;
uniform float pull : hint_range(0.0, 1.0) = 0.5;
uniform float width : hint_range(0.0, 90.0) = 20.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float keep_skin : hint_range(0.0, 1.0) = 0.6;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float wrap_deg(float d) {
	return mod(d + 180.0, 360.0) - 180.0;
}

float target_offset(int i) {
	if (scheme == 0) {
		return i == 0 ? 0.0 : (i == 1 ? 180.0 : 999.0);
	}
	if (scheme == 1) {
		return i == 0 ? 0.0 : (i == 1 ? 150.0 : 210.0);
	}
	if (scheme == 2) {
		return i == 0 ? 0.0 : (i == 1 ? -30.0 : 30.0);
	}
	if (scheme == 3) {
		return i == 0 ? 0.0 : (i == 1 ? 120.0 : 240.0);
	}
	return i == 0 ? 0.0 : 999.0;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec3 hsv = rgb_to_hsv(rgb);
	float h = hsv.x * 360.0;
	float best = 1000.0;
	float second = 1000.0;
	float best_d = 0.0;
	for (int i = 0; i < 3; i++) {
		float off = target_offset(i);
		if (off > 900.0) {
			continue;
		}
		float d = wrap_deg(h - (base_hue + off));
		if (abs(d) < best) {
			second = best;
			best = abs(d);
			best_d = d;
		} else if (abs(d) < second) {
			second = abs(d);
		}
	}
	float between = second > 900.0 ? 1.0 : smoothstep(0.0, 0.4, (second - best) / max(second + best, 0.001));
	float wdt = clamp(width, 0.0, 90.0);
	float kept = min(best, wdt) + max(best - wdt, 0.0) * (1.0 - clamp(pull, 0.0, 1.0));
	float moved = sign(best_d) * kept - best_d;
	float grey = smoothstep(0.03, 0.15, hsv.y);
	float skin_d = abs(wrap_deg(h - 25.0));
	float skin = (1.0 - smoothstep(12.0, 25.0, skin_d)) * smoothstep(0.1, 0.25, hsv.y) * (1.0 - smoothstep(0.7, 0.9, hsv.y)) * smoothstep(0.15, 0.3, hsv.z);
	moved *= grey * between * (1.0 - clamp(keep_skin, 0.0, 1.0) * skin);
	vec3 outc = hsv_to_rgb(vec3(fract((h + moved) / 360.0), clamp(hsv.y * clamp(saturation, 0.0, 2.0), 0.0, 1.0), hsv.z));
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
