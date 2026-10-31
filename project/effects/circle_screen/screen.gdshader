shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D soft_tex : filter_linear, repeat_disable;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float spacing : hint_range(2.0, 200.0) = 10.0;
uniform float contrast : hint_range(0.0, 4.0) = 1.0;
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.96, 0.93, 1.0);
uniform bool keep_colours = false;
uniform float px_scale = 1.0;

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(1.0);
}

void fragment() {
	vec2 full = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * 4.0, 0.0001);
	vec2 S = full / ps;
	vec2 C = centre * S;
	vec2 d = UV * S - C;
	float r = length(d);
	float sp = max(spacing, 0.5);
	float rl = floor(r / sp + 0.5) * sp;
	vec2 dir = r > 0.0001 ? d / r : vec2(1.0, 0.0);
	vec2 suv = clamp((C + dir * rl) / S, vec2(0.0), vec2(1.0));
	vec3 tone_c = straight(textureLod(soft_tex, suv, 0.0));
	float l = dot(tone_c, vec3(0.2126, 0.7152, 0.0722));
	l = clamp((l - 0.5) * max(contrast, 0.0) + 0.5, 0.0, 1.0);
	float duty = 1.0 - l;
	float hw = duty * sp * 0.5;
	float dist = abs(r - rl);
	float cov = clamp((hw - dist) * ps + 0.5, 0.0, 1.0) * clamp(hw * ps * 2.0, 0.0, 1.0);
	vec3 ink_c = keep_colours ? tone_c * 0.92 : ink.rgb;
	vec3 col = mix(paper.rgb, ink_c, cov);
	float a = textureLod(effect_tex, UV, 0.0).a;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
