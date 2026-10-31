shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 keep : source_color = vec4(0.85, 0.1, 0.1, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.08;
uniform float softness : hint_range(0.0, 1.0) = 0.05;
uniform float desaturate : hint_range(0.0, 1.0) = 1.0;
uniform int match : hint_range(0, 1) = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hue_of(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.00001) {
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
		h /= 6.0;
	}
	return h;
}

float chroma_of(vec3 c) {
	return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 target = clamp(keep.rgb, 0.0, 1.0);
	float soft = max(softness, 0.001);
	float kept;
	if (match == 1) {
		float d = length(rgb - target) * 0.57735027;
		kept = 1.0 - smoothstep(tolerance, tolerance + soft, d);
	} else {
		float dh = abs(fract(hue_of(rgb) - hue_of(target) + 0.5) - 0.5) * 2.0;
		kept = 1.0 - smoothstep(tolerance, tolerance + soft, dh);
		kept *= smoothstep(0.03, 0.15, chroma_of(rgb));
	}
	vec3 grey = vec3(dot(rgb, LUMA));
	rgb = mix(rgb, grey, desaturate * (1.0 - kept));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
