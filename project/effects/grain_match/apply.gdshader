shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
uniform float time = 0.0;
uniform int match : hint_range(0, 1) = 0;
uniform float level : hint_range(0.0, 10.0) = 2.0;
uniform float grain_size : hint_range(1.0, 4.0) = 1.3;
uniform float colour : hint_range(0.0, 1.0) = 0.2;
uniform float response : hint_range(0.0, 1.0) = 0.6;
uniform bool animate = true;
uniform bool show_grain = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float gauss_at(vec2 cell, float salt) {
	float s = hash12(cell + salt) + hash12(cell + salt + 17.31) + hash12(cell + salt + 41.77) + hash12(cell + salt + 73.09);
	return (s - 2.0) * 1.7320508;
}

float grain_at(vec2 p, float salt) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = gauss_at(i, salt);
	float b = gauss_at(i + vec2(1.0, 0.0), salt);
	float c = gauss_at(i + vec2(0.0, 1.0), salt);
	float d = gauss_at(i + vec2(1.0, 1.0), salt);
	vec2 spread = (1.0 - u) * (1.0 - u) + u * u;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) / sqrt(spread.x * spread.y);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	vec4 st = textureLod(TEXTURE, vec2(0.5), 0.0);
	float have = st.r * 0.1;
	float want = (match == 1 && st.b > 0.5) ? st.g * 0.1 : level * 0.01;
	float add = sqrt(max(want * want - have * have, 0.0));
	float seed = animate ? floor(time * 24.0) : 0.0;
	vec2 layer = vec2(textureSize(effect_tex, 0));
	vec2 p = (UV * layer - 0.5) / max(grain_size * px_scale * 32.0, 0.5);
	float salt = seed * 37.7;
	float n = grain_at(p, salt);
	vec3 nc = vec3(grain_at(p, salt + 101.0), n, grain_at(p, salt + 211.0));
	vec3 g = mix(vec3(n), nc, colour);
	float y = dot(rgb, LUMA);
	float tone = mix(1.0, clamp(4.0 * y * (1.0 - y) * 1.25, 0.0, 1.25), response);
	vec3 outc = show_grain ? vec3(0.5) + g * add * 2.0 : rgb + g * add * tone;
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
