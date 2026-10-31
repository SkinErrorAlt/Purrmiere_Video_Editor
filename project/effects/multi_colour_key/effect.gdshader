shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour_1 : source_color = vec4(0.12, 0.72, 0.28, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.05, 0.4, 0.14, 1.0);
uniform bool use_2 = true;
uniform vec4 colour_3 : source_color = vec4(0.15, 0.3, 0.85, 1.0);
uniform bool use_3 = false;
uniform float chroma_tolerance : hint_range(0.0, 1.0) = 0.45;
uniform float luma_tolerance : hint_range(0.0, 1.0) = 0.4;
uniform float softness : hint_range(0.0, 1.0) = 0.15;
uniform float despill : hint_range(0.0, 1.0) = 0.5;
uniform bool show_matte = false;

vec3 ycc(vec3 c) {
	float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return vec3(y, (c.b - y) / 1.8556, (c.r - y) / 1.5748);
}

float keyed_by(vec3 p, vec3 k) {
	vec3 a = ycc(p);
	vec3 b = ycc(k);
	float dc = length(a.yz - b.yz) / max(length(b.yz), 0.05) / max(chroma_tolerance, 0.001);
	float dl = abs(a.x - b.x) / max(luma_tolerance, 0.001);
	float d = length(vec2(dc, dl));
	float soft = softness * 4.0;
	if (soft < 0.0005) {
		return d <= 1.0 ? 1.0 : 0.0;
	}
	return 1.0 - smoothstep(1.0, 1.0 + soft, d);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	float keyed = keyed_by(rgb, colour_1.rgb);
	if (use_2) {
		keyed = max(keyed, keyed_by(rgb, colour_2.rgb));
	}
	if (use_3) {
		keyed = max(keyed, keyed_by(rgb, colour_3.rgb));
	}
	vec3 k = colour_1.rgb;
	vec3 fixed_rgb = rgb;
	if (k.g >= k.r && k.g >= k.b) {
		fixed_rgb.g = min(rgb.g, max(rgb.r, rgb.b));
	} else if (k.b >= k.r && k.b >= k.g) {
		fixed_rgb.b = min(rgb.b, max(rgb.r, rgb.g));
	} else {
		fixed_rgb.r = min(rgb.r, max(rgb.g, rgb.b));
	}
	rgb = mix(rgb, fixed_rgb, despill);
	float a = clamp(c.a * (1.0 - keyed), 0.0, 1.0);
	if (show_matte) {
		COLOR = vec4(vec3(a), 1.0);
	} else {
		COLOR = vec4(rgb * a, a);
	}
}
