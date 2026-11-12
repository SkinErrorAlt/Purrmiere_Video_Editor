shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0.7;
uniform float colour_bias : hint_range(0.0, 1.0) = 0.5;

float peak(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return max(rgb.r, max(rgb.g, rgb.b)) * c.a;
}

vec3 emission(vec4 c, float around) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float mn = min(rgb.r, min(rgb.g, rgb.b));
	float sat = mx > 0.0001 ? (mx - mn) / mx : 0.0;
	float hi = mix(threshold, 1.0, 0.45) + 0.03;
	float m = smoothstep(threshold, hi, mx) * mix(1.0, smoothstep(0.12, 0.6, sat), colour_bias);
	float standout = smoothstep(0.03, 0.3, mx - around);
	return rgb * m * mix(1.0, standout, 0.75) * c.a;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float aspect = size.y / size.x;
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.3;
		vec2 d = vec2(cos(a) * aspect, sin(a));
		around += peak(texture(TEXTURE, UV + d * 0.05));
		around += peak(texture(TEXTURE, UV + d * 0.14));
	}
	around /= 16.0;
	vec2 px = 0.5 / size;
	vec4 c0 = texture(TEXTURE, UV + vec2(-px.x, -px.y));
	vec4 c1 = texture(TEXTURE, UV + vec2(px.x, -px.y));
	vec4 c2 = texture(TEXTURE, UV + vec2(-px.x, px.y));
	vec4 c3 = texture(TEXTURE, UV + vec2(px.x, px.y));
	float lum = dot((c0.rgb + c1.rgb + c2.rgb + c3.rgb) * 0.25, vec3(0.2126, 0.7152, 0.0722));
	vec3 e = emission(texture(TEXTURE, UV + vec2(-px.x, -px.y)), around);
	e += emission(texture(TEXTURE, UV + vec2(px.x, -px.y)), around);
	e += emission(texture(TEXTURE, UV + vec2(-px.x, px.y)), around);
	e += emission(texture(TEXTURE, UV + vec2(px.x, px.y)), around);
	COLOR = vec4(pow(clamp(e * 0.0625, 0.0, 1.0), vec3(1.0 / 3.0)), sqrt(clamp(lum, 0.0, 1.0)));
}
