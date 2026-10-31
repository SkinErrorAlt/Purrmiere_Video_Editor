shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float intensity : hint_range(0.0, 4.0) = 1.3;
uniform float saturation : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool glow_only = false;

const float HEAD = 16.0;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 orig = texture(effect_tex, UV);
	vec4 e = texture(TEXTURE, UV);
	vec4 g = e * e * HEAD * intensity * 0.25;
	vec3 glow = g.rgb * tint.rgb;
	float lum = dot(glow, LUMA);
	glow = max(vec3(lum) + (glow - vec3(lum)) * (1.0 + clamp(saturation, 0.0, 1.0)), vec3(0.0));
	glow += (hash12(FRAGCOORD.xy) - 0.5) / 255.0 * step(0.002, lum);
	glow = max(glow, vec3(0.0));
	float ga = clamp(max(glow.r, max(glow.g, glow.b)), 0.0, 1.0);
	if (glow_only) {
		COLOR = vec4(min(glow, vec3(1.0)), ga);
	} else {
		float a = clamp(orig.a + ga * (1.0 - orig.a), 0.0, 1.0);
		COLOR = vec4(min(orig.rgb + glow, vec3(a)), a);
	}
}
