shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float dot_size : hint_range(2.0, 40.0) = 6.0;
uniform float angle : hint_range(0.0, 90.0) = 15.0;
uniform float punch : hint_range(0.0, 1.0) = 0.55;
uniform float edges : hint_range(0.0, 1.0) = 0.6;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

mat2 rot(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

float halftone(vec2 uvpx, float a, float amt, float cell) {
	vec2 p = (rot(a) * uvpx) / cell;
	vec2 g = fract(p) - 0.5;
	float d = length(g) * 2.0;
	float r = sqrt(clamp(amt, 0.0, 1.0));
	return 1.0 - smoothstep(r - 0.18, r + 0.18, d);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	vec4 src4 = texture(TEXTURE, UV);
	vec3 src = unpm(src4);

	float l = dot(src, LUMA);
	vec3 sat = clamp(mix(vec3(l), src, 1.0 + punch * 1.3), 0.0, 1.0);
	vec3 post = floor(sat * 5.0 + 0.5) / 5.0;
	vec3 base = mix(sat, post, punch);

	float k = 1.0 - max(max(base.r, base.g), base.b);
	float denom = max(1.0 - k, 0.001);
	float c = (1.0 - base.r - k) / denom;
	float m = (1.0 - base.g - k) / denom;
	float y = (1.0 - base.b - k) / denom;

	vec2 uvpx = UV * sz;
	float cell = max(dot_size, 2.0);
	float ab = radians(angle);
	float cd = halftone(uvpx, ab + radians(15.0), c, cell);
	float md = halftone(uvpx, ab + radians(75.0), m, cell);
	float yd = halftone(uvpx, ab + radians(0.0), y, cell);
	float kd = halftone(uvpx, ab + radians(45.0), k, cell);

	vec3 col = vec3(1.0);
	col = mix(col, col * vec3(0.10, 0.90, 0.95), cd);
	col = mix(col, col * vec3(0.95, 0.10, 0.60), md);
	col = mix(col, col * vec3(0.98, 0.95, 0.10), yd);
	col = mix(col, col * vec3(0.07, 0.07, 0.07), kd);

	vec2 tpx = 1.0 / sz;
	float tl = dot(unpm(texture(TEXTURE, clamp(UV + vec2(-tpx.x, -tpx.y), vec2(0.0), vec2(1.0)))), LUMA);
	float tm = dot(unpm(texture(TEXTURE, clamp(UV + vec2(0.0, -tpx.y), vec2(0.0), vec2(1.0)))), LUMA);
	float tr = dot(unpm(texture(TEXTURE, clamp(UV + vec2(tpx.x, -tpx.y), vec2(0.0), vec2(1.0)))), LUMA);
	float ml = dot(unpm(texture(TEXTURE, clamp(UV + vec2(-tpx.x, 0.0), vec2(0.0), vec2(1.0)))), LUMA);
	float mr = dot(unpm(texture(TEXTURE, clamp(UV + vec2(tpx.x, 0.0), vec2(0.0), vec2(1.0)))), LUMA);
	float bl = dot(unpm(texture(TEXTURE, clamp(UV + vec2(-tpx.x, tpx.y), vec2(0.0), vec2(1.0)))), LUMA);
	float bm = dot(unpm(texture(TEXTURE, clamp(UV + vec2(0.0, tpx.y), vec2(0.0), vec2(1.0)))), LUMA);
	float br = dot(unpm(texture(TEXTURE, clamp(UV + vec2(tpx.x, tpx.y), vec2(0.0), vec2(1.0)))), LUMA);
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bm + br) - (tl + 2.0 * tm + tr);
	float edge = sqrt(gx * gx + gy * gy);
	float ink = smoothstep(0.35, 0.7, edge) * edges;
	col = mix(col, vec3(0.05, 0.05, 0.06), ink);

	vec3 outc = mix(src, col, clamp(amount, 0.0, 1.0));
	COLOR = vec4(outc * src4.a, src4.a);
}
