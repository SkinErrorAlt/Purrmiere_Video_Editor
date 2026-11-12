shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float lights_only : hint_range(0.0, 1.0) = 0.4;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 source_of(vec3 lin) {
	float t0 = clamp(lights_only, 0.0, 1.0) * 0.55;
	float w = t0 <= 0.0005 ? 1.0 : smoothstep(t0, t0 + 0.3, dot(lin, LUMA));
	return lin * w;
}

void fragment() {
	vec2 px = 0.5 / max(tex_size, vec2(1.0));
	vec3 sum = vec3(0.0);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec4 c = texture(TEXTURE, UV + px * (vec2(float(i), float(j)) * 2.0 - 1.0));
			vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
			sum += source_of(to_linear(rgb)) * c.a;
		}
	}
	COLOR = vec4(to_display(sum * 0.25), 1.0);
}
