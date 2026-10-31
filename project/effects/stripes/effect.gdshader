shader_type canvas_item;
render_mode blend_disabled;

uniform float width : hint_range(2.0, 2000.0) = 60.0;
uniform float ratio : hint_range(0.0, 1.0) = 0.5;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform vec4 colour_a : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform vec4 colour_b : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform float speed : hint_range(-2000.0, 2000.0) = 0.0;
uniform float softness : hint_range(0.0, 200.0) = 0.0;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

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

float band_sum(float x, float share) {
	return floor(x) * share + min(fract(x), share);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pos = (UV - 0.5) * sz;
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));
	float period = max(width * ps, 1.0);
	float shift = mod(clip_time * speed * ps, period);
	float x = (dot(pos, dir) - shift) / period;
	float fw = (softness * ps + 1.0) / period;
	float share = clamp(ratio, 0.0, 1.0);
	float ka = clamp((band_sum(x + 0.5 * fw, share) - band_sum(x - 0.5 * fw, share)) / fw, 0.0, 1.0);
	vec4 pa = vec4(colour_a.rgb * colour_a.a, colour_a.a);
	vec4 pb = vec4(colour_b.rgb * colour_b.a, colour_b.a);
	vec4 pm = mix(pb, pa, ka);
	vec3 gen = pm.a > 0.0001 ? pm.rgb / pm.a : vec3(0.0);
	COLOR = mix_in(rgb, a, gen, pm.a, blend, strength);
}
