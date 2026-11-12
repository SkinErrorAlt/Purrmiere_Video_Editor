shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float cell_px : hint_range(2.0, 160.0) = 18.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float spread : hint_range(0.0, 1.0) = 0.22;
uniform int mode : hint_range(0, 2) = 0;
uniform int seed : hint_range(0, 9999) = 0;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 cell_uv = vec2(cell_px) / sz;
	vec2 ncells = max(floor(sz / vec2(cell_px)), vec2(1.0));
	vec2 cell = floor(UV / cell_uv);
	float sd = float(seed);

	vec2 target = cell;
	if (mode == 0) {
		vec2 h = hash22(cell + vec2(sd * 1.7 + 3.0, sd * 0.9 + 7.0));
		vec2 off = (h - 0.5) * 2.0 * spread * ncells;
		target = cell + floor(off + 0.5);
	} else if (mode == 1) {
		float h = hash22(vec2(cell.y, sd)).x;
		target.x = cell.x + floor((h - 0.5) * 2.0 * spread * ncells.x + 0.5);
	} else {
		float h = hash22(vec2(cell.x, sd)).x;
		target.y = cell.y + floor((h - 0.5) * 2.0 * spread * ncells.y + 0.5);
	}
	target = mod(target, ncells);
	if (target.x < 0.0) {
		target.x += ncells.x;
	}
	if (target.y < 0.0) {
		target.y += ncells.y;
	}

	vec2 uv_scram = clamp((target + 0.5) * cell_uv, vec2(0.0), vec2(1.0));
	vec2 uv_plain = clamp((cell + 0.5) * cell_uv, vec2(0.0), vec2(1.0));
	vec4 scram = texture(TEXTURE, uv_scram);
	vec4 plain = texture(TEXTURE, uv_plain);
	COLOR = mix(plain, scram, clamp(amount, 0.0, 1.0));
}
