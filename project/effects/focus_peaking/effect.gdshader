shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.15;
uniform vec4 colour : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float dim : hint_range(0.0, 0.9) = 0.3;
uniform bool greyscale = true;
uniform vec2 tex_size;
uniform float px_scale;

float lu(sampler2D t, vec2 p) {
	vec4 s = texture(t, p);
	return s.a > 0.0001 ? dot(s.rgb / s.a, vec3(0.299, 0.587, 0.114)) : 0.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 e = vec2(max(px_scale, 0.0001)) / max(tex_size, vec2(1.0));
	float tl = lu(TEXTURE, UV + vec2(-e.x, -e.y));
	float t = lu(TEXTURE, UV + vec2(0.0, -e.y));
	float tr = lu(TEXTURE, UV + vec2(e.x, -e.y));
	float l = lu(TEXTURE, UV + vec2(-e.x, 0.0));
	float r = lu(TEXTURE, UV + vec2(e.x, 0.0));
	float bl = lu(TEXTURE, UV + vec2(-e.x, e.y));
	float b = lu(TEXTURE, UV + vec2(0.0, e.y));
	float br = lu(TEXTURE, UV + vec2(e.x, e.y));
	float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
	float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
	float g = length(vec2(gx, gy)) * 0.25;
	vec3 base = greyscale ? vec3(dot(rgb, vec3(0.299, 0.587, 0.114))) : rgb;
	base *= 1.0 - dim;
	float k = smoothstep(threshold, threshold + 0.03, g);
	vec3 o = mix(base, colour.rgb, k * colour.a);
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
