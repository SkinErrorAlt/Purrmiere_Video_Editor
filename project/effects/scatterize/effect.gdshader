shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 0.5) = 0.03;
uniform float grain : hint_range(1.0, 40.0) = 5.0;
uniform float dot_size : hint_range(0.3, 1.4) = 1.15;
uniform float gravity : hint_range(-1.0, 1.0) = 0.0;
uniform float shrink : hint_range(0.0, 1.0) = 0.5;
uniform float edges : hint_range(0.0, 1.0) = 0.0;
uniform vec4 backdrop : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float px_scale = 1.0;

float sc_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 sc_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (strength <= 0.0 || amount <= 0.0) {
		COLOR = base;
	} else {
		vec2 px = max(tex_size, vec2(1.0));
		vec2 cell_uv = vec2(max(grain, 1.0) * max(px_scale, 0.0001)) / px;
		vec2 here = UV / cell_uv;
		vec4 acc = backdrop;
		float cover = 0.0;
		vec3 colour = vec3(0.0);
		for (int j = -2; j <= 2; j++) {
			for (int i = -2; i <= 2; i++) {
				vec2 cell = floor(here) + vec2(float(i), float(j));
				vec2 src_centre = (cell + 0.5) * cell_uv;
				if (src_centre.x < 0.0 || src_centre.x > 1.0 || src_centre.y < 0.0 || src_centre.y > 1.0) {
					continue;
				}
				vec2 r = sc_hash2(cell + 7.1) - 0.5;
				float far = sc_hash(cell + 2.9);
				float edge_gain = mix(1.0, length((src_centre - 0.5) * 2.0), edges);
				vec2 throw_dir = normalize(r + vec2(0.0001, 0.0002));
				vec2 off = throw_dir * amount * far * edge_gain;
				off.y += gravity * amount * far * 1.4;
				vec2 at = src_centre + off;
				float size = mix(1.0, 1.0 - far * 0.8, shrink) * dot_size;
				vec2 d = (UV - at) / max(cell_uv * size, vec2(0.000001));
				float dist = length(d * vec2(1.0, 1.0));
				float g = 1.0 - smoothstep(0.42, 0.52, dist);
				if (g <= 0.0) {
					continue;
				}
				vec3 c = texture(TEXTURE, src_centre).rgb;
				if (g > cover) {
					cover = g;
					colour = c;
				}
			}
		}
		vec4 scattered = mix(backdrop, vec4(colour, 1.0), cover);
		COLOR = mix(base, scattered, strength);
	}
}
