shader_type canvas_item;
render_mode blend_disabled;

uniform float charcoal_area : hint_range(0.0, 20.0) = 6.0;
uniform float chalk_area : hint_range(0.0, 20.0) = 6.0;
uniform float stroke_pressure : hint_range(0.0, 5.0) = 1.0;
uniform vec4 charcoal_colour : source_color = vec4(0.07, 0.07, 0.08, 1.0);
uniform vec4 chalk_colour : source_color = vec4(0.97, 0.97, 0.95, 1.0);
uniform vec4 paper : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float lum(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

float stroke(vec2 p, float ang, float w, float len, vec2 so) {
	vec2 dir = vec2(cos(ang), -sin(ang));
	float along = dot(p, dir);
	float across = dot(p, vec2(-dir.y, dir.x));
	float s = across / w;
	float lane = floor(s);
	float f = fract(s);
	float prof = 1.0 - smoothstep(0.22, 0.44, abs(f - 0.5));
	float seg = value_noise(vec2(along / len + hash12(vec2(lane, so.x)) * 23.0, lane * 0.71 + so.y));
	float grain = value_noise(vec2(along / 2.2, across / 0.9) + so * 0.7);
	return prof * smoothstep(0.2, 0.7, seg) * (0.55 + 0.45 * grain);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec2 so = seed_offset(seed);
	vec2 e = vec2(2.0 * ps) / dims;
	float tone = lum(c) * 0.4 + (lum(texture(TEXTURE, UV + vec2(e.x, 0.0))) + lum(texture(TEXTURE, UV - vec2(e.x, 0.0))) + lum(texture(TEXTURE, UV + vec2(0.0, e.y))) + lum(texture(TEXTURE, UV - vec2(0.0, e.y)))) * 0.15;
	vec2 pix = UV * dims / ps;
	float sd = stroke(pix, radians(45.0), 3.2, 16.0, so);
	float sl = stroke(pix + 1.3, radians(-45.0), 3.6, 14.0, so + 19.0);
	float dark_t = 0.15 + charcoal_area * 0.025;
	float light_t = 0.85 - chalk_area * 0.025;
	float dark_amt = smoothstep(dark_t + 0.22, dark_t - 0.15, tone);
	float light_amt = smoothstep(light_t - 0.22, light_t + 0.15, tone);
	float k = 2.0 + stroke_pressure * 1.2;
	float cov_d = clamp((dark_amt * 1.15 - (1.0 - sd)) * k, 0.0, 1.0);
	float cov_l = clamp((light_amt * 1.15 - (1.0 - sl)) * k, 0.0, 1.0);
	float tooth = value_noise(pix / 1.5 + so);
	vec3 outc = paper.rgb * (0.95 + 0.1 * tooth);
	outc = mix(outc, chalk_colour.rgb, cov_l);
	outc = mix(outc, charcoal_colour.rgb, cov_d);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
