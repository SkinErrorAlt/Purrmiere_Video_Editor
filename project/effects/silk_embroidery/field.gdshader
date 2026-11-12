shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

float lum(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
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
	vec3 t = vec3(gx * gx - gy * gy, 2.0 * gx * gy, gx * gx + gy * gy);
	t = t / (t.z + 0.002);
	COLOR = vec4(0.5 + 0.5 * clamp(t.xy, vec2(-1.0), vec2(1.0)), clamp(t.z, 0.0, 1.0), 1.0);
}
