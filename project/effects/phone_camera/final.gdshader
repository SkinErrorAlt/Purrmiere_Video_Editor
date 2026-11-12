shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D nr_tex : filter_linear, repeat_disable;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
uniform float hdr : hint_range(0.0, 1.0) = 0.6;
uniform float sharpen : hint_range(0.0, 3.0) = 1.0;
uniform float sharpen_radius : hint_range(0.5, 4.0) = 1.3;
uniform float colour : hint_range(0.0, 1.0) = 0.3;
uniform float zoom : hint_range(1.0, 10.0) = 1.0;
uniform vec2 zoom_centre = vec2(0.5, 0.5);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 to_lin(vec3 v) {
	vec3 lo = v / 12.92;
	vec3 hi = pow((v + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, step(v, vec3(0.04045)));
}

vec3 to_srgb(vec3 v) {
	vec3 lo = v * 12.92;
	vec3 hi = 1.055 * pow(max(v, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(hi, lo, step(v, vec3(0.0031308)));
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

float yof(sampler2D t, vec2 uv) {
	return dot(straight(texture(t, uv)), LUMA);
}

void fragment() {
	float z = max(zoom, 1.0);
	float half_w = 0.5 / z;
	vec2 zc = clamp(zoom_centre, vec2(half_w), vec2(1.0 - half_w));
	vec2 uv = zc + (UV - 0.5) / z;
	vec2 opx = vec2(abs(dFdx(UV.x)), abs(dFdy(UV.y)));
	vec2 zpx = opx / z;
	float out_scale = max(px_scale * 8.0, 0.125);
	vec4 orig = texture(effect_tex, uv);
	vec4 c = texture(nr_tex, uv);
	float a = orig.a;
	vec3 rgb = straight(c);
	vec3 lin = to_lin(clamp(rgb, 0.0, 1.0));
	float y = dot(lin, LUMA);
	float logy = log2(y + 0.001);
	float base = texture(TEXTURE, uv).r * 10.0 - 10.0;
	float k = clamp(hdr, 0.0, 1.0);
	float anchor = -2.6;
	float new_base = (base - anchor) * mix(1.0, 0.38, k) + anchor + 0.35 * k;
	float new_log = new_base + (logy - base) * (1.0 + 0.35 * k);
	float gain = exp2(new_log - logy);
	vec3 tl = lin * gain;
	float peak = max(tl.r, max(tl.g, tl.b));
	tl /= 1.0 + max(peak - 0.75, 0.0) * 1.1 * k;
	vec3 outc = k > 0.0 ? to_srgb(max(tl, vec3(0.0))) : rgb;
	if (sharpen > 0.0) {
		vec2 r = zpx * sharpen_radius * out_scale;
		float y0 = dot(rgb, LUMA);
		float sb = yof(nr_tex, uv + vec2(r.x, 0.0)) + yof(nr_tex, uv - vec2(r.x, 0.0)) + yof(nr_tex, uv + vec2(0.0, r.y)) + yof(nr_tex, uv - vec2(0.0, r.y));
		float sd = yof(nr_tex, uv + r) + yof(nr_tex, uv - r) + yof(nr_tex, uv + vec2(r.x, -r.y)) + yof(nr_tex, uv + vec2(-r.x, r.y));
		float blur = (y0 * 4.0 + sb * 2.0 + sd) / 16.0;
		float lift = sharpen * 2.2 * (y0 - blur);
		lift = sign(lift) * min(abs(lift), 0.45);
		outc += vec3(lift);
	}
	if (colour > 0.0) {
		float g = dot(outc, LUMA);
		float sat = max(outc.r, max(outc.g, outc.b)) - min(outc.r, min(outc.g, outc.b));
		outc = mix(vec3(g), outc, 1.0 + colour * 0.9 * (1.0 - clamp(sat, 0.0, 1.0)));
	}
	outc = clamp(outc, 0.0, 1.0);
	COLOR = vec4(outc * a, a);
}
