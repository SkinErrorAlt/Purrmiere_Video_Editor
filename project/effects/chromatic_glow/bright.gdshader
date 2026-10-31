shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.45;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);
const float HEAD = 16.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, LUMA);
	float k = max(0.3 * threshold, 0.0001);
	float soft = clamp(l - threshold + k, 0.0, 2.0 * k);
	soft = soft * soft / (4.0 * k);
	float contribution = max(soft, l - threshold) / max(l, 0.0001);
	float a = max(c.a, 0.0001);
	float peak = max(c.r, max(c.g, c.b)) / a;
	float boost = 1.0 + 5.0 * smoothstep(0.82, 1.0, peak);
	vec4 v = max(c * contribution * boost, vec4(0.0));
	vec4 enc = sqrt(clamp(v / HEAD, 0.0, 1.0));
	COLOR = clamp(enc + (hash12(FRAGCOORD.xy) - 0.5) / 255.0, 0.0, 1.0);
}
