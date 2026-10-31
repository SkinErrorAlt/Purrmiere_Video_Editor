shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 point_1 = vec2(0.1, 0.1);
uniform vec4 colour_1 : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec2 point_2 = vec2(0.9, 0.1);
uniform vec4 colour_2 : source_color = vec4(0.2, 0.8, 0.45, 1.0);
uniform vec2 point_3 = vec2(0.1, 0.9);
uniform vec4 colour_3 : source_color = vec4(0.9, 0.25, 0.6, 1.0);
uniform vec2 point_4 = vec2(0.9, 0.9);
uniform vec4 colour_4 : source_color = vec4(0.15, 0.3, 0.9, 1.0);
uniform int method : hint_range(0, 1) = 0;
uniform float blend_power : hint_range(0.5, 8.0) = 2.0;
uniform float jitter : hint_range(0.0, 1.0) = 0.2;
uniform int blend : hint_range(0, 6) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

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
	vec2 aspect = vec2(sz.x / sz.y, 1.0);
	vec2 pos = UV * aspect;
	vec4 d = vec4(length(pos - point_1 * aspect), length(pos - point_2 * aspect), length(pos - point_3 * aspect), length(pos - point_4 * aspect));
	d = max(d, vec4(0.00001));
	float dmin = min(min(d.x, d.y), min(d.z, d.w));
	float pw = max(blend_power, 0.01);
	vec4 w;
	if (method == 1) {
		w = exp(-(d - vec4(dmin)) * pw * 3.0);
	} else {
		w = pow(vec4(dmin) / d, vec4(pw));
	}
	float total = max(w.x + w.y + w.z + w.w, 0.0001);
	vec3 lin = (colour_1.rgb * colour_1.rgb * w.x + colour_2.rgb * colour_2.rgb * w.y + colour_3.rgb * colour_3.rgb * w.z + colour_4.rgb * colour_4.rgb * w.w) / total;
	float ga = dot(vec4(colour_1.a, colour_2.a, colour_3.a, colour_4.a), w) / total;
	vec3 gen = sqrt(max(lin, vec3(0.0)));
	vec2 px = floor(UV * sz);
	float n = hash12(px) + hash12(px + vec2(37.1, 91.7)) - 1.0;
	gen += vec3(n * clamp(jitter, 0.0, 1.0) * 0.04);
	COLOR = mix_in(rgb, a, gen, ga, blend, strength);
}
