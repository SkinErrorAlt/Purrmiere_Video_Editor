shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_display(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 tap(sampler2D tex, vec2 uv) {
	return to_linear(texture(tex, uv).rgb);
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec3 sum = (tap(TEXTURE, UV + px * vec2(-1.0, -1.0)) + tap(TEXTURE, UV + px * vec2(1.0, -1.0)) + tap(TEXTURE, UV + px * vec2(-1.0, 1.0)) + tap(TEXTURE, UV + px * vec2(1.0, 1.0))) * 0.125;
	sum += (tap(TEXTURE, UV + px * vec2(-2.0, -2.0)) + tap(TEXTURE, UV + px * vec2(2.0, -2.0)) + tap(TEXTURE, UV + px * vec2(-2.0, 2.0)) + tap(TEXTURE, UV + px * vec2(2.0, 2.0))) * 0.03125;
	sum += (tap(TEXTURE, UV + px * vec2(0.0, -2.0)) + tap(TEXTURE, UV + px * vec2(0.0, 2.0)) + tap(TEXTURE, UV + px * vec2(-2.0, 0.0)) + tap(TEXTURE, UV + px * vec2(2.0, 0.0))) * 0.0625;
	sum += tap(TEXTURE, UV) * 0.125;
	COLOR = vec4(to_display(sum), 1.0);
}
