shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float passage : hint_range(2.0, 200.0) = 10.0;
uniform float wall : hint_range(1.0, 200.0) = 10.0;
uniform vec4 wall_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 passage_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec3 blend_colour(vec3 base, vec3 over, int how) {
	if (how == 1) { return base * over; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over); }
	if (how == 3) { return mix(2.0 * base * over, 1.0 - 2.0 * (1.0 - base) * (1.0 - over), step(0.5, base)); }
	if (how == 4) { return base + over; }
	if (how == 5) { return (1.0 - 2.0 * over) * base * base + 2.0 * over * base; }
	return over;
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, float cov, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 1.0);
	float s = clamp(amt, 0.0, 1.0);
	float k = clamp(cov, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(g * k, k), s);
	}
	if (how == 6) {
		float w = k * s;
		return vec4(g * w + pc * pic_a * (1.0 - w), w + pic_a * (1.0 - w));
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
	float q = max(px_scale * sz.x / max(tex_size.x, 1.0), 0.0001);
	float w = max(wall * q, 1.0);
	float pitch = max(passage * q, 1.0) + w;
	ivec2 cells = max(ivec2(floor((sz - w) / pitch)), ivec2(1));
	vec2 extent = vec2(cells) * pitch + w;
	vec2 origin = floor((sz - extent) * 0.5);
	vec2 pos = floor(UV * sz) + 0.5 - origin;
	bool is_wall = true;
	if (pos.x >= 0.0 && pos.y >= 0.0 && pos.x < extent.x && pos.y < extent.y) {
		ivec2 cell = ivec2(floor(pos / pitch));
		vec2 local = pos - vec2(cell) * pitch;
		bool on_x = local.x < w;
		bool on_y = local.y < w;
		if (on_x && on_y) {
			is_wall = true;
		} else if (on_x) {
			if (cell.x <= 0 || cell.x >= cells.x || cell.y >= cells.y) {
				is_wall = true;
			} else {
				ivec2 k = min(ivec2(cell.x - 1, cell.y), textureSize(TEXTURE, 0) - 1);
				is_wall = texelFetch(TEXTURE, k, 0).r < 0.5;
			}
		} else if (on_y) {
			if (cell.y <= 0 || cell.y >= cells.y || cell.x >= cells.x) {
				is_wall = true;
			} else {
				ivec2 k = min(ivec2(cell.x, cell.y - 1), textureSize(TEXTURE, 0) - 1);
				is_wall = texelFetch(TEXTURE, k, 0).g < 0.5;
			}
		} else {
			is_wall = cell.x >= cells.x || cell.y >= cells.y;
		}
	}
	vec4 col = is_wall ? wall_colour : passage_colour;
	COLOR = mix_in(rgb, a, col.rgb, col.a, blend, strength);
}
