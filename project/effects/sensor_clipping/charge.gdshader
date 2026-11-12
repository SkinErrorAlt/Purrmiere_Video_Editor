shader_type canvas_item;
render_mode blend_disabled;

uniform float exposure : hint_range(-1.0, 6.0) = 1.5;
uniform int balance = 0;

vec3 to_lin(vec3 v) {
	vec3 lo = v / 12.92;
	vec3 hi = pow((v + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, step(v, vec3(0.04045)));
}

vec3 wb_gains(int b) {
	if (b == 1) {
		return vec3(1.35, 1.0, 2.7);
	}
	if (b == 2) {
		return vec3(1.7, 1.0, 2.1);
	}
	return vec3(2.0, 1.0, 1.5);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec3 raw = to_lin(clamp(rgb, 0.0, 1.0)) * exp2(exposure) / wb_gains(balance);
	float over = max(max(raw.r, max(raw.g, raw.b)) - 1.0, 0.0) * c.a;
	float clipped = smoothstep(0.9, 1.0, max(raw.r * wb_gains(balance).r, max(raw.g, raw.b * wb_gains(balance).b))) * c.a;
	COLOR = vec4(1.0 - exp(-over * 0.5), clipped, 0.0, 1.0);
}
