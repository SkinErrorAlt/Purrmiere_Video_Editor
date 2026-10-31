shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float amount : hint_range(-100.0, 100.0) = 20.0;
uniform float softness : hint_range(0.5, 30.0) = 3.0;
uniform int direction : hint_range(0, 2) = 0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float lum(vec4 c) {
	return dot(c.rgb, LUMA);
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 d = vec2(max(softness * ps, 0.5)) / size;
	float tl = lum(texture(TEXTURE, clamp(UV + vec2(-d.x, -d.y), vec2(0.0), vec2(1.0))));
	float tc = lum(texture(TEXTURE, clamp(UV + vec2(0.0, -d.y), vec2(0.0), vec2(1.0))));
	float tr = lum(texture(TEXTURE, clamp(UV + vec2(d.x, -d.y), vec2(0.0), vec2(1.0))));
	float ml = lum(texture(TEXTURE, clamp(UV + vec2(-d.x, 0.0), vec2(0.0), vec2(1.0))));
	float mr = lum(texture(TEXTURE, clamp(UV + vec2(d.x, 0.0), vec2(0.0), vec2(1.0))));
	float bl = lum(texture(TEXTURE, clamp(UV + vec2(-d.x, d.y), vec2(0.0), vec2(1.0))));
	float bc = lum(texture(TEXTURE, clamp(UV + vec2(0.0, d.y), vec2(0.0), vec2(1.0))));
	float br = lum(texture(TEXTURE, clamp(UV + vec2(d.x, d.y), vec2(0.0), vec2(1.0))));
	float gx = ((tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl)) * 0.25;
	float gy = ((bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr)) * 0.25;
	vec2 g = vec2(gx, gy);
	if (direction == 1) {
		g.y = 0.0;
	} else if (direction == 2) {
		g.x = 0.0;
	}
	vec2 off = g * amount * ps / size;
	COLOR = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
}
