shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform vec4 colour : source_color = vec4(0.3, 0.38, 0.52, 1.0);
uniform vec4 light_colour : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float light : hint_range(0.0, 1.0) = 0.7;
uniform vec2 light_at = vec2(0.5, 0.38);
uniform float light_size : hint_range(0.1, 2.0) = 0.7;
uniform float floor_amount : hint_range(0.0, 1.0) = 0.6;
uniform float horizon : hint_range(0.3, 1.0) = 0.72;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform float grain : hint_range(0.0, 1.0) = 0.25;
uniform int blend : hint_range(0, 7) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 blend_colour(vec3 base, vec3 over_c, int how) {
	if (how == 1) { return base * over_c; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over_c); }
	if (how == 3) { return mix(2.0 * base * over_c, 1.0 - 2.0 * (1.0 - base) * (1.0 - over_c), step(0.5, base)); }
	if (how == 4) { return base + over_c; }
	if (how == 5) { return (1.0 - 2.0 * over_c) * base * base + 2.0 * over_c * base; }
	return over_c;
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 1.0);
	float s = clamp(amt, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(g, 1.0), s);
	}
	if (how == 6) {
		return vec4(g * s + pc * pic_a * (1.0 - s), s + pic_a * (1.0 - s));
	}
	if (how == 7) {
		float w = s * (1.0 - pic_a);
		return vec4(pc * pic_a + g * w, pic_a + w);
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 k = vec2(asp, 1.0);
	vec2 p = UV * k;
	vec2 l = light_at * k;
	float ls = clamp(light_size, 0.1, 2.0);
	float h = clamp(horizon, 0.3, 1.0);
	float fl = clamp(floor_amount, 0.0, 1.0);
	float on_floor = smoothstep(h - 0.06, h + 0.1, p.y) * fl;
	vec2 wall_d = p - l;
	float wall_light = exp(-dot(wall_d, wall_d) / (ls * ls * 0.35));
	vec2 pool_c = vec2(l.x, h + (1.0 - h) * 0.55);
	vec2 pool_d = (p - pool_c) * vec2(1.0, 2.6);
	float pool = exp(-dot(pool_d, pool_d) / (ls * ls * 0.3));
	float lit = mix(wall_light, pool * 0.9 + wall_light * 0.25, on_floor);
	vec3 base = clamp(colour.rgb, 0.0, 1.0);
	float sweep = 1.0 - 0.18 * smoothstep(h - 0.15, h, p.y) * (1.0 - smoothstep(h, h + 0.08, p.y)) * fl;
	vec3 rgb = base * (0.45 + 0.25 * on_floor) * sweep;
	rgb += base * light_colour.rgb * lit * clamp(light, 0.0, 1.0) * 1.3;
	rgb += light_colour.rgb * pow(lit, 3.0) * clamp(light, 0.0, 1.0) * 0.12;
	vec2 vc = (UV - 0.5) * vec2(asp / max(asp, 1.0), 1.0 / max(1.0 / asp, 1.0)) * 2.0;
	rgb *= 1.0 - clamp(vignette, 0.0, 1.0) * 0.6 * smoothstep(0.5, 1.6, length(vc));
	float n = hash(floor(UV / max(fwidth(UV), vec2(0.000001))) + vec2(floor(fract(clip_time * 3.7) * 89.0) * 17.0)) - 0.5;
	rgb += n * clamp(grain, 0.0, 1.0) * 0.045;
	vec3 prgb = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
	COLOR = mix_in(prgb, pic.a, rgb, blend, strength);
}
