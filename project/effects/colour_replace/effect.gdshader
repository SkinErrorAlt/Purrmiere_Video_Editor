shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 from : source_color = vec4(0.8, 0.1, 0.1, 1.0);
uniform vec4 to : source_color = vec4(0.1, 0.35, 0.9, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.15;
uniform float softness : hint_range(0.0, 1.0) = 0.1;
uniform int change : hint_range(0, 2) = 0;
uniform bool show_mask = false;

vec3 rgb_to_hsl(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float l = (mx + mn) * 0.5;
	float d = mx - mn;
	float h = 0.0;
	float s = 0.0;
	if (d > 0.00001) {
		s = d / max(1.0 - abs(2.0 * l - 1.0), 0.00001);
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
		h /= 6.0;
	}
	return vec3(h, clamp(s, 0.0, 1.0), l);
}

vec3 hsl_to_rgb(vec3 hsl) {
	vec3 k = mod(vec3(0.0, 8.0, 4.0) + hsl.x * 12.0, 12.0);
	float amp = hsl.y * min(hsl.z, 1.0 - hsl.z);
	return vec3(hsl.z) - amp * max(vec3(-1.0), min(min(k - 3.0, 9.0 - k), vec3(1.0)));
}

float chroma_of(vec3 c) {
	return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 hsl = rgb_to_hsl(rgb);
	vec3 from_hsl = rgb_to_hsl(clamp(from.rgb, 0.0, 1.0));
	vec3 to_hsl = rgb_to_hsl(clamp(to.rgb, 0.0, 1.0));
	float dh = abs(fract(hsl.x - from_hsl.x + 0.5) - 0.5) * 2.0;
	float hue_trust = smoothstep(0.02, 0.2, min(chroma_of(rgb), chroma_of(clamp(from.rgb, 0.0, 1.0))));
	float ds = (hsl.y - from_hsl.y) * 0.5;
	float dl = (hsl.z - from_hsl.z) * 0.5;
	float d = sqrt(dh * dh * hue_trust + ds * ds + dl * dl);
	float m = 1.0 - smoothstep(tolerance, tolerance + max(softness, 0.001), d);
	if (show_mask) {
		COLOR = vec4(vec3(m) * a, a);
	} else {
		vec3 moved = hsl;
		moved.x = fract(hsl.x + to_hsl.x - from_hsl.x);
		if (change >= 1) {
			moved.y = clamp(hsl.y + to_hsl.y - from_hsl.y, 0.0, 1.0);
		}
		if (change >= 2) {
			moved.z = clamp(hsl.z + to_hsl.z - from_hsl.z, 0.0, 1.0);
		}
		rgb = mix(rgb, hsl_to_rgb(moved), m);
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
