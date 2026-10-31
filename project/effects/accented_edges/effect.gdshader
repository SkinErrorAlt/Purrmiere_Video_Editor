shader_type canvas_item;
render_mode blend_disabled;

uniform float edge_width : hint_range(1.0, 14.0) = 2.0;
uniform float edge_brightness : hint_range(0.0, 50.0) = 38.0;
uniform float smoothness : hint_range(1.0, 15.0) = 5.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 unp(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 soft_at(sampler2D tex, vec2 uv, vec2 r) {
	vec3 s = unp(texture(tex, uv)) * 2.0;
	s += unp(texture(tex, clamp(uv + vec2(r.x, 0.0), vec2(0.0), vec2(1.0))));
	s += unp(texture(tex, clamp(uv - vec2(r.x, 0.0), vec2(0.0), vec2(1.0))));
	s += unp(texture(tex, clamp(uv + vec2(0.0, r.y), vec2(0.0), vec2(1.0))));
	s += unp(texture(tex, clamp(uv - vec2(0.0, r.y), vec2(0.0), vec2(1.0))));
	return s / 6.0;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = unp(c);
	float sm = clamp(smoothness, 1.0, 15.0);
	vec2 r = vec2(sm * 0.25 * ps) / dims;
	vec2 d = vec2(max(edge_width, 0.5) * 0.6 * ps) / dims;
	float tl = lum(soft_at(TEXTURE, UV - d, r));
	float tr = lum(soft_at(TEXTURE, UV + vec2(d.x, -d.y), r));
	float bl = lum(soft_at(TEXTURE, UV + vec2(-d.x, d.y), r));
	float br = lum(soft_at(TEXTURE, UV + d, r));
	float le = lum(soft_at(TEXTURE, UV - vec2(d.x, 0.0), r));
	float ri = lum(soft_at(TEXTURE, UV + vec2(d.x, 0.0), r));
	float up = lum(soft_at(TEXTURE, UV - vec2(0.0, d.y), r));
	float dn = lum(soft_at(TEXTURE, UV + vec2(0.0, d.y), r));
	float gx = tr + 2.0 * ri + br - tl - 2.0 * le - bl;
	float gy = bl + 2.0 * dn + br - tl - 2.0 * up - tr;
	float g = length(vec2(gx, gy));
	float lo = 0.04 + sm * 0.008;
	float e = smoothstep(lo, lo + 0.25 + sm * 0.02, g);
	vec3 painted = mix(rgb, soft_at(TEXTURE, UV, r * 0.6), 0.45);
	float b = (edge_brightness - 25.0) / 25.0;
	vec3 col = painted;
	if (b >= 0.0) {
		col = mix(painted, vec3(1.0), e * clamp(b * 1.15, 0.0, 1.0));
	} else {
		col = mix(painted, vec3(0.0), e * clamp(-b * 1.15, 0.0, 1.0));
	}
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.25);
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
