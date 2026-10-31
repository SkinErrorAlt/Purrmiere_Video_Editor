shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D sparks_tex : filter_linear, repeat_disable;
uniform vec2 source = vec2(0.32, 0.55);
uniform vec4 colour : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform float glow : hint_range(0.0, 3.0) = 1.0;
uniform int blend : hint_range(0, 3) = 0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec4 pic = texture(effect_tex, UV);
	float a0 = pic.a;
	vec3 rgb = a0 > 0.0001 ? pic.rgb / a0 : vec3(0.0);
	vec2 sz = max(tex_size * 2.0, vec2(1.0));
	vec2 p = UV * sz;
	float t = clip_time;
	float sd = mod(float(seed), 9973.0);
	vec3 sparks = texture(sparks_tex, UV).rgb;
	vec3 gl = texture(TEXTURE, UV).rgb * (glow / 3.0) * 1.6;
	vec3 light = sparks + gl;
	float fl = 0.7 + 0.3 * h12(vec2(floor(t * 40.0), sd + 3.0));
	vec2 dv = (p - source * sz) / sz.y;
	float near = 1.0 / (1.0 + dot(dv, dv) * 9.0);
	vec3 warm = mix(vec3(1.0, 0.75, 0.45), colour.rgb, 0.35) * near * fl * glow * 0.32;
	float dith = (h12(p + fract(t * 7.13) * 91.0) - 0.5) / 255.0;
	if (blend == 3) {
		COLOR = vec4(clamp(light + warm * 0.1 + dith, 0.0, 1.0), 1.0);
	} else {
		vec3 lp = rgb * (1.0 + warm + gl * 0.5);
		vec3 o;
		if (blend == 1) {
			o = 1.0 - (1.0 - clamp(lp, 0.0, 1.0)) * (1.0 - clamp(light, 0.0, 1.0));
		} else if (blend == 2) {
			o = max(lp, light);
		} else {
			o = lp + light;
		}
		COLOR = vec4(clamp(o + dith, 0.0, 1.0) * a0, a0);
	}
}
