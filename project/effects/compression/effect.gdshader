shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform vec2 seq_size = vec2(1920.0, 1080.0);
uniform float target_lines : hint_range(0.0, 2160.0) = 0.0;
uniform float chroma_ratio : hint_range(1.0, 8.0) = 2.0;
uniform float block_strength : hint_range(0.0, 1.0) = 0.5;
uniform float levels : hint_range(4.0, 255.0) = 255.0;
uniform float ringing : hint_range(0.0, 1.0) = 0.25;
uniform bool smooth_upscale = true;
uniform bool grid_from_sequence = false;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec3 read_at(sampler2D tex, vec2 uv) {
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

vec3 sample_grid(sampler2D tex, vec2 uv, vec2 cells) {
	vec2 grid = uv * cells - 0.5;
	vec2 base = floor(grid);
	vec2 f = grid - base;
	if (smooth_upscale) {
		f = f * f * (3.0 - 2.0 * f);
	} else {
		f = step(0.5, f);
	}
	vec2 step_uv = 1.0 / cells;
	vec2 c0 = (base + 0.5) * step_uv;
	vec3 a = read_at(tex, c0);
	vec3 b = read_at(tex, c0 + vec2(step_uv.x, 0.0));
	vec3 c = read_at(tex, c0 + vec2(0.0, step_uv.y));
	vec3 d = read_at(tex, c0 + step_uv);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 srcp = texture(TEXTURE, UV);
	float alpha = srcp.a;
	vec3 src = alpha > 0.0001 ? srcp.rgb / alpha : vec3(0.0);
	vec2 ref = grid_from_sequence ? seq_size : tex_size;
	float source_lines = max(ref.y, 1.0);
	if (target_lines < 1.0 || target_lines >= source_lines) {
		COLOR = srcp;
	} else {
		float aspect = max(ref.x, 1.0) / max(ref.y, 1.0);
		vec2 cells = vec2(max(target_lines * aspect, 1.0), target_lines);
		vec3 fine = sample_grid(TEXTURE, UV, cells);
		vec3 chroma_src = sample_grid(TEXTURE, UV, max(cells / chroma_ratio, vec2(1.0)));
		float y = dot(fine, LUMA);
		vec3 chroma = chroma_src - vec3(dot(chroma_src, LUMA));
		vec3 col = clamp(vec3(y) + chroma, 0.0, 1.0);
		vec3 block = sample_grid(TEXTURE, UV, max(cells / 8.0, vec2(1.0)));
		float detail = clamp(length(fine - block) * 3.0, 0.0, 1.0);
		float flat_here = 1.0 - detail;
		col = mix(col, block, block_strength * flat_here);
		col += (fine - block) * ringing;
		if (levels < 254.0) {
			col = floor(clamp(col, 0.0, 1.0) * levels + 0.5) / levels;
		}
		COLOR = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
	}
}
