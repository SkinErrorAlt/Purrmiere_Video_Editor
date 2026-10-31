shader_type canvas_item;
render_mode blend_disabled;

uniform float dot_size : hint_range(2.0, 60.0) = 8.0;
uniform float density : hint_range(0.0, 1.0) = 0.8;
uniform float jitter : hint_range(0.0, 1.0) = 0.7;
uniform float size_variation : hint_range(0.0, 1.0) = 0.3;
uniform float saturation_boost : hint_range(0.0, 2.0) = 0.4;
uniform float colour_variation : hint_range(0.0, 1.0) = 0.2;
uniform vec4 paper : source_color = vec4(0.96, 0.94, 0.88, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float dpx = max(dot_size * px_scale, 1.5);
	float spacing = dpx * mix(1.5, 0.6, clamp(density, 0.0, 1.0));
	vec2 p = UV * dims / spacing;
	vec2 base = floor(p);
	vec2 so = seed_offset(seed);
	float aa = 0.7 / spacing;
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 col = paper.rgb;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = base + vec2(float(x), float(y));
			vec2 centre = cell + 0.5 + (hash22(cell + so) - 0.5) * clamp(jitter, 0.0, 1.0);
			float vary = hash12(cell + so + 17.0);
			float rad = 0.5 * dpx * (1.0 - clamp(size_variation, 0.0, 1.0) * vary * 0.7) / spacing;
			float cover = 1.0 - smoothstep(rad - aa, rad + aa, length(p - centre));
			vec4 s = texture(TEXTURE, clamp(centre * spacing / dims, vec2(0.0), vec2(1.0)));
			vec3 sc = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
			float luma = dot(sc, vec3(0.2126, 0.7152, 0.0722));
			sc = mix(vec3(luma), sc, 1.0 + saturation_boost);
			vec3 shift = vec3(hash22(cell + so + 31.0), hash12(cell + so + 47.0)) - 0.5;
			sc *= 1.0 + shift * colour_variation * 0.6;
			col = mix(col, clamp(sc, 0.0, 1.0), cover * s.a);
		}
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
