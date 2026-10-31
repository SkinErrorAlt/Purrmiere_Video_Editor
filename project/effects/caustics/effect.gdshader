shader_type canvas_item;
render_mode blend_disabled;

uniform float scale : hint_range(0.1, 10.0) = 1.0;
uniform float speed : hint_range(0.0, 5.0) = 0.6;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float sharpness : hint_range(2.0, 16.0) = 8.0;
uniform vec4 colour : source_color = vec4(0.75, 0.92, 1.0, 1.0);
uniform int blend : hint_range(0, 6) = 4;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	vec2 uv = UV * vec2(sz.x / sz.y, 1.0) / max(scale, 0.01);
	float tt = clip_time * speed * 0.5 + 23.0;
	vec2 pos = mod(uv * 6.2831853, vec2(6.2831853)) - 250.0;
	vec2 it = pos;
	float cc = 1.0;
	float inten = 0.005;
	float ax = pos.x * inten;
	float by = pos.y * inten;
	for (int n = 0; n < 5; n++) {
		float tn = tt * (1.0 - (3.5 / float(n + 1)));
		it = pos + vec2(cos(tn - it.x) + sin(tn + it.y), sin(tn - it.y) + cos(tn + it.x));
		float sx = sin(it.x + tn);
		float cy = cos(it.y + tn);
		float den = sqrt(ax * ax * cy * cy + by * by * sx * sx);
		cc += abs(sx * cy) / max(den, 0.000001);
	}
	cc /= 5.0;
	cc = 1.17 - pow(max(cc, 0.0), 1.4);
	float v = pow(max(cc, 0.0), max(sharpness, 1.0));
	float cov = clamp(v * intensity, 0.0, 1.0) * colour.a;
	COLOR = mix_in(rgb, a, colour.rgb, cov, blend, strength);
}
