shader_type canvas_item;
render_mode blend_disabled;

uniform float flat_angle : hint_range(-180.0, 180.0) = 45.0;
uniform int direction = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float lum(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 px = 4.0 / max(tex_size, vec2(1.0));
	float tl = lum(TEXTURE, UV + vec2(-px.x, -px.y));
	float tc = lum(TEXTURE, UV + vec2(0.0, -px.y));
	float tr = lum(TEXTURE, UV + vec2(px.x, -px.y));
	float ml = lum(TEXTURE, UV + vec2(-px.x, 0.0));
	float mr = lum(TEXTURE, UV + vec2(px.x, 0.0));
	float bl = lum(TEXTURE, UV + vec2(-px.x, px.y));
	float bc = lum(TEXTURE, UV + vec2(0.0, px.y));
	float br = lum(TEXTURE, UV + vec2(px.x, px.y));
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	float m2 = gx * gx + gy * gy;
	vec2 j = vec2(gx * gx - gy * gy, 2.0 * gx * gy) / max(m2, 0.000001);
	float conf = clamp(sqrt(m2) * 6.0, 0.0, 1.0);
	float fa = radians(flat_angle) + (direction == 0 ? 1.57079632679 : 0.0);
	vec2 flat_j = vec2(cos(2.0 * fa), sin(2.0 * fa));
	vec2 jj = j * conf + flat_j * 0.04;
	COLOR = vec4(0.5 + 0.5 * clamp(jj, vec2(-1.0), vec2(1.0)), 0.0, 1.0);
}
