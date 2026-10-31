shader_type canvas_item;
render_mode blend_disabled;

uniform float size : hint_range(2.0, 2000.0) = 120.0;
uniform float thickness : hint_range(0.0, 200.0) = 2.0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float feather : hint_range(0.0, 100.0) = 0.0;
uniform bool thirds = false;
uniform int blend : hint_range(0, 6) = 6;
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
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float half_w = thickness * ps * 0.5;
	float soft = feather * ps + 1.0;
	float dline;
	if (thirds) {
		vec2 pos = UV * sz;
		vec2 dd = min(abs(pos - sz / 3.0), abs(pos - sz * (2.0 / 3.0)));
		dline = min(dd.x, dd.y);
	} else {
		vec2 pos = (UV - 0.5) * sz;
		float rad = radians(angle);
		float cs = cos(rad);
		float sn = sin(rad);
		pos = vec2(cs * pos.x + sn * pos.y, cs * pos.y - sn * pos.x) - offset * ps;
		float cell = max(size * ps, 1.0);
		vec2 q = abs(mod(pos + vec2(0.5 * cell), vec2(cell)) - vec2(0.5 * cell));
		dline = min(q.x, q.y);
	}
	float cov = 1.0 - smoothstep(half_w - 0.5 * soft, half_w + 0.5 * soft, dline);
	cov *= clamp(thickness * ps, 0.0, 1.0) * colour.a;
	COLOR = mix_in(rgb, a, colour.rgb, cov, blend, strength);
}
