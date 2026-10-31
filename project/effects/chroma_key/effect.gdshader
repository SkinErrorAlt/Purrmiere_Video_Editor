shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 key_colour : source_color = vec4(0.1, 0.85, 0.15, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.0, 1.0) = 0.15;
uniform float spill : hint_range(0.0, 1.0) = 0.5;
uniform bool show_matte = false;

vec2 chroma_of(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	return vec2(c.b - y, c.r - y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 kc = chroma_of(key_colour.rgb);
	vec2 pc = chroma_of(rgb);
	float d = distance(kc, pc) / max(length(kc), 0.1);
	float matte = smoothstep(tolerance, tolerance + max(softness, 0.001), d);
	float key_g = key_colour.g;
	vec3 sup = rgb;
	if (key_g > max(key_colour.r, key_colour.b)) {
		float lim = max(rgb.r, rgb.b);
		sup.g = mix(rgb.g, min(rgb.g, lim), spill);
	} else if (key_colour.b > max(key_colour.r, key_colour.g)) {
		float lim = max(rgb.r, rgb.g);
		sup.b = mix(rgb.b, min(rgb.b, lim), spill);
	}
	float a = c.a * matte;
	if (show_matte) {
		COLOR = vec4(vec3(matte), 1.0);
	} else {
		COLOR = vec4(clamp(sup, 0.0, 1.0) * a, a);
	}
}
